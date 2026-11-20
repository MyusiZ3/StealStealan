--!strict
-- JungleBiomeAssetBuilder.luau
-- 56-Asset Voxel Jungle Biome Collection for Biome 1 (PineWoods / Jungle) matching visual reference.
-- Builds ServerStorage.JungleBiomeAssets organized into 9 clean subfolders:
-- Trees (10), Bushes (6), Plants (8), Flowers (5), Rocks (6), Mushrooms (4), Ruins (3), Decorations (10), WaterFeatures (4).
-- Every asset uses pure rectangular Studs/Glass/Neon Parts, Anchored = true, CanCollide/CanQuery/CanTouch = false,
-- PrimaryPart = RootPivot at ground origin CFrame.identity.

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ClassicStudBiomeBuilder = require(script.Parent.ClassicStudBiomeBuilder)

local JungleBiomeAssetBuilder = {}

export type AssetBuilderFn = (cframe: CFrame, scale: number?, parent: Instance?) -> Model

export type AssetEntry = {
	name: string,
	category: string,
	build: AssetBuilderFn,
}

JungleBiomeAssetBuilder.CATEGORIES = {
	"Trees",
	"Bushes",
	"Plants",
	"Flowers",
	"Rocks",
	"Mushrooms",
	"Ruins",
	"Decorations",
	"WaterFeatures",
}

-- ============================================================================
-- VISUAL PALETTE (Cohesive Stylized Voxel Jungle & Mossy Stone Palette)
-- ============================================================================

local P = {
	LEAF_DEEP = Color3.fromRGB(30, 96, 42),
	LEAF_MID = Color3.fromRGB(54, 146, 54),
	LEAF_BRIGHT = Color3.fromRGB(88, 184, 62),
	LEAF_LIME = Color3.fromRGB(134, 212, 72),
	LEAF_PINE_DARK = Color3.fromRGB(26, 86, 48),
	VINE_DARK = Color3.fromRGB(58, 144, 52),
	VINE_BRIGHT = Color3.fromRGB(104, 192, 68),

	BARK_DARK = Color3.fromRGB(88, 54, 34),
	BARK_MID = Color3.fromRGB(128, 82, 46),
	BARK_LIGHT = Color3.fromRGB(158, 106, 62),
	WOOD_CUT = Color3.fromRGB(204, 162, 106),
	WOOD_HOLLOW = Color3.fromRGB(52, 32, 20),

	STONE_DARK = Color3.fromRGB(72, 78, 90),
	STONE_MID = Color3.fromRGB(98, 106, 118),
	STONE_LIGHT = Color3.fromRGB(120, 128, 140),
	STONE_HI = Color3.fromRGB(138, 146, 158),
	MOSS_DARK = Color3.fromRGB(62, 148, 54),
	MOSS_BRIGHT = Color3.fromRGB(114, 198, 70),
	SOIL_DARK = Color3.fromRGB(104, 70, 42),

	LANTERN_IRON = Color3.fromRGB(56, 52, 54),
	LANTERN_GLOW = Color3.fromRGB(255, 198, 74),

	WATER_POOL = Color3.fromRGB(48, 188, 228),
	WATER_BED = Color3.fromRGB(24, 96, 128),
	WATER_FALL = Color3.fromRGB(78, 214, 252),
	WATER_FOAM = Color3.fromRGB(238, 250, 255),
	LILY_PAD = Color3.fromRGB(62, 168, 66),
	LILY_HI = Color3.fromRGB(98, 198, 76),
	LOTUS_PINK = Color3.fromRGB(255, 132, 186),
	LOTUS_GOLD = Color3.fromRGB(255, 224, 84),

	FL_RED = Color3.fromRGB(224, 58, 58),
	FL_ORANGE = Color3.fromRGB(246, 138, 46),
	FL_YELLOW = Color3.fromRGB(252, 214, 62),
	FL_PINK = Color3.fromRGB(242, 104, 168),
	FL_PURPLE = Color3.fromRGB(154, 88, 224),
	FL_BLUE = Color3.fromRGB(78, 146, 242),
	FL_WHITE = Color3.fromRGB(246, 246, 242),
	SHROOM_STEM = Color3.fromRGB(238, 226, 202),
	SHROOM_BROWN = Color3.fromRGB(142, 92, 52),
	SHROOM_TAN = Color3.fromRGB(184, 128, 78),
	SHROOM_GLOW = Color3.fromRGB(92, 246, 214),
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
	m:SetAttribute("BiomeId", "PineWoods")

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

local function addCanopyCluster(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	center: Vector3,
	w: number,
	h: number,
	d: number,
	toneBias: string?
)
	local deepCol = if toneBias == "Pine" then P.LEAF_PINE_DARK else P.LEAF_DEEP
	local midCol = P.LEAF_MID
	local brightCol = P.LEAF_BRIGHT
	local limeCol = P.LEAF_LIME

	addBox(m, originCF, s, prefix .. "_Under", Vector3.new(w * 0.92, h * 0.45, d * 0.92), CFrame.new(center + Vector3.new(0, -h * 0.25, 0)), deepCol)
	addBox(m, originCF, s, prefix .. "_Core", Vector3.new(w, h * 0.56, d), CFrame.new(center + Vector3.new(0, h * 0.05, 0)), midCol)
	addBox(m, originCF, s, prefix .. "_SideA", Vector3.new(w * 1.12, h * 0.34, d * 0.72), CFrame.new(center + Vector3.new(0.18, h * 0.08, -0.15)), midCol)
	addBox(m, originCF, s, prefix .. "_SideB", Vector3.new(w * 0.72, h * 0.34, d * 1.12), CFrame.new(center + Vector3.new(-0.18, h * 0.08, 0.15)), brightCol)
	addBox(m, originCF, s, prefix .. "_Crown", Vector3.new(w * 0.74, h * 0.36, d * 0.74), CFrame.new(center + Vector3.new(0.1, h * 0.42, -0.1)), brightCol)
	addBox(m, originCF, s, prefix .. "_SunTip", Vector3.new(w * 0.46, h * 0.28, d * 0.46), CFrame.new(center + Vector3.new(w * 0.12, h * 0.56, -d * 0.1)), limeCol)
end

local function addHangingVine(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	topPos: Vector3,
	length: number,
	stepDir: Vector3?
)
	local segs = math.max(2, math.floor(length / 1.5))
	local segH = length / segs
	local shift = stepDir or Vector3.new(0.18, 0, -0.12)
	for i = 1, segs do
		local y = topPos.Y - (i - 0.5) * segH
		local x = topPos.X + shift.X * (i % 2 == 0 and 1 or -0.5)
		local z = topPos.Z + shift.Z * (i % 2 == 0 and 1 or -0.5)
		local w = math.max(0.32, 0.56 - (i - 1) * 0.06)
		local col = if i == segs then P.VINE_BRIGHT elseif i % 2 == 0 then P.LEAF_BRIGHT else P.VINE_DARK
		addBox(m, originCF, s, prefix .. "_" .. i, Vector3.new(w, segH + 0.08, w), CFrame.new(x, y, z), col, nil, true, 0, false)
	end
end

local function addMossCap(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	pos: Vector3,
	w: number,
	d: number
)
	addBox(m, originCF, s, prefix .. "_Pad", Vector3.new(w, 0.38, d), CFrame.new(pos), P.MOSS_DARK, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Tip", Vector3.new(w * 0.65, 0.28, d * 0.65), CFrame.new(pos + Vector3.new(w * 0.12, 0.22, -d * 0.08)), P.MOSS_BRIGHT, nil, true, 0, false)
end

local function addLanternUnit(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	center: Vector3,
	lightRange: number?,
	brightness: number?
)
	local br = brightness or 1.05
	addBox(m, originCF, s, prefix .. "_TopCap", Vector3.new(1.22, 0.26, 1.22), CFrame.new(center + Vector3.new(0, 0.62, 0)), P.LANTERN_IRON)
	addBox(m, originCF, s, prefix .. "_BotCap", Vector3.new(1.14, 0.24, 1.14), CFrame.new(center + Vector3.new(0, -0.60, 0)), P.LANTERN_IRON)
	for _, corner in ipairs({
		Vector3.new(-0.46, 0, -0.46),
		Vector3.new(0.46, 0, -0.46),
		Vector3.new(-0.46, 0, 0.46),
		Vector3.new(0.46, 0, 0.46),
	}) do
		addBox(m, originCF, s, prefix .. "_Strut", Vector3.new(0.16, 1.0, 0.16), CFrame.new(center + corner), P.LANTERN_IRON)
	end
	local glowPart = addBox(m, originCF, s, prefix .. "_Glow", Vector3.new(0.76, 0.96, 0.76), CFrame.new(center), P.LANTERN_GLOW, Enum.Material.Neon, false, 0, false)
	local pl = Instance.new("PointLight")
	pl.Name = "LanternLight"
	pl.Color = P.LANTERN_GLOW
	pl.Range = lightRange or 18
	pl.Brightness = br
	pl.Shadows = false
	pl:SetAttribute("AnimKind", "LanternPulse")
	pl:SetAttribute("BaseBrightness", br)
	pl:SetAttribute("Phase", (math.abs(center.X) + math.abs(center.Z)) * 0.37)
	pl.Parent = glowPart
end

local function addFlowerStalk(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	x: number,
	yBase: number,
	z: number,
	height: number,
	petalCol: Color3,
	coreCol: Color3
)
	addBox(m, originCF, s, prefix .. "_LeafA", Vector3.new(0.55, 0.22, 0.28), CFrame.new(x + 0.16, yBase + height * 0.28, z) * CFrame.Angles(0, 0.4, math.rad(18)), P.LEAF_MID, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_LeafB", Vector3.new(0.28, 0.22, 0.55), CFrame.new(x - 0.14, yBase + height * 0.42, z + 0.12) * CFrame.Angles(math.rad(-16), 0.2, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Stem", Vector3.new(0.22, height, 0.22), CFrame.new(x, yBase + height * 0.5, z), P.VINE_DARK, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Petal", Vector3.new(0.86, 0.26, 0.86), CFrame.new(x, yBase + height + 0.08, z), petalCol, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Core", Vector3.new(0.4, 0.3, 0.4), CFrame.new(x, yBase + height + 0.2, z), coreCol, nil, true, 0, false)
end

local function addFireflies(parent: BasePart, rate: number?)
	local em = Instance.new("ParticleEmitter")
	em.Name = "JungleFireflies"
	em.Color = ColorSequence.new(Color3.fromRGB(184, 255, 118), Color3.fromRGB(255, 232, 108))
	em.Rate = rate or 3
	em.Lifetime = NumberRange.new(2.0, 3.6)
	em.Speed = NumberRange.new(0.6, 1.8)
	em.SpreadAngle = Vector2.new(180, 180)
	em.LightEmission = 0.75
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.26), NumberSequenceKeypoint.new(1, 0) })
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1) })
	em.Parent = parent
end

local function buildLilyPad(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, radius: number, yawDeg: number, hasLotus: boolean?, lotusCol: Color3?)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	addBox(m, originCF, s, prefix .. "_Pad", Vector3.new(radius, 0.14, radius * 0.88), cf, P.LILY_PAD, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Rim", Vector3.new(radius * 0.56, 0.16, radius * 0.52), cf * CFrame.new(radius * 0.12, 0.04, -radius * 0.1), P.LILY_HI, nil, true, 0, false)
	if hasLotus then
		local petal = lotusCol or P.LOTUS_PINK
		addBox(m, originCF, s, prefix .. "_LotusOut", Vector3.new(0.85, 0.26, 0.85), cf * CFrame.new(0, 0.18, 0), petal, nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_LotusTop", Vector3.new(0.54, 0.34, 0.54), cf * CFrame.new(0, 0.32, 0), Color3.fromRGB(255, 178, 214), nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_LotusCore", Vector3.new(0.28, 0.32, 0.28), cf * CFrame.new(0, 0.44, 0), P.LOTUS_GOLD, nil, true, 0, false)
	end
end

-- ============================================================================
-- 1. TREES (10: 5 Giant/Large + 5 Small/Medium)
-- ============================================================================

local function buildGiantJungleTree_CanopyArch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "GiantJungleTree_CanopyArch", cframe, parent)

	-- Flared buttress roots + stepped mossy pads
	for i, r in ipairs({
		{ pos = Vector3.new(-2.4, 1.1, 0.2), sz = Vector3.new(2.2, 2.2, 2.0), col = P.BARK_DARK },
		{ pos = Vector3.new(2.5, 0.9, -0.3), sz = Vector3.new(2.4, 1.8, 2.0), col = P.BARK_MID },
		{ pos = Vector3.new(0.2, 1.0, -2.3), sz = Vector3.new(2.0, 2.0, 2.2), col = P.BARK_DARK },
		{ pos = Vector3.new(-0.3, 1.0, 2.3), sz = Vector3.new(2.0, 2.0, 2.2), col = P.BARK_MID },
		{ pos = Vector3.new(-3.6, 0.55, 1.4), sz = Vector3.new(1.8, 1.1, 1.6), col = P.BARK_DARK },
	}) do
		addBox(m, cframe, s, "Buttress_" .. i, r.sz, CFrame.new(r.pos), r.col)
		addMossCap(m, cframe, s, "RootMoss_" .. i, Vector3.new(r.pos.X, r.sz.Y + 0.12, r.pos.Z), r.sz.X * 0.72, r.sz.Z * 0.72)
	end

	-- Stepped thick mahogany trunk
	addBox(m, cframe, s, "TrunkBase", Vector3.new(3.6, 5.2, 3.6), CFrame.new(0, 2.6, 0), P.BARK_MID)
	addBox(m, cframe, s, "TrunkRidge", Vector3.new(2.2, 6.2, 4.1), CFrame.new(0.3, 4.4, 0), P.BARK_DARK)
	addBox(m, cframe, s, "TrunkMid", Vector3.new(3.0, 5.4, 3.0), CFrame.new(-0.2, 7.6, 0.1), P.BARK_MID)
	addBox(m, cframe, s, "TrunkUpper", Vector3.new(2.3, 4.8, 2.3), CFrame.new(0.2, 11.8, -0.2), P.BARK_LIGHT)

	-- Jutting stepped right limb shelf & high left arch arm (from top-left reference)
	addBox(m, cframe, s, "ShelfLimbR", Vector3.new(4.8, 1.5, 1.7), CFrame.new(2.8, 8.2, 0.3) * CFrame.Angles(0, 0, math.rad(10)), P.BARK_MID)
	addBox(m, cframe, s, "ArchLimbL", Vector3.new(5.4, 1.6, 1.8), CFrame.new(-3.1, 11.4, -0.2) * CFrame.Angles(0, 0, math.rad(-16)), P.BARK_DARK)
	addBox(m, cframe, s, "HighLimbR", Vector3.new(4.2, 1.4, 1.6), CFrame.new(2.6, 12.6, -0.4) * CFrame.Angles(0, 0, math.rad(18)), P.BARK_MID)

	-- 3 staggered layered jungle canopies
	addCanopyCluster(m, cframe, s, "CanopyHigh", Vector3.new(-1.8, 15.6, -0.2), 11.2, 4.4, 10.4)
	addCanopyCluster(m, cframe, s, "CanopyCrown", Vector3.new(1.8, 14.8, -0.4), 9.4, 3.8, 8.8)
	addCanopyCluster(m, cframe, s, "CanopyShelf", Vector3.new(4.8, 10.4, 0.6), 7.8, 3.4, 7.2)

	-- 8 stepped hanging vines
	for i, v in ipairs({
		{ p = Vector3.new(-6.4, 13.6, 2.4), len = 6.2 },
		{ p = Vector3.new(-4.8, 13.4, -3.8), len = 5.4 },
		{ p = Vector3.new(-1.8, 13.2, 4.5), len = 4.8 },
		{ p = Vector3.new(2.6, 12.8, -4.1), len = 5.2 },
		{ p = Vector3.new(5.8, 12.8, 2.8), len = 4.4 },
		{ p = Vector3.new(7.4, 8.8, 1.6), len = 4.6 },
		{ p = Vector3.new(4.2, 8.8, -2.5), len = 4.2 },
		{ p = Vector3.new(0.8, 13.4, 4.0), len = 3.8 },
	}) do
		addHangingVine(m, cframe, s, "Vine_" .. i, v.p, v.len)
	end
	return m
end

local function buildGiantJungleTree_TwinFork(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "GiantJungleTree_TwinFork", cframe, parent)

	addBox(m, cframe, s, "RootCore", Vector3.new(4.6, 1.4, 4.4), CFrame.new(0, 0.7, 0), P.BARK_DARK)
	addBox(m, cframe, s, "TrunkBase", Vector3.new(3.2, 6.4, 3.2), CFrame.new(0, 3.4, 0), P.BARK_MID)
	-- Twin forked trunks
	addBox(m, cframe, s, "ForkTrunkL", Vector3.new(2.1, 7.2, 2.1), CFrame.new(-2.4, 8.8, 0.4) * CFrame.Angles(0, 0, math.rad(22)), P.BARK_DARK)
	addBox(m, cframe, s, "ForkTrunkR", Vector3.new(2.2, 8.0, 2.2), CFrame.new(2.3, 9.2, -0.4) * CFrame.Angles(0, 0, math.rad(-18)), P.BARK_MID)
	addBox(m, cframe, s, "ForkSpur", Vector3.new(3.4, 1.2, 1.4), CFrame.new(4.2, 10.6, 0.2) * CFrame.Angles(0, 0, math.rad(14)), P.BARK_LIGHT)

	addCanopyCluster(m, cframe, s, "TwinCanopyL", Vector3.new(-3.8, 13.2, 0.6), 9.4, 3.8, 8.8)
	addCanopyCluster(m, cframe, s, "TwinCanopyR", Vector3.new(3.4, 14.4, -0.5), 10.6, 4.2, 9.8)
	addCanopyCluster(m, cframe, s, "TwinCanopyCenter", Vector3.new(0, 15.8, 0), 7.6, 3.2, 7.4)

	for i, v in ipairs({
		{ p = Vector3.new(-7.4, 11.4, 1.6), len = 5.4 },
		{ p = Vector3.new(-5.2, 11.4, -3.2), len = 4.6 },
		{ p = Vector3.new(7.4, 12.6, 1.4), len = 6.0 },
		{ p = Vector3.new(5.2, 12.4, -4.0), len = 4.8 },
		{ p = Vector3.new(0.6, 11.8, 4.2), len = 5.2 },
		{ p = Vector3.new(-1.8, 11.6, -3.6), len = 4.2 },
	}) do
		addHangingVine(m, cframe, s, "Vine_" .. i, v.p, v.len)
	end
	return m
end

local function buildGiantJungleTree_AncientBanyan(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "GiantJungleTree_AncientBanyan", cframe, parent)

	local fluteCore = addBox(m, cframe, s, "BanyanCore", Vector3.new(4.2, 9.6, 4.2), CFrame.new(0, 4.8, 0), P.BARK_MID)
	addFireflies(fluteCore, 3)

	-- 4 arched aerial prop-root columns
	for i, ang in ipairs({ 20, 110, 200, 290 }) do
		local rot = CFrame.Angles(0, math.rad(ang), 0)
		addBox(m, cframe, s, "AerialCol_" .. i, Vector3.new(1.3, 6.2, 1.3), rot * CFrame.new(3.2, 3.1, 0), P.BARK_DARK)
		addBox(m, cframe, s, "AerialKnee_" .. i, Vector3.new(2.8, 1.3, 1.4), rot * CFrame.new(2.2, 6.4, 0) * CFrame.Angles(0, 0, math.rad(16)), P.BARK_MID)
		addMossCap(m, cframe, s, "AerialMoss_" .. i, (rot * CFrame.new(3.2, 0.35, 0)).Position, 1.8, 1.8)
	end

	addBox(m, cframe, s, "UpperCrownTrunk", Vector3.new(3.0, 5.4, 3.0), CFrame.new(0, 11.2, 0), P.BARK_DARK)
	addCanopyCluster(m, cframe, s, "BanyanLow", Vector3.new(0, 11.4, 0), 15.2, 3.4, 14.2)
	addCanopyCluster(m, cframe, s, "BanyanMid", Vector3.new(0.4, 14.0, -0.3), 12.2, 3.4, 11.4)
	addCanopyCluster(m, cframe, s, "BanyanTop", Vector3.new(-0.3, 16.4, 0.2), 8.2, 2.8, 7.8)

	for i = 1, 10 do
		local ang = (i / 10) * math.pi * 2
		local r = if i % 2 == 0 then 6.8 else 5.0
		local top = Vector3.new(math.cos(ang) * r, 10.0, math.sin(ang) * r)
		addHangingVine(m, cframe, s, "VineCurtain_" .. i, top, 4.4 + (i % 3) * 1.3)
	end
	return m
end

local function buildGiantJungleTree_LayeredPine(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "GiantJungleTree_LayeredPine", cframe, parent)

	for i, off in ipairs({ Vector3.new(1.8, 0.8, 0), Vector3.new(-1.8, 0.8, 0), Vector3.new(0, 0.8, 1.8), Vector3.new(0, 0.8, -1.8) }) do
		addBox(m, cframe, s, "PineButtress_" .. i, Vector3.new(1.6, 1.6, 1.6), CFrame.new(off), P.BARK_DARK)
	end
	addBox(m, cframe, s, "PineTrunkLow", Vector3.new(2.8, 7.6, 2.8), CFrame.new(0, 3.8, 0), P.BARK_MID)
	addBox(m, cframe, s, "PineTrunkHigh", Vector3.new(2.0, 12.0, 2.0), CFrame.new(0, 12.6, 0), P.BARK_DARK)

	-- 6 jagged asymmetric stepped pine tiers matching vibrant jungle-pine hybrid look
	for i, t in ipairs({
		{ y = 7.4, w = 11.4, h = 2.6, off = Vector3.new(0.3, 0, -0.2), col = P.LEAF_PINE_DARK },
		{ y = 10.2, w = 9.4, h = 2.5, off = Vector3.new(-0.3, 0, 0.2), col = P.LEAF_DEEP },
		{ y = 12.8, w = 7.6, h = 2.4, off = Vector3.new(0.2, 0, 0.2), col = P.LEAF_MID },
		{ y = 15.3, w = 5.8, h = 2.2, off = Vector3.new(-0.2, 0, -0.1), col = P.LEAF_MID },
		{ y = 17.6, w = 4.0, h = 2.0, off = Vector3.new(0.1, 0, 0), col = P.LEAF_BRIGHT },
		{ y = 19.7, w = 2.4, h = 1.9, off = Vector3.new(0, 0, 0), col = P.LEAF_LIME },
	}) do
		addBox(m, cframe, s, "TierMain_" .. i, Vector3.new(t.w, t.h, t.w), CFrame.new(t.off + Vector3.new(0, t.y, 0)), t.col)
		addBox(m, cframe, s, "TierWingX_" .. i, Vector3.new(t.w + 1.5, t.h * 0.52, t.w * 0.64), CFrame.new(t.off + Vector3.new(0, t.y + 0.15, 0)), P.LEAF_BRIGHT)
		if i <= 3 then
			addHangingVine(m, cframe, s, "MossWisp_" .. i, Vector3.new((i % 2 == 0 and 1 or -1) * (t.w * 0.44), t.y - 0.8, 1.8), 2.8)
		end
	end
	addBox(m, cframe, s, "PineSpire", Vector3.new(1.2, 2.0, 1.2), CFrame.new(0, 21.4, 0), P.LEAF_LIME)
	return m
end

local function buildGiantJungleTree_OverhangLimb(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "GiantJungleTree_OverhangLimb", cframe, parent)

	addBox(m, cframe, s, "BasePlinth", Vector3.new(4.2, 1.3, 4.0), CFrame.new(0, 0.65, 0), P.BARK_DARK)
	addMossCap(m, cframe, s, "BaseMoss", Vector3.new(-1.6, 1.42, 0.9), 2.2, 2.0)
	addBox(m, cframe, s, "LeanTrunkLow", Vector3.new(3.0, 6.2, 3.0), CFrame.new(-0.4, 3.4, 0) * CFrame.Angles(0, 0, math.rad(8)), P.BARK_MID)
	addBox(m, cframe, s, "LeanTrunkHigh", Vector3.new(2.4, 6.8, 2.4), CFrame.new(-1.4, 9.0, 0.2) * CFrame.Angles(0, 0, math.rad(12)), P.BARK_DARK)
	addBox(m, cframe, s, "OverhangArm", Vector3.new(6.8, 1.7, 1.8), CFrame.new(2.2, 9.8, -0.3) * CFrame.Angles(0, 0, math.rad(12)), P.BARK_LIGHT)

	addCanopyCluster(m, cframe, s, "OverhangDeck", Vector3.new(4.6, 11.4, -0.3), 8.6, 3.4, 8.2)
	addCanopyCluster(m, cframe, s, "CrownDeck", Vector3.new(-2.4, 14.0, 0.3), 10.6, 4.2, 9.8)

	for i, v in ipairs({
		{ p = Vector3.new(7.8, 9.8, 1.6), len = 5.2 },
		{ p = Vector3.new(5.2, 9.8, -2.8), len = 4.6 },
		{ p = Vector3.new(-6.2, 12.0, 2.6), len = 5.4 },
		{ p = Vector3.new(-3.8, 12.2, -3.8), len = 4.8 },
		{ p = Vector3.new(0.4, 10.2, 3.4), len = 4.0 },
	}) do
		addHangingVine(m, cframe, s, "Vine_" .. i, v.p, v.len)
	end
	return m
end

local function buildSmallJungleTree_Broadleaf(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallJungleTree_Broadleaf", cframe, parent)

	addBox(m, cframe, s, "RootPad", Vector3.new(2.6, 0.8, 2.6), CFrame.new(0, 0.4, 0), P.BARK_DARK)
	addBox(m, cframe, s, "TrunkLow", Vector3.new(1.7, 3.6, 1.7), CFrame.new(0, 2.0, 0), P.BARK_MID)
	addBox(m, cframe, s, "TrunkBent", Vector3.new(1.4, 3.2, 1.4), CFrame.new(0.4, 4.8, -0.2) * CFrame.Angles(0, 0, math.rad(-10)), P.BARK_DARK)
	addBox(m, cframe, s, "BranchTwig", Vector3.new(2.2, 0.9, 1.0), CFrame.new(-1.0, 5.4, 0.3) * CFrame.Angles(0, 0, math.rad(-18)), P.BARK_LIGHT)

	addCanopyCluster(m, cframe, s, "MainCanopy", Vector3.new(0.4, 7.6, -0.2), 7.4, 3.2, 7.0)
	addCanopyCluster(m, cframe, s, "SideLobe", Vector3.new(-2.2, 6.8, 0.5), 4.6, 2.4, 4.4)
	addHangingVine(m, cframe, s, "VineL", Vector3.new(-3.6, 5.8, 0.8), 2.8)
	addHangingVine(m, cframe, s, "VineR", Vector3.new(3.2, 6.1, -1.6), 3.1)
	return m
end

local function buildSmallJungleTree_TropicalPalm(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallJungleTree_TropicalPalm", cframe, parent)

	addBox(m, cframe, s, "PalmRoot", Vector3.new(2.4, 0.7, 2.4), CFrame.new(0, 0.35, 0), P.BARK_DARK)
	-- Arched 6-segment stepped palm trunk matching Trees Variations top-right reference
	local segCoords = {
		Vector3.new(0.0, 1.4, 0.0),
		Vector3.new(0.35, 3.3, 0.05),
		Vector3.new(0.8, 5.2, 0.1),
		Vector3.new(1.3, 7.1, 0.05),
		Vector3.new(1.65, 9.0, 0.0),
		Vector3.new(1.85, 10.7, 0.0),
	}
	for i, pos in ipairs(segCoords) do
		local w = 1.65 - (i - 1) * 0.11
		local col = if i % 2 == 0 then P.BARK_MID else P.BARK_LIGHT
		addBox(m, cframe, s, "PalmSeg_" .. i, Vector3.new(w, 2.05, w), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(-8)), col)
	end

	local top = Vector3.new(1.9, 11.7, 0)
	addBox(m, cframe, s, "PalmCrownHub", Vector3.new(2.4, 1.2, 2.4), CFrame.new(top), P.LEAF_DEEP)
	-- 3 coconuts tucked beneath fronds
	for i, cOff in ipairs({ Vector3.new(-0.8, -0.7, 0.6), Vector3.new(0.8, -0.65, 0.5), Vector3.new(0, -0.75, -0.8) }) do
		addBox(m, cframe, s, "Coconut_" .. i, Vector3.new(0.65, 0.65, 0.65), CFrame.new(top + cOff), P.BARK_DARK)
	end
	-- 6 arched stepped voxel palm fronds
	for i = 1, 6 do
		local rot = CFrame.new(top) * CFrame.Angles(0, math.rad((i - 1) * 60 + 18), 0)
		addBox(m, cframe, s, "FrondA_" .. i, Vector3.new(2.8, 0.65, 1.4), rot * CFrame.new(2.1, 0.45, 0) * CFrame.Angles(0, 0, math.rad(12)), P.LEAF_MID)
		addBox(m, cframe, s, "FrondB_" .. i, Vector3.new(2.5, 0.55, 1.2), rot * CFrame.new(4.3, 0.15, 0) * CFrame.Angles(0, 0, math.rad(-14)), P.LEAF_BRIGHT)
		addBox(m, cframe, s, "FrondTip_" .. i, Vector3.new(1.6, 0.45, 0.9), rot * CFrame.new(5.8, -0.75, 0) * CFrame.Angles(0, 0, math.rad(-34)), P.LEAF_LIME)
		if i % 2 == 1 then
			addHangingVine(m, cframe, s, "PalmVine_" .. i, (rot * CFrame.new(4.5, -0.35, 0)).Position, 2.4)
		end
	end
	return m
end

local function buildSmallJungleTree_SplitUmbrella(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallJungleTree_SplitUmbrella", cframe, parent)

	addBox(m, cframe, s, "SplitBase", Vector3.new(2.8, 0.8, 2.4), CFrame.new(0, 0.4, 0), P.BARK_DARK)
	addBox(m, cframe, s, "TrunkL", Vector3.new(1.2, 6.2, 1.2), CFrame.new(-0.9, 3.4, 0.2) * CFrame.Angles(0, 0, math.rad(8)), P.BARK_MID)
	addBox(m, cframe, s, "TrunkR", Vector3.new(1.1, 5.8, 1.1), CFrame.new(1.0, 3.2, -0.2) * CFrame.Angles(0, 0, math.rad(-10)), P.BARK_DARK)

	addCanopyCluster(m, cframe, s, "UmbrellaMain", Vector3.new(0, 7.6, 0), 8.6, 2.5, 7.8)
	addCanopyCluster(m, cframe, s, "UmbrellaSide", Vector3.new(-2.4, 8.6, 0.4), 5.0, 2.0, 4.8)
	addHangingVine(m, cframe, s, "Vine1", Vector3.new(-4.0, 6.4, 1.2), 2.8)
	addHangingVine(m, cframe, s, "Vine2", Vector3.new(3.6, 6.4, -1.4), 3.0)
	addHangingVine(m, cframe, s, "Vine3", Vector3.new(0.4, 6.3, 3.4), 2.3)
	return m
end

local function buildSmallJungleTree_SteppedCanopy(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallJungleTree_SteppedCanopy", cframe, parent)

	addBox(m, cframe, s, "RootFoot", Vector3.new(2.4, 0.85, 2.4), CFrame.new(0, 0.42, 0), P.BARK_DARK)
	addBox(m, cframe, s, "MainStem", Vector3.new(1.6, 5.4, 1.6), CFrame.new(0, 3.0, 0), P.BARK_MID)
	addBox(m, cframe, s, "StepShelf", Vector3.new(2.6, 1.0, 1.2), CFrame.new(1.4, 4.6, 0.2), P.BARK_LIGHT)

	addCanopyCluster(m, cframe, s, "TierLower", Vector3.new(1.6, 6.2, 0.2), 5.2, 2.4, 5.0)
	addCanopyCluster(m, cframe, s, "TierUpper", Vector3.new(-0.4, 8.2, -0.2), 6.8, 3.0, 6.6)
	addHangingVine(m, cframe, s, "VineA", Vector3.new(-3.0, 6.8, 1.8), 2.6)
	addHangingVine(m, cframe, s, "VineB", Vector3.new(3.6, 5.1, -1.2), 2.4)
	return m
end

local function buildSmallJungleTree_SpruceSapling(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallJungleTree_SpruceSapling", cframe, parent)

	addBox(m, cframe, s, "SpruceFoot", Vector3.new(2.0, 0.6, 2.0), CFrame.new(0, 0.3, 0), P.BARK_DARK)
	addBox(m, cframe, s, "SpruceTrunk", Vector3.new(1.3, 8.0, 1.3), CFrame.new(0, 4.1, 0), P.BARK_MID)

	for i, t in ipairs({
		{ y = 3.6, w = 6.2, h = 1.7, col = P.LEAF_PINE_DARK },
		{ y = 5.4, w = 5.0, h = 1.6, col = P.LEAF_DEEP },
		{ y = 7.0, w = 3.9, h = 1.5, col = P.LEAF_MID },
		{ y = 8.5, w = 2.8, h = 1.4, col = P.LEAF_BRIGHT },
		{ y = 9.8, w = 1.8, h = 1.3, col = P.LEAF_LIME },
	}) do
		addBox(m, cframe, s, "SpruceTier_" .. i, Vector3.new(t.w, t.h, t.w), CFrame.new(0, t.y, 0), t.col)
		if i <= 3 then
			addBox(m, cframe, s, "SpruceTipRim_" .. i, Vector3.new(t.w - 1.0, 0.45, t.w + 0.6), CFrame.new(0, t.y + 0.55, 0), P.LEAF_BRIGHT)
		end
	end
	addBox(m, cframe, s, "SpruceTop", Vector3.new(0.9, 1.2, 0.9), CFrame.new(0, 11.0, 0), P.LEAF_LIME)
	return m
end

-- ============================================================================
-- 2. BUSHES (6)
-- ============================================================================

local function buildBush_DenseBlocky(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "Bush_DenseBlocky", cframe, parent)
	addBox(m, cframe, s, "CoreDeep", Vector3.new(4.2, 2.2, 3.8), CFrame.new(0, 1.1, 0), P.LEAF_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "SideL", Vector3.new(2.2, 1.7, 2.6), CFrame.new(-1.5, 0.85, 0.4), P.LEAF_MID, nil, true, 0, false)
	addBox(m, cframe, s, "SideR", Vector3.new(2.2, 1.8, 2.4), CFrame.new(1.5, 0.9, -0.3), P.LEAF_MID, nil, true, 0, false)
	addBox(m, cframe, s, "TopMid", Vector3.new(2.8, 1.2, 2.6), CFrame.new(0.1, 2.5, 0.1), P.LEAF_BRIGHT, nil, true, 0, false)
	addBox(m, cframe, s, "SunCap", Vector3.new(1.6, 0.65, 1.6), CFrame.new(-0.3, 3.15, -0.2), P.LEAF_LIME, nil, true, 0, false)
	return m
end

local function buildBush_UprightBerry(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "Bush_UprightBerry", cframe, parent)
	addBox(m, cframe, s, "Core", Vector3.new(2.8, 3.2, 2.8), CFrame.new(0, 1.6, 0), P.LEAF_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "WrapA", Vector3.new(3.4, 1.9, 2.2), CFrame.new(0, 1.4, 0.2), P.LEAF_MID, nil, true, 0, false)
	addBox(m, cframe, s, "WrapB", Vector3.new(2.2, 2.2, 3.4), CFrame.new(0.1, 1.8, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	addBox(m, cframe, s, "Crown", Vector3.new(1.8, 1.0, 1.8), CFrame.new(-0.1, 3.4, 0), P.LEAF_LIME, nil, true, 0, false)
	for i, off in ipairs({
		Vector3.new(-1.7, 1.6, 0.6),
		Vector3.new(1.65, 2.1, -0.4),
		Vector3.new(0.4, 2.4, 1.7),
		Vector3.new(-0.5, 1.1, -1.65),
	}) do
		addBox(m, cframe, s, "Berry_" .. i, Vector3.new(0.38, 0.38, 0.38), CFrame.new(off), if i % 2 == 0 then P.FL_ORANGE else P.FL_RED, nil, true, 0, false)
	end
	return m
end

local function buildFloweredBush(id: string, cframe: CFrame, scale: number?, parent: Instance?, petalA: Color3, petalB: Color3, wideScale: Vector3?): Model
	local s = scale or 1
	local w = wideScale or Vector3.new(1, 1, 1)
	local m = newModel("Bushes", id, cframe, parent)
	addBox(m, cframe, s, "Core", Vector3.new(3.6 * w.X, 2.0 * w.Y, 3.4 * w.Z), CFrame.new(0, 1.0 * w.Y, 0), P.LEAF_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "Mid", Vector3.new(4.2 * w.X, 1.4 * w.Y, 2.8 * w.Z), CFrame.new(0.1, 1.2 * w.Y, 0), P.LEAF_MID, nil, true, 0, false)
	addBox(m, cframe, s, "Top", Vector3.new(2.4 * w.X, 1.0 * w.Y, 2.4 * w.Z), CFrame.new(0, 2.2 * w.Y, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	for i, fl in ipairs({
		{ pos = Vector3.new(-1.5 * w.X, 1.4 * w.Y, 1.2 * w.Z), col = petalA },
		{ pos = Vector3.new(1.4 * w.X, 1.5 * w.Y, 1.1 * w.Z), col = petalB },
		{ pos = Vector3.new(-0.6 * w.X, 2.4 * w.Y, 0.8 * w.Z), col = petalA },
		{ pos = Vector3.new(0.8 * w.X, 2.3 * w.Y, -0.9 * w.Z), col = petalB },
		{ pos = Vector3.new(0.2 * w.X, 1.3 * w.Y, -1.6 * w.Z), col = petalA },
	}) do
		addBox(m, cframe, s, "Bloom_" .. i, Vector3.new(0.55, 0.52, 0.55), CFrame.new(fl.pos), fl.col, nil, true, 0, false)
		addBox(m, cframe, s, "BloomCore_" .. i, Vector3.new(0.24, 0.24, 0.24), CFrame.new(fl.pos + Vector3.new(0, 0.22, 0)), P.FL_YELLOW, nil, true, 0, false)
	end
	return m
end

local function buildBush_PinkBlossom(cframe: CFrame, scale: number?, parent: Instance?): Model
	return buildFloweredBush("Bush_PinkBlossom", cframe, scale, parent, P.FL_PINK, P.FL_WHITE, Vector3.new(1.05, 1.0, 1.0))
end

local function buildBush_RedBlossom(cframe: CFrame, scale: number?, parent: Instance?): Model
	return buildFloweredBush("Bush_RedBlossom", cframe, scale, parent, P.FL_RED, P.FL_ORANGE, Vector3.new(0.95, 1.05, 0.95))
end

local function buildBush_PurpleBlossom(cframe: CFrame, scale: number?, parent: Instance?): Model
	return buildFloweredBush("Bush_PurpleBlossom", cframe, scale, parent, P.FL_PURPLE, P.FL_PINK, Vector3.new(1.0, 0.95, 1.05))
end

local function buildBush_WideLowThicket(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "Bush_WideLowThicket", cframe, parent)
	addBox(m, cframe, s, "ThicketBase", Vector3.new(5.6, 1.3, 4.4), CFrame.new(0, 0.65, 0), P.LEAF_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "ThicketShelfL", Vector3.new(3.2, 1.5, 3.0), CFrame.new(-1.6, 0.95, 0.3), P.LEAF_MID, nil, true, 0, false)
	addBox(m, cframe, s, "ThicketShelfR", Vector3.new(3.0, 1.3, 3.2), CFrame.new(1.5, 0.85, -0.3), P.LEAF_BRIGHT, nil, true, 0, false)
	addBox(m, cframe, s, "ThicketCrest", Vector3.new(2.2, 0.8, 2.0), CFrame.new(-0.6, 1.85, 0.1), P.LEAF_LIME, nil, true, 0, false)
	return m
end

-- ============================================================================
-- 3. PLANTS (8)
-- ============================================================================

local function buildPlant_TallGrassTuft(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_TallGrassTuft", cframe, parent)
	addBox(m, cframe, s, "TurfPad", Vector3.new(2.8, 0.22, 2.6), CFrame.new(0, 0.11, 0), P.LEAF_DEEP, nil, true, 0, false)
	for i, b in ipairs({
		{ x = -0.8, z = -0.5, h = 1.8, tilt = Vector3.new(10, 0, 12), col = P.LEAF_MID },
		{ x = -0.2, z = 0.2, h = 2.4, tilt = Vector3.new(-6, 15, -5), col = P.LEAF_BRIGHT },
		{ x = 0.65, z = -0.3, h = 2.0, tilt = Vector3.new(8, -12, -14), col = P.LEAF_MID },
		{ x = 0.1, z = -0.8, h = 1.6, tilt = Vector3.new(-14, 0, 6), col = P.LEAF_LIME },
		{ x = 0.8, z = 0.7, h = 1.5, tilt = Vector3.new(14, 24, -8), col = P.LEAF_LIME },
		{ x = -0.7, z = 0.65, h = 1.9, tilt = Vector3.new(12, -18, 10), col = P.LEAF_BRIGHT },
	}) do
		addBox(m, cframe, s, "Blade_" .. i, Vector3.new(0.42, b.h, 0.42), CFrame.new(b.x, b.h * 0.5 + 0.12, b.z) * CFrame.Angles(math.rad(b.tilt.X), math.rad(b.tilt.Y), math.rad(b.tilt.Z)), b.col, nil, true, 0, false)
	end
	return m
end

local function buildPlant_BroadBananaLeaf(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_BroadBananaLeaf", cframe, parent)
	addBox(m, cframe, s, "HeartStem", Vector3.new(0.95, 1.2, 0.95), CFrame.new(0, 0.6, 0), P.VINE_DARK, nil, true, 0, false)
	for i = 1, 5 do
		local rot = CFrame.Angles(0, math.rad((i - 1) * 72 + 12), 0)
		addBox(m, cframe, s, "LeafArm_" .. i, Vector3.new(1.15, 0.26, 2.2), rot * CFrame.new(0, 1.35, 1.1) * CFrame.Angles(math.rad(28), 0, 0), P.LEAF_MID, nil, true, 0, false)
		addBox(m, cframe, s, "LeafTip_" .. i, Vector3.new(0.95, 0.22, 1.4), rot * CFrame.new(0, 1.55, 2.45) * CFrame.Angles(math.rad(-14), 0, 0), P.LEAF_LIME, nil, true, 0, false)
	end
	return m
end

local function buildPlant_LushJungleFern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_LushJungleFern", cframe, parent)
	addBox(m, cframe, s, "FernHub", Vector3.new(1.3, 0.9, 1.3), CFrame.new(0, 0.45, 0), P.LEAF_DEEP, nil, true, 0, false)
	for i = 0, 7 do
		local rot = CFrame.Angles(0, math.rad(i * 45), 0)
		local len = if i % 2 == 0 then 2.1 else 1.65
		local elev = if i % 2 == 0 then 0.95 else 1.25
		addBox(m, cframe, s, "FrondBase_" .. i, Vector3.new(0.75, 0.26, len), rot * CFrame.new(0, elev, len * 0.55) * CFrame.Angles(math.rad(20), 0, 0), P.LEAF_MID, nil, true, 0, false)
		addBox(m, cframe, s, "FrondTip_" .. i, Vector3.new(0.5, 0.22, 1.15), rot * CFrame.new(0, elev + 0.12, len + 0.45) * CFrame.Angles(math.rad(-12), 0, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	end
	return m
end

local function buildPlant_SpireSapling(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_SpireSapling", cframe, parent)
	addBox(m, cframe, s, "SaplingStem", Vector3.new(0.5, 1.2, 0.5), CFrame.new(0, 0.6, 0), P.BARK_DARK, nil, true, 0, false)
	for i, t in ipairs({
		{ y = 1.2, w = 2.4, h = 0.85, col = P.LEAF_PINE_DARK },
		{ y = 2.0, w = 1.9, h = 0.85, col = P.LEAF_MID },
		{ y = 2.8, w = 1.4, h = 0.8, col = P.LEAF_BRIGHT },
		{ y = 3.55, w = 0.85, h = 0.8, col = P.LEAF_LIME },
	}) do
		addBox(m, cframe, s, "SpireTier_" .. i, Vector3.new(t.w, t.h, t.w), CFrame.new(0, t.y, 0), t.col, nil, true, 0, false)
	end
	return m
end

local function buildPlant_TropicalReeds(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_TropicalReeds", cframe, parent)
	addBox(m, cframe, s, "SoilPad", Vector3.new(2.2, 0.22, 2.2), CFrame.new(0, 0.11, 0), P.LEAF_DEEP, nil, true, 0, false)
	for i, r in ipairs({
		{ x = -0.45, z = -0.2, h = 3.6, tilt = 8 },
		{ x = 0.25, z = 0.35, h = 4.2, tilt = -6 },
		{ x = 0.65, z = -0.4, h = 3.1, tilt = 11 },
		{ x = -0.2, z = 0.6, h = 2.8, tilt = -10 },
	}) do
		local cf = CFrame.new(r.x, r.h * 0.5, r.z) * CFrame.Angles(math.rad(r.tilt), 0, math.rad(r.tilt * 0.5))
		addBox(m, cframe, s, "ReedStalk_" .. i, Vector3.new(0.28, r.h, 0.28), cf, P.LEAF_MID, nil, true, 0, false)
		addBox(m, cframe, s, "ReedLeaf_" .. i, Vector3.new(0.62, 0.8, 0.36), cf * CFrame.new(0, r.h * 0.32, 0.2), P.LEAF_LIME, nil, true, 0, false)
	end
	return m
end

local function buildPlant_SpreadingLowFern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_SpreadingLowFern", cframe, parent)
	addBox(m, cframe, s, "LowHub", Vector3.new(1.6, 0.45, 1.6), CFrame.new(0, 0.22, 0), P.LEAF_DEEP, nil, true, 0, false)
	for i = 1, 6 do
		local rot = CFrame.Angles(0, math.rad(i * 60 + 20), 0)
		addBox(m, cframe, s, "LowBlade_" .. i, Vector3.new(0.55, 0.24, 1.85), rot * CFrame.new(0, 0.5, 1.15) * CFrame.Angles(math.rad(14), 0, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	end
	addBox(m, cframe, s, "CenterSprout", Vector3.new(0.65, 1.1, 0.65), CFrame.new(0, 0.75, 0), P.LEAF_LIME, nil, true, 0, false)
	return m
end

local function buildPlant_BroadMonstera(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_BroadMonstera", cframe, parent)
	addBox(m, cframe, s, "MonsteraBase", Vector3.new(1.1, 1.0, 1.1), CFrame.new(0, 0.5, 0), P.LEAF_PINE_DARK, nil, true, 0, false)
	for i, a in ipairs({ 0, 90, 180, 270 }) do
		local rot = CFrame.Angles(0, math.rad(a + 25), 0)
		addBox(m, cframe, s, "Stem_" .. i, Vector3.new(0.32, 1.4, 0.32), rot * CFrame.new(0.45, 1.1, 0) * CFrame.Angles(0, 0, math.rad(-26)), P.VINE_DARK, nil, true, 0, false)
		addBox(m, cframe, s, "Paddle_" .. i, Vector3.new(1.5, 0.24, 1.7), rot * CFrame.new(1.25, 1.75, 0) * CFrame.Angles(0, 0, math.rad(-14)), if i % 2 == 0 then P.LEAF_MID else P.LEAF_PINE_DARK, nil, true, 0, false)
	end
	return m
end

local function buildPlant_MossyCloverPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Plant_MossyCloverPatch", cframe, parent)
	addBox(m, cframe, s, "CloverMatA", Vector3.new(4.2, 0.24, 3.8), CFrame.new(0, 0.12, 0), P.LEAF_MID, nil, true, 0, false)
	addBox(m, cframe, s, "CloverMatB", Vector3.new(2.8, 0.32, 2.5), CFrame.new(-0.5, 0.28, 0.3), P.LEAF_BRIGHT, nil, true, 0, false)
	addBox(m, cframe, s, "CloverSproutA", Vector3.new(0.7, 0.55, 0.7), CFrame.new(0.9, 0.42, -0.6), P.LEAF_LIME, nil, true, 0, false)
	addBox(m, cframe, s, "CloverSproutB", Vector3.new(0.55, 0.45, 0.55), CFrame.new(-1.1, 0.45, 0.7), P.FL_WHITE, nil, true, 0, false)
	addBox(m, cframe, s, "CloverPebble", Vector3.new(0.8, 0.38, 0.75), CFrame.new(1.2, 0.24, 0.8), P.STONE_MID, nil, true, 0, false)
	return m
end

-- ============================================================================
-- 4. FLOWERS (5)
-- ============================================================================

local function buildFlower_BlueVioletStalks(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Flowers", "Flower_BlueVioletStalks", cframe, parent)
	addBox(m, cframe, s, "Turf", Vector3.new(2.6, 0.2, 2.4), CFrame.new(0, 0.1, 0), P.LEAF_MID, nil, true, 0, false)
	addFlowerStalk(m, cframe, s, "BV1", -0.5, 0.2, -0.3, 1.85, P.FL_BLUE, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "BV2", 0.55, 0.2, 0.25, 1.45, P.FL_PURPLE, P.FL_WHITE)
	addFlowerStalk(m, cframe, s, "BV3", -0.1, 0.2, 0.65, 1.25, P.FL_BLUE, P.FL_WHITE)
	return m
end

local function buildFlower_RedOrangeCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Flowers", "Flower_RedOrangeCluster", cframe, parent)
	addBox(m, cframe, s, "Turf", Vector3.new(3.0, 0.2, 2.8), CFrame.new(0, 0.1, 0), P.LEAF_DEEP, nil, true, 0, false)
	addFlowerStalk(m, cframe, s, "RO1", -0.7, 0.2, 0.2, 1.5, P.FL_RED, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "RO2", 0.4, 0.2, -0.5, 1.8, P.FL_ORANGE, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "RO3", 0.8, 0.2, 0.65, 1.25, P.FL_RED, P.FL_WHITE)
	addFlowerStalk(m, cframe, s, "RO4", -0.2, 0.2, -0.8, 1.15, P.FL_ORANGE, P.FL_RED)
	return m
end

local function buildFlower_PurpleLavenderDuo(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Flowers", "Flower_PurpleLavenderDuo", cframe, parent)
	addBox(m, cframe, s, "Turf", Vector3.new(2.4, 0.2, 2.4), CFrame.new(0, 0.1, 0), P.LEAF_MID, nil, true, 0, false)
	addFlowerStalk(m, cframe, s, "PL1", -0.45, 0.2, -0.2, 1.75, P.FL_PURPLE, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "PL2", 0.55, 0.2, 0.35, 1.4, P.FL_PINK, P.FL_YELLOW)
	return m
end

local function buildFlower_SunnyWildflowerMix(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Flowers", "Flower_SunnyWildflowerMix", cframe, parent)
	addBox(m, cframe, s, "Turf", Vector3.new(3.6, 0.22, 3.4), CFrame.new(0, 0.11, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	addFlowerStalk(m, cframe, s, "SW1", -1.0, 0.22, -0.6, 1.25, P.FL_YELLOW, P.FL_ORANGE)
	addFlowerStalk(m, cframe, s, "SW2", 0.85, 0.22, -0.75, 1.5, P.FL_WHITE, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "SW3", 0.0, 0.22, 0.2, 1.65, P.FL_PINK, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "SW4", -0.65, 0.22, 0.95, 1.15, P.FL_WHITE, P.FL_YELLOW)
	addFlowerStalk(m, cframe, s, "SW5", 1.0, 0.22, 0.8, 1.35, P.FL_YELLOW, P.FL_ORANGE)
	return m
end

local function buildFlower_TropicalOrchidPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Flowers", "Flower_TropicalOrchidPatch", cframe, parent)
	addBox(m, cframe, s, "OrchidLeavesA", Vector3.new(2.2, 0.26, 0.9), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0.5, 0), P.LEAF_PINE_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "OrchidLeavesB", Vector3.new(0.9, 0.26, 2.2), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0.2, 0), P.LEAF_MID, nil, true, 0, false)
	addFlowerStalk(m, cframe, s, "Or1", -0.4, 0.25, -0.2, 1.9, P.FL_PINK, P.LOTUS_GOLD)
	addFlowerStalk(m, cframe, s, "Or2", 0.5, 0.25, 0.3, 1.5, P.FL_PURPLE, P.FL_YELLOW)
	return m
end

-- ============================================================================
-- 5. ROCKS (6)
-- ============================================================================

local function buildRock_TallMossyBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "Rock_TallMossyBoulder", cframe, parent)
	addBox(m, cframe, s, "StoneBase", Vector3.new(5.6, 2.6, 4.8), CFrame.new(0, 1.3, 0), P.STONE_DARK)
	addBox(m, cframe, s, "StoneMidL", Vector3.new(4.2, 3.2, 4.0), CFrame.new(-0.4, 3.4, 0.2), P.STONE_MID)
	addBox(m, cframe, s, "StonePeak", Vector3.new(2.8, 2.2, 2.8), CFrame.new(-0.6, 5.2, 0.1), P.STONE_LIGHT)
	addBox(m, cframe, s, "StoneStepR", Vector3.new(2.6, 2.4, 3.2), CFrame.new(1.8, 1.9, -0.4), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "TopMoss", Vector3.new(-0.6, 6.45, 0.1), 2.9, 2.9)
	addMossCap(m, cframe, s, "StepMoss", Vector3.new(1.8, 3.25, -0.4), 2.4, 2.8)
	addBox(m, cframe, s, "MossStreakA", Vector3.new(0.85, 2.4, 0.55), CFrame.new(-1.8, 3.8, 2.15), P.MOSS_DARK)
	addBox(m, cframe, s, "MossStreakB", Vector3.new(0.75, 1.8, 0.55), CFrame.new(0.6, 2.6, 2.35), P.MOSS_BRIGHT)
	return m
end

local function buildRock_MediumMossyMound(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "Rock_MediumMossyMound", cframe, parent)
	addBox(m, cframe, s, "MoundBase", Vector3.new(4.6, 1.8, 4.2), CFrame.new(0, 0.9, 0), P.STONE_DARK)
	addBox(m, cframe, s, "MoundMid", Vector3.new(3.4, 1.6, 3.2), CFrame.new(-0.2, 2.2, 0.1), P.STONE_MID)
	addBox(m, cframe, s, "MoundLedge", Vector3.new(2.0, 1.2, 2.2), CFrame.new(1.4, 1.1, -0.6), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "MoundMossTop", Vector3.new(-0.2, 3.15, 0.1), 3.3, 3.1)
	addBox(m, cframe, s, "MossDrip", Vector3.new(1.1, 1.6, 0.45), CFrame.new(-0.5, 2.0, 1.75), P.MOSS_BRIGHT)
	return m
end

local function buildRock_LowFlatMossStone(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "Rock_LowFlatMossStone", cframe, parent)
	addBox(m, cframe, s, "SlabBase", Vector3.new(4.8, 1.1, 4.0), CFrame.new(0, 0.55, 0), P.STONE_MID)
	addBox(m, cframe, s, "SlabStep", Vector3.new(3.2, 0.95, 2.8), CFrame.new(0.4, 1.35, -0.2), P.STONE_LIGHT)
	addBox(m, cframe, s, "EdgeChip", Vector3.new(1.4, 0.7, 1.5), CFrame.new(-2.1, 0.35, 1.1), P.STONE_DARK)
	addMossCap(m, cframe, s, "SlabMoss", Vector3.new(0.4, 1.96, -0.2), 3.0, 2.6)
	return m
end

local function buildRock_LayeredMonolith(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "Rock_LayeredMonolith", cframe, parent)
	-- L-shaped stacked mossy stone crag (reference Rocks bottom-right)
	addBox(m, cframe, s, "PlinthBlock", Vector3.new(4.8, 1.8, 2.8), CFrame.new(0, 0.9, 0.4), P.STONE_DARK)
	addBox(m, cframe, s, "LowerStep", Vector3.new(2.2, 2.4, 2.6), CFrame.new(-1.3, 1.2, 0.4), P.STONE_MID)
	addBox(m, cframe, s, "TowerLower", Vector3.new(2.4, 4.0, 2.6), CFrame.new(1.1, 2.8, 0.3), P.STONE_MID)
	addBox(m, cframe, s, "TowerTop", Vector3.new(2.6, 2.2, 2.8), CFrame.new(1.1, 5.4, 0.3), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "TowerMoss", Vector3.new(1.1, 6.65, 0.3), 2.5, 2.7)
	addMossCap(m, cframe, s, "StepMoss", Vector3.new(-1.3, 2.55, 0.4), 2.0, 2.3)
	addBox(m, cframe, s, "WallVineA", Vector3.new(0.55, 3.2, 0.45), CFrame.new(0.6, 4.2, 1.68), P.VINE_DARK)
	addBox(m, cframe, s, "WallVineB", Vector3.new(0.55, 2.4, 0.45), CFrame.new(1.7, 3.8, 1.68), P.VINE_BRIGHT)
	return m
end

local function buildRock_CobbleScatterCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "Rock_CobbleScatterCluster", cframe, parent)
	-- Grassy earth block + assorted cobble stone cubes (reference Rocks bottom-left)
	addBox(m, cframe, s, "EarthBlock", Vector3.new(1.8, 0.9, 1.8), CFrame.new(-1.6, 0.45, 0.4), P.SOIL_DARK)
	addBox(m, cframe, s, "EarthGrass", Vector3.new(1.9, 0.36, 1.9), CFrame.new(-1.6, 1.05, 0.4), P.MOSS_BRIGHT)
	addBox(m, cframe, s, "CobbleBig", Vector3.new(2.0, 1.35, 1.8), CFrame.new(0.6, 0.68, -0.3) * CFrame.Angles(0, 0.25, 0), P.STONE_MID)
	addBox(m, cframe, s, "CobbleSmall", Vector3.new(1.3, 0.9, 1.3), CFrame.new(1.9, 0.45, 0.9) * CFrame.Angles(0, -0.4, 0), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "CobbleMoss", Vector3.new(0.6, 1.48, -0.3), 1.4, 1.3)
	return m
end

local function buildRock_SteppedCliffOutcrop(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "Rock_SteppedCliffOutcrop", cframe, parent)
	addBox(m, cframe, s, "OutcropTier1", Vector3.new(6.4, 2.0, 4.6), CFrame.new(0, 1.0, 0), P.STONE_DARK)
	addBox(m, cframe, s, "OutcropTier2", Vector3.new(4.8, 2.4, 3.6), CFrame.new(-0.5, 2.8, -0.2), P.STONE_MID)
	addBox(m, cframe, s, "OutcropTier3", Vector3.new(3.0, 2.0, 2.6), CFrame.new(-1.0, 4.4, -0.3), P.STONE_HI)
	addMossCap(m, cframe, s, "OutcropMossA", Vector3.new(-1.0, 5.55, -0.3), 3.1, 2.7)
	addMossCap(m, cframe, s, "OutcropMossB", Vector3.new(1.4, 2.15, 0.6), 2.4, 2.4)
	addBox(m, cframe, s, "HangMoss", Vector3.new(0.65, 2.0, 0.5), CFrame.new(-0.8, 3.6, 1.55), P.MOSS_BRIGHT)
	return m
end

-- ============================================================================
-- 6. MUSHROOMS (4)
-- ============================================================================

local function addSingleShroom(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, stemH: number, stemW: number, capW: number, capCol: Color3, spotCol: Color3?)
	addBox(m, originCF, s, prefix .. "_Stem", Vector3.new(stemW, stemH, stemW), CFrame.new(pos.X, pos.Y + stemH * 0.5, pos.Z), P.SHROOM_STEM, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_CapBase", Vector3.new(capW, capW * 0.34, capW), CFrame.new(pos.X, pos.Y + stemH + capW * 0.16, pos.Z), capCol, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_CapTop", Vector3.new(capW * 0.7, capW * 0.24, capW * 0.7), CFrame.new(pos.X, pos.Y + stemH + capW * 0.42, pos.Z), capCol, nil, true, 0, false)
	if spotCol then
		addBox(m, originCF, s, prefix .. "_SpotA", Vector3.new(capW * 0.25, 0.16, capW * 0.25), CFrame.new(pos.X + capW * 0.2, pos.Y + stemH + capW * 0.42, pos.Z - capW * 0.18), spotCol, nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_SpotB", Vector3.new(capW * 0.22, 0.14, capW * 0.22), CFrame.new(pos.X - capW * 0.24, pos.Y + stemH + capW * 0.3, pos.Z + capW * 0.22), spotCol, nil, true, 0, false)
	end
end

local function buildMushroom_RedSpottedTrio(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Mushrooms", "Mushroom_RedSpottedTrio", cframe, parent)
	addBox(m, cframe, s, "MossTurf", Vector3.new(2.8, 0.22, 2.4), CFrame.new(0, 0.11, 0), P.LEAF_BRIGHT, nil, true, 0, false)
	addSingleShroom(m, cframe, s, "Tall", Vector3.new(-0.35, 0.2, 0), 1.65, 0.48, 1.55, P.FL_RED, P.FL_WHITE)
	addSingleShroom(m, cframe, s, "Med", Vector3.new(0.85, 0.2, 0.35), 1.05, 0.36, 1.12, P.FL_RED, P.FL_WHITE)
	addSingleShroom(m, cframe, s, "Mini", Vector3.new(-0.95, 0.2, -0.55), 0.7, 0.26, 0.78, P.FL_ORANGE, P.FL_WHITE)
	return m
end

local function buildMushroom_GiantRedToadstool(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Mushrooms", "Mushroom_GiantRedToadstool", cframe, parent)
	addBox(m, cframe, s, "BaseMoss", Vector3.new(3.4, 0.26, 3.2), CFrame.new(0, 0.13, 0), P.LEAF_MID, nil, true, 0, false)
	addSingleShroom(m, cframe, s, "Giant", Vector3.new(0, 0.25, 0), 2.9, 0.9, 2.8, P.FL_RED, P.FL_WHITE)
	addSingleShroom(m, cframe, s, "BabyA", Vector3.new(1.35, 0.25, 0.75), 0.95, 0.34, 0.95, P.FL_RED, P.FL_WHITE)
	return m
end

local function buildMushroom_BrownShelfCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Mushrooms", "Mushroom_BrownShelfCluster", cframe, parent)
	addBox(m, cframe, s, "MossPad", Vector3.new(2.6, 0.22, 2.4), CFrame.new(0, 0.11, 0), P.MOSS_DARK, nil, true, 0, false)
	addSingleShroom(m, cframe, s, "BrA", Vector3.new(0, 0.2, 0), 1.3, 0.44, 1.45, P.SHROOM_BROWN, P.SHROOM_TAN)
	addSingleShroom(m, cframe, s, "BrB", Vector3.new(-0.85, 0.2, 0.5), 0.95, 0.32, 1.05, P.SHROOM_TAN, nil)
	addSingleShroom(m, cframe, s, "BrC", Vector3.new(0.8, 0.2, -0.45), 0.75, 0.28, 0.85, P.SHROOM_BROWN, nil)
	return m
end

local function buildMushroom_GlowJungleShrooms(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Mushrooms", "Mushroom_GlowJungleShrooms", cframe, parent)
	addBox(m, cframe, s, "Turf", Vector3.new(2.6, 0.22, 2.4), CFrame.new(0, 0.11, 0), P.LEAF_DEEP, nil, true, 0, false)
	addSingleShroom(m, cframe, s, "GlowTall", Vector3.new(-0.2, 0.2, 0), 1.7, 0.42, 1.5, Color3.fromRGB(36, 134, 128), P.SHROOM_GLOW)
	addSingleShroom(m, cframe, s, "GlowSmall", Vector3.new(0.85, 0.2, 0.45), 1.05, 0.3, 0.95, Color3.fromRGB(48, 158, 146), P.SHROOM_GLOW)
	local gill = addBox(m, cframe, s, "GlowUnderGill", Vector3.new(1.15, 0.2, 1.15), CFrame.new(-0.2, 1.85, 0), P.SHROOM_GLOW, Enum.Material.Neon, false, 0, false)
	local pl = Instance.new("PointLight")
	pl.Name = "ShroomLight"
	pl.Color = P.SHROOM_GLOW
	pl.Range = 10
	pl.Brightness = 0.6
	pl.Shadows = false
	pl.Parent = gill
	return m
end

-- ============================================================================
-- 7. RUINS (3)
-- ============================================================================

local function buildRuin_MossyStoneArchway(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "Ruin_MossyStoneArchway", cframe, parent)

	-- Stepped plinth bases & double stone pillars matching hero archway reference
	for _, xSide in ipairs({ -5.0, 5.0 }) do
		addBox(m, cframe, s, "PlinthBot", Vector3.new(4.0, 1.3, 3.6), CFrame.new(xSide, 0.65, 0), P.STONE_DARK)
		addBox(m, cframe, s, "PlinthTop", Vector3.new(3.2, 1.2, 3.0), CFrame.new(xSide, 1.9, 0), P.STONE_MID)
		addBox(m, cframe, s, "PillarCore", Vector3.new(2.5, 6.2, 2.5), CFrame.new(xSide, 5.6, 0), P.STONE_MID)
		addBox(m, cframe, s, "PillarBrick", Vector3.new(2.7, 1.8, 2.7), CFrame.new(xSide, 4.4, 0), P.STONE_LIGHT)
		addBox(m, cframe, s, "PillarCap", Vector3.new(3.0, 1.2, 3.0), CFrame.new(xSide, 8.8, 0), P.STONE_LIGHT)
		-- Moss patches & base rubble stones
		addMossCap(m, cframe, s, "BaseMoss", Vector3.new(xSide * 0.85, 2.65, 0.8), 2.1, 1.8)
		addBox(m, cframe, s, "RubbleStone", Vector3.new(1.5, 0.9, 1.4), CFrame.new(xSide + (xSide > 0 and 2.1 or -2.1), 0.45, 1.1) * CFrame.Angles(0, 0.4, 0), P.STONE_LIGHT)
	end

	-- Arch lintel + stepped battlements + overhanging moss + hanging vines
	addBox(m, cframe, s, "ArchLintel", Vector3.new(13.6, 2.2, 2.8), CFrame.new(0, 10.2, 0), P.STONE_MID)
	addBox(m, cframe, s, "ArchStepCrown", Vector3.new(10.8, 1.3, 2.4), CFrame.new(-0.3, 11.7, 0), P.STONE_LIGHT)
	addBox(m, cframe, s, "ArchTopMerlon", Vector3.new(4.8, 1.1, 2.2), CFrame.new(0.8, 12.7, 0), P.STONE_HI)
	addMossCap(m, cframe, s, "LintelMossL", Vector3.new(-2.8, 12.45, 0), 4.6, 2.5)
	addMossCap(m, cframe, s, "LintelMossR", Vector3.new(2.2, 13.35, 0), 3.8, 2.3)

	-- Hanging vines draped from archway
	addHangingVine(m, cframe, s, "ArchVineA", Vector3.new(-1.8, 9.2, 1.25), 3.2)
	addHangingVine(m, cframe, s, "ArchVineB", Vector3.new(2.1, 9.2, -1.2), 2.8)
	addHangingVine(m, cframe, s, "ArchVineC", Vector3.new(5.8, 8.6, 1.3), 4.2)

	-- Two warm amber hanging lanterns inside the archway opening
	for idx, lx in ipairs({ -3.1, 3.1 }) do
		addBox(m, cframe, s, "HookArm_" .. idx, Vector3.new(1.4, 0.35, 0.35), CFrame.new(lx * 1.05, 8.2, 0.5), P.BARK_DARK)
		addLanternUnit(m, cframe, s, "ArchLantern_" .. idx, Vector3.new(lx, 7.1, 0.5), 14, 0.72)
	end
	return m
end

local function buildRuin_BrokenArchWall(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "Ruin_BrokenArchWall", cframe, parent)

	-- Asymmetric half-collapsed mossy stone archway (reference Ruins #1)
	addBox(m, cframe, s, "BaseWallL", Vector3.new(4.2, 1.4, 3.0), CFrame.new(-3.8, 0.7, 0), P.STONE_DARK)
	addBox(m, cframe, s, "TallPier", Vector3.new(2.4, 6.8, 2.4), CFrame.new(-3.8, 4.8, 0), P.STONE_MID)
	addBox(m, cframe, s, "PartialLintel", Vector3.new(6.8, 1.8, 2.4), CFrame.new(-1.6, 8.8, 0), P.STONE_LIGHT)
	addBox(m, cframe, s, "BrokenPierR", Vector3.new(2.5, 4.4, 2.5), CFrame.new(3.6, 2.2, 0), P.STONE_MID)
	addBox(m, cframe, s, "CollapsedStepR", Vector3.new(1.9, 1.5, 2.0), CFrame.new(3.4, 5.1, 0.1), P.STONE_DARK)
	addBox(m, cframe, s, "FallenBrickA", Vector3.new(2.2, 1.1, 1.8), CFrame.new(0.8, 0.55, 0.9) * CFrame.Angles(0, 0.35, 0), P.STONE_LIGHT)
	addBox(m, cframe, s, "FallenBrickB", Vector3.new(1.5, 0.9, 1.4), CFrame.new(-1.2, 0.45, -0.7) * CFrame.Angles(0, -0.4, 0), P.STONE_MID)

	addMossCap(m, cframe, s, "RuinMossA", Vector3.new(-2.0, 9.85, 0), 5.6, 2.4)
	addMossCap(m, cframe, s, "RuinMossB", Vector3.new(3.4, 6.0, 0.1), 2.0, 2.0)
	addHangingVine(m, cframe, s, "BrokenVineA", Vector3.new(0.4, 8.1, 1.25), 3.4)
	addHangingVine(m, cframe, s, "BrokenVineB", Vector3.new(-2.6, 8.0, -1.2), 2.8)
	return m
end

local function buildRuin_PillarAndPawBanner(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "Ruin_PillarAndPawBanner", cframe, parent)

	-- Carved mossy stone column on left
	addBox(m, cframe, s, "ColBase", Vector3.new(3.0, 1.3, 3.0), CFrame.new(-2.8, 0.65, 0), P.STONE_DARK)
	addBox(m, cframe, s, "ColShaft", Vector3.new(2.0, 6.8, 2.0), CFrame.new(-2.8, 4.7, 0), P.STONE_MID)
	addBox(m, cframe, s, "ColCap", Vector3.new(2.8, 1.2, 2.8), CFrame.new(-2.8, 8.5, 0), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "ColMoss", Vector3.new(-2.8, 9.25, 0), 2.6, 2.6)

	-- Rustic timber banner post + green paw-print voxel banner + attached glowing lantern post
	addBox(m, cframe, s, "TimberFoot", Vector3.new(2.0, 0.8, 2.0), CFrame.new(1.8, 0.4, 0), P.STONE_MID)
	addBox(m, cframe, s, "TimberMast", Vector3.new(0.9, 9.2, 0.9), CFrame.new(1.8, 5.0, 0), P.BARK_MID)
	addBox(m, cframe, s, "BannerArm", Vector3.new(4.2, 0.65, 0.65), CFrame.new(0.3, 8.8, 0), P.BARK_DARK)

	-- Green cloth banner with voxel white/cream paw print
	addBox(m, cframe, s, "BannerCloth", Vector3.new(2.6, 4.2, 0.24), CFrame.new(-0.1, 6.2, 0.1), P.LEAF_MID)
	addBox(m, cframe, s, "BannerTail", Vector3.new(1.5, 0.8, 0.24), CFrame.new(-0.1, 3.7, 0.1), P.LEAF_DEEP)
	addBox(m, cframe, s, "BannerTrim", Vector3.new(2.8, 0.35, 0.34), CFrame.new(-0.1, 8.2, 0.1), P.WOOD_CUT)
	local pawCol = Color3.fromRGB(246, 246, 232)
	addBox(m, cframe, s, "PawMainPad", Vector3.new(1.05, 0.85, 0.34), CFrame.new(-0.1, 5.8, 0.1), pawCol, nil, true, 0, false)
	for idx, toe in ipairs({
		Vector3.new(-0.68, 6.55, 0.1),
		Vector3.new(-0.26, 6.82, 0.1),
		Vector3.new(0.22, 6.82, 0.1),
		Vector3.new(0.62, 6.55, 0.1),
	}) do
		addBox(m, cframe, s, "PawToe_" .. idx, Vector3.new(0.32, 0.42, 0.34), CFrame.new(toe), pawCol, nil, true, 0, false)
	end

	-- Hanging glowing lantern beside mast
	addBox(m, cframe, s, "LanternSideArm", Vector3.new(1.6, 0.45, 0.45), CFrame.new(2.8, 8.0, 0), P.BARK_DARK)
	addLanternUnit(m, cframe, s, "BannerLantern", Vector3.new(3.4, 6.85, 0), 18, 1.05)
	return m
end

-- ============================================================================
-- 8. DECORATIONS (10: 4 Giant Tree Roots + 3 Fallen Logs + 3 Wooden Lanterns)
-- ============================================================================

local function buildTreeRoot_GiantArch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "TreeRoot_GiantArch", cframe, parent)
	addBox(m, cframe, s, "RootFootL", Vector3.new(1.8, 2.4, 1.8), CFrame.new(-2.8, 1.2, 0), P.BARK_DARK)
	addBox(m, cframe, s, "RootStepL", Vector3.new(2.4, 1.6, 1.6), CFrame.new(-1.6, 2.8, 0) * CFrame.Angles(0, 0, math.rad(20)), P.BARK_MID)
	addBox(m, cframe, s, "RootCrest", Vector3.new(2.8, 1.5, 1.5), CFrame.new(0, 3.6, 0), P.BARK_LIGHT)
	addBox(m, cframe, s, "RootStepR", Vector3.new(2.4, 1.6, 1.6), CFrame.new(1.6, 2.7, 0) * CFrame.Angles(0, 0, math.rad(-22)), P.BARK_MID)
	addBox(m, cframe, s, "RootFootR", Vector3.new(2.0, 2.2, 1.9), CFrame.new(2.9, 1.1, 0), P.BARK_DARK)
	addMossCap(m, cframe, s, "CrestMoss", Vector3.new(0, 4.48, 0), 2.5, 1.5)
	addHangingVine(m, cframe, s, "RootVine", Vector3.new(-0.3, 3.1, 0.72), 2.1)
	return m
end

local function buildTreeRoot_TwistedSprawl(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "TreeRoot_TwistedSprawl", cframe, parent)
	addBox(m, cframe, s, "HubKnot", Vector3.new(2.6, 2.0, 2.6), CFrame.new(0, 1.0, 0), P.BARK_MID)
	for i, prong in ipairs({
		{ pos = Vector3.new(-2.4, 0.65, 0.6), yaw = 22, len = 3.2 },
		{ pos = Vector3.new(2.3, 0.55, -0.5), yaw = -18, len = 3.0 },
		{ pos = Vector3.new(0.4, 0.5, 2.2), yaw = 82, len = 2.6 },
	}) do
		addBox(m, cframe, s, "Prong_" .. i, Vector3.new(prong.len, 1.15, 1.25), CFrame.new(prong.pos) * CFrame.Angles(0, math.rad(prong.yaw), 0), P.BARK_DARK)
		addMossCap(m, cframe, s, "ProngMoss_" .. i, Vector3.new(prong.pos.X * 0.75, 1.32, prong.pos.Z * 0.75), 1.4, 1.2)
	end
	addBox(m, cframe, s, "ClutchedStone", Vector3.new(1.8, 1.1, 1.6), CFrame.new(-1.3, 0.55, -1.2), P.STONE_MID)
	return m
end

local function buildTreeRoot_MossyButtress(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "TreeRoot_MossyButtress", cframe, parent)
	addBox(m, cframe, s, "ButtressRear", Vector3.new(2.2, 4.4, 2.2), CFrame.new(-1.4, 2.2, 0), P.BARK_DARK)
	addBox(m, cframe, s, "ButtressMid", Vector3.new(2.8, 2.8, 1.8), CFrame.new(0.3, 1.4, 0), P.BARK_MID)
	addBox(m, cframe, s, "ButtressToe", Vector3.new(2.6, 1.3, 1.6), CFrame.new(2.0, 0.65, 0.1), P.BARK_LIGHT)
	addMossCap(m, cframe, s, "MossBlanketA", Vector3.new(-1.4, 4.55, 0), 2.1, 2.1)
	addMossCap(m, cframe, s, "MossBlanketB", Vector3.new(0.4, 2.95, 0), 2.4, 1.7)
	addBox(m, cframe, s, "ShelfShroom", Vector3.new(0.75, 0.24, 0.65), CFrame.new(-0.3, 2.2, 1.0), P.SHROOM_TAN)
	return m
end

local function buildTreeRoot_ExposedKnuckle(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "TreeRoot_ExposedKnuckle", cframe, parent)
	addBox(m, cframe, s, "KnuckleA", Vector3.new(2.4, 1.2, 1.4), CFrame.new(-1.1, 0.7, 0.2) * CFrame.Angles(0, 0.2, math.rad(14)), P.BARK_DARK)
	addBox(m, cframe, s, "KnuckleB", Vector3.new(2.2, 1.15, 1.3), CFrame.new(0.8, 1.1, -0.2) * CFrame.Angles(0, -0.25, math.rad(-16)), P.BARK_MID)
	addBox(m, cframe, s, "KnuckleC", Vector3.new(1.8, 0.85, 1.1), CFrame.new(2.2, 0.45, -0.5) * CFrame.Angles(0, -0.35, 0), P.BARK_LIGHT)
	addMossCap(m, cframe, s, "KnuckleMoss", Vector3.new(0.5, 1.78, -0.15), 1.8, 1.2)
	addBox(m, cframe, s, "SproutShoot", Vector3.new(0.45, 0.9, 0.45), CFrame.new(-0.4, 1.65, 0.3), P.LEAF_BRIGHT)
	return m
end

local function buildFallenLog_HollowMossy(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "FallenLog_HollowMossy", cframe, parent)
	addBox(m, cframe, s, "LogBody", Vector3.new(7.4, 2.1, 2.2), CFrame.new(0, 1.05, 0), P.BARK_MID)
	addBox(m, cframe, s, "LogBarkRib", Vector3.new(5.6, 0.45, 2.45), CFrame.new(-0.4, 0.55, 0), P.BARK_DARK)
	addBox(m, cframe, s, "CutRingL", Vector3.new(0.24, 1.55, 1.65), CFrame.new(-3.68, 1.05, 0), P.WOOD_CUT)
	addBox(m, cframe, s, "HollowL", Vector3.new(0.28, 1.05, 1.15), CFrame.new(-3.72, 1.05, 0), P.WOOD_HOLLOW)
	addBox(m, cframe, s, "CutRingR", Vector3.new(0.24, 1.55, 1.65), CFrame.new(3.68, 1.05, 0), P.WOOD_CUT)
	addBox(m, cframe, s, "HollowR", Vector3.new(0.28, 1.05, 1.15), CFrame.new(3.72, 1.05, 0), P.WOOD_HOLLOW)
	addMossCap(m, cframe, s, "LogMossTop", Vector3.new(-0.6, 2.22, 0), 4.4, 1.8)
	addBox(m, cframe, s, "VineWrapA", Vector3.new(0.55, 1.5, 2.48), CFrame.new(1.2, 1.35, 0), P.VINE_BRIGHT)
	addBox(m, cframe, s, "VineWrapB", Vector3.new(0.45, 1.3, 2.42), CFrame.new(-2.1, 1.25, 0), P.VINE_DARK)
	addSingleShroom(m, cframe, s, "LogShroom", Vector3.new(1.8, 2.15, 0.3), 0.55, 0.24, 0.65, P.FL_RED, P.FL_WHITE)
	return m
end

local function buildFallenLog_SplitTimber(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "FallenLog_SplitTimber", cframe, parent)
	addBox(m, cframe, s, "LogSectionA", Vector3.new(4.2, 1.8, 2.0), CFrame.new(-1.8, 0.9, 0.15) * CFrame.Angles(0, 0.12, 0), P.BARK_MID)
	addBox(m, cframe, s, "CutFaceA", Vector3.new(0.22, 1.35, 1.55), CFrame.new(0.28, 0.9, 0.4) * CFrame.Angles(0, 0.12, 0), P.WOOD_CUT)
	addBox(m, cframe, s, "LogSectionB", Vector3.new(3.2, 1.65, 1.85), CFrame.new(2.4, 0.82, -0.35) * CFrame.Angles(0, -0.22, 0), P.BARK_DARK)
	addBox(m, cframe, s, "CutFaceB", Vector3.new(0.22, 1.2, 1.4), CFrame.new(0.85, 0.82, -0.7) * CFrame.Angles(0, -0.22, 0), P.WOOD_CUT)
	addMossCap(m, cframe, s, "SplitMoss", Vector3.new(-2.0, 1.92, 0.15), 2.8, 1.6)
	addSingleShroom(m, cframe, s, "SplitShroomA", Vector3.new(2.6, 1.65, -0.3), 0.6, 0.24, 0.72, P.FL_RED, P.FL_WHITE)
	addSingleShroom(m, cframe, s, "SplitShroomB", Vector3.new(0.5, 0.0, 0.9), 0.55, 0.22, 0.64, P.SHROOM_BROWN, nil)
	return m
end

local function buildFallenLog_VineBridge(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "FallenLog_VineBridge", cframe, parent)
	addBox(m, cframe, s, "RestStoneL", Vector3.new(2.2, 1.2, 2.4), CFrame.new(-3.2, 0.6, 0), P.STONE_MID)
	addBox(m, cframe, s, "RestStoneR", Vector3.new(2.0, 1.0, 2.2), CFrame.new(3.2, 0.5, 0), P.STONE_DARK)
	addBox(m, cframe, s, "SpanTrunk", Vector3.new(8.2, 1.7, 1.9), CFrame.new(0, 1.55, 0), P.BARK_LIGHT)
	addBox(m, cframe, s, "CutEndL", Vector3.new(0.22, 1.25, 1.4), CFrame.new(-4.08, 1.55, 0), P.WOOD_CUT)
	addBox(m, cframe, s, "CutEndR", Vector3.new(0.22, 1.25, 1.4), CFrame.new(4.08, 1.55, 0), P.WOOD_CUT)
	addMossCap(m, cframe, s, "SpanMossA", Vector3.new(-1.2, 2.52, 0), 3.6, 1.6)
	addMossCap(m, cframe, s, "SpanMossB", Vector3.new(2.0, 2.52, 0), 2.2, 1.4)
	addHangingVine(m, cframe, s, "BridgeVine", Vector3.new(0.2, 1.4, 0.98), 1.4)
	return m
end

local function buildLantern_OverhangArmPost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "Lantern_OverhangArmPost", cframe, parent)
	addBox(m, cframe, s, "GrassyMound", Vector3.new(2.4, 0.65, 2.4), CFrame.new(0, 0.32, 0), P.STONE_MID)
	addMossCap(m, cframe, s, "MoundMoss", Vector3.new(-0.3, 0.72, 0.2), 2.1, 2.1)
	addBox(m, cframe, s, "PostShaft", Vector3.new(0.9, 6.4, 0.9), CFrame.new(-0.5, 3.6, 0), P.BARK_MID)
	addBox(m, cframe, s, "TopArm", Vector3.new(2.8, 0.65, 0.75), CFrame.new(0.55, 6.5, 0), P.BARK_DARK)
	addBox(m, cframe, s, "Brace", Vector3.new(1.5, 0.45, 0.5), CFrame.new(0.2, 5.5, 0) * CFrame.Angles(0, 0, math.rad(40)), P.BARK_LIGHT)
	addBox(m, cframe, s, "Chain", Vector3.new(0.22, 0.7, 0.22), CFrame.new(1.5, 5.9, 0), P.LANTERN_IRON)
	addLanternUnit(m, cframe, s, "HangLantern", Vector3.new(1.5, 4.9, 0), 18, 1.1)
	return m
end

local function buildLantern_StandingPathPost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "Lantern_StandingPathPost", cframe, parent)
	addBox(m, cframe, s, "StoneFoot", Vector3.new(2.0, 1.1, 2.0), CFrame.new(0, 0.55, 0), P.STONE_MID)
	addMossCap(m, cframe, s, "FootMoss", Vector3.new(0.2, 1.18, -0.2), 1.6, 1.6)
	addBox(m, cframe, s, "PostShaft", Vector3.new(0.88, 3.8, 0.88), CFrame.new(0, 2.8, 0), P.BARK_MID)
	addBox(m, cframe, s, "Collar", Vector3.new(1.4, 0.35, 1.4), CFrame.new(0, 4.75, 0), P.BARK_DARK)
	addLanternUnit(m, cframe, s, "StandLantern", Vector3.new(0, 5.55, 0), 18, 1.1)
	return m
end

local function buildLantern_FencePostLamp(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "Lantern_FencePostLamp", cframe, parent)
	addBox(m, cframe, s, "CornerFoot", Vector3.new(1.8, 0.85, 1.8), CFrame.new(0, 0.42, 0), P.STONE_MID)
	addBox(m, cframe, s, "LanternPost", Vector3.new(0.9, 4.3, 0.9), CFrame.new(0, 2.55, 0), P.BARK_DARK)
	addLanternUnit(m, cframe, s, "CornerLantern", Vector3.new(0, 5.2, 0), 18, 1.1)

	-- Rustic fence rails on +Z and -Z along local Z (when rotated 0 or PI, aligns along X or road edge cleanly)
	for _, zOff in ipairs({ -3.4, 3.4 }) do
		addBox(m, cframe, s, "FencePost", Vector3.new(0.65, 2.6, 0.65), CFrame.new(0, 1.3, zOff), P.BARK_DARK)
	end
	addBox(m, cframe, s, "RailUpper", Vector3.new(0.38, 0.38, 7.2), CFrame.new(0, 2.1, 0), P.BARK_LIGHT)
	addBox(m, cframe, s, "RailLower", Vector3.new(0.38, 0.38, 7.2), CFrame.new(0, 1.15, 0), P.BARK_MID)
	addMossCap(m, cframe, s, "FenceBaseMoss", Vector3.new(0.5, 0.25, 1.4), 1.6, 2.2)
	return m
end

-- ============================================================================
-- 9. WATER FEATURES (4: 2 Ponds with Lily Pads + 2 Animated Mini Waterfalls)
-- ============================================================================

local function buildWaterFeature_LilyPadPond(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "WaterFeature_LilyPadPond", cframe, parent)

	addBox(m, cframe, s, "MossRim", Vector3.new(11.6, 0.32, 9.6), CFrame.new(0, 0.16, 0), P.LEAF_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(9.2, 0.2, 7.2), CFrame.new(0, 0.14, 0), P.WATER_BED, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "WaterSurface", Vector3.new(9.0, 0.34, 7.0), CFrame.new(0, 0.38, 0), P.WATER_POOL, Enum.Material.Glass, false, 0.24, false)

	-- Shoreline mossy stones
	for i, st in ipairs({
		{ pos = Vector3.new(-4.8, 0.65, -2.4), sz = Vector3.new(2.2, 1.1, 2.4) },
		{ pos = Vector3.new(4.9, 0.55, 2.1), sz = Vector3.new(2.0, 0.95, 2.2) },
		{ pos = Vector3.new(-3.8, 0.5, 3.6), sz = Vector3.new(2.4, 0.85, 1.6) },
		{ pos = Vector3.new(3.6, 0.7, -3.5), sz = Vector3.new(2.6, 1.2, 1.8) },
	}) do
		addBox(m, cframe, s, "RimStone_" .. i, st.sz, CFrame.new(st.pos), if i % 2 == 0 then P.STONE_MID else P.STONE_LIGHT, nil, true, 0, false)
		addMossCap(m, cframe, s, "RimMoss_" .. i, Vector3.new(st.pos.X, st.pos.Y + st.sz.Y * 0.5 + 0.12, st.pos.Z), st.sz.X * 0.8, st.sz.Z * 0.8)
	end

	buildLilyPad(m, cframe, s, "Lily1", Vector3.new(-1.8, 0.6, -0.8), 1.65, 14, true, P.LOTUS_PINK)
	buildLilyPad(m, cframe, s, "Lily2", Vector3.new(2.1, 0.6, 1.2), 1.45, -25, false)
	buildLilyPad(m, cframe, s, "Lily3", Vector3.new(0.8, 0.6, -1.9), 1.25, 36, false)
	addBox(m, cframe, s, "ShoreReed", Vector3.new(0.32, 1.9, 0.32), CFrame.new(-4.2, 1.1, -0.2), P.LEAF_BRIGHT, nil, true, 0, false)
	return m
end

local function buildWaterFeature_StoneLotusPool(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "WaterFeature_StoneLotusPool", cframe, parent)

	addBox(m, cframe, s, "PoolOuterTurf", Vector3.new(13.2, 0.3, 11.0), CFrame.new(0, 0.15, 0), P.MOSS_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(10.6, 0.22, 8.6), CFrame.new(0, 0.16, 0), P.WATER_BED, Enum.Material.SmoothPlastic, false, 0, false)
	local water = addBox(m, cframe, s, "PoolWater", Vector3.new(10.4, 0.36, 8.4), CFrame.new(0, 0.38, 0), P.WATER_POOL, Enum.Material.Glass, false, 0.22, false)
	addFireflies(water, 3)

	-- Stepped rim boulders + stepping stone inside pool
	for i, st in ipairs({
		{ pos = Vector3.new(-5.4, 0.8, 0.2), sz = Vector3.new(2.4, 1.4, 3.2) },
		{ pos = Vector3.new(5.2, 0.75, -1.6), sz = Vector3.new(2.4, 1.3, 3.0) },
		{ pos = Vector3.new(0.5, 0.55, -4.4), sz = Vector3.new(4.2, 0.9, 1.8) },
		{ pos = Vector3.new(-1.8, 0.52, 4.3), sz = Vector3.new(3.6, 0.85, 1.6) },
	}) do
		addBox(m, cframe, s, "PoolBoulder_" .. i, st.sz, CFrame.new(st.pos), P.STONE_MID, nil, true, 0, false)
		addMossCap(m, cframe, s, "PoolMoss_" .. i, Vector3.new(st.pos.X, st.pos.Y + st.sz.Y * 0.5 + 0.14, st.pos.Z), st.sz.X * 0.75, st.sz.Z * 0.75)
	end
	addBox(m, cframe, s, "SteppingStone", Vector3.new(2.0, 0.65, 1.8), CFrame.new(2.4, 0.35, 1.8) * CFrame.Angles(0, 0.3, 0), P.STONE_LIGHT, nil, true, 0, false)

	buildLilyPad(m, cframe, s, "LotusLilyA", Vector3.new(-1.8, 0.6, -1.2), 1.8, 22, true, P.LOTUS_PINK)
	buildLilyPad(m, cframe, s, "LotusLilyB", Vector3.new(1.5, 0.6, -1.4), 1.5, -16, true, P.FL_WHITE)
	buildLilyPad(m, cframe, s, "LilyC", Vector3.new(-2.4, 0.6, 1.6), 1.45, 40, false)
	buildLilyPad(m, cframe, s, "LilyD", Vector3.new(0.2, 0.6, 1.9), 1.35, -35, false)
	return m
end

local function addMiniWaterfallParticleEmitters(m: Model, originCF: CFrame, s: number, splashPos: Vector3)
	local splashAnchor = addBox(m, originCF, s, "SplashEmitterAnchor", Vector3.new(2.6, 0.3, 1.2), CFrame.new(splashPos), P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 1, false)
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "SplashDroplets"
	spray.Color = ColorSequence.new(P.WATER_FOAM, P.WATER_FALL)
	spray.Rate = 10
	spray.Lifetime = NumberRange.new(0.45, 0.85)
	spray.Speed = NumberRange.new(2.5, 5.0)
	spray.SpreadAngle = Vector2.new(55, 55)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28 * s), NumberSequenceKeypoint.new(1, 0.06 * s) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	spray.Parent = splashAnchor

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "WaterfallMist"
	mist.Color = ColorSequence.new(Color3.fromRGB(220, 246, 255), P.WATER_FOAM)
	mist.Rate = 5
	mist.Lifetime = NumberRange.new(1.0, 1.8)
	mist.Speed = NumberRange.new(0.8, 2.2)
	mist.SpreadAngle = Vector2.new(65, 65)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * s), NumberSequenceKeypoint.new(1, 2.2 * s) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	mist.Parent = splashAnchor
end

local function buildWaterFeature_MiniWaterfallPond(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "WaterFeature_MiniWaterfallPond", cframe, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)

	-- Stepped mossy stone cliff backdrop + lush lily pond in front (+Z faces the viewer/road)
	addBox(m, cframe, s, "PondTurfBase", Vector3.new(12.2, 0.34, 12.6), CFrame.new(0, 0.17, 0.4), P.LEAF_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(8.8, 0.2, 6.8), CFrame.new(0, 0.18, 2.0), P.WATER_BED, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "PondWater", Vector3.new(8.6, 0.36, 6.6), CFrame.new(0, 0.42, 2.0), P.WATER_POOL, Enum.Material.Glass, false, 0.24, false)

	-- Rear stepped mossy cliff block holding the cascade source
	addBox(m, cframe, s, "CliffBlockL", Vector3.new(3.4, 5.4, 3.8), CFrame.new(-2.8, 2.7, -3.2), P.STONE_MID)
	addBox(m, cframe, s, "CliffBlockR", Vector3.new(3.2, 4.8, 3.6), CFrame.new(2.7, 2.4, -3.2), P.STONE_DARK)
	addBox(m, cframe, s, "CliffCrestBack", Vector3.new(4.2, 4.9, 2.8), CFrame.new(0, 2.45, -3.8), P.STONE_LIGHT)
	addBox(m, cframe, s, "CliffUpperSpire", Vector3.new(2.8, 2.0, 2.6), CFrame.new(-2.8, 6.2, -3.4), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "CliffMossL", Vector3.new(-2.8, 7.35, -3.4), 2.8, 2.6)
	addMossCap(m, cframe, s, "CliffMossR", Vector3.new(2.7, 4.95, -3.2), 3.0, 3.4)
	addBox(m, cframe, s, "CliffVineL", Vector3.new(0.55, 2.6, 0.45), CFrame.new(-3.2, 4.2, -1.2), P.VINE_BRIGHT)

	-- Pond perimeter mossy rocks & lily pads + lotus
	for i, st in ipairs({
		{ pos = Vector3.new(-4.8, 0.65, 1.8), sz = Vector3.new(2.0, 1.1, 2.6) },
		{ pos = Vector3.new(4.8, 0.7, 2.2), sz = Vector3.new(2.0, 1.2, 2.8) },
		{ pos = Vector3.new(-2.6, 0.45, 5.4), sz = Vector3.new(2.6, 0.8, 1.5) },
		{ pos = Vector3.new(2.4, 0.5, 5.3), sz = Vector3.new(2.2, 0.9, 1.4) },
	}) do
		addBox(m, cframe, s, "PondRock_" .. i, st.sz, CFrame.new(st.pos), P.STONE_MID, nil, true, 0, false)
		addMossCap(m, cframe, s, "PondMoss_" .. i, Vector3.new(st.pos.X, st.pos.Y + st.sz.Y * 0.5 + 0.12, st.pos.Z), st.sz.X * 0.75, st.sz.Z * 0.75)
	end
	buildLilyPad(m, cframe, s, "LilyPink", Vector3.new(-1.5, 0.64, 2.4), 1.65, 16, true, P.LOTUS_PINK)
	buildLilyPad(m, cframe, s, "LilySide", Vector3.new(1.8, 0.64, 3.0), 1.45, -24, false)

	-- Static crest & vertical translucent waterfall core
	addBox(m, cframe, s, "WaterfallCrestPool", Vector3.new(2.8, 0.35, 2.2), CFrame.new(0, 5.05, -2.7), P.WATER_FALL, Enum.Material.Glass, false, 0.25, false)
	addBox(m, cframe, s, "WaterfallCore", Vector3.new(2.6, 4.5, 0.55), CFrame.new(0, 2.85, -1.75), P.WATER_FALL, Enum.Material.Glass, false, 0.34, false)
	addBox(m, cframe, s, "SplashFoamL", Vector3.new(1.4, 0.42, 1.1), CFrame.new(-0.9, 0.62, -1.0), P.WATER_FOAM, nil, true, 0.15, false)
	addBox(m, cframe, s, "SplashFoamR", Vector3.new(1.2, 0.38, 1.0), CFrame.new(0.85, 0.60, -1.1), P.WATER_FOAM, nil, true, 0.15, false)

	-- Reusable animated water segments driven smoothly by FloatingIslandWaterfallController
	for i = 1, 5 do
		local lx = ((i % 3) - 1) * 0.52
		local w = if i % 2 == 0 then 1.05 else 1.35
		local seg = addBox(m, cframe, s, "WaterSeg_" .. i, Vector3.new(w, 1.15, 0.34), CFrame.new(lx, 2.8, -1.52), P.WATER_FALL, Enum.Material.Glass, false, 0.22, false)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", lx)
		seg:SetAttribute("LocalZ", -1.52)
		seg:SetAttribute("StartVal", 4.9)
		seg:SetAttribute("EndVal", 0.72)
		seg:SetAttribute("Speed", 0.58 + (i % 3) * 0.05)
		seg:SetAttribute("Phase", (i - 1) / 5)
		seg:SetAttribute("BaseTransparency", 0.22)
	end

	for i = 1, 2 do
		local crestSeg = addBox(m, cframe, s, "CrestSeg_" .. i, Vector3.new(1.8, 0.24, 0.85), CFrame.new(0, 5.18, -2.5), P.WATER_FOAM, Enum.Material.Glass, false, 0.28, false)
		crestSeg:SetAttribute("FlowAxis", "Forward")
		crestSeg:SetAttribute("LocalX", (i == 1) and -0.3 or 0.3)
		crestSeg:SetAttribute("LocalY", 5.18)
		crestSeg:SetAttribute("StartVal", -3.4)
		crestSeg:SetAttribute("EndVal", -1.8)
		crestSeg:SetAttribute("Speed", 0.62)
		crestSeg:SetAttribute("Phase", (i - 1) * 0.5)
		crestSeg:SetAttribute("BaseTransparency", 0.28)
	end

	for i = 1, 3 do
		local lx = (i - 2) * 0.68
		local drop = addBox(m, cframe, s, "Droplet_" .. i, Vector3.new(0.28, 0.32, 0.28), CFrame.new(lx, 3.0, -1.35), P.WATER_FOAM, Enum.Material.Glass, false, 0.2, false)
		drop:SetAttribute("AnimKind", "Droplet")
		drop:SetAttribute("LocalX", lx)
		drop:SetAttribute("LocalZ", -1.35)
		drop:SetAttribute("StartY", 4.85)
		drop:SetAttribute("EndY", 0.6)
		drop:SetAttribute("OutArcZ", 0.75)
		drop:SetAttribute("Speed", 0.68 + i * 0.06)
		drop:SetAttribute("Phase", (i - 1) / 3)
		drop:SetAttribute("BaseTransparency", 0.2)
	end

	for i = 1, 2 do
		local ripCF = CFrame.new(0, 0.58, -0.55)
		local rip = addBox(m, cframe, s, "RippleRing_" .. i, Vector3.new(2.5, 0.08, 2.0), ripCF, P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 0.45, false)
		rip:SetAttribute("AnimKind", "RippleRing")
		rip:SetAttribute("BaseLocalCF", ripCF)
		rip:SetAttribute("Phase", (i - 1) * 0.5)
		rip:SetAttribute("Speed", 0.58)
	end

	addMiniWaterfallParticleEmitters(m, cframe, s, Vector3.new(0, 0.65, -0.95))
	return m
end

local function buildWaterFeature_CascadeRockBasin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "WaterFeature_CascadeRockBasin", cframe, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "BasinTurf", Vector3.new(11.4, 0.32, 11.4), CFrame.new(0, 0.16, 0.4), P.MOSS_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(8.0, 0.2, 6.2), CFrame.new(0, 0.18, 1.8), P.WATER_BED, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "PoolWater", Vector3.new(7.8, 0.34, 6.0), CFrame.new(0, 0.4, 1.8), P.WATER_POOL, Enum.Material.Glass, false, 0.22, false)

	-- Twin-stepped stone cascade crag
	addBox(m, cframe, s, "TopRock", Vector3.new(4.2, 6.2, 3.0), CFrame.new(-0.2, 3.1, -3.4), P.STONE_MID)
	addBox(m, cframe, s, "MidStepLedge", Vector3.new(5.6, 3.0, 2.2), CFrame.new(0.2, 1.5, -2.0), P.STONE_DARK)
	addBox(m, cframe, s, "FlankBoulderL", Vector3.new(2.4, 2.4, 2.8), CFrame.new(-3.8, 1.2, -1.6), P.STONE_LIGHT)
	addBox(m, cframe, s, "FlankBoulderR", Vector3.new(2.2, 2.2, 2.8), CFrame.new(3.8, 1.1, -1.2), P.STONE_MID)
	addMossCap(m, cframe, s, "TopRockMoss", Vector3.new(-0.2, 6.35, -3.4), 3.8, 2.7)
	addMossCap(m, cframe, s, "LedgeMoss", Vector3.new(2.2, 3.12, -2.0), 1.8, 2.0)

	-- Twin water streams down upper crag + mid step
	addBox(m, cframe, s, "UpperFall", Vector3.new(1.8, 3.2, 0.45), CFrame.new(-0.2, 4.6, -1.85), P.WATER_FALL, Enum.Material.Glass, false, 0.32, false)
	addBox(m, cframe, s, "LowerFall", Vector3.new(2.6, 2.6, 0.48), CFrame.new(0.1, 1.85, -0.82), P.WATER_FALL, Enum.Material.Glass, false, 0.32, false)
	addBox(m, cframe, s, "SplashFoam", Vector3.new(2.8, 0.4, 1.1), CFrame.new(0.1, 0.62, -0.25), P.WATER_FOAM, nil, true, 0.15, false)

	for i = 1, 3 do
		local lx = -0.5 + (i - 1) * 0.45
		local seg = addBox(m, cframe, s, "UpperSeg_" .. i, Vector3.new(0.95, 0.95, 0.32), CFrame.new(lx, 4.6, -1.62), P.WATER_FALL, Enum.Material.Glass, false, 0.2, false)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", lx)
		seg:SetAttribute("LocalZ", -1.62)
		seg:SetAttribute("StartVal", 6.0)
		seg:SetAttribute("EndVal", 3.1)
		seg:SetAttribute("Speed", 0.72 + i * 0.04)
		seg:SetAttribute("Phase", (i - 1) / 3)
		seg:SetAttribute("BaseTransparency", 0.2)
	end
	for i = 1, 3 do
		local lx = -0.6 + (i - 1) * 0.65
		local seg = addBox(m, cframe, s, "LowerSeg_" .. i, Vector3.new(1.1, 0.9, 0.32), CFrame.new(lx, 1.8, -0.62), P.WATER_FALL, Enum.Material.Glass, false, 0.22, false)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", lx)
		seg:SetAttribute("LocalZ", -0.62)
		seg:SetAttribute("StartVal", 3.0)
		seg:SetAttribute("EndVal", 0.68)
		seg:SetAttribute("Speed", 0.68 + i * 0.05)
		seg:SetAttribute("Phase", (i - 1) / 3)
		seg:SetAttribute("BaseTransparency", 0.22)
	end
	for i = 1, 3 do
		local lx = (i - 2) * 0.55
		local drop = addBox(m, cframe, s, "Droplet_" .. i, Vector3.new(0.26, 0.28, 0.26), CFrame.new(lx, 2.0, -0.5), P.WATER_FOAM, Enum.Material.Glass, false, 0.2, false)
		drop:SetAttribute("AnimKind", "Droplet")
		drop:SetAttribute("LocalX", lx)
		drop:SetAttribute("LocalZ", -0.5)
		drop:SetAttribute("StartY", 3.2)
		drop:SetAttribute("EndY", 0.55)
		drop:SetAttribute("OutArcZ", 0.7)
		drop:SetAttribute("Speed", 0.74 + i * 0.05)
		drop:SetAttribute("Phase", (i - 1) / 3)
		drop:SetAttribute("BaseTransparency", 0.2)
	end
	for i = 1, 2 do
		local ripCF = CFrame.new(0.1, 0.58, 0.2)
		local rip = addBox(m, cframe, s, "RippleRing_" .. i, Vector3.new(2.2, 0.08, 1.8), ripCF, P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 0.45, false)
		rip:SetAttribute("AnimKind", "RippleRing")
		rip:SetAttribute("BaseLocalCF", ripCF)
		rip:SetAttribute("Phase", (i - 1) * 0.5)
		rip:SetAttribute("Speed", 0.6)
	end

	buildLilyPad(m, cframe, s, "BasinLilyA", Vector3.new(-1.8, 0.62, 2.4), 1.45, 28, true, P.LOTUS_PINK)
	buildLilyPad(m, cframe, s, "BasinLilyB", Vector3.new(2.0, 0.62, 2.1), 1.3, -18, false)
	addMiniWaterfallParticleEmitters(m, cframe, s, Vector3.new(0.1, 0.62, -0.1))
	return m
end

-- ============================================================================
-- CATALOG & SERVERSTORAGE LIBRARY MANAGEMENT (56 ASSETS)
-- ============================================================================

JungleBiomeAssetBuilder.Catalog = {
	GiantTrees = {
		{ name = "GiantJungleTree_CanopyArch", category = "Trees", build = buildGiantJungleTree_CanopyArch },
		{ name = "GiantJungleTree_TwinFork", category = "Trees", build = buildGiantJungleTree_TwinFork },
		{ name = "GiantJungleTree_AncientBanyan", category = "Trees", build = buildGiantJungleTree_AncientBanyan },
		{ name = "GiantJungleTree_LayeredPine", category = "Trees", build = buildGiantJungleTree_LayeredPine },
		{ name = "GiantJungleTree_OverhangLimb", category = "Trees", build = buildGiantJungleTree_OverhangLimb },
	},
	SmallTrees = {
		{ name = "SmallJungleTree_Broadleaf", category = "Trees", build = buildSmallJungleTree_Broadleaf },
		{ name = "SmallJungleTree_TropicalPalm", category = "Trees", build = buildSmallJungleTree_TropicalPalm },
		{ name = "SmallJungleTree_SplitUmbrella", category = "Trees", build = buildSmallJungleTree_SplitUmbrella },
		{ name = "SmallJungleTree_SteppedCanopy", category = "Trees", build = buildSmallJungleTree_SteppedCanopy },
		{ name = "SmallJungleTree_SpruceSapling", category = "Trees", build = buildSmallJungleTree_SpruceSapling },
	},
	Bushes = {
		{ name = "Bush_DenseBlocky", category = "Bushes", build = buildBush_DenseBlocky },
		{ name = "Bush_UprightBerry", category = "Bushes", build = buildBush_UprightBerry },
		{ name = "Bush_PinkBlossom", category = "Bushes", build = buildBush_PinkBlossom },
		{ name = "Bush_RedBlossom", category = "Bushes", build = buildBush_RedBlossom },
		{ name = "Bush_PurpleBlossom", category = "Bushes", build = buildBush_PurpleBlossom },
		{ name = "Bush_WideLowThicket", category = "Bushes", build = buildBush_WideLowThicket },
	},
	Plants = {
		{ name = "Plant_TallGrassTuft", category = "Plants", build = buildPlant_TallGrassTuft },
		{ name = "Plant_BroadBananaLeaf", category = "Plants", build = buildPlant_BroadBananaLeaf },
		{ name = "Plant_LushJungleFern", category = "Plants", build = buildPlant_LushJungleFern },
		{ name = "Plant_SpireSapling", category = "Plants", build = buildPlant_SpireSapling },
		{ name = "Plant_TropicalReeds", category = "Plants", build = buildPlant_TropicalReeds },
		{ name = "Plant_SpreadingLowFern", category = "Plants", build = buildPlant_SpreadingLowFern },
		{ name = "Plant_BroadMonstera", category = "Plants", build = buildPlant_BroadMonstera },
		{ name = "Plant_MossyCloverPatch", category = "Plants", build = buildPlant_MossyCloverPatch },
	},
	Flowers = {
		{ name = "Flower_BlueVioletStalks", category = "Flowers", build = buildFlower_BlueVioletStalks },
		{ name = "Flower_RedOrangeCluster", category = "Flowers", build = buildFlower_RedOrangeCluster },
		{ name = "Flower_PurpleLavenderDuo", category = "Flowers", build = buildFlower_PurpleLavenderDuo },
		{ name = "Flower_SunnyWildflowerMix", category = "Flowers", build = buildFlower_SunnyWildflowerMix },
		{ name = "Flower_TropicalOrchidPatch", category = "Flowers", build = buildFlower_TropicalOrchidPatch },
	},
	Rocks = {
		{ name = "Rock_TallMossyBoulder", category = "Rocks", build = buildRock_TallMossyBoulder },
		{ name = "Rock_MediumMossyMound", category = "Rocks", build = buildRock_MediumMossyMound },
		{ name = "Rock_LowFlatMossStone", category = "Rocks", build = buildRock_LowFlatMossStone },
		{ name = "Rock_LayeredMonolith", category = "Rocks", build = buildRock_LayeredMonolith },
		{ name = "Rock_CobbleScatterCluster", category = "Rocks", build = buildRock_CobbleScatterCluster },
		{ name = "Rock_SteppedCliffOutcrop", category = "Rocks", build = buildRock_SteppedCliffOutcrop },
	},
	Mushrooms = {
		{ name = "Mushroom_RedSpottedTrio", category = "Mushrooms", build = buildMushroom_RedSpottedTrio },
		{ name = "Mushroom_GiantRedToadstool", category = "Mushrooms", build = buildMushroom_GiantRedToadstool },
		{ name = "Mushroom_BrownShelfCluster", category = "Mushrooms", build = buildMushroom_BrownShelfCluster },
		{ name = "Mushroom_GlowJungleShrooms", category = "Mushrooms", build = buildMushroom_GlowJungleShrooms },
	},
	Ruins = {
		{ name = "Ruin_MossyStoneArchway", category = "Ruins", build = buildRuin_MossyStoneArchway },
		{ name = "Ruin_BrokenArchWall", category = "Ruins", build = buildRuin_BrokenArchWall },
		{ name = "Ruin_PillarAndPawBanner", category = "Ruins", build = buildRuin_PillarAndPawBanner },
	},
	TreeRoots = {
		{ name = "TreeRoot_GiantArch", category = "Decorations", build = buildTreeRoot_GiantArch },
		{ name = "TreeRoot_TwistedSprawl", category = "Decorations", build = buildTreeRoot_TwistedSprawl },
		{ name = "TreeRoot_MossyButtress", category = "Decorations", build = buildTreeRoot_MossyButtress },
		{ name = "TreeRoot_ExposedKnuckle", category = "Decorations", build = buildTreeRoot_ExposedKnuckle },
	},
	FallenLogs = {
		{ name = "FallenLog_HollowMossy", category = "Decorations", build = buildFallenLog_HollowMossy },
		{ name = "FallenLog_SplitTimber", category = "Decorations", build = buildFallenLog_SplitTimber },
		{ name = "FallenLog_VineBridge", category = "Decorations", build = buildFallenLog_VineBridge },
	},
	Lanterns = {
		{ name = "Lantern_OverhangArmPost", category = "Decorations", build = buildLantern_OverhangArmPost },
		{ name = "Lantern_StandingPathPost", category = "Decorations", build = buildLantern_StandingPathPost },
		{ name = "Lantern_FencePostLamp", category = "Decorations", build = buildLantern_FencePostLamp },
	},
	Ponds = {
		{ name = "WaterFeature_LilyPadPond", category = "WaterFeatures", build = buildWaterFeature_LilyPadPond },
		{ name = "WaterFeature_StoneLotusPool", category = "WaterFeatures", build = buildWaterFeature_StoneLotusPool },
	},
	MiniWaterfalls = {
		{ name = "WaterFeature_MiniWaterfallPond", category = "WaterFeatures", build = buildWaterFeature_MiniWaterfallPond },
		{ name = "WaterFeature_CascadeRockBasin", category = "WaterFeatures", build = buildWaterFeature_CascadeRockBasin },
	},
}

local CATEGORY_BUILD_GROUPS: { { category: string, groups: { { AssetEntry } } } } = {
	{ category = "Trees", groups = { JungleBiomeAssetBuilder.Catalog.GiantTrees, JungleBiomeAssetBuilder.Catalog.SmallTrees } },
	{ category = "Bushes", groups = { JungleBiomeAssetBuilder.Catalog.Bushes } },
	{ category = "Plants", groups = { JungleBiomeAssetBuilder.Catalog.Plants } },
	{ category = "Flowers", groups = { JungleBiomeAssetBuilder.Catalog.Flowers } },
	{ category = "Rocks", groups = { JungleBiomeAssetBuilder.Catalog.Rocks } },
	{ category = "Mushrooms", groups = { JungleBiomeAssetBuilder.Catalog.Mushrooms } },
	{ category = "Ruins", groups = { JungleBiomeAssetBuilder.Catalog.Ruins } },
	{ category = "Decorations", groups = { JungleBiomeAssetBuilder.Catalog.TreeRoots, JungleBiomeAssetBuilder.Catalog.FallenLogs, JungleBiomeAssetBuilder.Catalog.Lanterns } },
	{ category = "WaterFeatures", groups = { JungleBiomeAssetBuilder.Catalog.Ponds, JungleBiomeAssetBuilder.Catalog.MiniWaterfalls } },
}

local EXPECTED_LIBRARY_VERSION = 2

function JungleBiomeAssetBuilder.EnsureLibrary(parentOverride: Instance?): Folder
	local rootParent: Instance = parentOverride or ServerStorage
	local existing = rootParent:FindFirstChild("JungleBiomeAssets")
	if existing and existing:IsA("Folder") and existing:GetAttribute("LibraryVersion") == EXPECTED_LIBRARY_VERSION then
		local complete = true
		for _, spec in ipairs(CATEGORY_BUILD_GROUPS) do
			local sub = existing:FindFirstChild(spec.category)
			local expectedCount = 0
			for _, g in ipairs(spec.groups) do
				expectedCount += #g
			end
			if not sub or #sub:GetChildren() < expectedCount then
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
	lib.Name = "JungleBiomeAssets"
	lib:SetAttribute("BiomeId", "PineWoods")
	lib:SetAttribute("LibraryVersion", EXPECTED_LIBRARY_VERSION)

	local totalCount = 0
	for _, spec in ipairs(CATEGORY_BUILD_GROUPS) do
		local catFolder = Instance.new("Folder")
		catFolder.Name = spec.category
		for _, grp in ipairs(spec.groups) do
			for _, entry in ipairs(grp) do
				entry.build(CFrame.identity, 1, catFolder)
				totalCount += 1
			end
		end
		catFolder.Parent = lib
		task.wait()
	end

	lib:SetAttribute("AssetCount", totalCount)
	lib.Parent = rootParent
	return lib
end

function JungleBiomeAssetBuilder.SpawnFromLibrary(
	category: string,
	assetName: string,
	cframe: CFrame,
	scale: number?,
	parent: Instance?
): Model
	local lib = JungleBiomeAssetBuilder.EnsureLibrary()
	local catFolder = lib:FindFirstChild(category)
	local template = if catFolder then catFolder:FindFirstChild(assetName) else nil
	if not template or not template:IsA("Model") then
		error(string.format("[JungleBiomeAssetBuilder] Asset '%s/%s' not found in JungleBiomeAssets", category, assetName))
	end

	local s = scale or 1
	local clone = template:Clone()
	if math.abs(s - 1) > 1e-4 then
		clone:ScaleTo(s)
	end
	if clone:GetAttribute("HasAnimatedWaterfall") == true then
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

return JungleBiomeAssetBuilder
