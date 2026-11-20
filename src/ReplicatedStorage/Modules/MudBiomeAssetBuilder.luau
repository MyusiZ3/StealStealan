--!strict
-- MudBiomeAssetBuilder.luau
-- 40-Asset Voxel Mud / Mystic Swamp Biome Asset Pack for MangroveSwamp matching reference.
-- Builds ServerStorage.MudBiomeAssets organized into 8 clean subfolders:
-- Trees (5), Bushes (3), Plants (7), Rocks (4), TerrainProps (4), Decorations (7), Structures (4), WaterFeatures (6).
-- Pure rectangular Studs/Glass/Neon/SmoothPlastic Parts, Anchored = true, CanCollide/CanQuery/CanTouch = false,
-- PrimaryPart = RootPivot at ground origin CFrame.identity.

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ClassicStudBiomeBuilder = require(script.Parent.ClassicStudBiomeBuilder)

local MudBiomeAssetBuilder = {}

export type AssetBuilderFn = (cframe: CFrame, scale: number?, parent: Instance?) -> Model

export type AssetEntry = {
	name: string,
	category: string,
	build: AssetBuilderFn,
}

MudBiomeAssetBuilder.CATEGORIES = {
	"Trees",
	"Bushes",
	"Plants",
	"Rocks",
	"TerrainProps",
	"Decorations",
	"Structures",
	"WaterFeatures",
}

-- ============================================================================
-- VISUAL PALETTE (Mud Brown, Olive, Moss, Mystic Purple & Warm Yellow Glow)
-- ============================================================================

local P = {
	MUD_DARK = Color3.fromRGB(68, 50, 36),
	MUD_MID = Color3.fromRGB(96, 72, 50),
	MUD_WET = Color3.fromRGB(76, 60, 44),
	BARK_DARK = Color3.fromRGB(78, 54, 38),
	BARK_MID = Color3.fromRGB(112, 78, 50),
	BARK_WARM = Color3.fromRGB(144, 102, 62),
	WOOD_CUT = Color3.fromRGB(194, 152, 100),
	WOOD_HOLLOW = Color3.fromRGB(48, 32, 22),

	SWAMP_DEEP = Color3.fromRGB(38, 76, 44),
	OLIVE_DARK = Color3.fromRGB(72, 98, 44),
	OLIVE_MID = Color3.fromRGB(104, 134, 52),
	MOSS_BRIGHT = Color3.fromRGB(126, 174, 62),
	LIME_SUN = Color3.fromRGB(162, 206, 76),
	TOXIC_GLOW = Color3.fromRGB(124, 248, 86),

	STONE_DARK = Color3.fromRGB(76, 80, 92),
	STONE_MID = Color3.fromRGB(106, 110, 122),
	STONE_LIGHT = Color3.fromRGB(134, 136, 146),

	PURPLE_DEEP = Color3.fromRGB(114, 62, 188),
	PURPLE_BRIGHT = Color3.fromRGB(168, 98, 244),
	PURPLE_GLOW = Color3.fromRGB(196, 128, 255),
	LOTUS_PINK = Color3.fromRGB(244, 126, 184),
	LOTUS_GOLD = Color3.fromRGB(255, 224, 84),
	SHROOM_RED = Color3.fromRGB(214, 62, 54),
	SHROOM_STEM = Color3.fromRGB(236, 224, 198),
	SHROOM_WHITE = Color3.fromRGB(244, 244, 238),
	CATTAIL_HEAD = Color3.fromRGB(96, 54, 34),
	AUTUMN_LEAF = Color3.fromRGB(188, 136, 52),

	LANTERN_IRON = Color3.fromRGB(52, 48, 50),
	LANTERN_GLOW = Color3.fromRGB(255, 206, 74),
	POINT_GLOW = Color3.fromRGB(255, 198, 72),

	WATER_MUD = Color3.fromRGB(48, 126, 112),
	WATER_BED = Color3.fromRGB(34, 62, 56),
	WATER_FALL = Color3.fromRGB(84, 208, 244),
	WATER_FOAM = Color3.fromRGB(228, 248, 252),
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
	m:SetAttribute("BiomeId", "MangroveSwamp")

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

local function addSwampCanopyCluster(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	center: Vector3,
	w: number,
	h: number,
	d: number
)
	addBox(m, originCF, s, prefix .. "_Under", Vector3.new(w * 0.92, h * 0.44, d * 0.92), CFrame.new(center + Vector3.new(0, -h * 0.24, 0)), P.SWAMP_DEEP)
	addBox(m, originCF, s, prefix .. "_Core", Vector3.new(w, h * 0.56, d), CFrame.new(center + Vector3.new(0, h * 0.04, 0)), P.OLIVE_DARK)
	addBox(m, originCF, s, prefix .. "_SideA", Vector3.new(w * 1.12, h * 0.34, d * 0.72), CFrame.new(center + Vector3.new(0.18, h * 0.08, -0.15)), P.OLIVE_MID)
	addBox(m, originCF, s, prefix .. "_SideB", Vector3.new(w * 0.72, h * 0.34, d * 1.12), CFrame.new(center + Vector3.new(-0.18, h * 0.08, 0.15)), P.MOSS_BRIGHT)
	addBox(m, originCF, s, prefix .. "_Crown", Vector3.new(w * 0.72, h * 0.35, d * 0.72), CFrame.new(center + Vector3.new(0.1, h * 0.42, -0.1)), P.MOSS_BRIGHT)
	addBox(m, originCF, s, prefix .. "_LimeTip", Vector3.new(w * 0.44, h * 0.26, d * 0.44), CFrame.new(center + Vector3.new(w * 0.12, h * 0.56, -d * 0.1)), P.LIME_SUN)
end

local function addSwampVine(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	topPos: Vector3,
	length: number,
	useLimeTip: boolean?
)
	local segs = math.max(2, math.floor(length / 1.5))
	local segH = length / segs
	for i = 1, segs do
		local y = topPos.Y - (i - 0.5) * segH
		local x = topPos.X + (if i % 2 == 0 then 0.16 else -0.08)
		local z = topPos.Z + (if i % 2 == 0 then -0.1 else 0.08)
		local w = math.max(0.32, 0.56 - (i - 1) * 0.06)
		local col = if i == segs and useLimeTip ~= false then P.LIME_SUN elseif i % 2 == 0 then P.MOSS_BRIGHT else P.OLIVE_MID
		addBox(m, originCF, s, prefix .. "_" .. i, Vector3.new(w, segH + 0.08, w), CFrame.new(x, y, z), col, nil, true, 0, false)
	end
end

local function addMossCap(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, w: number, d: number)
	addBox(m, originCF, s, prefix .. "_Pad", Vector3.new(w, 0.38, d), CFrame.new(pos), P.OLIVE_DARK, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Tip", Vector3.new(w * 0.65, 0.28, d * 0.65), CFrame.new(pos + Vector3.new(w * 0.12, 0.22, -d * 0.08)), P.MOSS_BRIGHT, nil, true, 0, false)
end

local function addWarmLantern(m: Model, originCF: CFrame, s: number, prefix: string, center: Vector3, range: number?, brightness: number?)
	local br = brightness or 0.88
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
	pl.Color = P.POINT_GLOW
	pl.Range = range or 16
	pl.Brightness = br
	pl.Shadows = false
	pl:SetAttribute("AnimKind", "LanternPulse")
	pl:SetAttribute("BaseBrightness", br)
	pl:SetAttribute("Phase", (math.abs(center.X) + math.abs(center.Z)) * 0.41)
	pl.Parent = glow
end

local function addSwampFireflies(parent: BasePart, rate: number?)
	local em = Instance.new("ParticleEmitter")
	em.Name = "SwampFireflies"
	em.Color = ColorSequence.new(Color3.fromRGB(192, 255, 118), Color3.fromRGB(255, 224, 96))
	em.Rate = rate or 3
	em.Lifetime = NumberRange.new(2.0, 3.6)
	em.Speed = NumberRange.new(0.5, 1.6)
	em.SpreadAngle = Vector2.new(180, 180)
	em.LightEmission = 0.75
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.26), NumberSequenceKeypoint.new(1, 0) })
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1) })
	em.Parent = parent
end

local function addMudBubbleEmitter(parent: BasePart, rate: number?)
	local em = Instance.new("ParticleEmitter")
	em.Name = "MudBubbles"
	em.Color = ColorSequence.new(Color3.fromRGB(118, 94, 64), Color3.fromRGB(168, 224, 128))
	em.Rate = rate or 4
	em.Lifetime = NumberRange.new(0.7, 1.3)
	em.Speed = NumberRange.new(0.8, 2.0)
	em.SpreadAngle = Vector2.new(25, 25)
	em.EmissionDirection = Enum.NormalId.Top
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(0.7, 0.36), NumberSequenceKeypoint.new(1, 0.05) })
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	em.Parent = parent
end

local function addLilyPad(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, radius: number, yawDeg: number, lotusCol: Color3?)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	addBox(m, originCF, s, prefix .. "_Pad", Vector3.new(radius, 0.14, radius * 0.88), cf, P.OLIVE_MID, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_Trim", Vector3.new(radius * 0.56, 0.16, radius * 0.52), cf * CFrame.new(radius * 0.14, 0.04, -radius * 0.1), P.MOSS_BRIGHT, nil, true, 0, false)
	if lotusCol then
		addBox(m, originCF, s, prefix .. "_LotusOut", Vector3.new(0.78, 0.26, 0.78), cf * CFrame.new(0, 0.18, 0), lotusCol, nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_LotusTop", Vector3.new(0.48, 0.32, 0.48), cf * CFrame.new(0, 0.32, 0), Color3.fromRGB(255, 198, 234), nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_LotusCore", Vector3.new(0.24, 0.30, 0.24), cf * CFrame.new(0, 0.42, 0), P.LOTUS_GOLD, nil, true, 0, false)
	end
end

local function addShroom(m: Model, originCF: CFrame, s: number, prefix: string, pos: Vector3, stemH: number, stemW: number, capW: number, capCol: Color3, spotCol: Color3?)
	addBox(m, originCF, s, prefix .. "_Stem", Vector3.new(stemW, stemH, stemW), CFrame.new(pos.X, pos.Y + stemH * 0.5, pos.Z), P.SHROOM_STEM, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_CapBase", Vector3.new(capW, capW * 0.34, capW), CFrame.new(pos.X, pos.Y + stemH + capW * 0.16, pos.Z), capCol, nil, true, 0, false)
	addBox(m, originCF, s, prefix .. "_CapTop", Vector3.new(capW * 0.68, capW * 0.24, capW * 0.68), CFrame.new(pos.X, pos.Y + stemH + capW * 0.4, pos.Z), capCol, nil, true, 0, false)
	if spotCol then
		addBox(m, originCF, s, prefix .. "_SpotA", Vector3.new(capW * 0.24, 0.16, capW * 0.24), CFrame.new(pos.X + capW * 0.2, pos.Y + stemH + capW * 0.4, pos.Z - capW * 0.16), spotCol, nil, true, 0, false)
		addBox(m, originCF, s, prefix .. "_SpotB", Vector3.new(capW * 0.2, 0.14, capW * 0.2), CFrame.new(pos.X - capW * 0.22, pos.Y + stemH + capW * 0.28, pos.Z + capW * 0.2), spotCol, nil, true, 0, false)
	end
end

-- ============================================================================
-- 1. TREES (5)
-- ============================================================================

local function buildGiantSwampTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "GiantSwampTree", cframe, parent)

	for i, r in ipairs({
		{ pos = Vector3.new(-2.4, 1.1, 0.2), sz = Vector3.new(2.2, 2.2, 2.0), col = P.MUD_DARK },
		{ pos = Vector3.new(2.5, 1.0, -0.3), sz = Vector3.new(2.3, 2.0, 2.0), col = P.BARK_DARK },
		{ pos = Vector3.new(0.2, 1.0, -2.3), sz = Vector3.new(2.0, 2.0, 2.2), col = P.MUD_MID },
		{ pos = Vector3.new(-0.3, 1.0, 2.3), sz = Vector3.new(2.0, 2.0, 2.2), col = P.BARK_DARK },
	}) do
		addBox(m, cframe, s, "Buttress_" .. i, r.sz, CFrame.new(r.pos), r.col)
		addMossCap(m, cframe, s, "RootMoss_" .. i, Vector3.new(r.pos.X, r.sz.Y + 0.14, r.pos.Z), r.sz.X * 0.72, r.sz.Z * 0.72)
	end

	local trunkCore = addBox(m, cframe, s, "TrunkBase", Vector3.new(3.6, 6.0, 3.6), CFrame.new(0, 3.0, 0), P.BARK_MID)
	addSwampFireflies(trunkCore, 3)
	addBox(m, cframe, s, "TrunkMid", Vector3.new(2.8, 5.6, 2.8), CFrame.new(-0.2, 8.2, 0.1), P.BARK_DARK)
	addBox(m, cframe, s, "TrunkTop", Vector3.new(2.2, 4.4, 2.2), CFrame.new(0.2, 12.2, -0.2), P.BARK_MID)

	addBox(m, cframe, s, "LimbL", Vector3.new(5.2, 1.6, 1.8), CFrame.new(-3.0, 10.6, 0.3) * CFrame.Angles(0, 0, math.rad(-16)), P.BARK_DARK)
	addBox(m, cframe, s, "LimbR", Vector3.new(5.0, 1.5, 1.8), CFrame.new(3.0, 9.6, -0.3) * CFrame.Angles(0, 0, math.rad(14)), P.BARK_MID)

	addSwampCanopyCluster(m, cframe, s, "SwampCanopyMain", Vector3.new(0, 15.2, 0), 12.6, 4.2, 11.4)
	addSwampCanopyCluster(m, cframe, s, "SwampCanopyL", Vector3.new(-4.8, 12.8, 0.6), 7.8, 3.2, 7.4)
	addSwampCanopyCluster(m, cframe, s, "SwampCanopyR", Vector3.new(4.8, 11.8, -0.5), 7.4, 3.0, 7.0)

	for i, v in ipairs({
		{ p = Vector3.new(-7.4, 11.2, 2.2), len = 5.6 },
		{ p = Vector3.new(-5.4, 11.2, -2.6), len = 4.8 },
		{ p = Vector3.new(7.4, 10.4, 1.8), len = 5.2 },
		{ p = Vector3.new(5.2, 10.2, -2.8), len = 4.6 },
		{ p = Vector3.new(-2.2, 13.0, 4.8), len = 5.0 },
		{ p = Vector3.new(2.4, 13.0, -4.6), len = 4.4 },
		{ p = Vector3.new(0.4, 13.2, 5.2), len = 4.0 },
		{ p = Vector3.new(-1.4, 13.0, -4.8), len = 3.8 },
	}) do
		addSwampVine(m, cframe, s, "Vine_" .. i, v.p, v.len)
	end
	return m
end

local function buildDeadSwampTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "DeadSwampTree", cframe, parent)

	for i, off in ipairs({ Vector3.new(-1.5, 0.55, 0.3), Vector3.new(1.5, 0.5, -0.3), Vector3.new(0.2, 0.6, 1.5), Vector3.new(-0.2, 0.5, -1.4) }) do
		addBox(m, cframe, s, "DeadRoot_" .. i, Vector3.new(1.4, 1.1, 1.3), CFrame.new(off), P.BARK_DARK)
	end
	addBox(m, cframe, s, "GnarledLow", Vector3.new(2.4, 4.8, 2.3), CFrame.new(0, 2.4, 0), P.BARK_MID)
	addBox(m, cframe, s, "GnarledMid", Vector3.new(1.9, 4.4, 1.9), CFrame.new(-0.35, 6.2, 0.15) * CFrame.Angles(0, 0, math.rad(9)), P.BARK_DARK)
	addBox(m, cframe, s, "SpireTop", Vector3.new(1.2, 3.8, 1.2), CFrame.new(-0.85, 9.6, 0.2) * CFrame.Angles(0, 0, math.rad(14)), P.BARK_MID)

	-- 4 Twisted jagged leafless branches + draping moss strands
	addBox(m, cframe, s, "BoughL", Vector3.new(4.2, 1.0, 1.0), CFrame.new(-2.4, 7.8, 0.3) * CFrame.Angles(0, 0, math.rad(-22)), P.BARK_DARK)
	addBox(m, cframe, s, "TwigL", Vector3.new(1.0, 2.4, 0.9), CFrame.new(-4.2, 9.4, 0.3) * CFrame.Angles(0, 0, math.rad(16)), P.BARK_MID)
	addBox(m, cframe, s, "BoughR", Vector3.new(4.0, 0.95, 1.0), CFrame.new(2.0, 7.0, -0.3) * CFrame.Angles(0, 0, math.rad(24)), P.BARK_MID)
	addBox(m, cframe, s, "TwigR", Vector3.new(0.9, 2.2, 0.9), CFrame.new(3.7, 8.6, -0.3) * CFrame.Angles(0, 0, math.rad(-14)), P.BARK_DARK)

	addSwampVine(m, cframe, s, "DeadMossL", Vector3.new(-3.6, 7.8, 0.3), 4.2)
	addSwampVine(m, cframe, s, "DeadMossR", Vector3.new(3.2, 7.0, -0.3), 3.6)

	-- Base cattail shoots
	addBox(m, cframe, s, "BaseReeds", Vector3.new(0.28, 1.8, 0.28), CFrame.new(1.6, 0.9, 1.2), P.OLIVE_MID, nil, true, 0, false)
	addBox(m, cframe, s, "BaseCattail", Vector3.new(0.42, 0.75, 0.42), CFrame.new(1.6, 1.5, 1.2), P.CATTAIL_HEAD, nil, true, 0, false)
	return m
end

local function buildWillowTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "WillowTree", cframe, parent)

	addBox(m, cframe, s, "WillowBase", Vector3.new(3.6, 1.2, 3.4), CFrame.new(0, 0.6, 0), P.BARK_DARK)
	addBox(m, cframe, s, "WillowTrunkA", Vector3.new(2.3, 5.4, 2.2), CFrame.new(-0.3, 3.2, 0) * CFrame.Angles(0, 0, math.rad(8)), P.BARK_MID)
	addBox(m, cframe, s, "WillowTrunkB", Vector3.new(1.8, 4.8, 1.8), CFrame.new(-0.9, 7.4, 0.1) * CFrame.Angles(0, 0, math.rad(10)), P.BARK_DARK)

	addSwampCanopyCluster(m, cframe, s, "WillowDomeLow", Vector3.new(-0.8, 10.6, 0), 10.8, 3.8, 10.4)
	addSwampCanopyCluster(m, cframe, s, "WillowDomeHigh", Vector3.new(-0.6, 13.0, 0), 7.6, 3.0, 7.4)

	-- 10 Long drooping weeping willow leaf curtains
	for i = 1, 10 do
		local ang = (i / 10) * math.pi * 2
		local r = if i % 2 == 0 then 5.0 else 3.8
		local top = Vector3.new(-0.8 + math.cos(ang) * r, 9.4, math.sin(ang) * r)
		local len = 6.2 + (i % 3) * 1.4
		addSwampVine(m, cframe, s, "WillowCurtain_" .. i, top, len, true)
	end
	return m
end

local function buildSmallMudlandTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallMudlandTree", cframe, parent)

	addBox(m, cframe, s, "MudFoot", Vector3.new(2.8, 0.85, 2.6), CFrame.new(0, 0.42, 0), P.MUD_DARK)
	addMossCap(m, cframe, s, "MudFootMoss", Vector3.new(-0.5, 0.96, 0.4), 1.9, 1.8)
	addBox(m, cframe, s, "TrunkBentA", Vector3.new(1.6, 3.6, 1.6), CFrame.new(0, 2.1, 0), P.BARK_MID)
	addBox(m, cframe, s, "TrunkBentB", Vector3.new(1.3, 3.0, 1.3), CFrame.new(0.45, 4.7, -0.2) * CFrame.Angles(0, 0, math.rad(-12)), P.BARK_DARK)

	addSwampCanopyCluster(m, cframe, s, "MudCanopyMain", Vector3.new(0.5, 7.4, -0.2), 7.0, 3.0, 6.8)
	addSwampCanopyCluster(m, cframe, s, "MudCanopySide", Vector3.new(-1.8, 6.6, 0.4), 4.4, 2.2, 4.2)

	addSwampVine(m, cframe, s, "ShortVineA", Vector3.new(-3.2, 5.6, 0.8), 2.8)
	addSwampVine(m, cframe, s, "ShortVineB", Vector3.new(3.1, 5.9, -1.4), 3.0)
	addSwampVine(m, cframe, s, "ShortVineC", Vector3.new(0.2, 5.8, 2.9), 2.4)
	return m
end

local function buildMossCoveredTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "MossCoveredTree", cframe, parent)

	for i, ang in ipairs({ 0, 90, 180, 270 }) do
		local rot = CFrame.Angles(0, math.rad(ang), 0)
		addBox(m, cframe, s, "KneeFoot_" .. i, Vector3.new(1.0, 2.4, 1.0), rot * CFrame.new(2.0, 1.2, 0), P.BARK_DARK)
		addBox(m, cframe, s, "KneeArch_" .. i, Vector3.new(1.9, 0.9, 0.9), rot * CFrame.new(1.3, 2.5, 0) * CFrame.Angles(0, 0, math.rad(24)), P.BARK_MID)
		addMossCap(m, cframe, s, "KneeMoss_" .. i, (rot * CFrame.new(1.6, 3.05, 0)).Position, 1.4, 1.2)
	end
	local hub = addBox(m, cframe, s, "MossTrunk", Vector3.new(2.2, 5.4, 2.2), CFrame.new(0, 4.8, 0), P.BARK_MID)
	addSwampFireflies(hub, 2)
	addBox(m, cframe, s, "TrunkMossBlanket", Vector3.new(2.45, 2.4, 1.2), CFrame.new(0, 5.4, 0.7), P.OLIVE_MID)
	addBox(m, cframe, s, "ShelfShroom", Vector3.new(0.8, 0.25, 0.7), CFrame.new(1.3, 4.0, 0.4), P.SHROOM_STEM)

	addSwampCanopyCluster(m, cframe, s, "MossCanopyA", Vector3.new(0, 8.6, 0), 9.4, 3.4, 8.8)
	addSwampCanopyCluster(m, cframe, s, "MossCanopyB", Vector3.new(0.4, 11.0, -0.3), 6.2, 2.6, 6.0)
	addSwampVine(m, cframe, s, "Curtain1", Vector3.new(-3.8, 7.2, 2.2), 3.6)
	addSwampVine(m, cframe, s, "Curtain2", Vector3.new(3.8, 7.2, -2.0), 3.8)
	return m
end

-- ============================================================================
-- 2. BUSHES (3)
-- ============================================================================

local function buildMudBush_Dense(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "MudBush_Dense", cframe, parent)
	addBox(m, cframe, s, "MudBase", Vector3.new(4.2, 0.45, 3.8), CFrame.new(0, 0.22, 0), P.MUD_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "Core", Vector3.new(3.8, 2.0, 3.4), CFrame.new(0, 1.2, 0), P.SWAMP_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "LobeL", Vector3.new(2.2, 1.6, 2.4), CFrame.new(-1.3, 1.0, 0.4), P.OLIVE_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "LobeR", Vector3.new(2.1, 1.5, 2.2), CFrame.new(1.3, 0.95, -0.3), P.OLIVE_MID, nil, true, 0, false)
	addBox(m, cframe, s, "Crown", Vector3.new(2.4, 1.0, 2.2), CFrame.new(-0.2, 2.45, 0), P.OLIVE_MID, nil, true, 0, false)
	return m
end

local function buildMossBush_Lush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "MossBush_Lush", cframe, parent)
	addBox(m, cframe, s, "Core", Vector3.new(3.6, 2.0, 3.4), CFrame.new(0, 1.0, 0), P.OLIVE_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "Mid", Vector3.new(4.2, 1.4, 2.6), CFrame.new(0.1, 1.2, 0), P.MOSS_BRIGHT, nil, true, 0, false)
	addBox(m, cframe, s, "Top", Vector3.new(2.4, 1.1, 2.2), CFrame.new(0, 2.3, 0), P.LIME_SUN, nil, true, 0, false)
	for i, off in ipairs({ Vector3.new(-1.6, 1.3, 1.1), Vector3.new(1.4, 1.5, 0.9), Vector3.new(-0.4, 2.5, -0.7), Vector3.new(0.7, 2.3, 0.8) }) do
		addBox(m, cframe, s, "SwampBloom_" .. i, Vector3.new(0.5, 0.48, 0.5), CFrame.new(off), if i % 2 == 0 then P.PURPLE_BRIGHT else P.PURPLE_DEEP, nil, true, 0, false)
	end
	return m
end

local function buildToxicBush_SwampGlow(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "ToxicBush_SwampGlow", cframe, parent)
	addBox(m, cframe, s, "Core", Vector3.new(3.4, 2.2, 3.2), CFrame.new(0, 1.1, 0), P.SWAMP_DEEP, nil, true, 0, false)
	addBox(m, cframe, s, "WingL", Vector3.new(2.2, 1.5, 2.4), CFrame.new(-1.2, 0.85, 0.2), P.OLIVE_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "Top", Vector3.new(2.2, 1.1, 2.2), CFrame.new(0.1, 2.35, -0.1), P.OLIVE_MID, nil, true, 0, false)
	for i, off in ipairs({ Vector3.new(-1.55, 1.45, 0.7), Vector3.new(1.5, 1.3, -0.5), Vector3.new(-0.3, 2.65, 0.75), Vector3.new(0.8, 2.1, 1.3) }) do
		addBox(m, cframe, s, "ToxicSpore_" .. i, Vector3.new(0.44, 0.44, 0.44), CFrame.new(off), P.TOXIC_GLOW, Enum.Material.Neon, false, 0, false)
	end
	return m
end

-- ============================================================================
-- 3. PLANTS (7)
-- ============================================================================

local function buildSwampFern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "SwampFern", cframe, parent)
	addBox(m, cframe, s, "FernHub", Vector3.new(1.2, 0.8, 1.2), CFrame.new(0, 0.4, 0), P.SWAMP_DEEP, nil, true, 0, false)
	for i = 0, 6 do
		local rot = CFrame.Angles(0, math.rad(i * 51), 0)
		addBox(m, cframe, s, "FrondA_" .. i, Vector3.new(0.7, 0.24, 1.9), rot * CFrame.new(0, 0.9, 1.05) * CFrame.Angles(math.rad(22), 0, 0), P.OLIVE_MID, nil, true, 0, false)
		addBox(m, cframe, s, "FrondB_" .. i, Vector3.new(0.5, 0.2, 1.1), rot * CFrame.new(0, 1.1, 2.15) * CFrame.Angles(math.rad(-10), 0, 0), P.LIME_SUN, nil, true, 0, false)
	end
	return m
end

local function buildTallReeds(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "TallReeds", cframe, parent)
	addBox(m, cframe, s, "MudBase", Vector3.new(2.4, 0.24, 2.4), CFrame.new(0, 0.12, 0), P.MUD_MID, nil, true, 0, false)
	for i, r in ipairs({
		{ x = -0.55, z = -0.25, h = 3.8, tilt = 7 },
		{ x = 0.2, z = 0.35, h = 4.5, tilt = -5 },
		{ x = 0.7, z = -0.35, h = 3.4, tilt = 10 },
		{ x = -0.25, z = 0.65, h = 3.1, tilt = -9 },
		{ x = 0.0, z = -0.7, h = 4.1, tilt = 5 },
	}) do
		local cf = CFrame.new(r.x, r.h * 0.5 + 0.1, r.z) * CFrame.Angles(math.rad(r.tilt), 0, math.rad(r.tilt * 0.4))
		addBox(m, cframe, s, "ReedStalk_" .. i, Vector3.new(0.24, r.h, 0.24), cf, P.OLIVE_DARK, nil, true, 0, false)
		addBox(m, cframe, s, "ReedTip_" .. i, Vector3.new(0.55, 0.85, 0.28), cf * CFrame.new(0, r.h * 0.34, 0.16), P.MOSS_BRIGHT, nil, true, 0, false)
	end
	return m
end

local function buildCattails(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "Cattails", cframe, parent)
	addBox(m, cframe, s, "MudPad", Vector3.new(2.8, 0.24, 2.8), CFrame.new(0, 0.12, 0), P.MUD_DARK, nil, true, 0, false)
	for i, r in ipairs({
		{ x = -0.65, z = -0.35, h = 3.6, tilt = 6 },
		{ x = 0.15, z = 0.2, h = 4.4, tilt = -4 },
		{ x = 0.75, z = -0.45, h = 3.3, tilt = 8 },
		{ x = -0.3, z = 0.7, h = 4.0, tilt = -7 },
	}) do
		local cf = CFrame.new(r.x, r.h * 0.5 + 0.1, r.z) * CFrame.Angles(math.rad(r.tilt), 0, 0)
		addBox(m, cframe, s, "CattailStem_" .. i, Vector3.new(0.22, r.h, 0.22), cf, P.OLIVE_MID, nil, true, 0, false)
		addBox(m, cframe, s, "CattailHead_" .. i, Vector3.new(0.44, 1.05, 0.44), cf * CFrame.new(0, r.h * 0.3, 0), P.CATTAIL_HEAD, nil, true, 0, false)
		addBox(m, cframe, s, "LeafBlade_" .. i, Vector3.new(0.28, r.h * 0.45, 0.18), cf * CFrame.new(0.24, -r.h * 0.15, 0) * CFrame.Angles(0, 0, math.rad(-14)), P.MOSS_BRIGHT, nil, true, 0, false)
	end
	return m
end

local function buildSwampGrass(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "SwampGrass", cframe, parent)
	addBox(m, cframe, s, "MudTuft", Vector3.new(2.8, 0.22, 2.6), CFrame.new(0, 0.11, 0), P.OLIVE_DARK, nil, true, 0, false)
	for i, b in ipairs({
		{ x = -0.8, z = -0.4, h = 1.7, tilt = Vector3.new(10, 0, 12), col = P.OLIVE_MID },
		{ x = -0.15, z = 0.2, h = 2.3, tilt = Vector3.new(-6, 15, -5), col = P.MOSS_BRIGHT },
		{ x = 0.7, z = -0.3, h = 1.9, tilt = Vector3.new(8, -12, -14), col = P.OLIVE_DARK },
		{ x = 0.15, z = -0.8, h = 1.5, tilt = Vector3.new(-14, 0, 6), col = P.LIME_SUN },
		{ x = 0.75, z = 0.65, h = 1.6, tilt = Vector3.new(14, 24, -8), col = P.MOSS_BRIGHT },
		{ x = -0.65, z = 0.65, h = 1.8, tilt = Vector3.new(12, -18, 10), col = P.OLIVE_MID },
	}) do
		addBox(m, cframe, s, "GrassBlade_" .. i, Vector3.new(0.4, b.h, 0.4), CFrame.new(b.x, b.h * 0.5 + 0.12, b.z) * CFrame.Angles(math.rad(b.tilt.X), math.rad(b.tilt.Y), math.rad(b.tilt.Z)), b.col, nil, true, 0, false)
	end
	return m
end

local function buildHangingVines(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "HangingVines", cframe, parent)
	addBox(m, cframe, s, "MossHeader", Vector3.new(4.2, 0.65, 0.8), CFrame.new(0, 4.4, 0), P.OLIVE_DARK, nil, true, 0, false)
	addSwampVine(m, cframe, s, "CurtainA", Vector3.new(-1.4, 4.1, 0), 3.6, true)
	addSwampVine(m, cframe, s, "CurtainB", Vector3.new(0.0, 4.1, 0.1), 3.9, true)
	addSwampVine(m, cframe, s, "CurtainC", Vector3.new(1.3, 4.1, -0.1), 3.1, false)
	return m
end

local function buildPurpleSwampFlowers(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "PurpleSwampFlowers", cframe, parent)
	addBox(m, cframe, s, "FoliageBase", Vector3.new(3.0, 0.55, 2.8), CFrame.new(0, 0.28, 0), P.SWAMP_DEEP, nil, true, 0, false)
	for i, sp in ipairs({
		{ x = -0.65, z = -0.25, h = 2.6, col = P.PURPLE_DEEP },
		{ x = 0.15, z = 0.25, h = 3.2, col = P.PURPLE_BRIGHT },
		{ x = 0.75, z = -0.35, h = 2.3, col = P.PURPLE_DEEP },
		{ x = -0.2, z = 0.65, h = 2.1, col = P.PURPLE_BRIGHT },
	}) do
		addBox(m, cframe, s, "Stalk_" .. i, Vector3.new(0.24, sp.h, 0.24), CFrame.new(sp.x, sp.h * 0.5 + 0.3, sp.z), P.OLIVE_MID, nil, true, 0, false)
		addBox(m, cframe, s, "SpikeBot_" .. i, Vector3.new(0.68, 0.72, 0.68), CFrame.new(sp.x, sp.h - 0.1, sp.z), sp.col, nil, true, 0, false)
		addBox(m, cframe, s, "SpikeTop_" .. i, Vector3.new(0.45, 0.6, 0.45), CFrame.new(sp.x, sp.h + 0.45, sp.z), P.PURPLE_GLOW, nil, true, 0, false)
		addBox(m, cframe, s, "BloomCore_" .. i, Vector3.new(0.22, 0.22, 0.22), CFrame.new(sp.x, sp.h + 0.75, sp.z), P.LOTUS_GOLD, nil, true, 0, false)
	end
	return m
end

local function buildToxicGreenPlants(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "ToxicGreenPlants", cframe, parent)
	addBox(m, cframe, s, "ToxicPad", Vector3.new(2.4, 0.25, 2.4), CFrame.new(0, 0.12, 0), P.SWAMP_DEEP, nil, true, 0, false)
	for i, t in ipairs({
		{ x = -0.5, z = -0.2, h = 2.2, r = 12 },
		{ x = 0.3, z = 0.3, h = 2.8, r = -8 },
		{ x = 0.6, z = -0.4, h = 1.9, r = 16 },
	}) do
		local cf = CFrame.new(t.x, t.h * 0.5 + 0.12, t.z) * CFrame.Angles(math.rad(t.r), 0, math.rad(-t.r))
		addBox(m, cframe, s, "Shoot_" .. i, Vector3.new(0.42, t.h, 0.42), cf, P.OLIVE_MID, nil, true, 0, false)
		addBox(m, cframe, s, "ToxicPod_" .. i, Vector3.new(0.55, 0.55, 0.55), cf * CFrame.new(0, t.h * 0.52, 0), P.TOXIC_GLOW, Enum.Material.Neon, false, 0, false)
	end
	return m
end

-- ============================================================================
-- 4. ROCKS (4)
-- ============================================================================

local function buildMuddyBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "MuddyBoulder", cframe, parent)
	addBox(m, cframe, s, "BoulderBase", Vector3.new(5.4, 2.4, 4.6), CFrame.new(0, 1.2, 0), P.MUD_DARK)
	addBox(m, cframe, s, "BoulderMid", Vector3.new(3.8, 2.0, 3.6), CFrame.new(-0.3, 2.9, 0.2), P.STONE_DARK)
	addBox(m, cframe, s, "BoulderStepR", Vector3.new(2.4, 1.4, 2.6), CFrame.new(1.8, 1.2, -0.6), P.MUD_MID)
	addMossCap(m, cframe, s, "MudRockMoss", Vector3.new(-0.3, 4.05, 0.2), 3.4, 3.2)
	addBox(m, cframe, s, "MudStreak", Vector3.new(0.95, 1.8, 0.45), CFrame.new(0.5, 2.2, 1.95), P.MUD_MID)
	return m
end

local function buildMossyRock(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "MossyRock", cframe, parent)
	addBox(m, cframe, s, "RockBase", Vector3.new(5.0, 2.2, 4.4), CFrame.new(0, 1.1, 0), P.STONE_DARK)
	addBox(m, cframe, s, "RockPeak", Vector3.new(3.6, 2.4, 3.4), CFrame.new(-0.4, 3.0, 0.1), P.STONE_MID)
	addBox(m, cframe, s, "RockShoulder", Vector3.new(2.2, 1.5, 2.4), CFrame.new(1.7, 1.35, -0.5), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "RockMossTop", Vector3.new(-0.4, 4.35, 0.1), 3.5, 3.3)
	addMossCap(m, cframe, s, "RockMossSide", Vector3.new(1.7, 2.25, -0.5), 2.0, 2.2)
	addBox(m, cframe, s, "MossStreak", Vector3.new(0.75, 2.2, 0.45), CFrame.new(-1.3, 2.6, 1.85), P.MOSS_BRIGHT)
	return m
end

local function buildAncientStone(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "AncientStone", cframe, parent)
	addBox(m, cframe, s, "Plinth", Vector3.new(4.0, 1.1, 3.6), CFrame.new(0, 0.55, 0), P.STONE_DARK)
	addBox(m, cframe, s, "SteleCore", Vector3.new(2.8, 4.4, 2.4), CFrame.new(0, 3.1, 0), P.STONE_MID)
	addBox(m, cframe, s, "RuneBand", Vector3.new(2.96, 0.65, 2.56), CFrame.new(0, 3.8, 0), P.OLIVE_MID)
	addBox(m, cframe, s, "CrownSlab", Vector3.new(3.2, 1.1, 2.7), CFrame.new(0, 5.6, 0), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "AncientMoss", Vector3.new(0, 6.28, 0), 3.0, 2.5)
	return m
end

local function buildBrokenStonePillars(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "BrokenStonePillars", cframe, parent)
	addBox(m, cframe, s, "PillarFootL", Vector3.new(2.6, 1.0, 2.6), CFrame.new(-2.0, 0.5, 0), P.STONE_DARK)
	addBox(m, cframe, s, "PillarShaftL", Vector3.new(1.9, 5.2, 1.9), CFrame.new(-2.0, 3.6, 0), P.STONE_MID)
	addMossCap(m, cframe, s, "PillarMossL", Vector3.new(-2.0, 6.32, 0), 1.8, 1.8)
	addBox(m, cframe, s, "PillarFootR", Vector3.new(2.4, 0.9, 2.4), CFrame.new(2.1, 0.45, 0.4), P.STONE_DARK)
	addBox(m, cframe, s, "PillarShaftR", Vector3.new(1.8, 2.8, 1.8), CFrame.new(2.1, 2.3, 0.4), P.STONE_LIGHT)
	addMossCap(m, cframe, s, "PillarMossR", Vector3.new(2.1, 3.82, 0.4), 1.6, 1.6)
	addBox(m, cframe, s, "FallenChunk", Vector3.new(1.6, 1.0, 1.5), CFrame.new(0.2, 0.5, -0.8) * CFrame.Angles(0, 0.35, 0), P.STONE_MID)
	return m
end

-- ============================================================================
-- 5. TERRAIN PROPS (4)
-- ============================================================================

local function buildExposedTreeRoots(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "ExposedTreeRoots", cframe, parent)
	addBox(m, cframe, s, "RootFootL", Vector3.new(1.7, 2.2, 1.6), CFrame.new(-2.5, 1.1, 0), P.MUD_DARK)
	addBox(m, cframe, s, "RootArchMid", Vector3.new(3.8, 1.4, 1.4), CFrame.new(0, 2.9, 0), P.BARK_MID)
	addBox(m, cframe, s, "RootFootR", Vector3.new(1.8, 2.0, 1.7), CFrame.new(2.6, 1.0, 0), P.BARK_DARK)
	addMossCap(m, cframe, s, "ArchMoss", Vector3.new(0, 3.74, 0), 3.2, 1.4)
	addShroom(m, cframe, s, "RootShroom", Vector3.new(-1.4, 0.0, 1.1), 0.5, 0.22, 0.65, P.SHROOM_RED, P.SHROOM_WHITE)
	return m
end

local function buildFallenSwampLog(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "FallenSwampLog", cframe, parent)
	addBox(m, cframe, s, "LogBody", Vector3.new(7.0, 2.0, 2.1), CFrame.new(0, 1.0, 0), P.BARK_MID)
	addBox(m, cframe, s, "LogMudRib", Vector3.new(5.2, 0.45, 2.35), CFrame.new(-0.3, 0.45, 0), P.MUD_DARK)
	addBox(m, cframe, s, "CutRingL", Vector3.new(0.22, 1.5, 1.6), CFrame.new(-3.48, 1.0, 0), P.WOOD_CUT)
	addBox(m, cframe, s, "HollowL", Vector3.new(0.26, 1.0, 1.1), CFrame.new(-3.52, 1.0, 0), P.WOOD_HOLLOW)
	addBox(m, cframe, s, "CutRingR", Vector3.new(0.22, 1.5, 1.6), CFrame.new(3.48, 1.0, 0), P.WOOD_CUT)
	addMossCap(m, cframe, s, "LogMoss", Vector3.new(-0.5, 2.14, 0), 4.0, 1.7)
	addBox(m, cframe, s, "VineWrap", Vector3.new(0.5, 1.4, 2.38), CFrame.new(1.3, 1.3, 0), P.MOSS_BRIGHT)
	addShroom(m, cframe, s, "LogShroom", Vector3.new(1.7, 2.02, 0.25), 0.55, 0.24, 0.68, P.SHROOM_RED, P.SHROOM_WHITE)
	return m
end

local function buildMudCracks(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "MudCracks", cframe, parent)
	addBox(m, cframe, s, "WetSeamBase", Vector3.new(5.2, 0.16, 4.6), CFrame.new(0, 0.08, 0), P.MUD_DARK, nil, true, 0, false)
	for i, pl in ipairs({
		{ pos = Vector3.new(-1.3, 0.2, -1.0), sz = Vector3.new(2.2, 0.16, 1.9), col = P.MUD_MID },
		{ pos = Vector3.new(1.3, 0.22, -0.8), sz = Vector3.new(2.1, 0.18, 2.0), col = P.MUD_WET },
		{ pos = Vector3.new(-1.1, 0.2, 1.2), sz = Vector3.new(2.3, 0.16, 1.8), col = P.MUD_WET },
		{ pos = Vector3.new(1.35, 0.2, 1.2), sz = Vector3.new(1.9, 0.16, 1.7), col = P.MUD_MID },
	}) do
		addBox(m, cframe, s, "Plate_" .. i, pl.sz, CFrame.new(pl.pos), pl.col, nil, true, 0, false)
	end
	addMossCap(m, cframe, s, "CrackMoss", Vector3.new(-0.2, 0.32, 0.1), 1.4, 1.2)
	return m
end

local function buildSmallMudMounds(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "SmallMudMounds", cframe, parent)
	addBox(m, cframe, s, "MoundBot", Vector3.new(5.2, 1.0, 4.4), CFrame.new(0, 0.5, 0), P.MUD_DARK)
	addBox(m, cframe, s, "MoundMid", Vector3.new(3.6, 0.9, 3.0), CFrame.new(-0.2, 1.35, 0.1), P.MUD_MID)
	addMossCap(m, cframe, s, "MoundTopMoss", Vector3.new(-0.2, 1.92, 0.1), 3.2, 2.6)
	addBox(m, cframe, s, "Pebble", Vector3.new(1.2, 0.75, 1.1), CFrame.new(1.6, 0.75, -0.8), P.STONE_MID)
	addBox(m, cframe, s, "Sprout", Vector3.new(0.32, 0.95, 0.32), CFrame.new(-0.8, 2.35, 0.4), P.MOSS_BRIGHT, nil, true, 0, false)
	return m
end

-- ============================================================================
-- 6. DECORATIONS (7)
-- ============================================================================

local function buildSwampWoodenLantern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SwampWoodenLantern", cframe, parent)
	addBox(m, cframe, s, "StoneFoot", Vector3.new(2.2, 1.2, 2.2), CFrame.new(-0.4, 0.6, 0), P.STONE_DARK)
	addMossCap(m, cframe, s, "FootMoss", Vector3.new(-0.4, 1.32, 0), 2.0, 2.0)
	addBox(m, cframe, s, "TimberPost", Vector3.new(0.88, 6.4, 0.88), CFrame.new(-0.4, 4.2, 0), P.BARK_MID)
	addBox(m, cframe, s, "TopArm", Vector3.new(2.8, 0.65, 0.75), CFrame.new(0.65, 7.1, 0), P.BARK_DARK)
	addBox(m, cframe, s, "Chain", Vector3.new(0.22, 0.75, 0.22), CFrame.new(1.6, 6.45, 0), P.LANTERN_IRON)
	addWarmLantern(m, cframe, s, "SwampCageLantern", Vector3.new(1.6, 5.45, 0), 16, 0.92)
	return m
end

local function buildOldWoodenBarrel(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "OldWoodenBarrel", cframe, parent)
	addBox(m, cframe, s, "BasePad", Vector3.new(4.2, 0.22, 3.6), CFrame.new(0, 0.11, 0), P.OLIVE_DARK, nil, true, 0, false)
	for idx, br in ipairs({
		{ pos = Vector3.new(-0.9, 1.2, 0.2), h = 2.1, w = 1.6 },
		{ pos = Vector3.new(0.95, 1.0, -0.55), h = 1.7, w = 1.4 },
	}) do
		addBox(m, cframe, s, "BarrelBody_" .. idx, Vector3.new(br.w, br.h, br.w), CFrame.new(br.pos), P.BARK_WARM)
		addBox(m, cframe, s, "IronHoopA_" .. idx, Vector3.new(br.w + 0.14, 0.24, br.w + 0.14), CFrame.new(br.pos + Vector3.new(0, br.h * 0.28, 0)), P.LANTERN_IRON)
		addBox(m, cframe, s, "IronHoopB_" .. idx, Vector3.new(br.w + 0.14, 0.24, br.w + 0.14), CFrame.new(br.pos + Vector3.new(0, -br.h * 0.26, 0)), P.LANTERN_IRON)
	end
	addBox(m, cframe, s, "SwampCrate", Vector3.new(1.5, 1.4, 1.5), CFrame.new(0.7, 0.85, 0.95) * CFrame.Angles(0, 0.28, 0), P.BARK_MID)
	addMossCap(m, cframe, s, "BarrelMoss", Vector3.new(-0.9, 2.38, 0.2), 1.1, 1.1)
	return m
end

local function buildBrokenWoodenCart(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "BrokenWoodenCart", cframe, parent)
	-- Slanted weathered wooden hand-cart with voxel wheels and mossy cargo
	local tilt = CFrame.Angles(0, 0, math.rad(-8))
	addBox(m, cframe, s, "CartBed", Vector3.new(4.8, 0.45, 3.0), CFrame.new(0, 1.5, 0) * tilt, P.BARK_MID)
	addBox(m, cframe, s, "SideRailL", Vector3.new(4.6, 1.4, 0.35), CFrame.new(0, 2.2, 1.35) * tilt, P.BARK_WARM)
	addBox(m, cframe, s, "SideRailR", Vector3.new(3.4, 1.3, 0.35), CFrame.new(-0.5, 2.15, -1.35) * tilt, P.BARK_DARK)
	addBox(m, cframe, s, "TailGate", Vector3.new(0.35, 1.4, 2.8), CFrame.new(-2.25, 2.2, 0) * tilt, P.BARK_WARM)
	addBox(m, cframe, s, "HandleL", Vector3.new(2.2, 0.32, 0.32), CFrame.new(3.1, 1.0, 1.1) * CFrame.Angles(0, 0, math.rad(-18)), P.BARK_DARK)
	addBox(m, cframe, s, "HandleR", Vector3.new(2.2, 0.32, 0.32), CFrame.new(3.1, 1.0, -1.1) * CFrame.Angles(0, 0, math.rad(-18)), P.BARK_DARK)
	for _, zSide in ipairs({ -1.65, 1.65 }) do
		addBox(m, cframe, s, "WheelOuter", Vector3.new(2.2, 2.2, 0.36), CFrame.new(-0.4, 1.1, zSide), P.BARK_DARK)
		addBox(m, cframe, s, "WheelHub", Vector3.new(0.8, 0.8, 0.48), CFrame.new(-0.4, 1.1, zSide), P.LANTERN_IRON)
	end
	addBox(m, cframe, s, "MossCargoA", Vector3.new(3.2, 1.0, 2.1), CFrame.new(-0.3, 2.35, 0) * tilt, P.OLIVE_MID)
	addBox(m, cframe, s, "MossCargoB", Vector3.new(2.0, 0.75, 1.5), CFrame.new(-0.7, 3.05, 0.2) * tilt, P.MOSS_BRIGHT)
	return m
end

local function buildSwampMushrooms(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SwampMushrooms", cframe, parent)
	addBox(m, cframe, s, "MudTurf", Vector3.new(3.2, 0.24, 2.8), CFrame.new(0, 0.12, 0), P.OLIVE_DARK, nil, true, 0, false)
	addShroom(m, cframe, s, "HeroRed", Vector3.new(-0.25, 0.22, 0), 2.1, 0.68, 2.2, P.SHROOM_RED, P.SHROOM_WHITE)
	addShroom(m, cframe, s, "SideRed", Vector3.new(1.05, 0.22, 0.45), 1.05, 0.38, 1.15, P.SHROOM_RED, P.SHROOM_WHITE)
	addShroom(m, cframe, s, "PurpleMini", Vector3.new(-1.15, 0.22, -0.5), 0.75, 0.28, 0.85, P.PURPLE_BRIGHT, P.PURPLE_GLOW)
	return m
end

local function buildWoodenSignpost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenSignpost", cframe, parent)
	addBox(m, cframe, s, "MudBase", Vector3.new(2.0, 0.45, 2.0), CFrame.new(0, 0.22, 0), P.MUD_MID)
	addMossCap(m, cframe, s, "BaseMoss", Vector3.new(-0.2, 0.56, 0.2), 1.7, 1.7)
	addBox(m, cframe, s, "PostShaft", Vector3.new(0.75, 5.2, 0.75), CFrame.new(0, 2.9, 0), P.BARK_DARK)
	addBox(m, cframe, s, "BoardTop", Vector3.new(3.2, 1.05, 0.36), CFrame.new(0.2, 4.7, 0.4) * CFrame.Angles(0, 0.1, 0), P.BARK_WARM)
	addBox(m, cframe, s, "BoardLow", Vector3.new(2.8, 0.9, 0.36), CFrame.new(-0.2, 3.55, 0.4) * CFrame.Angles(0, -0.14, 0), P.BARK_MID)
	addBox(m, cframe, s, "SignMoss", Vector3.new(1.4, 0.28, 0.42), CFrame.new(0.5, 5.32, 0.4), P.MOSS_BRIGHT)
	return m
end

local function buildSwampCrystalCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SwampCrystalCluster", cframe, parent)
	addBox(m, cframe, s, "RockBed", Vector3.new(3.4, 0.7, 3.2), CFrame.new(0, 0.35, 0), P.STONE_DARK)
	addMossCap(m, cframe, s, "RockMoss", Vector3.new(-0.4, 0.82, 0.2), 2.8, 2.6)
	local core = addBox(m, cframe, s, "CrystalMain", Vector3.new(1.15, 3.6, 1.15), CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0.3, math.rad(-8)), P.PURPLE_GLOW, Enum.Material.Neon, false, 0.12, false)
	addBox(m, cframe, s, "CrystalMainShell", Vector3.new(1.38, 3.2, 1.38), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0.3, math.rad(-8)), P.PURPLE_BRIGHT, Enum.Material.Glass, false, 0.35, false)
	addBox(m, cframe, s, "CrystalL", Vector3.new(0.85, 2.4, 0.85), CFrame.new(-0.95, 1.5, 0.25) * CFrame.Angles(0, 0, math.rad(22)), P.PURPLE_DEEP, Enum.Material.Glass, false, 0.28, false)
	addBox(m, cframe, s, "CrystalR", Vector3.new(0.8, 2.0, 0.8), CFrame.new(0.95, 1.3, -0.25) * CFrame.Angles(0, 0, math.rad(-24)), P.PURPLE_GLOW, Enum.Material.Neon, false, 0.16, false)
	local pl = Instance.new("PointLight")
	pl.Name = "CrystalGlow"
	pl.Color = P.PURPLE_BRIGHT
	pl.Range = 12
	pl.Brightness = 0.6
	pl.Shadows = false
	pl.Parent = core
	return m
end

local function buildSwampLanternFence(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SwampLanternFence", cframe, parent)
	addBox(m, cframe, s, "StoneFoot", Vector3.new(1.8, 0.85, 1.8), CFrame.new(0, 0.42, 0), P.STONE_DARK)
	addBox(m, cframe, s, "LanternPost", Vector3.new(0.88, 4.3, 0.88), CFrame.new(0, 2.55, 0), P.BARK_DARK)
	addWarmLantern(m, cframe, s, "FenceLantern", Vector3.new(0, 5.2, 0), 16, 0.88)
	for _, zOff in ipairs({ -3.3, 3.3 }) do
		addBox(m, cframe, s, "EndPost", Vector3.new(0.65, 2.5, 0.65), CFrame.new(0, 1.25, zOff), P.BARK_DARK)
	end
	addBox(m, cframe, s, "RailTop", Vector3.new(0.36, 0.36, 7.0), CFrame.new(0, 2.05, 0), P.BARK_WARM)
	addBox(m, cframe, s, "RailBot", Vector3.new(0.36, 0.36, 7.0), CFrame.new(0, 1.15, 0), P.BARK_MID)
	addMossCap(m, cframe, s, "FenceMoss", Vector3.new(0.4, 0.25, 1.2), 1.4, 2.0)
	return m
end

-- ============================================================================
-- 7. STRUCTURES (4)
-- ============================================================================

local function buildAbandonedSwampBridge(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "AbandonedSwampBridge", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	-- Arched plank bridge extending along local X (-6.4..6.4)
	for _, px in ipairs({ -5.2, 0, 5.2 }) do
		for _, pz in ipairs({ -2.2, 2.2 }) do
			addBox(m, cframe, s, "BridgeStilt", Vector3.new(0.75, 2.4, 0.75), CFrame.new(px, 1.2, pz), P.BARK_DARK)
		end
	end
	for idx = -4, 4 do
		local archY = 1.05 + math.cos(idx * 0.32) * 0.75
		local pCol = if idx % 2 == 0 then P.BARK_MID else P.BARK_WARM
		addBox(m, cframe, s, "BridgePlank_" .. idx, Vector3.new(1.32, 0.38, 4.8), CFrame.new(idx * 1.45, archY, 0), pCol)
	end
	for _, zSide in ipairs({ -2.2, 2.2 }) do
		addBox(m, cframe, s, "BridgeRail", Vector3.new(11.6, 0.36, 0.38), CFrame.new(0, 2.75, zSide), P.BARK_DARK)
	end
	addMossCap(m, cframe, s, "BridgeMossA", Vector3.new(-2.0, 1.92, 1.8), 2.0, 1.1)
	addMossCap(m, cframe, s, "BridgeMossB", Vector3.new(2.2, 1.85, -1.8), 1.8, 1.1)

	-- Twin glowing warm yellow bridge post lanterns
	for i, endX in ipairs({ -5.2, 5.2 }) do
		addBox(m, cframe, s, "LampPost_" .. i, Vector3.new(0.72, 2.0, 0.72), CFrame.new(endX, 2.6, 2.2), P.BARK_DARK)
		addWarmLantern(m, cframe, s, "BridgeLamp_" .. i, Vector3.new(endX, 4.15, 2.2), 16, 0.88)
	end
	return m
end

local function buildAncientSwampRuins(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "AncientSwampRuins", cframe, parent)

	for _, xSide in ipairs({ -4.5, 4.5 }) do
		addBox(m, cframe, s, "Plinth", Vector3.new(3.6, 1.3, 3.2), CFrame.new(xSide, 0.65, 0), P.STONE_DARK)
		addBox(m, cframe, s, "PierCore", Vector3.new(2.4, 7.2, 2.4), CFrame.new(xSide, 4.8, 0), P.STONE_MID)
		addBox(m, cframe, s, "PierStep", Vector3.new(2.8, 1.4, 2.8), CFrame.new(xSide, 8.6, 0), P.STONE_LIGHT)
		addMossCap(m, cframe, s, "BaseMoss", Vector3.new(xSide * 0.85, 1.42, 0.7), 2.0, 1.6)
	end
	addBox(m, cframe, s, "ArchLintel", Vector3.new(12.2, 2.0, 2.6), CFrame.new(0, 9.8, 0), P.STONE_MID)
	addBox(m, cframe, s, "ArchCrown", Vector3.new(7.4, 1.4, 2.2), CFrame.new(-1.0, 11.4, 0), P.STONE_LIGHT)
	addBox(m, cframe, s, "WingPier", Vector3.new(2.4, 4.6, 2.2), CFrame.new(7.4, 2.3, 0.2), P.STONE_DARK)
	addBox(m, cframe, s, "Rubble", Vector3.new(1.8, 0.9, 1.5), CFrame.new(1.5, 0.45, 1.2) * CFrame.Angles(0, 0.35, 0), P.STONE_LIGHT)

	addMossCap(m, cframe, s, "LintelMossL", Vector3.new(-2.4, 12.24, 0), 4.4, 2.2)
	addMossCap(m, cframe, s, "WingMoss", Vector3.new(7.4, 4.74, 0.2), 2.2, 2.0)
	addSwampVine(m, cframe, s, "RuinVineA", Vector3.new(-1.6, 8.9, 1.2), 3.6)
	addSwampVine(m, cframe, s, "RuinVineB", Vector3.new(2.0, 8.9, -1.1), 3.0)
	return m
end

local function buildSwampWoodenWatchtower(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "SwampWoodenWatchtower", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "StoneFoundL", Vector3.new(6.6, 1.5, 6.6), CFrame.new(0, 0.75, 0), P.STONE_DARK)
	addMossCap(m, cframe, s, "FoundMoss", Vector3.new(-1.6, 1.65, 1.4), 2.4, 2.4)
	for _, px in ipairs({ -2.2, 2.2 }) do
		for _, pz in ipairs({ -2.2, 2.2 }) do
			addBox(m, cframe, s, "TowerPost", Vector3.new(0.95, 9.6, 0.95), CFrame.new(px, 6.2, pz), P.BARK_DARK)
		end
	end
	addBox(m, cframe, s, "CrossBeamF", Vector3.new(5.2, 0.65, 0.75), CFrame.new(0, 4.4, 2.2), P.BARK_MID)
	addBox(m, cframe, s, "ObsDeck", Vector3.new(7.4, 0.75, 7.4), CFrame.new(0, 8.2, 0), P.BARK_WARM)
	for _, r in ipairs({
		{ sz = Vector3.new(7.4, 0.45, 0.45), off = Vector3.new(0, 9.7, -3.4) },
		{ sz = Vector3.new(7.4, 0.45, 0.45), off = Vector3.new(0, 9.7, 3.4) },
		{ sz = Vector3.new(0.45, 0.45, 7.4), off = Vector3.new(-3.4, 9.7, 0) },
		{ sz = Vector3.new(0.45, 0.45, 7.4), off = Vector3.new(3.4, 9.7, 0) },
	}) do
		addBox(m, cframe, s, "Rail", r.sz, CFrame.new(r.off), P.BARK_DARK)
	end
	for _, px in ipairs({ -2.4, 2.4 }) do
		for _, pz in ipairs({ -2.4, 2.4 }) do
			addBox(m, cframe, s, "RoofPost", Vector3.new(0.7, 3.4, 0.7), CFrame.new(px, 10.4, pz), P.BARK_DARK)
		end
	end
	addBox(m, cframe, s, "RoofT1", Vector3.new(8.2, 0.9, 8.2), CFrame.new(0, 12.4, 0), P.BARK_MID)
	addBox(m, cframe, s, "RoofT2", Vector3.new(5.6, 0.9, 5.6), CFrame.new(0, 13.3, 0), P.OLIVE_DARK)
	addBox(m, cframe, s, "RoofT3", Vector3.new(3.0, 0.85, 3.0), CFrame.new(0, 14.1, 0), P.MOSS_BRIGHT)

	addWarmLantern(m, cframe, s, "TowerHeartLamp", Vector3.new(0, 10.4, 0), 20, 1.0)
	addSwampVine(m, cframe, s, "TowerVineL", Vector3.new(-3.4, 11.8, 2.6), 3.6)
	addSwampVine(m, cframe, s, "TowerVineR", Vector3.new(3.4, 11.8, -2.4), 3.2)
	return m
end

local function buildSwampStiltCabin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "SwampStiltCabin", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	for _, px in ipairs({ -4.8, 0, 4.8 }) do
		for _, pz in ipairs({ -3.8, 3.8 }) do
			addBox(m, cframe, s, "MudStilt", Vector3.new(0.85, 2.2, 0.85), CFrame.new(px, 1.1, pz), P.BARK_DARK)
		end
	end
	addBox(m, cframe, s, "PorchDeck", Vector3.new(11.4, 0.65, 9.4), CFrame.new(0, 2.1, 0), P.BARK_MID)
	addBox(m, cframe, s, "PorchRail", Vector3.new(0.45, 1.4, 5.2), CFrame.new(-5.2, 3.1, 1.4), P.BARK_DARK)

	-- Stone base + warm wood cabin body + cozy glowing window & front eave lantern
	addBox(m, cframe, s, "CabinStone", Vector3.new(7.4, 1.8, 6.2), CFrame.new(1.2, 3.3, 0), P.STONE_MID)
	addBox(m, cframe, s, "CabinWood", Vector3.new(7.2, 2.6, 6.0), CFrame.new(1.2, 5.3, 0), P.BARK_WARM)
	addBox(m, cframe, s, "GlowWindow", Vector3.new(0.35, 1.5, 1.8), CFrame.new(-2.45, 4.8, -1.2), P.LANTERN_GLOW, Enum.Material.Neon, false, 0, false)
	addBox(m, cframe, s, "RoofLower", Vector3.new(9.2, 1.0, 7.8), CFrame.new(1.2, 7.0, 0), P.BARK_DARK)
	addBox(m, cframe, s, "RoofMidMoss", Vector3.new(7.0, 1.1, 6.0), CFrame.new(1.2, 8.0, 0), P.OLIVE_MID)
	addBox(m, cframe, s, "RoofTopMoss", Vector3.new(4.2, 0.95, 4.0), CFrame.new(1.2, 8.95, 0), P.MOSS_BRIGHT)

	addBox(m, cframe, s, "EaveBeam", Vector3.new(1.8, 0.45, 0.45), CFrame.new(-3.2, 6.5, 2.2), P.BARK_DARK)
	addWarmLantern(m, cframe, s, "PorchLantern", Vector3.new(-3.8, 5.35, 2.2), 18, 0.95)
	addSwampVine(m, cframe, s, "CabinVineA", Vector3.new(-3.0, 6.4, -2.6), 3.4)
	addSwampVine(m, cframe, s, "CabinVineB", Vector3.new(5.2, 6.4, 2.8), 3.0)
	return m
end

-- ============================================================================
-- 8. WATER FEATURES (6)
-- ============================================================================

local function buildMuddyWaterPool(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "MuddyWaterPool", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "MudRim", Vector3.new(12.8, 0.3, 10.6), CFrame.new(0, 0.15, 0), P.MUD_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(10.0, 0.18, 8.0), CFrame.new(0, 0.14, 0), P.WATER_BED, Enum.Material.SmoothPlastic, false, 0, false)
	local water = addBox(m, cframe, s, "SwampWater", Vector3.new(9.8, 0.34, 7.8), CFrame.new(0, 0.38, 0), P.WATER_MUD, Enum.Material.Glass, false, 0.24, false)
	addMudBubbleEmitter(water, 4)

	for i, st in ipairs({
		{ pos = Vector3.new(-5.2, 0.65, -2.0), sz = Vector3.new(2.2, 1.1, 2.8) },
		{ pos = Vector3.new(5.1, 0.6, 2.2), sz = Vector3.new(2.2, 1.0, 2.6) },
		{ pos = Vector3.new(-2.4, 0.5, 4.2), sz = Vector3.new(3.0, 0.8, 1.6) },
		{ pos = Vector3.new(2.2, 0.55, -4.3), sz = Vector3.new(3.2, 0.9, 1.6) },
	}) do
		addBox(m, cframe, s, "PoolRock_" .. i, st.sz, CFrame.new(st.pos), if i % 2 == 0 then P.STONE_MID else P.MUD_MID, nil, true, 0, false)
		addMossCap(m, cframe, s, "PoolMoss_" .. i, Vector3.new(st.pos.X, st.pos.Y + st.sz.Y * 0.5 + 0.12, st.pos.Z), st.sz.X * 0.75, st.sz.Z * 0.75)
	end

	addLilyPad(m, cframe, s, "PoolLilyA", Vector3.new(-2.0, 0.6, -1.2), 1.65, 18, P.LOTUS_PINK)
	addLilyPad(m, cframe, s, "PoolLilyB", Vector3.new(-0.2, 0.6, 1.8), 1.4, -28, nil)

	-- Tiny weathered wooden rowboat moored at pool edge (matching Water Features reference!)
	local boatCF = CFrame.new(2.3, 0.58, -1.3) * CFrame.Angles(0, math.rad(-22), 0)
	addBox(m, cframe, s, "BoatHull", Vector3.new(3.2, 0.45, 1.55), boatCF, P.BARK_MID)
	addBox(m, cframe, s, "BoatRimL", Vector3.new(3.0, 0.35, 0.25), boatCF * CFrame.new(0, 0.35, 0.65), P.BARK_WARM)
	addBox(m, cframe, s, "BoatRimR", Vector3.new(3.0, 0.35, 0.25), boatCF * CFrame.new(0, 0.35, -0.65), P.BARK_WARM)
	addBox(m, cframe, s, "BoatBench", Vector3.new(0.45, 0.28, 1.25), boatCF * CFrame.new(-0.2, 0.32, 0), P.BARK_DARK)

	for i = 1, 2 do
		local rCF = CFrame.new(-0.8, 0.56, 0.4)
		local r = addBox(m, cframe, s, "RippleRing_" .. i, Vector3.new(2.2, 0.08, 1.8), rCF, P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 0.45, false)
		r:SetAttribute("AnimKind", "RippleRing")
		r:SetAttribute("BaseLocalCF", rCF)
		r:SetAttribute("Phase", (i - 1) * 0.5)
		r:SetAttribute("Speed", 0.52)
	end
	return m
end

local function buildSwampLilyPads(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SwampLilyPads", cframe, parent)
	addLilyPad(m, cframe, s, "LilyA", Vector3.new(-1.3, 0.14, -0.6), 2.1, 16, P.LOTUS_PINK)
	addLilyPad(m, cframe, s, "LilyB", Vector3.new(1.5, 0.14, 0.7), 1.8, -22, P.PURPLE_BRIGHT)
	addLilyPad(m, cframe, s, "LilyC", Vector3.new(0.2, 0.14, -1.6), 1.5, 38, nil)
	addLilyPad(m, cframe, s, "LilyD", Vector3.new(-1.8, 0.14, 1.5), 1.35, -40, nil)
	return m
end

local function buildSmallSwampWaterfall(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SmallSwampWaterfall", cframe, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "PoolTurf", Vector3.new(12.0, 0.32, 12.4), CFrame.new(0, 0.16, 0.4), P.OLIVE_DARK, nil, true, 0, false)
	addBox(m, cframe, s, "PoolBed", Vector3.new(8.8, 0.18, 6.8), CFrame.new(0, 0.16, 2.0), P.WATER_BED, Enum.Material.SmoothPlastic, false, 0, false)
	addBox(m, cframe, s, "SwampPoolWater", Vector3.new(8.6, 0.34, 6.6), CFrame.new(0, 0.4, 2.0), P.WATER_MUD, Enum.Material.Glass, false, 0.24, false)

	addBox(m, cframe, s, "CliffL", Vector3.new(3.4, 5.2, 3.6), CFrame.new(-2.8, 2.6, -3.2), P.STONE_MID)
	addBox(m, cframe, s, "CliffR", Vector3.new(3.2, 4.6, 3.4), CFrame.new(2.7, 2.3, -3.2), P.STONE_DARK)
	addBox(m, cframe, s, "CliffBack", Vector3.new(4.2, 4.8, 2.6), CFrame.new(0, 2.4, -3.8), P.MUD_MID)
	addMossCap(m, cframe, s, "CliffMossL", Vector3.new(-2.8, 5.34, -3.2), 3.1, 3.3)
	addMossCap(m, cframe, s, "CliffMossR", Vector3.new(2.7, 4.74, -3.2), 2.9, 3.1)

	for i, st in ipairs({
		{ pos = Vector3.new(-4.8, 0.65, 2.0), sz = Vector3.new(2.0, 1.1, 2.6) },
		{ pos = Vector3.new(4.8, 0.65, 2.2), sz = Vector3.new(2.0, 1.1, 2.6) },
		{ pos = Vector3.new(-2.0, 0.45, 5.4), sz = Vector3.new(2.6, 0.8, 1.5) },
	}) do
		addBox(m, cframe, s, "RimStone_" .. i, st.sz, CFrame.new(st.pos), P.STONE_MID, nil, true, 0, false)
		addMossCap(m, cframe, s, "RimMoss_" .. i, Vector3.new(st.pos.X, st.pos.Y + st.sz.Y * 0.5 + 0.12, st.pos.Z), st.sz.X * 0.75, st.sz.Z * 0.75)
	end
	addLilyPad(m, cframe, s, "SwampFallLilyA", Vector3.new(-1.4, 0.62, 2.5), 1.65, 20, P.LOTUS_PINK)
	addLilyPad(m, cframe, s, "SwampFallLilyB", Vector3.new(1.8, 0.62, 3.0), 1.4, -25, nil)

	-- Cascade water stream & animated downward segments + splash foam & mist
	addBox(m, cframe, s, "CrestPool", Vector3.new(2.8, 0.34, 2.0), CFrame.new(0, 4.95, -2.7), P.WATER_FALL, Enum.Material.Glass, false, 0.25, false)
	addBox(m, cframe, s, "CascadeCore", Vector3.new(2.6, 4.4, 0.52), CFrame.new(0, 2.75, -1.75), P.WATER_FALL, Enum.Material.Glass, false, 0.34, false)
	addBox(m, cframe, s, "SplashFoam", Vector3.new(2.8, 0.4, 1.1), CFrame.new(0, 0.58, -1.05), P.WATER_FOAM, nil, true, 0.16, false)

	for i = 1, 5 do
		local lx = ((i % 3) - 1) * 0.5
		local w = if i % 2 == 0 then 1.05 else 1.35
		local seg = addBox(m, cframe, s, "WaterSeg_" .. i, Vector3.new(w, 1.1, 0.34), CFrame.new(lx, 2.7, -1.52), P.WATER_FALL, Enum.Material.Glass, false, 0.22, false)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", lx)
		seg:SetAttribute("LocalZ", -1.52)
		seg:SetAttribute("StartVal", 4.8)
		seg:SetAttribute("EndVal", 0.7)
		seg:SetAttribute("Speed", 0.58 + (i % 3) * 0.05)
		seg:SetAttribute("Phase", (i - 1) / 5)
		seg:SetAttribute("BaseTransparency", 0.22)
	end
	for i = 1, 2 do
		local crest = addBox(m, cframe, s, "CrestSeg_" .. i, Vector3.new(1.8, 0.24, 0.8), CFrame.new(0, 5.08, -2.5), P.WATER_FOAM, Enum.Material.Glass, false, 0.28, false)
		crest:SetAttribute("FlowAxis", "Forward")
		crest:SetAttribute("LocalX", if i == 1 then -0.28 else 0.28)
		crest:SetAttribute("LocalY", 5.08)
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
		drop:SetAttribute("StartY", 4.75)
		drop:SetAttribute("EndY", 0.58)
		drop:SetAttribute("OutArcZ", 0.75)
		drop:SetAttribute("Speed", 0.68 + i * 0.06)
		drop:SetAttribute("Phase", (i - 1) / 3)
		drop:SetAttribute("BaseTransparency", 0.2)
	end
	for i = 1, 2 do
		local ripCF = CFrame.new(0, 0.56, -0.5)
		local rip = addBox(m, cframe, s, "RippleRing_" .. i, Vector3.new(2.2, 0.08, 1.8), ripCF, P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 0.45, false)
		rip:SetAttribute("AnimKind", "RippleRing")
		rip:SetAttribute("BaseLocalCF", ripCF)
		rip:SetAttribute("Phase", (i - 1) * 0.5)
		rip:SetAttribute("Speed", 0.58)
	end

	local splashAnchor = addBox(m, cframe, s, "SplashAnchor", Vector3.new(2.4, 0.28, 1.1), CFrame.new(0, 0.64, -0.95), P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 1, false)
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "SwampSplashDroplets"
	spray.Color = ColorSequence.new(P.WATER_FOAM, P.WATER_FALL)
	spray.Rate = 9
	spray.Lifetime = NumberRange.new(0.45, 0.85)
	spray.Speed = NumberRange.new(2.2, 4.6)
	spray.SpreadAngle = Vector2.new(50, 50)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.26 * s), NumberSequenceKeypoint.new(1, 0.05 * s) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	spray.Parent = splashAnchor

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "SwampWaterfallMist"
	mist.Color = ColorSequence.new(Color3.fromRGB(214, 244, 252), P.WATER_FOAM)
	mist.Rate = 5
	mist.Lifetime = NumberRange.new(1.0, 1.8)
	mist.Speed = NumberRange.new(0.8, 2.0)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75 * s), NumberSequenceKeypoint.new(1, 2.0 * s) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	mist.Parent = splashAnchor

	return m
end

local function buildMudBubblePatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "MudBubblePatch", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "MudRim", Vector3.new(4.4, 0.24, 4.2), CFrame.new(0, 0.12, 0), P.MUD_DARK, nil, true, 0, false)
	local pool = addBox(m, cframe, s, "BubbleSurface", Vector3.new(3.4, 0.26, 3.2), CFrame.new(0, 0.2, 0), P.MUD_WET, Enum.Material.SmoothPlastic, false, 0.15, false)
	addMudBubbleEmitter(pool, 5)
	for i = 1, 2 do
		local rCF = CFrame.new(0, 0.36, 0)
		local r = addBox(m, cframe, s, "RippleRing_" .. i, Vector3.new(1.8, 0.08, 1.8), rCF, Color3.fromRGB(162, 136, 92), Enum.Material.SmoothPlastic, false, 0.45, false)
		r:SetAttribute("AnimKind", "RippleRing")
		r:SetAttribute("BaseLocalCF", rCF)
		r:SetAttribute("Phase", (i - 1) * 0.5)
		r:SetAttribute("Speed", 0.56)
	end
	return m
end

local function buildSwampWaterRipples(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SwampWaterRipples", cframe, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, cframe, s, "CenterBud", Vector3.new(0.65, 0.18, 0.65), CFrame.new(0, 0.09, 0), P.LOTUS_PINK, nil, true, 0, false)
	for i = 1, 3 do
		local rCF = CFrame.new(0, 0.06, 0)
		local r = addBox(m, cframe, s, "RippleRing_" .. i, Vector3.new(2.0, 0.08, 1.8), rCF, P.WATER_FOAM, Enum.Material.SmoothPlastic, false, 0.45, false)
		r:SetAttribute("AnimKind", "RippleRing")
		r:SetAttribute("BaseLocalCF", rCF)
		r:SetAttribute("Phase", (i - 1) / 3)
		r:SetAttribute("Speed", 0.48)
	end
	return m
end

local function buildFloatingSwampLeaves(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "FloatingSwampLeaves", cframe, parent)
	for i, lf in ipairs({
		{ pos = Vector3.new(-1.1, 0.07, -0.7), sz = Vector3.new(0.85, 0.1, 0.55), yaw = 22, col = P.OLIVE_MID },
		{ pos = Vector3.new(0.9, 0.07, -0.4), sz = Vector3.new(0.75, 0.1, 0.5), yaw = -35, col = P.AUTUMN_LEAF },
		{ pos = Vector3.new(-0.3, 0.07, 0.9), sz = Vector3.new(0.95, 0.1, 0.6), yaw = 48, col = P.MOSS_BRIGHT },
		{ pos = Vector3.new(1.4, 0.07, 1.1), sz = Vector3.new(0.65, 0.1, 0.45), yaw = -12, col = P.AUTUMN_LEAF },
		{ pos = Vector3.new(-1.6, 0.07, 0.6), sz = Vector3.new(1.5, 0.14, 0.24), yaw = 16, col = P.BARK_MID },
	}) do
		addBox(m, cframe, s, "Leaf_" .. i, lf.sz, CFrame.new(lf.pos) * CFrame.Angles(0, math.rad(lf.yaw), 0), lf.col, nil, true, 0, false)
	end
	return m
end

-- ============================================================================
-- CATALOG & SERVERSTORAGE LIBRARY MANAGEMENT (40 ASSETS)
-- ============================================================================

MudBiomeAssetBuilder.Catalog = {
	Trees = {
		{ name = "GiantSwampTree", category = "Trees", build = buildGiantSwampTree },
		{ name = "DeadSwampTree", category = "Trees", build = buildDeadSwampTree },
		{ name = "WillowTree", category = "Trees", build = buildWillowTree },
		{ name = "SmallMudlandTree", category = "Trees", build = buildSmallMudlandTree },
		{ name = "MossCoveredTree", category = "Trees", build = buildMossCoveredTree },
	},
	Bushes = {
		{ name = "MudBush_Dense", category = "Bushes", build = buildMudBush_Dense },
		{ name = "MossBush_Lush", category = "Bushes", build = buildMossBush_Lush },
		{ name = "ToxicBush_SwampGlow", category = "Bushes", build = buildToxicBush_SwampGlow },
	},
	Plants = {
		{ name = "SwampFern", category = "Plants", build = buildSwampFern },
		{ name = "TallReeds", category = "Plants", build = buildTallReeds },
		{ name = "Cattails", category = "Plants", build = buildCattails },
		{ name = "SwampGrass", category = "Plants", build = buildSwampGrass },
		{ name = "HangingVines", category = "Plants", build = buildHangingVines },
		{ name = "PurpleSwampFlowers", category = "Plants", build = buildPurpleSwampFlowers },
		{ name = "ToxicGreenPlants", category = "Plants", build = buildToxicGreenPlants },
	},
	Rocks = {
		{ name = "MuddyBoulder", category = "Rocks", build = buildMuddyBoulder },
		{ name = "MossyRock", category = "Rocks", build = buildMossyRock },
		{ name = "AncientStone", category = "Rocks", build = buildAncientStone },
		{ name = "BrokenStonePillars", category = "Rocks", build = buildBrokenStonePillars },
	},
	TerrainProps = {
		{ name = "ExposedTreeRoots", category = "TerrainProps", build = buildExposedTreeRoots },
		{ name = "FallenSwampLog", category = "TerrainProps", build = buildFallenSwampLog },
		{ name = "MudCracks", category = "TerrainProps", build = buildMudCracks },
		{ name = "SmallMudMounds", category = "TerrainProps", build = buildSmallMudMounds },
	},
	Decorations = {
		{ name = "SwampWoodenLantern", category = "Decorations", build = buildSwampWoodenLantern },
		{ name = "OldWoodenBarrel", category = "Decorations", build = buildOldWoodenBarrel },
		{ name = "BrokenWoodenCart", category = "Decorations", build = buildBrokenWoodenCart },
		{ name = "SwampMushrooms", category = "Decorations", build = buildSwampMushrooms },
		{ name = "WoodenSignpost", category = "Decorations", build = buildWoodenSignpost },
		{ name = "SwampCrystalCluster", category = "Decorations", build = buildSwampCrystalCluster },
		{ name = "SwampLanternFence", category = "Decorations", build = buildSwampLanternFence },
	},
	Structures = {
		{ name = "AbandonedSwampBridge", category = "Structures", build = buildAbandonedSwampBridge },
		{ name = "AncientSwampRuins", category = "Structures", build = buildAncientSwampRuins },
		{ name = "SwampWoodenWatchtower", category = "Structures", build = buildSwampWoodenWatchtower },
		{ name = "SwampStiltCabin", category = "Structures", build = buildSwampStiltCabin },
	},
	WaterFeatures = {
		{ name = "MuddyWaterPool", category = "WaterFeatures", build = buildMuddyWaterPool },
		{ name = "SwampLilyPads", category = "WaterFeatures", build = buildSwampLilyPads },
		{ name = "SmallSwampWaterfall", category = "WaterFeatures", build = buildSmallSwampWaterfall },
		{ name = "MudBubblePatch", category = "WaterFeatures", build = buildMudBubblePatch },
		{ name = "SwampWaterRipples", category = "WaterFeatures", build = buildSwampWaterRipples },
		{ name = "FloatingSwampLeaves", category = "WaterFeatures", build = buildFloatingSwampLeaves },
	},
}

local EXPECTED_LIBRARY_VERSION = 1

function MudBiomeAssetBuilder.EnsureLibrary(parentOverride: Instance?): Folder
	local rootParent: Instance = parentOverride or ServerStorage
	local existing = rootParent:FindFirstChild("MudBiomeAssets")
	if existing and existing:IsA("Folder") and existing:GetAttribute("LibraryVersion") == EXPECTED_LIBRARY_VERSION then
		local complete = true
		for _, catName in ipairs(MudBiomeAssetBuilder.CATEGORIES) do
			local sub = existing:FindFirstChild(catName)
			local list = (MudBiomeAssetBuilder.Catalog :: any)[catName]
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
	lib.Name = "MudBiomeAssets"
	lib:SetAttribute("BiomeId", "MangroveSwamp")
	lib:SetAttribute("LibraryVersion", EXPECTED_LIBRARY_VERSION)

	local totalCount = 0
	for _, catName in ipairs(MudBiomeAssetBuilder.CATEGORIES) do
		local catFolder = Instance.new("Folder")
		catFolder.Name = catName
		local list = (MudBiomeAssetBuilder.Catalog :: any)[catName] :: { AssetEntry }
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

function MudBiomeAssetBuilder.SpawnFromLibrary(
	category: string,
	assetName: string,
	cframe: CFrame,
	scale: number?,
	parent: Instance?
): Model
	local lib = MudBiomeAssetBuilder.EnsureLibrary()
	local catFolder = lib:FindFirstChild(category)
	local template = if catFolder then catFolder:FindFirstChild(assetName) else nil
	if not template or not template:IsA("Model") then
		error(string.format("[MudBiomeAssetBuilder] Asset '%s/%s' not found in MudBiomeAssets", category, assetName))
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

return MudBiomeAssetBuilder
