--!strict
-- MonetizationConfig.luau
-- Centralized Game Pass & Developer Product IDs (replace 0s with live IDs after Creator Dashboard / Open Cloud publish)

local MonetizationConfig = {
	GAME_PASSES = {
		VIP = {
			id = 0,
			name = "VIP Ranger Pass",
			priceRobux = 299,
			description = "+50% Cash Income, Golden Name Tag, VIP Dyno Lounge (1.5x Speed), & Golden Safari Jeep.",
		},
		DoubleSpeed = {
			id = 0,
			name = "2x Speed Training",
			priceRobux = 199,
			description = "Permanently doubles Speed EXP gained from Dyno & Mount training.",
		},
		DoublePull = {
			id = 0,
			name = "2x Lasso Pull Power",
			priceRobux = 249,
			description = "Doubles your Lasso Pull Power to extract buried crates twice as fast.",
		},
		DualTowHook = {
			id = 0,
			name = "Dual Tow Hook (+1 Crate)",
			priceRobux = 349,
			description = "Tow up to 2 animal crates at the same time behind your vehicle!",
		},
		AutoUnboxCollect = {
			id = 0,
			name = "Auto-Unbox & Collect",
			priceRobux = 149,
			description = "Automatically collects zoo stall coins and opens finished crates.",
		},
		ExtraZooCapacity = {
			id = 0,
			name = "Extra Zoo Capacity",
			priceRobux = 199,
			description = "Unlocks +6 maximum Zoo enclosure stalls and +50 storage slots.",
		},
	},

	DEVELOPER_PRODUCTS = {
		StarterPack = {
			id = 0,
			name = "Starter Ranger Pack",
			priceRobux = 99,
			oneTime = true,
			description = "Steel-Core Cable Lasso + Mud-Crawler Buggy + 5,000 Coins!",
		},
		ServerLuckBoost = {
			id = 0,
			name = "Server Crate Luck Boost (15m)",
			priceRobux = 75,
			durationSeconds = 900,
			description = "Boosts Rare/Epic/Legendary crate spawn chances for EVERYONE in the server!",
		},
		InstantUnbox = {
			id = 0,
			name = "Instant Unbox Crate",
			priceRobux = 25,
			description = "Immediately open a pending crate in your sanctuary stall.",
		},
		CoinsSmall = { id = 0, name = "Pocket of Coins", priceRobux = 49, baseCoins = 2500 },
		CoinsMedium = { id = 0, name = "Ranger Crate of Coins", priceRobux = 149, baseCoins = 12000 },
		CoinsLarge = { id = 0, name = "Sanctuary Vault of Coins", priceRobux = 399, baseCoins = 45000 },
	},
}

return MonetizationConfig
