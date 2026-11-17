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
	zMin: number,
	zMax: number,
	model: Model,
	root: Part,
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
end

function PoacherAISystem.TriggerBiomeAggro(biomeId: string, player: Player)
	local uid = player.UserId
	playerBiomeAggro[uid] = playerBiomeAggro[uid] or {}
	playerBiomeAggro[uid][biomeId] = true
	Remotes.Get("PoacherAlertSync"):FireClient(player, true, biomeId)
end

function PoacherAISystem.ClearBiomeAggro(player: Player, biomeId: string?)
	local uid = player.UserId
	local map = playerBiomeAggro[uid]
	if not map then
		Remotes.Get("PoacherAlertSync"):FireClient(player, false, "")
		return
	end
	if biomeId then
		map[biomeId] = nil
	else
		table.clear(map)
	end
	local hasAny = next(map) ~= nil
	if not hasAny then
		Remotes.Get("PoacherAlertSync"):FireClient(player, false, "")
	end
end

local function hasAggroInBiome(userId: number, biomeId: string): boolean
	local map = playerBiomeAggro[userId]
	return map ~= nil and map[biomeId] == true
end

local function buildPoacherModel(name: string, isBoss: boolean, accentColor: Color3, pos: Vector3, parent: Instance): (Model, Part, number)
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
	root.Transparency = 1
	root.CFrame = CFrame.new(pos)
	root.Parent = m
	m.PrimaryPart = root

	if heroSrc and heroSrc:IsA("Model") then
		local clone = heroSrc:Clone()
		pcall(function()
			clone:ScaleTo(clone:GetScale() * scale)
		end)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
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
		body.CFrame = CFrame.new(pos)
		body.Parent = m
	end

	-- Overhead Nameplate
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 44)
	bb.StudsOffset = Vector3.new(0, 4.5 * scale, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(24, 18, 22)
	lbl.BackgroundTransparency = 0.25
	lbl.Text = if isBoss then ("BOSS: " .. name) else ("Poacher: " .. name)
	lbl.TextColor3 = if isBoss then Color3.fromRGB(255, 86, 86) else Color3.fromRGB(255, 206, 84)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb

	m.Parent = parent
	return m, root, scale
end

function PoacherAISystem.Init()
	local gw = Workspace:WaitForChild("GameWorld")
	local biomesFolder = gw:WaitForChild("Biomes")

	local activeFolder = gw:FindFirstChild("ActivePoachers")
	if activeFolder then activeFolder:Destroy() end
	activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActivePoachers"
	activeFolder.Parent = gw

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
		local guard1M, guard1Root, g1Scale = buildPoacherModel(biome.id .. " Guard #1", false, biome.accentColor, waypoints[1], activeFolder)
		table.insert(agents, {
			id = biome.id .. "_Guard1",
			biomeId = biome.id,
			isBoss = false,
			baseSpeed = biome.poacherSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = guard1M,
			root = guard1Root,
			waypoints = waypoints,
			wpIndex = 2,
			baseScale = g1Scale,
		})

		local g2Start = waypoints[#waypoints]
		local guard2M, guard2Root, g2Scale = buildPoacherModel(biome.id .. " Guard #2", false, biome.accentColor, g2Start, activeFolder)
		table.insert(agents, {
			id = biome.id .. "_Guard2",
			biomeId = biome.id,
			isBoss = false,
			baseSpeed = biome.poacherSpeed * 1.05,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = guard2M,
			root = guard2Root,
			waypoints = waypoints,
			wpIndex = math.max(1, #waypoints - 1),
			baseScale = g2Scale,
		})

		local bossPos = waypoints[math.min(3, #waypoints)]
		local bossM, bossRoot, bScale = buildPoacherModel(biome.bossName, true, Color3.fromRGB(255, 62, 62), bossPos, activeFolder)
		table.insert(agents, {
			id = biome.id .. "_Boss",
			biomeId = biome.id,
			isBoss = true,
			baseSpeed = biome.bossSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = bossM,
			root = bossRoot,
			waypoints = waypoints,
			wpIndex = 1,
			baseScale = bScale,
		})
	end

	local lastCatchTick: { [number]: number } = {}

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local speedMult = AdminService.GetPoacherSpeedMultiplier()

		-- Clear aggro immediately once a fleeing player makes it back inside the Safe Zone
		for _, p in ipairs(Players:GetPlayers()) do
			local map = playerBiomeAggro[p.UserId]
			if map and next(map) ~= nil then
				local pChar = p.Character
				local pRoot = if pChar then pChar:FindFirstChild("HumanoidRootPart") else nil
				if pRoot and pRoot:IsA("BasePart") and pRoot.Position.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX then
					PoacherAISystem.ClearBiomeAggro(p, nil)
				end
			end
		end

		for _, ag in ipairs(agents) do
			local currPos = ag.root.Position
			local targetPos = ag.waypoints[ag.wpIndex]
			local chasingPlayer: Player? = nil
			local bestDistSq = math.huge

			-- Find closest thief who stole from THIS agent's biome and is outside Safe Zone
			for _, candidate in ipairs(Players:GetPlayers()) do
				if hasAggroInBiome(candidate.UserId, ag.biomeId) and not AdminService.HasGodMode(candidate) then
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
			local moveSpeed = ag.baseSpeed * speedMult * (if chasingPlayer then 1.0 elseif isReturningHome then 1.65 else 0.65)

			if dist > 1.5 then
				local step = math.min(dist, moveSpeed * dt)
				local dir = delta.Unit
				local nextPos = Vector3.new(currPos.X + dir.X * step, 3.2 * ag.baseScale, currPos.Z + dir.Z * step)
				local lookCF = CFrame.lookAt(nextPos, nextPos + dir)
				ag.model:PivotTo(lookCF)
			elseif not chasingPlayer then
				ag.wpIndex = (ag.wpIndex % #ag.waypoints) + 1
			end

			-- Horizontal XZ-plane hit detection scoped strictly to players aggroed on THIS biome
			for _, player in ipairs(Players:GetPlayers()) do
				if hasAggroInBiome(player.UserId, ag.biomeId) and not AdminService.HasGodMode(player) then
					local char = player.Character
					local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
					if pRoot and pRoot:IsA("BasePart") and pRoot.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX + 3 then
						local xzDist = Vector2.new(pRoot.Position.X - ag.root.Position.X, pRoot.Position.Z - ag.root.Position.Z).Magnitude
						local catchRadius = if ag.isBoss then 7.2 else 5.4
						if xzDist <= catchRadius and (now - (lastCatchTick[player.UserId] or 0)) > 2.5 then
							lastCatchTick[player.UserId] = now
							local shields = playerShields[player.UserId] or 0
							if shields > 0 then
								playerShields[player.UserId] = shields - 1
								Remotes.Get("NotifyClient"):FireClient(player, "Armor Shield absorbed Poacher tackle!", Color3.fromRGB(255, 206, 62))
							else
								local away = Vector3.new(pRoot.Position.X - ag.root.Position.X, 0, pRoot.Position.Z - ag.root.Position.Z)
								if away.Magnitude < 0.1 then
									away = Vector3.new(0, 0, -1)
								else
									away = away.Unit
								end
								local knockDir = Vector3.new(away.X * 68, 36, (away.Z - 0.35) * 68)
								player:SetAttribute("StunnedUntil", os.clock() + 1.5)
								Remotes.Get("PlayerKnockback"):FireClient(player, knockDir, 1.4)

								PoacherAISystem.ClearBiomeAggro(player, nil)
								for _, cb in ipairs(onCatchCallbacks) do
									cb(player, pRoot.Position)
								end
								Remotes.Get("NotifyClient"):FireClient(player, ag.model.Name .. " tackled you! Pick up your dropped crate within 50s!", Color3.fromRGB(255, 118, 72))
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
