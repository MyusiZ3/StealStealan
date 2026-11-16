--!strict
-- MonetizationConfig.luau
-- Centralized Game Pass & Developer Product IDs

local MonetizationConfig = {
	GAME_PASSES = {
		VIP = {
			id = 0,
			name = "VIP Ranger Pass",
			priceRobux = 299,
			description = "+50% Cash Income, VIP Golden Name Tag, 1.5x Treadmill Speed, & Golden Safari Jeep.",
		},
		DoubleSpeed = {
			id = 0,
			name = "2x Speed Training",
			priceRobux = 199,
			description = "Permanently doubles Speed gained from Treadmill training.",
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
			description = "Automatically collects zoo pen coins and opens finished crates.",
		},
		ExtraZooCapacity = {
			id = 0,
			name = "Extra Pen Capacity (+5 Max Animals)",
			priceRobux = 199,
			description = "Increases max roaming pen capacity from 20 to 25 and +50 storage slots.",
		},
	},

	DEVELOPER_PRODUCTS = {
		StarterPack = {
			id = 0,
			name = "Starter Ranger Pack",
			priceRobux = 99,
			oneTime = true,
			description = "High-Volt Taser Tether + Mud-Crawler Buggy + Amber Trail + 100K Coins!",
		},
		ServerLuckBoost = {
			id = 0,
			name = "Server Mutation Luck Boost (15m)",
			priceRobux = 75,
			durationSeconds = 900,
			description = "Boosts Rare/Epic/Legendary & Mutation chances for EVERYONE in the server!",
		},
		InstantUnbox = {
			id = 0,
			name = "Instant Unbox Crate",
			priceRobux = 25,
			description = "Immediately open a pending crate in your sanctuary pen.",
		},
		CoinsSmall = { id = 0, name = "Pocket of Coins", priceRobux = 49, baseCoins = 50000 },
		CoinsMedium = { id = 0, name = "Ranger Crate of Coins", priceRobux = 149, baseCoins = 500000 },
		CoinsLarge = { id = 0, name = "Sanctuary Vault of Coins", priceRobux = 399, baseCoins = 5000000 },
	},
}

return MonetizationConfig
