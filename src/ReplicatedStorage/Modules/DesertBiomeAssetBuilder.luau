--!strict
-- DesertBiomeAssetBuilder.luau
-- 46-Asset Voxel Desert Biome Asset Pack for SavannaCamp matching visual reference.
-- Builds ServerStorage.DesertBiomeAssets organized into 10 clean subfolders:
-- Trees (4), Cacti (4), Bushes (2), Plants (5), Rocks (4), TerrainProps (4),
-- Ruins (4), Structures (4), Decorations (9), WaterFeatures (6).
-- Pure rectangular Studs/Glass/Neon/SmoothPlastic Parts, Anchored = true, CanCollide/CanQuery/CanTouch = false,
-- PrimaryPart = RootPivot at ground origin CFrame.identity.

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ClassicStudBiomeBuilder = require(script.Parent.ClassicStudBiomeBuilder)

local DesertBiomeAssetBuilder = {}

export type AssetBuilderFn = (cframe: CFrame, scale: number?, parent: Instance?) -> Model

export type AssetEntry = {
	name: string,
	category: string,
	build: AssetBuilderFn,
}

DesertBiomeAssetBuilder.CATEGORIES = {
	"Trees",
	"Cacti",
	"Bushes",
	"Plants",
	"Rocks",
	"TerrainProps",
	"Ruins",
	"Structures",
	"Decorations",
	"WaterFeatures",
}

-- ============================================================================
-- VISUAL PALETTE (Golden Sand, Warm Sandstone, Terracotta & Turquoise Oasis)
-- ============================================================================

local P = {
	SAND_BRIGHT = Color3.fromRGB(246, 212, 134),
	SAND_GOLD = Color3.fromRGB(236, 192, 104),
	SAND_TAN = Color3.fromRGB(214, 162, 86),
	STONE_WARM = Color3.fromRGB(224, 168, 96),
	STONE_ORANGE = Color3.fromRGB(204, 128, 66),
	TERRACOTTA = Color3.fromRGB(176, 92, 48),
	TERRACOTTA_DARK = Color3.fromRGB(136, 68, 38),

	CACTUS_DEEP = Color3.fromRGB(44, 124, 48),
	CACTUS_MID = Color3.fromRGB(68, 158, 56),
	CACTUS_LIME = Color3.fromRGB(114, 196, 68),
	PALM_DARK = Color3.fromRGB(52, 128, 48),
	PALM_MID = Color3.fromRGB(86, 168, 56),
	PALM_LIME = Color3.fromRGB(132, 206, 68),
	DRY_GOLD = Color3.fromRGB(226, 184, 72),
	DRY_OCHRE = Color3.fromRGB(178, 136, 56),
	SUCCULENT_TEAL = Color3.fromRGB(68, 148, 96),
	VINE_DESERT = Color3.fromRGB(98, 164, 60),

	BLOSSOM_PINK = Color3.fromRGB(244, 102, 154),
	BLOSSOM_CORAL = Color3.fromRGB(248, 124, 58),
	BLOSSOM_PURPLE = Color3.fromRGB(162, 92, 232),
	BLOSSOM_YELLOW = Color3.fromRGB(255, 218, 72),

	WOOD_DARK = Color3.fromRGB(104, 66, 38),
	WOOD_MID = Color3.fromRGB(144, 92, 50),
	WOOD_LIGHT = Color3.fromRGB(178, 124, 72),
	CANVAS_CREAM = Color3.fromRGB(238, 224, 192),
	BONE_IVORY = Color3.fromRGB(240, 232, 216),
	BANNER_RED = Color3.fromRGB(196, 52, 48),
	GOLD_TRIM = Color3.fromRGB(248, 198, 58),

	LANTERN_IRON = Color3.fromRGB(56, 48, 46),
	LANTERN_GLOW = Color3.fromRGB(255, 204, 74),

	WATER_TURQ = Color3.fromRGB(36, 206, 224),
	WATER_DEEP = Color3.fromRGB(22, 118, 144),
	WATER_FALL = Color3.fromRGB(76, 228, 246),
	WATER_FOAM = Color3.fromRGB(234, 252, 255),
}

-- ============================================================================
-- CORE GEOMETRY & REUSABLE ASSET HELPERS
-- ============================================================================

local function ensureStuds()
	ClassicStudBiomeBuilder.EnsureClassicStudsVariant()
	if not MaterialService:FindFirstChild("Studs", true) and not (RunService:IsRunning() and not RunService:IsStudio()) then
		pcall(function()
			local v = Instance.new("MaterialVariant")
			v.Name = "Studs"
			v.BaseMaterial = Enum.Material.Plastic
			v.StudsPerTile = 1
			v.Parent = MaterialService
		end)
	end
end

local function newModel(category: string, assetId: string, originCF: CFrame, parent: Instance?): Model
	ensureStuds()
	local m = Instance.new("Model")
	m.Name = assetId
	m:SetAttribute("AssetCategory", category)
	m:SetAttribute("AssetId", assetId)
	m:SetAttribute("BiomeId", "SavannaCamp")

	local anchor = Instance.new("Part")
	anchor.Name = "RootPivot"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = originCF
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Parent = m

	m.PrimaryPart = anchor
	m.WorldPivot = originCF
	if parent then
		m.Parent = parent
	end
	return m
end

local function addBox(
	m: Model,
	originCF: CFrame,
	s: number,
	name: string,
	size: Vector3,
	localCF: CFrame,
	color: Color3,
	mat: Enum.Material?,
	studded: boolean?,
	transparency: number?,
	castShadow: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * s
	local rot = localCF - localCF.Position
	p.CFrame = originCF * CFrame.new(localCF.Position * s) * rot
	p.Color = color
	local material = mat or Enum.Material.Plastic
	p.Material = material
	local useStuds = (studded ~= false) and (material == Enum.Material.Plastic)
	if useStuds then
		p.MaterialVariant = "Studs"
	end
	p.TopSurface = if useStuds then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = if castShadow ~= nil then castShadow else true
	p.Transparency = transparency or 0
	p.Parent = m
	return p
end

local function addAmberLantern(m: Model, originCF: CFrame, s: number, prefix: string, center: Vector3, range: number?, brightness: number?)
	local br = brightness or 0.85
	addBox(m, originCF, s, prefix .. "_TopCap", Vector3.new(1.2, 0.26, 1.2), CFrame.new(center + Vector3.new(0, 0.6, 0)), P.LANTERN_IRON)
	addBox(m, originCF, s, prefix .. "_BotCap", Vector3.new(1.12, 0.24, 1.12), CFrame.new(center + Vector3.new(0, -0.58, 0)), P.LANTERN_IRON)
	for _, corner in ipairs({
		Vector3.new(-0.44, 0, -0.44),
		Vector3.new(0.44, 0, -0.44),
		Vector3.new(-0.44, 0, 0.44),
		Vector3.new(0.44, 0, 0.44),
	}) do
		addBox(m, originCF, s, prefix .. "_Strut", Vector3.new(0.16, 0.96, 0.16), CFrame.new(center + corner), P.LANTERN_IRON)
	end
	local glow = addBox(m, originCF, s, prefix .. "_Glow", Vector3.new(0.76, 0.94, 0.76), CFrame.new(center), P.LANTERN_GLOW, Enum.Material.Neon, false, 0, false)
	local pl = Instance.new("PointLight")
	pl.Name = "LanternLight"
	pl.Color = P.LANTERN_GLOW
	pl.Range = range or 16
	pl.Brightness = br
	pl.Shadows = false
	pl:SetAttribute("AnimKind", "LanternPulse")
	pl:SetAttribute("BaseBrightness", br)
	pl:SetAttribute("Phase", (math.abs(center.X) + math.abs(center.Z)) * 0.39)
	pl.Parent = glow
end

local function addPawBanner(m: Model, originCF: CFrame, s: number, prefix: string, center: Vector3, scaleW: number?, yawDeg: number?)
	local bw = scaleW or 1.0
	local cf = CFrame.new(center) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
	addBox(m, originCF, s, prefix .. "_Rod", Vector3.new(2.5 * bw, 0.28, 0.28), cf * CFrame.new(0, 1.8 * bw, 0), P.WOOD_DARK)
	addBox(m, originCF, s, prefix .. "_Cloth", Vector3.new(2.2 * bw, 3.2 * bw, 0.22), cf, P.BANNER_RED)
	addBox(m, originCF, s, prefix .. "_Tail", Vector3.new(1.3 * bw, 0.75 * bw, 0.22), cf * CFrame.new(0, -1.85 * bw, 0), P.BANNER_RED)
	addBox(m, originCF, s, prefix .. "_GoldBar", Vector3.new(2.3 * bw, 0.24 * bw, 0.28), cf * CFrame.new(0, 1.55 * bw, 0), P.GOLD_TRIM)
	-- Voxel paw-print emblem on banner front
	addBox(m, originCF, s, prefix .. "_PawPad", Vector3.new(0.88 * bw, 0.72 * bw, 0.30), cf * CFrame.new(0, -0.22 * bw, 0), P.BONE_IVORY, nil, true, 0, false)
	for i, toe in ipairs({
		Vector3.new(-0.56 * bw, 0.40 * bw, 0),
		Vector3.new(-0.20 * bw, 0.62 * bw, 0),
		Vector3.new(0.20 * bw, 0.62 * bw, 0),
		Vector3.new(0.56 * bw, 0.40 * bw, 0),
	}) do
		addBox(m, originCF, s, prefix .. "_PawToe_" .. i, Vector3.new(0.26 * bw, 0.34 * bw, 0.30), cf * CFrame.new(toe), P.BONE_IVORY, nil, true, 0, false)
	end
end

local function addDesertVine(m: Model, originCF: CFrame, s: number, prefix: string, topPos: Vector3, len: number)
	local segs = math.max(2, math.floor(len / 1.4))
	local segH = len / segs
	for i = 1, segs do
		local col = if i % 2 == 0 then P.CACTUS_LIME else P.VINE_DESERT
		addBox(m, originCF, s, prefix .. "_" .. i, Vector3.new(0.42, segH + 0.06, 0.42), CFrame.new(topPos.X + (i % 2 == 0 and 0.14 or -0.08), topPos.Y - (i - 0.5) * segH, topPos.Z), col, nil, true, 0, false)
	end
end

local function addSandDrift(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, w: number, d: number)
	addBox(m, originCF, s, prefix .. "_Base", Vector3.new(w, 0.48, d), CFrame.new(pos), P.SAND_GOLD, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Crest", Vector3.new(w * 0.64, 0.38, d * 0.64), CFrame.new(pos + Vector3.new(w * 0.1, 0.32, -d * 0.08)), P.SAND_BRIGHT, nil, true, 0, false)
end

local function addLilyPad(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, radius: number, yawDeg: number, lotusCol: Color3?)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	addBox(m, originCF, s, prefix .. "_Pad", Vector3.new(radius, 0.14, radius * 0.88), cf, P.PALM_MID, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Trim", Vector3.new(radius * 0.56, 0.16, radius * 0.52), cf * CFrame.new(radius * 0.12, 0.04, -radius * 0.08), P.PALM_LIME, nil, true, 0, false)
	if lotusCol then
		addBox(m, originCF, s, prefix .. "_LotusOut", Vector3.new(0.78, 0.24, 0.78), cf * CFrame.new(0, 0.18, 0), lotusCol, nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_LotusCore", Vector3.new(0.32, 0.28, 0.32), cf * CFrame.new(0, 0.34, 0), P.BLOSSOM_YELLOW, nil, true, 0, false)
	end
end

local function addRippleRings(m: Model, originCF: CFrame, s: number, centerPos: Vector3, sizeXZ: Vector2, count: number, speed: number)
	for i = 1, count do
		local ripCF = CFrame.new(centerPos)
		local rip = addBox(m, originCF, s, "RippleRing_" .. i, Vector3.new(sizeXZ.X, 0.08, sizeXZ.Y), ripCF, P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 0.45, false)
		rip:SetAttribute("AnimKind", "RippleRing")
		rip:SetAttribute("BaseLocalCF", ripCF)
		rip:SetAttribute("Phase", (i - 1) / count)
		rip:SetAttribute("Speed", speed)
	end
end

-- ============================================================================
-- 1. TREES (4)
-- ============================================================================

local function buildPalmHelper(assetId: string, cframe: CFrame, scale: number?, parent: Instance?, trunkSegs: number, frondLenScale: number): Model
	local s = scale or 1
	local m = newModel("Trees", assetId, cframe, parent)
	addBox(m, cframe, s, "SandMound", Vector3.new(3.2, 0.55, 3.2), CFrame.new(0, 0.28, 0), P.SAND_GOLD)
	addBox(m, cframe, s, "BaseTuft", Vector3.new(1.8, 0.55, 1.8), CFrame.new(0, 0.72, 0), P.PALM_DARK)

	local curX, curY = 0, 0.95
	for i = 1, trunkSegs do
		local w = math.max(0.85, 1.55 - (i - 1) * 0.1)
		local h = if trunkSegs >= 6 then 1.9 else 1.55
		curX += 0.26 * (i / trunkSegs) * 2.2
		curY += h * 0.92
		addBox(m, cframe, s, "TrunkSeg_" .. i, Vector3.new(w, h + 0.15, w), CFrame.new(curX, curY - h * 0.4, 0) * CFrame.Angles(0, 0, math.rad(-9)), if i % 2 == 0 then P.WOOD_MID else P.WOOD_LIGHT)
	end

	local top = Vector3.new(curX + 0.15, curY + 0.3, 0)
	addBox(m, cframe, s, "CrownHub", Vector3.new(2.2, 1.1, 2.2), CFrame.new(top), P.PALM_DARK)
	if trunkSegs >= 6 then
		for i, cOff in ipairs({ Vector3.new(-0.75, -0.65, 0.55), Vector3.new(0.75, -0.65, 0.5), Vector3.new(0, -0.7, -0.75) }) do
			addBox(m, cframe, s, "Coconut_" .. i, Vector3.new(0.6, 0.6, 0.6), CFrame.new(top + cOff), P.WOOD_DARK)
		end
	end
	local frondCount = if trunkSegs >= 6 then 6 else 5
	for i = 1, frondCount do
		local rot = CFrame.new(top) * CFrame.Angles(0, math.rad((i - 1) * (360 / frondCount) + 14), 0)
		addBox(m, cframe, s, "FrondA_" .. i, Vector3.new(2.6 * frondLenScale, 0.58, 1.3), rot * CFrame.new(1.9 * frondLenScale, 0.4, 0) * CFrame.Angles(0, 0, math.rad(12)), P.PALM_MID)
		addBox(m, cframe, s, "FrondB_" .. i, Vector3.new(2.3 * frondLenScale, 0.5, 1.1), rot * CFrame.new(4.0 * frondLenScale, 0.1, 0) * CFrame.Angles(0, 0, math.rad(-14)), P.PALM_LIME)
		addBox(m, cframe, s, "FrondTip_" .. i, Vector3.new(1.4 * frondLenScale, 0.42, 0.85), rot * CFrame.new(5.4 * frondLenScale, -0.75, 0) * CFrame.Angles(0, 0, math.rad(-32)), P.PALM_LIME)
	end
	return m
end

local function buildDesertPalmTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	return buildPalmHelper("DesertPalmTree", cframe, scale, parent, 6, 1.0)
end

local function buildSmallPalmTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	return buildPalmHelper("SmallPalmTree", cframe, scale, parent, 4, 0.78)
end

local function buildDeadDesertTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "DeadDesertTree", cframe, parent)
	for i, off in ipairs({ Vector3.new(-1.3, 0.45, 0.2), Vector3.new(1.3, 0.45, -0.2), Vector3.new(0.2, 0.45, 1.2) }) do
		addBox(m, cframe, s, "DeadRoot_" .. i, Vector3.new(1.2, 0.9, 1.1), CFrame.new(off), P.WOOD_DARK)
	end
	addBox(m, cframe, s, "TrunkLow", Vector3.new(2.0, 4.4, 1.9), CFrame.new(0, 2.2, 0), P.WOOD_MID)
	addBox(m, cframe, s, "TrunkMid", Vector3.new(1.5, 4.0, 1.5), CFrame.new(-0.25, 5.6, 0.1) * CFrame.Angles(0, 0, math.rad(10)), P.WOOD_DARK)
	addBox(m, cframe, s, "BoughL", Vector3.new(3.6, 0.9, 0.9), CFrame.new(-2.1, 6.8, 0.2) * CFrame.Angles(0, 0, math.rad(-26)), P.WOOD_MID)
	addBox(m, cframe, s, "TwigL", Vector3.new(0.8, 2.2, 0.8), CFrame.new(-3.6, 8.2, 0.2) * CFrame.Angles(0, 0, math.rad(18)), P.WOOD_DARK)
	addBox(m, cframe, s, "BoughR", Vector3.new(3.4, 0.85, 0.85), CFrame.new(1.8, 6.0, -0.2) * CFrame.Angles(0, 0, math.rad(28)), P.WOOD_DARK)
	addBox(m, cframe, s, "TwigR", Vector3.new(0.8, 2.0, 0.8), CFrame.new(3.2, 7.5, -0.2) * CFrame.Angles(0, 0, math.rad(-14)), P.WOOD_MID)
	addBox(m, cframe, s, "BaseAgave", Vector3.new(1.1, 0.8, 1.1), CFrame.new(1.6, 0.4, 1.1), P.SUCCULENT_TEAL, nil, true, 0, false)
	return m
end

local function buildAncientTwistedTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "AncientTwistedTree", cframe, parent)
	addSandDrift(m, cframe, s, "TreeDrift", Vector3.new(0, 0.24, 0), 4.6, 4.2)
	addBox(m, cframe, s, "KnotTrunk", Vector3.new(2.8, 4.8, 2.6), CFrame.new(0, 2.6, 0), P.WOOD_DARK)
	addBox(m, cframe, s, "TwistLimbL", Vector3.new(4.2, 1.2, 1.3), CFrame.new(-2.2, 5.4, 0.4) * CFrame.Angles(0, 0.2, math.rad(-18)), P.WOOD_MID)
	addBox(m, cframe, s, "TwistLimbR", Vector3.new(4.0, 1.1, 1.2), CFrame.new(2.0, 6.2, -0.3) * CFrame.Angles(0, -0.2, math.rad(20)), P.WOOD_DARK)
	-- Sparse sun-baked scrub foliage crowns
	addBox(m, cframe, s, "LeafPadL", Vector3.new(4.4, 1.8, 4.0), CFrame.new(-3.4, 6.8, 0.6), P.DRY_OCHRE)
	addBox(m, cframe, s, "LeafPadR", Vector3.new(4.8, 1.9, 4.2), CFrame.new(3.0, 7.8, -0.4), P.PALM_DARK)
	addBox(m, cframe, s, "LeafPadTop", Vector3.new(3.4, 1.4, 3.2), CFrame.new(2.8, 9.0, -0.4), P.PALM_MID)
	return m
end

-- ============================================================================
-- 2. CACTI (4)
-- ============================================================================

local function buildTallSaguaroCactus(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Cacti", "TallSaguaroCactus", cframe, parent)
	addBox(m, cframe, s, "CactusBase", Vector3.new(3.6, 0.4, 3.4), CFrame.new(0, 0.2, 0), P.CACTUS_DEEP)
	addBox(m, cframe, s, "MainCol", Vector3.new(2.1, 11.4, 2.1), CFrame.new(0, 5.9, 0), P.CACTUS_MID)
	addBox(m, cframe, s, "RibTrim", Vector3.new(2.26, 10.6, 0.85), CFrame.new(0, 5.8, 0), P.CACTUS_LIME)

	-- Left lower arm + Right upper arm + Third rear spur (matching reference hero cactus!)
	addBox(m, cframe, s, "ArmL_H", Vector3.new(2.6, 1.4, 1.4), CFrame.new(-2.1, 5.2, 0), P.CACTUS_DEEP)
	addBox(m, cframe, s, "ArmL_V", Vector3.new(1.4, 4.2, 1.4), CFrame.new(-2.9, 7.2, 0), P.CACTUS_MID)
	addBox(m, cframe, s, "ArmR_H", Vector3.new(2.4, 1.4, 1.4), CFrame.new(2.0, 6.6, 0), P.CACTUS_DEEP)
	addBox(m, cframe, s, "ArmR_V", Vector3.new(1.4, 3.8, 1.4), CFrame.new(2.7, 8.4, 0), P.CACTUS_LIME)
	addBox(m, cframe, s, "PupSide", Vector3.new(1.1, 3.4, 1.1), CFrame.new(-1.5, 1.9, 1.2), P.CACTUS_LIME)

	-- Pink cactus flowers on top crown & arm tips
	addBox(m, cframe, s, "BloomTop", Vector3.new(1.1, 0.7, 1.1), CFrame.new(0, 11.85, 0), P.BLOSSOM_PINK, nil, true, 0, false)
	addBox(m, cframe, s, "BloomL", Vector3.new(0.8, 0.55, 0.8), CFrame.new(-2.9, 9.5, 0), P.BLOSSOM_PINK, nil, true, 0, false)
	return m
end

local function buildSmallSaguaroCactus(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Cacti", "SmallSaguaroCactus", cframe, parent)
	addBox(m, cframe, s, "BaseSand", Vector3.new(2.4, 0.3, 2.4), CFrame.new(0, 0.15, 0), P.SAND_GOLD, nil, true, 0, false)
	addBox(m, cframe, s, "Stem", Vector3.new(1.4, 5.6, 1.4), CFrame.new(0, 2.9, 0), P.CACTUS_MID)
	addBox(m, cframe, s, "ArmL", Vector3.new(1.5, 1.0, 1.0), CFrame.new(-1.3, 2.6, 0), P.CACTUS_DEEP)
	addBox(m, cframe, s, "ArmLUp", Vector3.new(1.0, 2.2, 1.0), CFrame.new(-1.7, 3.7, 0), P.CACTUS_LIME)
	addBox(m, cframe, s, "ArmR", Vector3.new(1.4, 0.95, 0.95), CFrame.new(1.25, 3.2, 0), P.CACTUS_MID)
	addBox(m, cframe, s, "ArmRUp", Vector3.new(0.95, 1.7, 0.95), CFrame.new(1.65, 4.0, 0), P.CACTUS_LIME)
	return m
end

local function buildPricklyPearCactus(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Cacti", "PricklyPearCactus", cframe, parent)
	addBox(m, cframe, s, "PadBase", Vector3.new(1.8, 1.6, 0.65), CFrame.new(0, 0.8, 0), P.CACTUS_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "PadL", Vector3.new(1.5, 1.5, 0.58), CFrame.new(-1.1, 2.1, 0.1) * CFrame.Angles(0, 0.3, math.rad(14)), P.CACTUS_MID, nil, true, 0, false)
	addBox(m, cframe, s, "PadR", Vector3.new(1.6, 1.7, 0.58), CFrame.new(0.95, 2.2, -0.1) * CFrame.Angles(0, -0.25, math.rad(-12)), P.CACTUS_LIME, nil, true, 0, false)
	addBox(m, cframe, s, "PadTop", Vector3.new(1.2, 1.2, 0.5), CFrame.new(1.1, 3.5, -0.1) * CFrame.Angles(0, 0.2, math.rad(10)), P.CACTUS_MID, nil, true, 0, false)
	addBox(m, cframe, s, "PearFruitA", Vector3.new(0.48, 0.52, 0.48), CFrame.new(-1.2, 3.0, 0.1), P.BLOSSOM_CORAL, nil, true, 0, false)
	addBox(m, cframe, s, "PearFruitB", Vector3.new(0.48, 0.52, 0.48), CFrame.new(1.1, 4.25, -0.1), P.BLOSSOM_PINK, nil, true, 0, false)
	return m
end

local function buildFloweringCactus(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Cacti", "FloweringCactus", cframe, parent)
	addBox(m, cframe, s, "SandTuft", Vector3.new(3.0, 0.28, 2.8), CFrame.new(0, 0.14, 0), P.SAND_TAN, nil, true, 0, false)
	addBox(m, cframe, s, "BarrelBody", Vector3.new(2.2, 2.0, 2.2), CFrame.new(-0.3, 1.15, 0), P.CACTUS_MID, nil, true, 0, false)
	addBox(m, cframe, s, "BarrelRibs", Vector3.new(2.38, 1.6, 1.3), CFrame.new(-0.3, 1.15, 0), P.CACTUS_LIME, nil, true, 0, false)
	addBox(m, cframe, s, "SideOrb", Vector3.new(1.3, 1.4, 1.3), CFrame.new(1.25, 0.85, 0.35), P.CACTUS_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "BloomMain", Vector3.new(1.05, 0.65, 1.05), CFrame.new(-0.3, 2.4, 0), P.BLOSSOM_PINK, nil, true, 0, false)
	addBox(m, cframe, s, "BloomCore", Vector3.new(0.48, 0.55, 0.48), CFrame.new(-0.3, 2.75, 0), P.BLOSSOM_YELLOW, nil, true, 0, false)
	addBox(m, cframe, s, "BloomSide", Vector3.new(0.65, 0.45, 0.65), CFrame.new(1.25, 1.7, 0.35), P.BLOSSOM_CORAL, nil, true, 0, false)
	return m
end

-- ============================================================================
-- 3. BUSHES (2)
-- ============================================================================

local function buildDryDesertBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "DryDesertBush", cframe, parent)
	addBox(m, cframe, s, "ScrubBase", Vector3.new(3.6, 1.3, 3.2), CFrame.new(0, 0.65, 0), P.DRY_OCHRE, nil, true, 0, false)
	addBox(m, cframe, s, "ScrubWingL", Vector3.new(2.0, 1.6, 2.2), CFrame.new(-1.1, 0.9, 0.3), P.SAND_TAN, nil, true, 0, false)
	addBox(m, cframe, s, "ScrubTop", Vector3.new(2.2, 1.1, 2.0), CFrame.new(0.3, 1.65, -0.2), P.DRY_GOLD, nil, true, 0, false)
	for i, sp in ipairs({ Vector3.new(-1.3, 1.8, 0.2), Vector3.new(1.4, 1.5, -0.5) }) do
		addBox(m, cframe, s, "DryTwig_" .. i, Vector3.new(0.32, 0.9, 0.32), CFrame.new(sp) * CFrame.Angles(0, 0, math.rad(i * 18)), P.WOOD_MID, nil, true, 0, false)
	end
	return m
end

local function buildSmallSucculentBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "SmallSucculentBush", cframe, parent)
	addBox(m, cframe, s, "Hub", Vector3.new(1.4, 0.85, 1.4), CFrame.new(0, 0.42, 0), P.CACTUS_DEEP, nil, true, 0, false)
	for i = 0, 5 do
		local rot = CFrame.Angles(0, math.rad(i * 60), 0)
		addBox(m, cframe, s, "Leaf_" .. i, Vector3.new(0.68, 1.3, 0.45), rot * CFrame.new(0, 0.85, 1.1) * CFrame.Angles(math.rad(36), 0, 0), if i % 2 == 0 then P.SUCCULENT_TEAL else P.CACTUS_LIME, nil, true, 0, false)
	end
	addBox(m, cframe, s, "CenterBud", Vector3.new(0.65, 0.75, 0.65), CFrame.new(0, 1.15, 0), P.BLOSSOM_PINK, nil, true, 0, false)
	return m
end

-- ============================================================================
-- 4. PLANTS (5)
-- ============================================================================

local function buildGoldenDryGrass(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "GoldenDryGrass", cframe, parent)
	addBox(m, cframe, s, "SandTuft", Vector3.new(2.6, 0.2, 2.4), CFrame.new(0, 0.1, 0), P.SAND_TAN, nil, true, 0, false)
	for i, b in ipairs({
		{ x = -0.75, z = -0.4, h = 1.9, r = 12, col = P.DRY_GOLD },
		{ x = -0.1, z = 0.2, h = 2.5, r = -6, col = P.BLOSSOM_YELLOW },
		{ x = 0.7, z = -0.25, h = 2.0, r = -14, col = P.DRY_OCHRE },
		{ x = 0.2, z = 0.75, h = 1.6, r = 15, col = P.DRY_GOLD },
		{ x = -0.5, z = 0.6, h = 2.1, r = 9, col = P.DRY_OCHRE },
	}) do
		addBox(m, cframe, s, "Blade_" .. i, Vector3.new(0.38, b.h, 0.38), CFrame.new(b.x, b.h * 0.5 + 0.1, b.z) * CFrame.Angles(math.rad(b.r), 0, math.rad(b.r)), b.col, nil, true, 0, false)
	end
	return m
end

local function buildDesertFern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "DesertFern", cframe, parent)
	addBox(m, cframe, s, "BasePebble", Vector3.new(1.5, 0.5, 1.4), CFrame.new(0, 0.25, 0), P.STONE_WARM, nil, true, 0, false)
	for i = 0, 5 do
		local rot = CFrame.Angles(0, math.rad(i * 60 + 10), 0)
		addBox(m, cframe, s, "Frond_" .. i, Vector3.new(0.6, 0.22, 1.75), rot * CFrame.new(0, 0.75, 1.05) * CFrame.Angles(math.rad(18), 0, 0), if i % 2 == 0 then P.SUCCULENT_TEAL else P.PALM_MID, nil, true, 0, false)
	end
	return m
end

local function buildFloweringDesertPlant(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "FloweringDesertPlant", cframe, parent)
	addBox(m, cframe, s, "LeafPad", Vector3.new(2.2, 0.45, 2.0), CFrame.new(0, 0.22, 0), P.CACTUS_DEEP, nil, true, 0, false)
	for i, fl in ipairs({
		{ x = -0.5, z = -0.2, h = 1.9, col = P.BLOSSOM_CORAL },
		{ x = 0.4, z = 0.25, h = 2.4, col = P.BLOSSOM_YELLOW },
		{ x = 0.75, z = -0.45, h = 1.6, col = P.BLOSSOM_PINK },
	}) do
		addBox(m, cframe, s, "Stem_" .. i, Vector3.new(0.24, fl.h, 0.24), CFrame.new(fl.x, fl.h * 0.5 + 0.2, fl.z), P.CACTUS_MID, nil, true, 0, false)
		addBox(m, cframe, s, "Petal_" .. i, Vector3.new(0.82, 0.28, 0.82), CFrame.new(fl.x, fl.h + 0.3, fl.z), fl.col, nil, true, 0, false)
		addBox(m, cframe, s, "Core_" .. i, Vector3.new(0.38, 0.3, 0.38), CFrame.new(fl.x, fl.h + 0.45, fl.z), P.BLOSSOM_YELLOW, nil, true, 0, false)
	end
	return m
end

local function buildSmallPurpleDesertFlowers(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "SmallPurpleDesertFlowers", cframe, parent)
	addBox(m, cframe, s, "SageBase", Vector3.new(2.4, 0.45, 2.2), CFrame.new(0, 0.22, 0), P.SUCCULENT_TEAL, nil, true, 0, false)
	for i, sp in ipairs({
		{ x = -0.5, z = -0.2, h = 2.3 },
		{ x = 0.25, z = 0.3, h = 2.8 },
		{ x = 0.65, z = -0.35, h = 1.9 },
	}) do
		addBox(m, cframe, s, "SpikeStem_" .. i, Vector3.new(0.22, sp.h, 0.22), CFrame.new(sp.x, sp.h * 0.5 + 0.2, sp.z), P.CACTUS_MID, nil, true, 0, false)
		addBox(m, cframe, s, "Bloom_" .. i, Vector3.new(0.65, 0.72, 0.65), CFrame.new(sp.x, sp.h + 0.15, sp.z), P.BLOSSOM_PURPLE, nil, true, 0, false)
		addBox(m, cframe, s, "Tip_" .. i, Vector3.new(0.38, 0.42, 0.38), CFrame.new(sp.x, sp.h + 0.6, sp.z), P.BLOSSOM_YELLOW, nil, true, 0, false)
	end
	return m
end

local function buildDesertReeds(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "DesertReeds", cframe, parent)
	addBox(m, cframe, s, "MudSandPad", Vector3.new(2.4, 0.24, 2.4), CFrame.new(0, 0.12, 0), P.SAND_TAN, nil, true, 0, false)
	for i, r in ipairs({
		{ x = -0.5, z = -0.3, h = 3.5, r = 6 },
		{ x = 0.2, z = 0.3, h = 4.2, r = -5 },
		{ x = 0.7, z = -0.3, h = 3.1, r = 9 },
		{ x = -0.2, z = 0.65, h = 2.8, r = -8 },
	}) do
		local cf = CFrame.new(r.x, r.h * 0.5 + 0.1, r.z) * CFrame.Angles(math.rad(r.r), 0, 0)
		addBox(m, cframe, s, "ReedStalk_" .. i, Vector3.new(0.24, r.h, 0.24), cf, P.PALM_DARK, nil, true, 0, false)
		addBox(m, cframe, s, "ReedHead_" .. i, Vector3.new(0.42, 0.85, 0.42), cf * CFrame.new(0, r.h * 0.32, 0), P.DRY_GOLD, nil, true, 0, false)
	end
	return m
end

-- ============================================================================
-- 5. ROCKS (4)
-- ============================================================================

local function buildSandstoneBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "SandstoneBoulder", cframe, parent)
	addBox(m, cframe, s, "BoulderBase", Vector3.new(5.2, 2.2, 4.4), CFrame.new(0, 1.1, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "BoulderMid", Vector3.new(3.8, 1.8, 3.4), CFrame.new(-0.3, 2.6, 0.1), P.STONE_ORANGE)
	addBox(m, cframe, s, "BoulderTop", Vector3.new(2.4, 1.2, 2.2), CFrame.new(-0.4, 3.8, 0.1), P.STONE_WARM)
	addBox(m, cframe, s, "BoulderShoulder", Vector3.new(2.2, 1.4, 2.4), CFrame.new(1.7, 1.2, -0.5), P.SAND_TAN)
	return m
end

local function buildLayeredSandstoneRock(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "LayeredSandstoneRock", cframe, parent)
	-- Wide horizontal strata bands (reference Rocks #1)
	addBox(m, cframe, s, "Strata1", Vector3.new(7.4, 1.4, 4.8), CFrame.new(0, 0.7, 0), P.TERRACOTTA_DARK)
	addBox(m, cframe, s, "Strata2", Vector3.new(6.8, 1.4, 4.4), CFrame.new(-0.2, 2.0, 0.1), P.STONE_ORANGE)
	addBox(m, cframe, s, "Strata3", Vector3.new(5.6, 1.2, 3.8), CFrame.new(-0.4, 3.2, 0), P.STONE_WARM)
	addBox(m, cframe, s, "StrataCap", Vector3.new(4.2, 0.9, 3.0), CFrame.new(-0.6, 4.1, -0.1), P.SAND_GOLD)
	addBox(m, cframe, s, "SideCactus", Vector3.new(0.65, 1.8, 0.65), CFrame.new(3.2, 1.5, 1.8), P.CACTUS_MID, nil, true, 0, false)
	return m
end

local function buildTallRockPillar(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "TallRockPillar", cframe, parent)
	addBox(m, cframe, s, "Foot", Vector3.new(4.6, 1.6, 4.2), CFrame.new(0, 0.8, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "ShaftLow", Vector3.new(3.2, 3.4, 3.0), CFrame.new(0, 3.1, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "ShaftWaist", Vector3.new(2.6, 2.8, 2.4), CFrame.new(0.1, 5.8, 0), P.TERRACOTTA_DARK)
	addBox(m, cframe, s, "HoodooCap", Vector3.new(3.8, 1.6, 3.4), CFrame.new(0, 7.6, 0), P.STONE_WARM)
	addBox(m, cframe, s, "CapCrown", Vector3.new(2.8, 0.9, 2.6), CFrame.new(-0.2, 8.7, 0), P.SAND_GOLD)
	return m
end

local function buildSmallRockClusters(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "SmallRockClusters", cframe, parent)
	addBox(m, cframe, s, "RockA", Vector3.new(2.4, 1.4, 2.0), CFrame.new(-0.8, 0.7, 0.2) * CFrame.Angles(0, 0.25, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "RockB", Vector3.new(1.8, 1.0, 1.6), CFrame.new(1.1, 0.5, -0.4) * CFrame.Angles(0, -0.35, 0), P.STONE_WARM)
	addBox(m, cframe, s, "RockC", Vector3.new(1.2, 0.65, 1.1), CFrame.new(0.6, 0.32, 1.0) * CFrame.Angles(0, 0.5, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "DryTuft", Vector3.new(0.35, 0.8, 0.35), CFrame.new(-1.8, 0.4, -0.6), P.DRY_GOLD, nil, true, 0, false)
	return m
end

-- ============================================================================
-- 6. TERRAIN PROPS (4)
-- ============================================================================

local function buildSandDunes(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "SandDunes", cframe, parent)
	addBox(m, cframe, s, "DuneTier1", Vector3.new(10.4, 1.2, 7.2), CFrame.new(0, 0.6, 0), P.SAND_TAN)
	addBox(m, cframe, s, "DuneTier2", Vector3.new(7.6, 1.2, 5.2), CFrame.new(-0.6, 1.6, -0.3), P.SAND_GOLD)
	addBox(m, cframe, s, "DuneTier3", Vector3.new(4.6, 1.0, 3.2), CFrame.new(-1.0, 2.5, -0.5), P.SAND_BRIGHT)
	addBox(m, cframe, s, "DunePebble", Vector3.new(1.3, 0.7, 1.1), CFrame.new(3.2, 1.2, 1.5), P.STONE_ORANGE)
	return m
end

local function buildCrackedDryGround(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "CrackedDryGround", cframe, parent)
	addBox(m, cframe, s, "CrackedBed", Vector3.new(5.6, 0.16, 4.8), CFrame.new(0, 0.08, 0), P.TERRACOTTA_DARK, nil, true, 0, false)
	for i, pl in ipairs({
		{ pos = Vector3.new(-1.4, 0.2, -1.0), sz = Vector3.new(2.3, 0.16, 2.0), col = P.SAND_TAN },
		{ pos = Vector3.new(1.3, 0.22, -0.9), sz = Vector3.new(2.2, 0.18, 2.0), col = P.STONE_WARM },
		{ pos = Vector3.new(-1.1, 0.2, 1.3), sz = Vector3.new(2.4, 0.16, 1.9), col = P.STONE_WARM },
		{ pos = Vector3.new(1.4, 0.2, 1.2), sz = Vector3.new(2.0, 0.16, 1.8), col = P.SAND_TAN },
	}) do
		addBox(m, cframe, s, "Plate_" .. i, pl.sz, CFrame.new(pl.pos), pl.col, nil, true, 0, false)
	end
	return m
end

local function buildSandstoneCliffs(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "SandstoneCliffs", cframe, parent)
	addBox(m, cframe, s, "CliffBase", Vector3.new(8.2, 2.6, 5.2), CFrame.new(0, 1.3, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "CliffMid", Vector3.new(6.2, 2.8, 4.2), CFrame.new(-0.5, 3.8, -0.2), P.STONE_ORANGE)
	addBox(m, cframe, s, "CliffCrown", Vector3.new(4.2, 2.2, 3.2), CFrame.new(-0.9, 5.9, -0.3), P.STONE_WARM)
	addSandDrift(m, cframe, s, "CliffSand", Vector3.new(1.8, 0.26, 2.0), 4.4, 2.6)
	addBox(m, cframe, s, "CliffCactus", Vector3.new(0.75, 2.2, 0.75), CFrame.new(2.2, 3.5, 1.2), P.CACTUS_MID)
	return m
end

local function buildBrokenRockFormations(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "BrokenRockFormations", cframe, parent)
	addBox(m, cframe, s, "CragL", Vector3.new(2.8, 4.4, 2.6), CFrame.new(-2.0, 2.0, 0.2) * CFrame.Angles(0, 0, math.rad(14)), P.TERRACOTTA)
	addBox(m, cframe, s, "CragR", Vector3.new(2.4, 3.6, 2.4), CFrame.new(1.6, 1.6, -0.2) * CFrame.Angles(0, 0, math.rad(-16)), P.STONE_ORANGE)
	addBox(m, cframe, s, "ShardMid", Vector3.new(1.5, 1.6, 1.4), CFrame.new(-0.1, 0.8, 0.8) * CFrame.Angles(0, 0.4, 0), P.STONE_WARM)
	return m
end

-- ============================================================================
-- 7. RUINS (4)
-- ============================================================================

local function buildAncientSandstoneArch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "AncientSandstoneArch", cframe, parent)
	for _, xSide in ipairs({ -4.0, 4.0 }) do
		addBox(m, cframe, s, "ArchBase", Vector3.new(2.8, 1.4, 2.6), CFrame.new(xSide, 0.7, 0), P.STONE_ORANGE)
		addBox(m, cframe, s, "ArchPier", Vector3.new(2.1, 6.0, 2.1), CFrame.new(xSide, 4.2, 0), P.STONE_WARM)
	end
	addBox(m, cframe, s, "ArchLintel", Vector3.new(11.0, 1.8, 2.4), CFrame.new(0, 8.0, 0), P.STONE_WARM)
	addBox(m, cframe, s, "ArchStep", Vector3.new(7.4, 1.1, 2.0), CFrame.new(-0.6, 9.4, 0), P.SAND_GOLD)
	addSandDrift(m, cframe, s, "DriftL", Vector3.new(-3.8, 0.24, 1.1), 3.6, 2.4)
	addDesertVine(m, cframe, s, "VineA", Vector3.new(-1.8, 7.2, 1.15), 2.8)
	addDesertVine(m, cframe, s, "VineB", Vector3.new(2.4, 7.2, -1.05), 3.2)
	return m
end

local function buildBrokenAncientPillars(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "BrokenAncientPillars", cframe, parent)
	addBox(m, cframe, s, "ColFootL", Vector3.new(2.8, 1.1, 2.8), CFrame.new(-2.1, 0.55, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "ColShaftL", Vector3.new(2.0, 6.2, 2.0), CFrame.new(-2.1, 4.1, 0), P.STONE_WARM)
	addBox(m, cframe, s, "ColBandL", Vector3.new(2.2, 0.75, 2.2), CFrame.new(-2.1, 6.2, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "ColFootR", Vector3.new(2.5, 0.9, 2.5), CFrame.new(2.2, 0.45, 0.4), P.TERRACOTTA)
	addBox(m, cframe, s, "ColShaftR", Vector3.new(1.8, 3.0, 1.8), CFrame.new(2.2, 2.4, 0.4), P.SAND_GOLD)
	addBox(m, cframe, s, "FallenDrum", Vector3.new(1.9, 1.2, 1.6), CFrame.new(0.1, 0.6, -0.9) * CFrame.Angles(0, 0.4, 0), P.STONE_WARM)
	addSandDrift(m, cframe, s, "PillarSand", Vector3.new(-1.6, 0.22, 1.4), 3.4, 2.2)
	return m
end

local function buildSmallRuinedTemple(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "SmallRuinedTemple", cframe, parent)
	addBox(m, cframe, s, "TemplePlinth", Vector3.new(9.6, 1.1, 8.4), CFrame.new(0, 0.55, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "InnerDeck", Vector3.new(7.4, 0.7, 6.4), CFrame.new(0, 1.45, 0), P.SAND_GOLD)
	for i, c in ipairs({
		{ pos = Vector3.new(-3.2, 4.2, -2.5), h = 5.4 },
		{ pos = Vector3.new(3.2, 4.2, -2.5), h = 5.4 },
		{ pos = Vector3.new(-3.2, 3.0, 2.5), h = 3.2 },
		{ pos = Vector3.new(3.2, 3.6, 2.5), h = 4.4 },
	}) do
		addBox(m, cframe, s, "Col_" .. i, Vector3.new(1.5, c.h, 1.5), CFrame.new(c.pos.X, 1.6 + c.h * 0.5, c.pos.Z), P.STONE_WARM)
	end
	addBox(m, cframe, s, "BackBeam", Vector3.new(8.2, 1.3, 1.9), CFrame.new(0, 7.4, -2.5), P.TERRACOTTA)
	addBox(m, cframe, s, "AltarBlock", Vector3.new(2.2, 1.2, 1.6), CFrame.new(0, 2.35, -0.4), P.STONE_ORANGE)
	addSandDrift(m, cframe, s, "TempleSand", Vector3.new(2.0, 0.25, 3.6), 4.8, 2.6)
	return m
end

local function buildRuinedWalls(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "RuinedWalls", cframe, parent)
	addBox(m, cframe, s, "WallFoot", Vector3.new(9.2, 1.2, 2.4), CFrame.new(0, 0.6, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "WallMain", Vector3.new(7.8, 3.2, 1.8), CFrame.new(-0.4, 2.8, 0), P.STONE_WARM)
	addBox(m, cframe, s, "FriezeBand", Vector3.new(8.0, 0.65, 1.96), CFrame.new(-0.4, 3.4, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "TallStep", Vector3.new(3.2, 1.8, 1.9), CFrame.new(-2.4, 5.2, 0), P.SAND_GOLD)
	addBox(m, cframe, s, "RubbleChunk", Vector3.new(1.6, 0.9, 1.4), CFrame.new(3.6, 0.45, 1.1) * CFrame.Angles(0, 0.35, 0), P.STONE_WARM)
	addDesertVine(m, cframe, s, "WallVine", Vector3.new(-2.0, 5.6, 0.95), 2.8)
	return m
end

-- ============================================================================
-- 8. STRUCTURES (4)
-- ============================================================================

local function buildDesertTempleEntrance(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "DesertTempleEntrance", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "StairBot", Vector3.new(12.8, 0.85, 5.2), CFrame.new(0, 0.42, 0.6), P.STONE_ORANGE)
	addBox(m, cframe, s, "StairTop", Vector3.new(10.8, 0.8, 3.8), CFrame.new(0, 1.1, 0), P.SAND_GOLD)
	for _, xSide in ipairs({ -4.8, 4.8 }) do
		addBox(m, cframe, s, "GatePlinth", Vector3.new(3.6, 1.6, 3.4), CFrame.new(xSide, 1.8, 0), P.TERRACOTTA)
		addBox(m, cframe, s, "GatePier", Vector3.new(2.8, 7.6, 2.8), CFrame.new(xSide, 6.2, 0), P.STONE_WARM)
		addBox(m, cframe, s, "PierTrim", Vector3.new(3.0, 0.85, 3.0), CFrame.new(xSide, 7.2, 0), P.STONE_ORANGE)
	end
	addBox(m, cframe, s, "TempleLintel", Vector3.new(14.0, 2.2, 3.0), CFrame.new(0, 10.6, 0), P.STONE_WARM)
	addBox(m, cframe, s, "TempleCrown", Vector3.new(10.6, 1.4, 2.5), CFrame.new(-0.2, 12.2, 0), P.SAND_GOLD)
	addBox(m, cframe, s, "TempleCrest", Vector3.new(5.2, 1.2, 2.2), CFrame.new(0, 13.4, 0), P.TERRACOTTA)

	-- Center crimson paw-print banner + twin warm amber lanterns
	addPawBanner(m, cframe, s, "GateBanner", Vector3.new(0, 7.8, 1.55), 1.0, 0)
	for idx, lx in ipairs({ -3.0, 3.0 }) do
		addBox(m, cframe, s, "Hook_" .. idx, Vector3.new(1.2, 0.32, 0.32), CFrame.new(lx * 1.1, 8.6, 1.2), P.WOOD_DARK)
		addAmberLantern(m, cframe, s, "GateLantern_" .. idx, Vector3.new(lx, 7.45, 1.2), 18, 0.9)
	end
	addDesertVine(m, cframe, s, "TempleVineL", Vector3.new(-3.2, 9.6, 1.4), 3.4)
	addDesertVine(m, cframe, s, "TempleVineR", Vector3.new(3.4, 9.6, -1.3), 3.0)
	return m
end

local function buildSandstoneMonument(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "SandstoneMonument", cframe, parent)
	addBox(m, cframe, s, "Step1", Vector3.new(7.4, 1.3, 7.4), CFrame.new(0, 0.65, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "Step2", Vector3.new(5.4, 1.5, 5.4), CFrame.new(0, 2.0, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "ObeliskShaft", Vector3.new(3.2, 4.4, 3.2), CFrame.new(0, 4.9, 0), P.STONE_WARM)
	addBox(m, cframe, s, "SunBand", Vector3.new(3.4, 0.7, 3.4), CFrame.new(0, 5.6, 0), P.GOLD_TRIM)
	addBox(m, cframe, s, "SunSpire", Vector3.new(1.5, 2.6, 1.5), CFrame.new(0, 8.2, 0), P.GOLD_TRIM, Enum.Material.Neon, false, 0.1, false)
	addBox(m, cframe, s, "SpireSideL", Vector3.new(0.85, 1.6, 0.85), CFrame.new(-1.1, 7.6, 0.2) * CFrame.Angles(0, 0, math.rad(18)), P.BLOSSOM_YELLOW, Enum.Material.Neon, false, 0.15, false)
	return m
end

local function buildAncientStoneGate(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "AncientStoneGate", cframe, parent)
	for _, xSide in ipairs({ -4.6, 4.6 }) do
		addBox(m, cframe, s, "TowerBase", Vector3.new(3.4, 1.6, 3.4), CFrame.new(xSide, 0.8, 0), P.TERRACOTTA)
		addBox(m, cframe, s, "TowerBody", Vector3.new(2.8, 7.8, 2.8), CFrame.new(xSide, 5.4, 0), P.STONE_ORANGE)
		addBox(m, cframe, s, "TowerCap", Vector3.new(3.4, 1.3, 3.4), CFrame.new(xSide, 9.8, 0), P.SAND_GOLD)
	end
	addBox(m, cframe, s, "GateCross", Vector3.new(10.6, 2.0, 2.6), CFrame.new(0, 8.2, 0), P.STONE_WARM)
	addBox(m, cframe, s, "GateTrim", Vector3.new(8.4, 0.65, 2.8), CFrame.new(0, 8.4, 0), P.TERRACOTTA_DARK)
	addSandDrift(m, cframe, s, "GateSand", Vector3.new(-3.8, 0.22, 1.8), 4.0, 2.4)
	return m
end

local function buildAbandonedWatchtower(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "AbandonedWatchtower", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "SandBase", Vector3.new(7.0, 1.6, 7.0), CFrame.new(0, 0.8, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "SandStep", Vector3.new(5.8, 1.8, 5.8), CFrame.new(0, 2.4, 0), P.STONE_WARM)
	for _, px in ipairs({ -2.1, 2.1 }) do
		for _, pz in ipairs({ -2.1, 2.1 }) do
			addBox(m, cframe, s, "Post", Vector3.new(0.85, 9.0, 0.85), CFrame.new(px, 7.0, pz), P.WOOD_DARK)
		end
	end
	addBox(m, cframe, s, "Deck", Vector3.new(7.0, 0.7, 7.0), CFrame.new(0, 8.4, 0), P.WOOD_MID)
	addBox(m, cframe, s, "RoofA", Vector3.new(7.8, 0.85, 7.8), CFrame.new(0, 11.8, 0), P.TERRACOTTA)
	addBox(m, cframe, s, "RoofB", Vector3.new(4.8, 0.85, 4.8), CFrame.new(0, 12.6, 0), P.STONE_WARM)

	-- Crimson paw banner + overhanging desert lantern + cargo crate
	addPawBanner(m, cframe, s, "WatchBanner", Vector3.new(0, 6.4, 3.2), 0.9, 0)
	addBox(m, cframe, s, "LanternArm", Vector3.new(2.2, 0.5, 0.5), CFrame.new(-3.3, 8.2, 0), P.WOOD_DARK)
	addAmberLantern(m, cframe, s, "WatchLantern", Vector3.new(-4.0, 7.0, 0), 18, 0.95)
	addBox(m, cframe, s, "CargoCrate", Vector3.new(1.5, 1.5, 1.5), CFrame.new(4.2, 0.75, 1.8), P.WOOD_MID)
	return m
end

-- ============================================================================
-- 9. DECORATIONS (9)
-- ============================================================================

local function buildWoodenDesertLantern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenDesertLantern", cframe, parent)
	addBox(m, cframe, s, "SandFoot", Vector3.new(2.1, 1.1, 2.1), CFrame.new(-0.35, 0.55, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "PostShaft", Vector3.new(0.85, 6.2, 0.85), CFrame.new(-0.35, 4.0, 0), P.WOOD_DARK)
	addBox(m, cframe, s, "CrossArm", Vector3.new(2.6, 0.6, 0.7), CFrame.new(0.65, 6.8, 0), P.WOOD_MID)
	addBox(m, cframe, s, "Chain", Vector3.new(0.22, 0.7, 0.22), CFrame.new(1.55, 6.2, 0), P.LANTERN_IRON)
	addAmberLantern(m, cframe, s, "HangLamp", Vector3.new(1.55, 5.2, 0), 16, 0.88)
	return m
end

local function buildWoodenBarrels(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenBarrels", cframe, parent)
	addBox(m, cframe, s, "SandPad", Vector3.new(3.8, 0.2, 3.2), CFrame.new(0, 0.1, 0), P.SAND_GOLD, nil, true, 0, false)
	for i, br in ipairs({
		{ pos = Vector3.new(-0.85, 1.2, 0.15), h = 2.2, w = 1.6 },
		{ pos = Vector3.new(0.9, 1.0, -0.45), h = 1.8, w = 1.45 },
	}) do
		addBox(m, cframe, s, "Barrel_" .. i, Vector3.new(br.w, br.h, br.w), CFrame.new(br.pos), P.WOOD_LIGHT)
		addBox(m, cframe, s, "HoopA_" .. i, Vector3.new(br.w + 0.14, 0.24, br.w + 0.14), CFrame.new(br.pos + Vector3.new(0, br.h * 0.28, 0)), P.LANTERN_IRON)
		addBox(m, cframe, s, "HoopB_" .. i, Vector3.new(br.w + 0.14, 0.24, br.w + 0.14), CFrame.new(br.pos + Vector3.new(0, -br.h * 0.26, 0)), P.LANTERN_IRON)
	end
	return m
end

local function buildWoodenCrates(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenCrates", cframe, parent)
	addBox(m, cframe, s, "CrateA", Vector3.new(2.0, 2.0, 2.0), CFrame.new(-0.9, 1.0, 0.2) * CFrame.Angles(0, 0.14, 0), P.WOOD_MID)
	addBox(m, cframe, s, "CrateB", Vector3.new(1.7, 1.6, 1.7), CFrame.new(1.1, 0.8, -0.3) * CFrame.Angles(0, -0.22, 0), P.WOOD_LIGHT)
	addBox(m, cframe, s, "CrateTop", Vector3.new(1.4, 1.4, 1.4), CFrame.new(-0.7, 2.7, 0.1) * CFrame.Angles(0, -0.18, 0), P.WOOD_DARK)
	addBox(m, cframe, s, "Strap", Vector3.new(2.1, 0.28, 2.1), CFrame.new(-0.9, 1.0, 0.2) * CFrame.Angles(0, 0.14, 0), P.GOLD_TRIM)
	return m
end

local function buildMerchantCart(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "MerchantCart", cframe, parent)
	-- Covered canvas merchant wagon (matching Decorative Objects center reference!)
	addBox(m, cframe, s, "WagonBed", Vector3.new(5.6, 0.48, 3.4), CFrame.new(0, 1.45, 0), P.WOOD_MID)
	addBox(m, cframe, s, "SideRailL", Vector3.new(5.4, 1.2, 0.35), CFrame.new(0, 2.15, 1.55), P.WOOD_DARK)
	addBox(m, cframe, s, "SideRailR", Vector3.new(5.4, 1.2, 0.35), CFrame.new(0, 2.15, -1.55), P.WOOD_DARK)
	-- Canvas arched canopy cover
	addBox(m, cframe, s, "CanopyWall", Vector3.new(4.8, 1.8, 3.1), CFrame.new(-0.2, 3.4, 0), P.CANVAS_CREAM)
	addBox(m, cframe, s, "CanopyArch", Vector3.new(4.9, 1.0, 2.4), CFrame.new(-0.2, 4.6, 0), P.SAND_BRIGHT)
	addBox(m, cframe, s, "CanopyRim", Vector3.new(5.0, 0.45, 3.3), CFrame.new(-0.2, 2.6, 0), P.WOOD_LIGHT)
	addBox(m, cframe, s, "PullShaftL", Vector3.new(2.4, 0.3, 0.3), CFrame.new(3.8, 1.25, 1.0), P.WOOD_DARK)
	addBox(m, cframe, s, "PullShaftR", Vector3.new(2.4, 0.3, 0.3), CFrame.new(3.8, 1.25, -1.0), P.WOOD_DARK)
	for _, xW in ipairs({ -1.6, 1.6 }) do
		for _, zW in ipairs({ -1.85, 1.85 }) do
			addBox(m, cframe, s, "Wheel", Vector3.new(2.0, 2.0, 0.35), CFrame.new(xW, 1.0, zW), P.WOOD_DARK)
			addBox(m, cframe, s, "WheelHub", Vector3.new(0.7, 0.7, 0.46), CFrame.new(xW, 1.0, zW), P.GOLD_TRIM)
		end
	end
	return m
end

local function buildDesertSignpost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "DesertSignpost", cframe, parent)
	addBox(m, cframe, s, "SandFoot", Vector3.new(2.0, 0.4, 2.0), CFrame.new(0, 0.2, 0), P.SAND_GOLD, nil, true, 0, false)
	addBox(m, cframe, s, "Post", Vector3.new(0.75, 5.2, 0.75), CFrame.new(0, 2.8, 0), P.WOOD_DARK)
	addBox(m, cframe, s, "SignA", Vector3.new(3.2, 1.0, 0.34), CFrame.new(0.25, 4.6, 0.4) * CFrame.Angles(0, 0.12, 0), P.WOOD_LIGHT)
	addBox(m, cframe, s, "SignB", Vector3.new(2.8, 0.9, 0.34), CFrame.new(-0.2, 3.45, 0.4) * CFrame.Angles(0, -0.15, 0), P.WOOD_MID)
	return m
end

local function buildAnimalBonesAndSkull(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "AnimalBonesAndSkull", cframe, parent)
	addSandDrift(m, cframe, s, "BoneSand", Vector3.new(0, 0.22, 0), 6.2, 5.0)
	-- Horned skull + curved voxel ribcage arch (reference Decorative Objects + Miscellaneous)
	addBox(m, cframe, s, "SkullHead", Vector3.new(1.8, 1.25, 1.5), CFrame.new(-1.6, 0.9, 1.1) * CFrame.Angles(0, 0.4, 0), P.BONE_IVORY, nil, true, 0, false)
	addBox(m, cframe, s, "HornL", Vector3.new(0.45, 1.3, 0.45), CFrame.new(-2.4, 1.4, 0.5) * CFrame.Angles(0, 0, math.rad(36)), P.CANVAS_CREAM, nil, true, 0, false)
	addBox(m, cframe, s, "HornR", Vector3.new(0.45, 1.3, 0.45), CFrame.new(-1.2, 1.4, 2.0) * CFrame.Angles(math.rad(-34), 0, 0), P.CANVAS_CREAM, nil, true, 0, false)
	for idx, rx in ipairs({ -0.4, 1.0, 2.2 }) do
		addBox(m, cframe, s, "RibPostL_" .. idx, Vector3.new(0.5, 2.6, 0.5), CFrame.new(rx, 1.4, -1.2) * CFrame.Angles(math.rad(-14), 0, 0), P.BONE_IVORY, nil, true, 0, false)
		addBox(m, cframe, s, "RibPostR_" .. idx, Vector3.new(0.5, 2.4, 0.5), CFrame.new(rx, 1.3, 0.8) * CFrame.Angles(math.rad(16), 0, 0), P.BONE_IVORY, nil, true, 0, false)
		addBox(m, cframe, s, "RibArch_" .. idx, Vector3.new(0.52, 0.52, 2.0), CFrame.new(rx, 2.75, -0.2), P.BONE_IVORY, nil, true, 0, false)
	end
	return m
end

local function buildAncientTreasureChest(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "AncientTreasureChest", cframe, parent)
	addSandDrift(m, cframe, s, "ChestSand", Vector3.new(0, 0.2, 0), 4.0, 3.2)
	addBox(m, cframe, s, "ChestBase", Vector3.new(2.8, 1.35, 2.0), CFrame.new(0, 0.95, 0), P.WOOD_DARK)
	addBox(m, cframe, s, "ChestLid", Vector3.new(2.9, 0.75, 2.1), CFrame.new(0, 2.0, 0), P.WOOD_MID)
	addBox(m, cframe, s, "GoldBandL", Vector3.new(0.32, 2.15, 2.2), CFrame.new(-0.9, 1.35, 0), P.GOLD_TRIM)
	addBox(m, cframe, s, "GoldBandR", Vector3.new(0.32, 2.15, 2.2), CFrame.new(0.9, 1.35, 0), P.GOLD_TRIM)
	addBox(m, cframe, s, "GoldLock", Vector3.new(0.55, 0.75, 0.3), CFrame.new(0, 1.55, 1.08), P.BLOSSOM_YELLOW, Enum.Material.Neon, false, 0, false)
	return m
end

local function buildSmallWoodenFences(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SmallWoodenFences", cframe, parent)
	for _, zOff in ipairs({ -3.2, 0, 3.2 }) do
		addBox(m, cframe, s, "FencePost", Vector3.new(0.65, 2.5, 0.65), CFrame.new(0, 1.25, zOff), P.WOOD_DARK)
	end
	addBox(m, cframe, s, "TopRail", Vector3.new(0.36, 0.36, 7.2), CFrame.new(0, 2.0, 0), P.WOOD_LIGHT)
	addBox(m, cframe, s, "BotRail", Vector3.new(0.36, 0.36, 7.2), CFrame.new(0, 1.1, 0), P.WOOD_MID)
	addBox(m, cframe, s, "FenceSand", Vector3.new(1.5, 0.3, 2.4), CFrame.new(0.4, 0.15, 1.2), P.SAND_GOLD, nil, true, 0, false)
	return m
end

local function buildDesertBanners(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "DesertBanners", cframe, parent)
	addBox(m, cframe, s, "StoneFoot", Vector3.new(2.2, 1.1, 2.2), CFrame.new(0, 0.55, 0), P.STONE_ORANGE)
	addBox(m, cframe, s, "BannerPole", Vector3.new(0.7, 7.8, 0.7), CFrame.new(0, 4.6, 0), P.WOOD_DARK)
	addBox(m, cframe, s, "PoleFinial", Vector3.new(1.0, 0.9, 1.0), CFrame.new(0, 8.8, 0), P.GOLD_TRIM)
	addPawBanner(m, cframe, s, "DesertFlag", Vector3.new(0, 6.2, 0.52), 1.05, 0)
	return m
end

-- ============================================================================
-- 10. WATER FEATURES (6)
-- ============================================================================

local function buildSmallDesertOasis(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SmallDesertOasis", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "OasisSand", Vector3.new(12.2, 0.3, 10.2), CFrame.new(0, 0.15, 0), P.SAND_GOLD, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(9.2, 0.18, 7.2), CFrame.new(0, 0.14, 0), P.WATER_DEEP, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "TurquoisePool", Vector3.new(9.0, 0.34, 7.0), CFrame.new(0, 0.38, 0), P.WATER_TURQ, Enum.Material.Glass, false, 0.22, false)
	addSandDrift(m, cframe, s, "BackDune", Vector3.new(-4.8, 0.35, -3.2), 4.6, 3.6)
	addBox(m, cframe, s, "OasisRock", Vector3.new(2.4, 1.4, 2.2), CFrame.new(4.6, 0.7, -2.6), P.STONE_ORANGE)
	addBox(m, cframe, s, "ShoreReedsA", Vector3.new(0.28, 2.0, 0.28), CFrame.new(-4.6, 1.1, 2.2), P.PALM_MID, nil, true, 0, false)
	addBox(m, cframe, s, "ShoreReedsB", Vector3.new(0.28, 1.7, 0.28), CFrame.new(4.5, 0.95, 2.4), P.PALM_LIME, nil, true, 0, false)
	addRippleRings(m, cframe, s, Vector3.new(0, 0.56, 0), Vector2.new(2.4, 2.0), 2, 0.52)
	return m
end

local function buildTurquoiseWaterPond(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "TurquoiseWaterPond", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "ShoreSand", Vector3.new(13.4, 0.3, 11.2), CFrame.new(0, 0.15, 0), P.SAND_BRIGHT, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(10.6, 0.18, 8.6), CFrame.new(0, 0.14, 0), P.WATER_DEEP, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "PondSurface", Vector3.new(10.4, 0.34, 8.4), CFrame.new(0, 0.38, 0), P.WATER_TURQ, Enum.Material.Glass, false, 0.20, false)
	for i, st in ipairs({
		{ pos = Vector3.new(-5.4, 0.7, -1.8), sz = Vector3.new(2.4, 1.2, 3.0) },
		{ pos = Vector3.new(5.2, 0.65, 2.0), sz = Vector3.new(2.2, 1.1, 2.8) },
		{ pos = Vector3.new(-2.0, 0.5, 4.5), sz = Vector3.new(3.4, 0.85, 1.6) },
	}) do
		addBox(m, cframe, s, "PoolStone_" .. i, st.sz, CFrame.new(st.pos), if i % 2 == 0 then P.TERRACOTTA else P.STONE_WARM)
	end
	addBox(m, cframe, s, "StepSlab", Vector3.new(2.0, 0.62, 1.8), CFrame.new(2.2, 0.32, -1.4) * CFrame.Angles(0, 0.25, 0), P.STONE_WARM)
	addRippleRings(m, cframe, s, Vector3.new(-0.8, 0.56, 0.6), Vector2.new(2.5, 2.1), 2, 0.54)
	return m
end

local function buildOasisWithLilyPads(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "OasisWithLilyPads", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "OasisTurf", Vector3.new(11.8, 0.3, 10.0), CFrame.new(0, 0.15, 0), P.PALM_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(9.2, 0.18, 7.6), CFrame.new(0, 0.14, 0), P.WATER_DEEP, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "OasisWater", Vector3.new(9.0, 0.34, 7.4), CFrame.new(0, 0.38, 0), P.WATER_TURQ, Enum.Material.Glass, false, 0.22, false)
	addLilyPad(m, cframe, s, "Lily1", Vector3.new(-1.8, 0.58, -1.0), 1.85, 18, P.BLOSSOM_PINK)
	addLilyPad(m, cframe, s, "Lily2", Vector3.new(1.8, 0.58, 1.2), 1.55, -24, nil)
	addLilyPad(m, cframe, s, "Lily3", Vector3.new(0.4, 0.58, -1.9), 1.4, 34, P.BLOSSOM_PINK)
	addBox(m, cframe, s, "BorderRock", Vector3.new(2.2, 1.0, 2.0), CFrame.new(-4.8, 0.55, 2.2), P.STONE_ORANGE)
	addRippleRings(m, cframe, s, Vector3.new(0.4, 0.56, 0.5), Vector2.new(2.2, 1.8), 2, 0.50)
	return m
end

local function buildSmallOasisWaterfall(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SmallOasisWaterfall", cframe, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "SandApron", Vector3.new(12.2, 0.32, 12.6), CFrame.new(0, 0.16, 0.4), P.SAND_GOLD, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(8.8, 0.18, 6.8), CFrame.new(0, 0.16, 2.0), P.WATER_DEEP, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "OasisPool", Vector3.new(8.6, 0.34, 6.6), CFrame.new(0, 0.4, 2.0), P.WATER_TURQ, Enum.Material.Glass, false, 0.20, false)

	addBox(m, cframe, s, "CliffL", Vector3.new(3.4, 5.4, 3.6), CFrame.new(-2.8, 2.7, -3.2), P.STONE_ORANGE)
	addBox(m, cframe, s, "CliffR", Vector3.new(3.2, 4.8, 3.4), CFrame.new(2.7, 2.4, -3.2), P.TERRACOTTA)
	addBox(m, cframe, s, "CliffBack", Vector3.new(4.2, 4.9, 2.6), CFrame.new(0, 2.45, -3.8), P.STONE_WARM)
	addBox(m, cframe, s, "CliffCap", Vector3.new(2.8, 1.2, 2.6), CFrame.new(-2.8, 5.9, -3.2), P.SAND_GOLD)

	addLilyPad(m, cframe, s, "FallLily", Vector3.new(1.8, 0.6, 2.8), 1.5, -22, P.BLOSSOM_PINK)

	addBox(m, cframe, s, "CrestPool", Vector3.new(2.8, 0.34, 2.0), CFrame.new(0, 5.05, -2.7), P.WATER_FALL, Enum.Material.Glass, false, 0.25, false)
	addBox(m, cframe, s, "CascadeCore", Vector3.new(2.6, 4.4, 0.52), CFrame.new(0, 2.8, -1.75), P.WATER_FALL, Enum.Material.Glass, false, 0.32, false)
	addBox(m, cframe, s, "SplashFoam", Vector3.new(2.8, 0.4, 1.1), CFrame.new(0, 0.58, -1.05), P.WATER_FOAM, nil, true, 0.15, false)

	for i = 1, 5 do
		local lx = ((i % 3) - 1) * 0.5
		local w = if i % 2 == 0 then 1.05 else 1.35
		local seg = addBox(m, cframe, s, "WaterSeg_" .. i, Vector3.new(w, 1.1, 0.34), CFrame.new(lx, 2.7, -1.52), P.WATER_FALL, Enum.Material.Glass, false, 0.22, false)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", lx)
		seg:SetAttribute("LocalZ", -1.52)
		seg:SetAttribute("StartVal", 4.85)
		seg:SetAttribute("EndVal", 0.72)
		seg:SetAttribute("Speed", 0.6 + (i % 3) * 0.05)
		seg:SetAttribute("Phase", (i - 1) / 5)
		seg:SetAttribute("BaseTransparency", 0.22)
	end
	for i = 1, 2 do
		local crest = addBox(m, cframe, s, "CrestSeg_" .. i, Vector3.new(1.8, 0.24, 0.8), CFrame.new(0, 5.18, -2.5), P.WATER_FOAM, Enum.Material.Glass, false, 0.28, false)
		crest:SetAttribute("FlowAxis", "Forward")
		crest:SetAttribute("LocalX", if i == 1 then -0.28 else 0.28)
		crest:SetAttribute("LocalY", 5.18)
		crest:SetAttribute("StartVal", -3.4)
		crest:SetAttribute("EndVal", -1.8)
		crest:SetAttribute("Speed", 0.62)
		crest:SetAttribute("Phase", (i - 1) * 0.5)
		crest:SetAttribute("BaseTransparency", 0.28)
	end
	for i = 1, 3 do
		local lx = (i - 2) * 0.65
		local drop = addBox(m, cframe, s, "Droplet_" .. i, Vector3.new(0.28, 0.3, 0.28), CFrame.new(lx, 2.9, -1.35), P.WATER_FOAM, Enum.Material.Glass, false, 0.2, false)
		drop:SetAttribute("AnimKind", "Droplet")
		drop:SetAttribute("LocalX", lx)
		drop:SetAttribute("LocalZ", -1.35)
		drop:SetAttribute("StartY", 4.8)
		drop:SetAttribute("EndY", 0.58)
		drop:SetAttribute("OutArcZ", 0.75)
		drop:SetAttribute("Speed", 0.68 + i * 0.06)
		drop:SetAttribute("Phase", (i - 1) / 3)
		drop:SetAttribute("BaseTransparency", 0.2)
	end
	addRippleRings(m, cframe, s, Vector3.new(0, 0.56, -0.5), Vector2.new(2.2, 1.8), 2, 0.58)

	local splashAnchor = addBox(m, cframe, s, "SplashAnchor", Vector3.new(2.4, 0.28, 1.1), CFrame.new(0, 0.64, -0.95), P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 1, false)
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "OasisSplashDroplets"
	spray.Color = ColorSequence.new(P.WATER_FOAM, P.WATER_FALL)
	spray.Rate = 8
	spray.Lifetime = NumberRange.new(0.45, 0.85)
	spray.Speed = NumberRange.new(2.2, 4.5)
	spray.SpreadAngle = Vector2.new(50, 50)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * s), NumberSequenceKeypoint.new(1, 0.05 * s) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	spray.Parent = splashAnchor

	return m
end

local function buildDryRiverbed(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "DryRiverbed", cframe, parent)
	addBox(m, cframe, s, "RiverFloor", Vector3.new(4.2, 0.16, 10.2), CFrame.new(0, 0.08, 0), P.TERRACOTTA_DARK, nil, true, 0, false)
	for _, xSide in ipairs({ -2.4, 2.4 }) do
		addBox(m, cframe, s, "Bank", Vector3.new(1.1, 0.55, 10.4), CFrame.new(xSide, 0.28, 0), P.SAND_TAN)
	end
	for i, rb in ipairs({ Vector3.new(-1.1, 0.35, -2.5), Vector3.new(1.2, 0.35, 1.8), Vector3.new(-0.8, 0.3, 3.6) }) do
		addBox(m, cframe, s, "BedBoulder_" .. i, Vector3.new(1.1, 0.6, 1.0), CFrame.new(rb) * CFrame.Angles(0, i * 0.4, 0), P.STONE_ORANGE)
	end
	addBox(m, cframe, s, "BedScrub", Vector3.new(0.65, 0.9, 0.65), CFrame.new(1.9, 0.7, -1.2), P.DRY_OCHRE, nil, true, 0, false)
	return m
end

local function buildSmallWaterChannels(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SmallWaterChannels", cframe, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "ChannelBed", Vector3.new(3.2, 0.18, 10.2), CFrame.new(0, 0.12, 0), P.WATER_DEEP, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "ChannelWater", Vector3.new(3.0, 0.24, 10.0), CFrame.new(0, 0.28, 0), P.WATER_TURQ, Enum.Material.Glass, false, 0.24, false)
	for _, xCurb in ipairs({ -2.0, 2.0 }) do
		addBox(m, cframe, s, "SandCurb", Vector3.new(1.0, 0.55, 10.4), CFrame.new(xCurb, 0.28, 0), P.STONE_WARM)
	end
	for i = 1, 4 do
		local lx = ((i % 2 == 0) and 0.45 or -0.45)
		local seg = addBox(m, cframe, s, "FlowSeg_" .. i, Vector3.new(1.15, 0.12, 1.8), CFrame.new(lx, 0.43, 0), P.WATER_FOAM, Enum.Material.Glass, false, 0.26, false)
		seg:SetAttribute("FlowAxis", "Forward")
		seg:SetAttribute("LocalX", lx)
		seg:SetAttribute("LocalY", 0.43)
		seg:SetAttribute("StartVal", -4.2)
		seg:SetAttribute("EndVal", 4.2)
		seg:SetAttribute("Speed", 0.44 + (i % 2) * 0.06)
		seg:SetAttribute("Phase", (i - 1) / 4)
		seg:SetAttribute("BaseTransparency", 0.26)
	end
	return m
end

-- ============================================================================
-- CATALOG & SERVERSTORAGE LIBRARY MANAGEMENT (46 ASSETS)
-- ============================================================================

DesertBiomeAssetBuilder.Catalog = {
	Trees = {
		{ name = "DesertPalmTree", category = "Trees", build = buildDesertPalmTree },
		{ name = "SmallPalmTree", category = "Trees", build = buildSmallPalmTree },
		{ name = "DeadDesertTree", category = "Trees", build = buildDeadDesertTree },
		{ name = "AncientTwistedTree", category = "Trees", build = buildAncientTwistedTree },
	},
	Cacti = {
		{ name = "TallSaguaroCactus", category = "Cacti", build = buildTallSaguaroCactus },
		{ name = "SmallSaguaroCactus", category = "Cacti", build = buildSmallSaguaroCactus },
		{ name = "PricklyPearCactus", category = "Cacti", build = buildPricklyPearCactus },
		{ name = "FloweringCactus", category = "Cacti", build = buildFloweringCactus },
	},
	Bushes = {
		{ name = "DryDesertBush", category = "Bushes", build = buildDryDesertBush },
		{ name = "SmallSucculentBush", category = "Bushes", build = buildSmallSucculentBush },
	},
	Plants = {
		{ name = "GoldenDryGrass", category = "Plants", build = buildGoldenDryGrass },
		{ name = "DesertFern", category = "Plants", build = buildDesertFern },
		{ name = "FloweringDesertPlant", category = "Plants", build = buildFloweringDesertPlant },
		{ name = "SmallPurpleDesertFlowers", category = "Plants", build = buildSmallPurpleDesertFlowers },
		{ name = "DesertReeds", category = "Plants", build = buildDesertReeds },
	},
	Rocks = {
		{ name = "SandstoneBoulder", category = "Rocks", build = buildSandstoneBoulder },
		{ name = "LayeredSandstoneRock", category = "Rocks", build = buildLayeredSandstoneRock },
		{ name = "TallRockPillar", category = "Rocks", build = buildTallRockPillar },
		{ name = "SmallRockClusters", category = "Rocks", build = buildSmallRockClusters },
	},
	TerrainProps = {
		{ name = "SandDunes", category = "TerrainProps", build = buildSandDunes },
		{ name = "CrackedDryGround", category = "TerrainProps", build = buildCrackedDryGround },
		{ name = "SandstoneCliffs", category = "TerrainProps", build = buildSandstoneCliffs },
		{ name = "BrokenRockFormations", category = "TerrainProps", build = buildBrokenRockFormations },
	},
	Ruins = {
		{ name = "AncientSandstoneArch", category = "Ruins", build = buildAncientSandstoneArch },
		{ name = "BrokenAncientPillars", category = "Ruins", build = buildBrokenAncientPillars },
		{ name = "SmallRuinedTemple", category = "Ruins", build = buildSmallRuinedTemple },
		{ name = "RuinedWalls", category = "Ruins", build = buildRuinedWalls },
	},
	Structures = {
		{ name = "DesertTempleEntrance", category = "Structures", build = buildDesertTempleEntrance },
		{ name = "SandstoneMonument", category = "Structures", build = buildSandstoneMonument },
		{ name = "AncientStoneGate", category = "Structures", build = buildAncientStoneGate },
		{ name = "AbandonedWatchtower", category = "Structures", build = buildAbandonedWatchtower },
	},
	Decorations = {
		{ name = "WoodenDesertLantern", category = "Decorations", build = buildWoodenDesertLantern },
		{ name = "WoodenBarrels", category = "Decorations", build = buildWoodenBarrels },
		{ name = "WoodenCrates", category = "Decorations", build = buildWoodenCrates },
		{ name = "MerchantCart", category = "Decorations", build = buildMerchantCart },
		{ name = "DesertSignpost", category = "Decorations", build = buildDesertSignpost },
		{ name = "AnimalBonesAndSkull", category = "Decorations", build = buildAnimalBonesAndSkull },
		{ name = "AncientTreasureChest", category = "Decorations", build = buildAncientTreasureChest },
		{ name = "SmallWoodenFences", category = "Decorations", build = buildSmallWoodenFences },
		{ name = "DesertBanners", category = "Decorations", build = buildDesertBanners },
	},
	WaterFeatures = {
		{ name = "SmallDesertOasis", category = "WaterFeatures", build = buildSmallDesertOasis },
		{ name = "TurquoiseWaterPond", category = "WaterFeatures", build = buildTurquoiseWaterPond },
		{ name = "OasisWithLilyPads", category = "WaterFeatures", build = buildOasisWithLilyPads },
		{ name = "SmallOasisWaterfall", category = "WaterFeatures", build = buildSmallOasisWaterfall },
		{ name = "DryRiverbed", category = "WaterFeatures", build = buildDryRiverbed },
		{ name = "SmallWaterChannels", category = "WaterFeatures", build = buildSmallWaterChannels },
	},
}

local EXPECTED_LIBRARY_VERSION = 1

function DesertBiomeAssetBuilder.EnsureLibrary(parentOverride: Instance?): Folder
	local rootParent: Instance = parentOverride or ServerStorage
	local existing = rootParent:FindFirstChild("DesertBiomeAssets")
	if existing and existing:IsA("Folder") and existing:GetAttribute("LibraryVersion") == EXPECTED_LIBRARY_VERSION then
		local complete = true
		for _, catName in ipairs(DesertBiomeAssetBuilder.CATEGORIES) do
			local sub = existing:FindFirstChild(catName)
			local list = (DesertBiomeAssetBuilder.Catalog :: any)[catName]
			if not sub or not list or #sub:GetChildren() < #list then
				complete = false
				break
			end
		end
		if complete then
			return existing
		end
	end

	if existing then
		existing:Destroy()
	end

	local lib = Instance.new("Folder")
	lib.Name = "DesertBiomeAssets"
	lib:SetAttribute("BiomeId", "SavannaCamp")
	lib:SetAttribute("LibraryVersion", EXPECTED_LIBRARY_VERSION)

	local totalCount = 0
	for _, catName in ipairs(DesertBiomeAssetBuilder.CATEGORIES) do
		local catFolder = Instance.new("Folder")
		catFolder.Name = catName
		local list = (DesertBiomeAssetBuilder.Catalog :: any)[catName] :: { AssetEntry }
		for _, entry in ipairs(list) do
			entry.build(CFrame.identity, 1, catFolder)
			totalCount += 1
		end
		catFolder.Parent = lib
		task.wait()
	end

	lib:SetAttribute("AssetCount", totalCount)
	lib.Parent = rootParent
	return lib
end

function DesertBiomeAssetBuilder.SpawnFromLibrary(
	category: string,
	assetName: string,
	cframe: CFrame,
	scale: number?,
	parent: Instance?
): Model
	local lib = DesertBiomeAssetBuilder.EnsureLibrary()
	local catFolder = lib:FindFirstChild(category)
	local template = if catFolder then catFolder:FindFirstChild(assetName) else nil
	if not template or not template:IsA("Model") then
		error(string.format("[DesertBiomeAssetBuilder] Asset '%s/%s' not found in DesertBiomeAssets", category, assetName))
	end

	local s = scale or 1
	local clone = template:Clone()
	if math.abs(s - 1) > 1e-4 then
		clone:ScaleTo(s)
	end
	if clone:GetAttribute("HasAnimatedWaterfall") == true or clone:GetAttribute("HasEnvironmentalAnim") == true then
		clone:SetAttribute("IslandScale", s)
	end
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
		end
	end
	clone:PivotTo(cframe)
	if parent then
		clone.Parent = parent
	end
	return clone
end

return DesertBiomeAssetBuilder
