--!strict
-- GameConfig.luau
-- Core tuning constants and server limits for Wild Rescue: Poacher Run

local GameConfig = {
	MAX_PLAYERS_PER_SERVER = 6,
	PLOT_COUNT = 6,
	STARTING_STALLS = 4,
	MAX_STALLS_FREE = 14,
	MAX_STALLS_VIP_BONUS = 6, -- up to 20 total with Extra Zoo Capacity pass

	-- World layout coordinates (studs along Z axis)
	WORLD = {
		ROAD_WIDTH = 44,
		BIOME_WIDTH = 220,
		SAFE_ZONE_Z_MIN = -140,
		SAFE_ZONE_Z_MAX = 150,
		PLOT_SPACING_Z = 76,
		PLOT_OFFSET_X = 62,
		STUD_SIZE = 4,
	},

	-- Speed & Movement
	SPEED = {
		BASE_WALK_SPEED = 18,
		SLOW_MODE_MULTIPLIER = 0.42, -- Precision brake mode
		STAT_TO_WALKSPEED_SCALE = 0.08,
		MAX_EFFECTIVE_SPEED = 220,
		ANTI_TELEPORT_TOLERANCE = 1.35,
	},

	-- Economy & Rebirth
	ECONOMY = {
		STARTING_COINS = 100,
		INCOME_TICK_SECONDS = 2,
		STALL_UPGRADE_BASE_COST = 250,
		STALL_UPGRADE_GROWTH = 1.65,
		REBIRTH_BASE_SPEED = 250,
		REBIRTH_BASE_COINS = 5000,
		REBIRTH_GROWTH = 2.4,
		REBIRTH_INCOME_BONUS_PER_LEVEL = 0.5, -- +50% per rebirth
		FRIEND_BOOST_PER_FRIEND = 0.10, -- +10% per friend in server
		MAX_FRIEND_BOOST = 0.50,
	},

	-- Evolution Tier Multipliers (Merge & Fuse)
	TIER_MULTIPLIERS = {
		[1] = 1.0,  -- Normal
		[2] = 2.5,  -- Golden
		[3] = 6.0,  -- Rainbow
		[4] = 15.0, -- Galactic
	},

	-- Crate Unbox Durations (seconds)
	UNBOX_SECONDS = {
		Common = 5,
		Uncommon = 12,
		Rare = 25,
		Epic = 45,
		Legendary = 75,
		Mythic = 120,
	},

	-- Rarity Visual Colors
	RARITY_COLORS = {
		Common = Color3.fromRGB(162, 178, 165),
		Uncommon = Color3.fromRGB(82, 204, 112),
		Rare = Color3.fromRGB(64, 165, 255),
		Epic = Color3.fromRGB(178, 86, 255),
		Legendary = Color3.fromRGB(255, 196, 46),
		Mythic = Color3.fromRGB(255, 72, 128),
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
