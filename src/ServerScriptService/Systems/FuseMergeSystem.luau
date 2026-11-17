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

local RARITY_RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
}

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

	-- Acquire per-player + per-UID transaction lock (blocks race-condition / duplicate UID spam)
	if not DataService.AcquireTransactionLock(player.UserId, cleanUids) then
		return
	end

	local animals: { Types.AnimalInstance } = {}
	local forecastInputs: { { sizeRatio: number, mutation: string } } = {}
	local candidateSpecs: { Types.AnimalSpeciesDefinition } = {}

	for _, uid in ipairs(cleanUids) do
		local a = profile.inventoryAnimals[uid]
		if not a or DataService.IsUidConsumed(profile, uid) then
			DataService.ReleaseTransactionLock(player.UserId, cleanUids)
			return
		end
		table.insert(animals, a)
		table.insert(forecastInputs, { sizeRatio = a.sizeRatio, mutation = a.mutation })
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

	local boostedSize, crateScale, chances = GameConfig.ComputeMergeForecast(forecastInputs)
	local rolledMut = rollForecastMutation(chances)

	-- Pick species weighted slightly toward higher rarity inputs (or identical if all match)
	local totalRank = 0
	for _, sp in ipairs(candidateSpecs) do
		totalRank += (RARITY_RANK[sp.rarity] or 1)
	end
	local spRoll = math.random() * math.max(1, totalRank)
	local spAcc = 0
	local chosenSpec = candidateSpecs[1]
	for _, sp in ipairs(candidateSpecs) do
		spAcc += (RARITY_RANK[sp.rarity] or 1)
		if spRoll <= spAcc then
			chosenSpec = sp
			break
		end
	end

	-- Consume all input pets & record their UIDs in consumedUids tombstone list FIRST!
	for _, uid in ipairs(cleanUids) do
		removeAnimalFromPenAndInventory(profile, uid)
		DataService.MarkUidConsumed(profile, uid)
	end
	DataService.ReleaseTransactionLock(player.UserId, cleanUids)

	-- Merged result is delivered inside an oversized Crate in player's Backpack/Hotbar to hatch!
	local crateUid = PlotService.AddCrateToInventory(player, chosenSpec.biomeId, chosenSpec.rarity, chosenSpec.id, crateScale, {
		customSizeRatio = boostedSize,
		customMutation = rolledMut,
		originSource = "Merge",
		parentUids = cleanUids,
	})
	PlotService.RefreshPlotBoardVisuals(player)
	PlotService.BroadcastAllPlotsSync()
	DataService.SyncProfile(player)

	if crateUid then
		local mutText = if rolledMut ~= "None" then ("[" .. rolledMut .. "] ") else ""
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("MERGED! %s%s Crate (%.2fx Size) added to your Backpack — place in Pen to hatch!", mutText, chosenSpec.name, boostedSize),
			GameConfig.MUTATIONS[rolledMut].color
		)
	end
end

function FuseMergeSystem.Init()
	Remotes.Get("RequestMergeAnimals").OnServerEvent:Connect(handleUnifiedMerge)
	Remotes.Get("RequestCrossFuse").OnServerEvent:Connect(handleUnifiedMerge)
end

return FuseMergeSystem
