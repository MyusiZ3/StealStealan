--!strict
-- EconomyService.luau
-- Handles 10 Lasso Shop, 10 Trail Shop, 6 Vehicle Garage, Treadmill Upgrades, Sell/Lock Animal, Index Rewards, & Rebirth

local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local LassoConfig = require(game.ReplicatedStorage.Config.LassoConfig)
local TrailConfig = require(game.ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(game.ReplicatedStorage.Config.VehicleConfig)
local AnimalConfig = require(game.ReplicatedStorage.Config.AnimalConfig)
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)

local EconomyService = {}

local function findById(list: { any }, id: string): any?
	for _, item in ipairs(list) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function EconomyService.GetRebirthRequirements(rebirths: number): (number, number)
	local reqSpeed = math.floor(GameConfig.ECONOMY.REBIRTH_BASE_SPEED * math.pow(2.1, rebirths))
	local reqCoins = math.floor(GameConfig.ECONOMY.REBIRTH_BASE_COINS * math.pow(GameConfig.ECONOMY.REBIRTH_GROWTH, rebirths))
	return reqSpeed, reqCoins
end

function EconomyService.Init()
	Remotes.Get("BuyLasso").OnServerEvent:Connect(function(player, lassoId)
		if typeof(lassoId) ~= "string" then return end
		local def = findById(LassoConfig, lassoId)
		local profile = DataService.GetProfile(player)
		if not def or not profile then return end
		if profile.ownedLassos[lassoId] then
			profile.equippedLasso = lassoId
			DataService.SyncProfile(player)
			return
		end
		if profile.coins < def.cost then
			Remotes.Get("NotifyClient"):FireClient(player, "Need $" .. FormatUtil.Number(def.cost) .. " for " .. def.name, Color3.fromRGB(255, 96, 96))
			return
		end
		profile.coins -= def.cost
		profile.ownedLassos[lassoId] = true
		profile.equippedLasso = lassoId
		AnalyticsTracker.LogEconomy(player, false, "Coins", def.cost, profile.coins, "Shop", "Lasso_" .. lassoId)
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Equipped " .. def.name .. "!", Color3.fromRGB(84, 245, 148))
	end)

	Remotes.Get("EquipLasso").OnServerEvent:Connect(function(player, lassoId)
		if typeof(lassoId) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if profile and profile.ownedLassos[lassoId] then
			profile.equippedLasso = lassoId
			DataService.SyncProfile(player)
		end
	end)

	Remotes.Get("BuyTrail").OnServerEvent:Connect(function(player, trailId)
		if typeof(trailId) ~= "string" then return end
		local def = findById(TrailConfig, trailId)
		local profile = DataService.GetProfile(player)
		if not def or not profile then return end
		if profile.ownedTrails[trailId] then
			profile.equippedTrail = trailId
			DataService.SyncProfile(player)
			return
		end
		if profile.coins < def.cost then
			Remotes.Get("NotifyClient"):FireClient(player, "Need $" .. FormatUtil.Number(def.cost) .. " for " .. def.name, Color3.fromRGB(255, 96, 96))
			return
		end
		profile.coins -= def.cost
		profile.ownedTrails[trailId] = true
		profile.equippedTrail = trailId
		AnalyticsTracker.LogEconomy(player, false, "Coins", def.cost, profile.coins, "Shop", "Trail_" .. trailId)
		PlotService.RefreshPlotBoardVisuals(player)
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Equipped " .. def.name .. " (" .. def.speedMultiplier .. "x Speed)!", Color3.fromRGB(0, 224, 255))
	end)

	Remotes.Get("EquipTrail").OnServerEvent:Connect(function(player, trailId)
		if typeof(trailId) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if profile and profile.ownedTrails[trailId] then
			profile.equippedTrail = trailId
			PlotService.RefreshPlotBoardVisuals(player)
			DataService.SyncProfile(player)
		end
	end)

	Remotes.Get("BuyVehicle").OnServerEvent:Connect(function(player, vehicleId)
		if typeof(vehicleId) ~= "string" then return end
		local def = findById(VehicleConfig, vehicleId)
		local profile = DataService.GetProfile(player)
		if not def or not profile then return end
		if profile.ownedVehicles[vehicleId] then
			profile.equippedVehicle = vehicleId
			PlotService.RefreshPlotBoardVisuals(player)
			DataService.SyncProfile(player)
			return
		end
		if profile.coins < def.cost then
			Remotes.Get("NotifyClient"):FireClient(player, "Need $" .. FormatUtil.Number(def.cost) .. " for " .. def.name, Color3.fromRGB(255, 96, 96))
			return
		end
		profile.coins -= def.cost
		profile.ownedVehicles[vehicleId] = true
		profile.equippedVehicle = vehicleId
		AnalyticsTracker.LogEconomy(player, false, "Coins", def.cost, profile.coins, "Shop", "Vehicle_" .. vehicleId)
		PlotService.RefreshPlotBoardVisuals(player)
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Unlocked " .. def.name .. "!", Color3.fromRGB(84, 245, 148))
	end)

	Remotes.Get("EquipVehicle").OnServerEvent:Connect(function(player, vehicleId)
		if typeof(vehicleId) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if profile and profile.ownedVehicles[vehicleId] then
			profile.equippedVehicle = vehicleId
			PlotService.RefreshPlotBoardVisuals(player)
			DataService.SyncProfile(player)
		end
	end)

	Remotes.Get("UpgradeTreadmill").OnServerEvent:Connect(function(player)
		PlotService.UpgradeTreadmill(player)
	end)

	Remotes.Get("ToggleLockAnimal").OnServerEvent:Connect(function(player, animalUid)
		if typeof(animalUid) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local animal = profile.inventoryAnimals[animalUid]
		if animal then
			animal.locked = not animal.locked
			DataService.SyncProfile(player)
		end
	end)

	Remotes.Get("SellAnimal").OnServerEvent:Connect(function(player, animalUid)
		if typeof(animalUid) ~= "string" or animalUid == "" then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		if DataService.IsUidConsumed(profile, animalUid) then
			profile.inventoryAnimals[animalUid] = nil
			return
		end
		if not DataService.AcquireTransactionLock(player.UserId, { animalUid }) then
			return
		end
		local animal = profile.inventoryAnimals[animalUid]
		if not animal then
			DataService.ReleaseTransactionLock(player.UserId, { animalUid })
			return
		end
		if animal.locked then
			DataService.ReleaseTransactionLock(player.UserId, { animalUid })
			Remotes.Get("NotifyClient"):FireClient(player, "Animal is locked! Unlock it before selling.", Color3.fromRGB(255, 196, 62))
			return
		end
		local sellValue = math.floor(AnimalConfig.ComputeIncomePerSec(animal) * 35)
		-- Consume pet & record tombstone FIRST before granting coins
		profile.inventoryAnimals[animalUid] = nil
		for i = #profile.roamingAnimalUids, 1, -1 do
			if profile.roamingAnimalUids[i] == animalUid then
				table.remove(profile.roamingAnimalUids, i)
			end
		end
		DataService.MarkUidConsumed(profile, animalUid)
		profile.coins += sellValue
		DataService.ReleaseTransactionLock(player.UserId, { animalUid })

		PlotService.RefreshPlotBoardVisuals(player)
		PlotService.BroadcastAllPlotsSync()
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Sold animal for $" .. FormatUtil.Number(sellValue), Color3.fromRGB(84, 245, 148))
	end)

	Remotes.Get("ClaimIndexReward").OnServerEvent:Connect(function(player, speciesId)
		if typeof(speciesId) ~= "string" then return end
		local profile = DataService.GetProfile(player)
		local spec = AnimalConfig.GetById(speciesId)
		if not profile or not spec then return end
		local entry = profile.discoveredIndex[speciesId]
		if not entry or entry.rewardClaimed then return end
		entry.rewardClaimed = true
		local rewardCoins = math.floor(spec.baseIncomePerSec * 120)
		profile.coins += rewardCoins
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, string.format("Index Claimed (#%02d %s): +$%s!", spec.indexNumber, spec.name, FormatUtil.Number(rewardCoins)), Color3.fromRGB(255, 214, 72))
	end)

	Remotes.Get("ClaimAllIndexRewards").OnServerEvent:Connect(function(player)
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local totalCoins = 0
		local claimed = 0
		for speciesId, entry in pairs(profile.discoveredIndex) do
			if not entry.rewardClaimed then
				local spec = AnimalConfig.GetById(speciesId)
				if spec then
					entry.rewardClaimed = true
					totalCoins += math.floor(spec.baseIncomePerSec * 120)
					claimed += 1
				end
			end
		end
		-- Check zone 100% completions
		for _, biomeId in ipairs({ "PineWoods", "MangroveSwamp", "SavannaCamp", "AlpinePeaks", "VolcanicJungle" }) do
			if not profile.zoneIndexBonusesClaimed[biomeId] then
				local pool = AnimalConfig.GetByBiome(biomeId)
				local allFound = #pool > 0
				for _, spec in ipairs(pool) do
					if not profile.discoveredIndex[spec.id] then
						allFound = false
						break
					end
				end
				if allFound then
					profile.zoneIndexBonusesClaimed[biomeId] = true
					if biomeId == "SavannaCamp" then
						profile.penCapacity = math.min(PlotService.GetMaxPenCapacity(player, profile), profile.penCapacity + 1)
					end
					Remotes.Get("NotifyClient"):FireClient(player, "ZONE INDEX 100% COMPLETE: " .. biomeId .. " Permanent Bonus Unlocked!", Color3.fromRGB(255, 112, 245))
				end
			end
		end
		if claimed > 0 then
			profile.coins += totalCoins
			DataService.SyncProfile(player)
			Remotes.Get("NotifyClient"):FireClient(player, string.format("Claimed %d Index Rewards (+$%s)!", claimed, FormatUtil.Number(totalCoins)), Color3.fromRGB(255, 214, 72))
		end
	end)

	Remotes.Get("RequestRebirth").OnServerEvent:Connect(function(player)
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local reqSpeed, reqCoins = EconomyService.GetRebirthRequirements(profile.rebirths)
		if profile.speedStat < reqSpeed or profile.coins < reqCoins then
			Remotes.Get("NotifyClient"):FireClient(
				player,
				string.format("Need %s Speed & $%s Coins to Rebirth!", FormatUtil.Number(reqSpeed), FormatUtil.Number(reqCoins)),
				Color3.fromRGB(255, 96, 96)
			)
			return
		end
		profile.rebirths += 1
		-- Rebirth only resets Coins (preserves Speed, Pets, Crates, Tools, and Upgrades!)
		profile.coins = 0
		PlotService.RefreshPlotBoardVisuals(player)
		DataService.SyncProfile(player)
		task.spawn(LeaderboardService.RefreshGlobalLeaderboards)
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("REBIRTH %d COMPLETE! Only Coins reset — Permanent +%d%% Cash Bonus!", profile.rebirths, profile.rebirths * 75),
			Color3.fromRGB(255, 86, 178)
		)
	end)
end

return EconomyService
