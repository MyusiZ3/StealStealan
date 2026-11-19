--!strict
-- PoacherAISystem.luau
-- Manages Biome Poachers & Bosses: Waypoint Patrol, Biome-Scoped End-to-End Chase to Safe Zone, & Shield/GodMode checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local VehicleConfig = require(ReplicatedStorage.Config.VehicleConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
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

local function buildPoacherModel(name: string, isBoss: boolean, biomeId: string, accentColor: Color3, pos: Vector3, parent: Instance): (Model, Part, Part, number)
	local ca = ReplicatedStorage:FindFirstChild("CuratedAssets")
	local heroSrc = if ca then ca:FindFirstChild("Hero_PoacherBoss") else nil

	local m = Instance.new("Model")
	m.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	local scale = if isBoss then 1.6 else 1.05
	root.Size = Vector3.new(3.5 * scale, 5.5 * scale, 3.5 * scale)
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.CFrame = CFrame.new(pos)
	root.Parent = m
	m.PrimaryPart = root

	local hitbox = Instance.new("Part")
	hitbox.Name = "HitboxTrigger"
	hitbox.Shape = Enum.PartType.Block
	hitbox.Size = if isBoss then Vector3.new(5.6 * scale, 7.2 * scale, 5.6 * scale) else Vector3.new(3.6 * scale, 5.2 * scale, 3.6 * scale)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = true
	hitbox.CanQuery = true
	hitbox.CFrame = CFrame.new(pos)
	hitbox:SetAttribute("PoacherBiomeId", biomeId)
	hitbox:SetAttribute("IsBoss", isBoss)
	hitbox.Parent = m

	if heroSrc and heroSrc:IsA("Model") then
		local clone = heroSrc:Clone()
		pcall(function()
			clone:ScaleTo(clone:GetScale() * scale)
		end)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = true
			elseif d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		clone:PivotTo(CFrame.new(pos))
		clone.Parent = m
	else
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3 * scale, 4.5 * scale, 2.2 * scale)
		body.Color = if isBoss then Color3.fromRGB(168, 36, 36) else accentColor
		body.Anchored = true
		body.CanCollide = false
		body.CanTouch = true
		body.CFrame = CFrame.new(pos)
		body.Parent = m
	end

	-- Minimal Floating Emoji + Single-Word Difficulty Badge (Image 10 style — no box background!)
	local tierInfo = ENEMY_TIERS[biomeId] or ENEMY_TIERS.PineWoods
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(132, 74)
	bb.StudsOffset = Vector3.new(0, 4.8 * scale + 1.2, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
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

	m.Parent = parent
	return m, root, hitbox, scale
end

function PoacherAISystem.Init()
	local gw = Workspace:WaitForChild("GameWorld")
	local biomesFolder = gw:WaitForChild("Biomes")

	local activeFolder = gw:FindFirstChild("ActivePoachers")
	if activeFolder then activeFolder:Destroy() end
	activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActivePoachers"
	activeFolder.Parent = gw

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
					local dy = math.abs(pRoot.Position.Y - ag.root.Position.Y)
					local maxDist = if ag.isBoss then 7.5 else 5.8
					if xzDist <= maxDist and dy <= 7.0 then
						tryCatchPlayer(ag, player, os.clock())
					end
				end
				break
			end
		end
	end)

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

		-- Spawn 2 Biome-Scoped Patrol Guards & 1 Biome Boss
		local guard1M, guard1Root, guard1Hitbox, g1Scale = buildPoacherModel(biome.id .. " Guard #1", false, biome.id, biome.accentColor, waypoints[1], activeFolder)
		local ag1: PoacherAgent = {
			id = biome.id .. "_Guard1",
			biomeId = biome.id,
			isBoss = false,
			baseSpeed = biome.poacherSpeed,
			recommendedSpeed = biome.recommendedSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = guard1M,
			root = guard1Root,
			hitbox = guard1Hitbox,
			waypoints = waypoints,
			wpIndex = 2,
			baseScale = g1Scale,
		}
		table.insert(agents, ag1)
		bindHitboxTouch(ag1)

		local g2Start = waypoints[#waypoints]
		local guard2M, guard2Root, guard2Hitbox, g2Scale = buildPoacherModel(biome.id .. " Guard #2", false, biome.id, biome.accentColor, g2Start, activeFolder)
		local ag2: PoacherAgent = {
			id = biome.id .. "_Guard2",
			biomeId = biome.id,
			isBoss = false,
			baseSpeed = biome.poacherSpeed * 1.05,
			recommendedSpeed = biome.recommendedSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = guard2M,
			root = guard2Root,
			hitbox = guard2Hitbox,
			waypoints = waypoints,
			wpIndex = math.max(1, #waypoints - 1),
			baseScale = g2Scale,
		}
		table.insert(agents, ag2)
		bindHitboxTouch(ag2)

		local bossPos = waypoints[math.min(3, #waypoints)]
		local bossM, bossRoot, bossHitbox, bScale = buildPoacherModel(biome.bossName, true, biome.id, Color3.fromRGB(255, 62, 62), bossPos, activeFolder)
		local agBoss: PoacherAgent = {
			id = biome.id .. "_Boss",
			biomeId = biome.id,
			isBoss = true,
			baseSpeed = biome.bossSpeed,
			recommendedSpeed = biome.recommendedSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = bossM,
			root = bossRoot,
			hitbox = bossHitbox,
			waypoints = waypoints,
			wpIndex = 1,
			baseScale = bScale,
		}
		table.insert(agents, agBoss)
		bindHitboxTouch(agBoss)
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

			if dist > 1.5 then
				local step = math.min(dist, moveSpeed * dt)
				local dir = delta.Unit
				local nextPos = Vector3.new(currPos.X + dir.X * step, 3.2 * ag.baseScale, currPos.Z + dir.Z * step)
				local lookCF = CFrame.lookAt(nextPos, nextPos + dir)
				ag.model:PivotTo(lookCF)
			elseif not chasingPlayer then
				ag.wpIndex = (ag.wpIndex % #ag.waypoints) + 1
			end

			-- Direct contact & close-range tackle check (ONLY targets players towing crates AND aggroed in this enemy's biome)
			for _, player in ipairs(Players:GetPlayers()) do
				if not AdminService.HasGodMode(player) then
					local towedCount = tonumber(player:GetAttribute("TowedCrateCount")) or 0
					if towedCount > 0 and hasAggroInBiome(player.UserId, ag.biomeId) then
						local char = player.Character
						local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
						if pRoot and pRoot:IsA("BasePart") and pRoot.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2 then
							local dy = math.abs(pRoot.Position.Y - ag.root.Position.Y)
							if dy <= 6.0 then
								local localHit = ag.hitbox.CFrame:PointToObjectSpace(pRoot.Position)
								local inBox = math.abs(localHit.X) <= (ag.hitbox.Size.X * 0.5)
									and math.abs(localHit.Z) <= (ag.hitbox.Size.Z * 0.5)
									and math.abs(localHit.Y) <= (ag.hitbox.Size.Y * 0.5 + 0.5)
								local xzDist = Vector2.new(pRoot.Position.X - ag.root.Position.X, pRoot.Position.Z - ag.root.Position.Z).Magnitude
								local catchRadius = if ag.isBoss then 4.8 else 3.4
								if inBox or xzDist <= catchRadius then
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
