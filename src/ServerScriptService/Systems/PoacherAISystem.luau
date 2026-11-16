--!strict
-- PoacherAISystem.luau
-- Manages Biome Poachers & Bosses: Waypoint Patrol, Aggro Pursuit on Crate Pull, Safe-Zone Boundary, & Shield/GodMode checks

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
	aggroTarget: Player?,
	aggroUntil: number,
	baseScale: number,
}

local agents: { PoacherAgent } = {}
local playerShields: { [number]: number } = {}
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
	local now = os.clock()
	for _, ag in ipairs(agents) do
		if ag.biomeId == biomeId then
			ag.aggroTarget = player
			ag.aggroUntil = now + 22
		end
	end
	Remotes.Get("PoacherAlertSync"):FireClient(player, true, biomeId)
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

		-- Spawn 1 Patrol Guard & 1 Biome Boss
		local guardM, guardRoot, gScale = buildPoacherModel(biome.id .. " Guard", false, biome.accentColor, waypoints[1], activeFolder)
		table.insert(agents, {
			id = biome.id .. "_Guard",
			biomeId = biome.id,
			isBoss = false,
			baseSpeed = biome.poacherSpeed,
			zMin = biome.zStart + 8,
			zMax = biome.zEnd - 8,
			model = guardM,
			root = guardRoot,
			waypoints = waypoints,
			wpIndex = 2,
			aggroTarget = nil,
			aggroUntil = 0,
			baseScale = gScale,
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
			aggroTarget = nil,
			aggroUntil = 0,
			baseScale = bScale,
		})
	end

	local lastCatchTick: { [number]: number } = {}

	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local speedMult = AdminService.GetPoacherSpeedMultiplier()

		for _, ag in ipairs(agents) do
			local targetPos = ag.waypoints[ag.wpIndex]
			local chasingPlayer: Player? = nil

			if ag.aggroTarget and now < ag.aggroUntil and ag.aggroTarget.Parent == Players then
				local pChar = ag.aggroTarget.Character
				local pRoot = if pChar then pChar:FindFirstChild("HumanoidRootPart") else nil
				if pRoot and pRoot:IsA("BasePart") then
					if pRoot.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX + 4 and not AdminService.HasGodMode(ag.aggroTarget) then
						chasingPlayer = ag.aggroTarget
						targetPos = Vector3.new(pRoot.Position.X, 3.5, math.clamp(pRoot.Position.Z, ag.zMin, ag.zMax))
					else
						ag.aggroTarget = nil
						Remotes.Get("PoacherAlertSync"):FireClient(ag.aggroTarget, false, ag.biomeId)
					end
				end
			else
				ag.aggroTarget = nil
			end

			local currPos = ag.root.Position
			local delta = Vector3.new(targetPos.X - currPos.X, 0, targetPos.Z - currPos.Z)
			local dist = delta.Magnitude
			local moveSpeed = ag.baseSpeed * speedMult * (if chasingPlayer then 1.0 else 0.65)

			if dist > 1.5 then
				local step = math.min(dist, moveSpeed * dt)
				local dir = delta.Unit
				local nextPos = Vector3.new(currPos.X + dir.X * step, 3.2 * ag.baseScale, currPos.Z + dir.Z * step)
				local lookCF = CFrame.lookAt(nextPos, nextPos + dir)
				ag.model:PivotTo(lookCF)
			elseif not chasingPlayer then
				ag.wpIndex = (ag.wpIndex % #ag.waypoints) + 1
			end

			-- Horizontal XZ-plane hit detection (immune to jumping/noclip float exploits)
			for _, player in ipairs(Players:GetPlayers()) do
				if not AdminService.HasGodMode(player) then
					local char = player.Character
					local pRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
					if pRoot and pRoot:IsA("BasePart") and pRoot.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX + 6 then
						local xzDist = Vector2.new(pRoot.Position.X - ag.root.Position.X, pRoot.Position.Z - ag.root.Position.Z).Magnitude
						local catchRadius = if ag.isBoss then 7.2 else 5.4
						if xzDist <= catchRadius and (now - (lastCatchTick[player.UserId] or 0)) > 2.5 then
							lastCatchTick[player.UserId] = now
							local shields = playerShields[player.UserId] or 0
							if shields > 0 then
								playerShields[player.UserId] = shields - 1
								Remotes.Get("NotifyClient"):FireClient(player, "Armor Shield absorbed Poacher tackle!", Color3.fromRGB(255, 206, 62))
							else
								-- Knockback / Ragdoll at impact spot (NO teleport to Safe Zone!) & drop carried crates
								local away = Vector3.new(pRoot.Position.X - ag.root.Position.X, 0, pRoot.Position.Z - ag.root.Position.Z)
								if away.Magnitude < 0.1 then
									away = Vector3.new(0, 0, -1)
								else
									away = away.Unit
								end
								local knockDir = Vector3.new(away.X * 68, 36, (away.Z - 0.35) * 68)
								player:SetAttribute("StunnedUntil", os.clock() + 1.5)
								Remotes.Get("PlayerKnockback"):FireClient(player, knockDir, 1.4)

								ag.aggroTarget = nil
								Remotes.Get("PoacherAlertSync"):FireClient(player, false, ag.biomeId)
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
end

return PoacherAISystem
