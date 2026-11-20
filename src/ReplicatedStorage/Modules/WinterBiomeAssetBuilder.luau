--!strict
-- WinterBiomeAssetBuilder.luau
-- 55-Asset Voxel Winter / Snow Biome Asset Pack for AlpinePeaks matching visual reference.
-- Builds ServerStorage.WinterBiomeAssets organized into 11 clean subfolders:
-- Trees (7), Bushes (3), Plants (5), Rocks (4), IceCrystals (3), TerrainProps (2),
-- Ruins (4), Structures (5), Decorations (10), WaterFeatures (8), EnvironmentalEffects (4).
-- Pure rectangular Studs/Ice/Glass/Neon/SmoothPlastic Parts, Anchored = true, CanCollide/CanQuery/CanTouch = false,
-- PrimaryPart = RootPivot at ground origin CFrame.identity.

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ClassicStudBiomeBuilder = require(script.Parent.ClassicStudBiomeBuilder)

local WinterBiomeAssetBuilder = {}

export type AssetBuilderFn = (cframe: CFrame, scale: number?, parent: Instance?) -> Model

export type AssetEntry = {
	name: string,
	category: string,
	build: AssetBuilderFn,
}

WinterBiomeAssetBuilder.CATEGORIES = {
	"Trees",
	"Bushes",
	"Plants",
	"Rocks",
	"IceCrystals",
	"TerrainProps",
	"Ruins",
	"Structures",
	"Decorations",
	"WaterFeatures",
	"EnvironmentalEffects",
}

-- ============================================================================
-- VISUAL PALETTE (Snow + Glacial Cyan + Dark Evergreen + Warm Timber & Gold)
-- ============================================================================

local P = {
	SNOW_PURE = Color3.fromRGB(242, 248, 255),
	SNOW_SHADE = Color3.fromRGB(214, 232, 248),
	ICE_PALE = Color3.fromRGB(166, 224, 252),
	ICE_BLUE = Color3.fromRGB(84, 186, 242),
	ICE_DEEP = Color3.fromRGB(48, 128, 198),
	ICE_CYAN = Color3.fromRGB(68, 234, 255),
	WATER_FOAM = Color3.fromRGB(236, 250, 255),

	PINE_DEEP = Color3.fromRGB(22, 74, 46),
	PINE_MID = Color3.fromRGB(36, 106, 62),
	SPRUCE_TEAL = Color3.fromRGB(34, 96, 86),

	WOOD_DARK = Color3.fromRGB(86, 54, 34),
	WOOD_MID = Color3.fromRGB(124, 78, 46),
	WOOD_LIGHT = Color3.fromRGB(158, 108, 66),
	WOOD_CUT = Color3.fromRGB(204, 168, 118),

	SLATE_DARK = Color3.fromRGB(72, 82, 98),
	SLATE_MID = Color3.fromRGB(104, 116, 134),
	SLATE_LIGHT = Color3.fromRGB(138, 150, 168),
	FROST_PURPLE = Color3.fromRGB(156, 102, 236),
	ROYAL_BLUE = Color3.fromRGB(56, 98, 206),
	SCARF_RED = Color3.fromRGB(216, 52, 56),
	CARROT_ORANGE = Color3.fromRGB(244, 132, 42),
	COAL_DARK = Color3.fromRGB(34, 36, 42),

	LANTERN_IRON = Color3.fromRGB(46, 52, 62),
	WARM_GOLD = Color3.fromRGB(255, 204, 78),
	CAMPFIRE_ORANGE = Color3.fromRGB(255, 128, 38),
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
	m:SetAttribute("BiomeId", "AlpinePeaks")

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

local function addPulseLight(parentPart: Part, color: Color3, range: number, brightness: number, phaseOffset: number?)
	local pl = Instance.new("PointLight")
	pl.Name = "WinterLight"
	pl.Color = color
	pl.Range = range
	pl.Brightness = brightness
	pl.Shadows = false
	pl:SetAttribute("AnimKind", "LanternPulse")
	pl:SetAttribute("BaseBrightness", brightness)
	pl:SetAttribute("Phase", phaseOffset or 0.4)
	pl.Parent = parentPart
end

local function addWarmLantern(m: Model, originCF: CFrame, s: number, prefix: string, center: Vector3, range: number?, brightness: number?)
	local br = brightness or 0.95
	addBox(m, originCF, s, prefix .. "_TopCap", Vector3.new(1.18, 0.24, 1.18), CFrame.new(center + Vector3.new(0, 0.56, 0)), P.LANTERN_IRON)
	addBox(m, originCF, s, prefix .. "_SnowCap", Vector3.new(1.06, 0.16, 1.06), CFrame.new(center + Vector3.new(0, 0.74, 0)), P.SNOW_PURE)
	addBox(m, originCF, s, prefix .. "_BotCap", Vector3.new(1.08, 0.22, 1.08), CFrame.new(center + Vector3.new(0, -0.54, 0)), P.LANTERN_IRON)
	local glow = addBox(m, originCF, s, prefix .. "_Glow", Vector3.new(0.78, 0.88, 0.78), CFrame.new(center), P.WARM_GOLD, Enum.Material.Neon, false, 0, false)
	addPulseLight(glow, P.WARM_GOLD, range or 17, br, (math.abs(center.X) + math.abs(center.Z)) * 0.41)
end

local function addIcicleRow(m: Model, originCF: CFrame, s: number, prefix: string, startPos: Vector3, stepVec: Vector3, count: number)
	for i = 0, count - 1 do
		local h = if i % 2 == 0 then 0.95 else 0.62
		local pos = startPos + stepVec * i - Vector3.new(0, h * 0.5, 0)
		addBox(m, originCF, s, prefix .. "_Ice" .. i, Vector3.new(0.24, h, 0.24), CFrame.new(pos), P.ICE_PALE, Enum.Material.Glass, false, 0.18, false)
	end
end

local function addRippleRing(m: Model, originCF: CFrame, s: number, name: string, center: Vector3, baseDiam: number, phase: number, speed: number)
	local ring = addBox(
		m,
		originCF,
		s,
		name,
		Vector3.new(baseDiam, 0.08, baseDiam),
		CFrame.new(center),
		P.WATER_FOAM,
		Enum.Material.SmoothPlastic,
		false,
		0.34,
		false
	)
	ring:SetAttribute("AnimKind", "RippleRing")
	ring:SetAttribute("BaseLocalCF", CFrame.new(center * s))
	ring:SetAttribute("Phase", phase)
	ring:SetAttribute("Speed", speed)
end

local function addEmitter(
	parentPart: Part,
	name: string,
	rate: number,
	c1: Color3,
	c2: Color3,
	sizeSeq: NumberSequence,
	dir: Enum.NormalId,
	speed: NumberRange,
	life: NumberRange,
	spread: Vector2?,
	lightEmission: number?
): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.Rate = rate
	pe.Color = ColorSequence.new(c1, c2)
	pe.Size = sizeSeq
	pe.EmissionDirection = dir
	pe.Speed = speed
	pe.Lifetime = life
	pe.SpreadAngle = spread or Vector2.new(12, 12)
	pe.LightEmission = lightEmission or 0.15
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.RotSpeed = NumberRange.new(-45, 45)
	pe.Enabled = true
	pe.Parent = parentPart
	return pe
end

local function addPineTier(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	y: number,
	w: number,
	h: number,
	leafColor: Color3,
	snowColor: Color3?,
	offset: Vector3?
)
	local off = offset or Vector3.zero
	addBox(m, originCF, s, prefix .. "_Leaf", Vector3.new(w, h, w), CFrame.new(off + Vector3.new(0, y, 0)), leafColor)
	addBox(m, originCF, s, prefix .. "_Snow", Vector3.new(w * 0.9, 0.42, w * 0.9), CFrame.new(off + Vector3.new(0, y + h * 0.5 + 0.16, 0)), snowColor or P.SNOW_PURE)
end

-- ============================================================================
-- 1. TREES (7 Models)
-- ============================================================================

local function buildLargeSnowPineTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "LargeSnowPineTree", originCF, parent)
	addBox(m, originCF, s, "TrunkCore", Vector3.new(1.7, 13.5, 1.7), CFrame.new(0, 6.75, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "ButtressX", Vector3.new(3.2, 1.6, 1.3), CFrame.new(0, 0.8, 0), P.WOOD_MID)
	addBox(m, originCF, s, "ButtressZ", Vector3.new(1.3, 1.6, 3.2), CFrame.new(0, 0.8, 0), P.WOOD_MID)
	addPineTier(m, originCF, s, "Tier1", 5.0, 9.2, 2.2, P.PINE_DEEP, P.SNOW_PURE)
	addPineTier(m, originCF, s, "Tier2", 7.8, 7.6, 2.0, P.PINE_MID, P.SNOW_PURE, Vector3.new(0.25, 0, -0.2))
	addPineTier(m, originCF, s, "Tier3", 10.4, 6.0, 1.9, P.PINE_DEEP, P.SNOW_PURE, Vector3.new(-0.2, 0, 0.2))
	addPineTier(m, originCF, s, "Tier4", 12.9, 4.3, 1.8, P.PINE_MID, P.SNOW_SHADE)
	addPineTier(m, originCF, s, "Tier5", 15.2, 2.6, 1.7, P.PINE_DEEP, P.SNOW_PURE)
	addBox(m, originCF, s, "SpireSnow", Vector3.new(1.2, 1.7, 1.2), CFrame.new(0, 17.2, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "IcicleL", Vector3.new(0.28, 1.0, 0.28), CFrame.new(-3.8, 3.4, 2.2), P.ICE_PALE, Enum.Material.Glass, false, 0.18, false)
	addBox(m, originCF, s, "IcicleR", Vector3.new(0.28, 0.9, 0.28), CFrame.new(3.6, 6.3, -2.0), P.ICE_PALE, Enum.Material.Glass, false, 0.18, false)
	return m
end

local function buildMediumSnowPineTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "MediumSnowPineTree", originCF, parent)
	addBox(m, originCF, s, "Trunk", Vector3.new(1.3, 9.6, 1.3), CFrame.new(0, 4.8, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "RootSnow", Vector3.new(2.8, 0.55, 2.8), CFrame.new(0, 0.275, 0), P.SNOW_SHADE)
	addPineTier(m, originCF, s, "Tier1", 3.6, 6.6, 1.8, P.PINE_MID, P.SNOW_PURE, Vector3.new(-0.2, 0, 0.15))
	addPineTier(m, originCF, s, "Tier2", 6.0, 5.2, 1.7, P.PINE_DEEP, P.SNOW_PURE, Vector3.new(0.25, 0, -0.15))
	addPineTier(m, originCF, s, "Tier3", 8.2, 3.8, 1.6, P.PINE_MID, P.SNOW_PURE)
	addPineTier(m, originCF, s, "Tier4", 10.2, 2.3, 1.4, P.PINE_DEEP, P.SNOW_SHADE)
	addBox(m, originCF, s, "TopPeak", Vector3.new(1.0, 1.3, 1.0), CFrame.new(0, 11.8, 0), P.SNOW_PURE)
	return m
end

local function buildSmallSnowPineTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SmallSnowPineTree", originCF, parent)
	addBox(m, originCF, s, "Trunk", Vector3.new(0.95, 5.6, 0.95), CFrame.new(0, 2.8, 0), P.WOOD_MID)
	addBox(m, originCF, s, "BasePad", Vector3.new(2.2, 0.4, 2.2), CFrame.new(0, 0.2, 0), P.SNOW_PURE)
	addPineTier(m, originCF, s, "Tier1", 2.4, 4.4, 1.5, P.PINE_DEEP, P.SNOW_PURE)
	addPineTier(m, originCF, s, "Tier2", 4.4, 3.2, 1.4, P.PINE_MID, P.SNOW_PURE)
	addPineTier(m, originCF, s, "Tier3", 6.1, 2.0, 1.3, P.PINE_DEEP, P.SNOW_SHADE)
	addBox(m, originCF, s, "Tip", Vector3.new(0.9, 1.1, 0.9), CFrame.new(0, 7.5, 0), P.SNOW_PURE)
	return m
end

local function buildFrostedSpruceTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "FrostedSpruceTree", originCF, parent)
	addBox(m, originCF, s, "Trunk", Vector3.new(1.25, 11.8, 1.25), CFrame.new(0, 5.9, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "BaseRoots", Vector3.new(2.5, 0.9, 2.5), CFrame.new(0, 0.45, 0), P.WOOD_MID)
	for i = 1, 5 do
		local w = 6.2 - (i - 1) * 1.05
		local y = 2.8 + (i - 1) * 2.2
		addBox(m, originCF, s, "Bough" .. i, Vector3.new(w, 1.2, w * 0.85), CFrame.new(0, y, 0), if i % 2 == 0 then P.SPRUCE_TEAL else P.PINE_DEEP)
		addBox(m, originCF, s, "Rime" .. i, Vector3.new(w * 0.92, 0.36, w * 0.8), CFrame.new(0, y + 0.72, 0), if i >= 4 then P.ICE_PALE else P.SNOW_PURE)
	end
	addBox(m, originCF, s, "FrostSpire", Vector3.new(0.95, 1.9, 0.95), CFrame.new(0, 13.7, 0), P.ICE_PALE)
	return m
end

local function buildFrozenDeadTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "FrozenDeadTree", originCF, parent)
	addBox(m, originCF, s, "RootFoot", Vector3.new(2.9, 0.7, 2.5), CFrame.new(0, 0.35, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "TrunkLower", Vector3.new(1.4, 4.4, 1.4), CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(-5)), P.WOOD_DARK)
	addBox(m, originCF, s, "TrunkUpper", Vector3.new(1.1, 4.2, 1.1), CFrame.new(0.55, 5.9, 0.2) * CFrame.Angles(0, 0, math.rad(10)), P.WOOD_MID)
	addBox(m, originCF, s, "BranchL", Vector3.new(3.8, 0.8, 0.85), CFrame.new(-1.8, 5.4, -0.3) * CFrame.Angles(0, 0, math.rad(-26)), P.WOOD_DARK)
	addBox(m, originCF, s, "BranchLSnow", Vector3.new(3.2, 0.28, 0.72), CFrame.new(-1.8, 5.9, -0.3) * CFrame.Angles(0, 0, math.rad(-26)), P.SNOW_PURE)
	addBox(m, originCF, s, "BranchR", Vector3.new(3.5, 0.75, 0.85), CFrame.new(1.9, 7.1, 0.35) * CFrame.Angles(0, 0, math.rad(28)), P.WOOD_MID)
	addBox(m, originCF, s, "BranchRSnow", Vector3.new(2.9, 0.28, 0.72), CFrame.new(1.9, 7.6, 0.35) * CFrame.Angles(0, 0, math.rad(28)), P.ICE_PALE)
	addBox(m, originCF, s, "BranchF", Vector3.new(0.72, 0.72, 2.8), CFrame.new(0.1, 6.2, -1.6) * CFrame.Angles(math.rad(-24), 0, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "DeadIcicle1", Vector3.new(0.26, 1.25, 0.26), CFrame.new(-2.8, 4.7, -0.3), P.ICE_CYAN, Enum.Material.Glass, false, 0.2, false)
	addBox(m, originCF, s, "DeadIcicle2", Vector3.new(0.24, 1.05, 0.24), CFrame.new(2.7, 6.3, 0.35), P.ICE_PALE, Enum.Material.Glass, false, 0.2, false)
	return m
end

local function buildTwistedWinterTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "TwistedWinterTree", originCF, parent)
	addBox(m, originCF, s, "SnowPlinth", Vector3.new(3.4, 0.55, 3.2), CFrame.new(0, 0.275, 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "Trunk1", Vector3.new(1.45, 3.8, 1.45), CFrame.new(-0.3, 2.1, 0) * CFrame.Angles(0, 0, math.rad(14)), P.WOOD_DARK)
	addBox(m, originCF, s, "Trunk2", Vector3.new(1.2, 4.2, 1.2), CFrame.new(0.55, 5.2, 0.25) * CFrame.Angles(math.rad(6), 0, math.rad(-18)), P.WOOD_MID)
	addBox(m, originCF, s, "ArmL", Vector3.new(3.4, 0.85, 0.85), CFrame.new(-1.3, 6.6, -0.4) * CFrame.Angles(0, 0, math.rad(-18)), P.WOOD_DARK)
	addPineTier(m, originCF, s, "CanopyL", 7.8, 4.0, 1.9, P.PINE_DEEP, P.SNOW_PURE, Vector3.new(-2.1, 0, -0.4))
	addPineTier(m, originCF, s, "CanopyTop", 9.6, 5.0, 2.1, P.PINE_MID, P.SNOW_PURE, Vector3.new(0.9, 0, 0.3))
	addBox(m, originCF, s, "TwistIcicle", Vector3.new(0.26, 1.1, 0.26), CFrame.new(-2.8, 6.1, -0.4), P.ICE_PALE, Enum.Material.Glass, false, 0.18, false)
	return m
end

local function buildSnowCoveredOakTree(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Trees", "SnowCoveredOakTree", originCF, parent)
	addBox(m, originCF, s, "RootBase", Vector3.new(3.4, 1.1, 3.4), CFrame.new(0, 0.55, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "Trunk", Vector3.new(2.0, 5.8, 2.0), CFrame.new(0, 3.2, 0), P.WOOD_MID)
	addBox(m, originCF, s, "ForkL", Vector3.new(3.0, 1.0, 1.1), CFrame.new(-1.8, 5.6, 0.3) * CFrame.Angles(0, 0, math.rad(-22)), P.WOOD_DARK)
	addBox(m, originCF, s, "ForkR", Vector3.new(2.9, 1.0, 1.1), CFrame.new(1.7, 5.8, -0.3) * CFrame.Angles(0, 0, math.rad(20)), P.WOOD_DARK)
	addPineTier(m, originCF, s, "CanopyMain", 7.4, 7.6, 2.8, P.PINE_DEEP, P.SNOW_PURE)
	addPineTier(m, originCF, s, "CanopyLobeW", 6.5, 4.2, 2.2, P.PINE_MID, P.SNOW_PURE, Vector3.new(-3.0, 0, 0.6))
	addPineTier(m, originCF, s, "CanopyLobeE", 6.8, 4.2, 2.2, P.PINE_MID, P.SNOW_SHADE, Vector3.new(2.9, 0, -0.6))
	addPineTier(m, originCF, s, "CrownTop", 9.7, 4.6, 1.8, P.PINE_DEEP, P.SNOW_PURE)
	return m
end

-- ============================================================================
-- 2. BUSHES (3 Models)
-- ============================================================================

local function buildSnowCoveredBush(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "SnowCoveredBush", originCF, parent)
	addBox(m, originCF, s, "BodyMain", Vector3.new(3.4, 1.9, 3.2), CFrame.new(0, 0.95, 0), P.PINE_DEEP)
	addBox(m, originCF, s, "LobeSide", Vector3.new(1.8, 1.5, 2.0), CFrame.new(1.4, 0.75, 0.4), P.PINE_MID)
	addBox(m, originCF, s, "SnowTop", Vector3.new(3.1, 0.58, 2.9), CFrame.new(0, 2.05, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowSide", Vector3.new(1.6, 0.48, 1.8), CFrame.new(1.4, 1.65, 0.4), P.SNOW_SHADE)
	addBox(m, originCF, s, "Berry1", Vector3.new(0.32, 0.32, 0.32), CFrame.new(-1.55, 1.15, 0.7), P.SCARF_RED)
	addBox(m, originCF, s, "Berry2", Vector3.new(0.32, 0.32, 0.32), CFrame.new(0.85, 1.05, 1.55), P.SCARF_RED)
	addBox(m, originCF, s, "Berry3", Vector3.new(0.32, 0.32, 0.32), CFrame.new(0.4, 1.35, -1.55), P.SCARF_RED)
	return m
end

local function buildFrozenGreenBush(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "FrozenGreenBush", originCF, parent)
	addBox(m, originCF, s, "Core", Vector3.new(3.0, 2.0, 2.8), CFrame.new(0, 1.0, 0), P.SPRUCE_TEAL)
	addBox(m, originCF, s, "SideL", Vector3.new(1.5, 1.4, 1.7), CFrame.new(-1.2, 0.7, -0.3), P.PINE_DEEP)
	addBox(m, originCF, s, "RimeCap", Vector3.new(2.7, 0.45, 2.5), CFrame.new(0, 2.1, 0), P.ICE_PALE)
	addBox(m, originCF, s, "FrostShard1", Vector3.new(0.36, 0.95, 0.36), CFrame.new(0.9, 1.85, 0.6) * CFrame.Angles(0, 0, math.rad(-14)), P.ICE_BLUE, Enum.Material.Ice, false, 0.16, false)
	addBox(m, originCF, s, "FrostShard2", Vector3.new(0.32, 0.8, 0.32), CFrame.new(-0.8, 1.65, -0.5) * CFrame.Angles(0, 0, math.rad(16)), P.ICE_PALE, Enum.Material.Ice, false, 0.18, false)
	return m
end

local function buildSmallSnowCoveredShrubs(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Bushes", "SmallSnowCoveredShrubs", originCF, parent)
	addBox(m, originCF, s, "Twig1", Vector3.new(1.6, 1.1, 1.6), CFrame.new(-0.85, 0.55, 0.25), P.PINE_MID)
	addBox(m, originCF, s, "Snow1", Vector3.new(1.45, 0.42, 1.45), CFrame.new(-0.85, 1.22, 0.25), P.SNOW_PURE)
	addBox(m, originCF, s, "Twig2", Vector3.new(1.4, 0.9, 1.3), CFrame.new(0.85, 0.45, -0.3), P.PINE_DEEP)
	addBox(m, originCF, s, "Snow2", Vector3.new(1.25, 0.38, 1.15), CFrame.new(0.85, 1.0, -0.3), P.SNOW_SHADE)
	addBox(m, originCF, s, "Twig3", Vector3.new(1.2, 0.8, 1.2), CFrame.new(0.15, 0.4, 0.9), P.SPRUCE_TEAL)
	addBox(m, originCF, s, "Snow3", Vector3.new(1.05, 0.34, 1.05), CFrame.new(0.15, 0.9, 0.9), P.SNOW_PURE)
	return m
end

-- ============================================================================
-- 3. PLANTS (5 Models)
-- ============================================================================

local function buildSmallFrostFern(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "SmallFrostFern", originCF, parent)
	addBox(m, originCF, s, "BasePad", Vector3.new(1.2, 0.28, 1.2), CFrame.new(0, 0.14, 0), P.SNOW_SHADE)
	for i = 0, 5 do
		local ang = math.rad(i * 60 + 15)
		local cf = CFrame.Angles(0, ang, 0) * CFrame.new(0, 0.72, 0.62) * CFrame.Angles(math.rad(36), 0, 0)
		addBox(m, originCF, s, "Frond" .. i, Vector3.new(0.36, 1.35, 0.16), cf, if i % 2 == 0 then P.SPRUCE_TEAL else P.PINE_MID)
		local tipCF = CFrame.Angles(0, ang, 0) * CFrame.new(0, 1.15, 1.05) * CFrame.Angles(math.rad(46), 0, 0)
		addBox(m, originCF, s, "Tip" .. i, Vector3.new(0.28, 0.45, 0.14), tipCF, P.ICE_PALE)
	end
	return m
end

local function buildWinterGrass(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "WinterGrass", originCF, parent)
	addBox(m, originCF, s, "SnowTuft", Vector3.new(1.4, 0.22, 1.4), CFrame.new(0, 0.11, 0), P.SNOW_PURE)
	local blades = {
		{ Vector3.new(-0.4, 0.75, 0.2), 1.3, 12, -8, P.SPRUCE_TEAL },
		{ Vector3.new(0.35, 0.85, -0.25), 1.5, -10, 14, P.PINE_MID },
		{ Vector3.new(0.05, 0.95, 0.35), 1.6, 15, 6, P.SNOW_SHADE },
		{ Vector3.new(-0.2, 0.7, -0.4), 1.2, -16, -10, P.PINE_DEEP },
		{ Vector3.new(0.45, 0.65, 0.35), 1.1, 8, 18, P.ICE_PALE },
	}
	for i, b in ipairs(blades) do
		local cf = CFrame.new(b[1] :: Vector3) * CFrame.Angles(math.rad(b[3] :: number), 0, math.rad(b[4] :: number))
		addBox(m, originCF, s, "Blade" .. i, Vector3.new(0.22, b[2] :: number, 0.22), cf, b[5] :: Color3)
	end
	return m
end

local function buildPurpleFrostFlowers(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "PurpleFrostFlowers", originCF, parent)
	addBox(m, originCF, s, "LeafPad", Vector3.new(1.8, 0.32, 1.7), CFrame.new(0, 0.16, 0), P.PINE_DEEP)
	local stems = {
		{ Vector3.new(-0.45, 0.65, 0.2), 0.95, P.FROST_PURPLE },
		{ Vector3.new(0.4, 0.78, -0.2), 1.15, P.FROST_PURPLE },
		{ Vector3.new(0.05, 0.55, 0.45), 0.78, P.ICE_PALE },
	}
	for i, st in ipairs(stems) do
		local p = st[1] :: Vector3
		local h = st[2] :: number
		addBox(m, originCF, s, "Stem" .. i, Vector3.new(0.18, h, 0.18), CFrame.new(p.X, 0.25 + h * 0.5, p.Z), P.SPRUCE_TEAL)
		addBox(m, originCF, s, "Petal" .. i, Vector3.new(0.62, 0.36, 0.62), CFrame.new(p.X, 0.3 + h, p.Z), st[3] :: Color3)
		addBox(m, originCF, s, "Core" .. i, Vector3.new(0.28, 0.22, 0.28), CFrame.new(p.X, 0.52 + h, p.Z), P.WARM_GOLD, Enum.Material.Neon, false, 0, false)
	end
	return m
end

local function buildBlueCrystalPlants(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "BlueCrystalPlants", originCF, parent)
	addBox(m, originCF, s, "FrostSoil", Vector3.new(1.5, 0.28, 1.5), CFrame.new(0, 0.14, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "LeafA", Vector3.new(1.3, 0.24, 0.55), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, math.rad(35), math.rad(14)), P.SPRUCE_TEAL)
	addBox(m, originCF, s, "LeafB", Vector3.new(1.3, 0.24, 0.55), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, math.rad(-40), math.rad(-14)), P.PINE_MID)
	addBox(m, originCF, s, "BudMain", Vector3.new(0.45, 1.55, 0.45), CFrame.new(0, 0.95, 0), P.ICE_CYAN, Enum.Material.Neon, false, 0.08, false)
	addBox(m, originCF, s, "BudL", Vector3.new(0.32, 1.05, 0.32), CFrame.new(-0.42, 0.7, 0.18) * CFrame.Angles(0, 0, math.rad(20)), P.ICE_BLUE, Enum.Material.Ice, false, 0.18, false)
	addBox(m, originCF, s, "BudR", Vector3.new(0.32, 0.95, 0.32), CFrame.new(0.4, 0.65, -0.2) * CFrame.Angles(0, 0, math.rad(-22)), P.ICE_PALE, Enum.Material.Glass, false, 0.18, false)
	return m
end

local function buildFrozenReeds(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Plants", "FrozenReeds", originCF, parent)
	addBox(m, originCF, s, "IceBase", Vector3.new(1.6, 0.26, 1.4), CFrame.new(0, 0.13, 0), P.ICE_PALE, Enum.Material.Ice, false)
	local stalks = {
		{ -0.45, 2.3, 0.2, 6 },
		{ 0.0, 2.8, -0.25, -4 },
		{ 0.45, 2.1, 0.15, 8 },
		{ -0.2, 1.8, -0.35, -9 },
	}
	for i, st in ipairs(stalks) do
		local x, h, z, tilt = st[1], st[2], st[3], st[4]
		addBox(m, originCF, s, "Stalk" .. i, Vector3.new(0.18, h, 0.18), CFrame.new(x, 0.2 + h * 0.5, z) * CFrame.Angles(0, 0, math.rad(tilt)), P.SPRUCE_TEAL)
		addBox(m, originCF, s, "Plume" .. i, Vector3.new(0.3, 0.55, 0.3), CFrame.new(x, 0.25 + h, z) * CFrame.Angles(0, 0, math.rad(tilt)), P.SNOW_PURE)
	end
	return m
end

-- ============================================================================
-- 4. ROCKS (4 Models)
-- ============================================================================

local function buildSnowCoveredBoulder(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "SnowCoveredBoulder", originCF, parent)
	addBox(m, originCF, s, "RockCore", Vector3.new(3.8, 2.3, 3.4), CFrame.new(0, 1.15, 0), P.SLATE_MID)
	addBox(m, originCF, s, "RockStep", Vector3.new(2.4, 1.7, 2.6), CFrame.new(-1.0, 0.85, 0.5), P.SLATE_DARK)
	addBox(m, originCF, s, "RockCrown", Vector3.new(2.2, 0.9, 2.0), CFrame.new(0.3, 2.4, -0.2), P.SLATE_LIGHT)
	addBox(m, originCF, s, "SnowTop1", Vector3.new(3.6, 0.55, 3.2), CFrame.new(0, 2.55, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowTop2", Vector3.new(2.1, 0.45, 2.3), CFrame.new(-1.0, 1.9, 0.5), P.SNOW_SHADE)
	addBox(m, originCF, s, "SnowTop3", Vector3.new(1.9, 0.45, 1.8), CFrame.new(0.3, 3.05, -0.2), P.SNOW_PURE)
	return m
end

local function buildFrozenRockFormation(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "FrozenRockFormation", originCF, parent)
	addBox(m, originCF, s, "Plinth", Vector3.new(4.8, 1.4, 4.2), CFrame.new(0, 0.7, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "SpireSlate", Vector3.new(2.4, 4.2, 2.2), CFrame.new(-0.6, 2.7, 0.2) * CFrame.Angles(0, 0, math.rad(8)), P.SLATE_MID)
	addBox(m, originCF, s, "SnowLedge", Vector3.new(2.5, 0.45, 2.3), CFrame.new(-0.8, 4.95, 0.2), P.SNOW_PURE)
	addBox(m, originCF, s, "IceVein", Vector3.new(1.7, 3.4, 1.8), CFrame.new(1.1, 2.2, -0.4) * CFrame.Angles(0, 0, math.rad(-14)), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "LowChunk", Vector3.new(1.8, 1.6, 1.6), CFrame.new(1.4, 1.0, 1.1), P.SLATE_LIGHT)
	addBox(m, originCF, s, "ChunkSnow", Vector3.new(1.7, 0.4, 1.5), CFrame.new(1.4, 1.95, 1.1), P.SNOW_PURE)
	return m
end

local function buildFrozenCliffRocks(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "FrozenCliffRocks", originCF, parent)
	addBox(m, originCF, s, "TierLower", Vector3.new(5.6, 2.4, 4.2), CFrame.new(0, 1.2, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "TierMid", Vector3.new(4.2, 3.2, 3.2), CFrame.new(-0.3, 3.6, -0.2), P.SLATE_MID)
	addBox(m, originCF, s, "TierPeak", Vector3.new(2.6, 2.4, 2.4), CFrame.new(-0.5, 5.6, -0.2), P.SLATE_LIGHT)
	addBox(m, originCF, s, "Cornice", Vector3.new(3.2, 0.65, 2.9), CFrame.new(-0.4, 7.0, 0.1), P.SNOW_PURE)
	addBox(m, originCF, s, "LedgeSnow", Vector3.new(5.4, 0.5, 1.6), CFrame.new(0, 2.55, 1.4), P.SNOW_SHADE)
	addIcicleRow(m, originCF, s, "CliffIce", Vector3.new(-1.5, 6.7, 1.35), Vector3.new(0.85, 0, 0), 4)
	return m
end

local function buildSmallIceRocks(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Rocks", "SmallIceRocks", originCF, parent)
	addBox(m, originCF, s, "StoneA", Vector3.new(1.5, 0.9, 1.4), CFrame.new(-0.9, 0.45, 0.4), P.SLATE_MID)
	addBox(m, originCF, s, "SnowA", Vector3.new(1.3, 0.28, 1.2), CFrame.new(-0.9, 1.0, 0.4), P.SNOW_PURE)
	addBox(m, originCF, s, "StoneB", Vector3.new(1.1, 0.7, 1.0), CFrame.new(0.95, 0.35, -0.5), P.SLATE_DARK)
	addBox(m, originCF, s, "IceShardA", Vector3.new(0.75, 1.3, 0.75), CFrame.new(0.35, 0.7, 0.55) * CFrame.Angles(math.rad(12), math.rad(18), 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "IceShardB", Vector3.new(0.55, 0.9, 0.55), CFrame.new(-0.2, 0.5, -0.7), P.ICE_PALE, Enum.Material.Ice, false, 0.18)
	return m
end

-- ============================================================================
-- 5. ICE CRYSTALS (3 Models)
-- ============================================================================

local function buildIceSpikes(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("IceCrystals", "IceSpikes", originCF, parent)
	addBox(m, originCF, s, "SnowBase", Vector3.new(3.2, 0.45, 3.0), CFrame.new(0, 0.225, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SpikeMain", Vector3.new(0.9, 4.2, 0.9), CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(8), 0, math.rad(-10)), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "SpikeTip", Vector3.new(0.55, 1.4, 0.55), CFrame.new(0.45, 4.4, 0.35) * CFrame.Angles(math.rad(8), 0, math.rad(-10)), P.ICE_PALE, Enum.Material.Glass, false, 0.2)
	addBox(m, originCF, s, "SpikeL", Vector3.new(0.72, 2.9, 0.72), CFrame.new(-1.05, 1.5, 0.4) * CFrame.Angles(0, 0, math.rad(24)), P.ICE_CYAN, Enum.Material.Glass, false, 0.22)
	addBox(m, originCF, s, "SpikeR", Vector3.new(0.68, 2.5, 0.68), CFrame.new(1.0, 1.3, -0.45) * CFrame.Angles(math.rad(-14), 0, math.rad(-26)), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	return m
end

local function buildBlueIceCrystalCluster(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("IceCrystals", "BlueIceCrystalCluster", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "SlateBase", Vector3.new(2.8, 0.6, 2.6), CFrame.new(0, 0.3, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "CorePrism", Vector3.new(0.95, 3.1, 0.95), CFrame.new(0, 1.85, 0), P.ICE_CYAN, Enum.Material.Neon, false, 0.08, false)
	local light = addBox(m, originCF, s, "ShellMain", Vector3.new(1.28, 3.4, 1.28), CFrame.new(0, 1.9, 0), P.ICE_BLUE, Enum.Material.Glass, false, 0.26, false)
	addPulseLight(light, P.ICE_CYAN, 15, 0.85, 0.7)
	addBox(m, originCF, s, "ShardW", Vector3.new(0.78, 2.2, 0.78), CFrame.new(-0.95, 1.35, 0.2) * CFrame.Angles(0, 0, math.rad(20)), P.ICE_PALE, Enum.Material.Glass, false, 0.22, false)
	addBox(m, originCF, s, "ShardE", Vector3.new(0.74, 2.0, 0.74), CFrame.new(0.9, 1.25, -0.3) * CFrame.Angles(0, 0, math.rad(-22)), P.ICE_BLUE, Enum.Material.Glass, false, 0.24, false)
	addBox(m, originCF, s, "ShardN", Vector3.new(0.65, 1.65, 0.65), CFrame.new(0.15, 1.0, -0.85) * CFrame.Angles(math.rad(-22), 0, 0), P.ICE_CYAN, Enum.Material.Neon, false, 0.14, false)
	return m
end

local function buildLargeCrystalFormation(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("IceCrystals", "LargeCrystalFormation", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "StoneStep", Vector3.new(6.2, 1.6, 5.6), CFrame.new(0, 0.8, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "SnowRim", Vector3.new(5.6, 0.45, 5.0), CFrame.new(0, 1.75, 0), P.SNOW_PURE)
	local core = addBox(m, originCF, s, "MainCore", Vector3.new(1.55, 8.2, 1.55), CFrame.new(0, 5.4, 0), P.ICE_CYAN, Enum.Material.Neon, false, 0.06, false)
	addPulseLight(core, P.ICE_CYAN, 22, 1.15, 1.2)
	addBox(m, originCF, s, "MainShell", Vector3.new(2.15, 8.8, 2.15), CFrame.new(0, 5.5, 0), P.ICE_BLUE, Enum.Material.Glass, false, 0.26, false)
	addBox(m, originCF, s, "CrownTip", Vector3.new(1.2, 2.0, 1.2), CFrame.new(0, 10.1, 0), P.ICE_PALE, Enum.Material.Glass, false, 0.22, false)
	local shards = {
		{ Vector3.new(-2.1, 3.6, 0.8), Vector3.new(1.25, 5.2, 1.25), CFrame.Angles(math.rad(10), 0, math.rad(22)), P.ICE_BLUE },
		{ Vector3.new(2.1, 3.4, -0.7), Vector3.new(1.2, 4.8, 1.2), CFrame.Angles(math.rad(-8), 0, math.rad(-24)), P.ICE_PALE },
		{ Vector3.new(0.5, 3.0, 2.1), Vector3.new(1.05, 4.0, 1.05), CFrame.Angles(math.rad(24), 0, math.rad(-6)), P.ICE_CYAN },
		{ Vector3.new(-0.8, 2.9, -2.0), Vector3.new(1.05, 3.8, 1.05), CFrame.Angles(math.rad(-24), 0, math.rad(8)), P.ICE_DEEP },
	}
	for i, sh in ipairs(shards) do
		addBox(m, originCF, s, "FlankShard" .. i, sh[2] :: Vector3, CFrame.new(sh[1] :: Vector3) * (sh[3] :: CFrame), sh[4] :: Color3, Enum.Material.Glass, false, 0.22, false)
	end
	addEmitter(core, "CrystalSparkles", 5, P.ICE_CYAN, P.SNOW_PURE, NumberSequence.new(0.24, 0.08), Enum.NormalId.Top, NumberRange.new(1.2, 2.5), NumberRange.new(1.8, 2.8), Vector2.new(35, 35), 0.8)
	return m
end

-- ============================================================================
-- 6. TERRAIN PROPS (2 Models)
-- ============================================================================

local function buildSnowMounds(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "SnowMounds", originCF, parent)
	addBox(m, originCF, s, "DriftBase", Vector3.new(5.4, 1.0, 4.4), CFrame.new(0, 0.5, 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "DriftMid", Vector3.new(3.8, 0.9, 3.1), CFrame.new(-0.4, 1.35, 0.2), P.SNOW_PURE)
	addBox(m, originCF, s, "DriftTop", Vector3.new(2.1, 0.65, 1.8), CFrame.new(-0.6, 2.05, 0.3), P.SNOW_PURE)
	addBox(m, originCF, s, "Pebble1", Vector3.new(0.7, 0.5, 0.65), CFrame.new(1.8, 0.9, -1.1), P.SLATE_MID)
	addBox(m, originCF, s, "Pebble2", Vector3.new(0.55, 0.4, 0.55), CFrame.new(-1.9, 0.6, 1.4), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	return m
end

local function buildSnowCoveredFallenLogs(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("TerrainProps", "SnowCoveredFallenLogs", originCF, parent)
	addBox(m, originCF, s, "LogBody", Vector3.new(7.4, 1.55, 1.65), CFrame.new(0, 0.78, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "CutFaceL", Vector3.new(0.14, 1.2, 1.25), CFrame.new(-3.72, 0.78, 0), P.WOOD_CUT)
	addBox(m, originCF, s, "CutFaceR", Vector3.new(0.14, 1.2, 1.25), CFrame.new(3.72, 0.78, 0), P.WOOD_CUT)
	addBox(m, originCF, s, "SnowBlanketA", Vector3.new(5.4, 0.46, 1.5), CFrame.new(-0.5, 1.68, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowBlanketB", Vector3.new(2.1, 0.36, 1.3), CFrame.new(2.4, 1.62, 0.1), P.SNOW_SHADE)
	addBox(m, originCF, s, "StubBranch", Vector3.new(0.75, 0.75, 1.6), CFrame.new(-1.4, 1.0, 1.1) * CFrame.Angles(0, math.rad(25), 0), P.WOOD_MID)
	addBox(m, originCF, s, "FrostTwig", Vector3.new(0.32, 0.9, 0.32), CFrame.new(1.5, 1.75, -0.45), P.PINE_MID)
	return m
end

-- ============================================================================
-- 7. RUINS (4 Models)
-- ============================================================================

local function buildAncientFrozenStoneArch(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "AncientFrozenStoneArch", originCF, parent)
	addBox(m, originCF, s, "PlinthL", Vector3.new(2.6, 1.2, 2.6), CFrame.new(-3.4, 0.6, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "PlinthR", Vector3.new(2.6, 1.2, 2.6), CFrame.new(3.4, 0.6, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "PillarL", Vector3.new(2.0, 6.2, 2.0), CFrame.new(-3.4, 4.3, 0), P.SLATE_MID)
	addBox(m, originCF, s, "PillarR", Vector3.new(2.0, 6.2, 2.0), CFrame.new(3.4, 4.3, 0), P.SLATE_MID)
	addBox(m, originCF, s, "LintelBase", Vector3.new(9.6, 1.6, 2.4), CFrame.new(0, 8.2, 0), P.SLATE_LIGHT)
	addBox(m, originCF, s, "Keystone", Vector3.new(2.2, 2.2, 2.6), CFrame.new(0, 8.6, 0), P.SLATE_MID)
	addBox(m, originCF, s, "SnowCorniceL", Vector3.new(3.3, 0.55, 2.5), CFrame.new(-2.8, 9.25, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowCorniceR", Vector3.new(3.3, 0.55, 2.5), CFrame.new(2.8, 9.25, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowKey", Vector3.new(2.1, 0.55, 2.5), CFrame.new(0, 9.9, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "IceGem", Vector3.new(0.85, 0.95, 2.75), CFrame.new(0, 8.6, 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "Rubble1", Vector3.new(1.3, 0.85, 1.2), CFrame.new(-4.8, 0.42, 0.8), P.SLATE_MID)
	addBox(m, originCF, s, "Rubble2", Vector3.new(1.1, 0.7, 1.2), CFrame.new(4.6, 0.35, -0.7), P.SNOW_SHADE)
	addIcicleRow(m, originCF, s, "ArchIce", Vector3.new(-1.8, 7.4, 0.85), Vector3.new(1.2, 0, 0), 4)
	return m
end

local function buildBrokenIcePillars(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "BrokenIcePillars", originCF, parent)
	addBox(m, originCF, s, "BaseA", Vector3.new(2.6, 0.9, 2.6), CFrame.new(-1.8, 0.45, 0.2), P.SLATE_DARK)
	addBox(m, originCF, s, "ColA", Vector3.new(1.9, 4.8, 1.9), CFrame.new(-1.8, 3.3, 0.2), P.SLATE_MID)
	addBox(m, originCF, s, "IceTopA", Vector3.new(1.6, 1.4, 1.6), CFrame.new(-1.8, 6.2, 0.2) * CFrame.Angles(0, math.rad(12), math.rad(6)), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "SnowA", Vector3.new(1.4, 0.4, 1.4), CFrame.new(-1.8, 7.05, 0.2), P.SNOW_PURE)
	addBox(m, originCF, s, "BaseB", Vector3.new(2.4, 0.8, 2.4), CFrame.new(1.8, 0.4, -0.4), P.SLATE_DARK)
	addBox(m, originCF, s, "ColB", Vector3.new(1.75, 2.3, 1.75), CFrame.new(1.8, 1.95, -0.4), P.SLATE_LIGHT)
	addBox(m, originCF, s, "SnowB", Vector3.new(1.7, 0.45, 1.7), CFrame.new(1.8, 3.3, -0.4), P.SNOW_PURE)
	addBox(m, originCF, s, "FallenChunk", Vector3.new(1.6, 1.2, 2.4), CFrame.new(0.2, 0.6, 1.3) * CFrame.Angles(0, math.rad(28), 0), P.ICE_PALE, Enum.Material.Ice, false, 0.18)
	return m
end

local function buildAncientSnowRuins(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "AncientSnowRuins", originCF, parent)
	addBox(m, originCF, s, "StepBase", Vector3.new(8.2, 0.9, 6.8), CFrame.new(0, 0.45, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "SnowFloor", Vector3.new(7.4, 0.35, 6.0), CFrame.new(0, 1.05, 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "WallW", Vector3.new(1.5, 4.4, 5.4), CFrame.new(-3.0, 3.1, -0.2), P.SLATE_MID)
	addBox(m, originCF, s, "SnowW", Vector3.new(1.6, 0.5, 5.3), CFrame.new(-3.0, 5.55, -0.2), P.SNOW_PURE)
	addBox(m, originCF, s, "WallN", Vector3.new(5.6, 3.6, 1.5), CFrame.new(-0.3, 2.7, -2.3), P.SLATE_LIGHT)
	addBox(m, originCF, s, "SnowN", Vector3.new(5.2, 0.5, 1.5), CFrame.new(-0.3, 4.7, -2.3), P.SNOW_PURE)
	addBox(m, originCF, s, "CornerCol", Vector3.new(1.7, 5.4, 1.7), CFrame.new(2.8, 3.6, -2.1), P.SLATE_MID)
	addBox(m, originCF, s, "CornerSnow", Vector3.new(1.7, 0.5, 1.7), CFrame.new(2.8, 6.5, -2.1), P.SNOW_PURE)
	addBox(m, originCF, s, "RuneGem", Vector3.new(0.75, 0.85, 0.75), CFrame.new(-0.2, 1.6, -0.8), P.FROST_PURPLE, Enum.Material.Neon, false, 0.1, false)
	addIcicleRow(m, originCF, s, "RuinIce", Vector3.new(-2.1, 4.4, -1.45), Vector3.new(1.2, 0, 0), 3)
	return m
end

local function buildSnowCoveredStoneWalls(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Ruins", "SnowCoveredStoneWalls", originCF, parent)
	addBox(m, originCF, s, "WallFoot", Vector3.new(9.2, 1.1, 2.2), CFrame.new(0, 0.55, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "WallBodyL", Vector3.new(4.8, 2.9, 1.7), CFrame.new(-2.0, 2.55, 0), P.SLATE_MID)
	addBox(m, originCF, s, "WallBodyR", Vector3.new(3.4, 2.1, 1.7), CFrame.new(2.5, 2.15, 0), P.SLATE_LIGHT)
	addBox(m, originCF, s, "Merlon1", Vector3.new(1.4, 0.9, 1.7), CFrame.new(-3.5, 4.45, 0), P.SLATE_LIGHT)
	addBox(m, originCF, s, "Merlon2", Vector3.new(1.4, 0.9, 1.7), CFrame.new(-0.8, 4.45, 0), P.SLATE_MID)
	addBox(m, originCF, s, "SnowL", Vector3.new(1.5, 0.45, 1.75), CFrame.new(-3.5, 5.1, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowM", Vector3.new(1.5, 0.45, 1.75), CFrame.new(-0.8, 5.1, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowR", Vector3.new(3.5, 0.5, 1.75), CFrame.new(2.5, 3.4, 0), P.SNOW_PURE)
	return m
end

-- ============================================================================
-- 8. STRUCTURES (5 Models)
-- ============================================================================

local function buildFrozenTempleEntrance(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "FrozenTempleEntrance", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "Step1", Vector3.new(12.2, 0.9, 7.6), CFrame.new(0, 0.45, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "Step2", Vector3.new(10.2, 0.8, 5.6), CFrame.new(0, 1.3, -0.3), P.SLATE_MID)
	addBox(m, originCF, s, "PierL", Vector3.new(2.4, 6.8, 2.8), CFrame.new(-3.9, 5.1, -0.3), P.SLATE_MID)
	addBox(m, originCF, s, "PierR", Vector3.new(2.4, 6.8, 2.8), CFrame.new(3.9, 5.1, -0.3), P.SLATE_MID)
	addBox(m, originCF, s, "InlayIceL", Vector3.new(0.75, 4.2, 2.95), CFrame.new(-3.9, 5.0, -0.3), P.ICE_CYAN, Enum.Material.Neon, false, 0.12, false)
	addBox(m, originCF, s, "InlayIceR", Vector3.new(0.75, 4.2, 2.95), CFrame.new(3.9, 5.0, -0.3), P.ICE_CYAN, Enum.Material.Neon, false, 0.12, false)
	addBox(m, originCF, s, "BeamArch", Vector3.new(11.4, 1.8, 3.2), CFrame.new(0, 9.4, -0.3), P.SLATE_LIGHT)
	addBox(m, originCF, s, "Pediment", Vector3.new(6.8, 1.9, 2.6), CFrame.new(0, 11.2, -0.3), P.SLATE_MID)
	addBox(m, originCF, s, "RoofSnowA", Vector3.new(11.6, 0.55, 3.4), CFrame.new(0, 10.5, -0.3), P.SNOW_PURE)
	addBox(m, originCF, s, "RoofSnowB", Vector3.new(7.0, 0.6, 2.8), CFrame.new(0, 12.4, -0.3), P.SNOW_PURE)
	addBox(m, originCF, s, "CrestCrystal", Vector3.new(1.1, 2.1, 1.1), CFrame.new(0, 11.5, 1.1), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addIcicleRow(m, originCF, s, "GateIce", Vector3.new(-2.1, 8.5, 1.1), Vector3.new(1.4, 0, 0), 4)
	addBox(m, originCF, s, "BracketL", Vector3.new(0.45, 0.45, 1.5), CFrame.new(-3.9, 6.2, 1.5), P.WOOD_DARK)
	addBox(m, originCF, s, "BracketR", Vector3.new(0.45, 0.45, 1.5), CFrame.new(3.9, 6.2, 1.5), P.WOOD_DARK)
	addWarmLantern(m, originCF, s, "LanternL", Vector3.new(-3.9, 5.1, 2.0), 20, 1.0)
	addWarmLantern(m, originCF, s, "LanternR", Vector3.new(3.9, 5.1, 2.0), 20, 1.0)
	return m
end

local function buildIceMonument(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "IceMonument", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "PlinthBase", Vector3.new(6.8, 1.2, 6.8), CFrame.new(0, 0.6, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "PlinthSnow", Vector3.new(6.2, 0.4, 6.2), CFrame.new(0, 1.4, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "ObeliskBase", Vector3.new(3.4, 3.0, 3.4), CFrame.new(0, 3.1, 0), P.SLATE_MID)
	addBox(m, originCF, s, "RoyalTrim", Vector3.new(3.6, 0.6, 3.6), CFrame.new(0, 4.7, 0), P.ROYAL_BLUE)
	addBox(m, originCF, s, "ObeliskShaft", Vector3.new(2.2, 4.6, 2.2), CFrame.new(0, 7.2, 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	local orb = addBox(m, originCF, s, "CrownOrb", Vector3.new(1.5, 2.4, 1.5), CFrame.new(0, 10.7, 0), P.ICE_CYAN, Enum.Material.Neon, false, 0.08, false)
	addPulseLight(orb, P.ICE_CYAN, 20, 1.0, 0.9)
	addBox(m, originCF, s, "FinL", Vector3.new(0.8, 2.4, 0.8), CFrame.new(-2.1, 3.6, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "FinR", Vector3.new(0.8, 2.4, 0.8), CFrame.new(2.1, 3.6, 0), P.SNOW_PURE)
	return m
end

local function buildFrozenStoneGate(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "FrozenStoneGate", originCF, parent)
	addBox(m, originCF, s, "TowerL", Vector3.new(3.2, 9.4, 3.2), CFrame.new(-4.8, 4.7, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "TowerR", Vector3.new(3.2, 9.4, 3.2), CFrame.new(4.8, 4.7, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "TowerSnowL", Vector3.new(3.5, 0.7, 3.5), CFrame.new(-4.8, 9.75, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "TowerSnowR", Vector3.new(3.5, 0.7, 3.5), CFrame.new(4.8, 9.75, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "ArchSpan", Vector3.new(7.4, 2.2, 2.4), CFrame.new(0, 7.2, 0), P.SLATE_MID)
	addBox(m, originCF, s, "ArchSnow", Vector3.new(7.0, 0.55, 2.4), CFrame.new(0, 8.55, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "BannerL", Vector3.new(1.2, 3.2, 0.24), CFrame.new(-4.8, 5.4, 1.72), P.ROYAL_BLUE)
	addBox(m, originCF, s, "BannerR", Vector3.new(1.2, 3.2, 0.24), CFrame.new(4.8, 5.4, 1.72), P.ROYAL_BLUE)
	addBox(m, originCF, s, "CrestGem", Vector3.new(0.85, 0.9, 0.4), CFrame.new(0, 7.2, 1.3), P.ICE_CYAN, Enum.Material.Neon, false, 0.1, false)
	addBox(m, originCF, s, "GateTrimL", Vector3.new(0.65, 5.2, 0.8), CFrame.new(-2.9, 2.6, 1.1), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	addBox(m, originCF, s, "GateTrimR", Vector3.new(0.65, 5.2, 0.8), CFrame.new(2.9, 2.6, 1.1), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	return m
end

local function buildSmallAbandonedWatchtower(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "SmallAbandonedWatchtower", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "StoneBase", Vector3.new(6.2, 2.4, 6.2), CFrame.new(0, 1.2, 0), P.SLATE_DARK)
	for _, corner in ipairs({
		Vector3.new(-2.2, 5.2, -2.2),
		Vector3.new(2.2, 5.2, -2.2),
		Vector3.new(-2.2, 5.2, 2.2),
		Vector3.new(2.2, 5.2, 2.2),
	}) do
		addBox(m, originCF, s, "Post", Vector3.new(0.85, 5.8, 0.85), CFrame.new(corner), P.WOOD_DARK)
	end
	addBox(m, originCF, s, "CrossDeck", Vector3.new(6.6, 0.65, 6.6), CFrame.new(0, 5.6, 0), P.WOOD_MID)
	addBox(m, originCF, s, "RailFront", Vector3.new(6.2, 1.0, 0.45), CFrame.new(0, 6.4, 2.9), P.WOOD_LIGHT)
	addBox(m, originCF, s, "RailBack", Vector3.new(6.2, 1.0, 0.45), CFrame.new(0, 6.4, -2.9), P.WOOD_LIGHT)
	addBox(m, originCF, s, "RoofBase", Vector3.new(7.4, 0.9, 7.4), CFrame.new(0, 8.4, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "RoofPeak", Vector3.new(5.2, 1.4, 5.2), CFrame.new(0, 9.5, 0), P.WOOD_MID)
	addBox(m, originCF, s, "RoofSnowA", Vector3.new(7.5, 0.5, 7.5), CFrame.new(0, 9.05, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "RoofSnowB", Vector3.new(5.3, 0.55, 5.3), CFrame.new(0, 10.45, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "ApexSnow", Vector3.new(2.4, 0.9, 2.4), CFrame.new(0, 11.1, 0), P.SNOW_PURE)
	addIcicleRow(m, originCF, s, "EaveIce", Vector3.new(-2.4, 8.0, 3.55), Vector3.new(1.6, 0, 0), 4)
	addWarmLantern(m, originCF, s, "DeckLantern", Vector3.new(0, 6.9, 1.4), 22, 1.1)
	return m
end

local function buildFrozenCastleDecoration(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Structures", "FrozenCastleDecoration", originCF, parent)
	addBox(m, originCF, s, "KeepPlinth", Vector3.new(7.2, 1.4, 7.2), CFrame.new(0, 0.7, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "TurretBody", Vector3.new(5.2, 6.6, 5.2), CFrame.new(0, 4.7, 0), P.SLATE_MID)
	addBox(m, originCF, s, "Battlement", Vector3.new(6.2, 1.2, 6.2), CFrame.new(0, 8.4, 0), P.SLATE_LIGHT)
	addBox(m, originCF, s, "SnowTrim", Vector3.new(6.3, 0.45, 6.3), CFrame.new(0, 9.2, 0), P.SNOW_PURE)
	for _, corner in ipairs({
		Vector3.new(-2.4, 9.8, -2.4),
		Vector3.new(2.4, 9.8, -2.4),
		Vector3.new(-2.4, 9.8, 2.4),
		Vector3.new(2.4, 9.8, 2.4),
	}) do
		addBox(m, originCF, s, "Merlon", Vector3.new(1.1, 1.2, 1.1), CFrame.new(corner), P.SLATE_MID)
		addBox(m, originCF, s, "MerlonSnow", Vector3.new(1.15, 0.4, 1.15), CFrame.new(corner + Vector3.new(0, 0.8, 0)), P.SNOW_PURE)
	end
	addBox(m, originCF, s, "IceSpire", Vector3.new(1.6, 3.6, 1.6), CFrame.new(0, 11.2, 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "PurpleTrim", Vector3.new(5.45, 0.6, 5.45), CFrame.new(0, 6.6, 0), P.ROYAL_BLUE)
	addBox(m, originCF, s, "CrestShield", Vector3.new(1.5, 1.9, 0.35), CFrame.new(0, 4.8, 2.75), P.FROST_PURPLE)
	return m
end

-- ============================================================================
-- 9. DECORATIONS (10 Models)
-- ============================================================================

local function buildWoodenWinterLantern(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenWinterLantern", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "StoneBase", Vector3.new(1.7, 0.65, 1.7), CFrame.new(0, 0.325, 0), P.SLATE_MID)
	addBox(m, originCF, s, "BaseSnow", Vector3.new(1.85, 0.25, 1.85), CFrame.new(0, 0.72, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "Post", Vector3.new(0.62, 5.6, 0.62), CFrame.new(0, 3.45, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "CrossArm", Vector3.new(1.9, 0.48, 0.48), CFrame.new(0.7, 5.95, 0), P.WOOD_MID)
	addBox(m, originCF, s, "ArmSnow", Vector3.new(1.8, 0.2, 0.46), CFrame.new(0.7, 6.28, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "Chain", Vector3.new(0.18, 0.45, 0.18), CFrame.new(1.3, 5.52, 0), P.LANTERN_IRON)
	addWarmLantern(m, originCF, s, "Cage", Vector3.new(1.3, 4.7, 0), 17, 0.95)
	return m
end

local function buildSnowman(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "Snowman", originCF, parent)
	addBox(m, originCF, s, "BottomBall", Vector3.new(2.6, 2.0, 2.6), CFrame.new(0, 1.0, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "MidBall", Vector3.new(2.0, 1.7, 2.0), CFrame.new(0, 2.75, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "Scarf", Vector3.new(2.15, 0.42, 2.15), CFrame.new(0, 3.65, 0), P.SCARF_RED)
	addBox(m, originCF, s, "ScarfTail", Vector3.new(0.45, 1.15, 0.28), CFrame.new(0.55, 3.05, 1.05), P.SCARF_RED)
	addBox(m, originCF, s, "Head", Vector3.new(1.5, 1.45, 1.5), CFrame.new(0, 4.55, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "CarrotNose", Vector3.new(0.28, 0.28, 0.85), CFrame.new(0, 4.5, 1.05), P.CARROT_ORANGE)
	addBox(m, originCF, s, "EyeL", Vector3.new(0.22, 0.22, 0.18), CFrame.new(-0.34, 4.82, 0.74), P.COAL_DARK)
	addBox(m, originCF, s, "EyeR", Vector3.new(0.22, 0.22, 0.18), CFrame.new(0.34, 4.82, 0.74), P.COAL_DARK)
	addBox(m, originCF, s, "Button1", Vector3.new(0.22, 0.22, 0.18), CFrame.new(0, 3.0, 1.0), P.COAL_DARK)
	addBox(m, originCF, s, "Button2", Vector3.new(0.22, 0.22, 0.18), CFrame.new(0, 2.45, 1.0), P.COAL_DARK)
	addBox(m, originCF, s, "HatBrim", Vector3.new(1.9, 0.24, 1.9), CFrame.new(0, 5.36, 0), P.COAL_DARK)
	addBox(m, originCF, s, "HatRibbon", Vector3.new(1.35, 0.24, 1.35), CFrame.new(0, 5.58, 0), P.SCARF_RED)
	addBox(m, originCF, s, "HatCrown", Vector3.new(1.28, 0.85, 1.28), CFrame.new(0, 6.1, 0), P.COAL_DARK)
	addBox(m, originCF, s, "ArmL", Vector3.new(1.6, 0.22, 0.22), CFrame.new(-1.6, 3.1, 0) * CFrame.Angles(0, 0, math.rad(18)), P.WOOD_MID)
	addBox(m, originCF, s, "ArmR", Vector3.new(1.6, 0.22, 0.22), CFrame.new(1.6, 3.1, 0) * CFrame.Angles(0, 0, math.rad(-18)), P.WOOD_MID)
	return m
end

local function buildWoodenCrates(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenCrates", originCF, parent)
	addBox(m, originCF, s, "CrateA", Vector3.new(2.0, 1.9, 2.0), CFrame.new(-0.9, 0.95, 0), P.WOOD_MID)
	addBox(m, originCF, s, "TrimA", Vector3.new(2.12, 0.28, 2.12), CFrame.new(-0.9, 1.65, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "SnowA", Vector3.new(1.9, 0.34, 1.9), CFrame.new(-0.9, 2.05, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "CrateB", Vector3.new(1.7, 1.6, 1.7), CFrame.new(1.1, 0.8, 0.3) * CFrame.Angles(0, math.rad(14), 0), P.WOOD_LIGHT)
	addBox(m, originCF, s, "SnowB", Vector3.new(1.6, 0.32, 1.6), CFrame.new(1.1, 1.76, 0.3) * CFrame.Angles(0, math.rad(14), 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "CrateTop", Vector3.new(1.3, 1.25, 1.3), CFrame.new(-0.85, 2.8, 0) * CFrame.Angles(0, math.rad(-10), 0), P.WOOD_MID)
	addBox(m, originCF, s, "SnowTop", Vector3.new(1.22, 0.28, 1.22), CFrame.new(-0.85, 3.55, 0) * CFrame.Angles(0, math.rad(-10), 0), P.SNOW_PURE)
	return m
end

local function buildFrozenWoodenBarrels(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "FrozenWoodenBarrels", originCF, parent)
	for idx, off in ipairs({ Vector3.new(-0.95, 0, 0.15), Vector3.new(0.95, 0, -0.25) }) do
		addBox(m, originCF, s, "Barrel" .. idx, Vector3.new(1.45, 2.1, 1.45), CFrame.new(off + Vector3.new(0, 1.05, 0)), P.WOOD_MID)
		addBox(m, originCF, s, "HoopTop" .. idx, Vector3.new(1.56, 0.22, 1.56), CFrame.new(off + Vector3.new(0, 1.75, 0)), P.LANTERN_IRON)
		addBox(m, originCF, s, "HoopBot" .. idx, Vector3.new(1.56, 0.22, 1.56), CFrame.new(off + Vector3.new(0, 0.4, 0)), P.LANTERN_IRON)
		addBox(m, originCF, s, "SnowLid" .. idx, Vector3.new(1.38, 0.32, 1.38), CFrame.new(off + Vector3.new(0, 2.25, 0)), P.SNOW_PURE)
	end
	addBox(m, originCF, s, "BarrelIcicle", Vector3.new(0.24, 0.75, 0.24), CFrame.new(-0.25, 1.85, 0.8), P.ICE_PALE, Enum.Material.Glass, false, 0.18, false)
	return m
end

local function buildSnowCoveredSignposts(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SnowCoveredSignposts", originCF, parent)
	addBox(m, originCF, s, "StoneFoot", Vector3.new(1.4, 0.45, 1.4), CFrame.new(0, 0.225, 0), P.SLATE_MID)
	addBox(m, originCF, s, "Post", Vector3.new(0.55, 4.6, 0.55), CFrame.new(0, 2.5, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "BoardTop", Vector3.new(2.8, 0.75, 0.34), CFrame.new(0.35, 4.1, 0.15) * CFrame.Angles(0, math.rad(-8), 0), P.WOOD_LIGHT)
	addBox(m, originCF, s, "BoardSnowA", Vector3.new(2.7, 0.24, 0.36), CFrame.new(0.35, 4.58, 0.15) * CFrame.Angles(0, math.rad(-8), 0), P.SNOW_PURE)
	addBox(m, originCF, s, "BoardBot", Vector3.new(2.4, 0.68, 0.34), CFrame.new(-0.3, 3.05, -0.15) * CFrame.Angles(0, math.rad(12), 0), P.WOOD_MID)
	addBox(m, originCF, s, "BoardSnowB", Vector3.new(2.3, 0.22, 0.36), CFrame.new(-0.3, 3.48, -0.15) * CFrame.Angles(0, math.rad(12), 0), P.SNOW_PURE)
	return m
end

local function buildWoodenFences(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WoodenFences", originCF, parent)
	for i, px in ipairs({ -3.0, 0, 3.0 }) do
		addBox(m, originCF, s, "Post" .. i, Vector3.new(0.55, 2.6, 0.55), CFrame.new(px, 1.3, 0), P.WOOD_DARK)
		addBox(m, originCF, s, "PostSnow" .. i, Vector3.new(0.62, 0.28, 0.62), CFrame.new(px, 2.74, 0), P.SNOW_PURE)
	end
	addBox(m, originCF, s, "RailTop", Vector3.new(6.8, 0.34, 0.28), CFrame.new(0, 2.0, 0), P.WOOD_MID)
	addBox(m, originCF, s, "RailBot", Vector3.new(6.8, 0.34, 0.28), CFrame.new(0, 1.0, 0), P.WOOD_MID)
	addBox(m, originCF, s, "RailSnow", Vector3.new(6.6, 0.18, 0.3), CFrame.new(0, 2.24, 0), P.SNOW_PURE)
	return m
end

local function buildFrozenBenches(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "FrozenBenches", originCF, parent)
	addBox(m, originCF, s, "LegL", Vector3.new(0.45, 1.05, 1.7), CFrame.new(-1.85, 0.525, 0), P.LANTERN_IRON)
	addBox(m, originCF, s, "LegR", Vector3.new(0.45, 1.05, 1.7), CFrame.new(1.85, 0.525, 0), P.LANTERN_IRON)
	addBox(m, originCF, s, "Seat", Vector3.new(4.6, 0.36, 1.85), CFrame.new(0, 1.15, 0.1), P.WOOD_MID)
	addBox(m, originCF, s, "SeatSnow", Vector3.new(4.2, 0.22, 1.5), CFrame.new(0, 1.42, 0.1), P.SNOW_PURE)
	addBox(m, originCF, s, "Backrest", Vector3.new(4.6, 0.95, 0.34), CFrame.new(0, 2.05, -0.75), P.WOOD_DARK)
	addBox(m, originCF, s, "BackSnow", Vector3.new(4.4, 0.24, 0.38), CFrame.new(0, 2.62, -0.75), P.SNOW_PURE)
	return m
end

local function buildWinterCampfire(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "WinterCampfire", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local pos = Vector3.new(math.cos(a) * 1.45, 0.38, math.sin(a) * 1.45)
		addBox(m, originCF, s, "Stone" .. i, Vector3.new(0.85, 0.72, 0.85), CFrame.new(pos) * CFrame.Angles(0, a, 0), if i % 2 == 0 then P.SLATE_DARK else P.SLATE_MID)
	end
	addBox(m, originCF, s, "LogA", Vector3.new(2.2, 0.42, 0.44), CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(35), math.rad(8)), P.WOOD_DARK)
	addBox(m, originCF, s, "LogB", Vector3.new(2.2, 0.42, 0.44), CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(-42), math.rad(-8)), P.WOOD_MID)
	local flame = addBox(m, originCF, s, "FlameCore", Vector3.new(0.85, 1.35, 0.85), CFrame.new(0, 1.1, 0), P.CAMPFIRE_ORANGE, Enum.Material.Neon, false, 0, false)
	addBox(m, originCF, s, "FlameInner", Vector3.new(0.55, 1.0, 0.55), CFrame.new(0.1, 1.45, -0.05), P.WARM_GOLD, Enum.Material.Neon, false, 0, false)
	addPulseLight(flame, P.CAMPFIRE_ORANGE, 22, 1.15, 0.25)
	addEmitter(flame, "CampfireSparks", 8, P.WARM_GOLD, P.CAMPFIRE_ORANGE, NumberSequence.new(0.32, 0.08), Enum.NormalId.Top, NumberRange.new(2.2, 4.2), NumberRange.new(0.8, 1.4), Vector2.new(22, 22), 0.9)
	return m
end

local function buildSmallSnowCoveredWagons(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "SmallSnowCoveredWagons", originCF, parent)
	addBox(m, originCF, s, "Bed", Vector3.new(4.8, 0.55, 2.8), CFrame.new(0, 1.15, 0), P.WOOD_DARK)
	addBox(m, originCF, s, "SideL", Vector3.new(4.6, 1.1, 0.32), CFrame.new(0, 1.9, -1.25), P.WOOD_MID)
	addBox(m, originCF, s, "SideR", Vector3.new(4.6, 1.1, 0.32), CFrame.new(0, 1.9, 1.25), P.WOOD_MID)
	addBox(m, originCF, s, "Canopy", Vector3.new(4.2, 1.5, 2.65), CFrame.new(-0.1, 2.9, 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "CanopySnow", Vector3.new(4.35, 0.5, 2.75), CFrame.new(-0.1, 3.8, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "ShaftL", Vector3.new(2.2, 0.26, 0.26), CFrame.new(3.3, 1.1, -0.85), P.WOOD_LIGHT)
	addBox(m, originCF, s, "ShaftR", Vector3.new(2.2, 0.26, 0.26), CFrame.new(3.3, 1.1, 0.85), P.WOOD_LIGHT)
	for idx, wpos in ipairs({
		Vector3.new(-1.6, 0.72, -1.55),
		Vector3.new(1.6, 0.72, -1.55),
		Vector3.new(-1.6, 0.72, 1.55),
		Vector3.new(1.6, 0.72, 1.55),
	}) do
		addBox(m, originCF, s, "Wheel" .. idx, Vector3.new(1.4, 1.4, 0.34), CFrame.new(wpos), P.WOOD_DARK)
	end
	addBox(m, originCF, s, "Firewood", Vector3.new(1.1, 0.7, 1.6), CFrame.new(1.65, 1.7, 0), P.WOOD_LIGHT)
	return m
end

local function buildDecorativeIceSculptures(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("Decorations", "DecorativeIceSculptures", originCF, parent)
	addBox(m, originCF, s, "Plinth", Vector3.new(2.8, 1.0, 2.8), CFrame.new(0, 0.5, 0), P.SLATE_MID)
	addBox(m, originCF, s, "PlinthSnow", Vector3.new(2.9, 0.32, 2.9), CFrame.new(0, 1.15, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "PillarCore", Vector3.new(1.1, 2.6, 1.1), CFrame.new(0, 2.55, 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "WingL", Vector3.new(1.2, 1.6, 0.55), CFrame.new(-1.05, 3.3, 0) * CFrame.Angles(0, 0, math.rad(18)), P.ICE_CYAN, Enum.Material.Glass, false, 0.2)
	addBox(m, originCF, s, "WingR", Vector3.new(1.2, 1.6, 0.55), CFrame.new(1.05, 3.3, 0) * CFrame.Angles(0, 0, math.rad(-18)), P.ICE_CYAN, Enum.Material.Glass, false, 0.2)
	addBox(m, originCF, s, "CrownTop", Vector3.new(0.85, 1.35, 0.85), CFrame.new(0, 4.35, 0) * CFrame.Angles(0, math.rad(45), 0), P.ICE_PALE, Enum.Material.Glass, false, 0.16)
	return m
end

-- ============================================================================
-- 10. WATER FEATURES (8 Models)
-- ============================================================================

local function buildFrozenLake(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "FrozenLake", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "LakeBed", Vector3.new(13.6, 0.22, 10.6), CFrame.new(0, 0.11, 0), P.ICE_DEEP, Enum.Material.SmoothPlastic, false)
	addBox(m, originCF, s, "IceSheet", Vector3.new(12.2, 0.18, 9.2), CFrame.new(0, 0.22, 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	addBox(m, originCF, s, "BankN", Vector3.new(13.8, 0.65, 1.6), CFrame.new(0, 0.325, -5.2), P.SNOW_PURE)
	addBox(m, originCF, s, "BankS", Vector3.new(13.8, 0.65, 1.6), CFrame.new(0, 0.325, 5.2), P.SNOW_PURE)
	addBox(m, originCF, s, "BankW", Vector3.new(1.6, 0.65, 9.8), CFrame.new(-6.6, 0.325, 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "BankE", Vector3.new(1.6, 0.65, 9.8), CFrame.new(6.6, 0.325, 0), P.SNOW_SHADE)
	addBox(m, originCF, s, "EdgeStone", Vector3.new(2.2, 0.9, 1.8), CFrame.new(-5.2, 0.45, 3.8), P.SLATE_MID)
	addRippleRing(m, originCF, s, "IceShimmer1", Vector3.new(-2.0, 0.34, -0.8), 2.4, 0.2, 0.9)
	addRippleRing(m, originCF, s, "IceShimmer2", Vector3.new(2.2, 0.34, 1.2), 2.0, 1.6, 0.9)
	return m
end

local function buildSmallIcePond(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SmallIcePond", originCF, parent)
	addBox(m, originCF, s, "PondBed", Vector3.new(6.8, 0.2, 5.6), CFrame.new(0, 0.1, 0), P.ICE_DEEP, Enum.Material.SmoothPlastic, false)
	addBox(m, originCF, s, "PondIce", Vector3.new(5.6, 0.18, 4.4), CFrame.new(0, 0.22, 0), P.ICE_PALE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "RimA", Vector3.new(7.0, 0.55, 1.1), CFrame.new(0, 0.275, -2.5), P.SNOW_PURE)
	addBox(m, originCF, s, "RimB", Vector3.new(7.0, 0.55, 1.1), CFrame.new(0, 0.275, 2.5), P.SNOW_PURE)
	addBox(m, originCF, s, "PondBoulder", Vector3.new(1.5, 1.0, 1.3), CFrame.new(-2.8, 0.5, 1.8), P.SLATE_MID)
	addBox(m, originCF, s, "PondReed", Vector3.new(0.24, 1.8, 0.24), CFrame.new(2.5, 0.9, -1.6), P.SPRUCE_TEAL)
	return m
end

local function buildFrozenWaterfall(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "FrozenWaterfall", originCF, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)

	addBox(m, originCF, s, "CliffLeft", Vector3.new(2.4, 5.6, 4.4), CFrame.new(-2.8, 2.8, -0.5), P.SLATE_DARK)
	addBox(m, originCF, s, "CliffRight", Vector3.new(2.4, 5.6, 4.4), CFrame.new(2.8, 2.8, -0.5), P.SLATE_DARK)
	addBox(m, originCF, s, "CliffBack", Vector3.new(3.6, 5.2, 2.4), CFrame.new(0, 2.6, -1.6), P.SLATE_MID)
	addBox(m, originCF, s, "CliffSnowL", Vector3.new(2.5, 0.55, 4.5), CFrame.new(-2.8, 5.8, -0.5), P.SNOW_PURE)
	addBox(m, originCF, s, "CliffSnowR", Vector3.new(2.5, 0.55, 4.5), CFrame.new(2.8, 5.8, -0.5), P.SNOW_PURE)
	addBox(m, originCF, s, "CrestBed", Vector3.new(3.2, 0.35, 2.6), CFrame.new(0, 4.9, -0.3), P.ICE_DEEP, Enum.Material.SmoothPlastic, false)
	addBox(m, originCF, s, "BasinIce", Vector3.new(7.4, 0.24, 5.6), CFrame.new(0, 0.14, 2.8), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	addBox(m, originCF, s, "BasinSnowRim", Vector3.new(8.2, 0.48, 6.2), CFrame.new(0, 0.24, 2.8), P.SNOW_PURE)

	for i = 0, 1 do
		local zPos = -1.0 + i * 1.15
		local seg = addBox(
			m,
			originCF,
			s,
			"CrestFlow" .. i,
			Vector3.new(2.6, 0.28, 1.35),
			CFrame.new(0, 5.18, zPos),
			P.ICE_CYAN,
			Enum.Material.Glass,
			false,
			0.22,
			false
		)
		seg:SetAttribute("FlowAxis", "Forward")
		seg:SetAttribute("LocalX", 0)
		seg:SetAttribute("LocalY", 5.18)
		seg:SetAttribute("StartVal", -1.2)
		seg:SetAttribute("EndVal", 0.95)
		seg:SetAttribute("Speed", 1.8)
		seg:SetAttribute("Phase", i * 0.5)
		seg:SetAttribute("BaseTransparency", 0.22)
	end

	for i = 0, 4 do
		local yPos = 4.5 - i * 0.9
		local seg = addBox(
			m,
			originCF,
			s,
			"FallSegment" .. i,
			Vector3.new(2.7, 1.15, 0.52),
			CFrame.new(0, yPos, 0.95),
			if i % 2 == 0 then P.ICE_CYAN else P.ICE_PALE,
			Enum.Material.Glass,
			false,
			0.2,
			false
		)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", 0)
		seg:SetAttribute("LocalZ", 0.95)
		seg:SetAttribute("StartVal", 4.8)
		seg:SetAttribute("EndVal", 0.35)
		seg:SetAttribute("Speed", 2.9)
		seg:SetAttribute("Phase", i * 0.2)
		seg:SetAttribute("BaseTransparency", 0.2)
	end

	for i = 1, 3 do
		local dx = (i - 2) * 0.9
		local drop = addBox(
			m,
			originCF,
			s,
			"Drop" .. i,
			Vector3.new(0.26, 0.32, 0.26),
			CFrame.new(dx, 2.5, 1.25),
			P.WATER_FOAM,
			Enum.Material.Neon,
			false,
			0.24,
			false
		)
		drop:SetAttribute("AnimKind", "Droplet")
		drop:SetAttribute("LocalX", dx)
		drop:SetAttribute("LocalZ", 1.2)
		drop:SetAttribute("StartY", 4.6)
		drop:SetAttribute("EndY", 0.28)
		drop:SetAttribute("OutArcZ", 0.75)
		drop:SetAttribute("Speed", 2.4 + i * 0.2)
		drop:SetAttribute("Phase", i * 0.33)
		drop:SetAttribute("BaseTransparency", 0.24)
	end

	local foam = addBox(m, originCF, s, "FoamPool", Vector3.new(3.4, 0.32, 1.4), CFrame.new(0, 0.32, 1.3), P.WATER_FOAM, Enum.Material.SmoothPlastic, false)
	addRippleRing(m, originCF, s, "FallRipple1", Vector3.new(0, 0.34, 2.2), 2.8, 0.1, 1.35)
	addRippleRing(m, originCF, s, "FallRipple2", Vector3.new(0, 0.34, 2.2), 2.8, 0.6, 1.35)
	addEmitter(foam, "ColdMist", 6, P.WATER_FOAM, P.ICE_PALE, NumberSequence.new(0.55, 0.18), Enum.NormalId.Top, NumberRange.new(1.0, 2.2), NumberRange.new(1.0, 1.6), Vector2.new(40, 40), 0.25)
	return m
end

local function buildIceCaveEntrance(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "IceCaveEntrance", originCF, parent)
	addBox(m, originCF, s, "MoundL", Vector3.new(2.8, 5.2, 5.2), CFrame.new(-3.6, 2.6, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "MoundR", Vector3.new(2.8, 5.2, 5.2), CFrame.new(3.6, 2.6, 0), P.SLATE_DARK)
	addBox(m, originCF, s, "Backing", Vector3.new(5.6, 5.2, 1.6), CFrame.new(0, 2.6, -2.1), P.COAL_DARK)
	addBox(m, originCF, s, "ArchRoof", Vector3.new(9.8, 2.2, 5.2), CFrame.new(0, 5.8, 0), P.SLATE_MID)
	addBox(m, originCF, s, "SnowRoof", Vector3.new(9.6, 0.7, 5.0), CFrame.new(0, 7.2, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "IceArchL", Vector3.new(1.1, 4.2, 1.4), CFrame.new(-2.1, 2.6, 2.1), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	addBox(m, originCF, s, "IceArchR", Vector3.new(1.1, 4.2, 1.4), CFrame.new(2.1, 2.6, 2.1), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	addBox(m, originCF, s, "InnerGem", Vector3.new(0.75, 1.4, 0.75), CFrame.new(-1.0, 0.7, -0.6), P.ICE_CYAN, Enum.Material.Neon, false, 0.1, false)
	addIcicleRow(m, originCF, s, "FangIce", Vector3.new(-1.5, 4.8, 2.2), Vector3.new(1.0, 0, 0), 4)
	return m
end

local function buildFrozenRiverSections(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "FrozenRiverSections", originCF, parent)
	m:SetAttribute("HasAnimatedWaterfall", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "RiverBed", Vector3.new(4.2, 0.22, 10.6), CFrame.new(0, 0.11, 0), P.ICE_DEEP, Enum.Material.SmoothPlastic, false)
	addBox(m, originCF, s, "IceSurface", Vector3.new(3.8, 0.16, 10.4), CFrame.new(0, 0.22, 0), P.ICE_BLUE, Enum.Material.Ice, false, 0.2)
	addBox(m, originCF, s, "SnowBankL", Vector3.new(1.1, 0.55, 10.6), CFrame.new(-2.45, 0.275, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowBankR", Vector3.new(1.1, 0.55, 10.6), CFrame.new(2.45, 0.275, 0), P.SNOW_PURE)
	for i = 0, 3 do
		local zPos = -3.8 + i * 2.5
		local seg = addBox(
			m,
			originCF,
			s,
			"RiverFlow" .. i,
			Vector3.new(2.2, 0.1, 1.9),
			CFrame.new(0, 0.3, zPos),
			P.ICE_CYAN,
			Enum.Material.Glass,
			false,
			0.28,
			false
		)
		seg:SetAttribute("FlowAxis", "Forward")
		seg:SetAttribute("LocalX", 0)
		seg:SetAttribute("LocalY", 0.3)
		seg:SetAttribute("StartVal", -4.2)
		seg:SetAttribute("EndVal", 4.2)
		seg:SetAttribute("Speed", 1.75)
		seg:SetAttribute("Phase", i * 0.25)
		seg:SetAttribute("BaseTransparency", 0.28)
	end
	return m
end

local function buildIceBridges(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "IceBridges", originCF, parent)
	addBox(m, originCF, s, "RampW", Vector3.new(3.4, 0.48, 3.8), CFrame.new(-4.8, 0.72, 0) * CFrame.Angles(0, 0, math.rad(16)), P.ICE_BLUE, Enum.Material.Ice, false, 0.14)
	addBox(m, originCF, s, "SpanCenter", Vector3.new(6.8, 0.52, 3.8), CFrame.new(0, 1.25, 0), P.ICE_PALE, Enum.Material.Ice, false, 0.14)
	addBox(m, originCF, s, "RampE", Vector3.new(3.4, 0.48, 3.8), CFrame.new(4.8, 0.72, 0) * CFrame.Angles(0, 0, math.rad(-16)), P.ICE_BLUE, Enum.Material.Ice, false, 0.14)
	addBox(m, originCF, s, "SnowCurbN", Vector3.new(6.6, 0.38, 0.45), CFrame.new(0, 1.65, -1.75), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowCurbS", Vector3.new(6.6, 0.38, 0.45), CFrame.new(0, 1.65, 1.75), P.SNOW_PURE)
	for idx, cpos in ipairs({
		Vector3.new(-3.2, 2.15, -1.75),
		Vector3.new(3.2, 2.15, -1.75),
		Vector3.new(-3.2, 2.15, 1.75),
		Vector3.new(3.2, 2.15, 1.75),
	}) do
		addBox(m, originCF, s, "BridgePost" .. idx, Vector3.new(0.55, 1.6, 0.55), CFrame.new(cpos), P.ICE_CYAN, Enum.Material.Glass, false, 0.18)
	end
	return m
end

local function buildSnowCoveredWaterEdges(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "SnowCoveredWaterEdges", originCF, parent)
	addBox(m, originCF, s, "ShelfIce", Vector3.new(5.8, 0.24, 1.8), CFrame.new(0, 0.12, 0.7), P.ICE_PALE, Enum.Material.Ice, false, 0.16)
	addBox(m, originCF, s, "SnowBank", Vector3.new(6.2, 0.65, 1.7), CFrame.new(0, 0.325, -0.65), P.SNOW_PURE)
	addBox(m, originCF, s, "ShoreRock", Vector3.new(1.7, 1.0, 1.4), CFrame.new(-1.8, 0.5, -0.35), P.SLATE_MID)
	addBox(m, originCF, s, "RockSnow", Vector3.new(1.5, 0.35, 1.25), CFrame.new(-1.8, 1.12, -0.35), P.SNOW_PURE)
	addBox(m, originCF, s, "ReedA", Vector3.new(0.22, 1.9, 0.22), CFrame.new(1.8, 0.95, 0.2), P.SPRUCE_TEAL)
	addBox(m, originCF, s, "ReedB", Vector3.new(0.2, 1.5, 0.2), CFrame.new(2.2, 0.75, -0.2), P.PINE_MID)
	return m
end

local function buildBlueIceCrystalPonds(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("WaterFeatures", "BlueIceCrystalPonds", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "PondBed", Vector3.new(7.4, 0.2, 6.8), CFrame.new(0, 0.1, 0), P.ICE_DEEP, Enum.Material.SmoothPlastic, false)
	addBox(m, originCF, s, "CrystalWater", Vector3.new(6.2, 0.18, 5.6), CFrame.new(0, 0.22, 0), P.ICE_CYAN, Enum.Material.Glass, false, 0.22)
	addBox(m, originCF, s, "SnowEdgeL", Vector3.new(1.2, 0.5, 6.2), CFrame.new(-3.2, 0.25, 0), P.SNOW_PURE)
	addBox(m, originCF, s, "SnowEdgeR", Vector3.new(1.2, 0.5, 6.2), CFrame.new(3.2, 0.25, 0), P.SNOW_PURE)
	local shard = addBox(m, originCF, s, "ShardGlow", Vector3.new(0.8, 2.2, 0.8), CFrame.new(-2.8, 1.2, -2.0) * CFrame.Angles(0, 0, math.rad(14)), P.ICE_CYAN, Enum.Material.Neon, false, 0.1, false)
	addPulseLight(shard, P.ICE_CYAN, 16, 0.9, 1.1)
	addBox(m, originCF, s, "ShardB", Vector3.new(0.75, 1.8, 0.75), CFrame.new(2.7, 1.0, 2.1) * CFrame.Angles(0, 0, math.rad(-16)), P.ICE_BLUE, Enum.Material.Ice, false, 0.18)
	addRippleRing(m, originCF, s, "PondRing1", Vector3.new(0, 0.34, 0), 2.3, 0.3, 1.1)
	addRippleRing(m, originCF, s, "PondRing2", Vector3.new(0.8, 0.34, -0.6), 1.8, 1.4, 1.1)
	return m
end

-- ============================================================================
-- 11. ENVIRONMENTAL EFFECTS (4 Models)
-- ============================================================================

local function buildSnowfallEmitter(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("EnvironmentalEffects", "SnowfallEmitter", originCF, parent)
	local cloud = addBox(m, originCF, s, "SnowCloudEmitter", Vector3.new(100, 1, 120), CFrame.new(0, 38, 0), P.SNOW_PURE, Enum.Material.SmoothPlastic, false, 1, false)
	addEmitter(cloud, "FallingSnow", 12, P.SNOW_PURE, P.ICE_PALE, NumberSequence.new(0.28, 0.14), Enum.NormalId.Bottom, NumberRange.new(4, 6), NumberRange.new(6, 8), Vector2.new(14, 14), 0.25)
	return m
end

local function buildSnowWindDrift(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("EnvironmentalEffects", "SnowWindDrift", originCF, parent)
	local tuft = addBox(m, originCF, s, "DriftSnowTuft", Vector3.new(1.8, 0.32, 1.6), CFrame.new(0, 0.16, 0), P.SNOW_PURE)
	addEmitter(tuft, "WindSnowDrift", 6, P.SNOW_PURE, P.SNOW_SHADE, NumberSequence.new(0.26, 0.1), Enum.NormalId.Right, NumberRange.new(4.5, 7.5), NumberRange.new(1.4, 2.4), Vector2.new(20, 20), 0.15)
	return m
end

local function buildFloatingIceSparkles(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("EnvironmentalEffects", "FloatingIceSparkles", originCF, parent)
	local crystal = addBox(m, originCF, s, "SparkleCrystal", Vector3.new(0.75, 1.3, 0.75), CFrame.new(0, 0.65, 0), P.ICE_CYAN, Enum.Material.Ice, false, 0.18, false)
	addEmitter(crystal, "IceSparkleMotes", 4, P.ICE_CYAN, P.SNOW_PURE, NumberSequence.new(0.2, 0.06), Enum.NormalId.Top, NumberRange.new(0.8, 1.8), NumberRange.new(1.8, 3.0), Vector2.new(55, 55), 0.75)
	return m
end

local function buildGlowingFrostAura(originCF: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newModel("EnvironmentalEffects", "GlowingFrostAura", originCF, parent)
	m:SetAttribute("HasEnvironmentalAnim", true)
	m:SetAttribute("IslandScale", s)
	addBox(m, originCF, s, "AuraPlinth", Vector3.new(2.2, 0.45, 2.2), CFrame.new(0, 0.225, 0), P.SLATE_MID)
	local core = addBox(m, originCF, s, "FrostAuraCore", Vector3.new(0.95, 1.6, 0.95), CFrame.new(0, 1.15, 0), P.ICE_CYAN, Enum.Material.Neon, false, 0.1, false)
	addPulseLight(core, P.ICE_CYAN, 18, 0.95, 0.5)
	addEmitter(core, "FrostMistAura", 5, P.ICE_CYAN, P.ICE_PALE, NumberSequence.new(0.32, 0.12), Enum.NormalId.Top, NumberRange.new(0.8, 1.6), NumberRange.new(1.5, 2.5), Vector2.new(45, 45), 0.7)
	return m
end

-- ============================================================================
-- STRUCTURED 55-ASSET CATALOG & LIBRARY LIFECYCLE
-- ============================================================================

WinterBiomeAssetBuilder.Catalog = {
	Trees = {
		{ name = "LargeSnowPineTree", category = "Trees", build = buildLargeSnowPineTree },
		{ name = "MediumSnowPineTree", category = "Trees", build = buildMediumSnowPineTree },
		{ name = "SmallSnowPineTree", category = "Trees", build = buildSmallSnowPineTree },
		{ name = "FrostedSpruceTree", category = "Trees", build = buildFrostedSpruceTree },
		{ name = "FrozenDeadTree", category = "Trees", build = buildFrozenDeadTree },
		{ name = "TwistedWinterTree", category = "Trees", build = buildTwistedWinterTree },
		{ name = "SnowCoveredOakTree", category = "Trees", build = buildSnowCoveredOakTree },
	},
	Bushes = {
		{ name = "SnowCoveredBush", category = "Bushes", build = buildSnowCoveredBush },
		{ name = "FrozenGreenBush", category = "Bushes", build = buildFrozenGreenBush },
		{ name = "SmallSnowCoveredShrubs", category = "Bushes", build = buildSmallSnowCoveredShrubs },
	},
	Plants = {
		{ name = "SmallFrostFern", category = "Plants", build = buildSmallFrostFern },
		{ name = "WinterGrass", category = "Plants", build = buildWinterGrass },
		{ name = "PurpleFrostFlowers", category = "Plants", build = buildPurpleFrostFlowers },
		{ name = "BlueCrystalPlants", category = "Plants", build = buildBlueCrystalPlants },
		{ name = "FrozenReeds", category = "Plants", build = buildFrozenReeds },
	},
	Rocks = {
		{ name = "SnowCoveredBoulder", category = "Rocks", build = buildSnowCoveredBoulder },
		{ name = "FrozenRockFormation", category = "Rocks", build = buildFrozenRockFormation },
		{ name = "FrozenCliffRocks", category = "Rocks", build = buildFrozenCliffRocks },
		{ name = "SmallIceRocks", category = "Rocks", build = buildSmallIceRocks },
	},
	IceCrystals = {
		{ name = "IceSpikes", category = "IceCrystals", build = buildIceSpikes },
		{ name = "BlueIceCrystalCluster", category = "IceCrystals", build = buildBlueIceCrystalCluster },
		{ name = "LargeCrystalFormation", category = "IceCrystals", build = buildLargeCrystalFormation },
	},
	TerrainProps = {
		{ name = "SnowMounds", category = "TerrainProps", build = buildSnowMounds },
		{ name = "SnowCoveredFallenLogs", category = "TerrainProps", build = buildSnowCoveredFallenLogs },
	},
	Ruins = {
		{ name = "AncientFrozenStoneArch", category = "Ruins", build = buildAncientFrozenStoneArch },
		{ name = "BrokenIcePillars", category = "Ruins", build = buildBrokenIcePillars },
		{ name = "AncientSnowRuins", category = "Ruins", build = buildAncientSnowRuins },
		{ name = "SnowCoveredStoneWalls", category = "Ruins", build = buildSnowCoveredStoneWalls },
	},
	Structures = {
		{ name = "FrozenTempleEntrance", category = "Structures", build = buildFrozenTempleEntrance },
		{ name = "IceMonument", category = "Structures", build = buildIceMonument },
		{ name = "FrozenStoneGate", category = "Structures", build = buildFrozenStoneGate },
		{ name = "SmallAbandonedWatchtower", category = "Structures", build = buildSmallAbandonedWatchtower },
		{ name = "FrozenCastleDecoration", category = "Structures", build = buildFrozenCastleDecoration },
	},
	Decorations = {
		{ name = "WoodenWinterLantern", category = "Decorations", build = buildWoodenWinterLantern },
		{ name = "Snowman", category = "Decorations", build = buildSnowman },
		{ name = "WoodenCrates", category = "Decorations", build = buildWoodenCrates },
		{ name = "FrozenWoodenBarrels", category = "Decorations", build = buildFrozenWoodenBarrels },
		{ name = "SnowCoveredSignposts", category = "Decorations", build = buildSnowCoveredSignposts },
		{ name = "WoodenFences", category = "Decorations", build = buildWoodenFences },
		{ name = "FrozenBenches", category = "Decorations", build = buildFrozenBenches },
		{ name = "WinterCampfire", category = "Decorations", build = buildWinterCampfire },
		{ name = "SmallSnowCoveredWagons", category = "Decorations", build = buildSmallSnowCoveredWagons },
		{ name = "DecorativeIceSculptures", category = "Decorations", build = buildDecorativeIceSculptures },
	},
	WaterFeatures = {
		{ name = "FrozenLake", category = "WaterFeatures", build = buildFrozenLake },
		{ name = "SmallIcePond", category = "WaterFeatures", build = buildSmallIcePond },
		{ name = "FrozenWaterfall", category = "WaterFeatures", build = buildFrozenWaterfall },
		{ name = "IceCaveEntrance", category = "WaterFeatures", build = buildIceCaveEntrance },
		{ name = "FrozenRiverSections", category = "WaterFeatures", build = buildFrozenRiverSections },
		{ name = "IceBridges", category = "WaterFeatures", build = buildIceBridges },
		{ name = "SnowCoveredWaterEdges", category = "WaterFeatures", build = buildSnowCoveredWaterEdges },
		{ name = "BlueIceCrystalPonds", category = "WaterFeatures", build = buildBlueIceCrystalPonds },
	},
	EnvironmentalEffects = {
		{ name = "SnowfallEmitter", category = "EnvironmentalEffects", build = buildSnowfallEmitter },
		{ name = "SnowWindDrift", category = "EnvironmentalEffects", build = buildSnowWindDrift },
		{ name = "FloatingIceSparkles", category = "EnvironmentalEffects", build = buildFloatingIceSparkles },
		{ name = "GlowingFrostAura", category = "EnvironmentalEffects", build = buildGlowingFrostAura },
	},
}

local EXPECTED_LIBRARY_VERSION = 1

function WinterBiomeAssetBuilder.EnsureLibrary(parentOverride: Instance?): Folder
	local rootParent: Instance = parentOverride or ServerStorage
	local existing = rootParent:FindFirstChild("WinterBiomeAssets")
	if existing and existing:IsA("Folder") and existing:GetAttribute("LibraryVersion") == EXPECTED_LIBRARY_VERSION then
		local complete = true
		for _, catName in ipairs(WinterBiomeAssetBuilder.CATEGORIES) do
			local sub = existing:FindFirstChild(catName)
			local list = (WinterBiomeAssetBuilder.Catalog :: any)[catName]
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
	lib.Name = "WinterBiomeAssets"
	lib:SetAttribute("BiomeId", "AlpinePeaks")
	lib:SetAttribute("LibraryVersion", EXPECTED_LIBRARY_VERSION)

	local totalCount = 0
	for _, catName in ipairs(WinterBiomeAssetBuilder.CATEGORIES) do
		local catFolder = Instance.new("Folder")
		catFolder.Name = catName
		local list = (WinterBiomeAssetBuilder.Catalog :: any)[catName] :: { AssetEntry }
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

function WinterBiomeAssetBuilder.SpawnFromLibrary(
	category: string,
	assetName: string,
	cframe: CFrame,
	scale: number?,
	parent: Instance?
): Model
	local lib = WinterBiomeAssetBuilder.EnsureLibrary()
	local catFolder = lib:FindFirstChild(category)
	local template = if catFolder then catFolder:FindFirstChild(assetName) else nil
	if not template or not template:IsA("Model") then
		error(string.format("[WinterBiomeAssetBuilder] Asset '%s/%s' not found in WinterBiomeAssets", category, assetName))
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

return WinterBiomeAssetBuilder
