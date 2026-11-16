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
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PassManager = require(script.Parent.PassManager)

local PlotService = {}

local plotOwners: { [number]: Player? } = {} -- plotIndex (1..6) -> Player
local playerPlots: { [number]: number } = {} -- userId -> plotIndex

-- Live event hooks injected by AdminService to avoid circular dependency
local liveGetters = {
	getCashMultiplier = function(): number return 1.0 end,
	getMutationLuckMultiplier = function(): number return 1.0 end,
	getGiantSizeMultiplier = function(): number return 1.0 end,
	isInstantUnbox = function(_player: Player): boolean return false end,
}

function PlotService.RegisterLiveGetters(getters: typeof(liveGetters))
	liveGetters = getters
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

function PlotService.ComputePlayerIncomePerSec(player: Player, profile: Types.PlayerProfileSchema): number
	local baseSum = 0
	for _, uid in ipairs(profile.roamingAnimalUids) do
		local animal = profile.inventoryAnimals[uid]
		if animal then
			baseSum += AnimalConfig.ComputeIncomePerSec(animal)
		end
	end
	local penMult = 1 + (profile.penUpgradeLevel - 1) * GameConfig.PEN.INCOME_BONUS_PER_LEVEL
	local rebirthMult = 1 + profile.rebirths * GameConfig.ECONOMY.REBIRTH_INCOME_BONUS
	local vipMult = if PassManager.OwnsPass(player, "VIP") then 1.5 else 1.0
	local trailMult = 1 + getTrailCashBonus(profile.equippedTrail)
	local indexMult = 1 + getIndexCashBonus(profile)
	local friendMult = 1 + PassManager.GetFriendBoost(player)
	local eventMult = liveGetters.getCashMultiplier()

	return baseSum * penMult * rebirthMult * vipMult * trailMult * indexMult * friendMult * eventMult
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
	local incomePerSec = PlotService.ComputePlayerIncomePerSec(player, profile)
	local maxCap = PlotService.GetMaxPenCapacity(player, profile)

	local signBoard = model:FindFirstChild("OwnerSignBoard")
	updateSignGui(signBoard, player.DisplayName .. "'s ZOO", string.format("Open-Pen (%d/%d Animals)", #profile.roamingAnimalUids, profile.penCapacity))

	local cashPad = model:FindFirstChild("CashCollectorPad")
	updateSignGui(cashPad, "COLLECT: $" .. FormatUtil.Number(profile.unclaimedPenCoins), "$" .. FormatUtil.Number(incomePerSec) .. "/sec")

	local upgradePad = model:FindFirstChild("PenUpgradePad")
	if profile.penCapacity >= maxCap then
		updateSignGui(upgradePad, "PEN MAXED (" .. profile.penCapacity .. ")", "+" .. math.floor((profile.penUpgradeLevel - 1) * 10) .. "% Bonus")
	else
		local cost = PlotService.GetPenUpgradeCost(profile)
		updateSignGui(upgradePad, string.format("UPGRADE PEN (%d/%d)", profile.penCapacity, maxCap), "Next: $" .. FormatUtil.Number(cost))
	end

	local treadmillPad = model:FindFirstChild("TreadmillPad")
	local treadCost = math.floor(GameConfig.TREADMILL.UPGRADE_BASE_COST * math.pow(GameConfig.TREADMILL.UPGRADE_GROWTH, profile.treadmillLevel - 1))
	updateSignGui(treadmillPad, "TREADMILL LV." .. profile.treadmillLevel, "Upgrade: $" .. FormatUtil.Number(treadCost))

	local unboxPad = model:FindFirstChild("CrateUnboxPad")
	local pendingCount = 0
	for _ in pairs(profile.pendingCrates) do
		pendingCount += 1
	end
	updateSignGui(unboxPad, "CRATES READY: " .. pendingCount, "Press E to Drop / Open!")
end

function PlotService.BroadcastAllPlotsSync()
	local payload: { [string]: {
		plotIndex: number,
		ownerUserId: number,
		ownerName: string,
		roamingAnimals: { Types.AnimalInstance },
	} } = {}

	for i = 1, GameConfig.PLOT_COUNT do
		local owner = plotOwners[i]
		local list: { Types.AnimalInstance } = {}
		if owner then
			local prof = DataService.GetProfile(owner)
			if prof then
				for _, uid in ipairs(prof.roamingAnimalUids) do
					local a = prof.inventoryAnimals[uid]
					if a then
						table.insert(list, a)
					end
				end
			end
		end
		payload[tostring(i)] = {
			plotIndex = i,
			ownerUserId = if owner then owner.UserId else 0,
			ownerName = if owner then owner.DisplayName else "Vacant",
			roamingAnimals = list,
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
	forcedMutation: Types.AnimalMutation?
): Types.AnimalInstance?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local spec = AnimalConfig.GetById(speciesId) or AnimalConfig.ALL[1]
	local luckMult = PassManager.GetServerLuckMultiplier() * liveGetters.getMutationLuckMultiplier()
	local sizeRatio = forcedSizeRatio or AnimalConfig.RollSizeRatio(liveGetters.getGiantSizeMultiplier())
	local mutation = forcedMutation or AnimalConfig.RollMutation(luckMult)
	local weightKg = math.floor(spec.baseWeightKg * math.pow(sizeRatio, 2.2) * 10 + 0.5) / 10

	local uid = DataService.NewGuid()
	local animal: Types.AnimalInstance = {
		uid = uid,
		speciesId = spec.id,
		sizeRatio = sizeRatio,
		weightKg = weightKg,
		mutation = mutation,
		locked = (mutation ~= "None" or spec.rarity == "Legendary" or spec.rarity == "Mythic"),
		acquiredAt = os.time(),
	}

	profile.inventoryAnimals[uid] = animal
	PlotService.RegisterAnimalDiscovery(profile, spec.id, sizeRatio, mutation)

	-- Automatically place into Open Pen if there is room!
	if #profile.roamingAnimalUids < profile.penCapacity then
		table.insert(profile.roamingAnimalUids, uid)
	end

	PlotService.RefreshPlotBoardVisuals(player)
	PlotService.BroadcastAllPlotsSync()
	DataService.SyncProfile(player)
	return animal
end

function PlotService.AddPendingCrate(player: Player, biomeId: string, rarity: Types.AnimalRarity, speciesId: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local dur = GameConfig.UNBOX_SECONDS[rarity] or 5
	if liveGetters.isInstantUnbox(player) then
		dur = 0
	end
	local crateUid = DataService.NewGuid()
	local crate: Types.CrateInstance = {
		uid = crateUid,
		biomeId = biomeId,
		rarity = rarity,
		speciesId = speciesId,
		unlockAt = os.time() + dur,
	}
	profile.pendingCrates[crateUid] = crate
	PlotService.RefreshPlotBoardVisuals(player)
	DataService.SyncProfile(player)
end

function PlotService.OpenCrate(player: Player, crateUid: string)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local crate = profile.pendingCrates[crateUid]
	if not crate then
		return
	end
	if os.time() < crate.unlockAt and not liveGetters.isInstantUnbox(player) then
		local rem = crate.unlockAt - os.time()
		Remotes.Get("NotifyClient"):FireClient(player, "Crate unlocks in " .. rem .. "s!", Color3.fromRGB(255, 206, 62))
		return
	end
	profile.pendingCrates[crateUid] = nil
	local animal = PlotService.GrantAnimalToPlayer(player, crate.speciesId, nil, nil)
	if animal then
		local spec = AnimalConfig.GetById(animal.speciesId)
		local mutText = if animal.mutation ~= "None" then ("[" .. animal.mutation .. "] ") else ""
		Remotes.Get("NotifyClient"):FireClient(
			player,
			string.format("Rescued %s%s (%.2fx Size | %.1fkg)!", mutText, spec and spec.name or animal.speciesId, animal.sizeRatio, animal.weightKg),
			GameConfig.RARITY_COLORS[crate.rarity] or Color3.fromRGB(84, 245, 148)
		)
	end
end

function PlotService.AssignPlot(player: Player)
	for i = 1, GameConfig.PLOT_COUNT do
		if plotOwners[i] == nil then
			plotOwners[i] = player
			playerPlots[player.UserId] = i
			local model = PlotService.GetPlotModel(i)
			if model then
				model:SetAttribute("OwnerUserId", player.UserId)
			end
			PlotService.RefreshPlotBoardVisuals(player)
			PlotService.BroadcastAllPlotsSync()
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
			model:SetAttribute("OwnerUserId", 0)
			updateSignGui(model:FindFirstChild("OwnerSignBoard"), "ZOO SANCTUARY #" .. idx, "Vacant Plot")
			updateSignGui(model:FindFirstChild("CashCollectorPad"), "COLLECT CASH: $0", "0/s Pen Income")
		end
		PlotService.BroadcastAllPlotsSync()
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
						return
					end
					PlotService.ClaimPenCoins(player)
				end)
			end

			local upgradePad = plotModel:FindFirstChild("PenUpgradePad")
			local upgPrompt = if upgradePad then upgradePad:FindFirstChild("UpgradePenPrompt") else nil
			if upgPrompt and upgPrompt:IsA("ProximityPrompt") then
				upgPrompt.Triggered:Connect(function(player)
					if playerPlots[player.UserId] ~= pIdx then
						return
					end
					PlotService.UpgradePen(player)
				end)
			end

			local unboxPad = plotModel:FindFirstChild("CrateUnboxPad")
			local unboxPrompt = if unboxPad then unboxPad:FindFirstChild("UnboxPadPrompt") else nil
			if unboxPrompt and unboxPrompt:IsA("ProximityPrompt") then
				unboxPrompt.Triggered:Connect(function(player)
					if playerPlots[player.UserId] ~= pIdx then
						return
					end
					local profile = DataService.GetProfile(player)
					if not profile then
						return
					end
					-- Open any unlocked pending crate
					for uid, crate in pairs(profile.pendingCrates) do
						if os.time() >= crate.unlockAt or liveGetters.isInstantUnbox(player) then
							PlotService.OpenCrate(player, uid)
							return
						end
					end
					Remotes.Get("NotifyClient"):FireClient(player, "Bring a crate from the forest or wait for timer!", Color3.fromRGB(255, 206, 62))
				end)
			end

			local treadPad = plotModel:FindFirstChild("TreadmillPad")
			local treadPrompt = if treadPad then treadPad:FindFirstChild("UpgradeTreadmillPrompt") else nil
			if treadPrompt and treadPrompt:IsA("ProximityPrompt") then
				treadPrompt.Triggered:Connect(function(player)
					if playerPlots[player.UserId] ~= pIdx then
						return
					end
					local prof = DataService.GetProfile(player)
					if not prof then return end
					local cost = math.floor(GameConfig.TREADMILL.UPGRADE_BASE_COST * math.pow(GameConfig.TREADMILL.UPGRADE_GROWTH, prof.treadmillLevel - 1))
					if prof.coins < cost then
						Remotes.Get("NotifyClient"):FireClient(player, "Need $" .. FormatUtil.Number(cost) .. " to upgrade Treadmill!", Color3.fromRGB(255, 96, 96))
						return
					end
					prof.coins -= cost
					prof.treadmillLevel += 1
					PlotService.RefreshPlotBoardVisuals(player)
					DataService.SyncProfile(player)
					Remotes.Get("NotifyClient"):FireClient(player, "Treadmill upgraded to Lv." .. prof.treadmillLevel .. "!", Color3.fromRGB(58, 188, 255))
				end)
			end
		end
	end
end

function PlotService.ClaimPenCoins(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile or profile.unclaimedPenCoins <= 0 then
		return
	end
	local amount = math.floor(profile.unclaimedPenCoins)
	profile.unclaimedPenCoins = 0
	profile.coins += amount
	PlotService.RefreshPlotBoardVisuals(player)
	DataService.SyncProfile(player)
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
		Remotes.Get("NotifyClient"):FireClient(player, "Need $" .. FormatUtil.Number(cost) .. " to upgrade Pen!", Color3.fromRGB(255, 96, 96))
		return
	end
	profile.coins -= cost
	profile.penCapacity += 1
	profile.penUpgradeLevel += 1
	PlotService.RefreshPlotBoardVisuals(player)
	DataService.SyncProfile(player)
	Remotes.Get("NotifyClient"):FireClient(player, string.format("Pen Upgraded to %d/%d Animals (+10%% Income)!", profile.penCapacity, maxCap), Color3.fromRGB(168, 108, 255))
end

function PlotService.Init()
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
		table.sort(list, function(a, b)
			return a.income > b.income
		end)
		table.clear(profile.roamingAnimalUids)
		local limit = math.min(#list, profile.penCapacity)
		for i = 1, limit do
			table.insert(profile.roamingAnimalUids, list[i].uid)
		end
		PlotService.RefreshPlotBoardVisuals(player)
		PlotService.BroadcastAllPlotsSync()
		DataService.SyncProfile(player)
		Remotes.Get("NotifyClient"):FireClient(player, "Equipped Best Animals to your Sanctuary Pen!", Color3.fromRGB(84, 245, 148))
	end)

	-- Income accumulation + auto-unbox tick loop
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
