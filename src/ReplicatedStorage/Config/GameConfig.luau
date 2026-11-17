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
		MAX_PLACED_CRATES = 30,
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

	-- Random Animal Size Ratios (Dramatic Micro 0.45x -> Colossal 4.80x KG/Size Variety)
	SIZE_BRACKETS = {
		{ name = "Micro", minRatio = 0.45, maxRatio = 0.78, weight = 22.0 },
		{ name = "Normal", minRatio = 0.85, maxRatio = 1.25, weight = 48.0 },
		{ name = "Big", minRatio = 1.30, maxRatio = 1.95, weight = 19.0 },
		{ name = "Giant", minRatio = 2.00, maxRatio = 3.10, weight = 8.5 },
		{ name = "Colossal", minRatio = 3.15, maxRatio = 4.80, weight = 2.5 },
	},

	-- 15-Tier Crate & Pet Rarity Progression + Steal-an-Egg Mutations
	COSMIC_TIER_THRESHOLD = 7,

	RARITY_ORDER = {
		"Common",
		"Uncommon",
		"Rare",
		"Epic",
		"Legendary",
		"Mythic",
		"Cosmic",
		"Secret",
		"Eternal",
		"Divine",
		"Infinity",
		"Astral",
		"Omega",
		"Singularity",
		"Primordial",
	},

	RARITY_TIER_INDEX = {
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
		Legendary = 5,
		Mythic = 6,
		Cosmic = 7,
		Secret = 8,
		Eternal = 9,
		Divine = 10,
		Infinity = 11,
		Astral = 12,
		Omega = 13,
		Singularity = 14,
		Primordial = 15,
	},

	RARITY_WEIGHTS = {
		Common = 50.0,
		Uncommon = 26.0,
		Rare = 13.0,
		Epic = 6.0,
		Legendary = 2.8,
		Mythic = 1.2,
		Cosmic = 0.50,
		Secret = 0.22,
		Eternal = 0.12,
		Divine = 0.075,
		Infinity = 0.045,
		Astral = 0.022,
		Omega = 0.011,
		Singularity = 0.005,
		Primordial = 0.002,
	},

	RARITY_RESISTANCE_MULT = {
		Common = 1.0,
		Uncommon = 1.35,
		Rare = 1.85,
		Epic = 2.6,
		Legendary = 3.7,
		Mythic = 5.2,
		Cosmic = 7.2,
		Secret = 9.5,
		Eternal = 12.2,
		Divine = 15.5,
		Infinity = 19.2,
		Astral = 23.5,
		Omega = 28.0,
		Singularity = 32.5,
		Primordial = 38.0,
	},

	RARITY_WAVE_POINTS = {
		Common = 1,
		Uncommon = 1.4,
		Rare = 1.8,
		Epic = 2.5,
		Legendary = 3.4,
		Mythic = 4.6,
		Cosmic = 5.8,
		Secret = 6.8,
		Eternal = 7.6,
		Divine = 8.4,
		Infinity = 9.2,
		Astral = 10.0,
		Omega = 10.8,
		Singularity = 11.4,
		Primordial = 12.0,
	},

	-- Mutations & Income Multipliers (Steal an Egg inspired + Celestial)
	MUTATIONS = {
		None = { id = "None", label = "Normal", weight = 64.0, multiplier = 1.0, color = Color3.fromRGB(220, 226, 232) },
		Albino = { id = "Albino", label = "Albino", weight = 10.0, multiplier = 1.5, color = Color3.fromRGB(248, 250, 255) },
		Silver = { id = "Silver", label = "Silver", weight = 7.5, multiplier = 1.8, color = Color3.fromRGB(205, 222, 240) },
		Bloom = { id = "Bloom", label = "Bloom", weight = 5.5, multiplier = 2.4, color = Color3.fromRGB(255, 138, 206) },
		Golden = { id = "Golden", label = "Golden", weight = 4.2, multiplier = 3.8, color = Color3.fromRGB(255, 206, 56) },
		Fractured = { id = "Fractured", label = "Fractured", weight = 2.8, multiplier = 6.0, color = Color3.fromRGB(168, 92, 255) },
		Diamond = { id = "Diamond", label = "Diamond", weight = 2.0, multiplier = 9.5, color = Color3.fromRGB(92, 224, 255) },
		SpiritBloom = { id = "SpiritBloom", label = "Spirit Bloom", weight = 1.4, multiplier = 14.0, color = Color3.fromRGB(118, 248, 228) },
		Parasite = { id = "Parasite", label = "Parasite", weight = 1.0, multiplier = 20.0, color = Color3.fromRGB(142, 255, 62) },
		Neon = { id = "Neon", label = "Neon", weight = 0.7, multiplier = 28.0, color = Color3.fromRGB(68, 255, 162) },
		Scrambled = { id = "Scrambled", label = "Scrambled", weight = 0.45, multiplier = 42.0, color = Color3.fromRGB(255, 236, 98) },
		Monstrous = { id = "Monstrous", label = "Monstrous", weight = 0.25, multiplier = 60.0, color = Color3.fromRGB(255, 58, 72) },
		Rainbow = { id = "Rainbow", label = "Rainbow", weight = 0.14, multiplier = 90.0, color = Color3.fromRGB(255, 108, 236) },
		Celestial = { id = "Celestial", label = "Celestial", weight = 0.06, multiplier = 150.0, color = Color3.fromRGB(164, 96, 255) },
	},

	MUTATION_ORDER = {
		"None",
		"Albino",
		"Silver",
		"Bloom",
		"Golden",
		"Fractured",
		"Diamond",
		"SpiritBloom",
		"Parasite",
		"Neon",
		"Scrambled",
		"Monstrous",
		"Rainbow",
		"Celestial",
	},

	UNBOX_SECONDS = {
		Common = 4,
		Uncommon = 8,
		Rare = 15,
		Epic = 25,
		Legendary = 45,
		Mythic = 75,
		Cosmic = 95,
		Secret = 115,
		Eternal = 140,
		Divine = 165,
		Infinity = 195,
		Astral = 225,
		Omega = 255,
		Singularity = 290,
		Primordial = 320,
	},

	BIOME_HATCH_MULTIPLIER = {
		PineWoods = 1.0,
		MangroveSwamp = 1.35,
		SavannaCamp = 1.75,
		AlpinePeaks = 2.25,
		VolcanicJungle = 3.0,
	},

	CRATE_SIZE_BY_RARITY = {
		Common = 0.78,
		Uncommon = 0.90,
		Rare = 1.05,
		Epic = 1.22,
		Legendary = 1.42,
		Mythic = 1.65,
		Cosmic = 1.80,
		Secret = 1.92,
		Eternal = 2.04,
		Divine = 2.15,
		Infinity = 2.26,
		Astral = 2.38,
		Omega = 2.50,
		Singularity = 2.62,
		Primordial = 2.75,
	},

	RARITY_COLORS = {
		Common = Color3.fromRGB(168, 182, 172),
		Uncommon = Color3.fromRGB(78, 212, 114),
		Rare = Color3.fromRGB(64, 165, 255),
		Epic = Color3.fromRGB(178, 86, 255),
		Legendary = Color3.fromRGB(255, 196, 46),
		Mythic = Color3.fromRGB(255, 68, 128),
		Cosmic = Color3.fromRGB(118, 92, 255),
		Secret = Color3.fromRGB(32, 232, 198),
		Eternal = Color3.fromRGB(255, 224, 118),
		Divine = Color3.fromRGB(255, 248, 206),
		Infinity = Color3.fromRGB(56, 188, 255),
		Astral = Color3.fromRGB(186, 128, 255),
		Omega = Color3.fromRGB(255, 58, 92),
		Singularity = Color3.fromRGB(142, 62, 255),
		Primordial = Color3.fromRGB(255, 152, 44),
	},

	RARITY_SECONDARY_COLORS = {
		Cosmic = Color3.fromRGB(64, 218, 255),
		Secret = Color3.fromRGB(22, 118, 154),
		Eternal = Color3.fromRGB(255, 134, 46),
		Divine = Color3.fromRGB(255, 204, 86),
		Infinity = Color3.fromRGB(158, 92, 255),
		Astral = Color3.fromRGB(82, 165, 255),
		Omega = Color3.fromRGB(255, 162, 56),
		Singularity = Color3.fromRGB(24, 218, 255),
		Primordial = Color3.fromRGB(255, 56, 198),
	},

	DEFAULT_SETTINGS = {
		musicEnabled = true,
		musicVolume = 0.45,
		sfxEnabled = true,
		sfxVolume = 0.75,
		hideOtherAnimals = false,
		hideOwnAnimals = false,
		lowVFX = false,
		graphicsQuality = "Medium",
	},
}

function GameConfig.GetRarityTier(rarity: string): number
	return (GameConfig.RARITY_TIER_INDEX :: any)[rarity] or 1
end

function GameConfig.IsCosmicOrAbove(rarity: string): boolean
	return GameConfig.GetRarityTier(rarity) >= GameConfig.COSMIC_TIER_THRESHOLD
end

function GameConfig.ComputeHatchSeconds(rarity: string, biomeId: string): number
	local base = (GameConfig.UNBOX_SECONDS :: any)[rarity] or 5
	local mult = (GameConfig.BIOME_HATCH_MULTIPLIER :: any)[biomeId] or 1.0
	return math.max(2, math.round(base * mult))
end

function GameConfig.ComputeCrateScale(rarity: string, petSizeRatio: number?): number
	local baseScale = (GameConfig.CRATE_SIZE_BY_RARITY :: any)[rarity] or 1.0
	if petSizeRatio ~= nil then
		-- Scale crate visibly by contained pet size/KG without becoming excessively oversized
		local sizeBoost = math.clamp((petSizeRatio - 1.0) * 0.16, -0.14, 0.55)
		return math.floor(math.clamp(baseScale * (1.0 + sizeBoost), 0.68, 3.05) * 100 + 0.5) / 100
	end
	return baseScale
end

local function nextMutationTier(mut: string): string?
	for i, m in ipairs(GameConfig.MUTATION_ORDER) do
		if m == mut and i < #GameConfig.MUTATION_ORDER then
			return GameConfig.MUTATION_ORDER[i + 1]
		end
	end
	return nil
end

function GameConfig.ComputeMergeForecast(
	inputs: { { sizeRatio: number, mutation: string, weightKg: number? } },
	baseWeightKg: number?,
	rarity: string?
): (number, number, { { mutation: string, chance: number } }, { sizeGainPct: number, maxInputSize: number, inputTotalKg: number, expectedKg: number })
	if #inputs == 0 then
		return 1.0, 0.9, { { mutation = "None", chance = 100 } }, { sizeGainPct = 0, maxInputSize = 1.0, inputTotalKg = 0, expectedKg = baseWeightKg or 10 }
	end
	local sumSize, maxSize, sumKg = 0, 0, 0
	local mutCounts: { [string]: number } = {}
	for _, inp in ipairs(inputs) do
		local sz = inp.sizeRatio or 1.0
		sumSize += sz
		if sz > maxSize then maxSize = sz end
		sumKg += (inp.weightKg or 0)
		local m = inp.mutation or "None"
		if m ~= "None" then
			mutCounts[m] = (mutCounts[m] or 0) + 1
		end
	end
	local avgSize = sumSize / #inputs
	-- Compounds pet size upward reliably on every merge based on max & average input KG/size
	local gainBonus = if #inputs >= 3 then 0.22 else 0.10
	local boostedSize = math.floor(math.clamp(maxSize * 1.18 + avgSize * gainBonus, 0.72, 6.0) * 100 + 0.5) / 100
	local crateScale = GameConfig.ComputeCrateScale(rarity or "Rare", boostedSize)
	local sizeGainPct = math.max(0, math.round(((boostedSize - maxSize) / math.max(0.1, maxSize)) * 100))
	local refKg = baseWeightKg or 10
	local expectedKg = math.floor(refKg * math.pow(boostedSize, 2.2) * 10 + 0.5) / 10
	local meta = {
		sizeGainPct = sizeGainPct,
		maxInputSize = maxSize,
		inputTotalKg = math.floor(sumKg * 10 + 0.5) / 10,
		expectedKg = expectedKg,
	}

	local weights: { [string]: number } = {}
	for mut, cnt in pairs(mutCounts) do
		local nxt = nextMutationTier(mut)
		if cnt >= #inputs then
			if nxt then
				weights[nxt] = (weights[nxt] or 0) + 70
				weights[mut] = (weights[mut] or 0) + 30
			else
				weights[mut] = (weights[mut] or 0) + 100
			end
		elseif cnt >= 2 then
			weights[mut] = (weights[mut] or 0) + 50
			if nxt then
				weights[nxt] = (weights[nxt] or 0) + 15
			else
				weights[mut] += 15
			end
		else
			weights[mut] = (weights[mut] or 0) + 22
			if nxt then
				weights[nxt] = (weights[nxt] or 0) + 6
			else
				weights[mut] += 6
			end
		end
	end

	local nonNoneSum = 0
	for _, v in pairs(weights) do
		nonNoneSum += v
	end
	if nonNoneSum == 0 then
		weights["Albino"] = 14
		weights["Golden"] = 4
		nonNoneSum = 18
	elseif nonNoneSum > 100 then
		for k, v in pairs(weights) do
			weights[k] = math.round((v / nonNoneSum) * 100)
		end
		nonNoneSum = 100
	end

	local list: { { mutation: string, chance: number } } = {}
	for _, mutKey in ipairs(GameConfig.MUTATION_ORDER) do
		if mutKey ~= "None" and weights[mutKey] and weights[mutKey] > 0 then
			table.insert(list, { mutation = mutKey, chance = weights[mutKey] })
		end
	end
	local normalPct = math.max(0, 100 - nonNoneSum)
	if normalPct > 0 then
		table.insert(list, { mutation = "None", chance = normalPct })
	end
	table.sort(list, function(a, b)
		return a.chance > b.chance
	end)
	return boostedSize, crateScale, list, meta
end

return GameConfig
