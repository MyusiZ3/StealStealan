--!strict
-- GameConfig.luau
-- Core tuning constants for Open-Pen Zoo (8->20), Size Ratios, Mutations, & Economy

local GameConfig = {
	MAX_PLAYERS_PER_SERVER = 6,
	PLOT_COUNT = 6,

	-- Open-Pen Capacity (8 initial -> 20 full upgrade, +5 with Extra Capacity Pass)
	PEN = {
		STARTING_CAPACITY = 8,
		MAX_CAPACITY_FREE = 20,
		MAX_CAPACITY_PASS_BONUS = 5,
		UPGRADE_BASE_COST = 600,
		UPGRADE_GROWTH = 3.2,
		INCOME_BONUS_PER_LEVEL = 0.10, -- +10% pen income per upgrade level
		MAX_INVENTORY_FREE = 80,
		MAX_INVENTORY_PASS_BONUS = 50,
	},

	-- Treadmill Upgrades
	TREADMILL = {
		BASE_SPEED_PER_PULSE = 2.0,
		GROWTH_PER_LEVEL = 1.65,
		UPGRADE_BASE_COST = 250,
		UPGRADE_GROWTH = 2.6,
	},

	-- World layout coordinates
	WORLD = {
		SAFE_ZONE_Z_MAX = 150,
		MAX_Z = 2150,
	},

	-- Movement & Anti-Cheat
	SPEED = {
		BASE_WALK_SPEED = 18,
		SLOW_MODE_MULTIPLIER = 0.40,
		STAT_TO_WALKSPEED_LOG_SCALE = 8.5,
		MAX_EFFECTIVE_WALKSPEED = 170,
		ANTI_TELEPORT_TOLERANCE = 1.45,
	},

	-- Economy & Rebirth
	ECONOMY = {
		STARTING_COINS = 150,
		INCOME_TICK_SECONDS = 2,
		REBIRTH_BASE_SPEED = 350,
		REBIRTH_BASE_COINS = 25000,
		REBIRTH_GROWTH = 5.0,
		REBIRTH_INCOME_BONUS = 0.75, -- +75% per rebirth
		FRIEND_BOOST_PER_FRIEND = 0.10,
		MAX_FRIEND_BOOST = 0.50,
	},

	-- Random Animal Size Ratios (Min 0.70x -> Max 3.50x)
	SIZE_BRACKETS = {
		{ name = "Tiny", minRatio = 0.70, maxRatio = 0.89, weight = 20.0 },
		{ name = "Normal", minRatio = 0.90, maxRatio = 1.25, weight = 55.0 },
		{ name = "Big", minRatio = 1.26, maxRatio = 1.75, weight = 18.0 },
		{ name = "Giant", minRatio = 1.76, maxRatio = 2.40, weight = 5.5 },
		{ name = "Titanic", minRatio = 2.41, maxRatio = 3.50, weight = 1.5 },
	},

	-- Rare Mutations & Income Multipliers
	MUTATIONS = {
		None = { id = "None", label = "Normal", weight = 72.0, multiplier = 1.0, color = Color3.fromRGB(220, 226, 232) },
		Albino = { id = "Albino", label = "Albino", weight = 12.0, multiplier = 1.8, color = Color3.fromRGB(248, 250, 255) },
		Golden = { id = "Golden", label = "Golden", weight = 8.0, multiplier = 3.5, color = Color3.fromRGB(255, 206, 56) },
		Diamond = { id = "Diamond", label = "Diamond", weight = 4.5, multiplier = 7.5, color = Color3.fromRGB(92, 224, 255) },
		Neon = { id = "Neon", label = "Neon", weight = 2.2, multiplier = 16.0, color = Color3.fromRGB(68, 255, 162) },
		Rainbow = { id = "Rainbow", label = "Rainbow", weight = 1.0, multiplier = 35.0, color = Color3.fromRGB(255, 108, 236) },
		Celestial = { id = "Celestial", label = "Celestial", weight = 0.3, multiplier = 85.0, color = Color3.fromRGB(164, 96, 255) },
	},

	MUTATION_ORDER = { "None", "Albino", "Golden", "Diamond", "Neon", "Rainbow", "Celestial" },

	UNBOX_SECONDS = {
		Common = 4,
		Uncommon = 8,
		Rare = 15,
		Epic = 25,
		Legendary = 40,
		Mythic = 60,
	},

	RARITY_COLORS = {
		Common = Color3.fromRGB(168, 182, 172),
		Uncommon = Color3.fromRGB(78, 212, 114),
		Rare = Color3.fromRGB(64, 165, 255),
		Epic = Color3.fromRGB(178, 86, 255),
		Legendary = Color3.fromRGB(255, 196, 46),
		Mythic = Color3.fromRGB(255, 68, 128),
	},

	DEFAULT_SETTINGS = {
		musicEnabled = true,
		musicVolume = 0.45,
		sfxEnabled = true,
		sfxVolume = 0.75,
		hideOtherAnimals = false,
		hideOwnAnimals = false,
		lowVFX = false,
	},
}

return GameConfig
