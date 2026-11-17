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
	crateTitle: string,
	variantIdx: number,
	sizeScale: number,
	resistance: number,
	progress: number,
	spawnPos: Vector3,
	model: Model,
	billboardLabel: TextLabel,
	lassoPrompt: ProximityPrompt,
	grabPrompt: ProximityPrompt,
	pullers: { [number]: number }, -- userId -> lastTapBoostTime
	pullStartedAt: number?,
	hadPeakProgress: boolean?,
	isExtracted: boolean,
	extractedAt: number?,
	isTaken: boolean,
}

type TowedCrateRecord = {
	worldToken: string,
	biomeId: string,
	rarity: Types.AnimalRarity,
	speciesId: string,
	variantIdx: number,
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
local wavePhase: "OPEN" | "RESETTING" = "OPEN"
local waveEndsAt = os.time() + 300
local waveTotalSec = 300

local BIOME_ZONE_NAMES: { [string]: string } = {
	PineWoods = "Pine Wood Zone",
	MangroveSwamp = "Swamp Zone",
	SavannaCamp = "Savanna Zone",
	AlpinePeaks = "Alpine Zone",
	VolcanicJungle = "Volcanic Zone",
}

local RARITY_ANNOUNCE_ICON: { [Types.AnimalRarity]: string } = {
	Common = "📦",
	Uncommon = "📦",
	Rare = "💠",
	Epic = "💎",
	Legendary = "🔥",
	Mythic = "🌟",
}

local function announceCrateSpawn(rarity: Types.AnimalRarity, crateTitle: string, biomeId: string)
	local zoneName = BIOME_ZONE_NAMES[biomeId] or biomeId
	local icon = RARITY_ANNOUNCE_ICON[rarity] or "📦"
	local col = GameConfig.RARITY_COLORS[rarity] or Color3.fromRGB(255, 224, 92)
	local msg = string.format("%s %s Crate (%s) spawned in %s!", icon, rarity, crateTitle, zoneName)
	Remotes.Get("CrateSpawnAnnounce"):FireAllClients({
		message = msg,
		rarity = rarity,
		crateTitle = crateTitle,
		biomeId = biomeId,
		zoneName = zoneName,
		color = col,
	})
end

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

local function spawnCrateAt(biomeId: string, spawnPos: Vector3, isOnboarding: boolean, forcedRarity: Types.AnimalRarity?, announceSpawn: boolean?): WorldCrate?
	local cratesFolder = Workspace:FindFirstChild("GameWorld") and Workspace.GameWorld:FindFirstChild("ActiveCrates")
	if not cratesFolder then return nil end

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
	local variantIdx = (spec.indexNumber % 3) + 1
	local crateTitle = AnimalVisualBuilder.GetCrateVariantInfo(biomeId, rarity, variantIdx)
	local model = AnimalVisualBuilder.BuildBuriedCrate(rarity, biomeId, sizeScale, variantIdx)
	model.Name = "Crate_" .. id
	model:SetAttribute("CrateId", id)
	model:SetAttribute("BiomeId", biomeId)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("CrateTitle", crateTitle)
	model:SetAttribute("CrateVariant", variantIdx)
	model:SetAttribute("SizeScale", sizeScale)
	model:SetAttribute("Resistance", resistance)
	model:PivotTo(CFrame.new(spawnPos))

	-- Clean 2-Line Floating Crate Label (Image 11 style: Crate Name top + Rarity bottom, NO dark box!)
	local root = model.PrimaryPart :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(185, 52)
	bb.StudsOffset = Vector3.new(0, 4.4 * sizeScale + 1.1, 0)
	bb.MaxDistance = 85
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 0.52)
	lbl.BackgroundTransparency = 1
	lbl.Text = crateTitle
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb
	local lblStroke = Instance.new("UIStroke")
	lblStroke.Thickness = 2.6
	lblStroke.Color = Color3.fromRGB(10, 12, 16)
	lblStroke.Parent = lbl

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Size = UDim2.fromScale(1, 0.44)
	rarityLbl.Position = UDim2.fromScale(0, 0.52)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text = rarity
	rarityLbl.TextColor3 = GameConfig.RARITY_COLORS[rarity] or Color3.new(1, 1, 1)
	rarityLbl.Font = Enum.Font.FredokaOne
	rarityLbl.TextScaled = true
	rarityLbl.Parent = bb
	local rarStroke = Instance.new("UIStroke")
	rarStroke.Thickness = 2.4
	rarStroke.Color = Color3.fromRGB(10, 12, 16)
	rarStroke.Parent = rarityLbl

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
		crateTitle = crateTitle,
		variantIdx = variantIdx,
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
	if announceSpawn then
		announceCrateSpawn(rarity, crateTitle, biomeId)
	end
	return rec
end

function LassoRescueSystem.StartPull(player: Player, crateId: string)
	if wavePhase ~= "OPEN" then
		Remotes.Get("NotifyClient"):FireClient(player, "Biome gate is resetting! Please wait.", Color3.fromRGB(255, 196, 62))
		return
	end
	local crate = worldCrates[crateId]
	if not crate or crate.isTaken or crate.isExtracted then return end

	local towed = playerTowedCrates[player.UserId] or {}
	if #towed >= getTowCapacity(player) then
		Remotes.Get("NotifyClient"):FireClient(player, "Hands full! Cross into Safe Zone first!", Color3.fromRGB(255, 196, 62))
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

	local now = os.clock()
	playerPullingCrateId[player.UserId] = crateId
	crate.pullers[player.UserId] = now
	if not crate.pullStartedAt then
		crate.pullStartedAt = now
	end
	Remotes.Get("PullProgressSync"):FireClient(player, {
		active = true,
		crateId = crateId,
		progress = crate.progress,
		rarity = crate.rarity,
		tooWeak = false,
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
	crate.billboardLabel.Text = "✨ Grab! [E]"
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
		variantIdx = crate.variantIdx,
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
		local model = AnimalVisualBuilder.BuildBuriedCrate(rec.rarity, rec.biomeId, rec.sizeScale, rec.variantIdx)
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
					-- Return crate to its original biome spawn position if current wave is still open
					if wavePhase == "OPEN" then
						spawnCrateAt(rec.biomeId, rec.originSpawnPos, rec.isOnboarding, rec.rarity, true)
					end
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
	local lastDeliveredUid: string? = nil
	for _, rec in ipairs(list) do
		if not claimedWorldTokens[rec.worldToken] then
			claimedWorldTokens[rec.worldToken] = true
			local cUid = PlotService.AddCrateToInventory(player, rec.biomeId, rec.rarity, rec.speciesId, rec.sizeScale, {
				originSource = "Wild",
			})
			if cUid then
				deliveredCount += 1
				lastDeliveredUid = cUid
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
		Remotes.Get("CrateDelivered"):FireClient(player, deliveredCount, lastDeliveredUid)
		if profile and profile.analyticsMeta.onboardingStep == 0 then
			profile.analyticsMeta.onboardingStep = 1
		end
	end
end

local RARITY_WAVE_POINTS: { [Types.AnimalRarity]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 4,
	Epic = 7,
	Legendary = 11,
	Mythic = 16,
}

local CRATES_PER_BIOME_WAVE: { [string]: number } = {
	PineWoods = 12,
	MangroveSwamp = 11,
	SavannaCamp = 11,
	AlpinePeaks = 11,
	VolcanicJungle = 11,
}

local biomeGroundRayParams = RaycastParams.new()
biomeGroundRayParams.FilterType = Enum.RaycastFilterType.Include

local function updateStartGateVisuals(isClosed: boolean, remainingSec: number)
	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local gate = if hub then hub:FindFirstChild("SanctuaryExitGate") else nil
	if not gate then return end

	local barrier = gate:FindFirstChild("BiomeResetBarrier") :: Part?
	if not barrier then
		local p = Instance.new("Part")
		p.Name = "BiomeResetBarrier"
		p.Size = Vector3.new(260, 28, 3)
		p.CFrame = CFrame.new(0, 14, 148)
		p.Color = Color3.fromRGB(255, 64, 64)
		p.Material = Enum.Material.ForceField
		p.Anchored = true
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = gate
		barrier = p
	end
	if barrier then
		barrier.CanCollide = isClosed
		barrier.Transparency = if isClosed then 0.42 else 1
	end

	local banner = gate:FindFirstChild("GateBanner")
	if banner then
		local timeStr = FormatUtil.Time(math.max(0, remainingSec))
		for _, d in ipairs(banner:GetChildren()) do
			if d:IsA("SurfaceGui") then
				if d.Name == "Sign_Front" or (d.Face == Enum.NormalId.Front) then
					d.Enabled = true
					for _, child in ipairs(d:GetDescendants()) do
						if child:IsA("TextLabel") then
							if child.LayoutOrder == 1 or string.find(child.Text, "SAFE") or string.find(child.Text, "GATE") or string.find(child.Text, "LEAVING") then
								child.Text = if isClosed then "🔒 GATE CLOSED" else "🟢 GATE OPEN ->"
							else
								child.Text = if isClosed then ("Spawning New Animals: " .. timeStr) else ("Biome Reset In: " .. timeStr)
							end
						end
					end
				end
			end
		end
	end
end

local function sampleBiomeCrateGroundPos(biome: Types.BiomeDefinition, zMinOverride: number?, zMaxOverride: number?): Vector3
	local gw = Workspace:FindFirstChild("GameWorld")
	local biomesFolder = if gw then gw:FindFirstChild("Biomes") else nil
	local bFolder = if biomesFolder then biomesFolder:FindFirstChild(biome.id) else nil
	local blocky = if bFolder then bFolder:FindFirstChild("BlockyTerrain") else nil

	local rx = if math.random() < 0.5 then math.random(-66, -12) else math.random(12, 66)
	local zLo = math.floor(zMinOverride or (biome.zStart + 22))
	local zHi = math.ceil(zMaxOverride or (biome.zEnd - 22))
	if zHi < zLo then
		zHi = zLo
	end
	local rz = math.random(zLo, zHi)

	local targets: { Instance } = { Workspace.Terrain }
	if blocky then
		table.insert(targets, blocky)
	elseif bFolder then
		table.insert(targets, bFolder)
	end
	biomeGroundRayParams.FilterDescendantsInstances = targets
	local hit = Workspace:Raycast(Vector3.new(rx, 45, rz), Vector3.new(0, -80, 0), biomeGroundRayParams)
	local y = if hit then hit.Position.Y else 0.15
	return Vector3.new(rx, y + 0.1, rz)
end

local function clearFieldCratesForReset()
	for uid, crate in pairs(worldCrates) do
		if crate.model and crate.model.Parent then
			crate.model:Destroy()
		end
		worldCrates[uid] = nil
	end
	for uid, _ in pairs(playerPullingCrateId) do
		local p = Players:GetPlayerByUserId(uid)
		playerPullingCrateId[uid] = nil
		if p then
			Remotes.Get("PullProgressSync"):FireClient(p, { active = false })
		end
	end
	for id, dRec in pairs(droppedCrates) do
		dRec.pickedUp = true
		if dRec.model and dRec.model.Parent then
			dRec.model:Destroy()
		end
		droppedCrates[id] = nil
	end
end

local function spawnSingleBiomeWaveBatch(biome: Types.BiomeDefinition, announceHighlights: boolean?): number
	local count = CRATES_PER_BIOME_WAVE[biome.id] or 10
	local spawned: { WorldCrate } = {}
	local totalRarityScore = 0
	for i = 1, count do
		local isOnboard = (biome.id == "PineWoods" and i == 1)
		local pos = if isOnboard
			then sampleBiomeCrateGroundPos(biome, 166, 200)
			else sampleBiomeCrateGroundPos(biome)
		local rec = spawnCrateAt(biome.id, pos, isOnboard, nil, false)
		if rec then
			table.insert(spawned, rec)
		end
	end
	if announceHighlights and #spawned > 0 then
		table.sort(spawned, function(a, b)
			return (RARITY_WAVE_POINTS[a.rarity] or 1) > (RARITY_WAVE_POINTS[b.rarity] or 1)
		end)
		announceCrateSpawn(spawned[1].rarity, spawned[1].crateTitle, biome.id)
		if spawned[2] and (RARITY_WAVE_POINTS[spawned[2].rarity] or 1) >= (RARITY_WAVE_POINTS.Epic or 7) then
			announceCrateSpawn(spawned[2].rarity, spawned[2].crateTitle, biome.id)
		end
	end
	for _, crate in pairs(worldCrates) do
		if crate.biomeId == biome.id then
			totalRarityScore += RARITY_WAVE_POINTS[crate.rarity] or 1
		end
	end
	return totalRarityScore
end

local function computeWaveOpenSeconds(): number
	local sum = 0
	local count = 0
	for _, crate in pairs(worldCrates) do
		sum += RARITY_WAVE_POINTS[crate.rarity] or 1
		count += 1
	end
	local avg = if count > 0 then (sum / count) else 1.5
	local t = math.clamp((avg - 1.2) / 3.4, 0, 1)
	return math.round(240 + t * 240) -- 4:00 to 8:00 scaled dynamically by accumulated rarity!
end

local function broadcastWaveState()
	local rem = math.max(0, waveEndsAt - os.time())
	updateStartGateVisuals(wavePhase == "RESETTING", rem)
	Remotes.Get("BiomeWaveSync"):FireAllClients({
		phase = wavePhase,
		remainingSec = rem,
		totalSec = waveTotalSec,
		endsAt = waveEndsAt,
	})
end

function LassoRescueSystem.SpawnCrateRain()
	local rarities: { Types.AnimalRarity } = { "Epic", "Legendary", "Mythic" }
	for _, biome in ipairs(BiomeConfig) do
		local best: WorldCrate? = nil
		for i = 1, 5 do
			local pos = sampleBiomeCrateGroundPos(biome)
			local rar = rarities[math.random(1, #rarities)]
			local rec = spawnCrateAt(biome.id, pos, false, rar, false)
			if rec and (not best or (RARITY_WAVE_POINTS[rec.rarity] or 1) > (RARITY_WAVE_POINTS[best.rarity] or 1)) then
				best = rec
			end
		end
		if best then
			announceCrateSpawn(best.rarity, best.crateTitle, biome.id)
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

	-- Initial random biome-scoped crate wave
	for _, biome in ipairs(BiomeConfig) do
		spawnSingleBiomeWaveBatch(biome)
	end
	wavePhase = "OPEN"
	waveTotalSec = computeWaveOpenSeconds()
	waveEndsAt = os.time() + waveTotalSec
	broadcastWaveState()

	Players.PlayerAdded:Connect(function(p)
		task.delay(1.0, function()
			if p.Parent then
				Remotes.Get("BiomeWaveSync"):FireClient(p, {
					phase = wavePhase,
					remainingSec = math.max(0, waveEndsAt - os.time()),
					totalSec = waveTotalSec,
					endsAt = waveEndsAt,
				})
			end
		end)
	end)

	-- Autonomous 4-8m Open Window & 20-40s Gate-Closed Random Respawn Wave Loop + Live Random Crate Spawns
	local nextLiveSpawnAt = os.clock() + 18
	local firstJoinAnnounced = false
	task.spawn(function()
		while true do
			task.wait(1)
			local rem = waveEndsAt - os.time()
			if wavePhase == "OPEN" then
				-- On first wave after first player finishes loading, spawn or announce one fresh wild crate soon
				if not firstJoinAnnounced and #Players:GetPlayers() > 0 then
					firstJoinAnnounced = true
					nextLiveSpawnAt = math.min(nextLiveSpawnAt, os.clock() + 8)
				end
				if rem > 15 and os.clock() >= nextLiveSpawnAt then
					nextLiveSpawnAt = os.clock() + math.random(22, 35)
					local countsByBiome: { [string]: number } = {}
					local totalActive = 0
					for _, wc in pairs(worldCrates) do
						countsByBiome[wc.biomeId] = (countsByBiome[wc.biomeId] or 0) + 1
						totalActive += 1
					end
					local candidates: { Types.BiomeDefinition } = {}
					for _, b in ipairs(BiomeConfig) do
						local cur = countsByBiome[b.id] or 0
						local target = CRATES_PER_BIOME_WAVE[b.id] or 10
						if cur < target then
							table.insert(candidates, b)
						end
					end
					if #candidates == 0 and totalActive < 64 then
						for _, b in ipairs(BiomeConfig) do
							local cur = countsByBiome[b.id] or 0
							local target = CRATES_PER_BIOME_WAVE[b.id] or 10
							if cur < target + 2 then
								table.insert(candidates, b)
							end
						end
					end
					if #candidates > 0 then
						local picked = candidates[math.random(1, #candidates)]
						local pos = sampleBiomeCrateGroundPos(picked)
						spawnCrateAt(picked.id, pos, false, nil, true)
					end
				end

				if rem <= 0 then
					local resetDur = math.random(20, 40)
					wavePhase = "RESETTING"
					waveTotalSec = resetDur
					waveEndsAt = os.time() + resetDur
					broadcastWaveState()

					Remotes.Get("GlobalEventBanner"):FireAllClients(
						string.format("🔒 BIOME GATE CLOSED! Spawning new animals (%ds)...", resetDur),
						Color3.fromRGB(255, 96, 84),
						resetDur
					)

					-- Safely bring players back inside Safe Zone (banking carried crates!) & clear old field crates
					for _, p in ipairs(Players:GetPlayers()) do
						LassoRescueSystem.CancelPull(p)
						if playerTowedCrates[p.UserId] and #playerTowedCrates[p.UserId] > 0 then
							LassoRescueSystem.TryDeliverToPen(p)
						end
						PoacherAISystem.ClearBiomeAggro(p, nil)
						local char = p.Character
						local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
						if hrp and hrp:IsA("BasePart") and hrp.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX - 2 then
							hrp.CFrame = CFrame.new(math.random(-8, 8), 4.5, 134)
							Remotes.Get("NotifyClient"):FireClient(p, "Gate closed for biome reset! Returning to Safe Zone...", Color3.fromRGB(255, 206, 62))
						end
					end

					clearFieldCratesForReset()
					-- Stagger random spawn smoothly across the 20-40s closure window before reopening gate
					local stepWait = math.max(1.2, (resetDur - 6) / #BiomeConfig)
					for _, biome in ipairs(BiomeConfig) do
						task.wait(stepWait)
						spawnSingleBiomeWaveBatch(biome, true)
					end
				else
					broadcastWaveState()
				end
			else
				-- Guard Safe Zone boundary while RESETTING
				for _, p in ipairs(Players:GetPlayers()) do
					local char = p.Character
					local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
					if hrp and hrp:IsA("BasePart") and hrp.Position.Z > GameConfig.WORLD.SAFE_ZONE_Z_MAX - 1 then
						hrp.CFrame = CFrame.new(math.clamp(hrp.Position.X, -80, 80), 4.5, 138)
					end
				end

				if rem <= 0 then
					local openSec = computeWaveOpenSeconds()
					wavePhase = "OPEN"
					waveTotalSec = openSec
					waveEndsAt = os.time() + openSec
					nextLiveSpawnAt = os.clock() + math.random(22, 35)
					broadcastWaveState()
					Remotes.Get("GlobalEventBanner"):FireAllClients(
						string.format("🟢 BIOME GATE OPEN! New animals spawned (Reset in %s)!", FormatUtil.Time(openSec)),
						Color3.fromRGB(88, 255, 132),
						8
					)
				else
					broadcastWaveState()
				end
			end
		end
	end)

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
		if not crate or crate.isExtracted or crate.isTaken then return end
		local now = os.clock()
		local lastTap = crate.pullers[player.UserId] or 0
		if now - lastTap >= 0.08 then
			crate.pullers[player.UserId] = now
			if not crate.pullStartedAt then
				crate.pullStartedAt = now
			end
			local pwr, _ = computePlayerPullPower(player)
			local effRes = math.max(1, crate.resistance * AdminService.GetResistanceMultiplier())
			local ratio = pwr / effRes
			local tapGain = if AdminService.HasInstantPull(player)
				then 1.0
				elseif ratio >= 0.45 then math.clamp(0.11 + math.min(ratio, 3.0) * 0.05, 0.11, 0.25)
				else math.clamp(0.025 + ratio * 0.08, 0.025, 0.06)
			crate.progress = math.min(1, crate.progress + tapGain)
			if crate.progress >= 0.05 then
				crate.hadPeakProgress = true
			end
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

	-- Server-authoritative Tug-of-War Pull Tick (Tap to gain, slips & fails if Lasso is too weak!)
	RunService.Heartbeat:Connect(function(dt: number)
		local resMult = AdminService.GetResistanceMultiplier()
		local nowClk = os.clock()

		for _, crate in pairs(worldCrates) do
			if crate.isExtracted and not crate.isTaken and crate.extractedAt and (nowClk - crate.extractedAt) > 35 then
				crate.isExtracted = false
				crate.extractedAt = nil
				crate.progress = 0
				crate.pullStartedAt = nil
				crate.hadPeakProgress = false
				crate.model:PivotTo(CFrame.new(crate.spawnPos))
				crate.lassoPrompt.Enabled = true
				crate.grabPrompt.Enabled = false
				crate.billboardLabel.Text = crate.crateTitle
				crate.billboardLabel.TextColor3 = Color3.new(1, 1, 1)
			elseif not crate.isTaken and not crate.isExtracted then
				local totalPower = 0
				local pullerCount = 0
				local latestTap = 0
				local validPullers: { Player } = {}

				for uid, tapTime in pairs(crate.pullers) do
					local p = Players:GetPlayerByUserId(uid)
					local char = if p then p.Character else nil
					local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
					local cRoot = crate.model.PrimaryPart
					if p and root and root:IsA("BasePart") and cRoot then
						local pwr, maxR = computePlayerPullPower(p)
						if (root.Position - cRoot.Position).Magnitude <= maxR + 10 then
							totalPower += pwr
							pullerCount += 1
							if tapTime > latestTap then latestTap = tapTime end
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
					if not crate.pullStartedAt then
						crate.pullStartedAt = nowClk
					end
					local effectiveResistance = math.max(1, crate.resistance * resMult)
					local ratio = totalPower / effectiveResistance
					local hasInstant = false
					for _, p in ipairs(validPullers) do
						if AdminService.HasInstantPull(p) then
							hasInstant = true
							crate.progress = 1
							break
						end
					end

					local isTooWeak = (not hasInstant) and (ratio < 0.45)
					if not hasInstant then
						local idleAfterTap = nowClk - math.max(latestTap, crate.pullStartedAt or nowClk)
						if isTooWeak then
							if idleAfterTap > 0.14 or crate.progress > 0 then
								local drainRate = math.clamp(0.28 + (0.45 - ratio) * 0.48, 0.28, 0.56)
								crate.progress = math.max(0, crate.progress - drainRate * dt)
							end
						elseif idleAfterTap > 0.25 and crate.progress > 0 then
							crate.progress = math.max(0, crate.progress - 0.15 * dt)
						end
					end

					local elapsed = nowClk - (crate.pullStartedAt or nowClk)
					local timedOutTooWeak = isTooWeak and elapsed >= 4.2 and crate.progress < 0.99
					local slippedToZero = crate.hadPeakProgress and crate.progress <= 0.005 and elapsed >= 1.2
					local abandonedEmpty = elapsed >= 5.5 and crate.progress <= 0.01

					if timedOutTooWeak or slippedToZero or abandonedEmpty then
						-- Fail tug-of-war: progress drops, rope snaps back!
						crate.progress = 0
						crate.pullStartedAt = nil
						crate.hadPeakProgress = false
						crate.model:PivotTo(CFrame.new(crate.spawnPos))
						for _, p in ipairs(validPullers) do
							playerPullingCrateId[p.UserId] = nil
							crate.pullers[p.UserId] = nil
							Remotes.Get("PullProgressSync"):FireClient(p, {
								active = false,
								failed = true,
								tooWeak = isTooWeak,
							})
							Remotes.Get("NotifyClient"):FireClient(
								p,
								if isTooWeak then "Lasso too weak! Progress slipped — Upgrade your Lasso!" else "Crate slipped away! Keep tapping faster!",
								Color3.fromRGB(255, 92, 92)
							)
						end
						table.clear(crate.pullers)
					else
						local liftY = crate.progress * 2.4
						crate.model:PivotTo(CFrame.new(crate.spawnPos + Vector3.new(0, liftY, 0)))

						for _, p in ipairs(validPullers) do
							Remotes.Get("PullProgressSync"):FireClient(p, {
								active = true,
								crateId = crate.id,
								progress = crate.progress,
								rarity = crate.rarity,
								tooWeak = isTooWeak,
								cratePos = (crate.model.PrimaryPart :: BasePart).Position,
							})
						end

						if crate.progress >= 1 then
							LassoRescueSystem.CompletePull(crate)
						end
					end
				end
			end
		end

		-- Auto-store carried crates when player crosses into Safe Zone!
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
				spawnCrateAt(rec.biomeId, rec.originSpawnPos, rec.isOnboarding, nil, true)
			end
		end
		playerTowedCrates[player.UserId] = nil
	end)
end

return LassoRescueSystem
