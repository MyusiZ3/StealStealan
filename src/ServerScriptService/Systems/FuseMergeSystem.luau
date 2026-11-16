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

local function getNextMutation(current: Types.AnimalMutation): Types.AnimalMutation?
	for idx, m in ipairs(GameConfig.MUTATION_ORDER) do
		if m == current and idx < #GameConfig.MUTATION_ORDER then
			return GameConfig.MUTATION_ORDER[idx + 1] :: Types.AnimalMutation
		end
	end
	return nil
end

local function removeAnimalFromPenAndInventory(profile: Types.PlayerProfileSchema, uid: string)
	profile.inventoryAnimals[uid] = nil
	for i, rUid in ipairs(profile.roamingAnimalUids) do
		if rUid == uid then
			table.remove(profile.roamingAnimalUids, i)
			break
		end
	end
end

function FuseMergeSystem.Init()
	Remotes.Get("RequestMergeAnimals").OnServerEvent:Connect(function(player, uidList)
		if type(uidList) ~= "table" or #uidList ~= 3 then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end

		local seen: { [string]: boolean } = {}
		local animals: { Types.AnimalInstance } = {}
		for _, uid in ipairs(uidList) do
			if typeof(uid) ~= "string" or seen[uid] then return end
			seen[uid] = true
			local a = profile.inventoryAnimals[uid]
			if not a then return end
			table.insert(animals, a)
		end

		local firstSpecies = animals[1].speciesId
		local firstMut = animals[1].mutation
		local bestSize = animals[1].sizeRatio
		for i = 2, 3 do
			if animals[i].speciesId ~= firstSpecies or animals[i].mutation ~= firstMut then
				Remotes.Get("NotifyClient"):FireClient(player, "Merge requires 3 identical species with the same mutation!", Color3.fromRGB(255, 96, 96))
				return
			end
			if animals[i].sizeRatio > bestSize then
				bestSize = animals[i].sizeRatio
			end
		end

		local nextMut = getNextMutation(firstMut)
		if not nextMut then
			Remotes.Get("NotifyClient"):FireClient(player, "Already at max Celestial mutation!", Color3.fromRGB(255, 206, 62))
			return
		end

		for _, uid in ipairs(uidList) do
			removeAnimalFromPenAndInventory(profile, uid)
		end

		local merged = PlotService.GrantAnimalToPlayer(player, firstSpecies, math.min(3.8, bestSize * 1.08), nextMut)
		if merged then
			local spec = AnimalConfig.GetById(firstSpecies)
			Remotes.Get("NotifyClient"):FireClient(
				player,
				string.format("MERGED! %s evolved to [%s] (%.2fx Size)!", spec and spec.name or firstSpecies, nextMut, merged.sizeRatio),
				GameConfig.MUTATIONS[nextMut].color
			)
		end
	end)

	Remotes.Get("RequestCrossFuse").OnServerEvent:Connect(function(player, uidList)
		if type(uidList) ~= "table" or #uidList ~= 3 then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end

		local seen: { [string]: boolean } = {}
		local biomePool: { string } = {}
		for _, uid in ipairs(uidList) do
			if typeof(uid) ~= "string" or seen[uid] then return end
			seen[uid] = true
			local a = profile.inventoryAnimals[uid]
			if not a then return end
			local spec = AnimalConfig.GetById(a.speciesId)
			table.insert(biomePool, spec and spec.biomeId or "PineWoods")
		end

		for _, uid in ipairs(uidList) do
			removeAnimalFromPenAndInventory(profile, uid)
		end

		local chosenBiome = biomePool[math.random(1, #biomePool)]
		local rolledSpec = AnimalConfig.RollSpeciesForBiome(chosenBiome, 6.0)
		local rolledMut = AnimalConfig.RollMutation(8.0)
		local rolledSize = AnimalConfig.RollSizeRatio(4.0)

		local created = PlotService.GrantAnimalToPlayer(player, rolledSpec.id, rolledSize, rolledMut)
		if created then
			Remotes.Get("NotifyClient"):FireClient(
				player,
				string.format("CROSS-FUSE SUCCESS! Got [%s] %s (%.2fx)!", rolledMut, rolledSpec.name, created.sizeRatio),
				Color3.fromRGB(196, 92, 255)
			)
		end
	end)
end

return FuseMergeSystem
