--!strict
-- VoxelCrateBuilder.luau
-- Comprehensive 10-Archetype Modular 3D Voxel Crate & Reliquary System
-- Implements the 10 voxel containment cage designs from the official concept turnaround sheet:
--   Top Apex Row: Void/Singularity (Spiked Crown), Astral (Floating Halo), Divine (Angel Wings + Halo),
--                 Cosmic (Orb + Satellites), Primordial (Dorsal Horn Spire)
--   Bottom Progression Row: Legendary (Solar Crown), Epic (Amethyst Cluster), Rare (Glacier Spires),
--                           Uncommon (Forest Leaf Spires), Common (Stone Battlement Crenels)
-- Also supports intermediate rarities (Mythic, Secret, Eternal, Infinity, Omega) and Biome-specific variations.
--
-- Guaranteed Contract:
--   - PrimaryPart: CrateRoot (CanQuery = true, Anchored = true)
--   - Ground-anchored bottom pivot: PivotOffset at Y = 0 (groundDelta = 0.000)
--   - TowRing preserved for lasso/tow attachment compatibility
--   - Optional RarityBeacon & CosmicBeaconCore when showBeacon == true
--   - Anti-glare compliant: strictly ZERO PointLights

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local VoxelCrateBuilder = {}

export type BuildOpts = {
	isBuried: boolean?,
	canCollide: boolean?,
	showBeacon: boolean?,
	variant: number?,
	lowDetail: boolean?,
}

export type CrateProfile = {
	title: string,
	crownStyle: string,
	frameDark: Color3,
	frameMid: Color3,
	frameRim: Color3,
	trimMetal: Color3,
	trimAccent: Color3,
	chamberCol: Color3,
	neonPrimary: Color3,
	neonSecondary: Color3,
	chainCol: Color3,
	chainMat: Enum.Material?,
	isNeonChain: boolean?,
}

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local MAT_NEON = Enum.Material.Neon

-- Canonical Profiles matching the 10 designs in the reference sheet
local PROFILES: { [string]: CrateProfile } = {
	Common = {
		title = "Iron Stone Reliquary",
		crownStyle = "IronBattlement",
		frameDark = Color3.fromRGB(48, 52, 58),
		frameMid = Color3.fromRGB(72, 78, 86),
		frameRim = Color3.fromRGB(102, 110, 120),
		trimMetal = Color3.fromRGB(180, 186, 194),
		trimAccent = Color3.fromRGB(130, 136, 144),
		chamberCol = Color3.fromRGB(28, 30, 34),
		neonPrimary = Color3.fromRGB(220, 230, 242),
		neonSecondary = Color3.fromRGB(255, 255, 255),
		chainCol = Color3.fromRGB(96, 102, 112),
	},
	Uncommon = {
		title = "Forest Emerald Cage",
		crownStyle = "EmeraldSpire",
		frameDark = Color3.fromRGB(26, 42, 28),
		frameMid = Color3.fromRGB(38, 64, 42),
		frameRim = Color3.fromRGB(56, 92, 60),
		trimMetal = Color3.fromRGB(68, 178, 84),
		trimAccent = Color3.fromRGB(42, 128, 54),
		chamberCol = Color3.fromRGB(16, 32, 18),
		neonPrimary = Color3.fromRGB(68, 235, 88),
		neonSecondary = Color3.fromRGB(154, 255, 128),
		chainCol = Color3.fromRGB(34, 58, 36),
	},
	Rare = {
		title = "Glacier Sapphire Vault",
		crownStyle = "GlacierSpires",
		frameDark = Color3.fromRGB(22, 38, 64),
		frameMid = Color3.fromRGB(34, 60, 98),
		frameRim = Color3.fromRGB(52, 90, 144),
		trimMetal = Color3.fromRGB(74, 168, 235),
		trimAccent = Color3.fromRGB(42, 118, 186),
		chamberCol = Color3.fromRGB(14, 26, 48),
		neonPrimary = Color3.fromRGB(72, 218, 255),
		neonSecondary = Color3.fromRGB(196, 246, 255),
		chainCol = Color3.fromRGB(48, 84, 132),
	},
	Epic = {
		title = "Amethyst Crystal Coffer",
		crownStyle = "AmethystCluster",
		frameDark = Color3.fromRGB(36, 30, 48),
		frameMid = Color3.fromRGB(56, 44, 76),
		frameRim = Color3.fromRGB(82, 62, 112),
		trimMetal = Color3.fromRGB(178, 112, 238),
		trimAccent = Color3.fromRGB(128, 72, 186),
		chamberCol = Color3.fromRGB(26, 18, 38),
		neonPrimary = Color3.fromRGB(198, 92, 255),
		neonSecondary = Color3.fromRGB(240, 178, 255),
		chainCol = Color3.fromRGB(64, 50, 84),
	},
	Legendary = {
		title = "Solar Gold Reliquary",
		crownStyle = "SolarCrown",
		frameDark = Color3.fromRGB(56, 42, 22),
		frameMid = Color3.fromRGB(92, 68, 32),
		frameRim = Color3.fromRGB(138, 102, 44),
		trimMetal = Color3.fromRGB(245, 186, 52),
		trimAccent = Color3.fromRGB(186, 128, 32),
		chamberCol = Color3.fromRGB(42, 28, 12),
		neonPrimary = Color3.fromRGB(255, 208, 62),
		neonSecondary = Color3.fromRGB(255, 246, 168),
		chainCol = Color3.fromRGB(168, 118, 38),
	},
	Mythic = {
		title = "Abyssal Flame Reliquary",
		crownStyle = "AbyssalFlame",
		frameDark = Color3.fromRGB(34, 22, 32),
		frameMid = Color3.fromRGB(64, 34, 56),
		frameRim = Color3.fromRGB(98, 48, 84),
		trimMetal = Color3.fromRGB(242, 74, 138),
		trimAccent = Color3.fromRGB(182, 42, 96),
		chamberCol = Color3.fromRGB(28, 14, 24),
		neonPrimary = Color3.fromRGB(255, 54, 138),
		neonSecondary = Color3.fromRGB(255, 168, 214),
		chainCol = Color3.fromRGB(78, 36, 64),
	},
	Cosmic = {
		title = "Celestial Star Pod",
		crownStyle = "CosmicOrb",
		frameDark = Color3.fromRGB(24, 20, 42),
		frameMid = Color3.fromRGB(42, 34, 74),
		frameRim = Color3.fromRGB(68, 54, 116),
		trimMetal = Color3.fromRGB(192, 92, 255),
		trimAccent = Color3.fromRGB(64, 216, 255),
		chamberCol = Color3.fromRGB(18, 14, 34),
		neonPrimary = Color3.fromRGB(242, 68, 212),
		neonSecondary = Color3.fromRGB(68, 236, 255),
		chainCol = Color3.fromRGB(78, 226, 255),
		isNeonChain = true,
	},
	Secret = {
		title = "Mystic Prism Vault",
		crownStyle = "MysticPrism",
		frameDark = Color3.fromRGB(22, 36, 44),
		frameMid = Color3.fromRGB(38, 62, 76),
		frameRim = Color3.fromRGB(58, 96, 118),
		trimMetal = Color3.fromRGB(72, 238, 212),
		trimAccent = Color3.fromRGB(246, 112, 198),
		chamberCol = Color3.fromRGB(14, 28, 34),
		neonPrimary = Color3.fromRGB(52, 248, 218),
		neonSecondary = Color3.fromRGB(255, 142, 228),
		chainCol = Color3.fromRGB(52, 248, 218),
		isNeonChain = true,
	},
	Eternal = {
		title = "Eternal Pyre Reliquary",
		crownStyle = "EternalPyre",
		frameDark = Color3.fromRGB(48, 30, 22),
		frameMid = Color3.fromRGB(86, 52, 34),
		frameRim = Color3.fromRGB(132, 78, 48),
		trimMetal = Color3.fromRGB(255, 154, 48),
		trimAccent = Color3.fromRGB(255, 214, 72),
		chamberCol = Color3.fromRGB(36, 20, 14),
		neonPrimary = Color3.fromRGB(255, 128, 38),
		neonSecondary = Color3.fromRGB(255, 228, 118),
		chainCol = Color3.fromRGB(168, 86, 36),
	},
	Divine = {
		title = "Seraph Divine Sanctum",
		crownStyle = "DivineWings",
		frameDark = Color3.fromRGB(236, 240, 246), -- Pure white marble / ivory
		frameMid = Color3.fromRGB(214, 220, 230),
		frameRim = Color3.fromRGB(186, 194, 208),
		trimMetal = Color3.fromRGB(248, 198, 48),  -- Sovereign gold
		trimAccent = Color3.fromRGB(198, 146, 28),
		chamberCol = Color3.fromRGB(98, 76, 34),
		neonPrimary = Color3.fromRGB(255, 226, 78),
		neonSecondary = Color3.fromRGB(255, 255, 255),
		chainCol = Color3.fromRGB(242, 188, 44),
	},
	Infinity = {
		title = "Spacetime Infinity Vault",
		crownStyle = "InfinityShards",
		frameDark = Color3.fromRGB(20, 28, 52),
		frameMid = Color3.fromRGB(34, 48, 88),
		frameRim = Color3.fromRGB(54, 76, 138),
		trimMetal = Color3.fromRGB(68, 204, 255),
		trimAccent = Color3.fromRGB(168, 112, 255),
		chamberCol = Color3.fromRGB(14, 18, 42),
		neonPrimary = Color3.fromRGB(64, 228, 255),
		neonSecondary = Color3.fromRGB(214, 148, 255),
		chainCol = Color3.fromRGB(64, 228, 255),
		isNeonChain = true,
	},
	Astral = {
		title = "Astral Halo Reliquary",
		crownStyle = "AstralHalo",
		frameDark = Color3.fromRGB(18, 24, 38),
		frameMid = Color3.fromRGB(32, 42, 66),
		frameRim = Color3.fromRGB(48, 64, 102),
		trimMetal = Color3.fromRGB(68, 198, 255),
		trimAccent = Color3.fromRGB(112, 142, 220),
		chamberCol = Color3.fromRGB(12, 18, 32),
		neonPrimary = Color3.fromRGB(56, 212, 255),
		neonSecondary = Color3.fromRGB(186, 242, 255),
		chainCol = Color3.fromRGB(56, 212, 255),
		isNeonChain = true,
	},
	Omega = {
		title = "Omega Colossus Coffer",
		crownStyle = "OmegaHorns",
		frameDark = Color3.fromRGB(24, 20, 26),
		frameMid = Color3.fromRGB(46, 38, 52),
		frameRim = Color3.fromRGB(72, 60, 82),
		trimMetal = Color3.fromRGB(238, 148, 52),
		trimAccent = Color3.fromRGB(168, 92, 32),
		chamberCol = Color3.fromRGB(30, 22, 34),
		neonPrimary = Color3.fromRGB(255, 128, 44),
		neonSecondary = Color3.fromRGB(255, 218, 122),
		chainCol = Color3.fromRGB(86, 72, 94),
	},
	Singularity = {
		title = "Void Singularity Vault",
		crownStyle = "VoidCrown",
		frameDark = Color3.fromRGB(20, 16, 28),
		frameMid = Color3.fromRGB(38, 28, 54),
		frameRim = Color3.fromRGB(62, 44, 88),
		trimMetal = Color3.fromRGB(174, 76, 255),
		trimAccent = Color3.fromRGB(116, 42, 182),
		chamberCol = Color3.fromRGB(24, 14, 38),
		neonPrimary = Color3.fromRGB(182, 58, 255),
		neonSecondary = Color3.fromRGB(236, 158, 255),
		chainCol = Color3.fromRGB(142, 48, 224),
		isNeonChain = true,
	},
	Primordial = {
		title = "Primordial Cataclysm Reliquary",
		crownStyle = "Spire",
		frameDark = Color3.fromRGB(22, 20, 26),
		frameMid = Color3.fromRGB(44, 39, 52),
		frameRim = Color3.fromRGB(64, 56, 74),
		trimMetal = Color3.fromRGB(228, 168, 74),
		trimAccent = Color3.fromRGB(168, 106, 42),
		chamberCol = Color3.fromRGB(158, 14, 42),
		neonPrimary = Color3.fromRGB(255, 34, 78),
		neonSecondary = Color3.fromRGB(255, 134, 168),
		chainCol = Color3.fromRGB(48, 42, 56),
	},
}

-- Biome subtle frame tint adjustments for environmental harmony
local BIOME_FRAME_TINTS: { [string]: { darkMul: Color3, rimMul: Color3 } } = {
	PineWoods = {
		darkMul = Color3.fromRGB(240, 250, 240),
		rimMul = Color3.fromRGB(220, 255, 220),
	},
	MangroveSwamp = {
		darkMul = Color3.fromRGB(230, 240, 230),
		rimMul = Color3.fromRGB(200, 240, 210),
	},
	SavannaCamp = {
		darkMul = Color3.fromRGB(255, 248, 230),
		rimMul = Color3.fromRGB(255, 235, 190),
	},
	AlpinePeaks = {
		darkMul = Color3.fromRGB(235, 245, 255),
		rimMul = Color3.fromRGB(210, 235, 255),
	},
	VolcanicJungle = {
		darkMul = Color3.fromRGB(255, 230, 230),
		rimMul = Color3.fromRGB(255, 210, 210),
	},
}

local function tintColor(c: Color3, mul: Color3): Color3
	return Color3.new(
		math.clamp(c.R * mul.R, 0, 1),
		math.clamp(c.G * mul.G, 0, 1),
		math.clamp(c.B * mul.B, 0, 1)
	)
end

function VoxelCrateBuilder.GetProfile(rarity: string, biomeId: string?): CrateProfile
	local base = PROFILES[rarity] or PROFILES.Common
	local tint = if biomeId then BIOME_FRAME_TINTS[biomeId] else nil
	if not tint then
		return base
	end
	return {
		title = base.title,
		crownStyle = base.crownStyle,
		frameDark = tintColor(base.frameDark, tint.darkMul),
		frameMid = base.frameMid,
		frameRim = tintColor(base.frameRim, tint.rimMul),
		trimMetal = base.trimMetal,
		trimAccent = base.trimAccent,
		chamberCol = base.chamberCol,
		neonPrimary = base.neonPrimary,
		neonSecondary = base.neonSecondary,
		chainCol = base.chainCol,
		chainMat = base.chainMat,
		isNeonChain = base.isNeonChain,
	}
end

function VoxelCrateBuilder.GetTitle(rarity: string): string
	local prof = PROFILES[rarity] or PROFILES.Common
	return prof.title
end

-- Helper: Stepped Diamond Medallion Lock on given face
local function buildFaceDiamond(
	vox: (string, number, number, number, number, number, number, Color3, Enum.Material, CFrame?) -> Part,
	face: string,
	centerU: number,
	centerY: number,
	faceDepth: number,
	normalSign: number,
	prof: CrateProfile,
	voxelStep: number,
	ringSteps: number,
	starRadius: number,
	lowDetail: boolean
)
	local function placeOnFace(name: string, u: number, y: number, wU: number, hY: number, thick: number, outOff: number, col: Color3, mat: Enum.Material)
		local d = faceDepth + normalSign * (outOff + thick * 0.5)
		if face == "Front" or face == "Back" then
			local lx = if face == "Front" then u else -u
			vox(name, wU, hY, thick, lx, y - hY * 0.5, d, col, mat)
		else
			local lz = if face == "Right" then u else -u
			vox(name, thick, hY, wU, d, y - hY * 0.5, lz, col, mat)
		end
	end

	-- Stepped dark backing diamond
	for row = -ringSteps, ringSteps do
		local span = (ringSteps - math.abs(row)) * 2 + 1
		local uWidth = span * voxelStep
		local relief = (math.abs(row) % 2) * 0.005
		placeOnFace("LockBackRow", centerU, centerY + row * voxelStep, uWidth, voxelStep, 0.08, 0.00 + relief, prof.frameDark, MAT_PLASTIC)
	end

	-- Stepped metallic diamond bezel
	local metalHalf = ringSteps - 1
	for row = -metalHalf, metalHalf do
		local span = (metalHalf - math.abs(row)) * 2 + 1
		local uWidth = span * voxelStep
		local col = if math.abs(row) >= metalHalf - 1 then prof.trimAccent else prof.trimMetal
		local relief = (math.abs(row) % 2) * 0.005
		placeOnFace("LockMetalRow", centerU, centerY + row * voxelStep, uWidth, voxelStep, 0.09, 0.06 + relief, col, MAT_PLASTIC)
	end

	-- Inner dark socket
	local innerHalf = math.max(1, metalHalf - 2)
	local sockSize = (innerHalf * 2 + 1) * voxelStep * 0.85
	placeOnFace("LockSocket", centerU, centerY, sockSize, sockSize, 0.07, 0.13, prof.frameDark, MAT_PLASTIC)

	-- 4-Point Neon Star Gem + Secondary Pin Core
	local armLen = starRadius * 2.0
	local armThick = if lowDetail then voxelStep * 1.15 else voxelStep * 0.95
	placeOnFace("LockGemH", centerU, centerY, armLen, armThick, 0.08, 0.18, prof.neonPrimary, MAT_NEON)
	placeOnFace("LockGemV", centerU, centerY, armThick, armLen, 0.08, 0.186, prof.neonPrimary, MAT_NEON)
	placeOnFace("LockGemCore", centerU, centerY, armThick * 1.15, armThick * 1.15, 0.08, 0.22, prof.neonSecondary, MAT_NEON)
end

-- Helper: Stepped X-Brace arms for side/back faces
local function buildSteppedXBrace(
	vox: (string, number, number, number, number, number, number, Color3, Enum.Material, CFrame?) -> Part,
	face: string,
	faceDepth: number,
	normalSign: number,
	spanU: number,
	centerY: number,
	spanY: number,
	steps: number,
	prof: CrateProfile
)
	local function placeArmPart(name: string, u: number, y: number, wU: number, hY: number, thick: number, outOff: number, col: Color3)
		local d = faceDepth + normalSign * (outOff + thick * 0.5)
		if face == "Back" then
			vox(name, wU, hY, thick, -u, y - hY * 0.5, d, col, MAT_PLASTIC)
		elseif face == "Right" then
			vox(name, thick, hY, wU, d, y - hY * 0.5, u, col, MAT_PLASTIC)
		else
			vox(name, thick, hY, wU, d, y - hY * 0.5, -u, col, MAT_PLASTIC)
		end
	end

	local stepW = (spanU / steps) * 1.24
	local stepH = (spanY / steps) * 1.24
	for _, su in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for i = 1, steps do
				local t = (i - 0.5) / steps
				local u = su * spanU * (0.20 + t * 0.78)
				local y = centerY + sy * spanY * (0.20 + t * 0.78)
				local relief = (i % 2) * 0.008
				placeArmPart("XBraceBack", u, y, stepW * 1.14, stepH * 1.14, 0.08, 0.00 + relief, prof.frameDark)
				local trimCol = if i % 2 == 1 then prof.trimMetal else prof.trimAccent
				placeArmPart("XBraceTrim", u, y, stepW * 0.84, stepH * 0.84, 0.09, 0.06 + relief, trimCol)
			end
		end
	end
end

-- Helper: Diagonal Wrapped Exterior Chains circling the cage
-- Accurately recreates the crossing diagonal chains seen in all 10 turnaround designs!
local function buildWrappedChains(
	vox: (string, number, number, number, number, number, number, Color3, Enum.Material, CFrame?) -> Part,
	prof: CrateProfile,
	lowDetail: boolean
)
	local chainMat = if prof.isNeonChain then MAT_NEON else (prof.chainMat or MAT_PLASTIC)
	local stepsPerFace = if lowDetail then 3 else 5
	local yBottom = 0.85
	local yTop = 3.25
	local yMid = (yBottom + yTop) * 0.5
	local halfY = (yTop - yBottom) * 0.5

	-- 4 faces: Front (-Z), Right (+X), Back (+Z), Left (-X)
	-- Each face has 2 crossing diagonal chain segments passing outside the bars
	local faces = {
		{ name = "Front", signZ = -1, signX = 0, depth = -2.06 },
		{ name = "Right", signZ = 0, signX = 1, depth = 2.06 },
		{ name = "Back", signZ = 1, signX = 0, depth = 2.06 },
		{ name = "Left", signZ = 0, signX = -1, depth = -2.06 },
	}

	for _, f in ipairs(faces) do
		-- Diagonal 1: from (-spanU, yBottom) to (+spanU, yTop)
		-- Diagonal 2: from (+spanU, yBottom) to (-spanU, yTop)
		local spanU = 1.62
		for _, diagDir in ipairs({ 1, -1 }) do
			for i = 1, stepsPerFace do
				local t = (i - 0.5) / stepsPerFace -- 0 .. 1
				local u = (-1 + 2 * t) * spanU * diagDir
				local y = yBottom + t * (yTop - yBottom)

				-- Skip link if it collides directly with the central lock medallion
				if math.abs(u) < 0.42 and math.abs(y - yMid) < 0.42 then
					continue
				end

				local isOdd = (i % 2 == 1)
				local col = prof.chainCol
				if prof.crownStyle == "CosmicOrb" then
					col = if isOdd then prof.neonPrimary else prof.neonSecondary
				end

				local linkW = 0.22
				local linkH = 0.18
				local linkThick = 0.12

				if f.signZ ~= 0 then
					vox("WrappedChainLink", linkW, linkH, linkThick, u, y - linkH * 0.5, f.depth, col, chainMat)
				else
					vox("WrappedChainLink", linkThick, linkH, linkW, f.depth, y - linkH * 0.5, u, col, chainMat)
				end
			end
		end
	end
end

-- Distinct Crown Generators
local function buildCrownOrnaments(
	vox: (string, number, number, number, number, number, number, Color3, Enum.Material, CFrame?) -> Part,
	prof: CrateProfile,
	lowDetail: boolean
)
	local style = prof.crownStyle

	if style == "Spire" then
		-- Primordial / Cataclysm Dorsal Horn Spire (Peak at ly = 5.14)
		vox("SpireBase", 0.96, 0.28, 1.76, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("SpireRibStep", 0.64, 0.26, 1.24, 0, 4.30, 0, prof.frameMid, MAT_PLASTIC)
		vox("SpireObsPeak", 0.36, 0.24, 0.56, 0, 4.56, 0, prof.frameDark, MAT_PLASTIC)
		vox("SpireCrimsonCore", 0.22, 0.42, 0.38, 0, 4.42, 0, prof.neonPrimary, MAT_NEON)
		vox("SpireTipCrimson", 0.16, 0.20, 0.22, 0, 4.76, 0, prof.neonPrimary, MAT_NEON)
		vox("SpireApex", 0.10, 0.18, 0.14, 0, 4.96, 0, prof.neonSecondary, MAT_NEON)
		vox("SpireFrontFlank", 0.26, 0.30, 0.26, 0, 4.18, -0.66, prof.trimMetal, MAT_PLASTIC)
		vox("SpireBackFlank", 0.24, 0.28, 0.26, 0, 4.18, 0.66, prof.neonPrimary, MAT_NEON)

	elseif style == "VoidCrown" then
		-- Singularity Spiked Void Crystal Crown (Towering crystal needle + 4 flanking spiked crystal peaks)
		vox("VoidSpireBase", 0.88, 0.26, 0.88, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("VoidSpireShaft", 0.44, 0.54, 0.44, 0, 4.28, 0, prof.frameMid, MAT_PLASTIC)
		vox("VoidSpireCore", 0.26, 0.62, 0.26, 0, 4.50, 0, prof.neonPrimary, MAT_NEON)
		vox("VoidSpireTip", 0.14, 0.28, 0.14, 0, 4.88, 0, prof.neonSecondary, MAT_NEON)
		-- 4 Flanking jagged crystal peaks
		for _, cx in ipairs({ -1, 1 }) do
			for _, cz in ipairs({ -1, 1 }) do
				vox("VoidSpikeFoot", 0.32, 0.36, 0.32, cx * 0.92, 4.04, cz * 0.92, prof.frameMid, MAT_PLASTIC)
				vox("VoidSpikeCrystal", 0.18, 0.44, 0.18, cx * 0.92, 4.36, cz * 0.92, prof.neonPrimary, MAT_NEON)
				vox("VoidSpikeTip", 0.10, 0.18, 0.10, cx * 0.92, 4.76, cz * 0.92, prof.neonSecondary, MAT_NEON)
			end
		end

	elseif style == "AstralHalo" then
		-- Astral Floating Celestial Halo Ring
		-- Levitates at ly = 4.35 .. 4.55, formed by an 8-segmented ring + central stellar apex
		vox("HaloMountShaft", 0.20, 0.36, 0.20, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("HaloZenithGem", 0.26, 0.34, 0.26, 0, 4.34, 0, prof.neonSecondary, MAT_NEON)
		vox("HaloZenithPeak", 0.12, 0.22, 0.12, 0, 4.64, 0, prof.neonSecondary, MAT_NEON)
		-- Circular floating halo ring (radius 1.12 studs)
		local ringSegments = if lowDetail then 6 else 10
		for i = 1, ringSegments do
			local ang = ((i - 0.5) / ringSegments) * math.pi * 2
			local rx = math.cos(ang) * 1.12
			local rz = math.sin(ang) * 1.12
			local segW = (2 * math.pi * 1.12 / ringSegments) * 1.08
			local rotCF = CFrame.Angles(0, -ang + math.pi * 0.5, 0)
			vox("HaloRingSeg", segW, 0.16, 0.20, rx, 4.40, rz, prof.neonPrimary, MAT_NEON, rotCF)
		end
		-- 4 Under-halo support prongs
		for _, cx in ipairs({ -1, 1 }) do
			for _, cz in ipairs({ -1, 1 }) do
				vox("HaloProngBase", 0.24, 0.34, 0.24, cx * 1.20, 4.00, cz * 1.20, prof.frameMid, MAT_PLASTIC)
				vox("HaloProngTip", 0.14, 0.22, 0.14, cx * 1.16, 4.28, cz * 1.16, prof.trimMetal, MAT_PLASTIC)
			end
		end

	elseif style == "DivineWings" then
		-- Divine Angelic Wings & Holy Sun Halo
		-- Twin white marble voxel wings flanking outwards + central radiant golden halo
		vox("DivineHaloBase", 0.54, 0.32, 0.54, 0, 4.02, 0, prof.trimMetal, MAT_PLASTIC)
		vox("DivineHaloRing", 0.72, 0.18, 0.72, 0, 4.30, 0, prof.neonPrimary, MAT_NEON)
		vox("DivineHaloCore", 0.28, 0.44, 0.28, 0, 4.22, 0, prof.neonSecondary, MAT_NEON)
		vox("DivineHaloPeak", 0.14, 0.26, 0.14, 0, 4.62, 0, prof.neonSecondary, MAT_NEON)
		-- Left & Right Angelic Feathers (stepped outward & upward)
		for _, side in ipairs({ -1, 1 }) do
			-- Base wing joint
			vox("WingBaseJoint", 0.38, 0.28, 0.42, side * 0.72, 4.04, 0, prof.trimMetal, MAT_PLASTIC)
			-- Feather 1 (Low outer)
			vox("WingFeather1", 0.46, 0.22, 0.28, side * 1.12, 4.18, 0, prof.frameDark, MAT_PLASTIC)
			-- Feather 2 (Mid swept)
			vox("WingFeather2", 0.50, 0.24, 0.26, side * 1.48, 4.38, 0, prof.frameDark, MAT_PLASTIC)
			-- Feather 3 (High crest tip)
			vox("WingFeather3", 0.38, 0.26, 0.22, side * 1.76, 4.62, 0, prof.frameMid, MAT_PLASTIC)
			vox("WingGoldTip", 0.22, 0.18, 0.18, side * 1.88, 4.82, 0, prof.trimMetal, MAT_PLASTIC)
		end

	elseif style == "CosmicOrb" then
		-- Cosmic Floating Celestial Orb + Orbiting Satellite Spheres
		vox("CosmicOrbPedestal", 0.52, 0.24, 0.52, 0, 4.02, 0, prof.frameMid, MAT_PLASTIC)
		vox("CosmicPedestalGem", 0.30, 0.18, 0.30, 0, 4.22, 0, prof.neonPrimary, MAT_NEON)
		-- Central Celestial Nebula Sphere
		local centerOrb = vox("CosmicCentralOrb", 0.94, 0.94, 0.94, 0, 4.32, 0, prof.neonSecondary, MAT_NEON)
		centerOrb.Shape = Enum.PartType.Ball
		-- 4 Orbiting Satellite Micro-Spheres
		local satellites = {
			{ x = 1.05, z = 0.00, col = prof.neonPrimary, s = 0.30 },
			{ x = -1.05, z = 0.00, col = prof.neonPrimary, s = 0.30 },
			{ x = 0.00, z = 0.95, col = prof.neonSecondary, s = 0.26 },
			{ x = 0.00, z = -0.95, col = prof.neonSecondary, s = 0.26 },
		}
		for i, sat in ipairs(satellites) do
			local p = vox("CosmicSatellite_" .. i, sat.s, sat.s, sat.s, sat.x, 4.54, sat.z, sat.col, MAT_NEON)
			p.Shape = Enum.PartType.Ball
		end

	elseif style == "SolarCrown" then
		-- Legendary Multi-Pointed Radiant Sun-Ray Crown
		vox("SolarBaseHub", 0.88, 0.26, 0.88, 0, 4.02, 0, prof.trimAccent, MAT_PLASTIC)
		vox("SolarCenterRay", 0.38, 0.68, 0.38, 0, 4.24, 0, prof.trimMetal, MAT_PLASTIC)
		vox("SolarCenterGem", 0.24, 0.52, 0.24, 0, 4.40, 0, prof.neonPrimary, MAT_NEON)
		vox("SolarApexTip", 0.14, 0.26, 0.14, 0, 4.88, 0, prof.neonSecondary, MAT_NEON)
		-- Radiating rays on 4 cardinals
		for _, dir in ipairs({ { x = 0.72, z = 0 }, { x = -0.72, z = 0 }, { x = 0, z = 0.72 }, { x = 0, z = -0.72 } }) do
			vox("SolarRayMid", 0.28, 0.48, 0.28, dir.x, 4.16, dir.z, prof.trimMetal, MAT_PLASTIC)
			vox("SolarRayGem", 0.16, 0.32, 0.16, dir.x, 4.36, dir.z, prof.neonPrimary, MAT_NEON)
			vox("SolarRayTip", 0.10, 0.18, 0.10, dir.x, 4.64, dir.z, prof.trimAccent, MAT_PLASTIC)
		end

	elseif style == "AmethystCluster" then
		-- Epic Faceted Amethyst Crystal Spires
		vox("AmethystBaseBed", 0.92, 0.24, 0.92, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("AmethystCenterShard", 0.38, 0.58, 0.38, 0, 4.22, 0, prof.neonPrimary, MAT_NEON)
		vox("AmethystCenterTip", 0.18, 0.26, 0.18, 0, 4.76, 0, prof.neonSecondary, MAT_NEON)
		-- Flanking crystal shards of varied heights
		local shards = {
			{ x = 0.56, z = 0.34, h = 0.46, col = prof.trimMetal },
			{ x = -0.56, z = -0.34, h = 0.50, col = prof.neonPrimary },
			{ x = -0.42, z = 0.52, h = 0.40, col = prof.trimAccent },
			{ x = 0.42, z = -0.52, h = 0.44, col = prof.neonPrimary },
		}
		for i, sh in ipairs(shards) do
			vox("AmethystShard_" .. i, 0.24, sh.h, 0.24, sh.x, 4.14, sh.z, sh.col, MAT_PLASTIC)
			vox("AmethystShardTip_" .. i, 0.12, 0.18, 0.12, sh.x, 4.14 + sh.h, sh.z, prof.neonSecondary, MAT_NEON)
		end

	elseif style == "GlacierSpires" then
		-- Rare Glacier / Sapphire Pointed Ice Spires
		vox("GlacierBaseBlock", 0.88, 0.24, 0.88, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("GlacierCenterSpire", 0.36, 0.62, 0.36, 0, 4.24, 0, prof.neonPrimary, MAT_NEON)
		vox("GlacierApexIce", 0.16, 0.24, 0.16, 0, 4.82, 0, prof.neonSecondary, MAT_NEON)
		for _, cx in ipairs({ -1, 1 }) do
			vox("GlacierFlankSpire", 0.26, 0.48, 0.26, cx * 0.74, 4.14, 0, prof.trimMetal, MAT_PLASTIC)
			vox("GlacierFlankTip", 0.14, 0.20, 0.14, cx * 0.74, 4.58, 0, prof.neonPrimary, MAT_NEON)
		end

	elseif style == "EmeraldSpire" then
		-- Uncommon Forest / Emerald Bramble Leaf Spires
		vox("EmeraldBase", 0.86, 0.24, 0.86, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("EmeraldCenterLeaf", 0.32, 0.52, 0.32, 0, 4.22, 0, prof.trimMetal, MAT_PLASTIC)
		vox("EmeraldCenterGem", 0.18, 0.34, 0.18, 0, 4.38, 0, prof.neonPrimary, MAT_NEON)
		vox("EmeraldCenterTip", 0.12, 0.22, 0.12, 0, 4.70, 0, prof.neonSecondary, MAT_NEON)
		for _, cz in ipairs({ -1, 1 }) do
			vox("EmeraldSideLeaf", 0.22, 0.40, 0.22, 0, 4.14, cz * 0.68, prof.trimAccent, MAT_PLASTIC)
			vox("EmeraldSideTip", 0.12, 0.18, 0.12, 0, 4.50, cz * 0.68, prof.neonPrimary, MAT_NEON)
		end

	elseif style == "IronBattlement" then
		-- Common Medieval Stone Battlement Crenels
		vox("IronRoofSlab", 1.10, 0.24, 1.10, 0, 4.02, 0, prof.frameMid, MAT_PLASTIC)
		vox("IronCenterPost", 0.44, 0.34, 0.44, 0, 4.24, 0, prof.frameDark, MAT_PLASTIC)
		vox("IronPyramidCap", 0.24, 0.22, 0.24, 0, 4.54, 0, prof.trimMetal, MAT_PLASTIC)
		for _, cx in ipairs({ -1, 1 }) do
			vox("CrenelBlockX", 0.28, 0.30, 0.54, cx * 0.82, 4.14, 0, prof.frameDark, MAT_PLASTIC)
		end
		for _, cz in ipairs({ -1, 1 }) do
			vox("CrenelBlockZ", 0.54, 0.30, 0.28, 0, 4.14, cz * 0.82, prof.frameDark, MAT_PLASTIC)
		end

	else
		-- Fallback / Specialty (Mythic, Secret, Eternal, Infinity, Omega)
		vox("SpecialtySpireBase", 0.84, 0.26, 0.84, 0, 4.02, 0, prof.frameDark, MAT_PLASTIC)
		vox("SpecialtySpireShaft", 0.40, 0.54, 0.40, 0, 4.24, 0, prof.trimMetal, MAT_PLASTIC)
		vox("SpecialtySpireCore", 0.24, 0.42, 0.24, 0, 4.40, 0, prof.neonPrimary, MAT_NEON)
		vox("SpecialtySpireApex", 0.14, 0.24, 0.14, 0, 4.78, 0, prof.neonSecondary, MAT_NEON)
	end
end

-- Main Build Entry Point
function VoxelCrateBuilder.Build(
	rarity: string,
	biomeId: string?,
	sizeScale: number?,
	opts: BuildOpts?
): Model
	local prof = VoxelCrateBuilder.GetProfile(rarity, biomeId)
	local s = sizeScale or GameConfig.ComputeCrateScale(rarity :: any)
	local isBuried = if opts and opts.isBuried ~= nil then opts.isBuried else true
	local canCollide = if opts and opts.canCollide ~= nil then opts.canCollide else false
	local showBeacon = if opts and opts.showBeacon ~= nil then opts.showBeacon else isBuried
	local styleIdx = math.max(1, math.floor((opts and opts.variant) or 1))
	local lowDetail = (opts and opts.lowDetail == true) or (s < 0.52)

	local bId = biomeId or "PineWoods"
	local crateModel = Instance.new("Model")
	crateModel.Name = string.format("Crate_%s_%s", bId, rarity)
	crateModel:SetAttribute("BiomeId", bId)
	crateModel:SetAttribute("Rarity", rarity)
	crateModel:SetAttribute("SizeScale", s)
	crateModel:SetAttribute("CrateVariant", styleIdx)
	crateModel:SetAttribute("CrateTitle", prof.title)
	crateModel:SetAttribute("IsVoxelCrate", true)

	local baseYUnit = 2.05
	local baseY = baseYUnit * s
	local tilt = if isBuried then CFrame.Angles(math.rad(10), math.rad(12), math.rad(-7)) else CFrame.new()

	local root = Instance.new("Part")
	root.Name = "CrateRoot"
	root.Size = Vector3.new(4.32 * s, 4.10 * s, 4.16 * s)
	root.CFrame = CFrame.new(0, baseY, 0) * tilt
	root.Color = prof.frameDark
	root.Material = MAT_PLASTIC
	root.Transparency = 1
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Anchored = true
	root.CanCollide = canCollide
	root.CanQuery = true
	root.CanTouch = false
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -baseY, 0)
	root.Parent = crateModel

	crateModel.PrimaryPart = root
	crateModel.WorldPivot = CFrame.new(0, 0, 0)

	local rootCF = root.CFrame

	local function vox(
		name: string,
		sx: number,
		sy: number,
		sz: number,
		lx: number,
		lyBottom: number,
		lz: number,
		color: Color3,
		mat: Enum.Material,
		rotCF: CFrame?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx * s, sy * s, sz * s)
		local offsetCF = CFrame.new(lx * s, (lyBottom + sy * 0.5 - baseYUnit) * s, lz * s)
		p.CFrame = rootCF * offsetCF * (rotCF or CFrame.new())
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = (sx * sy * sz >= 0.35) and (mat ~= MAT_NEON)
		p.Parent = crateModel
		return p
	end

	-- 1. Stepped Plinth Base & Corner Feet (Y = 0.00 .. 0.68)
	vox("PlinthBottom", 4.32, 0.26, 4.16, 0, 0.00, 0, prof.frameDark, MAT_PLASTIC)
	vox("PlinthStep", 4.08, 0.30, 3.92, 0, 0.26, 0, prof.frameMid, MAT_PLASTIC)

	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			vox("CornerFoot", 0.98, 0.44, 0.94, cx * 1.82, 0.00, cz * 1.74, prof.frameDark, MAT_PLASTIC)
			vox("CornerFootRim", 0.88, 0.20, 0.84, cx * 1.82, 0.44, cz * 1.74, prof.frameRim, MAT_PLASTIC)
			-- Flared corner claws / toe brackets
			vox("FootClawZ", 0.34, 0.24, 0.22, cx * 1.74, 0.00, cz * 2.18, prof.trimMetal, MAT_PLASTIC)
			vox("FootClawX", 0.22, 0.24, 0.34, cx * 2.26, 0.00, cz * 1.66, prof.trimMetal, MAT_PLASTIC)
			vox("FootClawToe", 0.24, 0.16, 0.24, cx * 2.22, 0.24, cz * 2.12, prof.trimAccent, MAT_PLASTIC)
		end
	end

	-- Front sill & lower horizontal accent slit
	vox("FrontSillBar", 2.48, 0.22, 0.18, 0, 0.24, -2.04, prof.trimAccent, MAT_PLASTIC)
	vox("FrontSillNotch", 0.36, 0.14, 0.12, 0, 0.34, -2.09, prof.neonPrimary, MAT_NEON)
	for _, sx in ipairs({ -1, 1 }) do
		vox("FrontFangBase", 0.26, 0.42, 0.20, sx * 0.32, 0.24, -2.07, prof.trimMetal, MAT_PLASTIC)
		vox("FrontFangTip", 0.16, 0.26, 0.16, sx * 0.32, 0.66, -2.07, prof.trimMetal, MAT_PLASTIC)
		vox("FrontSillStud", 0.22, 0.18, 0.16, sx * 0.92, 0.30, -2.06, prof.frameRim, MAT_PLASTIC)
	end

	-- Back & Side lower sill horizontal energy slits
	vox("BackSillSlit", 2.16, 0.10, 0.10, 0, 0.42, 2.04, prof.neonPrimary, MAT_NEON)
	vox("BackSillStep", 2.38, 0.16, 0.16, 0, 0.24, 2.02, prof.frameDark, MAT_PLASTIC)
	for _, sx in ipairs({ -1, 1 }) do
		vox("SideSillSlit", 0.10, 0.10, 2.00, sx * 2.12, 0.42, 0, prof.neonPrimary, MAT_NEON)
		vox("SideSillStep", 0.16, 0.16, 2.24, sx * 2.10, 0.24, 0, prof.frameDark, MAT_PLASTIC)
	end

	-- 2. Inner Chamber & 4-Face Glowing Panes
	vox("InnerChamberCore", 3.68, 2.94, 3.52, 0, 0.60, 0, prof.chamberCol, MAT_PLASTIC)

	for _, sz in ipairs({ -1, 1 }) do
		local zPane = sz * 1.80
		local zCore = sz * 1.835
		for _, sx in ipairs({ -1, 1 }) do
			vox("GlowPaneFB", 1.08, 2.68, 0.09, sx * 0.66, 0.72, zPane, prof.neonPrimary, MAT_NEON)
			vox("CoreFB", 0.34, 2.48, 0.06, sx * 0.66, 0.82, zCore, prof.neonSecondary, MAT_NEON)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local xPane = sx * 1.88
		local xCore = sx * 1.915
		for _, sz in ipairs({ -1, 1 }) do
			vox("GlowPaneSide", 0.09, 2.68, 0.98, xPane, 0.72, sz * 0.60, prof.neonPrimary, MAT_NEON)
			vox("CoreSide", 0.06, 2.48, 0.32, xCore, 0.82, sz * 0.60, prof.neonSecondary, MAT_NEON)
		end
	end

	-- 3. Four Stepped Corner Pillars + Recessed Vertical Rune Slits & Metallic Collars
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local px, pz = cx * 1.72, cz * 1.64
			vox("CornerPillar", 0.72, 3.24, 0.70, px, 0.56, pz, prof.frameDark, MAT_PLASTIC)

			local fzCheek = cz * 2.02
			local fzRune = cz * 2.01
			vox("PillarCheekZ_Out", 0.24, 2.74, 0.10, px + cx * 0.24, 0.66, fzCheek, prof.frameMid, MAT_PLASTIC)
			vox("PillarCheekZ_In", 0.24, 2.74, 0.10, px - cx * 0.24, 0.66, fzCheek, prof.frameMid, MAT_PLASTIC)
			vox("PillarRuneZV", 0.15, 2.78, 0.06, px, 0.64, fzRune, prof.neonPrimary, MAT_NEON)
			vox("PillarRuneZTopPlus", 0.52, 0.15, 0.10, px, 3.16, cz * 2.04, prof.neonPrimary, MAT_NEON)
			vox("PillarRuneZBotPlus", 0.52, 0.15, 0.10, px, 0.72, cz * 2.04, prof.neonPrimary, MAT_NEON)

			local fxCheek = cx * 2.11
			local fxRune = cx * 2.10
			vox("PillarCheekX_Out", 0.10, 2.74, 0.24, fxCheek, 0.66, pz + cz * 0.24, prof.frameMid, MAT_PLASTIC)
			vox("PillarCheekX_In", 0.10, 2.74, 0.24, fxCheek, 0.66, pz - cz * 0.24, prof.frameMid, MAT_PLASTIC)
			vox("PillarRuneXV", 0.06, 2.78, 0.15, fxRune, 0.64, pz, prof.neonPrimary, MAT_NEON)
			vox("PillarRuneXTopPlus", 0.10, 0.15, 0.50, cx * 2.13, 3.16, pz, prof.neonPrimary, MAT_NEON)
			vox("PillarRuneXBotPlus", 0.10, 0.15, 0.50, cx * 2.13, 0.72, pz, prof.neonPrimary, MAT_NEON)

			vox("PillarGoldCollar", 0.88, 0.26, 0.86, cx * 1.76, 3.44, cz * 1.68, prof.trimMetal, MAT_PLASTIC)
			vox("PillarBronzeStep", 0.76, 0.14, 0.74, cx * 1.80, 3.30, cz * 1.72, prof.trimAccent, MAT_PLASTIC)
		end
	end

	-- 4. Diagonal Wrapped Exterior Chains (The hallmark feature of the 10 designs)
	buildWrappedChains(vox, prof, lowDetail)

	-- 5. Front View (-Z): Bars, Stepped Diamond Medallion Lock & Lid Clasp
	vox("FrontHBar", 2.60, 0.26, 0.16, 0, 1.74, -1.91, prof.frameDark, MAT_PLASTIC)
	vox("FrontVCenterBar", 0.26, 2.86, 0.16, 0, 0.66, -1.91, prof.frameDark, MAT_PLASTIC)
	for _, sx in ipairs({ -1, 1 }) do
		vox("FrontInnerMul", 0.18, 2.74, 0.12, sx * 0.88, 0.68, -1.90, prof.frameMid, MAT_PLASTIC)
	end
	vox("FrontTopLintel", 2.60, 0.36, 0.22, 0, 3.50, -1.94, prof.frameDark, MAT_PLASTIC)
	vox("FrontBotLintel", 2.60, 0.24, 0.20, 0, 0.48, -1.94, prof.frameDark, MAT_PLASTIC)

	buildFaceDiamond(
		vox,
		"Front",
		0,
		1.86,
		-1.94,
		-1,
		prof,
		if lowDetail then 0.20 else 0.155,
		if lowDetail then 3 else 4,
		if lowDetail then 0.35 else 0.40,
		lowDetail
	)

	-- Front Upper Lid Clasp above Lock
	vox("ClaspCenterObs", 0.46, 0.78, 0.20, 0, 3.12, -2.04, prof.frameDark, MAT_PLASTIC)
	vox("ClaspCenterGem", 0.16, 0.38, 0.10, 0, 3.30, -2.11, prof.neonPrimary, MAT_NEON)
	vox("ClaspCenterFang", 0.24, 0.44, 0.18, 0, 2.76, -2.07, prof.trimMetal, MAT_PLASTIC)
	vox("ClaspFangTip", 0.12, 0.16, 0.16, 0, 2.62, -2.08, prof.trimMetal, MAT_PLASTIC)
	vox("ClaspCrownPeak", 0.22, 0.46, 0.16, 0, 3.90, -2.04, prof.trimMetal, MAT_PLASTIC)
	vox("ClaspCrownTip", 0.12, 0.22, 0.14, 0, 4.36, -2.04, prof.trimMetal, MAT_PLASTIC)
	for _, sx in ipairs({ -1, 1 }) do
		vox("ClaspWingOuter", 0.56, 0.24, 0.18, sx * 0.88, 3.66, -2.04, prof.trimMetal, MAT_PLASTIC)
		vox("ClaspWingMid", 0.48, 0.24, 0.18, sx * 0.50, 3.44, -2.05, prof.trimMetal, MAT_PLASTIC)
		vox("ClaspWingLow", 0.34, 0.24, 0.18, sx * 0.24, 3.20, -2.06, prof.trimAccent, MAT_PLASTIC)
		vox("ClaspWingTooth", 0.16, 0.20, 0.14, sx * 0.72, 3.46, -2.06, prof.frameRim, MAT_PLASTIC)
	end

	-- 6. Back & Sides: Bars, Stepped X-Braces & Diamond Locks
	local xSteps = if lowDetail then 2 else 3
	local sideDiamondStep = if lowDetail then 0.18 else 0.14
	local sideDiamondRings = 3

	-- Back (+Z)
	vox("BackHBar", 2.60, 0.24, 0.14, 0, 1.92, 1.91, prof.frameDark, MAT_PLASTIC)
	vox("BackVBar", 0.24, 2.74, 0.14, 0, 0.68, 1.91, prof.frameDark, MAT_PLASTIC)
	vox("BackTopFriezeSlit", 2.28, 0.11, 0.10, 0, 3.36, 1.96, prof.neonPrimary, MAT_NEON)
	vox("BackTopLintel", 2.60, 0.36, 0.22, 0, 3.50, 1.94, prof.frameDark, MAT_PLASTIC)
	buildSteppedXBrace(vox, "Back", 1.92, 1, 1.10, 2.04, 1.10, xSteps, prof)
	buildFaceDiamond(vox, "Back", 0, 2.04, 1.95, 1, prof, sideDiamondStep, sideDiamondRings, 0.28, lowDetail)

	-- Sides (-X / +X)
	for _, sx in ipairs({ -1, 1 }) do
		local fName = if sx > 0 then "Right" else "Left"
		vox(fName .. "HBar", 0.14, 0.24, 2.48, sx * 1.99, 1.92, 0, prof.frameDark, MAT_PLASTIC)
		vox(fName .. "VBar", 0.14, 2.74, 0.24, sx * 1.99, 0.68, 0, prof.frameDark, MAT_PLASTIC)
		vox(fName .. "TopFriezeSlit", 0.10, 0.11, 2.12, sx * 2.04, 3.36, 0, prof.neonPrimary, MAT_NEON)
		vox(fName .. "TopLintel", 0.22, 0.36, 2.48, sx * 2.02, 3.50, 0, prof.frameDark, MAT_PLASTIC)
		buildSteppedXBrace(vox, fName, 2.00, sx, 1.04, 2.04, 1.10, xSteps, prof)
		buildFaceDiamond(vox, fName, 0, 2.04, 2.03, sx, prof, sideDiamondStep, sideDiamondRings, 0.28, lowDetail)
	end

	-- 7. Roof Chamber, Lattice Crossbeams, Cornice & Corner Turrets
	vox("RoofChamberBase", 3.60, 0.22, 3.44, 0, 3.74, 0, prof.chamberCol, MAT_PLASTIC)
	vox("RoofNeonGlow", 3.24, 0.12, 3.08, 0, 3.90, 0, prof.neonPrimary, MAT_NEON)
	for _, gx in ipairs({ -1.04, 0, 1.04 }) do
		vox("RoofLatticeZ", 0.22, 0.18, 3.04, gx, 3.92, 0, prof.frameDark, MAT_PLASTIC)
	end
	for _, gz in ipairs({ -0.98, 0, 0.98 }) do
		vox("RoofLatticeX", 3.22, 0.16, 0.22, 0, 3.91, gz, prof.frameDark, MAT_PLASTIC)
	end

	for _, sz in ipairs({ -1, 1 }) do
		vox("CrownRimZ", 2.82, 0.30, 0.42, 0, 3.80, sz * 1.76, prof.frameDark, MAT_PLASTIC)
		vox("CrownCrenelMidZ", 0.62, 0.22, 0.38, 0, 4.10, sz * 1.78, prof.frameMid, MAT_PLASTIC)
	end
	for _, sx in ipairs({ -1, 1 }) do
		vox("CrownRimX", 0.42, 0.30, 2.66, sx * 1.84, 3.80, 0, prof.frameDark, MAT_PLASTIC)
		vox("CrownCrenelMidX", 0.38, 0.22, 0.62, sx * 1.86, 4.10, 0, prof.frameMid, MAT_PLASTIC)
		vox("CrownSideGold", 0.24, 0.20, 0.34, sx * 1.90, 4.16, 0, prof.trimMetal, MAT_PLASTIC)
	end

	-- Four Pointed Corner Turrets
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local tx, tz = cx * 1.76, cz * 1.68
			vox("CornerTurretBase", 0.68, 0.34, 0.68, tx, 3.80, tz, prof.frameDark, MAT_PLASTIC)
			vox("CornerTurretStep", 0.46, 0.28, 0.46, cx * 1.78, 4.14, cz * 1.70, prof.frameMid, MAT_PLASTIC)
			vox("CornerTurretFinial", 0.28, 0.28, 0.28, cx * 1.80, 4.42, cz * 1.72, prof.trimMetal, MAT_PLASTIC)
		end
	end

	-- 8. Unique Crown Ornaments for Each Rarity Archetype
	buildCrownOrnaments(vox, prof, lowDetail)

	-- 9. TowRing preserved invisibly for gameplay tow attachment compatibility
	local ring = vox("TowRing", 0.72, 0.72, 0.72, 0, 4.00, 0, prof.neonPrimary, MAT_PLASTIC)
	ring.Shape = Enum.PartType.Ball
	ring.Transparency = 1
	ring.CastShadow = false

	-- 10. Optional Rarity Beacons for Buried / Wild State
	local tier = GameConfig.GetRarityTier(rarity :: any)
	if showBeacon and tier >= 3 then
		local beamHeight = if tier >= GameConfig.COSMIC_TIER_THRESHOLD then 48 + (tier - 6) * 6 else 32
		local beamWidth = if tier >= GameConfig.COSMIC_TIER_THRESHOLD then 1.35 * s else 1.0 * s
		local beacon = vox("RarityBeacon", beamWidth / s, beamHeight / s, beamWidth / s, 0, 2.05, 0, prof.neonPrimary, MAT_PLASTIC)
		beacon.Transparency = 0.82
		if tier >= GameConfig.COSMIC_TIER_THRESHOLD then
			local innerCore = vox("CosmicBeaconCore", 0.42, (beamHeight + 8) / s, 0.42, 0, 2.05, 0, prof.neonSecondary, MAT_NEON)
			innerCore.Transparency = 0.68
		end
	end

	return crateModel
end

return VoxelCrateBuilder
