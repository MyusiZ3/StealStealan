--!strict
-- AnimalConfig.luau
-- Complete 83 Exclusive Animal Index across 5 Zones with Tiered Max-Rarity Ceilings, Size Ratio & Mutation Rolls

local Types = require(script.Parent.Parent.Shared.Types)
local GameConfig = require(script.Parent.GameConfig)
local BiomeConfig = require(script.Parent.BiomeConfig)

local AnimalConfig = {}

local BIOME_BY_ID: { [string]: Types.BiomeDefinition } = {}
for _, b in ipairs(BiomeConfig) do
	BIOME_BY_ID[b.id] = b
end

-- Canonical weights table ordered Common -> Primordial (also referenced cleanly by Admin tools)
AnimalConfig.RARITY_WEIGHTS = {}
for _, r in ipairs(GameConfig.RARITY_ORDER) do
	table.insert(AnimalConfig.RARITY_WEIGHTS, {
		rarity = r :: Types.AnimalRarity,
		weight = (GameConfig.RARITY_WEIGHTS :: any)[r] or 1.0,
	})
end

local function makeSpec(
	indexNumber: number,
	id: string,
	name: string,
	biomeId: string,
	rarity: Types.AnimalRarity,
	baseIncomePerSec: number,
	baseWeightKg: number,
	bodyColor: Color3,
	secondaryColor: Color3,
	eyeColor: Color3,
	shapeStyle: "Canine" | "Bear" | "Bird" | "Reptile" | "Hooved" | "Feline" | "Critter"
): Types.AnimalSpeciesDefinition
	return {
		indexNumber = indexNumber,
		id = id,
		name = name,
		biomeId = biomeId,
		rarity = rarity,
		baseIncomePerSec = baseIncomePerSec,
		baseWeightKg = baseWeightKg,
		bodyColor = bodyColor,
		secondaryColor = secondaryColor,
		eyeColor = eyeColor,
		shapeStyle = shapeStyle,
	}
end

local LIST: { Types.AnimalSpeciesDefinition } = {
	-- ZONA 1: Whispering Pine Woods (10 Index: #01 - #10)
	makeSpec(1, "RustyFox", "Rusty Fox", "PineWoods", "Common", 18, 7.5, Color3.fromRGB(228, 108, 44), Color3.fromRGB(248, 240, 224), Color3.fromRGB(20, 20, 24), "Canine"),
	makeSpec(2, "PineSquirrel", "Pine Squirrel", "PineWoods", "Common", 22, 1.8, Color3.fromRGB(168, 98, 54), Color3.fromRGB(238, 198, 148), Color3.fromRGB(20, 20, 24), "Critter"),
	makeSpec(3, "HedgehogScout", "Hedgehog Scout", "PineWoods", "Common", 26, 2.2, Color3.fromRGB(118, 86, 66), Color3.fromRGB(224, 198, 168), Color3.fromRGB(18, 18, 20), "Critter"),
	makeSpec(4, "BadgerDigger", "Badger Digger", "PineWoods", "Common", 32, 11.0, Color3.fromRGB(82, 86, 94), Color3.fromRGB(242, 242, 246), Color3.fromRGB(22, 22, 26), "Critter"),
	makeSpec(5, "AcornRaccoon", "Acorn Raccoon", "PineWoods", "Uncommon", 75, 8.5, Color3.fromRGB(122, 126, 134), Color3.fromRGB(46, 48, 54), Color3.fromRGB(255, 220, 92), "Critter"),
	makeSpec(6, "SpottedOwl", "Spotted Owl", "PineWoods", "Uncommon", 92, 3.4, Color3.fromRGB(146, 112, 82), Color3.fromRGB(242, 232, 212), Color3.fromRGB(255, 192, 48), "Bird"),
	makeSpec(7, "RedBoar", "Forest Red Boar", "PineWoods", "Uncommon", 115, 42.0, Color3.fromRGB(126, 68, 48), Color3.fromRGB(238, 228, 206), Color3.fromRGB(255, 138, 52), "Hooved"),
	makeSpec(8, "AntlerStag", "Antler Stag", "PineWoods", "Rare", 340, 88.0, Color3.fromRGB(158, 102, 58), Color3.fromRGB(238, 206, 128), Color3.fromRGB(28, 22, 18), "Hooved"),
	makeSpec(9, "TimberLynx", "Timber Lynx", "PineWoods", "Rare", 460, 28.0, Color3.fromRGB(198, 154, 108), Color3.fromRGB(64, 48, 38), Color3.fromRGB(122, 245, 162), "Feline"),
	makeSpec(10, "SylvanSpiritWolf", "Sylvan Spirit Wolf", "PineWoods", "Legendary", 2600, 52.0, Color3.fromRGB(92, 238, 168), Color3.fromRGB(232, 255, 245), Color3.fromRGB(0, 255, 195), "Canine"),

	-- ZONA 2: Muddy Mangrove Swamp (12 Index: #11 - #22)
	makeSpec(11, "ChillCapybara", "Chill Capybara", "MangroveSwamp", "Common", 1400, 48.0, Color3.fromRGB(148, 104, 68), Color3.fromRGB(102, 72, 46), Color3.fromRGB(22, 20, 20), "Critter"),
	makeSpec(12, "MudFrog", "Bog Hopper Frog", "MangroveSwamp", "Common", 1750, 1.5, Color3.fromRGB(98, 146, 68), Color3.fromRGB(196, 222, 118), Color3.fromRGB(255, 214, 52), "Reptile"),
	makeSpec(13, "MarshDuck", "Marsh Mallard", "MangroveSwamp", "Common", 2100, 2.8, Color3.fromRGB(68, 148, 92), Color3.fromRGB(238, 178, 58), Color3.fromRGB(20, 20, 24), "Bird"),
	makeSpec(14, "SwampOtter", "Swamp River Otter", "MangroveSwamp", "Common", 2600, 12.0, Color3.fromRGB(108, 76, 54), Color3.fromRGB(218, 194, 162), Color3.fromRGB(24, 24, 28), "Critter"),
	makeSpec(15, "PinkFlamingo", "Pink Flamingo", "MangroveSwamp", "Uncommon", 6400, 4.5, Color3.fromRGB(255, 126, 178), Color3.fromRGB(255, 196, 218), Color3.fromRGB(25, 25, 30), "Bird"),
	makeSpec(16, "PoisonDartToad", "Neon Dart Toad", "MangroveSwamp", "Uncommon", 8200, 1.2, Color3.fromRGB(58, 172, 248), Color3.fromRGB(255, 222, 54), Color3.fromRGB(255, 76, 98), "Reptile"),
	makeSpec(17, "MangroveCrab", "King Mangrove Crab", "MangroveSwamp", "Uncommon", 10500, 6.0, Color3.fromRGB(224, 88, 56), Color3.fromRGB(248, 192, 112), Color3.fromRGB(20, 20, 20), "Critter"),
	makeSpec(18, "MossySnapper", "Mossy Snapper Turtle", "MangroveSwamp", "Rare", 28000, 35.0, Color3.fromRGB(84, 142, 74), Color3.fromRGB(168, 154, 98), Color3.fromRGB(255, 192, 54), "Reptile"),
	makeSpec(19, "ElectricEel", "Shock Swamp Eel", "MangroveSwamp", "Rare", 36000, 18.0, Color3.fromRGB(72, 204, 255), Color3.fromRGB(255, 238, 84), Color3.fromRGB(255, 255, 255), "Reptile"),
	makeSpec(20, "AnacondaStriker", "Jungle Anaconda", "MangroveSwamp", "Rare", 46000, 68.0, Color3.fromRGB(78, 118, 58), Color3.fromRGB(218, 184, 72), Color3.fromRGB(255, 92, 48), "Reptile"),
	makeSpec(21, "AlbinoGator", "Albino Gator", "MangroveSwamp", "Epic", 145000, 140.0, Color3.fromRGB(238, 242, 245), Color3.fromRGB(196, 224, 216), Color3.fromRGB(245, 76, 98), "Reptile"),
	makeSpec(22, "SwampHydraFrog", "Swamp Hydra Frog", "MangroveSwamp", "Legendary", 520000, 95.0, Color3.fromRGB(72, 218, 148), Color3.fromRGB(255, 214, 72), Color3.fromRGB(255, 120, 40), "Reptile"),

	-- ZONA 3: Savanna Poacher Camp (12 Index: #23 - #34)
	makeSpec(23, "DashingMeerkat", "Dashing Meerkat", "SavannaCamp", "Common", 180000, 1.4, Color3.fromRGB(218, 178, 118), Color3.fromRGB(98, 70, 44), Color3.fromRGB(20, 20, 20), "Critter"),
	makeSpec(24, "SavannaHare", "Savanna Scrub Hare", "SavannaCamp", "Common", 240000, 3.2, Color3.fromRGB(198, 158, 108), Color3.fromRGB(245, 234, 214), Color3.fromRGB(28, 22, 18), "Critter"),
	makeSpec(25, "WarthogCharger", "Tusk Warthog", "SavannaCamp", "Common", 310000, 72.0, Color3.fromRGB(128, 86, 68), Color3.fromRGB(242, 232, 204), Color3.fromRGB(255, 168, 58), "Hooved"),
	makeSpec(26, "BlitzZebra", "Blitz Zebra", "SavannaCamp", "Uncommon", 950000, 240.0, Color3.fromRGB(244, 244, 248), Color3.fromRGB(36, 36, 42), Color3.fromRGB(72, 198, 255), "Hooved"),
	makeSpec(27, "OstrichSprinter", "Ostrich Sprinter", "SavannaCamp", "Uncommon", 1300000, 95.0, Color3.fromRGB(48, 46, 54), Color3.fromRGB(242, 174, 158), Color3.fromRGB(255, 214, 72), "Bird"),
	makeSpec(28, "SpottedHyena", "Laughing Hyena", "SavannaCamp", "Uncommon", 1700000, 56.0, Color3.fromRGB(178, 138, 88), Color3.fromRGB(64, 48, 36), Color3.fromRGB(255, 192, 64), "Canine"),
	makeSpec(29, "GazelleLeaper", "Golden Gazelle", "SavannaCamp", "Uncommon", 2200000, 32.0, Color3.fromRGB(224, 164, 84), Color3.fromRGB(250, 244, 232), Color3.fromRGB(24, 24, 28), "Hooved"),
	makeSpec(30, "TuskedElephant", "Baby Savanna Elephant", "SavannaCamp", "Rare", 6800000, 420.0, Color3.fromRGB(142, 152, 166), Color3.fromRGB(245, 242, 224), Color3.fromRGB(28, 28, 32), "Hooved"),
	makeSpec(31, "ArmoredRhino", "Armored Rhino", "SavannaCamp", "Rare", 9200000, 650.0, Color3.fromRGB(118, 124, 136), Color3.fromRGB(228, 224, 212), Color3.fromRGB(255, 124, 48), "Hooved"),
	makeSpec(32, "ToweringGiraffe", "Towering Giraffe", "SavannaCamp", "Rare", 12500000, 540.0, Color3.fromRGB(242, 192, 82), Color3.fromRGB(136, 78, 42), Color3.fromRGB(22, 20, 20), "Hooved"),
	makeSpec(33, "TurboCheetah", "Turbo Cheetah", "SavannaCamp", "Epic", 42000000, 54.0, Color3.fromRGB(246, 196, 72), Color3.fromRGB(54, 42, 34), Color3.fromRGB(255, 132, 24), "Feline"),
	makeSpec(34, "SolarManeLion", "Solar Mane Lion", "SavannaCamp", "Legendary", 165000000, 185.0, Color3.fromRGB(245, 178, 52), Color3.fromRGB(255, 102, 34), Color3.fromRGB(255, 245, 140), "Feline"),

	-- ZONA 4: Frostbite Alpine Peaks (14 Index: #35 - #48)
	makeSpec(35, "EmperorPuffin", "Emperor Puffin", "AlpinePeaks", "Common", 65000000, 4.0, Color3.fromRGB(42, 48, 62), Color3.fromRGB(245, 248, 252), Color3.fromRGB(255, 184, 54), "Bird"),
	makeSpec(36, "LemmingJumper", "Frost Lemming", "AlpinePeaks", "Common", 85000000, 0.9, Color3.fromRGB(224, 232, 242), Color3.fromRGB(138, 168, 204), Color3.fromRGB(32, 44, 68), "Critter"),
	makeSpec(37, "SnowPtarmigan", "Snow Ptarmigan", "AlpinePeaks", "Common", 110000000, 1.6, Color3.fromRGB(248, 250, 255), Color3.fromRGB(178, 196, 218), Color3.fromRGB(255, 132, 48), "Bird"),
	makeSpec(38, "MountainGoat", "Alpine Cliff Goat", "AlpinePeaks", "Common", 145000000, 62.0, Color3.fromRGB(238, 240, 244), Color3.fromRGB(118, 112, 108), Color3.fromRGB(255, 214, 72), "Hooved"),
	makeSpec(39, "ArcticHare", "Arctic Snow Hare", "AlpinePeaks", "Uncommon", 420000000, 4.5, Color3.fromRGB(240, 248, 255), Color3.fromRGB(162, 214, 248), Color3.fromRGB(82, 182, 255), "Critter"),
	makeSpec(40, "IceSeal", "Glacier Harp Seal", "AlpinePeaks", "Uncommon", 560000000, 88.0, Color3.fromRGB(218, 236, 248), Color3.fromRGB(122, 178, 218), Color3.fromRGB(24, 34, 48), "Critter"),
	makeSpec(41, "SnowyOwl", "Blizzard Snowy Owl", "AlpinePeaks", "Uncommon", 740000000, 3.2, Color3.fromRGB(248, 252, 255), Color3.fromRGB(154, 182, 212), Color3.fromRGB(255, 216, 48), "Bird"),
	makeSpec(42, "BighornRam", "Frost Bighorn Ram", "AlpinePeaks", "Uncommon", 980000000, 112.0, Color3.fromRGB(168, 184, 206), Color3.fromRGB(238, 246, 255), Color3.fromRGB(92, 224, 255), "Hooved"),
	makeSpec(43, "FrostFangWolf", "Frost Fang Wolf", "AlpinePeaks", "Rare", 3200000000, 58.0, Color3.fromRGB(142, 208, 248), Color3.fromRGB(238, 248, 255), Color3.fromRGB(0, 232, 255), "Canine"),
	makeSpec(44, "WalrusTusker", "Iceberg Walrus", "AlpinePeaks", "Rare", 4500000000, 520.0, Color3.fromRGB(132, 116, 112), Color3.fromRGB(248, 248, 242), Color3.fromRGB(22, 24, 32), "Critter"),
	makeSpec(45, "CaribouMonarch", "Caribou Monarch", "AlpinePeaks", "Rare", 6200000000, 160.0, Color3.fromRGB(158, 146, 138), Color3.fromRGB(172, 232, 255), Color3.fromRGB(0, 245, 255), "Hooved"),
	makeSpec(46, "GhostSnowLeopard", "Ghost Snow Leopard", "AlpinePeaks", "Epic", 22000000000, 64.0, Color3.fromRGB(218, 228, 238), Color3.fromRGB(108, 128, 152), Color3.fromRGB(148, 244, 255), "Feline"),
	makeSpec(47, "PolarBearJuggernaut", "Polar Juggernaut", "AlpinePeaks", "Epic", 34000000000, 410.0, Color3.fromRGB(246, 250, 255), Color3.fromRGB(168, 222, 252), Color3.fromRGB(64, 212, 255), "Bear"),
	makeSpec(48, "GlacierMammoth", "Glacier Woolly Mammoth", "AlpinePeaks", "Legendary", 140000000000, 1250.0, Color3.fromRGB(118, 86, 68), Color3.fromRGB(182, 238, 255), Color3.fromRGB(122, 248, 255), "Hooved"),

	-- ZONA 5: Volcanic Obsidian Jungle (15 Index: #49 - #63)
	makeSpec(49, "MagmaGecko", "Magma Gecko", "VolcanicJungle", "Common", 65000000000, 2.5, Color3.fromRGB(238, 88, 38), Color3.fromRGB(54, 42, 46), Color3.fromRGB(255, 222, 68), "Reptile"),
	makeSpec(50, "AshScorpion", "Ash Ember Scorpion", "VolcanicJungle", "Common", 92000000000, 4.2, Color3.fromRGB(64, 52, 58), Color3.fromRGB(255, 114, 34), Color3.fromRGB(255, 232, 84), "Critter"),
	makeSpec(51, "EmberBeetle", "Pyro Horn Beetle", "VolcanicJungle", "Common", 130000000000, 3.0, Color3.fromRGB(148, 42, 38), Color3.fromRGB(255, 168, 48), Color3.fromRGB(255, 245, 120), "Critter"),
	makeSpec(52, "LavaSalamander", "Lava Salamander", "VolcanicJungle", "Common", 180000000000, 5.8, Color3.fromRGB(48, 42, 48), Color3.fromRGB(255, 96, 36), Color3.fromRGB(255, 214, 56), "Reptile"),
	makeSpec(53, "CinderBoar", "Cinder Tusk Boar", "VolcanicJungle", "Uncommon", 580000000000, 92.0, Color3.fromRGB(68, 52, 56), Color3.fromRGB(255, 118, 42), Color3.fromRGB(255, 84, 34), "Hooved"),
	makeSpec(54, "ObsidianPanther", "Obsidian Panther", "VolcanicJungle", "Uncommon", 840000000000, 74.0, Color3.fromRGB(36, 34, 46), Color3.fromRGB(168, 72, 255), Color3.fromRGB(255, 112, 245), "Feline"),
	makeSpec(55, "PyroToucan", "Pyro Flame Toucan", "VolcanicJungle", "Uncommon", 1200000000000, 3.8, Color3.fromRGB(44, 42, 52), Color3.fromRGB(255, 146, 44), Color3.fromRGB(255, 224, 62), "Bird"),
	makeSpec(56, "BasaltArmadillo", "Basalt Armadillo", "VolcanicJungle", "Uncommon", 1700000000000, 24.0, Color3.fromRGB(82, 74, 84), Color3.fromRGB(255, 108, 48), Color3.fromRGB(255, 206, 72), "Critter"),
	makeSpec(57, "KomodoDrake", "Komodo Fire Drake", "VolcanicJungle", "Rare", 6200000000000, 145.0, Color3.fromRGB(124, 48, 42), Color3.fromRGB(255, 152, 48), Color3.fromRGB(255, 235, 92), "Reptile"),
	makeSpec(58, "MagmaWyvern", "Pocket Magma Wyvern", "VolcanicJungle", "Rare", 9500000000000, 110.0, Color3.fromRGB(196, 52, 38), Color3.fromRGB(255, 206, 62), Color3.fromRGB(255, 255, 180), "Reptile"),
	makeSpec(59, "HellhoundStalker", "Blaze Hound", "VolcanicJungle", "Rare", 14500000000000, 68.0, Color3.fromRGB(52, 38, 42), Color3.fromRGB(255, 86, 32), Color3.fromRGB(255, 214, 64), "Canine"),
	makeSpec(60, "SilverbackTitan", "Obsidian Silverback Titan", "VolcanicJungle", "Epic", 58000000000000, 320.0, Color3.fromRGB(48, 44, 58), Color3.fromRGB(192, 198, 212), Color3.fromRGB(255, 114, 44), "Bear"),
	makeSpec(61, "MoltenCerberus", "Molten Cerberus", "VolcanicJungle", "Epic", 96000000000000, 190.0, Color3.fromRGB(142, 42, 44), Color3.fromRGB(255, 178, 48), Color3.fromRGB(255, 245, 110), "Canine"),
	makeSpec(62, "InfernoPhoenix", "Inferno Phoenix", "VolcanicJungle", "Legendary", 480000000000000, 42.0, Color3.fromRGB(255, 112, 36), Color3.fromRGB(255, 232, 72), Color3.fromRGB(255, 255, 255), "Bird"),
	makeSpec(63, "MythicWhiteTiger", "Mythic White Tiger", "VolcanicJungle", "Mythic", 3200000000000000, 260.0, Color3.fromRGB(248, 250, 255), Color3.fromRGB(42, 48, 68), Color3.fromRGB(0, 245, 255), "Feline"),

	-- Exclusive Biome Ceiling & Cosmic+ Extensions (#64 - #83)
	-- PineWoods (+1 Epic -> 11 total, Max: Legendary)
	makeSpec(64, "MossbackGrizzly", "Mossback Grizzly", "PineWoods", "Epic", 1150, 310.0, Color3.fromRGB(102, 78, 56), Color3.fromRGB(84, 178, 72), Color3.fromRGB(255, 220, 74), "Bear"),

	-- MangroveSwamp (+1 Mythic -> 13 total, Max: Mythic)
	makeSpec(65, "SwampLeviathan", "Tidewater Leviathan", "MangroveSwamp", "Mythic", 2600000, 460.0, Color3.fromRGB(42, 178, 148), Color3.fromRGB(118, 255, 186), Color3.fromRGB(255, 244, 110), "Reptile"),

	-- SavannaCamp (+1 Mythic, +1 Cosmic, +1 Secret -> 15 total, Max: Secret)
	makeSpec(66, "SunfireRoc", "Sunfire Roc", "SavannaCamp", "Mythic", 780000000, 140.0, Color3.fromRGB(255, 142, 38), Color3.fromRGB(255, 242, 92), Color3.fromRGB(255, 68, 68), "Bird"),
	makeSpec(67, "CelestiaStarCat", "Celestia Starlight Cat", "SavannaCamp", "Cosmic", 5200000000, 38.0, Color3.fromRGB(42, 178, 248), Color3.fromRGB(255, 156, 208), Color3.fromRGB(28, 168, 255), "Feline"),
	makeSpec(68, "SylphPlumeDrake", "Sylph Plume Drake", "SavannaCamp", "Secret", 28000000000, 165.0, Color3.fromRGB(88, 44, 148), Color3.fromRGB(36, 196, 184), Color3.fromRGB(244, 168, 208), "Reptile"),

	-- AlpinePeaks (+1 Mythic..Infinity -> 20 total, Max: Infinity)
	makeSpec(69, "BlizzardGriffin", "Blizzard Sky Griffin", "AlpinePeaks", "Mythic", 720000000000, 320.0, Color3.fromRGB(238, 248, 255), Color3.fromRGB(78, 174, 255), Color3.fromRGB(255, 236, 112), "Bird"),
	makeSpec(70, "AuroraPegasus", "Aurora Star Pegasus", "AlpinePeaks", "Cosmic", 3600000000000, 280.0, Color3.fromRGB(128, 112, 255), Color3.fromRGB(92, 255, 222), Color3.fromRGB(255, 255, 255), "Hooved"),
	makeSpec(71, "SubzeroKraken", "Subzero Cryptic Owl", "AlpinePeaks", "Secret", 18000000000000, 95.0, Color3.fromRGB(38, 112, 164), Color3.fromRGB(82, 248, 224), Color3.fromRGB(212, 255, 255), "Bird"),
	makeSpec(72, "ObsidianNightmare", "Obsidian Moonhorn Steed", "AlpinePeaks", "Eternal", 135000000000000, 295.0, Color3.fromRGB(26, 24, 38), Color3.fromRGB(168, 192, 255), Color3.fromRGB(255, 118, 36), "Hooved"),
	makeSpec(73, "JadeKirinSteed", "Jade Kirin Steed", "AlpinePeaks", "Divine", 680000000000000, 320.0, Color3.fromRGB(34, 178, 112), Color3.fromRGB(226, 236, 248), Color3.fromRGB(255, 214, 62), "Hooved"),
	makeSpec(74, "ZephyrSpiritDragon", "Zephyr River Dragon", "AlpinePeaks", "Infinity", 5400000000000000, 210.0, Color3.fromRGB(248, 250, 252), Color3.fromRGB(46, 178, 112), Color3.fromRGB(224, 182, 162), "Reptile"),

	-- VolcanicJungle (+9 Cosmic..Primordial -> 24 total, Max: Primordial)
	makeSpec(75, "CosmicPyroRaptor", "Cosmic PyroDrake", "VolcanicJungle", "Cosmic", 18000000000000000, 180.0, Color3.fromRGB(108, 72, 255), Color3.fromRGB(255, 118, 56), Color3.fromRGB(112, 248, 255), "Reptile"),
	makeSpec(76, "SecretShadowWyrm", "Secret Onyx Fox", "VolcanicJungle", "Secret", 95000000000000000, 76.0, Color3.fromRGB(28, 34, 48), Color3.fromRGB(36, 242, 198), Color3.fromRGB(82, 255, 224), "Canine"),
	makeSpec(77, "EternalAshenKitsune", "Eternal Ember Wolf", "VolcanicJungle", "Eternal", 520000000000000000, 145.0, Color3.fromRGB(255, 212, 102), Color3.fromRGB(255, 88, 38), Color3.fromRGB(255, 252, 210), "Canine"),
	makeSpec(78, "DivineSolarSeraph", "Divine Solar Griffin", "VolcanicJungle", "Divine", 2900000000000000000, 290.0, Color3.fromRGB(255, 246, 210), Color3.fromRGB(255, 196, 52), Color3.fromRGB(255, 255, 255), "Bird"),
	makeSpec(79, "InfinityVoidHydra", "Infinity Abyss Panther", "VolcanicJungle", "Infinity", 16000000000000000000, 310.0, Color3.fromRGB(46, 174, 255), Color3.fromRGB(168, 72, 255), Color3.fromRGB(172, 248, 255), "Feline"),
	makeSpec(80, "AstralStarDragon", "Astral Starry Lynx", "VolcanicJungle", "Astral", 92000000000000000000, 215.0, Color3.fromRGB(174, 102, 255), Color3.fromRGB(98, 206, 255), Color3.fromRGB(255, 224, 255), "Feline"),
	makeSpec(81, "OmegaObsidianColossus", "Omega Basalt Titan", "VolcanicJungle", "Omega", 540000000000000000000, 950.0, Color3.fromRGB(224, 38, 76), Color3.fromRGB(255, 168, 44), Color3.fromRGB(255, 244, 140), "Bear"),
	makeSpec(82, "AstralNebulaLynx", "Astral Nebula Lynx", "VolcanicJungle", "Singularity", 4500000000000000000000, 46.0, Color3.fromRGB(28, 34, 78), Color3.fromRGB(48, 214, 255), Color3.fromRGB(248, 148, 232), "Feline"),
	makeSpec(83, "FaeLaceDragon", "Fae Lacewing Dragon", "VolcanicJungle", "Primordial", 28000000000000000000000, 240.0, Color3.fromRGB(232, 52, 162), Color3.fromRGB(52, 92, 232), Color3.fromRGB(245, 192, 68), "Reptile"),
}

AnimalConfig.ALL = LIST
AnimalConfig.BY_ID = {} :: { [string]: Types.AnimalSpeciesDefinition }
for _, spec in ipairs(LIST) do
	AnimalConfig.BY_ID[spec.id] = spec
end

function AnimalConfig.GetById(speciesId: string): Types.AnimalSpeciesDefinition?
	return AnimalConfig.BY_ID[speciesId]
end

function AnimalConfig.GetByBiome(biomeId: string): { Types.AnimalSpeciesDefinition }
	local out = {}
	for _, spec in ipairs(LIST) do
		if spec.biomeId == biomeId then
			table.insert(out, spec)
		end
	end
	table.sort(out, function(a, b)
		local ta = GameConfig.GetRarityTier(a.rarity)
		local tb = GameConfig.GetRarityTier(b.rarity)
		if ta ~= tb then
			return ta < tb
		end
		return a.indexNumber < b.indexNumber
	end)
	return out
end

function AnimalConfig.ComputeIndexRewards(spec: Types.AnimalSpeciesDefinition): (number, number)
	local cashReward = math.max(100, math.round(spec.baseIncomePerSec * 120))
	local biome = BIOME_BY_ID[spec.biomeId]
	local recSpd = if biome then biome.recommendedSpeed else 50
	local tier = GameConfig.GetRarityTier(spec.rarity)
	local speedReward = math.max(10, math.round(recSpd * 0.05 * math.pow(1.38, math.max(0, tier - 1))))
	return cashReward, speedReward
end

function AnimalConfig.RollSpeciesForBiome(
	biomeId: string,
	luckMultiplier: number?,
	rarityWeightOverrides: { [string]: number }?,
	forcedMaxRarity: string?
): Types.AnimalSpeciesDefinition
	local pool = AnimalConfig.GetByBiome(biomeId)
	if #pool == 0 then
		return LIST[1]
	end
	local biome = BIOME_BY_ID[biomeId]
	local capRarity = forcedMaxRarity or (biome and biome.maxRarity) or "Legendary"
	local maxTier = GameConfig.GetRarityTier(capRarity)

	-- Strict isolation: ONLY include rarities that both exist in this biome AND do not exceed maxRarity
	local allowedByRarity: { [string]: { Types.AnimalSpeciesDefinition } } = {}
	for _, spec in ipairs(pool) do
		local tier = GameConfig.GetRarityTier(spec.rarity)
		if tier <= maxTier then
			if not allowedByRarity[spec.rarity] then
				allowedByRarity[spec.rarity] = {}
			end
			table.insert(allowedByRarity[spec.rarity], spec)
		end
	end

	local luck = math.max(0.05, luckMultiplier or 1.0)
	local weightedRarities: { { rarity: string, w: number } } = {}
	local totalW = 0
	for _, entry in ipairs(AnimalConfig.RARITY_WEIGHTS) do
		local r = entry.rarity
		if allowedByRarity[r] and #allowedByRarity[r] > 0 then
			local baseW = if rarityWeightOverrides and rarityWeightOverrides[r] ~= nil
				then math.max(0, rarityWeightOverrides[r])
				else entry.weight
			local w = baseW
			if r ~= "Common" and baseW > 0 then
				w = baseW * luck
			end
			if w > 0 then
				totalW += w
				table.insert(weightedRarities, { rarity = r, w = w })
			end
		end
	end

	if totalW <= 0 or #weightedRarities == 0 then
		return pool[math.random(1, #pool)]
	end

	local roll = math.random() * totalW
	local chosenRarity = weightedRarities[1].rarity
	local acc = 0
	for _, entry in ipairs(weightedRarities) do
		acc += entry.w
		if roll <= acc then
			chosenRarity = entry.rarity
			break
		end
	end

	local matching = allowedByRarity[chosenRarity] or pool
	return matching[math.random(1, #matching)]
end

function AnimalConfig.RollSizeRatio(giantBonusMult: number?): number
	local bonus = giantBonusMult or 1.0
	local total = 0
	local brackets = {}
	for _, b in ipairs(GameConfig.SIZE_BRACKETS) do
		local w = b.weight
		if b.minRatio >= 2.0 then
			w = w * bonus
		end
		total += w
		table.insert(brackets, { b = b, w = w })
	end
	local roll = math.random() * total
	local acc = 0
	local chosen = GameConfig.SIZE_BRACKETS[2]
	for _, item in ipairs(brackets) do
		acc += item.w
		if roll <= acc then
			chosen = item.b
			break
		end
	end
	local ratio = chosen.minRatio + math.random() * (chosen.maxRatio - chosen.minRatio)
	return math.floor(ratio * 100 + 0.5) / 100
end

function AnimalConfig.RollMutation(
	mutationLuckMult: number?,
	mutationWeightOverrides: { [string]: number }?,
	forcedMutation: string?
): Types.AnimalMutation
	if forcedMutation and forcedMutation ~= "" and forcedMutation ~= "Random" and (GameConfig.MUTATIONS :: any)[forcedMutation] then
		return forcedMutation :: Types.AnimalMutation
	end
	local luck = math.max(0.05, mutationLuckMult or 1.0)
	local total = 0
	local entries = {}
	for _, key in ipairs(GameConfig.MUTATION_ORDER) do
		local m = GameConfig.MUTATIONS[key]
		local baseW = if mutationWeightOverrides and mutationWeightOverrides[key] ~= nil
			then math.max(0, mutationWeightOverrides[key])
			else m.weight
		local w = baseW
		if key ~= "None" and baseW > 0 then
			w = baseW * luck
		end
		if w > 0 then
			total += w
			table.insert(entries, { id = key :: Types.AnimalMutation, w = w })
		end
	end
	if total <= 0 or #entries == 0 then
		return "None"
	end
	local roll = math.random() * total
	local acc = 0
	for _, e in ipairs(entries) do
		acc += e.w
		if roll <= acc then
			return e.id
		end
	end
	return entries[1].id
end

function AnimalConfig.ComputeIncomePerSec(animal: Types.AnimalInstance): number
	local spec = AnimalConfig.BY_ID[animal.speciesId]
	if not spec then
		return 1
	end
	local mutInfo = GameConfig.MUTATIONS[animal.mutation] or GameConfig.MUTATIONS.None
	local sizeFactor = math.pow(math.max(0.45, animal.sizeRatio), 1.5)
	return spec.baseIncomePerSec * sizeFactor * mutInfo.multiplier
end

return AnimalConfig
