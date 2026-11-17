--!strict
-- FuseMergeSystem.luau
-- 3-in-1 Mutation Evolution Merge (Normal -> Albino -> Golden -> Diamond -> Neon -> Rainbow -> Celestial)
-- & Cross-Fuse Machine (3 random animals -> bonus chance for higher mutation/size)

local Types = require(game.ReplicatedStorage.Shared.Types)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local AnimalConfig = require(game.ReplicatedStorage.Config.AnimalConfig)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.Parent.Services.DataService)
local PlotService = require(script.Parent.Parent.Services.PlotService)

local FuseMergeSystem = {}

local function removeAnimalFromPenAndInventory(profile: Types.PlayerProfileSchema, uid: string)
	profile.inventoryAnimals[uid] = nil
	for i, rUid in ipairs(profile.roamingAnimalUids) do
		if rUid == uid then
			table.remove(profile.roamingAnimalUids, i)
			break
		end
	end
end

local function rollForecastMutation(chances: { { mutation: string, chance: number } }): Types.AnimalMutation
	local total = 0
	for _, entry in ipairs(chances) do
		total += math.max(0, entry.chance)
	end
	if total <= 0 then
		return "None"
	end
	local roll = math.random() * total
	local acc = 0
	for _, entry in ipairs(chances) do
		acc += math.max(0, entry.chance)
		if roll <= acc then
			return entry.mutation :: Types.AnimalMutation
		end
	end
	return "None"
end

local function handleUnifiedMerge(player: Player, uidList: any)
	if type(uidList) ~= "table" or #uidList ~= 3 then
		Remotes.Get("NotifyClient"):FireClient(player, "Select 3 of the same pets to Merge!", Color3.fromRGB(255, 196, 62))
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then return end

	local cleanUids: { string } = {}
	for _, uid in ipairs(uidList) do
		if typeof(uid) ~= "string" or uid == "" then
			return
		end
		table.insert(cleanUids, uid)
	end

	-- Reject any pet currently roaming inside the Open Pen (must be unequipped in Backpack first)
	local roamingSet: { [string]: boolean } = {}
	for _, rUid in ipairs(profile.roamingAnimalUids) do
		roamingSet[rUid] = true
	end
	for _, uid in ipairs(cleanUids) do
		if roamingSet[uid] then
			Remotes.Get("NotifyClient"):FireClient(player, "Cannot merge pets inside your Pen! Unequip them first.", Color3.fromRGB(255, 96, 96))
			return
		end
	end

	-- Acquire per-player + per-UID transaction lock (blocks race-condition / duplicate UID spam)
	if not DataService.AcquireTransactionLock(player.UserId, cleanUids) then
		Remotes.Get("NotifyClient"):FireClient(player, "Merge busy — please try again in a moment!", Color3.fromRGB(255, 196, 62))
		return
	end

	local animals: { Types.AnimalInstance } = {}
	local forecastInputs: { { sizeRatio: number, mutation: string, weightKg: number? } } = {}
	local candidateSpecs: { Types.AnimalSpeciesDefinition } = {}

	for _, uid in ipairs(cleanUids) do
		local a = profile.inventoryAnimals[uid]
		if not a or DataService.IsUidConsumed(profile, uid) then
			DataService.ReleaseTransactionLock(player.UserId, cleanUids)
			Remotes.Get("NotifyClient"):FireClient(player, "One of the selected pets is no longer in your Backpack!", Color3.fromRGB(255, 86, 86))
			return
		end
		table.insert(animals, a)
		table.insert(forecastInputs, { sizeRatio = a.sizeRatio, mutation = a.mutation, weightKg = a.weightKg })
		local spec = AnimalConfig.GetById(a.speciesId) or AnimalConfig.ALL[1]
		table.insert(candidateSpecs, spec)
	end

	local firstSpecies = animals[1].speciesId
	for i = 2, #animals do
		if animals[i].speciesId ~= firstSpecies then
			DataService.ReleaseTransactionLock(player.UserId, cleanUids)
			Remotes.Get("NotifyClient"):FireClient(player, "Merge requires 3 of the same pet species!", Color3.fromRGB(255, 96, 96))
			return
		end
	end

	-- Pick species weighted slightly toward higher rarity inputs (or identical if all match)
	local totalRank = 0
	for _, sp in ipairs(candidateSpecs) do
		totalRank += GameConfig.GetRarityTier(sp.rarity)
	end
	local spRoll = math.random() * math.max(1, totalRank)
	local spAcc = 0
	local chosenSpec = candidateSpecs[1]
	for _, sp in ipairs(candidateSpecs) do
		spAcc += GameConfig.GetRarityTier(sp.rarity)
		if spRoll <= spAcc then
			chosenSpec = sp
			break
		end
	end

	local boostedSize, crateScale, chances, fMeta = GameConfig.ComputeMergeForecast(forecastInputs, chosenSpec.baseWeightKg, chosenSpec.rarity)
	local rolledMut = rollForecastMutation(chances)

	-- Consume all input pets & record their UIDs in consumedUids tombstone list FIRST!
	for _, uid in ipairs(cleanUids) do
		removeAnimalFromPenAndInventory(profile, uid)
		DataService.MarkUidConsumed(profile, uid)
	end
	DataService.ReleaseTransactionLock(player.UserId, cleanUids)

	-- Merged result is delivered inside an oversized Merge Crate AND automatically held in player's hand!
	local crateUid = PlotService.AddCrateToInventory(player, chosenSpec.biomeId, chosenSpec.rarity, chosenSpec.id, crateScale, {
		customSizeRatio = boostedSize,
		customMutation = rolledMut,
		originSource = "Merge",
		parentUids = cleanUids,
	})
	PlotService.RefreshPlotBoardVisuals(player)
	PlotService.BroadcastAllPlotsSync()
	DataService.SyncProfile(player)
	task.spawn(DataService.SaveProfile, player)

	if crateUid then
		player:SetAttribute("HeldItemType", "Crate")
		player:SetAttribute("HeldItemId", crateUid)
		player:SetAttribute("HeldItemSpecies", chosenSpec.id)
		player:SetAttribute("HeldItemMutation", rolledMut)
		player:SetAttribute("HeldItemBiome", chosenSpec.biomeId)
		player:SetAttribute("HeldItemRarity", chosenSpec.rarity)
		player:SetAttribute("HeldItemScale", crateScale)
		player:SetAttribute("HeldItemMerged", true)
		Remotes.Get("CrateDelivered"):FireClient(player, 1, crateUid, true)
		Remotes.Get("PlayWorldVFX"):FireAllClients({
			kind = "MergeBurst",
			userId = player.UserId,
			rarity = chosenSpec.rarity,
			mutation = rolledMut,
			scale = crateScale,
		})

		local mutText = if rolledMut ~= "None" then ("[" .. rolledMut .. "] ") else ""
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("⚡ MERGE CRATE IN HAND! %s%s (+%d%% Size / %.1fkg) — place in Pen to hatch!", mutText, chosenSpec.name, fMeta.sizeGainPct, fMeta.expectedKg),
			GameConfig.MUTATIONS[rolledMut].color
		)
	end
end

function FuseMergeSystem.Init()
	Remotes.Get("RequestMergeAnimals").OnServerEvent:Connect(handleUnifiedMerge)
	Remotes.Get("RequestCrossFuse").OnServerEvent:Connect(handleUnifiedMerge)
end

return FuseMergeSystem
