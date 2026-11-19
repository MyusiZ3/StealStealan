--!strict
-- PoacherAISystem.luau
-- Manages Biome Pet Guards & Bosses (5-Biome Voxel Guard Rigs):
-- Waypoint Patrol, Biome-Scoped End-to-End Chase to Safe Zone, Attack Animation Sync, & Shield/GodMode checks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local VehicleConfig = require(ReplicatedStorage.Config.VehicleConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local VoxelPetGuardBuilder = require(ReplicatedStorage.Modules.VoxelPetGuardBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.Parent.Services.DataService)
local AdminService = require(script.Parent.Parent.Services.AdminService)

local PoacherAISystem = {}

type PoacherAgent = {
	id: string,
	biomeId: string,
	isBoss: boolean,
	baseSpeed: number,
	recommendedSpeed: number,
	zMin: number,
	zMax: number,
	model: Model,
	root: Part,
	hitbox: Part,
	waypoints: { Vector3 },
	wpIndex: number,
	baseScale: number,
	rootYOffset: number,
	groundY: number,
	catchRadius: number,
	lastAnimState: string,
	lastQuantSpeed: number,
	attackSeq: number,
	groundRayAccum: number,
}

local agents: { PoacherAgent } = {}
local playerShields: { [number]: number } = {}
local playerBiomeAggro: { [number]: { [string]: boolean } } = {}
local onCatchCallbacks: { (Player, Vector3) -> () } = {}

function PoacherAISystem.OnPlayerCaught(cb: (Player, Vector3) -> ())
	table.insert(onCatchCallbacks, cb)
end

function PoacherAISystem.ResetShieldsForPlayer(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local hits = 0
	for _, v in ipairs(VehicleConfig) do
		if v.id == profile.equippedVehicle then
			hits = v.shieldHits
			break
		end
	end
	playerShields[player.UserId] = hits
	player:SetAttribute("ArmorShields", hits)
end

local function syncAggroBiomesAttr(player: Player)
	local map = playerBiomeAggro[player.UserId]
	if not map or next(map) == nil then
		player:SetAttribute("AggroBiomesCsv", "")
		return
	end
	local keys: { string } = {}
	for bId, active in pairs(map) do
		if active then
			table.insert(keys, bId)
		end
	end
	if #keys == 0 then
		player:SetAttribute("AggroBiomesCsv", "")
	else
		player:SetAttribute("AggroBiomesCsv", "," .. table.concat(keys, ",") .. ",")
	end
end

function PoacherAISystem.TriggerBiomeAggro(biomeId: string, player: Player)
	if (tonumber(player:GetAttribute("TowedCrateCount")) or 0) <= 0 then
		return
	end
	local uid = player.UserId
	playerBiomeAggro[uid] = playerBiomeAggro[uid] or {}
	playerBiomeAggro[uid][biomeId] = true
	syncAggroBiomesAttr(player)
	Remotes.Get("PoacherAlertSync"):FireClient(player, true, biomeId)
end

function PoacherAISystem.ClearBiomeAggro(player: Player, biomeId: string?)
	local uid = player.UserId
	local map = playerBiomeAggro[uid]
	if not map then
		player:SetAttribute("AggroBiomesCsv", "")
		Remotes.Get("PoacherAlertSync"):FireClient(player, false, "")
		return
	end
	if biomeId then
		map[biomeId] = nil
	else
		table.clear(map)
	end
	syncAggroBiomesAttr(player)
	local hasAny = next(map) ~= nil
	if not hasAny then
		Remotes.Get("PoacherAlertSync"):FireClient(player, false, "")
	end
end

local function hasAggroInBiome(userId: number, biomeId: string): boolean
	local map = playerBiomeAggro[userId]
	return map ~= nil and map[biomeId] == true
end

local ENEMY_TIERS: { [string]: { emoji: string, label: string, color: Color3 } } = {
	PineWoods = { emoji = "😠", label = "Easy", color = Color3.fromRGB(118, 245, 118) },
	MangroveSwamp = { emoji = "😢", label = "Medium", color = Color3.fromRGB(255, 168, 52) },
	SavannaCamp = { emoji = "😰", label = "Hard", color = Color3.fromRGB(255, 102, 58) },
	AlpinePeaks = { emoji = "😡", label = "Extreme", color = Color3.fromRGB(255, 58, 78) },
	VolcanicJungle = { emoji = "😈", label = "Nightmare", color = Color3.fromRGB(218, 76, 255) },
}

local function sampleFloorHeight(rayParams: RaycastParams, x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 2.5, z), Vector3.new(0, -5.0, 0), rayParams)
	if hit and hit.Position.Y >= -0.2 and hit.Position.Y <= 1.25 then
		return hit.Position.Y
	end
	return fallback
end

local function buildPoacherModel(
	name: string,
	isBoss: boolean,
	biomeId: string,
	_accentColor: Color3,
	pos: Vector3,
	initialGroundY: number,
	parent: Instance
): (Model, Part, Part, number, number, number)
	local guardCfg = VoxelPetGuardBuilder.GetConfig(biomeId)
	local guardScale = if isBoss then (guardCfg.scale * 1.16) else (guardCfg.scale * 0.85)
	local spawnCF = CFrame.new(pos.X, initialGroundY, pos.Z)

	local m = VoxelPetGuardBuilder.Build(biomeId, spawnCF, {
		scale = guardScale,
		rigged = true,
		isBoss = isBoss,
		canCollide = false,
		withEffects = true,
		parent = nil,
	})
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local root = m.PrimaryPart :: Part
	local rootYOffset = tonumber(m:GetAttribute("RootYOffset")) or (3.2 * guardScale)

	local hitW = math.clamp(3.6 * guardScale, 3.8, 9.0)
	local hitH = math.clamp(7.4 * guardScale, 6.8, 17.5)
	local hitD = math.clamp(3.4 * guardScale, 3.6, 8.6)
	local catchRadius = math.clamp((if isBoss then 3.8 else 3.0) * math.sqrt(guardScale), 3.4, 7.2)

	local hitbox = Instance.new("Part")
	hitbox.Name = "HitboxTrigger"
	hitbox.Shape = Enum.PartType.Block
	hitbox.Size = Vector3.new(hitW, hitH, hitD)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = true
	hitbox.CanQuery = true
	hitbox.CastShadow = false
	hitbox.CFrame = CFrame.new(pos.X, initialGroundY + hitH * 0.5, pos.Z)
	hitbox:SetAttribute("PoacherBiomeId", biomeId)
	hitbox:SetAttribute("IsBoss", isBoss)
	hitbox:SetAttribute("CatchRadius", catchRadius)
	hitbox:SetAttribute("GuardScale", guardScale)
	hitbox.Parent = m

	-- Minimal Floating Emoji + Single-Word Difficulty Badge (clears horned hats cleanly)
	local tierInfo = ENEMY_TIERS[biomeId] or ENEMY_TIERS.PineWoods
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(132, 74)
	bb.StudsOffset = Vector3.new(0, 6.4 * guardScale + 1.4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 150
	bb.Parent = root

	local emojiLbl = Instance.new("TextLabel")
	emojiLbl.Size = UDim2.fromScale(1, 0.54)
	emojiLbl.BackgroundTransparency = 1
	emojiLbl.Text = if isBoss then "😈" else tierInfo.emoji
	emojiLbl.TextScaled = true
	emojiLbl.Parent = bb

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 0.44)
	lbl.Position = UDim2.fromScale(0, 0.54)
	lbl.BackgroundTransparency = 1
	lbl.Text = if isBoss then "Boss" else tierInfo.label
	lbl.TextColor3 = if isBoss then Color3.fromRGB(255, 68, 68) else tierInfo.color
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb
	local lblSt = Instance.new("UIStroke")
	lblSt.Thickness = 2.8
	lblSt.Color = Color3.fromRGB(10, 12, 16)
	lblSt.Parent = lbl

	m:SetAttribute("GuardAnimState", "Walk")
	m:SetAttribute("GuardMoveSpeed", 0)
	m:SetAttribute("GuardAttackSeq", 0)
	m:SetAttribute("IsBoss", isBoss)
	m.Parent = parent

	return m, root, hitbox, guardScale, rootYOffset, catchRadius
end

function PoacherAISystem.Init()
	local gw = Workspace:WaitForChild("GameWorld")
	local biomesFolder = gw:WaitForChild("Biomes")
	local sanctuaryHub = gw:FindFirstChild("SanctuaryHub")

	local activeFolder = gw:FindFirstChild("ActivePoachers")
	if activeFolder then activeFolder:Destroy() end
	activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActivePoachers"
	activeFolder.Parent = gw

	local groundFilter: { Instance } = { biomesFolder }
	if sanctuaryHub then
		table.insert(groundFilter, sanctuaryHub)
	end
	local groundRayParams = RaycastParams.new()
	groundRayParams.FilterType = Enum.RaycastFilterType.Include
	groundRayParams.FilterDescendantsInstances = groundFilter
	groundRayParams.RespectCanCollide = true

	local lastCatchTick: { [number]: number } = {}

	local function tryCatchPlayer(ag: PoacherAgent, player: Player, now: number)
		if AdminService.HasGodMode(player) then
			return
		end
		-- Only players actively towing a crate from this enemy's biome can be tackled!
		local towedCount = tonumber(player:GetAttribute("TowedCrateCount")) or 0
		if towedCount <= 0 then
			return
		end
		if not hasAggroInBiome(player.UserId, ag.biomeId) then
			return
		end
		local char = player.Character
		local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if not pRoot or not pRoot:IsA("BasePart") or pRoot.Position.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2 then
			return
		end
		if (now - (lastCatchTick[player.UserId] or 0)) <= 1.1 then
			return
		end
		lastCatchTick[player.UserId] = now

		-- Trigger Net-Staff attack swing across clients
		ag.attackSeq += 1
		ag.model:SetAttribute("GuardAttackSeq", ag.attackSeq)

		local shields = playerShields[player.UserId] or 0
		if shields > 0 then
			local rem = shields - 1
			playerShields[player.UserId] = rem
			player:SetAttribute("ArmorShields", rem)
			Remotes.Get("NotifyClient"):FireClient(player, "Armor Shield absorbed Poacher tackle!", Color3.fromRGB(255, 206, 62))
		else
			local away = Vector3.new(pRoot.Position.X - ag.root.Position.X, 0, pRoot.Position.Z - ag.root.Position.Z)
			if away.Magnitude < 0.1 then
				away = Vector3.new(0, 0, -1)
			else
				away = away.Unit
			end
			local horizSpeed = if ag.isBoss then 118 else 98
			local liftY = if ag.isBoss then 66 else 56
			local knockDir = Vector3.new(away.X * horizSpeed, liftY, (away.Z - 0.35) * horizSpeed)
			player:SetAttribute("StunnedUntil", os.clock() + 1.65)
			Remotes.Get("PlayerKnockback"):FireClient(player, knockDir, 1.55)

			PoacherAISystem.ClearBiomeAggro(player, nil)
			for _, cb in ipairs(onCatchCallbacks) do
				cb(player, pRoot.Position)
			end
			Remotes.Get("NotifyClient"):FireClient(player, ag.model.Name .. " tackled you! Pick up your dropped crate within 50s!", Color3.fromRGB(255, 118, 72))
		end
	end

	local function bindHitboxTouch(ag: PoacherAgent)
		local function onTouch(hit: BasePart)
			local char = hit and hit.Parent
			if not char or not char:IsA("Model") then return end
			local p = Players:GetPlayerFromCharacter(char)
			if p then
				local towedCount = tonumber(p:GetAttribute("TowedCrateCount")) or 0
				if towedCount > 0 and hasAggroInBiome(p.UserId, ag.biomeId) then
					tryCatchPlayer(ag, p, os.clock())
				end
			end
		end
		for _, d in ipairs(ag.model:GetDescendants()) do
			if d:IsA("BasePart") and d.CanTouch then
				d.Touched:Connect(onTouch)
			end
		end
	end

	Remotes.Get("PlayerTouchedPoacher").OnServerEvent:Connect(function(player, poacherName)
		if typeof(poacherName) ~= "string" or AdminService.HasGodMode(player) then
			return
		end
		local towedCount = tonumber(player:GetAttribute("TowedCrateCount")) or 0
		if towedCount <= 0 then
			return
		end
		local char = player.Character
		local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if not pRoot or not pRoot:IsA("BasePart") or pRoot.Position.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2 then
			return
		end
		for _, ag in ipairs(agents) do
			if ag.model.Name == poacherName then
				if hasAggroInBiome(player.UserId, ag.biomeId) then
					local xzDist = Vector2.new(pRoot.Position.X - ag.root.Position.X, pRoot.Position.Z - ag.root.Position.Z).Magnitude
					local dy = math.abs(pRoot.Position.Y - ag.hitbox.Position.Y)
					local maxDy = ag.hitbox.Size.Y * 0.5 + 2.5
					local maxDist = ag.catchRadius + 2.4
					if xzDist <= maxDist and dy <= maxDy then
						tryCatchPlayer(ag, player, os.clock())
					end
				end
				break
			end
		end
	end)

	local function spawnAgent(
		id: string,
		displayName: string,
		biome: Types.BiomeDefinition,
		isBoss: boolean,
		baseSpeed: number,
		startPos: Vector3,
		waypoints: { Vector3 },
		wpIndex: number
	)
		local initY = sampleFloorHeight(groundRayParams, startPos.X, startPos.Z, 0.0)
		local m, root, hitbox, scale, rootYOffset, catchRadius = buildPoacherModel(
			displayName,
			isBoss,
			biome.id,
			if isBoss then Color3.fromRGB(255, 62, 62) else biome.accentColor,
			startPos,
			initY,
			activeFolder
		)
		local ag: PoacherAgent = {
			id = id,
			biomeId = biome.id,
			isBoss = isBoss,
			baseSpeed = baseSpeed,
			recommendedSpeed = biome.recommendedSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = m,
			root = root,
			hitbox = hitbox,
			waypoints = waypoints,
			wpIndex = wpIndex,
			baseScale = scale,
			rootYOffset = rootYOffset,
			groundY = initY,
			catchRadius = catchRadius,
			lastAnimState = "Walk",
			lastQuantSpeed = 0,
			attackSeq = 0,
			groundRayAccum = math.random() * 0.12,
		}
		table.insert(agents, ag)
		bindHitboxTouch(ag)
	end

	for _, biome in ipairs(BiomeConfig) do
		local bFolder = biomesFolder:FindFirstChild(biome.id)
		local patrolFolder = if bFolder then bFolder:FindFirstChild("PoacherPatrol") else nil
		local waypoints: { Vector3 } = {}
		if patrolFolder then
			for _, wp in ipairs(patrolFolder:GetChildren()) do
				if wp:IsA("BasePart") then
					table.insert(waypoints, wp.Position + Vector3.new(0, 1.5, 0))
				end
			end
		end
		if #waypoints == 0 then
			waypoints = {
				Vector3.new(-25, 3, (biome.zStart + biome.zEnd) * 0.5),
				Vector3.new(25, 3, (biome.zStart + biome.zEnd) * 0.5),
			}
		end

		-- Spawn 2 Biome-Scoped Patrol Guards & 1 Biome Boss (5-View Rigged Voxel Guard Series)
		spawnAgent(biome.id .. "_Guard1", biome.id .. " Guard #1", biome, false, biome.poacherSpeed, waypoints[1], waypoints, 2)
		spawnAgent(biome.id .. "_Guard2", biome.id .. " Guard #2", biome, false, biome.poacherSpeed * 1.05, waypoints[#waypoints], waypoints, math.max(1, #waypoints - 1))
		spawnAgent(biome.id .. "_Boss", biome.bossName, biome, true, biome.bossSpeed, waypoints[math.min(3, #waypoints)], waypoints, 1)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local speedMult = AdminService.GetPoacherSpeedMultiplier()

		-- Clear aggro immediately once a fleeing player makes it back inside the Safe Zone OR is no longer carrying crates
		for _, p in ipairs(Players:GetPlayers()) do
			local map = playerBiomeAggro[p.UserId]
			if map and next(map) ~= nil then
				local pChar = p.Character
				local pRoot = if pChar then pChar:FindFirstChild("HumanoidRootPart") else nil
				local inSafe = pRoot and pRoot:IsA("BasePart") and pRoot.Position.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX
				local towedCount = tonumber(p:GetAttribute("TowedCrateCount")) or 0
				if inSafe or towedCount <= 0 then
					PoacherAISystem.ClearBiomeAggro(p, nil)
				end
			end
		end

		for _, ag in ipairs(agents) do
			local currPos = ag.root.Position
			local targetPos = ag.waypoints[ag.wpIndex]
			local chasingPlayer: Player? = nil
			local bestDistSq = math.huge

			-- Find closest thief (ONLY players actively towing crates from THIS enemy's aggroed biome outside Safe Zone)
			for _, candidate in ipairs(Players:GetPlayers()) do
				if not AdminService.HasGodMode(candidate) then
					local towedCount = tonumber(candidate:GetAttribute("TowedCrateCount")) or 0
					if towedCount > 0 and hasAggroInBiome(candidate.UserId, ag.biomeId) then
						local cChar = candidate.Character
						local cHum = if cChar then cChar:FindFirstChildOfClass("Humanoid") else nil
						local cRoot = if cChar then cChar:FindFirstChild("HumanoidRootPart") else nil
						if cHum and cHum.Health > 0 and cRoot and cRoot:IsA("BasePart") and cRoot.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2 then
							local d = (cRoot.Position - currPos)
							local distSq = d.X * d.X + d.Z * d.Z
							if distSq < bestDistSq then
								bestDistSq = distSq
								chasingPlayer = candidate
							end
						end
					end
				end
			end

			if chasingPlayer then
				local pChar = chasingPlayer.Character
				local pRoot = if pChar then pChar:FindFirstChild("HumanoidRootPart") else nil
				if pRoot and pRoot:IsA("BasePart") then
					-- End-to-end chase across ALL zones up to the Safe Zone boundary!
					targetPos = Vector3.new(pRoot.Position.X, 3.5, math.max(GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2, pRoot.Position.Z))
				end
			end

			local delta = Vector3.new(targetPos.X - currPos.X, 0, targetPos.Z - currPos.Z)
			local dist = delta.Magnitude
			local isReturningHome = (not chasingPlayer) and (currPos.Z < ag.zMin - 4 or currPos.Z > ag.zMax + 4)
			local recWalkSpeed = GameConfig.SPEED.BASE_WALK_SPEED + math.log10(1 + math.max(10, ag.recommendedSpeed)) * GameConfig.SPEED.STAT_TO_WALKSPEED_LOG_SCALE
			local alertChaseSpeed = math.max(ag.baseSpeed * 1.15, recWalkSpeed * (if ag.isBoss then 1.24 else 1.10))
			local moveSpeed = if chasingPlayer
				then (alertChaseSpeed * speedMult)
				else (ag.baseSpeed * speedMult * (if isReturningHome then 1.65 else 0.65))
			if chasingPlayer and dist < 16 then
				moveSpeed *= 1.22 -- Close-range tackle lunge
			end

			local movingNow = false
			if dist > 1.5 and moveSpeed > 0.05 then
				movingNow = true
				local step = math.min(dist, moveSpeed * dt)
				local dir = delta.Unit
				local nx = currPos.X + dir.X * step
				local nz = currPos.Z + dir.Z * step

				ag.groundRayAccum += dt
				if ag.groundRayAccum >= 0.12 then
					ag.groundRayAccum = 0
					local targetGroundY = sampleFloorHeight(groundRayParams, nx, nz, ag.groundY)
					ag.groundY = ag.groundY + (targetGroundY - ag.groundY) * math.min(1, dt * 16)
				end

				local groundCF = CFrame.lookAt(Vector3.new(nx, ag.groundY, nz), Vector3.new(nx + dir.X, ag.groundY, nz + dir.Z))
				-- Update ONLY root & hitbox CFrames (never Model:PivotTo each frame so Motor6D limbs animate cleanly on Client!)
				ag.root.CFrame = groundCF * CFrame.new(0, ag.rootYOffset, 0)
				ag.hitbox.CFrame = groundCF * CFrame.new(0, ag.hitbox.Size.Y * 0.5, 0)
			elseif not chasingPlayer then
				ag.wpIndex = (ag.wpIndex % #ag.waypoints) + 1
			end

			local nextState = if chasingPlayer then "Chase" elseif movingNow then "Walk" else "Idle"
			local quantSpeed = math.floor(moveSpeed * 2 + 0.5) * 0.5
			if ag.lastAnimState ~= nextState then
				ag.lastAnimState = nextState
				ag.model:SetAttribute("GuardAnimState", nextState)
			end
			if math.abs(ag.lastQuantSpeed - quantSpeed) >= 0.45 then
				ag.lastQuantSpeed = quantSpeed
				ag.model:SetAttribute("GuardMoveSpeed", quantSpeed)
			end

			-- Direct contact & close-range tackle check (ONLY targets players towing crates AND aggroed in this enemy's biome)
			for _, player in ipairs(Players:GetPlayers()) do
				if not AdminService.HasGodMode(player) then
					local towedCount = tonumber(player:GetAttribute("TowedCrateCount")) or 0
					if towedCount > 0 and hasAggroInBiome(player.UserId, ag.biomeId) then
						local char = player.Character
						local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
						if pRoot and pRoot:IsA("BasePart") and pRoot.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2 then
							local dy = math.abs(pRoot.Position.Y - ag.hitbox.Position.Y)
							local maxDy = ag.hitbox.Size.Y * 0.5 + 2.5
							if dy <= maxDy then
								local localHit = ag.hitbox.CFrame:PointToObjectSpace(pRoot.Position)
								local inBox = math.abs(localHit.X) <= (ag.hitbox.Size.X * 0.5)
									and math.abs(localHit.Z) <= (ag.hitbox.Size.Z * 0.5)
									and math.abs(localHit.Y) <= (ag.hitbox.Size.Y * 0.5 + 0.5)
								local xzDist = Vector2.new(pRoot.Position.X - ag.root.Position.X, pRoot.Position.Z - ag.root.Position.Z).Magnitude
								if inBox or xzDist <= ag.catchRadius then
									tryCatchPlayer(ag, player, now)
								end
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerShields[player.UserId] = nil
		playerBiomeAggro[player.UserId] = nil
		lastCatchTick[player.UserId] = nil
	end)
end

return PoacherAISystem
