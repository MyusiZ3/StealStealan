--!strict
-- PassManager.luau
-- Game Pass caching, Developer Product receipt handling, Friend Boost, & 7-Day Daily Rewards

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MonetizationConfig = require(game.ReplicatedStorage.Config.MonetizationConfig)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PassManager = {}

local ownershipCache: { [number]: { [string]: boolean } } = {}
local serverLuckBoostExpiresAt = 0

local DAILY_LADDER = {
	{ coins = 500, speed = 25 },
	{ coins = 2500, speed = 60 },
	{ coins = 12000, speed = 120 },
	{ coins = 65000, speed = 250 },
	{ coins = 350000, speed = 500 },
	{ coins = 2500000, speed = 1000 },
	{ coins = 25000000, speed = 2500 },
}

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

function PassManager.ClaimDailyReward(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local now = os.time()
	local elapsed = now - profile.dailyReward.lastClaimTime
	if elapsed < 86400 and profile.dailyReward.lastClaimTime > 0 then
		local rem = 86400 - elapsed
		Remotes.Get("NotifyClient"):FireClient(player, "Daily reward ready in " .. tostring(math.ceil(rem / 60)) .. "m!", Color3.fromRGB(255, 196, 62))
		return
	end
	if elapsed > 86400 * 2 then
		profile.dailyReward.streak = 0
	end
	profile.dailyReward.streak = (profile.dailyReward.streak % #DAILY_LADDER) + 1
	profile.dailyReward.lastClaimTime = now

	local reward = DAILY_LADDER[profile.dailyReward.streak]
	local mult = 1 + profile.rebirths * GameConfig.ECONOMY.REBIRTH_INCOME_BONUS
	local coinsGain = math.floor(reward.coins * mult)
	profile.coins += coinsGain
	profile.speedStat += reward.speed

	DataService.SyncProfile(player)
	Remotes.Get("NotifyClient"):FireClient(
		player,
		string.format("Day %d Reward Claimed! +%d Coins & +%d Speed!", profile.dailyReward.streak, coinsGain, reward.speed),
		Color3.fromRGB(84, 245, 148)
	)
end

function PassManager.Init()
	Remotes.Get("ClaimDailyReward").OnServerEvent:Connect(function(player)
		PassManager.ClaimDailyReward(player)
	end)

	Remotes.Get("PromptGamePass").OnServerEvent:Connect(function(player, passKey)
		if typeof(passKey) ~= "string" then
			return
		end
		local def = (MonetizationConfig.GAME_PASSES :: any)[passKey]
		if not def or def.id == 0 then
			Remotes.Get("NotifyClient"):FireClient(player, "Game Pass ID not published yet (Studio Preview).", Color3.fromRGB(255, 196, 62))
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, def.id)
	end)

	Remotes.Get("PromptProduct").OnServerEvent:Connect(function(player, prodKey)
		if typeof(prodKey) ~= "string" then
			return
		end
		local def = (MonetizationConfig.DEVELOPER_PRODUCTS :: any)[prodKey]
		if not def or def.id == 0 then
			Remotes.Get("NotifyClient"):FireClient(player, "Developer Product ID not published yet (Studio Preview).", Color3.fromRGB(255, 196, 62))
			return
		end
		MarketplaceService:PromptProductPurchase(player, def.id)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		ownershipCache[player.UserId] = ownershipCache[player.UserId] or {}
		for key, def in pairs(MonetizationConfig.GAME_PASSES) do
			if def.id == passId then
				ownershipCache[player.UserId][key] = true
			end
		end
		DataService.SyncProfile(player)
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
		elseif prodId == MonetizationConfig.DEVELOPER_PRODUCTS.StarterPack.id and prodId ~= 0 then
			profile.ownedLassos.TaserTether = true
			profile.equippedLasso = "TaserTether"
			profile.ownedVehicles.MudBuggy = true
			profile.equippedVehicle = "MudBuggy"
			profile.ownedTrails.SparkTrail = true
			profile.equippedTrail = "SparkTrail"
			profile.coins += 100000
		else
			for _, def in pairs(MonetizationConfig.DEVELOPER_PRODUCTS) do
				if def.id == prodId and (def :: any).baseCoins then
					local mult = 1 + profile.rebirths * GameConfig.ECONOMY.REBIRTH_INCOME_BONUS
					profile.coins += math.floor((def :: any).baseCoins * mult)
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
