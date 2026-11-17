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
	sizeScale: number,
	resistance: number,
	progress: number,
	spawnPos: Vector3,
	model: Model,
	billboardLabel: TextLabel,
	lassoPrompt: ProximityPrompt,
	grabPrompt: ProximityPrompt,
	pullers: { [number]: number }, -- userId -> lastTapBoostTime
	isExtracted: boolean,
	extractedAt: number?,
	isTaken: boolean,
}

type TowedCrateRecord = {
	worldToken: string,
	biomeId: string,
	rarity: Types.AnimalRarity,
	speciesId: string,
	sizeScale: number,
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
local claimedWorldTokens: { [string]: boolean } = {}
local deliveringUsers: { [number]: boolean } = {}

local function syncPlayerTowAttributes(player: Player)
	local list = playerTowedCrates[player.UserId] or {}
	player:SetAttribute("TowedCrateCount", #list)
	local visualList = {}
	for _, rec in ipairs(list) do
		table.insert(visualList, {
			b = rec.biomeId,
			r = rec.rarity,
			s = rec.sizeScale,
		})
	end
	player:SetAttribute("TowedCratesJson", HttpService:JSONEncode(visualList))
end

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
	local sizeScale = GameConfig.ComputeCrateScale(rarity)
	local resistance = if isOnboarding
		then 180
		else biome.crateBaseResistance * (RARITY_RESISTANCE_MULT[rarity] or 1.0)

	local id = HttpService:GenerateGUID(false)
	local model = AnimalVisualBuilder.BuildBuriedCrate(rarity, biomeId, sizeScale)
	model.Name = "Crate_" .. id
	model:SetAttribute("CrateId", id)
	model:SetAttribute("BiomeId", biomeId)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("SizeScale", sizeScale)
	model:SetAttribute("Resistance", resistance)
	model:PivotTo(CFrame.new(spawnPos))

	-- Floating transparent label above crate (NO dark box background, NO Power Needed text!)
	local root = model.PrimaryPart :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(190, 44)
	bb.StudsOffset = Vector3.new(0, 4.4 * sizeScale + 1.1, 0)
	bb.MaxDistance = 75
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.format("[%s] Trapped Crate", string.upper(rarity))
	lbl.TextColor3 = GameConfig.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb
	local lblStroke = Instance.new("UIStroke")
	lblStroke.Thickness = 2.6
	lblStroke.Color = Color3.fromRGB(10, 12, 16)
	lblStroke.Parent = lbl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LassoPullPrompt"
	prompt.ActionText = "Throw Lasso"
	prompt.ObjectText = string.upper(rarity) .. " Animal Crate"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local grabPrompt = Instance.new("ProximityPrompt")
	grabPrompt.Name = "GrabCratePrompt"
	grabPrompt.ActionText = "Grab Crate"
	grabPrompt.ObjectText = string.upper(rarity) .. " Animal Crate"
	grabPrompt.HoldDuration = 0
	grabPrompt.MaxActivationDistance = 15
	grabPrompt.RequiresLineOfSight = false
	grabPrompt.ClickablePrompt = true
	grabPrompt.Enabled = false
	grabPrompt.Parent = root

	model.Parent = cratesFolder

	local rec: WorldCrate = {
		id = id,
		biomeId = biomeId,
		rarity = rarity,
		speciesId = spec.id,
		sizeScale = sizeScale,
		resistance = resistance,
		progress = 0,
		spawnPos = spawnPos,
		model = model,
		billboardLabel = lbl,
		lassoPrompt = prompt,
		grabPrompt = grabPrompt,
		pullers = {},
		isExtracted = false,
		extractedAt = nil,
		isTaken = false,
	}
	worldCrates[id] = rec

	prompt.Triggered:Connect(function(player)
		LassoRescueSystem.StartPull(player, id)
	end)
	grabPrompt.Triggered:Connect(function(player)
		LassoRescueSystem.GrabExtractedCrate(player, id)
	end)
end

function LassoRescueSystem.StartPull(player: Player, crateId: string)
	local crate = worldCrates[crateId]
	if not crate or crate.isTaken or crate.isExtracted then return end

	local towed = playerTowedCrates[player.UserId] or {}
	if #towed >= getTowCapacity(player) then
		Remotes.Get("NotifyClient"):FireClient(player, "Hands full! Cross into Safe Zone to bank crates into Inventory!", Color3.fromRGB(255, 196, 62))
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
	if crate.isExtracted or crate.isTaken then
		return
	end
	crate.isExtracted = true
	crate.extractedAt = os.clock()

	for uid, _ in pairs(crate.pullers) do
		local player = Players:GetPlayerByUserId(uid)
		playerPullingCrateId[uid] = nil
		if player then
			Remotes.Get("PullProgressSync"):FireClient(player, { active = false, completed = true, crateId = crate.id })
			Remotes.Get("NotifyClient"):FireClient(player, "Crate freed! Press [E] to Grab it into your hands!", Color3.fromRGB(108, 255, 132))
		end
	end
	table.clear(crate.pullers)

	-- Lift upright cleanly above ground and enable [E] Grab prompt
	local uprightPos = crate.spawnPos + Vector3.new(0, 1.8 * crate.sizeScale, 0)
	crate.model:PivotTo(CFrame.new(uprightPos))
	crate.lassoPrompt.Enabled = false
	crate.grabPrompt.Enabled = true
	crate.billboardLabel.Text = string.format("[%s] Grab Crate [E]", string.upper(crate.rarity))
	crate.billboardLabel.TextColor3 = Color3.fromRGB(108, 255, 132)
end

function LassoRescueSystem.GrabExtractedCrate(player: Player, crateId: string)
	local crate = worldCrates[crateId]
	if not crate or crate.isTaken or not crate.isExtracted then
		return
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local cRoot = crate.model.PrimaryPart
	if not root or not root:IsA("BasePart") or not cRoot or not cRoot:IsA("BasePart") then
		return
	end
	if (root.Position - cRoot.Position).Magnitude > 22 then
		Remotes.Get("NotifyClient"):FireClient(player, "Move closer to grab the crate!", Color3.fromRGB(255, 196, 62))
		return
	end

	local uid = player.UserId
	local list = playerTowedCrates[uid] or {}
	if #list >= getTowCapacity(player) then
		Remotes.Get("NotifyClient"):FireClient(player, "Hands full! Cross into Safe Zone to bank crates into Inventory!", Color3.fromRGB(255, 196, 62))
		return
	end

	-- Mark taken & remove from worldCrates atomically BEFORE inserting into playerTowedCrates
	crate.isTaken = true
	worldCrates[crate.id] = nil
	local isOnboard = (crate.spawnPos - Vector3.new(10, 0.25, 174)).Magnitude < 6
	table.insert(list, {
		worldToken = crate.id,
		biomeId = crate.biomeId,
		rarity = crate.rarity,
		speciesId = crate.speciesId,
		sizeScale = crate.sizeScale,
		hookedAt = os.clock(),
		originPos = cRoot.Position,
		originSpawnPos = crate.spawnPos,
		isOnboarding = isOnboard,
	})
	playerTowedCrates[uid] = list
	syncPlayerTowAttributes(player)
	PoacherAISystem.TriggerBiomeAggro(crate.biomeId, player)
	Remotes.Get("NotifyClient"):FireClient(player, "GRABBED CRATE! Run back to Safe Zone to store in Inventory!", Color3.fromRGB(255, 214, 62))

	crate.model:Destroy()
end

function LassoRescueSystem.DropPlayerCrates(player: Player, dropOrigin: Vector3)
	local list = playerTowedCrates[player.UserId]
	if not list or #list == 0 then
		return
	end
	playerTowedCrates[player.UserId] = {}
	syncPlayerTowAttributes(player)

	local cratesFolder = Workspace:FindFirstChild("GameWorld") and Workspace.GameWorld:FindFirstChild("ActiveCrates")
	if not cratesFolder then
		return
	end

	for idx, rec in ipairs(list) do
		local angle = (idx - 1) * 1.4
		local dropX = math.clamp(dropOrigin.X + math.cos(angle) * 4, -85, 85)
		local dropZ = math.max(GameConfig.WORLD.SAFE_ZONE_Z_MAX + 2, dropOrigin.Z + math.sin(angle) * 4)
		local dropPos = Vector3.new(dropX, 1.4, dropZ)

		local dropId = HttpService:GenerateGUID(false)
		local model = AnimalVisualBuilder.BuildBuriedCrate(rec.rarity, rec.biomeId, rec.sizeScale)
		model.Name = "DroppedCrate_" .. dropId
		model:PivotTo(CFrame.new(dropPos))

		local root = model.PrimaryPart :: BasePart
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(180, 60)
		bb.StudsOffset = Vector3.new(0, 4.5 * rec.sizeScale + 1.2, 0)
		bb.MaxDistance = 90
		bb.Parent = root

		local lbl = Instance.new("TextLabel")
		lbl.Name = "CountdownLabel"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("[%s] Dropped Crate\nReturning in: 50s", string.upper(rec.rarity))
		lbl.TextColor3 = Color3.fromRGB(255, 214, 72)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb
		local dropSt = Instance.new("UIStroke")
		dropSt.Thickness = 2.6
		dropSt.Color = Color3.fromRGB(10, 12, 16)
		dropSt.Parent = lbl

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
			local pChar = picker.Character
			local pHum = if pChar then pChar:FindFirstChildOfClass("Humanoid") else nil
			if not pHum or pHum.Health <= 0 or pHum.PlatformStand then
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
			syncPlayerTowAttributes(picker)
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
	local uid = player.UserId
	if deliveringUsers[uid] then return end
	local list = playerTowedCrates[uid]
	if not list or #list == 0 then return end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	-- Atomically detach towed list FIRST so Heartbeat + Prompt can never double-deliver
	deliveringUsers[uid] = true
	playerTowedCrates[uid] = {}
	syncPlayerTowAttributes(player)

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
		deliveringUsers[uid] = nil
		Remotes.Get("NotifyClient"):FireClient(player, "Delivery rejected (movement speed anomaly)!", Color3.fromRGB(255, 84, 84))
		return
	end

	local remaining: { TowedCrateRecord } = {}
	local deliveredCount = 0
	for _, rec in ipairs(list) do
		if not claimedWorldTokens[rec.worldToken] then
			claimedWorldTokens[rec.worldToken] = true
			local cUid = PlotService.AddCrateToInventory(player, rec.biomeId, rec.rarity, rec.speciesId, rec.sizeScale, {
				originSource = "Wild",
			})
			if cUid then
				deliveredCount += 1
				task.delay(if rec.isOnboarding then 5 else 12, function()
					spawnCrateAt(rec.biomeId, rec.originSpawnPos, rec.isOnboarding, nil)
				end)
			else
				claimedWorldTokens[rec.worldToken] = nil
				table.insert(remaining, rec)
			end
		end
	end
	if #remaining > 0 then
		playerTowedCrates[uid] = remaining
		syncPlayerTowAttributes(player)
	end
	deliveringUsers[uid] = nil
	if deliveredCount > 0 then
		PoacherAISystem.ClearBiomeAggro(player, nil)
		Remotes.Get("CrateDelivered"):FireClient(player, deliveredCount)
		Remotes.Get("NotifyClient"):FireClient(player, string.format("Stored %d crate(s) in your Backpack/Hotbar! Grab more or place inside your Pen!", deliveredCount), Color3.fromRGB(84, 245, 148))
		if profile and profile.analyticsMeta.onboardingStep == 0 then
			profile.analyticsMeta.onboardingStep = 1
		end
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
	PlotService.RegisterPenDropHandler(LassoRescueSystem.TryDeliverToPen)

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

	Remotes.Get("GrabExtractedCrate").OnServerEvent:Connect(function(player, crateId)
		if typeof(crateId) == "string" then
			LassoRescueSystem.GrabExtractedCrate(player, crateId)
		end
	end)

	Remotes.Get("DropCarriedCrate").OnServerEvent:Connect(function(player)
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local dropOrigin = if root and root:IsA("BasePart") then root.Position else Vector3.new(0, 1.5, GameConfig.WORLD.SAFE_ZONE_Z_MAX + 6)
		LassoRescueSystem.DropPlayerCrates(player, dropOrigin)
		PoacherAISystem.ClearBiomeAggro(player, nil)
		Remotes.Get("NotifyClient"):FireClient(player, "Dropped carried crate(s)!", Color3.fromRGB(255, 214, 72))
	end)

	Remotes.Get("DeliverCrateToPen").OnServerEvent:Connect(function(player)
		LassoRescueSystem.TryDeliverToPen(player)
	end)

	-- Server-authoritative Pull Progress Tick + Auto-Bank into Inventory on Safe Zone Crossing
	RunService.Heartbeat:Connect(function(dt: number)
		local resMult = AdminService.GetResistanceMultiplier()
		local nowClk = os.clock()

		for _, crate in pairs(worldCrates) do
			if crate.isExtracted and not crate.isTaken and crate.extractedAt and (nowClk - crate.extractedAt) > 35 then
				-- Reset ungrabbed crate cleanly back into trapped state
				crate.isExtracted = false
				crate.extractedAt = nil
				crate.progress = 0
				crate.model:PivotTo(CFrame.new(crate.spawnPos))
				crate.lassoPrompt.Enabled = true
				crate.grabPrompt.Enabled = false
				crate.billboardLabel.Text = string.format("[%s] Trapped Crate", string.upper(crate.rarity))
				crate.billboardLabel.TextColor3 = GameConfig.RARITY_COLORS[crate.rarity] or Color3.new(1, 1, 1)
			elseif not crate.isTaken and not crate.isExtracted then
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

		-- Auto-store carried crates directly into Backpack/Inventory as soon as player crosses into Safe Zone!
		for uid, list in pairs(playerTowedCrates) do
			if #list > 0 then
				local p = Players:GetPlayerByUserId(uid)
				local char = if p then p.Character else nil
				local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
				if p and root and root:IsA("BasePart") and root.Position.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX - 2 then
					LassoRescueSystem.TryDeliverToPen(p)
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
