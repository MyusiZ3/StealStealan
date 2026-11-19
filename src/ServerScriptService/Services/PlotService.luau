--!strict
-- PlotService.luau
-- Manages 6 Open-Pen Roaming Plots, Passive Income/sec (Size + Mutation + Multipliers),
-- Pen Capacity Upgrades (8->20), Crate Delivery/Unboxing, and Animal Index Registration.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Types = require(game.ReplicatedStorage.Shared.Types)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local AnimalConfig = require(game.ReplicatedStorage.Config.AnimalConfig)
local TrailConfig = require(game.ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(game.ReplicatedStorage.Config.VehicleConfig)
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local PlotVisualBuilder = require(game.ReplicatedStorage.Modules.PlotVisualBuilder)
local PlotPrefabSystem = require(game.ReplicatedStorage.Modules.PlotPrefabSystem)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PassManager = require(script.Parent.PassManager)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)

local PlotService = {}

local plotOwners: { [number]: Player? } = {} -- plotIndex (1..6) -> Player
local playerPlots: { [number]: number } = {} -- userId -> plotIndex

-- Live event hooks injected by AdminService to avoid circular dependency
local liveGetters = {
	getCashMultiplier = function(): number return 1.0 end,
	getMutationLuckMultiplier = function(): number return 1.0 end,
	getGiantSizeMultiplier = function(): number return 1.0 end,
	isInstantUnbox = function(_player: Player): boolean return false end,
	getMutationWeightOverrides = function(): { [string]: number }? return nil end,
	getForcedWildMutation = function(): string? return nil end,
	getSizeBracketOverrides = function(): { [string]: number }? return nil end,
}

local penDropHandler: ((Player) -> ())? = nil

function PlotService.RegisterLiveGetters(getters: typeof(liveGetters))
	liveGetters = getters
end

function PlotService.RegisterPenDropHandler(fn: (Player) -> ())
	penDropHandler = fn
end

local function getPlotsFolder(): Folder?
	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local plots = if hub then hub:FindFirstChild("Plots") else nil
	return plots :: Folder?
end

function PlotService.GetPlotModel(plotIndex: number): Model?
	local folder = getPlotsFolder()
	if not folder then
		return nil
	end
	local m = folder:FindFirstChild("Plot_" .. tostring(plotIndex))
	return if m and m:IsA("Model") then m else nil
end

function PlotService.GetPlayerPlotIndex(player: Player): number?
	return playerPlots[player.UserId]
end

function PlotService.GetPlotSpawnCFrame(plotIndex: number): CFrame?
	local model = PlotService.GetPlotModel(plotIndex)
	if not model then
		return nil
	end
	local base = model.PrimaryPart or model:FindFirstChild("PlotBase")
	if not base or not base:IsA("BasePart") then
		return nil
	end
	local plotCF = base.CFrame
	local spawnPos = (plotCF * CFrame.new(0, 4.5, -24)).Position
	local lookAtPos = (plotCF * CFrame.new(0, 4.5, -48)).Position
	return CFrame.lookAt(spawnPos, lookAtPos)
end

function PlotService.TeleportPlayerToPlot(player: Player)
	local idx = playerPlots[player.UserId]
	if not idx then
		return
	end
	local cf = PlotService.GetPlotSpawnCFrame(idx)
	local char = player.Character
	if cf and char then
		char:PivotTo(cf)
	end
end

function PlotService.GetMaxPenCapacity(player: Player, profile: Types.PlayerProfileSchema): number
	local maxCap = GameConfig.PEN.MAX_CAPACITY_FREE
	if PassManager.OwnsPass(player, "ExtraZooCapacity") then
		maxCap += GameConfig.PEN.MAX_CAPACITY_PASS_BONUS
	end
	-- Add Savanna Index bonus if completed
	if profile.zoneIndexBonusesClaimed.SavannaCamp then
		maxCap += 1
	end
	return maxCap
end

function PlotService.GetPenUpgradeCost(profile: Types.PlayerProfileSchema): number
	return math.floor(GameConfig.PEN.UPGRADE_BASE_COST * math.pow(GameConfig.PEN.UPGRADE_GROWTH, profile.penUpgradeLevel - 1))
end

local function getTrailCashBonus(trailId: string): number
	for _, t in ipairs(TrailConfig) do
		if t.id == trailId then
			return t.cashBonus
		end
	end
	return 0
end

local function getIndexCashBonus(profile: Types.PlayerProfileSchema): number
	local bonus = 0
	if profile.zoneIndexBonusesClaimed.PineWoods then bonus += 0.10 end
	if profile.zoneIndexBonusesClaimed.SavannaCamp then bonus += 0.35 end
	if profile.zoneIndexBonusesClaimed.VolcanicJungle then bonus += 1.00 end
	return bonus
end

function PlotService.ComputePlayerCashMultiplier(player: Player, profile: Types.PlayerProfileSchema): number
	local penMult = 1 + (profile.penUpgradeLevel - 1) * GameConfig.PEN.INCOME_BONUS_PER_LEVEL
	local rebirthMult = 1 + profile.rebirths * GameConfig.ECONOMY.REBIRTH_INCOME_BONUS
	local vipMult = if PassManager.OwnsPass(player, "VIP") then 1.5 else 1.0
	local trailMult = 1 + getTrailCashBonus(profile.equippedTrail)
	local indexMult = 1 + getIndexCashBonus(profile)
	local friendMult = 1 + PassManager.GetFriendBoost(player)
	local eventMult = liveGetters.getCashMultiplier()

	return penMult * rebirthMult * vipMult * trailMult * indexMult * friendMult * eventMult
end

function PlotService.ComputePlayerIncomePerSec(player: Player, profile: Types.PlayerProfileSchema): number
	local baseSum = 0
	for _, uid in ipairs(profile.roamingAnimalUids) do
		local animal = profile.inventoryAnimals[uid]
		if animal then
			baseSum += AnimalConfig.ComputeIncomePerSec(animal)
		end
	end
	return baseSum * PlotService.ComputePlayerCashMultiplier(player, profile)
end

local function updateSignGui(part: Instance?, titleText: string, subText: string?)
	if not part then
		return
	end
	local gui = part:FindFirstChild("SignGui")
	if not gui then
		return
	end
	local frame = gui:FindFirstChildOfClass("Frame")
	if not frame then
		return
	end
	local title = frame:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = titleText
	end
	local sub = frame:FindFirstChild("Subtitle")
	if sub and sub:IsA("TextLabel") and subText then
		sub.Text = subText
	end
end

function PlotService.RefreshPlotBoardVisuals(player: Player)
	local plotIdx = playerPlots[player.UserId]
	local profile = DataService.GetProfile(player)
	if not plotIdx or not profile then
		return
	end
	local model = PlotService.GetPlotModel(plotIdx)
	if not model then
		return
	end
	local cashMult = PlotService.ComputePlayerCashMultiplier(player, profile)
	local incomePerSec = PlotService.ComputePlayerIncomePerSec(player, profile)
	player:SetAttribute("CashMult", cashMult)
	player:SetAttribute("IncomePerSec", incomePerSec)
	local maxCap = PlotService.GetMaxPenCapacity(player, profile)

	-- Keep Roblox Top-Right PlayerList (leaderstats: Cash/s & Speed) synced
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		ls = folder
	end
	local cashStat = ls:FindFirstChild("Cash/s")
	if not cashStat or not cashStat:IsA("StringValue") then
		local sv = Instance.new("StringValue")
		sv.Name = "Cash/s"
		sv.Parent = ls
		cashStat = sv
	end
	(cashStat :: StringValue).Value = FormatUtil.Number(incomePerSec)

	local speedStat = ls:FindFirstChild("Speed")
	if not speedStat or not speedStat:IsA("StringValue") then
		local sv = Instance.new("StringValue")
		sv.Name = "Speed"
		sv.Parent = ls
		speedStat = sv
	end
	local speedMult = 1
	if player:GetAttribute("IsRidingVehicle") == true then
		for _, v in ipairs(VehicleConfig) do
			if v.id == profile.equippedVehicle then
				speedMult = v.speedMultiplier
				break
			end
		end
	end
	local attrEffective = tonumber(player:GetAttribute("EffectiveSpeedStat"))
	local effectiveSpeedVal = if attrEffective ~= nil then attrEffective else (profile.speedStat * speedMult)
	local speedValObj = speedStat :: StringValue
	speedValObj.Value = FormatUtil.Number(effectiveSpeedVal)

	-- Evolve physical Pen Fence & Treadmill tiers dynamically
	PlotVisualBuilder.ApplyPlotEvolution(model, profile.penUpgradeLevel, profile.treadmillLevel)

	local signBoard = model:FindFirstChild("OwnerSignBoard")
	updateSignGui(signBoard, player.DisplayName .. "'s ZOO", string.format("Open-Pen (%d/%d Animals)", #profile.roamingAnimalUids, profile.penCapacity))

	local cashPad = model:FindFirstChild("CashCollectorPad")
	updateSignGui(cashPad, "COLLECT: $" .. FormatUtil.Number(profile.unclaimedPenCoins), "$" .. FormatUtil.Number(incomePerSec) .. "/sec")
	PlotVisualBuilder.UpdateCashPileVisual(model, profile.unclaimedPenCoins, incomePerSec)

	local upgradeBoard = model:FindFirstChild("PenUpgradeBoard")
	if profile.penCapacity >= maxCap then
		PlotVisualBuilder.UpdateUpgradeBoardGui(
			upgradeBoard,
			"Upgrade Pen",
			string.format("Lv. %d (MAX %d/%d)", profile.penUpgradeLevel, profile.penCapacity, maxCap),
			"MAX",
			true
		)
	else
		local cost = PlotService.GetPenUpgradeCost(profile)
		PlotVisualBuilder.UpdateUpgradeBoardGui(
			upgradeBoard,
			"Upgrade Pen",
			string.format("Lv. %d > Lv. %d (%d > %d)", profile.penUpgradeLevel, profile.penUpgradeLevel + 1, profile.penCapacity, profile.penCapacity + 1),
			"$" .. FormatUtil.Number(cost),
			false
		)
	end

	local treadBoard = model:FindFirstChild("TreadmillUpgradeBoard")
	local treadLv = math.clamp(math.floor(tonumber(profile.treadmillLevel) or 1), 1, GameConfig.TREADMILL.MAX_LEVEL)
	if treadLv >= GameConfig.TREADMILL.MAX_LEVEL then
		PlotVisualBuilder.UpdateUpgradeBoardGui(
			treadBoard,
			"Upgrade Treadmill",
			"Lv. 12 MAX (+125K/Step)",
			"MAX",
			true
		)
	else
		local nextCost = GameConfig.GetTreadmillUpgradeCost(treadLv) or 400
		local curStep = GameConfig.GetTreadmillBaseStep(treadLv)
		local nextStep = GameConfig.GetTreadmillBaseStep(treadLv + 1)
		PlotVisualBuilder.UpdateUpgradeBoardGui(
			treadBoard,
			"Upgrade Treadmill",
			string.format("Lv. %d > Lv. %d (+%s > +%s)", treadLv, treadLv + 1, FormatUtil.Number(curStep), FormatUtil.Number(nextStep)),
			"$" .. FormatUtil.Number(nextCost),
			false
		)
	end
end

function PlotService.BroadcastAllPlotsSync()
	local payload: { [string]: {
		plotIndex: number,
		ownerUserId: number,
		ownerName: string,
		ownerUsername: string,
		roamingAnimals: { Types.AnimalInstance },
		pendingCrates: { Types.CrateInstance },
	} } = {}

	for i = 1, GameConfig.PLOT_COUNT do
		local owner = plotOwners[i]
		local list: { Types.AnimalInstance } = {}
		local crates: { Types.CrateInstance } = {}
		if owner then
			local prof = DataService.GetProfile(owner)
			if prof then
				for _, uid in ipairs(prof.roamingAnimalUids) do
					local a = prof.inventoryAnimals[uid]
					if a then
						table.insert(list, a)
					end
				end
				for _, c in pairs(prof.pendingCrates) do
					table.insert(crates, c)
				end
			end
		end
		payload[tostring(i)] = {
			plotIndex = i,
			ownerUserId = if owner then owner.UserId else 0,
			ownerName = if owner then owner.DisplayName else "Vacant",
			ownerUsername = if owner then owner.Name else "",
			roamingAnimals = list,
			pendingCrates = crates,
		}
	end
	Remotes.Get("AllPlotsSync"):FireAllClients(payload)
end

function PlotService.RegisterAnimalDiscovery(profile: Types.PlayerProfileSchema, speciesId: string, sizeRatio: number, mutation: Types.AnimalMutation)
	local entry = profile.discoveredIndex[speciesId]
	if not entry then
		entry = {
			count = 0,
			maxSizeRatio = sizeRatio,
			mutationsFound = {},
			rewardClaimed = false,
		}
		profile.discoveredIndex[speciesId] = entry
	end
	entry.count += 1
	if sizeRatio > entry.maxSizeRatio then
		entry.maxSizeRatio = sizeRatio
	end
	entry.mutationsFound[mutation] = true
end

function PlotService.GrantAnimalToPlayer(
	player: Player,
	speciesId: string,
	forcedSizeRatio: number?,
	forcedMutation: Types.AnimalMutation?,
	originMeta: { originSource: Types.ItemOriginSource?, parentUids: { string }? }?
): Types.AnimalInstance?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local spec = AnimalConfig.GetById(speciesId) or AnimalConfig.ALL[1]
	local luckMult = PassManager.GetServerLuckMultiplier() * liveGetters.getMutationLuckMultiplier()
	local mutOverrides = if liveGetters.getMutationWeightOverrides then liveGetters.getMutationWeightOverrides() else nil
	local forcedWild = if liveGetters.getForcedWildMutation then liveGetters.getForcedWildMutation() else nil
	local sizeOverrides = if liveGetters.getSizeBracketOverrides then liveGetters.getSizeBracketOverrides() else nil
	local sizeRatio = forcedSizeRatio or AnimalConfig.RollSizeRatio(liveGetters.getGiantSizeMultiplier(), sizeOverrides)
	local mutation = forcedMutation or AnimalConfig.RollMutation(luckMult, mutOverrides, forcedWild)
	local weightKg = math.floor(spec.baseWeightKg * math.pow(sizeRatio, 2.2) * 10 + 0.5) / 10

	local uid, serialNonce = DataService.MintUniqueId(profile)
	DataService.RegisterUidOwner(uid, player.UserId, "PetInv")
	local animal: Types.AnimalInstance = {
		uid = uid,
		speciesId = spec.id,
		sizeRatio = sizeRatio,
		weightKg = weightKg,
		mutation = mutation,
		locked = (mutation ~= "None" or GameConfig.GetRarityTier(spec.rarity) >= 5),
		acquiredAt = os.time(),
		serialNonce = serialNonce,
		mintedByUserId = player.UserId,
		originSource = if originMeta and originMeta.originSource then originMeta.originSource else "Hatch",
		parentUids = if originMeta then originMeta.parentUids else nil,
	}

	profile.inventoryAnimals[uid] = animal
	PlotService.RegisterAnimalDiscovery(profile, spec.id, sizeRatio, mutation)

	-- Automatically place into Open Pen if there is room!
	if #profile.roamingAnimalUids < profile.penCapacity and not table.find(profile.roamingAnimalUids, uid) then
		table.insert(profile.roamingAnimalUids, uid)
	end

	PlotService.RefreshPlotBoardVisuals(player)
	PlotService.BroadcastAllPlotsSync()
	DataService.SyncProfile(player)
	return animal
end

local function resolveCrateLocalXZ(crate: Types.CrateInstance, fallbackIdx: number): (number, number)
	if type(crate.localX) == "number" and type(crate.localZ) == "number" then
		return crate.localX, crate.localZ
	end
	local slotIdx = tonumber(crate.placedSlot) or fallbackIdx
	local idx0 = math.clamp(slotIdx - 1, 0, GameConfig.PEN.MAX_PLACED_CRATES - 1)
	local col = idx0 % 6
	local row = math.floor(idx0 / 6)
	return -15 + col * 6.0, -10 + row * 6.0
end

function PlotService.AddCrateToInventory(
	player: Player,
	biomeId: string,
	rarity: Types.AnimalRarity,
	speciesId: string,
	sizeScale: number?,
	customStats: {
		customSizeRatio: number?,
		customMutation: Types.AnimalMutation?,
		originSource: Types.ItemOriginSource?,
		parentUids: { string }?,
	}?
): string?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	if type(profile.crateInventory) ~= "table" then
		profile.crateInventory = {}
	end
	local crateUid, serialNonce = DataService.MintUniqueId(profile)
	DataService.RegisterUidOwner(crateUid, player.UserId, "CrateInv")
	local dur = GameConfig.ComputeHatchSeconds(rarity, biomeId)
	if liveGetters.isInstantUnbox(player) then
		dur = 0
	end
	local rec: Types.InventoryCrate = {
		uid = crateUid,
		biomeId = biomeId,
		rarity = rarity,
		speciesId = speciesId,
		sizeScale = sizeScale or GameConfig.ComputeCrateScale(rarity),
		hatchDuration = dur,
		acquiredAt = os.time(),
		customSizeRatio = if customStats then customStats.customSizeRatio else nil,
		customMutation = if customStats then customStats.customMutation else nil,
		serialNonce = serialNonce,
		mintedByUserId = player.UserId,
		originSource = if customStats and customStats.originSource then customStats.originSource else "Wild",
		parentUids = if customStats then customStats.parentUids else nil,
	}
	profile.crateInventory[crateUid] = rec
	DataService.SyncProfile(player)
	return crateUid
end

function PlotService.PlaceCrateInPen(player: Player, crateUid: string, targetLocalX: number, targetLocalZ: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or type(profile.crateInventory) ~= "table" then
		return false
	end
	if DataService.IsUidConsumed(profile, crateUid) or profile.pendingCrates[crateUid] ~= nil then
		profile.crateInventory[crateUid] = nil
		return false
	end
	if not DataService.AcquireTransactionLock(player.UserId, { crateUid }) then
		return false
	end
	local invCrate = profile.crateInventory[crateUid]
	if not invCrate then
		DataService.ReleaseTransactionLock(player.UserId, { crateUid })
		return false
	end

	local usedSlots: { [number]: boolean } = {}
	local count = 0
	local plotIdx = playerPlots[player.UserId]
	local plotModel = if plotIdx then PlotService.GetPlotModel(plotIdx) else nil
	local paddock = if plotModel then plotModel:FindFirstChild("OpenPaddockFloor") else nil
	local halfX = if paddock and paddock:IsA("BasePart") then math.max(14.0, paddock.Size.X * 0.5 - 2.5) else 17.5
	local halfZ = if paddock and paddock:IsA("BasePart") then math.max(14.0, paddock.Size.Z * 0.5 - 2.5) else 17.5
	local lx = math.clamp(targetLocalX, -halfX, halfX)
	local lz = math.clamp(targetLocalZ, -halfZ, halfZ)
	local newScale = tonumber(invCrate.sizeScale) or GameConfig.ComputeCrateScale(invCrate.rarity)

	local idxCounter = 0
	for _, existing in pairs(profile.pendingCrates) do
		count += 1
		idxCounter += 1
		if type(existing.placedSlot) == "number" then
			usedSlots[existing.placedSlot] = true
		end
		local ex, ez = resolveCrateLocalXZ(existing, idxCounter)
		local exScale = tonumber(existing.sizeScale) or GameConfig.ComputeCrateScale(existing.rarity)
		local reqDist = 2.8 + (newScale + exScale) * 2.1
		local dx = lx - ex
		local dz = lz - ez
		if math.sqrt(dx * dx + dz * dz) < reqDist then
			DataService.ReleaseTransactionLock(player.UserId, { crateUid })
			Remotes.Get("NotifyClient"):FireClient(player, "Too close to another crate! Pick an open spot in your Pen.", Color3.fromRGB(255, 196, 62))
			return false
		end
	end

	if count >= GameConfig.PEN.MAX_PLACED_CRATES then
		DataService.ReleaseTransactionLock(player.UserId, { crateUid })
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("Pen crate slots full (%d/%d)! Hatch crates first.", count, GameConfig.PEN.MAX_PLACED_CRATES),
			Color3.fromRGB(255, 196, 62)
		)
		return false
	end

	local freeSlot = 1
	for s = 1, GameConfig.PEN.MAX_PLACED_CRATES do
		if not usedSlots[s] then
			freeSlot = s
			break
		end
	end

	local dur = GameConfig.ComputeHatchSeconds(invCrate.rarity, invCrate.biomeId)
	if liveGetters.isInstantUnbox(player) then
		dur = 0
	end

	-- Atomic handover: remove from crateInventory FIRST, then insert into pendingCrates
	profile.crateInventory[crateUid] = nil
	DataService.RegisterUidOwner(crateUid, player.UserId, "PendingCrate")
	profile.pendingCrates[crateUid] = {
		uid = crateUid,
		biomeId = invCrate.biomeId,
		rarity = invCrate.rarity,
		speciesId = invCrate.speciesId,
		unlockAt = os.time() + dur,
		hatchDuration = dur,
		placedSlot = freeSlot,
		sizeScale = newScale,
		localX = lx,
		localZ = lz,
		customSizeRatio = invCrate.customSizeRatio,
		customMutation = invCrate.customMutation,
		serialNonce = invCrate.serialNonce,
		mintedByUserId = invCrate.mintedByUserId,
		originSource = invCrate.originSource,
		parentUids = invCrate.parentUids,
	}
	DataService.ReleaseTransactionLock(player.UserId, { crateUid })

	PlotService.RefreshPlotBoardVisuals(player)
	PlotService.BroadcastAllPlotsSync()
	DataService.SyncProfile(player)
	Remotes.Get("NotifyClient"):FireClient(
		player,
		string.format("Placed [%s] Crate in Pen! Hatches in %ds.", invCrate.rarity, dur),
		GameConfig.RARITY_COLORS[invCrate.rarity] or Color3.fromRGB(84, 245, 148)
	)
	return true
end

function PlotService.AddPendingCrate(player: Player, biomeId: string, rarity: Types.AnimalRarity, speciesId: string, sizeScale: number?): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end

	local usedSlots: { [number]: boolean } = {}
	local count = 0
	for _, existing in pairs(profile.pendingCrates) do
		count += 1
		if type(existing.placedSlot) == "number" then
			usedSlots[existing.placedSlot] = true
		end
	end
	if count >= GameConfig.PEN.MAX_PLACED_CRATES then
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("Pen crate slots full (%d/%d)! Hatch crates inside your pen first.", count, GameConfig.PEN.MAX_PLACED_CRATES),
			Color3.fromRGB(255, 196, 62)
		)
		return false
	end

	local freeSlot = 1
	for s = 1, GameConfig.PEN.MAX_PLACED_CRATES do
		if not usedSlots[s] then
			freeSlot = s
			break
		end
	end

	local dur = GameConfig.ComputeHatchSeconds(rarity, biomeId)
	if liveGetters.isInstantUnbox(player) then
		dur = 0
	end
	local crateUid, serialNonce = DataService.MintUniqueId(profile)
	DataService.RegisterUidOwner(crateUid, player.UserId, "PendingCrate")
	local crate: Types.CrateInstance = {
		uid = crateUid,
		biomeId = biomeId,
		rarity = rarity,
		speciesId = speciesId,
		unlockAt = os.time() + dur,
		hatchDuration = dur,
		placedSlot = freeSlot,
		sizeScale = sizeScale or GameConfig.ComputeCrateScale(rarity),
		serialNonce = serialNonce,
		mintedByUserId = player.UserId,
		originSource = "Wild",
	}
	profile.pendingCrates[crateUid] = crate
	PlotService.RefreshPlotBoardVisuals(player)
	PlotService.BroadcastAllPlotsSync()
	DataService.SyncProfile(player)
	return true
end

function PlotService.OpenCrate(player: Player, crateUid: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	if DataService.IsUidConsumed(profile, crateUid) then
		profile.pendingCrates[crateUid] = nil
		return
	end
	if not DataService.AcquireTransactionLock(player.UserId, { crateUid }) then
		return
	end
	local crate = profile.pendingCrates[crateUid]
	if not crate then
		DataService.ReleaseTransactionLock(player.UserId, { crateUid })
		return
	end
	if os.time() < crate.unlockAt and not liveGetters.isInstantUnbox(player) then
		DataService.ReleaseTransactionLock(player.UserId, { crateUid })
		local rem = crate.unlockAt - os.time()
		Remotes.Get("NotifyClient"):FireClient(player, "Crate unlocks in " .. rem .. "s!", Color3.fromRGB(255, 206, 62))
		return
	end
	local revealPayload = {
		crateUid = crateUid,
		plotIndex = playerPlots[player.UserId] or 1,
		biomeId = crate.biomeId,
		rarity = crate.rarity,
		sizeScale = crate.sizeScale or GameConfig.ComputeCrateScale(crate.rarity),
		placedSlot = crate.placedSlot,
		localX = crate.localX,
		localZ = crate.localZ,
	}
	-- Consume crate & record tombstone FIRST before minting hatched pet!
	profile.pendingCrates[crateUid] = nil
	profile.crateInventory[crateUid] = nil
	DataService.MarkUidConsumed(profile, crateUid)
	DataService.ReleaseTransactionLock(player.UserId, { crateUid })

	local currentOpened = (player:GetAttribute("CratesOpened") or 0) + 1
	player:SetAttribute("CratesOpened", currentOpened)

	local animal = PlotService.GrantAnimalToPlayer(player, crate.speciesId, crate.customSizeRatio, crate.customMutation, {
		originSource = "Hatch",
		parentUids = { crateUid },
	})
	if animal then
		local spec = AnimalConfig.GetById(animal.speciesId)
		local mutText = if animal.mutation ~= "None" then ("[" .. animal.mutation .. "] ") else ""
		local oddsDenom = GameConfig.ComputePullOddsDenominator(crate.rarity, animal.mutation)
		local tier = GameConfig.GetRarityTier(crate.rarity)
		Remotes.Get("CrateHatchReveal"):FireAllClients({
			openerUserId = player.UserId,
			openerName = player.DisplayName,
			crateUid = revealPayload.crateUid,
			plotIndex = revealPayload.plotIndex,
			biomeId = revealPayload.biomeId,
			rarity = revealPayload.rarity,
			sizeScale = revealPayload.sizeScale,
			placedSlot = revealPayload.placedSlot,
			localX = revealPayload.localX,
			localZ = revealPayload.localZ,
			animalUid = animal.uid,
			speciesId = animal.speciesId,
			mutation = animal.mutation,
			sizeRatio = animal.sizeRatio,
			weightKg = animal.weightKg,
			oddsDenom = oddsDenom,
		})
		if tier >= 10 or oddsDenom >= 2500 then
			Remotes.Get("GlobalEventBanner"):FireAllClients(
				string.format("🌌 [%s • 1 IN %s] %s hatched %s%s!", string.upper(crate.rarity), FormatUtil.Number(oddsDenom), player.DisplayName, mutText, spec and spec.name or animal.speciesId),
				GameConfig.RARITY_COLORS[crate.rarity] or Color3.fromRGB(186, 128, 255),
				8
			)
		end
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("Hatched %s%s (%.2fx Size | %.1fkg)!", mutText, spec and spec.name or animal.speciesId, animal.sizeRatio, animal.weightKg),
			GameConfig.RARITY_COLORS[crate.rarity] or Color3.fromRGB(84, 245, 148)
		)
	else
		PlotService.BroadcastAllPlotsSync()
		DataService.SyncProfile(player)
	end
end

function PlotService.AssignPlot(player: Player)
	for i = 1, GameConfig.PLOT_COUNT do
		if plotOwners[i] == nil then
			plotOwners[i] = player
			playerPlots[player.UserId] = i
			local model = PlotService.GetPlotModel(i)
			if model then
				model:SetAttribute("OwnerUsername", player.Name)
				model:SetAttribute("OwnerUserId", player.UserId)
			end
			PlotService.RefreshPlotBoardVisuals(player)
			PlotService.BroadcastAllPlotsSync()
			PlotService.TeleportPlayerToPlot(player)
			return
		end
	end
end

function PlotService.ReleasePlot(player: Player)
	local idx = playerPlots[player.UserId]
	if idx then
		plotOwners[idx] = nil
		playerPlots[player.UserId] = nil
		local model = PlotService.GetPlotModel(idx)
		if model then
			model:SetAttribute("OwnerUsername", "")
			model:SetAttribute("OwnerUserId", 0)
			PlotVisualBuilder.ApplyPlotEvolution(model, 1, 1)
			updateSignGui(model:FindFirstChild("OwnerSignBoard"), "ZOO SANCTUARY #" .. idx, "Vacant Plot")
			updateSignGui(model:FindFirstChild("CashCollectorPad"), "COLLECT: $0", "$0/s Pen Income")
			PlotVisualBuilder.UpdateCashPileVisual(model, 0, 0)
			PlotVisualBuilder.UpdateUpgradeBoardGui(model:FindFirstChild("PenUpgradeBoard"), "Upgrade Pen", "Lv. 1 > Lv. 2 (8 > 9)", "$600", false)
			PlotVisualBuilder.UpdateUpgradeBoardGui(model:FindFirstChild("TreadmillUpgradeBoard"), "Upgrade Treadmill", "Lv. 1 > Lv. 2 (+2 > +6)", "$400", false)
		end
		PlotService.BroadcastAllPlotsSync()
	end
end

function PlotService.UpgradeTreadmill(player: Player)
	local prof = DataService.GetProfile(player)
	if not prof then return end
	local curLv = math.clamp(math.floor(tonumber(prof.treadmillLevel) or 1), 1, GameConfig.TREADMILL.MAX_LEVEL)
	if curLv >= GameConfig.TREADMILL.MAX_LEVEL then
		Remotes.Get("NotifyClient"):FireClient(player, "Treadmill is already MAX Level (Lv. 12)!", Color3.fromRGB(255, 206, 62))
		return
	end
	local cost = GameConfig.GetTreadmillUpgradeCost(curLv) or 400
	if prof.coins < cost then
		local short = cost - prof.coins
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("Not enough Cash! Need $%s more to Upgrade Treadmill ($%s)", FormatUtil.Number(short), FormatUtil.Number(cost)),
			Color3.fromRGB(255, 86, 86)
		)
		return
	end
	prof.coins -= cost
	prof.treadmillLevel = curLv + 1
	PlotService.RefreshPlotBoardVisuals(player)
	DataService.SyncProfile(player)
	local newStep = GameConfig.GetTreadmillBaseStep(prof.treadmillLevel)
	Remotes.Get("NotifyClient"):FireClient(player, string.format("Treadmill upgraded to Lv.%d (+%s/Step)!", prof.treadmillLevel, FormatUtil.Number(newStep)), Color3.fromRGB(58, 188, 255))
end

local function bindBoardTrigger(board: Instance?, promptName: string, pIdx: number, cb: (Player) -> ())
	if not board then return end
	local prompt = board:FindFirstChild(promptName)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			if playerPlots[player.UserId] ~= pIdx then
				Remotes.Get("NotifyClient"):FireClient(player, "That belongs to another player's Sanctuary Plot!", Color3.fromRGB(255, 118, 96))
				return
			end
			cb(player)
		end)
	end
	local cd = board:FindFirstChild(promptName .. "_Click")
	if cd and cd:IsA("ClickDetector") then
		cd.MouseClick:Connect(function(player)
			if playerPlots[player.UserId] ~= pIdx then
				Remotes.Get("NotifyClient"):FireClient(player, "That belongs to another player's Sanctuary Plot!", Color3.fromRGB(255, 118, 96))
				return
			end
			cb(player)
		end)
	end
end

local function bindPlotPrompts()
	local folder = getPlotsFolder()
	if not folder then
		return
	end
	for _, plotModel in ipairs(folder:GetChildren()) do
		local pIdx = plotModel:GetAttribute("PlotIndex")
		if type(pIdx) == "number" then
			local cashPad = plotModel:FindFirstChild("CashCollectorPad")
			local cashPrompt = if cashPad then cashPad:FindFirstChild("CollectCashPrompt") else nil
			if cashPrompt and cashPrompt:IsA("ProximityPrompt") then
				cashPrompt.Triggered:Connect(function(player)
					if playerPlots[player.UserId] ~= pIdx then
						Remotes.Get("NotifyClient"):FireClient(player, "That belongs to another player's Sanctuary Plot!", Color3.fromRGB(255, 118, 96))
						return
					end
					PlotService.ClaimPenCoins(player)
				end)
			end

			local paddock = plotModel:FindFirstChild("OpenPaddockFloor")
			local dropPrompt = if paddock then paddock:FindFirstChild("PenDropPrompt") else nil
			if dropPrompt and dropPrompt:IsA("ProximityPrompt") then
				dropPrompt.Triggered:Connect(function(player)
					if playerPlots[player.UserId] ~= pIdx then
						return
					end
					if penDropHandler then
						penDropHandler(player)
					end
				end)
			end

			bindBoardTrigger(plotModel:FindFirstChild("PenUpgradeBoard"), "UpgradePenPrompt", pIdx, PlotService.UpgradePen)
			bindBoardTrigger(plotModel:FindFirstChild("TreadmillUpgradeBoard"), "UpgradeTreadmillPrompt", pIdx, PlotService.UpgradeTreadmill)
		end
	end
end

local lastCashClaimTick: { [number]: number } = {}

function PlotService.ClaimPenCoins(player: Player)
	local now = os.clock()
	if now - (lastCashClaimTick[player.UserId] or 0) < 0.35 then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile or profile.unclaimedPenCoins < 1 then
		if profile and now - (lastCashClaimTick[player.UserId] or 0) > 1.0 then
			Remotes.Get("NotifyClient"):FireClient(player, "No Pen Cash ready yet — equip pets in your Pen to earn!", Color3.fromRGB(255, 198, 62))
		end
		return
	end
	lastCashClaimTick[player.UserId] = now
	local plotIdx = playerPlots[player.UserId]
	local model = if plotIdx then PlotService.GetPlotModel(plotIdx) else nil
	local pile = if model then model:FindFirstChild("VoxelCashPile") else nil
	local bundleCount = math.clamp(tonumber(pile and pile:GetAttribute("BundleCount")) or 6, 4, 20)

	local amount = math.floor(profile.unclaimedPenCoins)
	profile.unclaimedPenCoins = 0
	profile.coins += amount
	AnalyticsTracker.LogEconomy(player, true, "Coins", amount, profile.coins, "Gameplay", "PenIncome")
	PlotService.RefreshPlotBoardVisuals(player)
	DataService.SyncProfile(player)
	if plotIdx then
		Remotes.Get("PlayWorldVFX"):FireClient(player, "CashPileSuction", {
			plotIndex = plotIdx,
			bundleCount = bundleCount,
			amount = amount,
		})
	end
	Remotes.Get("NotifyClient"):FireClient(player, "+$" .. FormatUtil.Number(amount) .. " collected from Zoo Pen!", Color3.fromRGB(84, 245, 148))
end

function PlotService.UpgradePen(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local maxCap = PlotService.GetMaxPenCapacity(player, profile)
	if profile.penCapacity >= maxCap then
		Remotes.Get("NotifyClient"):FireClient(player, "Pen Capacity is already MAX (" .. maxCap .. ")!", Color3.fromRGB(255, 206, 62))
		return
	end
	local cost = PlotService.GetPenUpgradeCost(profile)
	if profile.coins < cost then
		local short = cost - profile.coins
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("Not enough Cash! Need $%s more to Upgrade Pen ($%s)", FormatUtil.Number(short), FormatUtil.Number(cost)),
			Color3.fromRGB(255, 86, 86)
		)
		return
	end
	profile.coins -= cost
	profile.penCapacity += 1
	profile.penUpgradeLevel += 1
	AnalyticsTracker.LogEconomy(player, false, "Coins", cost, profile.coins, "Upgrade", "PenCapacity_" .. tostring(profile.penCapacity))
	if profile.analyticsMeta.onboardingStep < 4 then
		profile.analyticsMeta.onboardingStep = 4
		AnalyticsTracker.LogOnboardingStep(player, 4, "FirstPenUpgrade")
	end
	PlotService.RefreshPlotBoardVisuals(player)
	DataService.SyncProfile(player)
	Remotes.Get("NotifyClient"):FireClient(player, string.format("Pen Upgraded to %d/%d Animals (+10%% Income)!", profile.penCapacity, maxCap), Color3.fromRGB(168, 108, 255))
end

function PlotService.Init()
	local gw = Workspace:FindFirstChild("GameWorld")
	if gw and PlotPrefabSystem.GetOpenPlotPrefab() then
		PlotPrefabSystem.SyncAllPlotsFromPrefab(gw, false)
	end
	for i = 1, GameConfig.PLOT_COUNT do
		if plotOwners[i] == nil then
			local plotModel = PlotService.GetPlotModel(i)
			if plotModel then
				PlotVisualBuilder.ApplyPlotEvolution(plotModel, 1, 1)
				PlotVisualBuilder.UpdateUpgradeBoardGui(plotModel:FindFirstChild("TreadmillUpgradeBoard"), "Upgrade Treadmill", "Lv. 1 > Lv. 2 (+2 > +6)", "$400", false)
			end
		end
	end
	bindPlotPrompts()

	Remotes.Get("ClaimPenCoins").OnServerEvent:Connect(function(player)
		PlotService.ClaimPenCoins(player)
	end)
	Remotes.Get("UpgradePen").OnServerEvent:Connect(function(player)
		PlotService.UpgradePen(player)
	end)
	Remotes.Get("OpenPendingCrate").OnServerEvent:Connect(function(player, crateUid)
		if typeof(crateUid) == "string" then
			PlotService.OpenCrate(player, crateUid)
		end
	end)
	Remotes.Get("PlaceCrateInPen").OnServerEvent:Connect(function(player, crateUid, localX, localZ)
		if typeof(crateUid) == "string" and typeof(localX) == "number" and typeof(localZ) == "number" then
			PlotService.PlaceCrateInPen(player, crateUid, localX, localZ)
		end
	end)
	Remotes.Get("PlacePetInPen").OnServerEvent:Connect(function(player, animalUid, _localX, _localZ)
		if typeof(animalUid) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if not profile or not profile.inventoryAnimals[animalUid] then return end
		for _, uid in ipairs(profile.roamingAnimalUids) do
			if uid == animalUid then
				Remotes.Get("NotifyClient"):FireClient(player, "Pet is already roaming inside your Pen!", Color3.fromRGB(118, 224, 255))
				return
			end
		end
		if #profile.roamingAnimalUids >= profile.penCapacity then
			Remotes.Get("NotifyClient"):FireClient(player, "Pen full! Upgrade capacity or swap an animal.", Color3.fromRGB(255, 196, 62))
			return
		end
		table.insert(profile.roamingAnimalUids, animalUid)
		PlotService.RefreshPlotBoardVisuals(player)
		PlotService.BroadcastAllPlotsSync()
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Placed pet into your Sanctuary Pen!", Color3.fromRGB(84, 245, 148))
	end)

	Remotes.Get("EquipAnimalToPen").OnServerEvent:Connect(function(player, animalUid)
		if typeof(animalUid) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if not profile or not profile.inventoryAnimals[animalUid] then return end
		for _, uid in ipairs(profile.roamingAnimalUids) do
			if uid == animalUid then return end
		end
		if #profile.roamingAnimalUids >= profile.penCapacity then
			Remotes.Get("NotifyClient"):FireClient(player, "Pen full! Upgrade capacity or swap an animal.", Color3.fromRGB(255, 196, 62))
			return
		end
		table.insert(profile.roamingAnimalUids, animalUid)
		PlotService.RefreshPlotBoardVisuals(player)
		PlotService.BroadcastAllPlotsSync()
		DataService.SyncProfile(player)
	end)

	Remotes.Get("UnequipPenAnimal").OnServerEvent:Connect(function(player, animalUid)
		if typeof(animalUid) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		for i, uid in ipairs(profile.roamingAnimalUids) do
			if uid == animalUid then
				table.remove(profile.roamingAnimalUids, i)
				PlotService.RefreshPlotBoardVisuals(player)
				PlotService.BroadcastAllPlotsSync()
				DataService.SyncProfile(player)
				return
			end
		end
	end)

	Remotes.Get("EquipBestAnimals").OnServerEvent:Connect(function(player)
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local list: { { uid: string, income: number } } = {}
		for uid, animal in pairs(profile.inventoryAnimals) do
			table.insert(list, { uid = uid, income = AnimalConfig.ComputeIncomePerSec(animal) })
		end
		if #list == 0 then
			Remotes.Get("NotifyClient"):FireClient(player, "No pets in your Backpack yet! Rescue crates first.", Color3.fromRGB(255, 198, 62))
			return
		end
		table.sort(list, function(a, b)
			return a.income > b.income
		end)
		local limit = math.min(#list, profile.penCapacity)
		local wantedSet: { [string]: boolean } = {}
		for i = 1, limit do
			wantedSet[list[i].uid] = true
		end

		-- Preserve currently roaming pets that stay in top N so their pen positions never reset!
		local keptSet: { [string]: boolean } = {}
		local nextRoaming: { string } = {}
		for _, existingUid in ipairs(profile.roamingAnimalUids) do
			if wantedSet[existingUid] and not keptSet[existingUid] then
				table.insert(nextRoaming, existingUid)
				keptSet[existingUid] = true
			end
		end
		for i = 1, limit do
			local uid = list[i].uid
			if not keptSet[uid] then
				table.insert(nextRoaming, uid)
				keptSet[uid] = true
			end
		end
		profile.roamingAnimalUids = nextRoaming
		PlotService.RefreshPlotBoardVisuals(player)
		PlotService.BroadcastAllPlotsSync()
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Equipped Best Animals to your Sanctuary Pen!", Color3.fromRGB(84, 245, 148))
	end)

	-- Rideable Animal Mount System
	Remotes.Get("MountAnimal").OnServerEvent:Connect(function(player, animalUid)
		if typeof(animalUid) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		if animalUid == "" or player:GetAttribute("MountedAnimalUid") == animalUid then
			player:SetAttribute("MountedAnimalUid", "")
			player:SetAttribute("MountedAnimalId", "")
			player:SetAttribute("MountedAnimalMutation", "None")
			player:SetAttribute("MountedAnimalSize", 1)
			player:SetAttribute("MountedAnimalSpeedBonus", 0)
			Remotes.Get("NotifyClient"):FireClient(player, "Dismounted animal.", Color3.fromRGB(200, 210, 225))
			return
		end
		local animal = profile.inventoryAnimals[animalUid]
		local spec = if animal then AnimalConfig.GetById(animal.speciesId) else nil
		if not animal or not spec then return end
		-- Dismount vehicle if active
		player:SetAttribute("IsRidingVehicle", false)
		local rarityIdx = table.find({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }, spec.rarity) or 1
		local speedBonus = 12 + rarityIdx * 7 + math.floor(animal.sizeRatio * 4)
		player:SetAttribute("MountedAnimalUid", animalUid)
		player:SetAttribute("MountedAnimalId", spec.id)
		player:SetAttribute("MountedAnimalMutation", animal.mutation)
		player:SetAttribute("MountedAnimalSize", animal.sizeRatio)
		player:SetAttribute("MountedAnimalSpeedBonus", speedBonus)
		Remotes.Get("NotifyClient"):FireClient(player, string.format("Riding %s (+%d Speed)!", spec.name, speedBonus), Color3.fromRGB(84, 245, 148))
	end)

	-- Responsive step-on CashCollectorPad check (sucks up VoxelCashPile cleanly when stepping on pad)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				local pIdx = playerPlots[player.UserId]
				if profile and profile.unclaimedPenCoins >= 1 and pIdx then
					local model = PlotService.GetPlotModel(pIdx)
					local cashPad = if model then model:FindFirstChild("CashCollectorPad") else nil
					local char = player.Character
					local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
					if cashPad and cashPad:IsA("BasePart") and hrp and hrp:IsA("BasePart") then
						local rel = cashPad.CFrame:PointToObjectSpace(hrp.Position)
						if math.abs(rel.X) <= cashPad.Size.X * 0.5 + 1.2 and math.abs(rel.Z) <= cashPad.Size.Z * 0.5 + 1.2 and math.abs(rel.Y) <= 6.5 then
							PlotService.ClaimPenCoins(player)
						end
					end
				end
			end
		end
	end)

	-- Income accumulation + auto-unbox loop
	task.spawn(function()
		while true do
			task.wait(GameConfig.ECONOMY.INCOME_TICK_SECONDS)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile then
					local perSec = PlotService.ComputePlayerIncomePerSec(player, profile)
					if perSec > 0 then
						local gain = perSec * GameConfig.ECONOMY.INCOME_TICK_SECONDS
						if PassManager.OwnsPass(player, "AutoUnboxCollect") then
							profile.coins += math.floor(gain)
						else
							profile.unclaimedPenCoins += gain
						end
					end

					if PassManager.OwnsPass(player, "AutoUnboxCollect") then
						for uid, crate in pairs(profile.pendingCrates) do
							if now >= crate.unlockAt then
								PlotService.OpenCrate(player, uid)
							end
						end
					end

					PlotService.RefreshPlotBoardVisuals(player)
					DataService.SyncProfile(player)
				end
			end
		end
	end)
end

return PlotService
