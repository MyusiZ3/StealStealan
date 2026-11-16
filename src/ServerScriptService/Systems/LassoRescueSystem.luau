--!strict
-- LassoRescueSystem.luau
-- Server-authoritative Buried Crate Spawner, Lasso Pull (K-Sp Power), Co-op Dual Pull,
-- Velocity-Validated Crate Towing & Delivery, and Admin Crate Rain!

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Types = require(game.ReplicatedStorage.Shared.Types)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local BiomeConfig = require(game.ReplicatedStorage.Config.BiomeConfig)
local LassoConfig = require(game.ReplicatedStorage.Config.LassoConfig)
local VehicleConfig = require(game.ReplicatedStorage.Config.VehicleConfig)
local AnimalConfig = require(game.ReplicatedStorage.Config.AnimalConfig)
local AnimalVisualBuilder = require(game.ReplicatedStorage.Modules.AnimalVisualBuilder)
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.Parent.Services.DataService)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local PassManager = require(script.Parent.Parent.Services.PassManager)
local AdminService = require(script.Parent.Parent.Services.AdminService)
local PoacherAISystem = require(script.Parent.PoacherAISystem)

local LassoRescueSystem = {}

type WorldCrate = {
	id: string,
	biomeId: string,
	rarity: Types.AnimalRarity,
	speciesId: string,
	resistance: number,
	progress: number,
	spawnPos: Vector3,
	model: Model,
	pullers: { [number]: number }, -- userId -> lastTapBoostTime
	isTaken: boolean,
}

type TowedCrateRecord = {
	biomeId: string,
	rarity: Types.AnimalRarity,
	speciesId: string,
	hookedAt: number,
	originPos: Vector3,
	originSpawnPos: Vector3,
	isOnboarding: boolean,
}

type DroppedCrateRecord = {
	id: string,
	rec: TowedCrateRecord,
	model: Model,
	expiresAt: number,
	pickedUp: boolean,
}

local worldCrates: { [string]: WorldCrate } = {}
local droppedCrates: { [string]: DroppedCrateRecord } = {}
local playerPullingCrateId: { [number]: string } = {}
local playerTowedCrates: { [number]: { TowedCrateRecord } } = {}

local function getLassoDef(lassoId: string): Types.LassoDefinition
	for _, l in ipairs(LassoConfig) do
		if l.id == lassoId then return l end
	end
	return LassoConfig[1]
end

local function getVehicleDef(vehicleId: string): Types.VehicleDefinition
	for _, v in ipairs(VehicleConfig) do
		if v.id == vehicleId then return v end
	end
	return VehicleConfig[1]
end

local function getBiomeDef(biomeId: string): Types.BiomeDefinition
	for _, b in ipairs(BiomeConfig) do
		if b.id == biomeId then return b end
	end
	return BiomeConfig[1]
end

local function getTowCapacity(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1 end
	local v = getVehicleDef(profile.equippedVehicle)
	local cap = v.towCapacity
	if PassManager.OwnsPass(player, "DualTowHook") then
		cap += 1
	end
	return cap
end

local function computePlayerPullPower(player: Player): (number, number)
	local profile = DataService.GetProfile(player)
	if not profile then return 150, 16 end
	local lasso = getLassoDef(profile.equippedLasso)
	local power = lasso.pullPower
	if PassManager.OwnsPass(player, "DoublePull") then
		power *= 2
	end
	if profile.zoneIndexBonusesClaimed.MangroveSwamp then
		power *= 1.25
	end
	if profile.zoneIndexBonusesClaimed.AlpinePeaks then
		power *= 1.50
	end
	if profile.zoneIndexBonusesClaimed.VolcanicJungle then
		power *= 2.0
	end
	power *= (1 + profile.rebirths * 0.5)
	power *= (1 + PassManager.GetFriendBoost(player))
	return power, lasso.maxRange
end

local RARITY_RESISTANCE_MULT: { [Types.AnimalRarity]: number } = {
	Common = 1.0,
	Uncommon = 2.2,
	Rare = 5.5,
	Epic = 14.0,
	Legendary = 38.0,
	Mythic = 95.0,
}

local function spawnCrateAt(biomeId: string, spawnPos: Vector3, isOnboarding: boolean, forcedRarity: Types.AnimalRarity?)
	local cratesFolder = Workspace:FindFirstChild("GameWorld") and Workspace.GameWorld:FindFirstChild("ActiveCrates")
	if not cratesFolder then return end

	local biome = getBiomeDef(biomeId)
	local luckMult = PassManager.GetServerLuckMultiplier() * AdminService.GetMutationLuckMultiplier()
	local spec = if isOnboarding
		then (AnimalConfig.GetById("RustyFox") or AnimalConfig.ALL[1])
		else AnimalConfig.RollSpeciesForBiome(biomeId, luckMult)
	local rarity = forcedRarity or spec.rarity
	local resistance = if isOnboarding
		then 180
		else biome.crateBaseResistance * (RARITY_RESISTANCE_MULT[rarity] or 1.0)

	local id = HttpService:GenerateGUID(false)
	local model = AnimalVisualBuilder.BuildBuriedCrate(rarity, biomeId)
	model.Name = "Crate_" .. id
	model:SetAttribute("CrateId", id)
	model:SetAttribute("BiomeId", biomeId)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("Resistance", resistance)
	model:PivotTo(CFrame.new(spawnPos))

	-- Label above buried crate
	local root = model.PrimaryPart :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(170, 56)
	bb.StudsOffset = Vector3.new(0, 5.2, 0)
	bb.MaxDistance = 75
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	lbl.BackgroundTransparency = 0.25
	lbl.Text = string.format("[%s] Trapped Crate\nPower Needed: %s", string.upper(rarity), FormatUtil.Number(resistance))
	lbl.TextColor3 = GameConfig.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LassoPullPrompt"
	prompt.ActionText = "Throw Lasso"
	prompt.ObjectText = string.upper(rarity) .. " Animal Crate"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	model.Parent = cratesFolder

	local rec: WorldCrate = {
		id = id,
		biomeId = biomeId,
		rarity = rarity,
		speciesId = spec.id,
		resistance = resistance,
		progress = 0,
		spawnPos = spawnPos,
		model = model,
		pullers = {},
		isTaken = false,
	}
	worldCrates[id] = rec

	prompt.Triggered:Connect(function(player)
		LassoRescueSystem.StartPull(player, id)
	end)
end

function LassoRescueSystem.StartPull(player: Player, crateId: string)
	local crate = worldCrates[crateId]
	if not crate or crate.isTaken then return end

	local towed = playerTowedCrates[player.UserId] or {}
	if #towed >= getTowCapacity(player) then
		Remotes.Get("NotifyClient"):FireClient(player, "Tow capacity full! Deliver your crate to your Sanctuary Pen!", Color3.fromRGB(255, 196, 62))
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	local _, maxRange = computePlayerPullPower(player)
	local cratePos = (crate.model.PrimaryPart :: BasePart).Position
	if (root.Position - cratePos).Magnitude > maxRange + 8 then
		Remotes.Get("NotifyClient"):FireClient(player, "Move closer to hook your Lasso!", Color3.fromRGB(255, 196, 62))
		return
	end

	playerPullingCrateId[player.UserId] = crateId
	crate.pullers[player.UserId] = 0
	Remotes.Get("PullProgressSync"):FireClient(player, {
		active = true,
		crateId = crateId,
		progress = crate.progress,
		rarity = crate.rarity,
		cratePos = cratePos,
	})
end

function LassoRescueSystem.CancelPull(player: Player)
	local cid = playerPullingCrateId[player.UserId]
	if cid and worldCrates[cid] then
		worldCrates[cid].pullers[player.UserId] = nil
	end
	playerPullingCrateId[player.UserId] = nil
	Remotes.Get("PullProgressSync"):FireClient(player, { active = false })
end

function LassoRescueSystem.CompletePull(crate: WorldCrate)
	crate.isTaken = true
	local cratePos = (crate.model.PrimaryPart :: BasePart).Position
	local isOnboard = (crate.spawnPos - Vector3.new(10, 0.25, 174)).Magnitude < 6
	local assignedAny = false

	for uid, _ in pairs(crate.pullers) do
		local player = Players:GetPlayerByUserId(uid)
		playerPullingCrateId[uid] = nil
		if player then
			Remotes.Get("PullProgressSync"):FireClient(player, { active = false, completed = true })
			local list = playerTowedCrates[uid] or {}
			if #list < getTowCapacity(player) then
				assignedAny = true
				table.insert(list, {
					biomeId = crate.biomeId,
					rarity = crate.rarity,
					speciesId = crate.speciesId,
					hookedAt = os.clock(),
					originPos = cratePos,
					originSpawnPos = crate.spawnPos,
					isOnboarding = isOnboard,
				})
				playerTowedCrates[uid] = list
				player:SetAttribute("TowedCrateCount", #list)
				PoacherAISystem.TriggerBiomeAggro(crate.biomeId, player)
				Remotes.Get("NotifyClient"):FireClient(player, "CRATE PULLED! Escape to your Sanctuary Pen!", Color3.fromRGB(255, 214, 62))
			end
		end
	end

	local respawnPos = crate.spawnPos
	local biomeId = crate.biomeId
	crate.model:Destroy()
	worldCrates[crate.id] = nil

	if not assignedAny then
		task.delay(if isOnboard then 5 else 12, function()
			spawnCrateAt(biomeId, respawnPos, isOnboard, nil)
		end)
	end
end

function LassoRescueSystem.DropPlayerCrates(player: Player, dropOrigin: Vector3)
	local list = playerTowedCrates[player.UserId]
	if not list or #list == 0 then
		return
	end
	playerTowedCrates[player.UserId] = {}
	player:SetAttribute("TowedCrateCount", 0)

	local cratesFolder = Workspace:FindFirstChild("GameWorld") and Workspace.GameWorld:FindFirstChild("ActiveCrates")
	if not cratesFolder then
		return
	end

	for idx, rec in ipairs(list) do
		local angle = (idx - 1) * 1.4
		local dropX = math.clamp(dropOrigin.X + math.cos(angle) * 5, -85, 85)
		local dropZ = math.max(GameConfig.WORLD.SAFE_ZONE_Z_MAX + 8, dropOrigin.Z + math.sin(angle) * 5)
		local dropPos = Vector3.new(dropX, 1.4, dropZ)

		local dropId = HttpService:GenerateGUID(false)
		local model = AnimalVisualBuilder.BuildBuriedCrate(rec.rarity, rec.biomeId)
		model.Name = "DroppedCrate_" .. dropId
		model:PivotTo(CFrame.new(dropPos))

		local root = model.PrimaryPart :: BasePart
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(180, 60)
		bb.StudsOffset = Vector3.new(0, 5.4, 0)
		bb.MaxDistance = 90
		bb.Parent = root

		local lbl = Instance.new("TextLabel")
		lbl.Name = "CountdownLabel"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundColor3 = Color3.fromRGB(24, 18, 22)
		lbl.BackgroundTransparency = 0.2
		lbl.Text = string.format("[%s] Dropped Crate\nReturning in: 50s", string.upper(rec.rarity))
		lbl.TextColor3 = Color3.fromRGB(255, 214, 72)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb
		Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PickupDroppedCratePrompt"
		prompt.ActionText = "Pick Up Crate"
		prompt.ObjectText = string.upper(rec.rarity) .. " Animal Crate"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = root

		model.Parent = cratesFolder

		local dRec: DroppedCrateRecord = {
			id = dropId,
			rec = rec,
			model = model,
			expiresAt = os.time() + 50,
			pickedUp = false,
		}
		droppedCrates[dropId] = dRec

		prompt.Triggered:Connect(function(picker: Player)
			if dRec.pickedUp or not droppedCrates[dropId] then
				return
			end
			local pList = playerTowedCrates[picker.UserId] or {}
			if #pList >= getTowCapacity(picker) then
				Remotes.Get("NotifyClient"):FireClient(picker, "Tow capacity full! Deliver your crate first!", Color3.fromRGB(255, 196, 62))
				return
			end
			dRec.pickedUp = true
			droppedCrates[dropId] = nil
			model:Destroy()

			-- Refresh hookedAt timestamp for anti-teleport check on pickup
			rec.hookedAt = os.clock()
			rec.originPos = dropPos
			table.insert(pList, rec)
			playerTowedCrates[picker.UserId] = pList
			picker:SetAttribute("TowedCrateCount", #pList)
			PoacherAISystem.TriggerBiomeAggro(rec.biomeId, picker)
			Remotes.Get("NotifyClient"):FireClient(picker, "Picked up crate! Run to your Sanctuary Pen!", Color3.fromRGB(84, 245, 148))
		end)

		-- 50s Countdown Loop (only active while crate is unheld on the ground)
		task.spawn(function()
			while not dRec.pickedUp and droppedCrates[dropId] do
				local rem = dRec.expiresAt - os.time()
				if rem <= 0 then
					droppedCrates[dropId] = nil
					if model.Parent then
						model:Destroy()
					end
					-- Return crate to its original biome spawn position
					spawnCrateAt(rec.biomeId, rec.originSpawnPos, rec.isOnboarding, rec.rarity)
					break
				end
				if lbl.Parent then
					lbl.Text = string.format("[%s] Dropped Crate\nReturning in: %ds", string.upper(rec.rarity), rem)
					lbl.TextColor3 = if rem <= 10 then Color3.fromRGB(255, 84, 84) else Color3.fromRGB(255, 214, 72)
				end
				task.wait(1)
			end
		end)
	end
end

function LassoRescueSystem.TryDeliverToPen(player: Player)
	local list = playerTowedCrates[player.UserId]
	if not list or #list == 0 then return end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	-- Velocity / Anti-Teleport envelope check
	local now = os.clock()
	local profile = DataService.GetProfile(player)
	local maxAllowedSpeed = GameConfig.SPEED.MAX_EFFECTIVE_WALKSPEED * GameConfig.SPEED.ANTI_TELEPORT_TOLERANCE
	if player:GetAttribute("AdminSuperSpeed") then
		maxAllowedSpeed = 99999
	end

	local first = list[1]
	local dt = math.max(0.5, now - first.hookedAt)
	local dist = (root.Position - first.originPos).Magnitude
	if (dist / dt) > maxAllowedSpeed and not AdminService.HasInstantPull(player) then
		-- Reset crate cleanly instead of rewarding teleportation
		playerTowedCrates[player.UserId] = {}
		player:SetAttribute("TowedCrateCount", 0)
		Remotes.Get("NotifyClient"):FireClient(player, "Delivery rejected (movement speed anomaly)!", Color3.fromRGB(255, 84, 84))
		return
	end

	for _, rec in ipairs(list) do
		PlotService.AddPendingCrate(player, rec.biomeId, rec.rarity, rec.speciesId)
		task.delay(if rec.isOnboarding then 5 else 12, function()
			spawnCrateAt(rec.biomeId, rec.originSpawnPos, rec.isOnboarding, nil)
		end)
	end
	local deliveredCount = #list
	playerTowedCrates[player.UserId] = {}
	player:SetAttribute("TowedCrateCount", 0)
	Remotes.Get("PoacherAlertSync"):FireClient(player, false, "")
	Remotes.Get("CrateDelivered"):FireClient(player, deliveredCount)
	Remotes.Get("NotifyClient"):FireClient(player, string.format("Delivered %d crate(s) to your Sanctuary Pen!", deliveredCount), Color3.fromRGB(84, 245, 148))
	if profile and profile.analyticsMeta.onboardingStep == 0 then
		profile.analyticsMeta.onboardingStep = 1
	end
end

function LassoRescueSystem.SpawnCrateRain()
	local rarities: { Types.AnimalRarity } = { "Epic", "Legendary", "Mythic" }
	for _, biome in ipairs(BiomeConfig) do
		for i = 1, 5 do
			local rx = math.random(-55, 55)
			local rz = math.random(biome.zStart + 25, biome.zEnd - 25)
			local rar = rarities[math.random(1, #rarities)]
			spawnCrateAt(biome.id, Vector3.new(rx, 0.2, rz), false, rar)
		end
	end
end

function LassoRescueSystem.Init()
	local gw = Workspace:WaitForChild("GameWorld")
	local cratesFolder = gw:FindFirstChild("ActiveCrates")
	if cratesFolder then cratesFolder:Destroy() end
	cratesFolder = Instance.new("Folder")
	cratesFolder.Name = "ActiveCrates"
	cratesFolder.Parent = gw

	AdminService.RegisterCrateRainCallback(LassoRescueSystem.SpawnCrateRain)

	-- Spawn initial buried crates across all 5 Biomes
	local biomesFolder = gw:WaitForChild("Biomes")
	for _, biome in ipairs(BiomeConfig) do
		local bModel = biomesFolder:FindFirstChild(biome.id)
		local spawns = if bModel then bModel:FindFirstChild("CrateSpawns") else nil
		if spawns then
			for _, sp in ipairs(spawns:GetChildren()) do
				if sp:IsA("BasePart") then
					local isOnboard = sp:GetAttribute("IsOnboarding") == true
					spawnCrateAt(biome.id, sp.Position, isOnboard, nil)
				end
			end
		end
	end

	PoacherAISystem.OnPlayerCaught(function(player, catchPos)
		LassoRescueSystem.CancelPull(player)
		LassoRescueSystem.DropPlayerCrates(player, catchPos)
	end)

	Remotes.Get("RequestStartPull").OnServerEvent:Connect(function(player, crateId)
		if typeof(crateId) == "string" then
			LassoRescueSystem.StartPull(player, crateId)
		end
	end)

	Remotes.Get("RequestCancelPull").OnServerEvent:Connect(function(player)
		LassoRescueSystem.CancelPull(player)
	end)

	Remotes.Get("LassoTapBoost").OnServerEvent:Connect(function(player)
		local cid = playerPullingCrateId[player.UserId]
		if not cid then return end
		local crate = worldCrates[cid]
		if not crate then return end
		local now = os.clock()
		local lastTap = crate.pullers[player.UserId] or 0
		if now - lastTap >= 0.25 then
			crate.pullers[player.UserId] = now
			crate.progress = math.min(1, crate.progress + 0.08)
		end
	end)

	Remotes.Get("DeliverCrateToPen").OnServerEvent:Connect(function(player)
		LassoRescueSystem.TryDeliverToPen(player)
	end)

	-- Server-authoritative Pull Progress Tick + Auto-Deliver inside Safe Zone
	RunService.Heartbeat:Connect(function(dt: number)
		local resMult = AdminService.GetResistanceMultiplier()

		for _, crate in pairs(worldCrates) do
			if not crate.isTaken then
				local totalPower = 0
				local pullerCount = 0
				local validPullers: { Player } = {}

				for uid, _ in pairs(crate.pullers) do
					local p = Players:GetPlayerByUserId(uid)
					local char = if p then p.Character else nil
					local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
					local cRoot = crate.model.PrimaryPart
					if p and root and root:IsA("BasePart") and cRoot then
						local pwr, maxR = computePlayerPullPower(p)
						if (root.Position - cRoot.Position).Magnitude <= maxR + 10 then
							totalPower += pwr
							pullerCount += 1
							table.insert(validPullers, p)
						else
							LassoRescueSystem.CancelPull(p)
						end
					elseif p then
						LassoRescueSystem.CancelPull(p)
					end
				end

				if pullerCount > 0 then
					if pullerCount > 1 then
						totalPower *= 1.25 -- Co-op Dual Lasso bonus
					end
					local effectiveResistance = math.max(1, crate.resistance * resMult)
					local rate = totalPower / effectiveResistance
					for _, p in ipairs(validPullers) do
						if AdminService.HasInstantPull(p) then
							rate = 10
							break
						end
					end
					crate.progress = math.min(1, crate.progress + math.max(0.18, rate) * dt)

					-- Lift crate visually out of the ground as it's pulled
					local liftY = crate.progress * 2.4
					crate.model:PivotTo(CFrame.new(crate.spawnPos + Vector3.new(0, liftY, 0)))

					for _, p in ipairs(validPullers) do
						Remotes.Get("PullProgressSync"):FireClient(p, {
							active = true,
							crateId = crate.id,
							progress = crate.progress,
							rarity = crate.rarity,
							cratePos = (crate.model.PrimaryPart :: BasePart).Position,
						})
					end

					if crate.progress >= 1 then
						LassoRescueSystem.CompletePull(crate)
					end
				end
			end
		end

		-- Auto-deliver when carrying crates into player's Sanctuary Plot or Safe Zone entrance
		for uid, list in pairs(playerTowedCrates) do
			if #list > 0 then
				local p = Players:GetPlayerByUserId(uid)
				local char = if p then p.Character else nil
				local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
				if p and root and root:IsA("BasePart") and root.Position.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX - 8 then
					local plotIdx = PlotService.GetPlayerPlotIndex(p)
					local plotModel = if plotIdx then PlotService.GetPlotModel(plotIdx) else nil
					local unboxPad = if plotModel then plotModel:FindFirstChild("CrateUnboxPad") else nil
					if unboxPad and unboxPad:IsA("BasePart") and (root.Position - unboxPad.Position).Magnitude <= 26 then
						LassoRescueSystem.TryDeliverToPen(p)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		LassoRescueSystem.CancelPull(player)
		local list = playerTowedCrates[player.UserId]
		if list then
			for _, rec in ipairs(list) do
				spawnCrateAt(rec.biomeId, rec.originSpawnPos, rec.isOnboarding, nil)
			end
		end
		playerTowedCrates[player.UserId] = nil
	end)
end

return LassoRescueSystem
