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
		Legendary = 45,
		Mythic = 75,
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
		graphicsQuality = "Medium",
	},
}

function GameConfig.ComputeHatchSeconds(rarity: string, biomeId: string): number
	local base = (GameConfig.UNBOX_SECONDS :: any)[rarity] or 5
	local mult = (GameConfig.BIOME_HATCH_MULTIPLIER :: any)[biomeId] or 1.0
	return math.max(2, math.round(base * mult))
end

function GameConfig.ComputeCrateScale(rarity: string): number
	return (GameConfig.CRATE_SIZE_BY_RARITY :: any)[rarity] or 1.0
end

local function nextMutationTier(mut: string): string?
	for i, m in ipairs(GameConfig.MUTATION_ORDER) do
		if m == mut and i < #GameConfig.MUTATION_ORDER then
			return GameConfig.MUTATION_ORDER[i + 1]
		end
	end
	return nil
end

function GameConfig.ComputeMergeForecast(inputs: { { sizeRatio: number, mutation: string } }): (number, number, { { mutation: string, chance: number } })
	if #inputs == 0 then
		return 1.0, 0.9, { { mutation = "None", chance = 100 } }
	end
	local sumSize, maxSize = 0, 0
	local mutCounts: { [string]: number } = {}
	for _, inp in ipairs(inputs) do
		local sz = inp.sizeRatio or 1.0
		sumSize += sz
		if sz > maxSize then maxSize = sz end
		local m = inp.mutation or "None"
		if m ~= "None" then
			mutCounts[m] = (mutCounts[m] or 0) + 1
		end
	end
	local avgSize = sumSize / #inputs
	local boostedSize = math.floor(math.min(5.5, math.max(maxSize * 1.15, avgSize * 1.32)) * 100 + 0.5) / 100
	local crateScale = math.clamp(0.72 + boostedSize * 0.28, 0.72, 2.25)

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
	return boostedSize, crateScale, list
end

return GameConfig
