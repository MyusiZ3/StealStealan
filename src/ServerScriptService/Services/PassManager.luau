--!strict
-- PassManager.luau
-- Game Pass caching, Developer Product receipt handling, Friend Boost, & 7-Day Daily Rewards

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MonetizationConfig = require(game.ReplicatedStorage.Config.MonetizationConfig)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local RewardConfig = require(game.ReplicatedStorage.Config.RewardConfig)
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Types = require(game.ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)

local PassManager = {}

local ownershipCache: { [number]: { [string]: boolean } } = {}
local serverLuckBoostExpiresAt = 0

local rewardCallbacks: {
	addCrateToInventory: ((Player, string, Types.AnimalRarity, string, number?, { customSizeRatio: number?, originSource: Types.ItemOriginSource? }?) -> string?)?,
	refreshPlotVisuals: ((Player) -> ())?,
	refreshLeaderboards: (() -> ())?,
} = {}

function PassManager.RegisterRewardCallbacks(cbs: typeof(rewardCallbacks))
	rewardCallbacks = cbs
end

function PassManager.OwnsPass(player: Player, passKey: string): boolean
	local userId = player.UserId
	if not ownershipCache[userId] then
		ownershipCache[userId] = {}
	end
	if ownershipCache[userId][passKey] ~= nil then
		return ownershipCache[userId][passKey]
	end
	local def = (MonetizationConfig.GAME_PASSES :: any)[passKey]
	if not def or not def.id or def.id == 0 then
		ownershipCache[userId][passKey] = false
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, def.id)
	local result = ok and owns == true
	ownershipCache[userId][passKey] = result
	return result
end

function PassManager.GetFriendBoost(player: Player): number
	local count = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and isFriend then
				count += 1
			end
		end
	end
	return math.min(GameConfig.ECONOMY.MAX_FRIEND_BOOST, count * GameConfig.ECONOMY.FRIEND_BOOST_PER_FRIEND)
end

function PassManager.GetServerLuckMultiplier(): number
	if os.time() < serverLuckBoostExpiresAt then
		return 10.0
	end
	return 1.0
end

function PassManager.GetServerLuckRemainingSeconds(): number
	return math.max(0, serverLuckBoostExpiresAt - os.time())
end

local function ensureAfkState(profile: Types.PlayerProfileSchema): { elapsedSeconds: number, claimedTiers: { [string]: boolean } }
	if type(profile.afkRewards) ~= "table" then
		profile.afkRewards = { elapsedSeconds = 0, claimedTiers = {} }
	end
	local state = profile.afkRewards :: { elapsedSeconds: number, claimedTiers: { [string]: boolean } }
	if type(state.claimedTiers) ~= "table" then
		state.claimedTiers = {}
	end
	state.elapsedSeconds = math.max(0, tonumber(state.elapsedSeconds) or 0)
	return state
end

local function grantRewardBundle(player: Player, profile: Types.PlayerProfileSchema, entry: { baseCoins: number, speed: number, biomeId: string?, rarity: Types.AnimalRarity?, speciesId: string?, isOP: boolean? }): (string, string?)
	local mult = 1 + (profile.rebirths or 0) * GameConfig.ECONOMY.REBIRTH_INCOME_BONUS
	local parts: { string } = {}
	local grantedCrateUid: string? = nil
	if entry.baseCoins > 0 then
		local coinsGain = math.floor(entry.baseCoins * mult)
		profile.coins += coinsGain
		table.insert(parts, "+$" .. FormatUtil.Number(coinsGain))
	end
	if entry.speed > 0 then
		profile.speedStat += entry.speed
		table.insert(parts, "+" .. FormatUtil.Number(entry.speed) .. " Spd")
	end
	if entry.biomeId and entry.rarity and entry.speciesId and rewardCallbacks.addCrateToInventory then
		local bonusSize = if entry.isOP then 1.95 else 1.25
		local sc = GameConfig.ComputeCrateScale(entry.rarity, bonusSize)
		grantedCrateUid = rewardCallbacks.addCrateToInventory(player, entry.biomeId, entry.rarity, entry.speciesId, sc, {
			customSizeRatio = bonusSize,
			originSource = "Wild",
		})
		table.insert(parts, tostring(entry.rarity) .. " Crate")
	end
	return table.concat(parts, " & "), grantedCrateUid
end

local function formatWaitTime(secs: number): string
	local s = math.max(1, math.ceil(secs))
	if s >= 3600 then
		local h = math.floor(s / 3600)
		local m = math.floor((s % 3600) / 60)
		return string.format("%dh %dm", h, m)
	elseif s >= 60 then
		local m = math.floor(s / 60)
		local r = s % 60
		return string.format("%dm %ds", m, r)
	end
	return string.format("%ds", s)
end

function PassManager.ClaimDailyReward(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local now = os.time()
	local elapsed = now - profile.dailyReward.lastClaimTime
	if elapsed < 86400 and profile.dailyReward.lastClaimTime > 0 then
		local rem = 86400 - elapsed
		Remotes.Get("NotifyClient"):FireClient(player, "Daily Reward locked! Ready in " .. formatWaitTime(rem) .. ".", Color3.fromRGB(255, 196, 62))
		return
	end
	if elapsed > 86400 * 2 then
		profile.dailyReward.streak = 0
	end
	profile.dailyReward.streak = (profile.dailyReward.streak % #RewardConfig.DAILY) + 1
	profile.dailyReward.lastClaimTime = now

	local reward = RewardConfig.DAILY[profile.dailyReward.streak]
	local summary, crateUid = grantRewardBundle(player, profile, reward)

	if rewardCallbacks.refreshPlotVisuals then
		rewardCallbacks.refreshPlotVisuals(player)
	end
	DataService.SyncProfile(player)
	task.spawn(DataService.SaveProfile, player)
	if crateUid then
		Remotes.Get("CrateDelivered"):FireClient(player, 1, crateUid)
	end
	Remotes.Get("NotifyClient"):FireClient(
		player,
		string.format("Day %d Reward Claimed! %s!", profile.dailyReward.streak, summary),
		Color3.fromRGB(84, 245, 148)
	)
end

function PassManager.ClaimAfkGift(player: Player, tierIdx: number)
	if typeof(tierIdx) ~= "number" or tierIdx < 1 or tierIdx > #RewardConfig.AFK_GIFTS then
		Remotes.Get("NotifyClient"):FireClient(player, "Invalid AFK Gift selection!", Color3.fromRGB(255, 86, 86))
		return
	end
	local idx = math.floor(tierIdx)
	local def = RewardConfig.AFK_GIFTS[idx]
	local profile = DataService.GetProfile(player)
	if not def or not profile then
		return
	end
	local afk = ensureAfkState(profile)
	local key = tostring(idx)
	if afk.claimedTiers[key] then
		Remotes.Get("NotifyClient"):FireClient(player, "AFK Gift (" .. def.timeLabel .. ") already claimed!", Color3.fromRGB(255, 196, 62))
		return
	end
	if afk.elapsedSeconds < def.requiredSeconds then
		local rem = math.ceil(def.requiredSeconds - afk.elapsedSeconds)
		Remotes.Get("NotifyClient"):FireClient(player, "AFK Gift locked! Play " .. formatWaitTime(rem) .. " more to claim.", Color3.fromRGB(255, 112, 92))
		return
	end
	afk.claimedTiers[key] = true
	local summary, crateUid = grantRewardBundle(player, profile, def)
	if rewardCallbacks.refreshPlotVisuals then
		rewardCallbacks.refreshPlotVisuals(player)
	end
	DataService.SyncProfile(player)
	task.spawn(DataService.SaveProfile, player)
	if crateUid then
		Remotes.Get("CrateDelivered"):FireClient(player, 1, crateUid)
	end
	Remotes.Get("NotifyClient"):FireClient(player, string.format("AFK Gift (%s) Claimed: %s!", def.timeLabel, summary), Color3.fromRGB(118, 255, 148))
end

function PassManager.ClaimAllAfkGifts(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local afk = ensureAfkState(profile)
	local claimed = 0
	local allAlreadyClaimed = true
	local lastCrateUid: string? = nil
	local crateCount = 0
	for idx, def in ipairs(RewardConfig.AFK_GIFTS) do
		local key = tostring(idx)
		if not afk.claimedTiers[key] then
			allAlreadyClaimed = false
			if afk.elapsedSeconds >= def.requiredSeconds then
				afk.claimedTiers[key] = true
				local _, cUid = grantRewardBundle(player, profile, def)
				if cUid then
					lastCrateUid = cUid
					crateCount += 1
				end
				claimed += 1
			end
		end
	end
	if claimed > 0 then
		if rewardCallbacks.refreshPlotVisuals then
			rewardCallbacks.refreshPlotVisuals(player)
		end
		DataService.SyncProfile(player)
		task.spawn(DataService.SaveProfile, player)
		if lastCrateUid then
			Remotes.Get("CrateDelivered"):FireClient(player, crateCount, lastCrateUid)
		end
		Remotes.Get("NotifyClient"):FireClient(player, string.format("Claimed %d AFK Gifts!", claimed), Color3.fromRGB(118, 255, 148))
	elseif allAlreadyClaimed then
		Remotes.Get("NotifyClient"):FireClient(player, "All AFK Gifts claimed! Click NEW 2H CYCLE to restart.", Color3.fromRGB(255, 196, 62))
	else
		Remotes.Get("NotifyClient"):FireClient(player, "No AFK Gifts ready yet — wait for the timer!", Color3.fromRGB(255, 196, 62))
	end
end

function PassManager.ResetAfkCycle(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local afk = ensureAfkState(profile)
	for idx = 1, #RewardConfig.AFK_GIFTS do
		if not afk.claimedTiers[tostring(idx)] then
			Remotes.Get("NotifyClient"):FireClient(player, "Claim all 9 AFK Gifts before starting a new 2H cycle!", Color3.fromRGB(255, 196, 62))
			return
		end
	end
	afk.elapsedSeconds = 0
	afk.claimedTiers = {}
	player:SetAttribute("AfkSeconds", 0)
	DataService.SyncProfile(player)
	task.spawn(DataService.SaveProfile, player)
	Remotes.Get("NotifyClient"):FireClient(player, "Started a fresh 2-Hour AFK Gift cycle!", Color3.fromRGB(118, 224, 255))
end

function PassManager.Init()
	Remotes.Get("ClaimDailyReward").OnServerEvent:Connect(function(player)
		PassManager.ClaimDailyReward(player)
	end)
	Remotes.Get("ClaimAfkGift").OnServerEvent:Connect(function(player, tierIdx)
		PassManager.ClaimAfkGift(player, tonumber(tierIdx) or 0)
	end)
	Remotes.Get("ClaimAllAfkGifts").OnServerEvent:Connect(function(player)
		PassManager.ClaimAllAfkGifts(player)
	end)
	Remotes.Get("ResetAfkCycle").OnServerEvent:Connect(function(player)
		PassManager.ResetAfkCycle(player)
	end)

	-- Playtime / AFK timer ticker (1s lightweight attribute updates without spamming DataStore/ProfileSync)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local prof = DataService.GetProfile(p)
				if prof then
					local afk = ensureAfkState(prof)
					afk.elapsedSeconds += 1
					p:SetAttribute("AfkSeconds", afk.elapsedSeconds)
				end
			end
		end
	end)

	Remotes.Get("PromptGamePass").OnServerEvent:Connect(function(player, passKey)
		if typeof(passKey) ~= "string" then
			return
		end
		local def = (MonetizationConfig.GAME_PASSES :: any)[passKey]
		if not def then
			Remotes.Get("NotifyClient"):FireClient(player, "Unknown Game Pass!", Color3.fromRGB(255, 86, 86))
			return
		end
		if def.id == 0 then
			Remotes.Get("NotifyClient"):FireClient(player, string.format("Purchase Unavailable: %s (Robux Pass ID not configured yet)", def.name), Color3.fromRGB(255, 112, 92))
			return
		end
		if PassManager.OwnsPass(player, passKey) then
			Remotes.Get("NotifyClient"):FireClient(player, string.format("You already own %s!", def.name), Color3.fromRGB(255, 198, 62))
			return
		end
		local ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, def.id)
		end)
		if not ok then
			Remotes.Get("NotifyClient"):FireClient(player, "Could not open Robux purchase prompt — please try again!", Color3.fromRGB(255, 86, 86))
		end
	end)

	Remotes.Get("PromptProduct").OnServerEvent:Connect(function(player, prodKey)
		if typeof(prodKey) ~= "string" then
			return
		end
		local prof = DataService.GetProfile(player)
		local trailDef = (MonetizationConfig.TRAIL_PRODUCTS :: any)[prodKey]
		if trailDef then
			if prof and prof.ownedTrails[trailDef.trailId] then
				Remotes.Get("NotifyClient"):FireClient(player, "You already own this Trail!", Color3.fromRGB(255, 198, 62))
				return
			end
			if (trailDef.passId or 0) ~= 0 then
				local ok = pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, trailDef.passId)
				end)
				if not ok then
					Remotes.Get("NotifyClient"):FireClient(player, "Could not open Robux purchase prompt — please try again!", Color3.fromRGB(255, 86, 86))
				end
				return
			elseif (trailDef.id or 0) ~= 0 then
				local ok = pcall(function()
					MarketplaceService:PromptProductPurchase(player, trailDef.id)
				end)
				if not ok then
					Remotes.Get("NotifyClient"):FireClient(player, "Could not open Robux purchase prompt — please try again!", Color3.fromRGB(255, 86, 86))
				end
				return
			end
			Remotes.Get("NotifyClient"):FireClient(player, string.format("Purchase Unavailable: %s Robux ID not configured yet!", prodKey), Color3.fromRGB(255, 112, 92))
			return
		end
		local def = (MonetizationConfig.DEVELOPER_PRODUCTS :: any)[prodKey]
		if not def then
			Remotes.Get("NotifyClient"):FireClient(player, "Purchase Unavailable: Item not found!", Color3.fromRGB(255, 86, 86))
			return
		end
		if def.oneTime and prodKey == "StarterPack" and prof then
			if prof.ownedLassos.TaserTether and prof.ownedVehicles.MudBuggy and prof.ownedTrails.SparkTrail then
				Remotes.Get("NotifyClient"):FireClient(player, "You already own the Starter Ranger Pack!", Color3.fromRGB(255, 198, 62))
				return
			end
		end
		if def.id == 0 then
			Remotes.Get("NotifyClient"):FireClient(player, string.format("Purchase Unavailable: %s (Robux ID not configured yet)", def.name), Color3.fromRGB(255, 112, 92))
			return
		end
		local ok = pcall(function()
			MarketplaceService:PromptProductPurchase(player, def.id)
		end)
		if not ok then
			Remotes.Get("NotifyClient"):FireClient(player, "Could not open Robux purchase prompt — please try again!", Color3.fromRGB(255, 86, 86))
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			Remotes.Get("NotifyClient"):FireClient(player, "Robux purchase cancelled or not completed.", Color3.fromRGB(255, 168, 82))
			return
		end
		ownershipCache[player.UserId] = ownershipCache[player.UserId] or {}
		for key, def in pairs(MonetizationConfig.GAME_PASSES) do
			if def.id == passId then
				ownershipCache[player.UserId][key] = true
				Remotes.Get("NotifyClient"):FireClient(player, "Unlocked Game Pass: " .. def.name .. "!", Color3.fromRGB(84, 245, 148))
			end
		end
		local prof = DataService.GetProfile(player)
		if prof and MonetizationConfig.TRAIL_PRODUCTS then
			for _, tDef in pairs(MonetizationConfig.TRAIL_PRODUCTS :: any) do
				if tDef.passId and tDef.passId == passId then
					prof.ownedTrails[tDef.trailId] = true
					prof.equippedTrail = tDef.trailId
					Remotes.Get("NotifyClient"):FireClient(player, "Unlocked Trail: " .. tDef.trailId .. "!", Color3.fromRGB(0, 224, 255))
				end
			end
		end
		DataService.SyncProfile(player)
	end)

	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, isPurchased)
			if not isPurchased then
				local p = Players:GetPlayerByUserId(userId)
				if p then
					Remotes.Get("NotifyClient"):FireClient(p, "Robux purchase cancelled or not completed.", Color3.fromRGB(255, 168, 82))
				end
			end
		end)
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local prodId = receiptInfo.ProductId
		if prodId == MonetizationConfig.DEVELOPER_PRODUCTS.ServerLuckBoost.id and prodId ~= 0 then
			serverLuckBoostExpiresAt = os.time() + 900
			Remotes.Get("GlobalEventBanner"):FireAllClients(player.Name .. " activated 10x Server Mutation Luck (15m)!", Color3.fromRGB(224, 92, 255), 8)
		elseif prodId == MonetizationConfig.DEVELOPER_PRODUCTS.SkipRebirth.id and prodId ~= 0 then
			profile.rebirths += 1
			if rewardCallbacks.refreshPlotVisuals then
				rewardCallbacks.refreshPlotVisuals(player)
			end
			if rewardCallbacks.refreshLeaderboards then
				task.spawn(rewardCallbacks.refreshLeaderboards)
			end
			Remotes.Get("NotifyClient"):FireClient(player, string.format("SKIPPED REBIRTH #%d (Kept All Cash & Stats!)", profile.rebirths), Color3.fromRGB(255, 118, 224))
		elseif prodId == MonetizationConfig.DEVELOPER_PRODUCTS.StarterPack.id and prodId ~= 0 then
			profile.ownedLassos.TaserTether = true
			profile.equippedLasso = "TaserTether"
			profile.ownedVehicles.MudBuggy = true
			profile.equippedVehicle = "MudBuggy"
			profile.ownedTrails.SparkTrail = true
			profile.equippedTrail = "SparkTrail"
			profile.coins += 100000
			Remotes.Get("NotifyClient"):FireClient(player, "Unlocked Starter Ranger Pack (+$100K & Gear)!", Color3.fromRGB(84, 245, 148))
		else
			local granted = false
			if MonetizationConfig.TRAIL_PRODUCTS then
				for _, tDef in pairs(MonetizationConfig.TRAIL_PRODUCTS :: any) do
					if tDef.id == prodId and prodId ~= 0 then
						profile.ownedTrails[tDef.trailId] = true
						profile.equippedTrail = tDef.trailId
						granted = true
						Remotes.Get("NotifyClient"):FireClient(player, "Unlocked Trail: " .. tDef.trailId .. "!", Color3.fromRGB(0, 224, 255))
						break
					end
				end
			end
			if not granted then
				for _, def in pairs(MonetizationConfig.DEVELOPER_PRODUCTS) do
					if def.id == prodId and (def :: any).baseCoins then
						local mult = 1 + profile.rebirths * GameConfig.ECONOMY.REBIRTH_INCOME_BONUS
						local coinsGain = math.floor((def :: any).baseCoins * mult)
						profile.coins += coinsGain
						Remotes.Get("NotifyClient"):FireClient(player, string.format("Purchased %s (+$%s)!", def.name, FormatUtil.Number(coinsGain)), Color3.fromRGB(84, 245, 148))
					end
				end
			end
		end
		DataService.SyncProfile(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	Players.PlayerRemoving:Connect(function(player)
		ownershipCache[player.UserId] = nil
	end)
end

return PassManager
