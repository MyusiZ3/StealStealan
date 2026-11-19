--!strict
-- ClassicStudBiomeBuilder.luau
-- Generates Classic Studs environment asset kits (trees, landmarks, grass, flora, rocks, ruins, props)
-- and full dioramas for all 5 Biomes (PineWoods, MangroveSwamp, SavannaCamp, AlpinePeaks, VolcanicJungle)
-- in PetLab_Showroom with zero colliders (CanCollide = false, CanQuery = false, CanTouch = false).

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClassicStudBiomeBuilder = {}

local STUDS_COLOR_MAP = "rbxassetid://10509831729"
local STUDS_NORMAL_MAP = "rbxassetid://10509831753"
local SHOWROOM_FLOOR_Y = 0.04

export type AssetSpec = {
	id: string,
	title: string,
	category: "Tree" | "Flora" | "Prop",
	catalogScale: number?,
	build: (cframe: CFrame, scale: number?, parent: Instance?) -> Model,
}

function ClassicStudBiomeBuilder.EnsureClassicStudsVariant(): MaterialVariant?
	local existing = MaterialService:FindFirstChild("Studs", true)
	if existing and existing:IsA("MaterialVariant") then
		return existing
	end
	if RunService:IsRunning() and not RunService:IsStudio() then
		return nil
	end
	local ok, variant = pcall(function()
		local v = Instance.new("MaterialVariant")
		v.Name = "Studs"
		v.BaseMaterial = Enum.Material.Plastic
		v.ColorMap = STUDS_COLOR_MAP
		v.NormalMap = STUDS_NORMAL_MAP
		v.StudsPerTile = 1
		v.Parent = MaterialService
		return v
	end)
	return if ok then variant else nil
end

local function makeStudPart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	studded: boolean?,
	transparency: number?,
	castShadow: boolean?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	local mat = props.material or Enum.Material.Plastic
	p.Material = mat
	local useStuds = (props.studded ~= false) and (mat == Enum.Material.Plastic)
	if useStuds then
		p.MaterialVariant = "Studs"
	end
	p.TopSurface = if useStuds then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = if props.castShadow ~= nil then props.castShadow else true
	p.Transparency = props.transparency or 0
	p.Parent = props.parent
	return p
end

local function newAssetModel(name: string, originCF: CFrame, parent: Instance?): (Model, Part)
	ClassicStudBiomeBuilder.EnsureClassicStudsVariant()
	local m = Instance.new("Model")
	m.Name = name
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
	return m, anchor
end

local function createBlock(
	m: Model,
	originCF: CFrame,
	s: number,
	name: string,
	size: Vector3,
	localCF: CFrame,
	color: Color3,
	mat: Enum.Material?,
	studded: boolean?,
	transparency: number?
): Part
	local pos = localCF.Position * s
	local rot = localCF - localCF.Position
	return makeStudPart({
		name = name,
		size = size * s,
		cframe = originCF * CFrame.new(pos) * rot,
		color = color,
		material = mat,
		studded = studded,
		transparency = transparency,
		parent = m,
	})
end

local function addLanternLight(part: BasePart, color: Color3, range: number?, brightness: number?): PointLight
	local pl = Instance.new("PointLight")
	pl.Name = "VoxelLight"
	pl.Color = color
	pl.Range = range or 18
	pl.Brightness = brightness or 1.15
	pl.Shadows = false
	pl.Parent = part
	return pl
end

local function addSelectiveParticles(
	parent: BasePart,
	kind: "WaterfallMist" | "Fireflies" | "SwampSpores" | "Snowfall" | "FireEmbers" | "VolcanoSmoke"
): ParticleEmitter
	local em = Instance.new("ParticleEmitter")
	em.Name = "BiomeParticle_" .. kind
	em.LockedToPart = false
	if kind == "WaterfallMist" then
		em.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255), Color3.fromRGB(255, 255, 255))
		em.Rate = 7
		em.Lifetime = NumberRange.new(1.2, 2.2)
		em.Speed = NumberRange.new(1.5, 4.5)
		em.SpreadAngle = Vector2.new(65, 65)
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2.6) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		em.EmissionDirection = Enum.NormalId.Top
	elseif kind == "Fireflies" then
		em.Color = ColorSequence.new(Color3.fromRGB(192, 255, 118), Color3.fromRGB(255, 232, 112))
		em.Rate = 4
		em.Lifetime = NumberRange.new(2.2, 3.8)
		em.Speed = NumberRange.new(0.8, 2.0)
		em.SpreadAngle = Vector2.new(180, 180)
		em.LightEmission = 0.75
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.28), NumberSequenceKeypoint.new(1, 0) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.15), NumberSequenceKeypoint.new(1, 1) })
	elseif kind == "SwampSpores" then
		em.Color = ColorSequence.new(Color3.fromRGB(142, 255, 168), Color3.fromRGB(218, 255, 128))
		em.Rate = 5
		em.Lifetime = NumberRange.new(2.4, 4.0)
		em.Speed = NumberRange.new(0.6, 1.8)
		em.SpreadAngle = Vector2.new(180, 180)
		em.LightEmission = 0.65
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.4, 0.2), NumberSequenceKeypoint.new(1, 1) })
	elseif kind == "Snowfall" then
		em.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255), Color3.fromRGB(204, 236, 255))
		em.Rate = 10
		em.Lifetime = NumberRange.new(2.5, 4.2)
		em.Speed = NumberRange.new(2.5, 5.0)
		em.SpreadAngle = Vector2.new(24, 24)
		em.EmissionDirection = Enum.NormalId.Bottom
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.16) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) })
	elseif kind == "FireEmbers" then
		em.Color = ColorSequence.new(Color3.fromRGB(255, 198, 56), Color3.fromRGB(255, 74, 22))
		em.Rate = 6
		em.Lifetime = NumberRange.new(1.4, 2.6)
		em.Speed = NumberRange.new(2.2, 5.5)
		em.SpreadAngle = Vector2.new(35, 35)
		em.LightEmission = 0.8
		em.EmissionDirection = Enum.NormalId.Top
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.04) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	elseif kind == "VolcanoSmoke" then
		em.Color = ColorSequence.new(Color3.fromRGB(82, 74, 88), Color3.fromRGB(132, 124, 138))
		em.Rate = 8
		em.Lifetime = NumberRange.new(3.5, 5.5)
		em.Speed = NumberRange.new(4.0, 7.5)
		em.SpreadAngle = Vector2.new(28, 28)
		em.EmissionDirection = Enum.NormalId.Top
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 8.5) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	end
	em.Parent = parent
	return em
end

local function addGrassBladesHelper(
	m: Model,
	originCF: CFrame,
	s: number,
	padCol: Color3,
	colA: Color3,
	colB: Color3,
	tipCol: Color3,
	tipMat: Enum.Material?
)
	createBlock(m, originCF, s, "TurfPad", Vector3.new(3.2, 0.22, 3.2), CFrame.new(0, 0.11, 0), padCol)
	local blades = {
		{ pos = Vector3.new(-0.85, 0.85, -0.5), sz = Vector3.new(0.45, 1.6, 0.45), tilt = Vector3.new(-10, 15, 12), col = colA },
		{ pos = Vector3.new(-0.15, 1.15, 0.1), sz = Vector3.new(0.48, 2.2, 0.48), tilt = Vector3.new(6, -10, -5), col = colB },
		{ pos = Vector3.new(0.75, 0.95, -0.35), sz = Vector3.new(0.42, 1.8, 0.42), tilt = Vector3.new(-8, 28, -14), col = colA },
		{ pos = Vector3.new(0.3, 0.75, 0.85), sz = Vector3.new(0.44, 1.4, 0.44), tilt = Vector3.new(14, -20, 8), col = tipCol, isTip = true },
		{ pos = Vector3.new(-0.65, 0.7, 0.7), sz = Vector3.new(0.4, 1.3, 0.4), tilt = Vector3.new(12, 18, 10), col = colA },
		{ pos = Vector3.new(0.95, 0.65, 0.65), sz = Vector3.new(0.38, 1.2, 0.38), tilt = Vector3.new(9, 40, -12), col = tipCol, isTip = true },
	}
	for idx, b in ipairs(blades) do
		local ang = CFrame.Angles(math.rad(b.tilt.X), math.rad(b.tilt.Y), math.rad(b.tilt.Z))
		local mat = if b.isTip and tipMat then tipMat else nil
		createBlock(m, originCF, s, "Blade_" .. idx, b.sz, CFrame.new(b.pos) * ang, b.col, mat, mat == nil)
	end
end

-- ============================================================================
-- BIOME 1: WHISPERING PINE WOODS (15 ASSETS)
-- ============================================================================

function ClassicStudBiomeBuilder.BuildPineTreeTall(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("PineTreeTall", cframe, parent)
	local barkDark, barkMid = Color3.fromRGB(92, 58, 36), Color3.fromRGB(110, 72, 46)
	local leafDeep, leafMid, leafBright = Color3.fromRGB(38, 102, 48), Color3.fromRGB(54, 134, 62), Color3.fromRGB(78, 166, 76)

	for idx, off in ipairs({ Vector3.new(1.1, 0.45, 0), Vector3.new(-1.1, 0.45, 0), Vector3.new(0, 0.45, 1.1), Vector3.new(0, 0.45, -1.1) }) do
		createBlock(m, cframe, s, "Root_" .. idx, Vector3.new(1.3, 0.9, 1.3), CFrame.new(off), barkDark)
	end
	createBlock(m, cframe, s, "TrunkLower", Vector3.new(1.8, 5.5, 1.8), CFrame.new(0, 2.75, 0), barkMid)
	createBlock(m, cframe, s, "TrunkUpper", Vector3.new(1.3, 9.0, 1.3), CFrame.new(0, 8.8, 0), barkDark)

	for idx, t in ipairs({
		{ y = 5.4, w = 8.4, h = 2.1, col = leafDeep },
		{ y = 7.7, w = 6.9, h = 2.0, col = leafMid },
		{ y = 9.9, w = 5.4, h = 1.9, col = leafDeep },
		{ y = 12.0, w = 3.9, h = 1.8, col = leafBright },
		{ y = 13.9, w = 2.3, h = 1.7, col = leafMid },
	}) do
		createBlock(m, cframe, s, "FoliageTier_" .. idx, Vector3.new(t.w, t.h, t.w), CFrame.new(0, t.y, 0), t.col)
		if idx < 5 then
			createBlock(m, cframe, s, "FoliageCap_" .. idx, Vector3.new(t.w - 1.1, 0.55, t.w - 1.1), CFrame.new(0, t.y + t.h * 0.5 + 0.25, 0), leafBright)
		end
	end
	createBlock(m, cframe, s, "PineTipSpire", Vector3.new(1.1, 1.4, 1.1), CFrame.new(0, 15.3, 0), leafBright)
	return m
end

function ClassicStudBiomeBuilder.BuildPineTreeTwin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("PineTreeTwin", cframe, parent)
	local bark, barkShade = Color3.fromRGB(98, 64, 42), Color3.fromRGB(80, 52, 34)
	local pineA, pineB = Color3.fromRGB(44, 118, 56), Color3.fromRGB(66, 150, 72)

	createBlock(m, cframe, s, "MainTrunk", Vector3.new(1.6, 8.2, 1.6), CFrame.new(-0.9, 4.1, -0.3), bark)
	createBlock(m, cframe, s, "MainRoot", Vector3.new(2.6, 0.8, 2.6), CFrame.new(-0.9, 0.4, -0.3), barkShade)
	for idx, t in ipairs({ { y = 5.2, w = 6.8, h = 1.8, col = pineA }, { y = 7.2, w = 5.2, h = 1.7, col = pineB }, { y = 9.0, w = 3.6, h = 1.6, col = pineA }, { y = 10.6, w = 2.0, h = 1.4, col = pineB } }) do
		createBlock(m, cframe, s, "MainTier_" .. idx, Vector3.new(t.w, t.h, t.w), CFrame.new(-0.9, t.y, -0.3), t.col)
	end
	createBlock(m, cframe, s, "SideTrunk", Vector3.new(1.2, 5.4, 1.2), CFrame.new(2.2, 2.7, 1.1), barkShade)
	for idx, t in ipairs({ { y = 3.7, w = 4.6, h = 1.5, col = pineB }, { y = 5.3, w = 3.3, h = 1.4, col = pineA }, { y = 6.7, w = 1.9, h = 1.2, col = pineB } }) do
		createBlock(m, cframe, s, "SideTier_" .. idx, Vector3.new(t.w, t.h, t.w), CFrame.new(2.2, t.y, 1.1), t.col)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildOakTreeBroad(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("OakTreeBroad", cframe, parent)
	local bark, barkDeep = Color3.fromRGB(116, 74, 44), Color3.fromRGB(92, 58, 34)
	local oakDark, oakMid, oakBright = Color3.fromRGB(56, 134, 52), Color3.fromRGB(78, 168, 64), Color3.fromRGB(108, 194, 78)

	createBlock(m, cframe, s, "OakRootBase", Vector3.new(3.4, 1.0, 3.4), CFrame.new(0, 0.5, 0), barkDeep)
	createBlock(m, cframe, s, "OakTrunk", Vector3.new(2.2, 5.8, 2.2), CFrame.new(0, 3.3, 0), bark)
	createBlock(m, cframe, s, "OakBranchL", Vector3.new(2.8, 1.1, 1.2), CFrame.new(-1.8, 5.6, 0.2) * CFrame.Angles(0, 0, math.rad(-18)), barkDeep)
	createBlock(m, cframe, s, "OakBranchR", Vector3.new(2.6, 1.1, 1.2), CFrame.new(1.7, 5.3, -0.3) * CFrame.Angles(0, 0, math.rad(16)), barkDeep)
	createBlock(m, cframe, s, "CanopyCore", Vector3.new(7.4, 4.2, 7.4), CFrame.new(0, 7.6, 0), oakDark)
	createBlock(m, cframe, s, "CanopyMid", Vector3.new(8.8, 2.6, 6.6), CFrame.new(0, 7.9, 0), oakMid)
	createBlock(m, cframe, s, "CanopyCross", Vector3.new(6.6, 2.6, 8.8), CFrame.new(0, 7.9, 0), oakMid)
	createBlock(m, cframe, s, "CanopyUpper", Vector3.new(5.6, 2.0, 5.6), CFrame.new(0, 10.3, 0), oakBright)
	createBlock(m, cframe, s, "CanopyCrown", Vector3.new(3.2, 1.2, 3.2), CFrame.new(0.4, 11.7, -0.3), oakBright)
	return m
end

function ClassicStudBiomeBuilder.BuildBirchTreeForest(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("BirchTreeForest", cframe, parent)
	local birchWhite, birchSpot = Color3.fromRGB(234, 232, 224), Color3.fromRGB(54, 56, 60)
	local leafLime, leafLeaf = Color3.fromRGB(116, 198, 72), Color3.fromRGB(88, 168, 58)

	createBlock(m, cframe, s, "BirchBase", Vector3.new(1.8, 0.7, 1.8), CFrame.new(0, 0.35, 0), birchSpot)
	createBlock(m, cframe, s, "BirchTrunk", Vector3.new(1.25, 7.2, 1.25), CFrame.new(0, 3.8, 0), birchWhite)
	for idx, by in ipairs({ 1.6, 3.0, 4.4, 5.8 }) do
		createBlock(m, cframe, s, "BarkStripe_" .. idx, Vector3.new(1.32, 0.38, 1.32), CFrame.new(0, by, 0), birchSpot)
	end
	createBlock(m, cframe, s, "BirchLeavesLow", Vector3.new(6.0, 2.5, 6.0), CFrame.new(0, 8.2, 0), leafLeaf)
	createBlock(m, cframe, s, "BirchLeavesSide", Vector3.new(7.0, 1.9, 4.6), CFrame.new(0.3, 8.7, 0.2), leafLime)
	createBlock(m, cframe, s, "BirchLeavesTop", Vector3.new(4.4, 2.0, 4.4), CFrame.new(-0.2, 10.3, 0), leafLime)
	return m
end

function ClassicStudBiomeBuilder.BuildGrassTuftCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("GrassTuftCluster", cframe, parent)
	addGrassBladesHelper(m, cframe, s, Color3.fromRGB(72, 152, 62), Color3.fromRGB(72, 152, 62), Color3.fromRGB(98, 184, 74), Color3.fromRGB(130, 212, 88))
	return m
end

function ClassicStudBiomeBuilder.BuildMossyTurfPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MossyTurfPatch", cframe, parent)
	createBlock(m, cframe, s, "MossBase", Vector3.new(6.8, 0.28, 6.2), CFrame.new(0, 0.14, 0), Color3.fromRGB(78, 152, 66))
	createBlock(m, cframe, s, "MossMid", Vector3.new(4.6, 0.36, 4.2), CFrame.new(-0.5, 0.36, 0.3), Color3.fromRGB(98, 182, 74))
	createBlock(m, cframe, s, "MossTop", Vector3.new(2.4, 0.32, 2.2), CFrame.new(-0.8, 0.62, 0.2), Color3.fromRGB(124, 206, 86))
	createBlock(m, cframe, s, "CloverPad", Vector3.new(2.1, 0.26, 2.3), CFrame.new(1.5, 0.32, -1.1), Color3.fromRGB(112, 194, 78))
	createBlock(m, cframe, s, "PebbleA", Vector3.new(0.8, 0.45, 0.8), CFrame.new(1.8, 0.42, 1.2), Color3.fromRGB(142, 146, 152))
	createBlock(m, cframe, s, "PebbleB", Vector3.new(0.55, 0.35, 0.55), CFrame.new(2.4, 0.35, 0.6), Color3.fromRGB(164, 168, 174))
	return m
end

function ClassicStudBiomeBuilder.BuildFernCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FernCluster", cframe, parent)
	createBlock(m, cframe, s, "FernHub", Vector3.new(1.2, 0.7, 1.2), CFrame.new(0, 0.35, 0), Color3.fromRGB(48, 126, 56))
	for idx = 0, 5 do
		local yaw = math.rad(idx * 60)
		createBlock(m, cframe, s, "FrondBase_" .. idx, Vector3.new(0.7, 0.28, 1.9), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.75, 1.2) * CFrame.Angles(math.rad(22), 0, 0), Color3.fromRGB(76, 168, 68))
		createBlock(m, cframe, s, "FrondTip_" .. idx, Vector3.new(0.5, 0.24, 1.1), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 1.05, 2.25) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(108, 198, 82))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildBerryBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("BerryBush", cframe, parent)
	local bushDeep, bushBright = Color3.fromRGB(46, 118, 48), Color3.fromRGB(72, 158, 62)
	local berryRed, berryBlue = Color3.fromRGB(224, 54, 66), Color3.fromRGB(64, 148, 242)
	createBlock(m, cframe, s, "BushCore", Vector3.new(3.6, 2.2, 3.6), CFrame.new(0, 1.1, 0), bushDeep)
	createBlock(m, cframe, s, "BushSideL", Vector3.new(2.2, 1.6, 2.4), CFrame.new(-1.3, 0.8, 0.3), bushBright)
	createBlock(m, cframe, s, "BushSideR", Vector3.new(2.2, 1.5, 2.2), CFrame.new(1.2, 0.75, -0.4), bushBright)
	createBlock(m, cframe, s, "BushTop", Vector3.new(2.3, 1.2, 2.3), CFrame.new(0, 2.4, 0), bushBright)
	for idx, b in ipairs({
		{ pos = Vector3.new(-1.85, 1.35, 0.6), col = berryRed },
		{ pos = Vector3.new(-0.7, 1.75, 1.85), col = berryBlue },
		{ pos = Vector3.new(1.1, 1.95, 1.65), col = berryRed },
		{ pos = Vector3.new(1.85, 1.15, -0.6), col = berryBlue },
		{ pos = Vector3.new(-0.3, 2.75, -1.15), col = berryRed },
	}) do
		createBlock(m, cframe, s, "Berry_" .. idx, Vector3.new(0.45, 0.45, 0.45), CFrame.new(b.pos), b.col)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildWildflowerPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("WildflowerPatch", cframe, parent)
	createBlock(m, cframe, s, "FlowerTurf", Vector3.new(3.8, 0.2, 3.8), CFrame.new(0, 0.1, 0), Color3.fromRGB(90, 174, 72))
	for idx, fl in ipairs({
		{ x = -1.0, z = -0.8, h = 1.1, petal = Color3.fromRGB(255, 214, 62), center = Color3.fromRGB(218, 128, 32) },
		{ x = 0.8, z = -0.9, h = 1.35, petal = Color3.fromRGB(244, 246, 250), center = Color3.fromRGB(255, 206, 56) },
		{ x = 0.1, z = 0.3, h = 1.5, petal = Color3.fromRGB(94, 186, 255), center = Color3.fromRGB(246, 248, 255) },
		{ x = -0.7, z = 1.0, h = 1.0, petal = Color3.fromRGB(255, 118, 152), center = Color3.fromRGB(255, 224, 92) },
		{ x = 1.1, z = 0.8, h = 1.2, petal = Color3.fromRGB(255, 214, 62), center = Color3.fromRGB(218, 128, 32) },
	}) do
		createBlock(m, cframe, s, "Stem_" .. idx, Vector3.new(0.22, fl.h, 0.22), CFrame.new(fl.x, fl.h * 0.5 + 0.15, fl.z), Color3.fromRGB(64, 148, 56))
		createBlock(m, cframe, s, "Petals_" .. idx, Vector3.new(0.82, 0.22, 0.82), CFrame.new(fl.x, fl.h + 0.24, fl.z), fl.petal)
		createBlock(m, cframe, s, "Core_" .. idx, Vector3.new(0.38, 0.28, 0.38), CFrame.new(fl.x, fl.h + 0.34, fl.z), fl.center)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildMossyBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MossyBoulder", cframe, parent)
	createBlock(m, cframe, s, "BoulderBase", Vector3.new(5.2, 2.2, 4.6), CFrame.new(0, 1.1, 0), Color3.fromRGB(108, 114, 122))
	createBlock(m, cframe, s, "BoulderMid", Vector3.new(3.8, 1.6, 3.6), CFrame.new(-0.3, 2.7, 0.2), Color3.fromRGB(134, 140, 148))
	createBlock(m, cframe, s, "BoulderLedge", Vector3.new(2.2, 1.3, 2.6), CFrame.new(1.8, 0.65, -0.8), Color3.fromRGB(134, 140, 148))
	createBlock(m, cframe, s, "MossCapMain", Vector3.new(3.9, 0.42, 3.7), CFrame.new(-0.3, 3.65, 0.2), Color3.fromRGB(82, 164, 68))
	createBlock(m, cframe, s, "MossCapSide", Vector3.new(2.1, 0.35, 2.3), CFrame.new(1.75, 1.42, -0.8), Color3.fromRGB(108, 192, 78))
	return m
end

function ClassicStudBiomeBuilder.BuildRockCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("RockCluster", cframe, parent)
	createBlock(m, cframe, s, "RockA", Vector3.new(2.8, 1.6, 2.4), CFrame.new(-0.8, 0.8, 0.2) * CFrame.Angles(0, math.rad(14), 0), Color3.fromRGB(122, 128, 136))
	createBlock(m, cframe, s, "RockATop", Vector3.new(1.8, 0.7, 1.6), CFrame.new(-0.9, 1.9, 0.1) * CFrame.Angles(0, math.rad(14), 0), Color3.fromRGB(144, 150, 158))
	createBlock(m, cframe, s, "RockB", Vector3.new(2.0, 1.1, 1.9), CFrame.new(1.3, 0.55, -0.5) * CFrame.Angles(0, math.rad(-22), 0), Color3.fromRGB(106, 112, 120))
	createBlock(m, cframe, s, "RockC", Vector3.new(1.4, 0.7, 1.3), CFrame.new(0.8, 0.35, 1.2) * CFrame.Angles(0, math.rad(30), 0), Color3.fromRGB(136, 142, 148))
	createBlock(m, cframe, s, "RockMoss", Vector3.new(0.8, 0.35, 0.8), CFrame.new(-0.3, 1.75, 0.5), Color3.fromRGB(92, 174, 72))
	return m
end

function ClassicStudBiomeBuilder.BuildFallenHollowLog(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FallenHollowLog", cframe, parent)
	createBlock(m, cframe, s, "LogBody", Vector3.new(6.8, 1.9, 2.0), CFrame.new(0, 0.95, 0), Color3.fromRGB(106, 68, 40))
	createBlock(m, cframe, s, "LogBarkRidge", Vector3.new(5.2, 0.35, 2.2), CFrame.new(-0.3, 0.5, 0), Color3.fromRGB(82, 52, 30))
	createBlock(m, cframe, s, "LogCoreL", Vector3.new(0.24, 1.35, 1.45), CFrame.new(-3.36, 0.95, 0), Color3.fromRGB(194, 156, 102))
	createBlock(m, cframe, s, "LogCoreR", Vector3.new(0.24, 1.35, 1.45), CFrame.new(3.36, 0.95, 0), Color3.fromRGB(194, 156, 102))
	createBlock(m, cframe, s, "LogMossA", Vector3.new(2.8, 0.3, 1.4), CFrame.new(-1.1, 2.0, 0.1), Color3.fromRGB(88, 172, 68))
	createBlock(m, cframe, s, "ShelfShroom", Vector3.new(0.8, 0.22, 0.7), CFrame.new(-0.6, 1.2, 1.15), Color3.fromRGB(238, 198, 128))
	return m
end

function ClassicStudBiomeBuilder.BuildTreeStump(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("TreeStump", cframe, parent)
	createBlock(m, cframe, s, "StumpRoots", Vector3.new(3.2, 0.65, 3.2), CFrame.new(0, 0.32, 0), Color3.fromRGB(84, 52, 32))
	createBlock(m, cframe, s, "StumpBody", Vector3.new(2.3, 1.75, 2.3), CFrame.new(0, 1.0, 0), Color3.fromRGB(108, 68, 42))
	createBlock(m, cframe, s, "StumpCore", Vector3.new(1.75, 0.2, 1.75), CFrame.new(0, 1.92, 0), Color3.fromRGB(208, 172, 114))
	createBlock(m, cframe, s, "StumpRing", Vector3.new(0.85, 0.24, 0.85), CFrame.new(0, 1.94, 0), Color3.fromRGB(184, 144, 88))
	createBlock(m, cframe, s, "SproutLeaf", Vector3.new(0.85, 0.25, 0.65), CFrame.new(1.4, 1.5, 0.2), Color3.fromRGB(110, 198, 82))
	return m
end

function ClassicStudBiomeBuilder.BuildMushroomCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MushroomCluster", cframe, parent)
	for idx, sh in ipairs({
		{ x = 0, z = 0, stemH = 1.25, stemW = 0.52, capW = 1.55, capH = 0.62 },
		{ x = -0.95, z = 0.65, stemH = 0.85, stemW = 0.38, capW = 1.1, capH = 0.45 },
		{ x = 0.9, z = -0.55, stemH = 0.65, stemW = 0.32, capW = 0.9, capH = 0.38 },
	}) do
		createBlock(m, cframe, s, "Stem_" .. idx, Vector3.new(sh.stemW, sh.stemH, sh.stemW), CFrame.new(sh.x, sh.stemH * 0.5, sh.z), Color3.fromRGB(238, 228, 206))
		createBlock(m, cframe, s, "Cap_" .. idx, Vector3.new(sh.capW, sh.capH, sh.capW), CFrame.new(sh.x, sh.stemH + sh.capH * 0.45, sh.z), Color3.fromRGB(218, 56, 56))
		createBlock(m, cframe, s, "Spot_" .. idx, Vector3.new(sh.capW * 0.28, 0.18, sh.capW * 0.28), CFrame.new(sh.x + sh.capW * 0.16, sh.stemH + sh.capH * 0.88, sh.z - sh.capW * 0.12), Color3.fromRGB(248, 246, 240))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildRangerLanternPost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("RangerLanternPost", cframe, parent)
	local wood, iron, glow = Color3.fromRGB(112, 72, 42), Color3.fromRGB(48, 54, 64), Color3.fromRGB(255, 206, 94)
	createBlock(m, cframe, s, "PostFooting", Vector3.new(1.5, 0.6, 1.5), CFrame.new(0, 0.3, 0), Color3.fromRGB(118, 124, 132))
	createBlock(m, cframe, s, "PostShaft", Vector3.new(0.85, 6.2, 0.85), CFrame.new(0, 3.4, 0), wood)
	createBlock(m, cframe, s, "CrossArm", Vector3.new(2.2, 0.55, 0.65), CFrame.new(0.85, 6.1, 0), wood)
	createBlock(m, cframe, s, "LanternCap", Vector3.new(1.3, 0.35, 1.3), CFrame.new(1.65, 5.45, 0), iron)
	createBlock(m, cframe, s, "LanternGlow", Vector3.new(0.9, 1.0, 0.9), CFrame.new(1.65, 4.78, 0), glow, Enum.Material.Neon, false)
	createBlock(m, cframe, s, "LanternBase", Vector3.new(1.15, 0.28, 1.15), CFrame.new(1.65, 4.18, 0), iron)
	return m
end

-- ============================================================================
-- BIOME 2: MUDDY MANGROVE SWAMP (13 ASSETS)
-- ============================================================================

function ClassicStudBiomeBuilder.BuildMangroveTreeArch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MangroveTreeArch", cframe, parent)
	local bark, moss = Color3.fromRGB(84, 62, 46), Color3.fromRGB(64, 136, 78)
	local leafDeep, leafTeal = Color3.fromRGB(46, 108, 68), Color3.fromRGB(70, 152, 92)

	-- 4 arched aerial prop roots lifting the main trunk above muddy water
	for idx, ang in ipairs({ 0, 90, 180, 270 }) do
		local rCF = CFrame.Angles(0, math.rad(ang), 0)
		createBlock(m, cframe, s, "PropRootFoot_" .. idx, Vector3.new(0.9, 2.4, 0.9), rCF * CFrame.new(2.1, 1.2, 0), bark)
		createBlock(m, cframe, s, "PropRootKnee_" .. idx, Vector3.new(1.8, 0.85, 0.85), rCF * CFrame.new(1.4, 2.5, 0) * CFrame.Angles(0, 0, math.rad(28)), bark)
	end
	createBlock(m, cframe, s, "TrunkHub", Vector3.new(2.1, 4.8, 2.1), CFrame.new(0, 4.6, 0), bark)
	createBlock(m, cframe, s, "CanopyWide", Vector3.new(8.6, 2.6, 8.2), CFrame.new(0, 7.6, 0), leafDeep)
	createBlock(m, cframe, s, "CanopyMid", Vector3.new(6.8, 2.2, 6.4), CFrame.new(0.4, 9.6, -0.3), leafTeal)
	createBlock(m, cframe, s, "CanopyCrown", Vector3.new(4.2, 1.4, 4.2), CFrame.new(0, 11.1, 0), moss)
	-- Hanging swamp moss strips
	for idx, hx in ipairs({ -3.4, -1.8, 2.2, 3.6 }) do
		createBlock(m, cframe, s, "HangVine_" .. idx, Vector3.new(0.45, 2.8, 0.45), CFrame.new(hx, 5.2, (idx % 2 == 0) and 2.8 or -2.6), moss)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildDeadSwampWillow(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DeadSwampWillow", cframe, parent)
	local deadBark, vineCol = Color3.fromRGB(72, 64, 58), Color3.fromRGB(74, 146, 84)
	createBlock(m, cframe, s, "GnarledBase", Vector3.new(3.0, 1.1, 3.0), CFrame.new(0, 0.55, 0), deadBark)
	createBlock(m, cframe, s, "GnarledTrunk", Vector3.new(1.8, 6.4, 1.8), CFrame.new(-0.2, 3.5, 0) * CFrame.Angles(0, 0, math.rad(7)), deadBark)
	createBlock(m, cframe, s, "CrookedBoughL", Vector3.new(4.0, 1.0, 1.0), CFrame.new(-2.2, 6.4, 0.4) * CFrame.Angles(0, 0, math.rad(-14)), deadBark)
	createBlock(m, cframe, s, "CrookedBoughR", Vector3.new(3.6, 0.9, 1.0), CFrame.new(1.8, 5.8, -0.4) * CFrame.Angles(0, 0, math.rad(16)), deadBark)
	for idx, vx in ipairs({ -3.7, -2.5, 2.4, 3.2 }) do
		createBlock(m, cframe, s, "WillowMoss_" .. idx, Vector3.new(0.42, 3.2, 0.42), CFrame.new(vx, 4.4, (idx % 2 == 0) and 0.4 or -0.4), vineCol)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildGiantGlowMushroom(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("GiantGlowMushroom", cframe, parent)
	local stemCol, capCol, glowTeal = Color3.fromRGB(196, 214, 198), Color3.fromRGB(48, 128, 108), Color3.fromRGB(88, 248, 198)
	createBlock(m, cframe, s, "StemMain", Vector3.new(1.4, 6.2, 1.4), CFrame.new(0, 3.1, 0), stemCol)
	createBlock(m, cframe, s, "CapMain", Vector3.new(5.6, 1.7, 5.6), CFrame.new(0, 6.8, 0), capCol)
	createBlock(m, cframe, s, "CapDome", Vector3.new(3.6, 1.0, 3.6), CFrame.new(0, 8.0, 0), capCol)
	createBlock(m, cframe, s, "GlowGills", Vector3.new(4.4, 0.4, 4.4), CFrame.new(0, 5.9, 0), glowTeal, Enum.Material.Neon, false)
	for idx, off in ipairs({ Vector3.new(-1.5, 7.6, 1.3), Vector3.new(1.4, 7.6, -1.2), Vector3.new(0.4, 8.5, 0.8) }) do
		createBlock(m, cframe, s, "GlowSpot_" .. idx, Vector3.new(0.75, 0.35, 0.75), CFrame.new(off), glowTeal, Enum.Material.Neon, false)
	end
	createBlock(m, cframe, s, "SideStem", Vector3.new(0.85, 3.4, 0.85), CFrame.new(2.1, 1.7, 1.2), stemCol)
	createBlock(m, cframe, s, "SideCap", Vector3.new(2.8, 1.0, 2.8), CFrame.new(2.1, 3.7, 1.2), glowTeal)
	return m
end

function ClassicStudBiomeBuilder.BuildSwampTotemShrine(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampTotemShrine", cframe, parent)
	local stone, moss, glow = Color3.fromRGB(82, 88, 82), Color3.fromRGB(68, 146, 78), Color3.fromRGB(96, 248, 158)
	createBlock(m, cframe, s, "ShrinePlinth", Vector3.new(9.2, 0.8, 4.2), CFrame.new(0, 0.4, 0), stone)
	createBlock(m, cframe, s, "PillarL", Vector3.new(1.9, 7.2, 1.9), CFrame.new(-3.2, 4.2, 0), stone)
	createBlock(m, cframe, s, "PillarR", Vector3.new(1.9, 7.2, 1.9), CFrame.new(3.2, 4.2, 0), stone)
	createBlock(m, cframe, s, "Lintels", Vector3.new(9.6, 1.6, 2.5), CFrame.new(0, 8.4, 0), stone)
	createBlock(m, cframe, s, "ShrineCrest", Vector3.new(5.2, 1.4, 2.1), CFrame.new(0, 9.8, 0), moss)
	createBlock(m, cframe, s, "MossDrapL", Vector3.new(1.4, 2.2, 2.1), CFrame.new(-3.3, 6.2, 0.1), moss)
	createBlock(m, cframe, s, "ShrineCore", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 11.0, 0), glow, Enum.Material.Neon, false)
	createBlock(m, cframe, s, "OrbL", Vector3.new(0.85, 0.85, 0.85), CFrame.new(-3.2, 5.0, 1.2), glow, Enum.Material.Neon, false)
	createBlock(m, cframe, s, "OrbR", Vector3.new(0.85, 0.85, 0.85), CFrame.new(3.2, 5.0, 1.2), glow, Enum.Material.Neon, false)
	return m
end

function ClassicStudBiomeBuilder.BuildCattailReedCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("CattailReedCluster", cframe, parent)
	createBlock(m, cframe, s, "MudBase", Vector3.new(3.0, 0.25, 3.0), CFrame.new(0, 0.12, 0), Color3.fromRGB(74, 58, 42))
	for idx, r in ipairs({
		{ x = -0.6, z = -0.4, h = 3.8, tilt = 6 },
		{ x = 0.2, z = 0.2, h = 4.5, tilt = -4 },
		{ x = 0.8, z = -0.5, h = 3.4, tilt = 8 },
		{ x = -0.3, z = 0.7, h = 4.1, tilt = -7 },
	}) do
		local cf = CFrame.new(r.x, r.h * 0.5, r.z) * CFrame.Angles(math.rad(r.tilt), 0, 0)
		createBlock(m, cframe, s, "ReedStalk_" .. idx, Vector3.new(0.22, r.h, 0.22), cf, Color3.fromRGB(68, 138, 66))
		createBlock(m, cframe, s, "CattailHead_" .. idx, Vector3.new(0.42, 1.1, 0.42), cf * CFrame.new(0, r.h * 0.3, 0), Color3.fromRGB(98, 58, 36))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSwampLilyPadCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampLilyPadCluster", cframe, parent)
	createBlock(m, cframe, s, "LagoonRing", Vector3.new(5.4, 0.14, 4.8), CFrame.new(0, 0.07, 0), Color3.fromRGB(44, 134, 114), nil, true, 0.25)
	for idx, p in ipairs({
		{ x = -1.1, z = -0.6, w = 2.0, flower = true },
		{ x = 1.2, z = 0.4, w = 1.7, flower = false },
		{ x = 0.2, z = -1.3, w = 1.5, flower = true },
	}) do
		createBlock(m, cframe, s, "LilyPad_" .. idx, Vector3.new(p.w, 0.18, p.w * 0.9), CFrame.new(p.x, 0.2, p.z) * CFrame.Angles(0, idx * 0.7, 0), Color3.fromRGB(72, 174, 78))
		if p.flower then
			createBlock(m, cframe, s, "Lotus_" .. idx, Vector3.new(0.75, 0.45, 0.75), CFrame.new(p.x, 0.48, p.z), Color3.fromRGB(255, 146, 188))
			createBlock(m, cframe, s, "LotusCore_" .. idx, Vector3.new(0.35, 0.55, 0.35), CFrame.new(p.x, 0.54, p.z), Color3.fromRGB(255, 224, 96))
		end
	end
	return m
end

function ClassicStudBiomeBuilder.BuildMudMossTurfPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MudMossTurfPatch", cframe, parent)
	createBlock(m, cframe, s, "MudBase", Vector3.new(6.8, 0.28, 6.0), CFrame.new(0, 0.14, 0), Color3.fromRGB(82, 66, 46))
	createBlock(m, cframe, s, "WetMudPool", Vector3.new(4.2, 0.34, 3.6), CFrame.new(0.4, 0.22, -0.3), Color3.fromRGB(58, 46, 32))
	createBlock(m, cframe, s, "SwampMossL", Vector3.new(2.8, 0.32, 2.4), CFrame.new(-1.5, 0.36, 1.0), Color3.fromRGB(68, 138, 86))
	createBlock(m, cframe, s, "MossStone", Vector3.new(1.1, 0.55, 1.0), CFrame.new(-1.6, 0.65, 1.1), Color3.fromRGB(98, 106, 98))
	return m
end

function ClassicStudBiomeBuilder.BuildSwampVineFern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampVineFern", cframe, parent)
	createBlock(m, cframe, s, "BogRoot", Vector3.new(1.4, 0.8, 1.4), CFrame.new(0, 0.4, 0), Color3.fromRGB(56, 86, 54))
	for idx = 0, 5 do
		local yaw = math.rad(idx * 60 + 15)
		createBlock(m, cframe, s, "SwampFrond_" .. idx, Vector3.new(0.75, 0.26, 2.2), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.8, 1.4) * CFrame.Angles(math.rad(16), 0, 0), Color3.fromRGB(58, 148, 98))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildGlowSporeTrio(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("GlowSporeTrio", cframe, parent)
	createBlock(m, cframe, s, "SporeTurf", Vector3.new(2.8, 0.22, 2.8), CFrame.new(0, 0.11, 0), Color3.fromRGB(64, 54, 42))
	for idx, sp in ipairs({ { x = 0, z = 0, h = 1.4, w = 1.3 }, { x = -0.8, z = 0.6, h = 0.9, w = 0.9 }, { x = 0.85, z = -0.45, h = 1.1, w = 1.0 } }) do
		createBlock(m, cframe, s, "Stem_" .. idx, Vector3.new(0.38, sp.h, 0.38), CFrame.new(sp.x, sp.h * 0.5, sp.z), Color3.fromRGB(194, 212, 198))
		createBlock(m, cframe, s, "Cap_" .. idx, Vector3.new(sp.w, 0.45, sp.w), CFrame.new(sp.x, sp.h + 0.22, sp.z), Color3.fromRGB(72, 238, 186), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSunkenHollowLog(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SunkenHollowLog", cframe, parent)
	createBlock(m, cframe, s, "MudPuddle", Vector3.new(6.8, 0.16, 3.2), CFrame.new(0, 0.08, 0), Color3.fromRGB(58, 48, 34))
	createBlock(m, cframe, s, "SunkLog", Vector3.new(6.2, 1.5, 1.8), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(-5)), Color3.fromRGB(78, 56, 38))
	createBlock(m, cframe, s, "LogMoss", Vector3.new(3.4, 0.32, 1.4), CFrame.new(-0.6, 1.45, 0), Color3.fromRGB(68, 148, 86))
	createBlock(m, cframe, s, "GlowFungus", Vector3.new(0.65, 0.22, 0.65), CFrame.new(1.2, 1.0, 1.0), Color3.fromRGB(88, 248, 198), Enum.Material.Neon, false)
	return m
end

function ClassicStudBiomeBuilder.BuildMossySwampBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MossySwampBoulder", cframe, parent)
	createBlock(m, cframe, s, "WetRockA", Vector3.new(4.8, 2.1, 4.2), CFrame.new(0, 1.05, 0), Color3.fromRGB(76, 80, 76))
	createBlock(m, cframe, s, "WetRockB", Vector3.new(3.2, 1.4, 3.0), CFrame.new(-0.4, 2.5, 0.2), Color3.fromRGB(92, 96, 92))
	createBlock(m, cframe, s, "SwampMossCap", Vector3.new(3.4, 0.45, 3.2), CFrame.new(-0.4, 3.3, 0.2), Color3.fromRGB(62, 142, 82))
	createBlock(m, cframe, s, "DrapingMoss", Vector3.new(0.6, 1.8, 1.4), CFrame.new(1.4, 2.0, 0.4), Color3.fromRGB(62, 142, 82))
	return m
end

function ClassicStudBiomeBuilder.BuildWoodenSwampDock(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("WoodenSwampDock", cframe, parent)
	local woodDark, woodPlank = Color3.fromRGB(86, 56, 36), Color3.fromRGB(122, 84, 52)
	for _, px in ipairs({ -2.4, 2.4 }) do
		for _, pz in ipairs({ -2.6, 2.6 }) do
			createBlock(m, cframe, s, "Piling", Vector3.new(0.9, 2.4, 0.9), CFrame.new(px, 1.2, pz), woodDark)
		end
	end
	for i = 0, 5 do
		createBlock(m, cframe, s, "Plank_" .. i, Vector3.new(5.6, 0.32, 0.95), CFrame.new(0, 1.55, -2.6 + i * 1.05), if i % 2 == 0 then woodPlank else woodDark)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSwampLanternTotem(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampLanternTotem", cframe, parent)
	createBlock(m, cframe, s, "TotemBase", Vector3.new(1.6, 0.6, 1.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(76, 80, 76))
	createBlock(m, cframe, s, "TotemPole", Vector3.new(0.95, 5.4, 0.95), CFrame.new(0, 3.0, 0), Color3.fromRGB(88, 60, 40))
	createBlock(m, cframe, s, "TotemArm", Vector3.new(1.9, 0.48, 0.55), CFrame.new(0.75, 5.2, 0), Color3.fromRGB(88, 60, 40))
	createBlock(m, cframe, s, "SwampFlame", Vector3.new(0.85, 0.95, 0.85), CFrame.new(1.4, 4.2, 0), Color3.fromRGB(96, 248, 178), Enum.Material.Neon, false)
	return m
end

-- ============================================================================
-- BIOME 3: SAVANNA & DESERT POACHER CAMP (13 ASSETS — INCLUDES STEP PYRAMID!)
-- ============================================================================

function ClassicStudBiomeBuilder.BuildDesertStepPyramid(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertStepPyramid", cframe, parent)
	local sandA, sandB = Color3.fromRGB(224, 186, 108), Color3.fromRGB(204, 162, 88)
	local goldTrim, darkEntry = Color3.fromRGB(246, 198, 62), Color3.fromRGB(36, 26, 22)

	-- 6 Classic Stud sandstone tiers
	for tier = 0, 5 do
		local w = 24.0 - tier * 3.6
		local h = 2.4
		local y = tier * h + h * 0.5
		createBlock(m, cframe, s, "PyramidTier_" .. tier, Vector3.new(w, h, w), CFrame.new(0, y, 0), if tier % 2 == 0 then sandA else sandB)
		-- Front central grand staircase step protruding (+Z face)
		if tier < 4 then
			createBlock(m, cframe, s, "StairStep_" .. tier, Vector3.new(5.6, h, 1.4), CFrame.new(0, y, w * 0.5 + 0.65), sandA)
		end
	end
	-- Temple doorway portal at base front + golden capstone
	createBlock(m, cframe, s, "TemplePortalFrame", Vector3.new(5.8, 5.2, 1.2), CFrame.new(0, 2.6, 12.1), goldTrim)
	createBlock(m, cframe, s, "TempleDoorVoid", Vector3.new(3.6, 3.8, 1.4), CFrame.new(0, 1.9, 12.25), darkEntry, Enum.Material.SmoothPlastic, false)
	createBlock(m, cframe, s, "PyramidGoldCapstone", Vector3.new(3.6, 2.2, 3.6), CFrame.new(0, 15.5, 0), goldTrim)
	createBlock(m, cframe, s, "CapstoneBeacon", Vector3.new(1.8, 1.4, 1.8), CFrame.new(0, 17.3, 0), Color3.fromRGB(255, 224, 108), Enum.Material.Neon, false)
	-- Twin entrance obelisks
	for _, ox in ipairs({ -5.2, 5.2 }) do
		createBlock(m, cframe, s, "Obelisk_" .. ox, Vector3.new(1.5, 5.8, 1.5), CFrame.new(ox, 2.9, 13.4), sandB)
		createBlock(m, cframe, s, "ObeliskTip_" .. ox, Vector3.new(1.1, 1.1, 1.1), CFrame.new(ox, 6.3, 13.4), Color3.fromRGB(255, 168, 58), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildAcaciaTreeFlat(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("AcaciaTreeFlat", cframe, parent)
	local bark, leafA, leafB = Color3.fromRGB(122, 82, 52), Color3.fromRGB(116, 152, 52), Color3.fromRGB(148, 178, 62)
	createBlock(m, cframe, s, "AcaciaTrunk", Vector3.new(1.6, 6.2, 1.6), CFrame.new(-0.4, 3.1, 0) * CFrame.Angles(0, 0, math.rad(10)), bark)
	createBlock(m, cframe, s, "AcaciaFork", Vector3.new(4.2, 0.9, 1.1), CFrame.new(1.2, 6.2, 0) * CFrame.Angles(0, 0, math.rad(22)), bark)
	-- Characteristic wide flat savanna umbrella crowns
	createBlock(m, cframe, s, "CanopyMain", Vector3.new(11.4, 1.4, 9.2), CFrame.new(0.8, 7.6, 0), leafA)
	createBlock(m, cframe, s, "CanopyHighlight", Vector3.new(8.8, 1.0, 6.8), CFrame.new(1.0, 8.7, 0), leafB)
	createBlock(m, cframe, s, "CanopySub", Vector3.new(5.6, 1.1, 5.2), CFrame.new(-3.2, 6.4, 1.2), leafA)
	return m
end

function ClassicStudBiomeBuilder.BuildDesertPalmTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertPalmTree", cframe, parent)
	local barkA, barkB = Color3.fromRGB(132, 92, 56), Color3.fromRGB(108, 74, 44)
	for i = 0, 5 do
		local t = i / 5
		createBlock(m, cframe, s, "PalmSeg_" .. i, Vector3.new(1.3 - i * 0.06, 1.7, 1.3 - i * 0.06), CFrame.new(t * 1.4, i * 1.45 + 0.85, 0) * CFrame.Angles(0, 0, math.rad(-i * 3.5)), if i % 2 == 0 then barkA else barkB)
	end
	local crownPos = Vector3.new(1.5, 8.6, 0)
	for _, cx in ipairs({ -0.6, 0.6 }) do
		createBlock(m, cframe, s, "Coconut", Vector3.new(0.75, 0.75, 0.75), CFrame.new(crownPos + Vector3.new(cx, -0.5, 0.5)), Color3.fromRGB(88, 52, 28))
	end
	for idx = 0, 5 do
		local yaw = math.rad(idx * 60)
		local fCF = CFrame.new(crownPos) * CFrame.Angles(0, yaw, 0)
		createBlock(m, cframe, s, "FrondInner_" .. idx, Vector3.new(1.3, 0.35, 3.4), fCF * CFrame.new(0, 0.3, 1.7) * CFrame.Angles(math.rad(-10), 0, 0), Color3.fromRGB(88, 168, 58))
		createBlock(m, cframe, s, "FrondTip_" .. idx, Vector3.new(1.0, 0.3, 2.2), fCF * CFrame.new(0, -0.35, 4.1) * CFrame.Angles(math.rad(-32), 0, 0), Color3.fromRGB(116, 194, 68))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSaguaroCactusGiant(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SaguaroCactusGiant", cframe, parent)
	local col, colLight = Color3.fromRGB(68, 178, 74), Color3.fromRGB(92, 206, 86)
	createBlock(m, cframe, s, "CactusStem", Vector3.new(1.9, 7.6, 1.9), CFrame.new(0, 3.8, 0), col)
	createBlock(m, cframe, s, "ArmLHoriz", Vector3.new(2.2, 1.4, 1.4), CFrame.new(-1.8, 4.0, 0), colLight)
	createBlock(m, cframe, s, "ArmLVert", Vector3.new(1.4, 2.8, 1.4), CFrame.new(-2.4, 5.4, 0), col)
	createBlock(m, cframe, s, "ArmRHoriz", Vector3.new(2.0, 1.3, 1.3), CFrame.new(1.6, 3.2, 0), colLight)
	createBlock(m, cframe, s, "ArmRVert", Vector3.new(1.3, 2.4, 1.3), CFrame.new(2.1, 4.4, 0), col)
	createBlock(m, cframe, s, "CactusBloom", Vector3.new(0.85, 0.6, 0.85), CFrame.new(0, 7.85, 0), Color3.fromRGB(255, 86, 108))
	return m
end

function ClassicStudBiomeBuilder.BuildBarrelCactusCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("BarrelCactusCluster", cframe, parent)
	createBlock(m, cframe, s, "SandBase", Vector3.new(3.4, 0.22, 3.4), CFrame.new(0, 0.11, 0), Color3.fromRGB(224, 186, 104))
	for idx, c in ipairs({ { x = -0.6, z = 0, sz = 1.6, h = 1.7 }, { x = 1.0, z = -0.6, sz = 1.2, h = 1.2 }, { x = 0.7, z = 0.9, sz = 1.0, h = 1.0 } }) do
		createBlock(m, cframe, s, "Barrel_" .. idx, Vector3.new(c.sz, c.h, c.sz), CFrame.new(c.x, c.h * 0.5 + 0.18, c.z), Color3.fromRGB(78, 174, 76))
		createBlock(m, cframe, s, "Flower_" .. idx, Vector3.new(0.45, 0.3, 0.45), CFrame.new(c.x, c.h + 0.32, c.z), Color3.fromRGB(255, 208, 62))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSavannaGrassTuft(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SavannaGrassTuft", cframe, parent)
	addGrassBladesHelper(m, cframe, s, Color3.fromRGB(198, 162, 76), Color3.fromRGB(186, 148, 56), Color3.fromRGB(222, 184, 72), Color3.fromRGB(246, 212, 94))
	return m
end

function ClassicStudBiomeBuilder.BuildSandDuneTurfPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SandDuneTurfPatch", cframe, parent)
	createBlock(m, cframe, s, "DuneLow", Vector3.new(6.8, 0.3, 6.2), CFrame.new(0, 0.15, 0), Color3.fromRGB(224, 184, 98))
	createBlock(m, cframe, s, "DuneMid", Vector3.new(4.8, 0.4, 4.4), CFrame.new(0.6, 0.45, -0.3), Color3.fromRGB(238, 198, 112))
	createBlock(m, cframe, s, "DuneTop", Vector3.new(2.6, 0.4, 2.4), CFrame.new(1.0, 0.78, -0.5), Color3.fromRGB(246, 212, 132))
	createBlock(m, cframe, s, "RedSandStone", Vector3.new(1.3, 0.6, 1.1), CFrame.new(-1.8, 0.48, 1.2), Color3.fromRGB(186, 114, 68))
	return m
end

function ClassicStudBiomeBuilder.BuildDesertScrubBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertScrubBush", cframe, parent)
	local dryBark, dryOlive = Color3.fromRGB(134, 108, 66), Color3.fromRGB(158, 148, 72)
	createBlock(m, cframe, s, "ScrubCore", Vector3.new(2.6, 1.6, 2.6), CFrame.new(0, 0.85, 0), dryBark)
	createBlock(m, cframe, s, "ScrubCrown", Vector3.new(3.2, 1.0, 2.0), CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(25), 0), dryOlive)
	createBlock(m, cframe, s, "ScrubCross", Vector3.new(2.0, 1.0, 3.2), CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.rad(-15), 0), dryOlive)
	return m
end

function ClassicStudBiomeBuilder.BuildSandstoneRuinedPillar(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SandstoneRuinedPillar", cframe, parent)
	local stone, gold = Color3.fromRGB(214, 174, 102), Color3.fromRGB(244, 196, 64)
	createBlock(m, cframe, s, "Plinth", Vector3.new(3.2, 0.8, 3.2), CFrame.new(0, 0.4, 0), stone)
	createBlock(m, cframe, s, "Shaft", Vector3.new(2.0, 5.2, 2.0), CFrame.new(0, 3.4, 0), stone)
	createBlock(m, cframe, s, "GoldBand", Vector3.new(2.2, 0.5, 2.2), CFrame.new(0, 4.4, 0), gold)
	createBlock(m, cframe, s, "FallenCap", Vector3.new(2.4, 1.1, 2.4), CFrame.new(2.4, 0.55, 1.4) * CFrame.Angles(0, math.rad(24), math.rad(12)), stone)
	return m
end

function ClassicStudBiomeBuilder.BuildSandstoneMesaArch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SandstoneMesaArch", cframe, parent)
	local terra, sand = Color3.fromRGB(186, 108, 62), Color3.fromRGB(212, 148, 86)
	createBlock(m, cframe, s, "LegL", Vector3.new(2.6, 6.2, 2.8), CFrame.new(-3.2, 3.1, 0), terra)
	createBlock(m, cframe, s, "LegR", Vector3.new(2.6, 6.2, 2.8), CFrame.new(3.2, 3.1, 0), sand)
	createBlock(m, cframe, s, "ArchSpan", Vector3.new(9.6, 2.2, 3.0), CFrame.new(0, 7.2, 0), sand)
	createBlock(m, cframe, s, "ArchCap", Vector3.new(6.8, 1.4, 2.6), CFrame.new(-0.3, 8.9, 0), terra)
	return m
end

function ClassicStudBiomeBuilder.BuildOasisWaterPool(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("OasisWaterPool", cframe, parent)
	createBlock(m, cframe, s, "SandBank", Vector3.new(7.4, 0.28, 6.2), CFrame.new(0, 0.14, 0), Color3.fromRGB(234, 198, 114))
	createBlock(m, cframe, s, "OasisWater", Vector3.new(5.4, 0.36, 4.4), CFrame.new(0, 0.22, 0), Color3.fromRGB(48, 198, 224), nil, true, 0.2)
	createBlock(m, cframe, s, "OasisReeds", Vector3.new(0.45, 2.2, 0.45), CFrame.new(-2.4, 1.1, 1.6), Color3.fromRGB(82, 168, 62))
	createBlock(m, cframe, s, "OasisStone", Vector3.new(1.2, 0.8, 1.1), CFrame.new(2.5, 0.5, -1.6), Color3.fromRGB(186, 134, 82))
	return m
end

function ClassicStudBiomeBuilder.BuildDesertSkullBone(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertSkullBone", cframe, parent)
	local bone = Color3.fromRGB(238, 232, 214)
	createBlock(m, cframe, s, "SkullCranium", Vector3.new(2.2, 1.5, 2.4), CFrame.new(0, 0.85, 0), bone)
	createBlock(m, cframe, s, "SkullSnout", Vector3.new(1.3, 0.9, 1.4), CFrame.new(0, 0.5, 1.7), bone)
	createBlock(m, cframe, s, "HornL", Vector3.new(2.0, 0.55, 0.55), CFrame.new(-1.8, 1.3, -0.4) * CFrame.Angles(0, 0, math.rad(-22)), bone)
	createBlock(m, cframe, s, "HornR", Vector3.new(2.0, 0.55, 0.55), CFrame.new(1.8, 1.3, -0.4) * CFrame.Angles(0, 0, math.rad(22)), bone)
	createBlock(m, cframe, s, "RibArch", Vector3.new(2.6, 0.45, 0.55), CFrame.new(0, 0.55, -2.1), bone)
	return m
end

function ClassicStudBiomeBuilder.BuildDesertBrazierTorch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertBrazierTorch", cframe, parent)
	createBlock(m, cframe, s, "BrazierBase", Vector3.new(2.2, 0.7, 2.2), CFrame.new(0, 0.35, 0), Color3.fromRGB(204, 162, 88))
	createBlock(m, cframe, s, "BrazierPillar", Vector3.new(1.3, 3.2, 1.3), CFrame.new(0, 2.2, 0), Color3.fromRGB(224, 186, 108))
	createBlock(m, cframe, s, "BrazierBowl", Vector3.new(2.0, 0.65, 2.0), CFrame.new(0, 4.0, 0), Color3.fromRGB(246, 198, 62))
	createBlock(m, cframe, s, "BrazierFlame", Vector3.new(1.1, 1.2, 1.1), CFrame.new(0, 4.9, 0), Color3.fromRGB(255, 138, 36), Enum.Material.Neon, false)
	return m
end

-- ============================================================================
-- BIOME 4: FROSTBITE ALPINE PEAKS (13 ASSETS)
-- ============================================================================

function ClassicStudBiomeBuilder.BuildGiantIceCrystalSpire(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("GiantIceCrystalSpire", cframe, parent)
	local snow, iceLight, iceCyan, iceGlow = Color3.fromRGB(240, 248, 255), Color3.fromRGB(186, 232, 255), Color3.fromRGB(92, 206, 255), Color3.fromRGB(132, 242, 255)

	createBlock(m, cframe, s, "GlacierBaseSnow", Vector3.new(8.8, 1.4, 8.8), CFrame.new(0, 0.7, 0), snow)
	for tier = 0, 3 do
		local w = 4.6 - tier * 0.9
		local h = 3.2
		createBlock(m, cframe, s, "CoreCrystal_" .. tier, Vector3.new(w, h, w), CFrame.new(0, 1.4 + tier * h + h * 0.5, 0) * CFrame.Angles(0, math.rad(tier * 18), 0), if tier % 2 == 0 then iceCyan else iceLight, nil, true, 0.15)
	end
	createBlock(m, cframe, s, "SpireBeacon", Vector3.new(1.2, 1.8, 1.2), CFrame.new(0, 14.8, 0), iceGlow, Enum.Material.Neon, false)
	for idx = 0, 3 do
		local yaw = math.rad(idx * 90 + 25)
		createBlock(m, cframe, s, "SideShard_" .. idx, Vector3.new(1.9, 6.2, 1.9), CFrame.Angles(0, yaw, 0) * CFrame.new(2.8, 3.4, 0) * CFrame.Angles(0, 0, math.rad(-18)), iceCyan, nil, true, 0.18)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSnowyPineTreeTall(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SnowyPineTreeTall", cframe, parent)
	local bark, pine, snow = Color3.fromRGB(84, 58, 42), Color3.fromRGB(46, 118, 72), Color3.fromRGB(242, 248, 255)
	createBlock(m, cframe, s, "Trunk", Vector3.new(1.6, 11.2, 1.6), CFrame.new(0, 5.6, 0), bark)
	for idx, t in ipairs({ { y = 5.0, w = 8.2 }, { y = 7.4, w = 6.6 }, { y = 9.7, w = 5.0 }, { y = 11.8, w = 3.4 }, { y = 13.6, w = 2.0 } }) do
		createBlock(m, cframe, s, "PineLayer_" .. idx, Vector3.new(t.w, 1.6, t.w), CFrame.new(0, t.y, 0), pine)
		createBlock(m, cframe, s, "SnowCap_" .. idx, Vector3.new(t.w - 0.5, 0.7, t.w - 0.5), CFrame.new(0, t.y + 1.1, 0), snow)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSnowyPineTreeTwin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SnowyPineTreeTwin", cframe, parent)
	local bark, pine, snow = Color3.fromRGB(80, 56, 42), Color3.fromRGB(52, 128, 78), Color3.fromRGB(242, 248, 255)
	createBlock(m, cframe, s, "MainTrunk", Vector3.new(1.4, 7.6, 1.4), CFrame.new(-0.9, 3.8, 0), bark)
	for idx, t in ipairs({ { y = 4.6, w = 6.2 }, { y = 6.7, w = 4.6 }, { y = 8.6, w = 3.0 } }) do
		createBlock(m, cframe, s, "MainGreen_" .. idx, Vector3.new(t.w, 1.4, t.w), CFrame.new(-0.9, t.y, 0), pine)
		createBlock(m, cframe, s, "MainSnow_" .. idx, Vector3.new(t.w - 0.5, 0.6, t.w - 0.5), CFrame.new(-0.9, t.y + 0.95, 0), snow)
	end
	createBlock(m, cframe, s, "SideTrunk", Vector3.new(1.1, 5.2, 1.1), CFrame.new(2.1, 2.6, 0.9), bark)
	for idx, t in ipairs({ { y = 3.5, w = 4.4 }, { y = 5.3, w = 3.0 } }) do
		createBlock(m, cframe, s, "SideGreen_" .. idx, Vector3.new(t.w, 1.2, t.w), CFrame.new(2.1, t.y, 0.9), pine)
		createBlock(m, cframe, s, "SideSnow_" .. idx, Vector3.new(t.w - 0.4, 0.55, t.w - 0.4), CFrame.new(2.1, t.y + 0.85, 0.9), snow)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildFrostedBirchTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FrostedBirchTree", cframe, parent)
	local bark, frostCyan, snow = Color3.fromRGB(218, 224, 232), Color3.fromRGB(136, 212, 246), Color3.fromRGB(244, 250, 255)
	createBlock(m, cframe, s, "Trunk", Vector3.new(1.3, 6.8, 1.3), CFrame.new(0, 3.4, 0), bark)
	createBlock(m, cframe, s, "StripeA", Vector3.new(1.36, 0.4, 1.36), CFrame.new(0, 2.2, 0), Color3.fromRGB(92, 102, 118))
	createBlock(m, cframe, s, "StripeB", Vector3.new(1.36, 0.4, 1.36), CFrame.new(0, 4.4, 0), Color3.fromRGB(92, 102, 118))
	createBlock(m, cframe, s, "FrostLeaves", Vector3.new(6.4, 2.6, 6.4), CFrame.new(0, 7.6, 0), frostCyan)
	createBlock(m, cframe, s, "FrostCap", Vector3.new(5.2, 1.4, 5.2), CFrame.new(0, 9.4, 0), snow)
	return m
end

function ClassicStudBiomeBuilder.BuildSnowDriftTurfPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SnowDriftTurfPatch", cframe, parent)
	createBlock(m, cframe, s, "SnowBase", Vector3.new(6.8, 0.34, 6.2), CFrame.new(0, 0.17, 0), Color3.fromRGB(236, 246, 255))
	createBlock(m, cframe, s, "IcePatch", Vector3.new(4.2, 0.4, 3.6), CFrame.new(0.7, 0.24, -0.3), Color3.fromRGB(142, 222, 255), nil, true, 0.15)
	createBlock(m, cframe, s, "DriftMound", Vector3.new(3.0, 0.65, 2.8), CFrame.new(-1.3, 0.5, 0.8), Color3.fromRGB(246, 252, 255))
	return m
end

function ClassicStudBiomeBuilder.BuildFrostGrassTuft(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FrostGrassTuft", cframe, parent)
	addGrassBladesHelper(m, cframe, s, Color3.fromRGB(224, 242, 255), Color3.fromRGB(122, 204, 242), Color3.fromRGB(168, 228, 255), Color3.fromRGB(244, 250, 255))
	return m
end

function ClassicStudBiomeBuilder.BuildIceBerryBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("IceBerryBush", cframe, parent)
	createBlock(m, cframe, s, "BushBody", Vector3.new(3.6, 2.1, 3.6), CFrame.new(0, 1.05, 0), Color3.fromRGB(58, 128, 108))
	createBlock(m, cframe, s, "SnowHood", Vector3.new(3.1, 0.9, 3.1), CFrame.new(0, 2.2, 0), Color3.fromRGB(242, 248, 255))
	for idx, off in ipairs({ Vector3.new(-1.85, 1.2, 0.5), Vector3.new(0.8, 1.5, 1.85), Vector3.new(1.85, 1.1, -0.7), Vector3.new(-0.4, 1.4, -1.85) }) do
		createBlock(m, cframe, s, "IceBerry_" .. idx, Vector3.new(0.45, 0.45, 0.45), CFrame.new(off), Color3.fromRGB(98, 236, 255), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildCrystalFrostFlower(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("CrystalFrostFlower", cframe, parent)
	createBlock(m, cframe, s, "SnowTurf", Vector3.new(3.4, 0.2, 3.4), CFrame.new(0, 0.1, 0), Color3.fromRGB(232, 246, 255))
	for idx, fl in ipairs({ { x = -0.7, z = -0.5, h = 1.2 }, { x = 0.7, z = 0.4, h = 1.45 }, { x = 0.1, z = -0.8, h = 1.0 } }) do
		createBlock(m, cframe, s, "Stem_" .. idx, Vector3.new(0.24, fl.h, 0.24), CFrame.new(fl.x, fl.h * 0.5 + 0.15, fl.z), Color3.fromRGB(118, 198, 224))
		createBlock(m, cframe, s, "IceBloom_" .. idx, Vector3.new(0.85, 0.35, 0.85), CFrame.new(fl.x, fl.h + 0.25, fl.z), Color3.fromRGB(118, 236, 255), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildGlacierBoulderSnowy(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("GlacierBoulderSnowy", cframe, parent)
	createBlock(m, cframe, s, "AlpineRock", Vector3.new(5.0, 2.4, 4.4), CFrame.new(0, 1.2, 0), Color3.fromRGB(112, 128, 148))
	createBlock(m, cframe, s, "RockPeak", Vector3.new(3.4, 1.5, 3.2), CFrame.new(-0.3, 2.9, 0.2), Color3.fromRGB(132, 150, 172))
	createBlock(m, cframe, s, "SnowDriftCap", Vector3.new(3.6, 0.6, 3.4), CFrame.new(-0.3, 3.85, 0.2), Color3.fromRGB(242, 248, 255))
	createBlock(m, cframe, s, "IcicleLedge", Vector3.new(0.45, 1.1, 0.45), CFrame.new(1.6, 2.1, 1.4), Color3.fromRGB(152, 232, 255))
	return m
end

function ClassicStudBiomeBuilder.BuildIceCrystalCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("IceCrystalCluster", cframe, parent)
	createBlock(m, cframe, s, "IceShardMain", Vector3.new(1.3, 4.2, 1.3), CFrame.new(0, 2.0, 0) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(112, 224, 255), nil, true, 0.16)
	createBlock(m, cframe, s, "IceShardL", Vector3.new(1.0, 2.8, 1.0), CFrame.new(-1.1, 1.3, 0.3) * CFrame.Angles(0, 0, math.rad(24)), Color3.fromRGB(168, 238, 255), nil, true, 0.16)
	createBlock(m, cframe, s, "IceShardR", Vector3.new(0.95, 2.4, 0.95), CFrame.new(1.0, 1.1, -0.3) * CFrame.Angles(math.rad(-14), 0, math.rad(-22)), Color3.fromRGB(84, 208, 255), nil, true, 0.16)
	return m
end

function ClassicStudBiomeBuilder.BuildFrozenHollowLog(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FrozenHollowLog", cframe, parent)
	createBlock(m, cframe, s, "LogBody", Vector3.new(6.4, 1.8, 1.9), CFrame.new(0, 0.9, 0), Color3.fromRGB(88, 68, 56))
	createBlock(m, cframe, s, "LogSnowTop", Vector3.new(5.6, 0.45, 1.6), CFrame.new(0, 1.95, 0), Color3.fromRGB(242, 248, 255))
	createBlock(m, cframe, s, "IcicleA", Vector3.new(0.32, 0.9, 0.32), CFrame.new(-1.2, 1.3, 1.0), Color3.fromRGB(142, 228, 255))
	createBlock(m, cframe, s, "IcicleB", Vector3.new(0.28, 0.75, 0.28), CFrame.new(0.8, 1.35, 1.0), Color3.fromRGB(142, 228, 255))
	return m
end

function ClassicStudBiomeBuilder.BuildAlpineStoneCairn(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("AlpineStoneCairn", cframe, parent)
	for idx, st in ipairs({ { y = 0.45, w = 2.6, h = 0.9 }, { y = 1.25, w = 2.0, h = 0.75 }, { y = 1.9, w = 1.4, h = 0.6 }, { y = 2.45, w = 0.9, h = 0.5 } }) do
		createBlock(m, cframe, s, "CairnStone_" .. idx, Vector3.new(st.w, st.h, st.w), CFrame.new(0, st.y, 0) * CFrame.Angles(0, idx * 0.4, 0), Color3.fromRGB(122 + idx * 12, 134 + idx * 10, 150 + idx * 8))
	end
	createBlock(m, cframe, s, "FrostBeacon", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 3.05, 0), Color3.fromRGB(108, 238, 255), Enum.Material.Neon, false)
	return m
end

function ClassicStudBiomeBuilder.BuildFrozenIceArchway(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FrozenIceArchway", cframe, parent)
	createBlock(m, cframe, s, "IcePillarL", Vector3.new(2.2, 6.4, 2.2), CFrame.new(-3.2, 3.2, 0), Color3.fromRGB(118, 208, 246), nil, true, 0.14)
	createBlock(m, cframe, s, "IcePillarR", Vector3.new(2.2, 6.4, 2.2), CFrame.new(3.2, 3.2, 0), Color3.fromRGB(118, 208, 246), nil, true, 0.14)
	createBlock(m, cframe, s, "IceArchSpan", Vector3.new(9.2, 2.0, 2.4), CFrame.new(0, 7.2, 0), Color3.fromRGB(168, 234, 255), nil, true, 0.12)
	createBlock(m, cframe, s, "IceArchSnow", Vector3.new(8.4, 0.85, 2.6), CFrame.new(0, 8.6, 0), Color3.fromRGB(242, 248, 255))
	return m
end

-- ============================================================================
-- BIOME 5: VOLCANIC OBSIDIAN JUNGLE (13 ASSETS)
-- ============================================================================

function ClassicStudBiomeBuilder.BuildVolcanoCraterLandmark(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VolcanoCraterLandmark", cframe, parent)
	local basalt, charDark, lavaNeon = Color3.fromRGB(48, 38, 54), Color3.fromRGB(32, 26, 38), Color3.fromRGB(255, 92, 24)
	for tier = 0, 4 do
		local w = 22.0 - tier * 3.4
		local h = 3.2
		createBlock(m, cframe, s, "VolcanoTier_" .. tier, Vector3.new(w, h, w), CFrame.new(0, tier * h + h * 0.5, 0), if tier % 2 == 0 then basalt else charDark)
	end
	createBlock(m, cframe, s, "MagmaCraterPool", Vector3.new(6.8, 1.2, 6.8), CFrame.new(0, 15.8, 0), lavaNeon, Enum.Material.Neon, false)
	for idx = 0, 3 do
		local rot = CFrame.Angles(0, math.rad(idx * 90), 0)
		createBlock(m, cframe, s, "LavaFlow_" .. idx, Vector3.new(2.2, 13.8, 1.2), rot * CFrame.new(0, 7.2, 6.4) * CFrame.Angles(math.rad(24), 0, 0), lavaNeon, Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildCharredCrimsonTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("CharredCrimsonTree", cframe, parent)
	createBlock(m, cframe, s, "CharTrunk", Vector3.new(1.9, 6.4, 1.9), CFrame.new(0, 3.2, 0), Color3.fromRGB(34, 28, 36))
	createBlock(m, cframe, s, "CharRoots", Vector3.new(3.2, 0.9, 3.2), CFrame.new(0, 0.45, 0), Color3.fromRGB(46, 36, 48))
	createBlock(m, cframe, s, "CrimsonCanopyLow", Vector3.new(7.6, 2.8, 7.6), CFrame.new(0, 7.2, 0), Color3.fromRGB(162, 34, 28))
	createBlock(m, cframe, s, "CrimsonCanopyTop", Vector3.new(5.4, 2.0, 5.4), CFrame.new(0.2, 9.4, -0.2), Color3.fromRGB(224, 72, 34))
	createBlock(m, cframe, s, "EmberCrown", Vector3.new(2.8, 1.1, 2.8), CFrame.new(0, 10.8, 0), Color3.fromRGB(255, 134, 38), Enum.Material.Neon, false)
	return m
end

function ClassicStudBiomeBuilder.BuildObsidianDeadTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("ObsidianDeadTree", cframe, parent)
	local obs, lava = Color3.fromRGB(32, 26, 38), Color3.fromRGB(255, 102, 28)
	createBlock(m, cframe, s, "ObsTrunk", Vector3.new(1.7, 7.0, 1.7), CFrame.new(0, 3.5, 0), obs)
	createBlock(m, cframe, s, "MagmaVein", Vector3.new(0.5, 5.4, 1.8), CFrame.new(0, 3.2, 0), lava, Enum.Material.Neon, false)
	createBlock(m, cframe, s, "DeadBranchL", Vector3.new(3.4, 0.9, 0.9), CFrame.new(-1.8, 6.2, 0) * CFrame.Angles(0, 0, math.rad(-26)), obs)
	createBlock(m, cframe, s, "DeadBranchR", Vector3.new(3.2, 0.9, 0.9), CFrame.new(1.7, 5.4, 0.2) * CFrame.Angles(0, 0, math.rad(28)), obs)
	return m
end

function ClassicStudBiomeBuilder.BuildMagmaPalmTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MagmaPalmTree", cframe, parent)
	for i = 0, 4 do
		createBlock(m, cframe, s, "AshSeg_" .. i, Vector3.new(1.2, 1.6, 1.2), CFrame.new(i * 0.25, i * 1.45 + 0.8, 0), if i % 2 == 0 then Color3.fromRGB(48, 38, 50) else Color3.fromRGB(64, 48, 60))
	end
	local crown = Vector3.new(1.0, 7.6, 0)
	for idx = 0, 5 do
		local fCF = CFrame.new(crown) * CFrame.Angles(0, math.rad(idx * 60), 0)
		createBlock(m, cframe, s, "FrondBase_" .. idx, Vector3.new(1.2, 0.35, 3.2), fCF * CFrame.new(0, 0.2, 1.6), Color3.fromRGB(168, 42, 32))
		createBlock(m, cframe, s, "FrondEmber_" .. idx, Vector3.new(0.9, 0.3, 1.8), fCF * CFrame.new(0, -0.2, 3.8) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(255, 118, 32), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildAshEmberGrassTuft(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("AshEmberGrassTuft", cframe, parent)
	addGrassBladesHelper(m, cframe, s, Color3.fromRGB(44, 36, 48), Color3.fromRGB(58, 44, 58), Color3.fromRGB(142, 46, 36), Color3.fromRGB(255, 112, 28), Enum.Material.Neon)
	return m
end

function ClassicStudBiomeBuilder.BuildBasaltLavaTurfPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("BasaltLavaTurfPatch", cframe, parent)
	createBlock(m, cframe, s, "LavaCrackPool", Vector3.new(6.4, 0.22, 5.8), CFrame.new(0, 0.11, 0), Color3.fromRGB(255, 94, 24), Enum.Material.Neon, false)
	createBlock(m, cframe, s, "BasaltPlateL", Vector3.new(2.7, 0.42, 5.6), CFrame.new(-1.8, 0.25, 0), Color3.fromRGB(46, 38, 52))
	createBlock(m, cframe, s, "BasaltPlateR", Vector3.new(2.7, 0.42, 5.6), CFrame.new(1.8, 0.25, 0), Color3.fromRGB(58, 46, 62))
	return m
end

function ClassicStudBiomeBuilder.BuildFirebloomFlowerPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FirebloomFlowerPatch", cframe, parent)
	createBlock(m, cframe, s, "AshTurf", Vector3.new(3.6, 0.2, 3.6), CFrame.new(0, 0.1, 0), Color3.fromRGB(52, 42, 54))
	for idx, fl in ipairs({ { x = -0.8, z = -0.5, h = 1.1 }, { x = 0.7, z = 0.5, h = 1.4 }, { x = 0.2, z = -0.9, h = 1.2 } }) do
		createBlock(m, cframe, s, "CharStem_" .. idx, Vector3.new(0.24, fl.h, 0.24), CFrame.new(fl.x, fl.h * 0.5 + 0.15, fl.z), Color3.fromRGB(64, 38, 38))
		createBlock(m, cframe, s, "CrimsonPetal_" .. idx, Vector3.new(0.9, 0.26, 0.9), CFrame.new(fl.x, fl.h + 0.24, fl.z), Color3.fromRGB(204, 38, 38))
		createBlock(m, cframe, s, "FlameCore_" .. idx, Vector3.new(0.42, 0.32, 0.42), CFrame.new(fl.x, fl.h + 0.36, fl.z), Color3.fromRGB(255, 198, 48), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildScorchedThornBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("ScorchedThornBush", cframe, parent)
	createBlock(m, cframe, s, "ThornCore", Vector3.new(3.4, 2.0, 3.4), CFrame.new(0, 1.0, 0), Color3.fromRGB(48, 34, 42))
	createBlock(m, cframe, s, "ThornCrown", Vector3.new(2.4, 1.2, 2.4), CFrame.new(0, 2.2, 0), Color3.fromRGB(98, 34, 32))
	for idx, off in ipairs({ Vector3.new(-1.7, 1.2, 0.4), Vector3.new(0.9, 1.5, 1.7), Vector3.new(1.7, 1.0, -0.6) }) do
		createBlock(m, cframe, s, "EmberBerry_" .. idx, Vector3.new(0.46, 0.46, 0.46), CFrame.new(off), Color3.fromRGB(255, 118, 28), Enum.Material.Neon, false)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildObsidianMonolithRuins(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("ObsidianMonolithRuins", cframe, parent)
	createBlock(m, cframe, s, "MonoPlinth", Vector3.new(4.2, 1.0, 4.2), CFrame.new(0, 0.5, 0), Color3.fromRGB(54, 44, 62))
	createBlock(m, cframe, s, "MonoPillar", Vector3.new(2.2, 7.6, 2.2), CFrame.new(0, 4.8, 0), Color3.fromRGB(28, 22, 36))
	createBlock(m, cframe, s, "RuneBand", Vector3.new(2.36, 0.7, 2.36), CFrame.new(0, 5.2, 0), Color3.fromRGB(255, 92, 24), Enum.Material.Neon, false)
	createBlock(m, cframe, s, "RuneCore", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 9.2, 0), Color3.fromRGB(255, 148, 36), Enum.Material.Neon, false)
	return m
end

function ClassicStudBiomeBuilder.BuildMagmaVentGeyser(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MagmaVentGeyser", cframe, parent)
	createBlock(m, cframe, s, "VentBase", Vector3.new(4.6, 1.1, 4.6), CFrame.new(0, 0.55, 0), Color3.fromRGB(48, 38, 52))
	createBlock(m, cframe, s, "VentRim", Vector3.new(3.0, 0.85, 3.0), CFrame.new(0, 1.45, 0), Color3.fromRGB(64, 48, 64))
	createBlock(m, cframe, s, "VentMagma", Vector3.new(1.9, 0.45, 1.9), CFrame.new(0, 1.8, 0), Color3.fromRGB(255, 98, 24), Enum.Material.Neon, false)
	createBlock(m, cframe, s, "SteamPuffA", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0.2, 3.2, -0.1), Color3.fromRGB(168, 162, 174), nil, true, 0.35)
	createBlock(m, cframe, s, "SteamPuffB", Vector3.new(1.5, 1.5, 1.5), CFrame.new(-0.3, 4.6, 0.2), Color3.fromRGB(186, 180, 192), nil, true, 0.5)
	return m
end

function ClassicStudBiomeBuilder.BuildLavaCrackedBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("LavaCrackedBoulder", cframe, parent)
	createBlock(m, cframe, s, "LavaCoreGlow", Vector3.new(4.0, 2.2, 3.8), CFrame.new(0, 1.2, 0), Color3.fromRGB(255, 96, 24), Enum.Material.Neon, false)
	createBlock(m, cframe, s, "BasaltHalfL", Vector3.new(2.2, 2.5, 4.2), CFrame.new(-1.3, 1.25, 0), Color3.fromRGB(46, 38, 50))
	createBlock(m, cframe, s, "BasaltHalfR", Vector3.new(2.2, 2.4, 4.2), CFrame.new(1.3, 1.2, 0), Color3.fromRGB(58, 46, 62))
	return m
end

function ClassicStudBiomeBuilder.BuildCrimsonCrystalCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("CrimsonCrystalCluster", cframe, parent)
	createBlock(m, cframe, s, "RubyMain", Vector3.new(1.3, 4.0, 1.3), CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(255, 58, 72), Enum.Material.Neon, false)
	createBlock(m, cframe, s, "RubySideL", Vector3.new(0.95, 2.6, 0.95), CFrame.new(-1.0, 1.2, 0.3) * CFrame.Angles(0, 0, math.rad(22)), Color3.fromRGB(218, 42, 64))
	createBlock(m, cframe, s, "RubySideR", Vector3.new(0.9, 2.2, 0.9), CFrame.new(1.0, 1.0, -0.3) * CFrame.Angles(0, 0, math.rad(-24)), Color3.fromRGB(255, 118, 38), Enum.Material.Neon, false)
	return m
end

function ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VolcanicSkullBrazier", cframe, parent)
	createBlock(m, cframe, s, "AltarBase", Vector3.new(2.6, 0.8, 2.6), CFrame.new(0, 0.4, 0), Color3.fromRGB(46, 38, 52))
	createBlock(m, cframe, s, "AltarPillar", Vector3.new(1.5, 2.8, 1.5), CFrame.new(0, 2.2, 0), Color3.fromRGB(34, 28, 40))
	createBlock(m, cframe, s, "SkullBowl", Vector3.new(2.2, 1.1, 2.2), CFrame.new(0, 4.0, 0), Color3.fromRGB(224, 214, 198))
	createBlock(m, cframe, s, "SkullHornL", Vector3.new(1.3, 0.45, 0.45), CFrame.new(-1.4, 4.5, 0) * CFrame.Angles(0, 0, math.rad(-26)), Color3.fromRGB(28, 22, 32))
	createBlock(m, cframe, s, "SkullHornR", Vector3.new(1.3, 0.45, 0.45), CFrame.new(1.4, 4.5, 0) * CFrame.Angles(0, 0, math.rad(26)), Color3.fromRGB(28, 22, 32))
	createBlock(m, cframe, s, "MagmaFire", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 5.1, 0), Color3.fromRGB(255, 102, 24), Enum.Material.Neon, false)
	return m
end

-- ============================================================================
-- FULL REDESIGN VOXEL HERO STRUCTURES, VINE TREES, LANTERNS, SKY ISLANDS & LIGHTING
-- ============================================================================

local function buildGlowingLanternBox(
	m: Model,
	originCF: CFrame,
	s: number,
	prefix: string,
	localCenter: Vector3,
	frameCol: Color3,
	glowCol: Color3,
	lightRange: number?
)
	createBlock(m, originCF, s, prefix .. "_CapTop", Vector3.new(1.3, 0.28, 1.3), CFrame.new(localCenter + Vector3.new(0, 0.65, 0)), frameCol)
	createBlock(m, originCF, s, prefix .. "_CapBot", Vector3.new(1.2, 0.24, 1.2), CFrame.new(localCenter + Vector3.new(0, -0.62, 0)), frameCol)
	local core = createBlock(m, originCF, s, prefix .. "_Core", Vector3.new(0.88, 1.02, 0.88), CFrame.new(localCenter), glowCol, Enum.Material.Neon, false)
	addLanternLight(core, glowCol, lightRange or 18, 1.15)
end

-- BIOME 1 (FOREST): Lush Vine Tree, Watchtower, Stream & Bridge, Fence + Lantern
function ClassicStudBiomeBuilder.BuildLushVoxelTreeWithVines(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("LushVoxelTreeWithVines", cframe, parent)
	local barkDark = Color3.fromRGB(88, 54, 34)
	local barkMid = Color3.fromRGB(112, 70, 44)
	local leafDeep = Color3.fromRGB(44, 122, 46)
	local leafMid = Color3.fromRGB(68, 158, 56)
	local leafBright = Color3.fromRGB(108, 198, 72)

	for i, off in ipairs({ Vector3.new(1.4, 0.6, 0), Vector3.new(-1.4, 0.6, 0), Vector3.new(0, 0.6, 1.4), Vector3.new(0, 0.6, -1.4) }) do
		createBlock(m, cframe, s, "Root_" .. i, Vector3.new(1.6, 1.2, 1.6), CFrame.new(off), barkDark)
	end
	createBlock(m, cframe, s, "TrunkLower", Vector3.new(2.5, 5.2, 2.5), CFrame.new(0, 2.6, 0), barkMid)
	createBlock(m, cframe, s, "TrunkUpper", Vector3.new(2.0, 4.4, 2.0), CFrame.new(0, 7.0, 0), barkDark)
	createBlock(m, cframe, s, "BranchArmL", Vector3.new(2.8, 1.2, 1.3), CFrame.new(-1.8, 7.8, 0.3) * CFrame.Angles(0, 0, math.rad(-18)), barkDark)
	createBlock(m, cframe, s, "BranchArmR", Vector3.new(2.8, 1.2, 1.3), CFrame.new(1.8, 8.2, -0.3) * CFrame.Angles(0, 0, math.rad(18)), barkDark)

	-- 4-tier dappled lush canopy
	createBlock(m, cframe, s, "CanopyT1", Vector3.new(11.4, 2.6, 10.6), CFrame.new(0, 9.6, 0), leafDeep)
	createBlock(m, cframe, s, "CanopyT2", Vector3.new(9.6, 2.4, 9.2), CFrame.new(0.4, 11.8, -0.2), leafMid)
	createBlock(m, cframe, s, "CanopyT3", Vector3.new(7.4, 2.0, 7.2), CFrame.new(-0.3, 13.6, 0.3), leafBright)
	createBlock(m, cframe, s, "CanopyT4", Vector3.new(4.4, 1.5, 4.4), CFrame.new(0, 14.9, 0), leafMid)

	-- 8 Hanging green voxel vine strands
	local vineOffsets = {
		{ x = -5.1, z = -3.2, h = 4.6 }, { x = -4.6, z = 2.8, h = 3.4 },
		{ x = 5.1, z = -2.4, h = 4.8 }, { x = 4.7, z = 3.4, h = 3.2 },
		{ x = -2.2, z = -4.8, h = 3.8 }, { x = 2.5, z = -4.9, h = 4.4 },
		{ x = -2.0, z = 4.9, h = 4.2 }, { x = 2.3, z = 4.6, h = 2.8 },
	}
	for i, v in ipairs(vineOffsets) do
		createBlock(m, cframe, s, "Vine_" .. i, Vector3.new(0.62, v.h, 0.62), CFrame.new(v.x, 8.4 - v.h * 0.5, v.z), if i % 2 == 0 then leafBright else leafMid)
	end
	return m
end

local WATCHTOWER_THEMES = {
	Forest = {
		stone = Color3.fromRGB(134, 138, 142),
		stoneAccent = Color3.fromRGB(108, 114, 118),
		wood = Color3.fromRGB(132, 86, 50),
		woodDark = Color3.fromRGB(96, 62, 36),
		roof = Color3.fromRGB(148, 92, 48),
		lanternCol = Color3.fromRGB(255, 198, 76),
		hasMoss = false,
	},
	Swamp = {
		stone = Color3.fromRGB(106, 114, 102),
		stoneAccent = Color3.fromRGB(78, 128, 68),
		wood = Color3.fromRGB(108, 74, 46),
		woodDark = Color3.fromRGB(76, 52, 32),
		roof = Color3.fromRGB(82, 134, 58),
		lanternCol = Color3.fromRGB(255, 192, 74),
		hasMoss = true,
	},
	Desert = {
		stone = Color3.fromRGB(214, 178, 114),
		stoneAccent = Color3.fromRGB(186, 134, 72),
		wood = Color3.fromRGB(142, 92, 52),
		woodDark = Color3.fromRGB(108, 68, 38),
		roof = Color3.fromRGB(158, 104, 58),
		lanternCol = Color3.fromRGB(255, 186, 68),
		hasMoss = false,
	},
}

function ClassicStudBiomeBuilder.BuildVoxelWatchtower(cframe: CFrame, scale: number?, parent: Instance?, theme: string?): Model
	local s = scale or 1
	local th = WATCHTOWER_THEMES[theme or "Forest"] or WATCHTOWER_THEMES.Forest
	local m = newAssetModel("VoxelWatchtower_" .. (theme or "Forest"), cframe, parent)

	-- Tiered stone foundation
	createBlock(m, cframe, s, "FoundBase", Vector3.new(6.4, 1.4, 6.4), CFrame.new(0, 0.7, 0), th.stone)
	createBlock(m, cframe, s, "FoundUpper", Vector3.new(5.4, 1.8, 5.4), CFrame.new(0, 2.3, 0), th.stoneAccent)

	-- 4 timber tower corner posts + cross beams
	for i, px in ipairs({ -2.1, 2.1 }) do
		for j, pz in ipairs({ -2.1, 2.1 }) do
			createBlock(m, cframe, s, "Post_" .. i .. "_" .. j, Vector3.new(0.95, 9.6, 0.95), CFrame.new(px, 7.8, pz), th.woodDark)
		end
	end
	createBlock(m, cframe, s, "MidBeamX1", Vector3.new(5.0, 0.65, 0.7), CFrame.new(0, 5.4, 2.1), th.wood)
	createBlock(m, cframe, s, "MidBeamX2", Vector3.new(5.0, 0.65, 0.7), CFrame.new(0, 5.4, -2.1), th.wood)

	-- Observation deck + railings
	createBlock(m, cframe, s, "ObsDeck", Vector3.new(7.4, 0.75, 7.4), CFrame.new(0, 8.6, 0), th.wood)
	for _, r in ipairs({
		{ sz = Vector3.new(7.4, 0.45, 0.5), off = Vector3.new(0, 10.1, -3.4) },
		{ sz = Vector3.new(7.4, 0.45, 0.5), off = Vector3.new(0, 10.1, 3.4) },
		{ sz = Vector3.new(0.5, 0.45, 7.4), off = Vector3.new(-3.4, 10.1, 0) },
		{ sz = Vector3.new(0.5, 0.45, 7.4), off = Vector3.new(3.4, 10.1, 0) },
	}) do
		createBlock(m, cframe, s, "Rail", r.sz, CFrame.new(r.off), th.woodDark)
	end

	-- Roof posts & pitched 3-tier voxel roof
	for i, px in ipairs({ -2.6, 2.6 }) do
		for j, pz in ipairs({ -2.6, 2.6 }) do
			createBlock(m, cframe, s, "RoofPost_" .. i .. "_" .. j, Vector3.new(0.75, 3.8, 0.75), CFrame.new(px, 10.9, pz), th.woodDark)
		end
	end
	createBlock(m, cframe, s, "RoofT1", Vector3.new(8.2, 0.9, 8.2), CFrame.new(0, 13.0, 0), th.roof)
	createBlock(m, cframe, s, "RoofT2", Vector3.new(6.0, 0.9, 6.0), CFrame.new(0, 13.9, 0), th.woodDark)
	createBlock(m, cframe, s, "RoofT3", Vector3.new(3.4, 0.9, 3.4), CFrame.new(0, 14.8, 0), th.roof)

	-- Lantern overhang beam & glowing lantern
	createBlock(m, cframe, s, "LanternBeam", Vector3.new(2.2, 0.55, 0.55), CFrame.new(-3.4, 8.2, 0), th.woodDark)
	buildGlowingLanternBox(m, cframe, s, "WatchLantern", Vector3.new(-4.1, 7.0, 0), Color3.fromRGB(48, 36, 28), th.lanternCol, 22)

	-- Stacked crates at base
	createBlock(m, cframe, s, "CrateA", Vector3.new(1.8, 1.8, 1.8), CFrame.new(-4.2, 0.9, 1.8) * CFrame.Angles(0, 0.15, 0), th.wood)
	createBlock(m, cframe, s, "CrateB", Vector3.new(1.6, 1.6, 1.6), CFrame.new(-4.5, 0.8, -0.3) * CFrame.Angles(0, -0.2, 0), th.woodDark)
	createBlock(m, cframe, s, "CrateC", Vector3.new(1.4, 1.4, 1.4), CFrame.new(-4.2, 2.5, 1.6), th.wood)

	if th.hasMoss then
		createBlock(m, cframe, s, "MossCap1", Vector3.new(3.6, 0.55, 3.6), CFrame.new(-1.8, 13.5, 1.6), Color3.fromRGB(78, 152, 58))
		createBlock(m, cframe, s, "SwampVineL", Vector3.new(0.55, 4.4, 0.55), CFrame.new(-3.4, 6.2, -2.5), Color3.fromRGB(64, 138, 52))
		createBlock(m, cframe, s, "SwampVineR", Vector3.new(0.55, 3.8, 0.55), CFrame.new(3.4, 6.6, 2.2), Color3.fromRGB(78, 156, 62))
	end
	return m
end

function ClassicStudBiomeBuilder.BuildForestStreamAndBridge(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("ForestStreamAndBridge", cframe, parent)
	local stoneCol = Color3.fromRGB(134, 140, 146)
	local woodCol = Color3.fromRGB(138, 88, 50)
	local darkWood = Color3.fromRGB(98, 62, 36)

	createBlock(m, cframe, s, "PondRim", Vector3.new(14.5, 0.3, 18.0), CFrame.new(0, 0.15, 0), stoneCol)
	local water = createBlock(m, cframe, s, "StreamWater", Vector3.new(12.2, 0.36, 16.0), CFrame.new(0, 0.2, 0), Color3.fromRGB(62, 198, 232), Enum.Material.Glass, false, 0.22)
	addSelectiveParticles(water, "Fireflies")

	-- Small arched wooden footbridge across the stream
	for idx = -3, 3 do
		local archY = 0.85 + math.cos(idx * 0.38) * 0.65
		createBlock(m, cframe, s, "BridgePlank_" .. idx, Vector3.new(1.5, 0.42, 4.8), CFrame.new(idx * 1.65, archY, 0), woodCol)
	end
	for _, zSide in ipairs({ -2.2, 2.2 }) do
		for _, xPos in ipairs({ -4.8, 0, 4.8 }) do
			createBlock(m, cframe, s, "BridgePost", Vector3.new(0.55, 2.0, 0.55), CFrame.new(xPos, 1.8, zSide), darkWood)
		end
		createBlock(m, cframe, s, "BridgeRail", Vector3.new(10.5, 0.38, 0.42), CFrame.new(0, 2.6, zSide), woodCol)
	end

	-- Shoreline reeds & wildflowers + bridge lantern
	for _, ox in ipairs({ -5.4, 5.4 }) do
		createBlock(m, cframe, s, "ShoreReed", Vector3.new(0.45, 2.0, 0.45), CFrame.new(ox, 1.0, 5.2), Color3.fromRGB(82, 168, 64))
		createBlock(m, cframe, s, "ShoreFlower", Vector3.new(0.65, 0.65, 0.65), CFrame.new(ox, 0.65, -5.0), Color3.fromRGB(255, 164, 58))
	end
	createBlock(m, cframe, s, "LampPost", Vector3.new(0.65, 3.8, 0.65), CFrame.new(-5.8, 1.9, -3.8), darkWood)
	buildGlowingLanternBox(m, cframe, s, "BridgeLantern", Vector3.new(-5.8, 4.2, -3.8), darkWood, Color3.fromRGB(255, 206, 84), 18)
	return m
end

function ClassicStudBiomeBuilder.BuildVoxelFenceWithLantern(cframe: CFrame, scale: number?, parent: Instance?, lanternColor: Color3?): Model
	local s = scale or 1
	local m = newAssetModel("VoxelFenceWithLantern", cframe, parent)
	local wood = Color3.fromRGB(132, 84, 48)
	local darkWood = Color3.fromRGB(94, 58, 34)
	local glow = lanternColor or Color3.fromRGB(255, 204, 78)

	createBlock(m, cframe, s, "StoneFoot", Vector3.new(1.8, 0.9, 1.8), CFrame.new(0, 0.45, 0), Color3.fromRGB(132, 138, 144))
	createBlock(m, cframe, s, "MainPost", Vector3.new(0.9, 4.2, 0.9), CFrame.new(0, 2.5, 0), darkWood)
	buildGlowingLanternBox(m, cframe, s, "FenceLantern", Vector3.new(0, 5.1, 0), darkWood, glow, 18)

	for _, xOff in ipairs({ -3.6, 3.6 }) do
		createBlock(m, cframe, s, "SidePost", Vector3.new(0.65, 2.6, 0.65), CFrame.new(xOff, 1.3, 0), darkWood)
	end
	createBlock(m, cframe, s, "RailUpper", Vector3.new(7.8, 0.36, 0.36), CFrame.new(0, 2.1, 0), wood)
	createBlock(m, cframe, s, "RailLower", Vector3.new(7.8, 0.36, 0.36), CFrame.new(0, 1.15, 0), wood)
	return m
end

-- BIOME 2 (SWAMP): Banyan Vine Tree, Swamp Cabin Dock, Cross Lantern Post
function ClassicStudBiomeBuilder.BuildSwampBanyanVineTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampBanyanVineTree", cframe, parent)
	local bark = Color3.fromRGB(92, 62, 42)
	local barkDark = Color3.fromRGB(68, 46, 30)
	local leafMoss = Color3.fromRGB(74, 128, 48)
	local leafBright = Color3.fromRGB(108, 162, 58)
	local leafDeep = Color3.fromRGB(54, 98, 40)

	for i, off in ipairs({ Vector3.new(2.0, 1.0, 0.4), Vector3.new(-2.0, 1.0, -0.4), Vector3.new(0.4, 1.0, 2.0), Vector3.new(-0.4, 1.0, -2.0) }) do
		createBlock(m, cframe, s, "ButtressRoot_" .. i, Vector3.new(1.8, 2.2, 1.8), CFrame.new(off), barkDark)
	end
	createBlock(m, cframe, s, "SwampTrunk", Vector3.new(3.2, 8.6, 3.2), CFrame.new(0, 4.3, 0), bark)
	createBlock(m, cframe, s, "BranchL", Vector3.new(4.8, 1.5, 1.8), CFrame.new(-3.2, 8.2, 0.4) * CFrame.Angles(0, 0, math.rad(-14)), barkDark)
	createBlock(m, cframe, s, "BranchR", Vector3.new(4.8, 1.5, 1.8), CFrame.new(3.2, 8.4, -0.4) * CFrame.Angles(0, 0, math.rad(14)), barkDark)

	createBlock(m, cframe, s, "BanyanT1", Vector3.new(16.0, 2.8, 14.5), CFrame.new(0, 10.0, 0), leafDeep)
	createBlock(m, cframe, s, "BanyanT2", Vector3.new(13.2, 2.5, 12.2), CFrame.new(0.5, 12.2, 0.3), leafMoss)
	createBlock(m, cframe, s, "BanyanT3", Vector3.new(9.2, 2.0, 9.0), CFrame.new(-0.3, 14.0, -0.2), leafBright)

	-- 12 Thick hanging swamp moss vine curtains
	for i = 1, 12 do
		local ang = (i / 12) * math.pi * 2
		local r = if i % 2 == 0 then 6.6 else 4.8
		local vx = math.cos(ang) * r
		local vz = math.sin(ang) * r
		local vh = 4.2 + (i % 3) * 1.4
		createBlock(m, cframe, s, "VineCurtain_" .. i, Vector3.new(0.7, vh, 0.7), CFrame.new(vx, 8.8 - vh * 0.5, vz), if i % 2 == 0 then leafBright else leafMoss)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildSwampWoodenCabinDock(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampWoodenCabinDock", cframe, parent)
	local plank = Color3.fromRGB(132, 88, 52)
	local timber = Color3.fromRGB(92, 60, 36)
	local stone = Color3.fromRGB(124, 128, 122)
	local moss = Color3.fromRGB(84, 148, 54)

	-- Dock stilts & plank deck
	for _, px in ipairs({ -5.2, 0, 5.2 }) do
		for _, pz in ipairs({ -4.5, 4.5 }) do
			createBlock(m, cframe, s, "Stilt", Vector3.new(0.85, 2.0, 0.85), CFrame.new(px, 0.8, pz), timber)
		end
	end
	createBlock(m, cframe, s, "DockDeck", Vector3.new(12.2, 0.65, 10.8), CFrame.new(0, 1.8, 0), plank)

	-- Cabin stone lower wall & timber upper body
	createBlock(m, cframe, s, "CabinStoneWall", Vector3.new(8.2, 2.2, 6.8), CFrame.new(1.2, 3.2, 0), stone)
	createBlock(m, cframe, s, "CabinTimberWall", Vector3.new(8.0, 2.6, 6.6), CFrame.new(1.2, 5.4, 0), plank)
	local win = createBlock(m, cframe, s, "CabinGlowWindow", Vector3.new(0.4, 1.8, 2.2), CFrame.new(-2.85, 4.4, 0), Color3.fromRGB(255, 202, 86), Enum.Material.Neon, false)
	addLanternLight(win, Color3.fromRGB(255, 198, 78), 20, 1.0)

	-- Moss-covered pitched cabin roof + vines
	createBlock(m, cframe, s, "RoofBase", Vector3.new(9.6, 1.0, 8.2), CFrame.new(1.2, 7.1, 0), timber)
	createBlock(m, cframe, s, "RoofMossTop", Vector3.new(7.4, 1.2, 6.4), CFrame.new(1.2, 8.1, 0), moss)
	createBlock(m, cframe, s, "RoofVine1", Vector3.new(0.6, 3.2, 0.6), CFrame.new(-3.2, 5.4, 3.0), moss)
	createBlock(m, cframe, s, "RoofVine2", Vector3.new(0.6, 2.6, 0.6), CFrame.new(-3.2, 5.6, -2.8), moss)

	-- Front dock fence + glowing lantern + crate
	createBlock(m, cframe, s, "FrontFence", Vector3.new(0.45, 1.6, 5.4), CFrame.new(-5.4, 2.9, 1.8), timber)
	createBlock(m, cframe, s, "LanternPole", Vector3.new(0.6, 3.4, 0.6), CFrame.new(-5.0, 3.8, -3.6), timber)
	buildGlowingLanternBox(m, cframe, s, "CabinLantern", Vector3.new(-5.0, 5.8, -3.6), timber, Color3.fromRGB(255, 202, 76), 18)
	createBlock(m, cframe, s, "DockCrate", Vector3.new(1.6, 1.6, 1.6), CFrame.new(-3.6, 2.9, -2.2), plank)
	return m
end

function ClassicStudBiomeBuilder.BuildSwampCrossLanternPost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("SwampCrossLanternPost", cframe, parent)
	local stone = Color3.fromRGB(118, 124, 114)
	local moss = Color3.fromRGB(76, 142, 54)
	local timber = Color3.fromRGB(98, 64, 38)

	createBlock(m, cframe, s, "StonePed", Vector3.new(2.2, 1.4, 2.2), CFrame.new(0, 0.7, 0), stone)
	createBlock(m, cframe, s, "MossPed", Vector3.new(1.4, 0.6, 1.2), CFrame.new(-0.5, 1.6, 0.4), moss)
	createBlock(m, cframe, s, "Pole", Vector3.new(0.85, 7.6, 0.85), CFrame.new(0, 5.2, 0), timber)
	createBlock(m, cframe, s, "CrossArm", Vector3.new(3.2, 0.7, 0.7), CFrame.new(1.1, 8.6, 0), timber)
	createBlock(m, cframe, s, "Chain", Vector3.new(0.28, 0.9, 0.28), CFrame.new(2.2, 7.9, 0), Color3.fromRGB(64, 68, 72))
	buildGlowingLanternBox(m, cframe, s, "SwampHangLantern", Vector3.new(2.2, 6.8, 0), timber, Color3.fromRGB(255, 198, 72), 20)
	return m
end

-- BIOME 3 (DESERT): Stone Arch Ruin, Flower Cactus, Dead Scrub, Pedestal Lantern
function ClassicStudBiomeBuilder.BuildDesertStoneArchRuin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertStoneArchRuin", cframe, parent)
	local stone = Color3.fromRGB(154, 152, 146)
	local sandStone = Color3.fromRGB(218, 174, 102)
	local timber = Color3.fromRGB(132, 84, 46)

	for _, xOff in ipairs({ -4.2, 4.2 }) do
		createBlock(m, cframe, s, "PillarBase", Vector3.new(2.4, 1.6, 2.4), CFrame.new(xOff, 0.8, 0), stone)
		createBlock(m, cframe, s, "PillarShaft", Vector3.new(1.7, 6.4, 1.7), CFrame.new(xOff, 4.8, 0), stone)
		createBlock(m, cframe, s, "TimberPost", Vector3.new(0.75, 6.0, 0.75), CFrame.new(xOff * 0.72, 3.0, 0.9), timber)
	end
	createBlock(m, cframe, s, "ArchLintel", Vector3.new(11.4, 1.7, 2.2), CFrame.new(0, 8.6, 0), stone)
	createBlock(m, cframe, s, "ArchSandCap", Vector3.new(9.6, 0.9, 2.0), CFrame.new(0, 9.9, 0), sandStone)
	createBlock(m, cframe, s, "ArchWoodBeam", Vector3.new(8.2, 0.65, 0.75), CFrame.new(0, 7.2, 0.8), timber)
	buildGlowingLanternBox(m, cframe, s, "ArchLantern", Vector3.new(0, 6.1, 0), timber, Color3.fromRGB(255, 194, 68), 20)
	return m
end

function ClassicStudBiomeBuilder.BuildVoxelFlowerCactus(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VoxelFlowerCactus", cframe, parent)
	local green = Color3.fromRGB(64, 172, 62)
	local greenLight = Color3.fromRGB(88, 198, 78)
	local flower = Color3.fromRGB(246, 114, 178)

	createBlock(m, cframe, s, "Stem", Vector3.new(2.0, 6.8, 2.0), CFrame.new(0, 3.4, 0), green)
	createBlock(m, cframe, s, "ArmL1", Vector3.new(2.0, 1.4, 1.4), CFrame.new(-1.8, 3.2, 0), greenLight)
	createBlock(m, cframe, s, "ArmL2", Vector3.new(1.4, 2.6, 1.4), CFrame.new(-2.4, 4.5, 0), green)
	createBlock(m, cframe, s, "ArmR1", Vector3.new(1.8, 1.3, 1.3), CFrame.new(1.7, 2.4, 0), greenLight)
	createBlock(m, cframe, s, "ArmR2", Vector3.new(1.3, 2.2, 1.3), CFrame.new(2.2, 3.6, 0), green)

	-- Pink cactus blossoms on crown & arm tips
	createBlock(m, cframe, s, "FlowerTop", Vector3.new(1.1, 0.75, 1.1), CFrame.new(0, 7.1, 0), flower)
	createBlock(m, cframe, s, "FlowerArmL", Vector3.new(0.85, 0.6, 0.85), CFrame.new(-2.4, 6.0, 0), flower)
	createBlock(m, cframe, s, "FlowerArmR", Vector3.new(0.8, 0.55, 0.8), CFrame.new(2.2, 4.9, 0), flower)
	return m
end

function ClassicStudBiomeBuilder.BuildDesertDeadScrub(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertDeadScrub", cframe, parent)
	local twigA = Color3.fromRGB(132, 88, 48)
	local twigB = Color3.fromRGB(158, 108, 60)
	createBlock(m, cframe, s, "Core", Vector3.new(0.65, 1.6, 0.65), CFrame.new(0, 0.8, 0), twigA)
	for i, b in ipairs({
		{ off = Vector3.new(-0.8, 1.4, 0.3), ang = Vector3.new(12, 0, 32) },
		{ off = Vector3.new(0.8, 1.5, -0.3), ang = Vector3.new(-14, 0, -34) },
		{ off = Vector3.new(0.2, 1.3, 0.8), ang = Vector3.new(30, 15, 0) },
		{ off = Vector3.new(-0.3, 1.3, -0.8), ang = Vector3.new(-30, -15, 0) },
	}) do
		createBlock(m, cframe, s, "Twig_" .. i, Vector3.new(0.42, 1.7, 0.42), CFrame.new(b.off) * CFrame.Angles(math.rad(b.ang.X), math.rad(b.ang.Y), math.rad(b.ang.Z)), if i % 2 == 0 then twigB else twigA)
	end
	return m
end

function ClassicStudBiomeBuilder.BuildDesertPedestalLantern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("DesertPedestalLantern", cframe, parent)
	createBlock(m, cframe, s, "PedBase", Vector3.new(2.2, 0.9, 2.2), CFrame.new(0, 0.45, 0), Color3.fromRGB(148, 146, 142))
	createBlock(m, cframe, s, "PedStep", Vector3.new(1.5, 1.0, 1.5), CFrame.new(0, 1.4, 0), Color3.fromRGB(172, 168, 160))
	createBlock(m, cframe, s, "TimberPost", Vector3.new(0.8, 1.8, 0.8), CFrame.new(0, 2.8, 0), Color3.fromRGB(122, 78, 44))
	buildGlowingLanternBox(m, cframe, s, "DesertLantern", Vector3.new(0, 4.3, 0), Color3.fromRGB(98, 64, 38), Color3.fromRGB(255, 198, 72), 18)
	return m
end

-- BIOME 4 (ALPINE ICE): Snow Igloo, Snowman, Frozen Icicle Pergola, Cyan Lantern
function ClassicStudBiomeBuilder.BuildVoxelSnowIgloo(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VoxelSnowIgloo", cframe, parent)
	local snowW = Color3.fromRGB(244, 249, 255)
	local snowB = Color3.fromRGB(204, 230, 250)

	createBlock(m, cframe, s, "DomeT1", Vector3.new(11.6, 2.4, 11.6), CFrame.new(0, 1.2, 0), snowW)
	createBlock(m, cframe, s, "DomeT2", Vector3.new(9.6, 2.2, 9.6), CFrame.new(0, 3.5, 0), snowB)
	createBlock(m, cframe, s, "DomeT3", Vector3.new(7.2, 1.8, 7.2), CFrame.new(0, 5.4, 0), snowW)
	createBlock(m, cframe, s, "DomeT4", Vector3.new(4.4, 1.2, 4.4), CFrame.new(0, 6.8, 0), snowB)

	-- Entrance tunnel (+Z facing front) & warm hearth glow
	createBlock(m, cframe, s, "TunnelWallL", Vector3.new(1.2, 3.8, 4.2), CFrame.new(-2.1, 1.9, 6.6), snowW)
	createBlock(m, cframe, s, "TunnelWallR", Vector3.new(1.2, 3.8, 4.2), CFrame.new(2.1, 1.9, 6.6), snowW)
	createBlock(m, cframe, s, "TunnelRoof", Vector3.new(5.4, 1.3, 4.2), CFrame.new(0, 4.2, 6.6), snowB)
	local hearth = createBlock(m, cframe, s, "HearthGlow", Vector3.new(2.6, 2.6, 1.0), CFrame.new(0, 1.6, 5.6), Color3.fromRGB(255, 198, 92), Enum.Material.Neon, false)
	addLanternLight(hearth, Color3.fromRGB(255, 196, 86), 22, 1.25)

	-- Tiny wooden snow fence beside door
	createBlock(m, cframe, s, "FenceRail", Vector3.new(3.8, 0.35, 0.35), CFrame.new(4.6, 1.2, 7.2), Color3.fromRGB(118, 76, 46))
	return m
end

function ClassicStudBiomeBuilder.BuildVoxelSnowman(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VoxelSnowman", cframe, parent)
	local snow = Color3.fromRGB(246, 250, 255)
	local black = Color3.fromRGB(28, 32, 40)
	local scarf = Color3.fromRGB(224, 52, 52)

	createBlock(m, cframe, s, "BottomBall", Vector3.new(2.6, 2.2, 2.6), CFrame.new(0, 1.1, 0), snow)
	createBlock(m, cframe, s, "MidBall", Vector3.new(2.1, 1.9, 2.1), CFrame.new(0, 3.1, 0), snow)
	createBlock(m, cframe, s, "Scarf", Vector3.new(2.25, 0.48, 2.25), CFrame.new(0, 4.15, 0), scarf)
	createBlock(m, cframe, s, "HeadBall", Vector3.new(1.75, 1.7, 1.75), CFrame.new(0, 5.15, 0), snow)
	createBlock(m, cframe, s, "CarrotNose", Vector3.new(0.32, 0.32, 0.85), CFrame.new(0, 5.1, 1.1), Color3.fromRGB(255, 132, 34))
	createBlock(m, cframe, s, "EyeL", Vector3.new(0.24, 0.24, 0.2), CFrame.new(-0.4, 5.45, 0.88), black)
	createBlock(m, cframe, s, "EyeR", Vector3.new(0.24, 0.24, 0.2), CFrame.new(0.4, 5.45, 0.88), black)
	createBlock(m, cframe, s, "HatBrim", Vector3.new(2.3, 0.28, 2.3), CFrame.new(0, 6.1, 0), black)
	createBlock(m, cframe, s, "HatTop", Vector3.new(1.5, 1.35, 1.5), CFrame.new(0, 6.9, 0), black)
	createBlock(m, cframe, s, "ArmL", Vector3.new(1.6, 0.24, 0.24), CFrame.new(-1.6, 3.3, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(98, 62, 36))
	createBlock(m, cframe, s, "ArmR", Vector3.new(1.6, 0.24, 0.24), CFrame.new(1.6, 3.3, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(98, 62, 36))
	return m
end

function ClassicStudBiomeBuilder.BuildFrozenIciclePergola(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FrozenIciclePergola", cframe, parent)
	local timber = Color3.fromRGB(108, 72, 46)
	local snow = Color3.fromRGB(242, 248, 255)
	local ice = Color3.fromRGB(118, 214, 255)

	for _, xOff in ipairs({ -4.5, 4.5 }) do
		for _, zOff in ipairs({ -2.4, 2.4 }) do
			createBlock(m, cframe, s, "PergolaPost", Vector3.new(0.85, 6.4, 0.85), CFrame.new(xOff, 3.2, zOff), timber)
		end
	end
	createBlock(m, cframe, s, "RoofDeck", Vector3.new(11.4, 0.85, 6.6), CFrame.new(0, 6.7, 0), timber)
	createBlock(m, cframe, s, "SnowRoofCap", Vector3.new(11.6, 1.1, 6.8), CFrame.new(0, 7.6, 0), snow)

	for idx, ix in ipairs({ -3.8, -1.9, 0, 1.9, 3.8 }) do
		local ih = 1.4 + (idx % 3) * 0.55
		createBlock(m, cframe, s, "Icicle_" .. idx, Vector3.new(0.48, ih, 0.48), CFrame.new(ix, 6.2 - ih * 0.5, 2.8), if idx % 2 == 0 then snow else ice, Enum.Material.Ice, false)
	end
	buildGlowingLanternBox(m, cframe, s, "IceLanternL", Vector3.new(-3.2, 5.2, 0), timber, Color3.fromRGB(84, 234, 255), 20)
	buildGlowingLanternBox(m, cframe, s, "IceLanternR", Vector3.new(3.2, 5.2, 0), timber, Color3.fromRGB(84, 234, 255), 20)
	return m
end

function ClassicStudBiomeBuilder.BuildAlpineCyanLantern(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("AlpineCyanLantern", cframe, parent)
	createBlock(m, cframe, s, "StonePed", Vector3.new(2.0, 1.0, 2.0), CFrame.new(0, 0.5, 0), Color3.fromRGB(134, 152, 174))
	createBlock(m, cframe, s, "Post", Vector3.new(0.8, 2.6, 0.8), CFrame.new(0, 2.3, 0), Color3.fromRGB(88, 60, 42))
	buildGlowingLanternBox(m, cframe, s, "CyanLantern", Vector3.new(0, 4.2, 0), Color3.fromRGB(54, 62, 74), Color3.fromRGB(82, 238, 255), 18)
	return m
end

-- BIOME 5 (VOLCANO): Crimson Canopy Tree, Basalt Gate Ruin, Fire Brazier Pillar, Colossal Horizon Volcano
function ClassicStudBiomeBuilder.BuildVoxelCrimsonCanopyTree(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VoxelCrimsonCanopyTree", cframe, parent)
	local bark = Color3.fromRGB(48, 32, 34)
	local barkChar = Color3.fromRGB(32, 22, 26)
	local crimDeep = Color3.fromRGB(154, 22, 34)
	local crimBright = Color3.fromRGB(214, 42, 52)
	local emberRed = Color3.fromRGB(246, 78, 42)

	for i, off in ipairs({ Vector3.new(1.3, 0.5, 0), Vector3.new(-1.3, 0.5, 0), Vector3.new(0, 0.5, 1.3), Vector3.new(0, 0.5, -1.3) }) do
		createBlock(m, cframe, s, "Root_" .. i, Vector3.new(1.3, 1.0, 1.3), CFrame.new(off), barkChar)
	end
	createBlock(m, cframe, s, "TrunkBase", Vector3.new(2.2, 5.4, 2.2), CFrame.new(0, 2.7, 0), bark)
	createBlock(m, cframe, s, "BranchL", Vector3.new(4.2, 1.2, 1.2), CFrame.new(-2.4, 6.2, 0.3) * CFrame.Angles(0, 0, math.rad(-22)), barkChar)
	createBlock(m, cframe, s, "BranchR", Vector3.new(4.2, 1.2, 1.2), CFrame.new(2.4, 6.6, -0.3) * CFrame.Angles(0, 0, math.rad(20)), barkChar)

	createBlock(m, cframe, s, "LeafPadC", Vector3.new(7.4, 1.9, 6.8), CFrame.new(0, 9.2, 0), crimDeep)
	createBlock(m, cframe, s, "LeafPadTop", Vector3.new(5.2, 1.5, 4.8), CFrame.new(0.2, 10.6, 0), crimBright)
	createBlock(m, cframe, s, "LeafPadL", Vector3.new(5.8, 1.6, 5.2), CFrame.new(-4.0, 7.6, 0.4), crimBright)
	createBlock(m, cframe, s, "LeafPadR", Vector3.new(5.8, 1.6, 5.2), CFrame.new(4.0, 8.0, -0.4), emberRed)
	return m
end

function ClassicStudBiomeBuilder.BuildVolcanicBasaltGateRuin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VolcanicBasaltGateRuin", cframe, parent)
	local basaltA = Color3.fromRGB(48, 40, 52)
	local basaltB = Color3.fromRGB(64, 52, 68)

	for _, xOff in ipairs({ -3.8, 3.8 }) do
		createBlock(m, cframe, s, "GateBase", Vector3.new(3.0, 1.6, 3.0), CFrame.new(xOff, 0.8, 0), basaltB)
		createBlock(m, cframe, s, "GatePillar", Vector3.new(2.2, 6.8, 2.2), CFrame.new(xOff, 5.0, 0), basaltA)
	end
	createBlock(m, cframe, s, "GateLintel", Vector3.new(11.0, 1.8, 2.8), CFrame.new(0, 9.2, 0), basaltB)
	createBlock(m, cframe, s, "GateCrest", Vector3.new(5.6, 1.2, 2.4), CFrame.new(0, 10.6, 0), basaltA)
	local core = createBlock(m, cframe, s, "GateCoreSlot", Vector3.new(1.4, 1.8, 2.95), CFrame.new(-3.8, 4.8, 0), Color3.fromRGB(255, 118, 28), Enum.Material.Neon, false)
	addLanternLight(core, Color3.fromRGB(255, 108, 32), 20, 1.25)
	return m
end

function ClassicStudBiomeBuilder.BuildVolcanicFireBrazierPillar(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("VolcanicFireBrazierPillar", cframe, parent)
	local basalt = Color3.fromRGB(52, 42, 54)
	createBlock(m, cframe, s, "Base", Vector3.new(2.8, 0.9, 2.8), CFrame.new(0, 0.45, 0), basalt)
	createBlock(m, cframe, s, "Shaft", Vector3.new(1.8, 2.4, 1.8), CFrame.new(0, 2.1, 0), Color3.fromRGB(40, 32, 44))
	createBlock(m, cframe, s, "Bowl", Vector3.new(2.6, 0.85, 2.6), CFrame.new(0, 3.6, 0), basalt)
	local fire = createBlock(m, cframe, s, "FlameCore", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 4.7, 0), Color3.fromRGB(255, 168, 36), Enum.Material.Neon, false)
	createBlock(m, cframe, s, "FlameTip", Vector3.new(0.85, 1.0, 0.85), CFrame.new(0, 5.7, 0), Color3.fromRGB(255, 86, 24), Enum.Material.Neon, false)
	addLanternLight(fire, Color3.fromRGB(255, 132, 36), 20, 1.3)
	addSelectiveParticles(fire, "FireEmbers")
	return m
end

function ClassicStudBiomeBuilder.BuildColossalHorizonVolcano(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("ColossalHorizonVolcano", cframe, parent)
	local darkRock = Color3.fromRGB(46, 36, 48)
	local midRock = Color3.fromRGB(64, 48, 62)
	local lavaCol = Color3.fromRGB(255, 108, 24)

	local tiers = {
		{ w = 176, h = 18, y = 9, col = darkRock },
		{ w = 136, h = 18, y = 27, col = midRock },
		{ w = 98, h = 18, y = 45, col = darkRock },
		{ w = 64, h = 18, y = 63, col = midRock },
		{ w = 36, h = 14, y = 79, col = darkRock },
	}
	for i, t in ipairs(tiers) do
		createBlock(m, cframe, s, "VolcanoTier_" .. i, Vector3.new(t.w, t.h, t.w * 0.72), CFrame.new(0, t.y, 0), t.col)
	end
	local caldera = createBlock(m, cframe, s, "SummitMagma", Vector3.new(26, 3.0, 20), CFrame.new(0, 86.2, 0), Color3.fromRGB(255, 152, 32), Enum.Material.Neon, false)
	addSelectiveParticles(caldera, "VolcanoSmoke")

	-- Glowing stepped lava veins running down the front (-Z) face toward player camera
	for i = 1, 5 do
		local y = 80 - (i - 1) * 16
		local z = -14 - (i - 1) * 11.5
		createBlock(m, cframe, s, "LavaRiverCenter_" .. i, Vector3.new(8 + i * 2, 16, 4), CFrame.new(0, y, z), lavaCol, Enum.Material.Neon, false)
		createBlock(m, cframe, s, "LavaRiverLeft_" .. i, Vector3.new(5 + i, 15, 3.5), CFrame.new(-12 - i * 4, y - 4, z + 3), lavaCol, Enum.Material.Neon, false)
	end
	return m
end

-- SHARED HORIZON ARCHWAYS & FLOATING SKY ISLANDS
local ARCHWAY_STYLES = {
	PineWoods = { pillar = Color3.fromRGB(168, 52, 42), trim = Color3.fromRGB(118, 42, 34), cap = Color3.fromRGB(72, 154, 62), glow = Color3.fromRGB(255, 206, 86) },
	MangroveSwamp = { pillar = Color3.fromRGB(98, 68, 44), trim = Color3.fromRGB(74, 134, 56), cap = Color3.fromRGB(108, 168, 62), glow = Color3.fromRGB(255, 198, 72) },
	SavannaCamp = { pillar = Color3.fromRGB(218, 174, 102), trim = Color3.fromRGB(182, 128, 68), cap = Color3.fromRGB(242, 204, 132), glow = Color3.fromRGB(255, 194, 68) },
	AlpinePeaks = { pillar = Color3.fromRGB(184, 224, 250), trim = Color3.fromRGB(114, 198, 248), cap = Color3.fromRGB(244, 249, 255), glow = Color3.fromRGB(82, 238, 255) },
	VolcanicJungle = { pillar = Color3.fromRGB(46, 36, 48), trim = Color3.fromRGB(68, 52, 68), cap = Color3.fromRGB(255, 102, 28), glow = Color3.fromRGB(255, 132, 32) },
}

function ClassicStudBiomeBuilder.BuildBiomeHorizonArchway(cframe: CFrame, scale: number?, parent: Instance?, biomeId: string): Model
	local s = scale or 1
	local st = ARCHWAY_STYLES[biomeId] or ARCHWAY_STYLES.PineWoods
	local m = newAssetModel("BiomeHorizonArchway_" .. biomeId, cframe, parent)

	for _, xSide in ipairs({ -20, 20 }) do
		createBlock(m, cframe, s, "PillarBase_" .. xSide, Vector3.new(5.2, 2.4, 5.2), CFrame.new(xSide, 1.2, 0), st.trim)
		createBlock(m, cframe, s, "PillarCol_" .. xSide, Vector3.new(3.4, 17.5, 3.4), CFrame.new(xSide, 11.0, 0), st.pillar)
		buildGlowingLanternBox(m, cframe, s, "ArchLamp_" .. xSide, Vector3.new(xSide * 0.78, 14.5, 0), st.trim, st.glow, 22)
	end
	createBlock(m, cframe, s, "TopCrossBeam", Vector3.new(48.0, 2.8, 4.4), CFrame.new(0, 20.8, 0), st.pillar)
	createBlock(m, cframe, s, "LowerCrossBeam", Vector3.new(43.0, 1.8, 3.2), CFrame.new(0, 17.4, 0), st.trim)
	createBlock(m, cframe, s, "CrownCap", Vector3.new(51.0, 1.5, 5.2), CFrame.new(0, 22.8, 0), st.cap)
	return m
end

local SKY_ISLAND_PALETTES = {
	PineWoods = { top = Color3.fromRGB(98, 182, 74), rim = Color3.fromRGB(132, 92, 58), stone = Color3.fromRGB(118, 94, 78), treeFn = ClassicStudBiomeBuilder.BuildLushVoxelTreeWithVines, isVolcano = false },
	MangroveSwamp = { top = Color3.fromRGB(82, 134, 58), rim = Color3.fromRGB(96, 70, 44), stone = Color3.fromRGB(84, 74, 62), treeFn = ClassicStudBiomeBuilder.BuildSwampBanyanVineTree, isVolcano = false },
	SavannaCamp = { top = Color3.fromRGB(232, 192, 108), rim = Color3.fromRGB(204, 134, 68), stone = Color3.fromRGB(168, 102, 56), treeFn = ClassicStudBiomeBuilder.BuildVoxelFlowerCactus, isVolcano = false },
	AlpinePeaks = { top = Color3.fromRGB(242, 248, 255), rim = Color3.fromRGB(142, 214, 248), stone = Color3.fromRGB(108, 168, 222), treeFn = ClassicStudBiomeBuilder.BuildSnowyPineTreeTall, isVolcano = false },
	VolcanicJungle = { top = Color3.fromRGB(58, 46, 62), rim = Color3.fromRGB(46, 36, 48), stone = Color3.fromRGB(34, 28, 38), treeFn = ClassicStudBiomeBuilder.BuildVoxelCrimsonCanopyTree, isVolcano = true },
}

function ClassicStudBiomeBuilder.BuildBiomeFloatingSkyIsland(
	cframe: CFrame,
	scale: number?,
	parent: Instance?,
	biomeId: string,
	hasFall: boolean?,
	fallSideSign: number?
): Model
	local s = scale or 1
	local pal = SKY_ISLAND_PALETTES[biomeId] or SKY_ISLAND_PALETTES.PineWoods
	local m = newAssetModel("BiomeSkyIsland_" .. biomeId, cframe, parent)

	local topPlate = createBlock(m, cframe, s, "IslandTopCap", Vector3.new(40, 4.4, 36), CFrame.new(0, 0, 0), pal.top)
	m.PrimaryPart = topPlate
	createBlock(m, cframe, s, "IslandDeckStep", Vector3.new(22, 3.2, 20), CFrame.new(-6, 3.6, 4), pal.top)
	createBlock(m, cframe, s, "IslandStrataA", Vector3.new(34, 9.0, 30), CFrame.new(0, -6.5, 0), pal.rim)
	createBlock(m, cframe, s, "IslandStrataB", Vector3.new(24, 11.0, 21), CFrame.new(2, -16.0, -1), pal.stone)
	createBlock(m, cframe, s, "IslandKeelTip", Vector3.new(12, 10.0, 11), CFrame.new(1, -25.5, 0), pal.stone)

	-- Top vegetation matching the biome
	pal.treeFn(cframe * CFrame.new(-7 * s, 5.2 * s, 4 * s), s * 1.15, m)
	pal.treeFn(cframe * CFrame.new(9 * s, 2.2 * s, -6 * s), s * 0.9, m)
	createBlock(m, cframe, s, "SkyBoulder", Vector3.new(5.5, 4.0, 5.5), CFrame.new(6, 4.0, 8), pal.stone)

	-- Hanging vines / icicles / lava accents underneath
	for i = 1, 4 do
		local hx = (-12 + i * 6)
		local hz = if i % 2 == 0 then 14 else -14
		local hCol = if biomeId == "AlpinePeaks" then Color3.fromRGB(168, 232, 255) elseif pal.isVolcano then Color3.fromRGB(255, 108, 28) else Color3.fromRGB(82, 168, 62)
		createBlock(m, cframe, s, "IslandHang_" .. i, Vector3.new(1.2, 6.5, 1.2), CFrame.new(hx, -5.2, hz), hCol, if pal.isVolcano then Enum.Material.Neon else nil, not pal.isVolcano)
	end

	-- Optional cascading waterfall or magma lavafall toward the main trail
	if hasFall then
		local side = fallSideSign or -1
		local fx = side * 19.5
		if pal.isVolcano then
			local lava = createBlock(m, cframe, s, "SkyLavafall", Vector3.new(3.2, 48, 7.8), CFrame.new(fx, -23.0, 0), Color3.fromRGB(255, 112, 24), Enum.Material.Neon, false)
			addSelectiveParticles(lava, "FireEmbers")
		else
			local water = createBlock(m, cframe, s, "SkyWaterfall", Vector3.new(3.0, 52, 8.2), CFrame.new(fx, -25.0, 0), Color3.fromRGB(76, 206, 250), Enum.Material.Glass, false, 0.25)
			createBlock(m, cframe, s, "WaterfallFoamTop", Vector3.new(4.2, 1.8, 9.2), CFrame.new(fx * 0.96, 1.8, 0), Color3.fromRGB(238, 250, 255))
			addSelectiveParticles(water, "WaterfallMist")
		end
	end
	return m
end

function ClassicStudBiomeBuilder.ApplyReferenceLighting()
	local Lighting = game:GetService("Lighting")
	local Workspace = game:GetService("Workspace")
	pcall(function()
		Lighting.ClockTime = 14.8
		Lighting.Brightness = 1.85
		Lighting.ExposureCompensation = -0.06
		Lighting.Ambient = Color3.fromRGB(108, 124, 146)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 148, 174)
		Lighting.EnvironmentDiffuseScale = 0.65
		Lighting.EnvironmentSpecularScale = 0.28
		Lighting.GlobalShadows = true
	end)

	local atm = Lighting:FindFirstChild("GameAtmosphere") :: Atmosphere?
	if not atm or not atm:IsA("Atmosphere") then
		atm = Instance.new("Atmosphere")
		atm.Name = "GameAtmosphere"
		atm.Parent = Lighting
	end
	atm.Density = 0.17
	atm.Offset = 0.22
	atm.Color = Color3.fromRGB(196, 230, 255)
	atm.Decay = Color3.fromRGB(164, 206, 246)
	atm.Glare = 0.12
	atm.Haze = 0.45

	local cc = Lighting:FindFirstChild("GameColorCorrection") :: ColorCorrectionEffect?
	if not cc or not cc:IsA("ColorCorrectionEffect") then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "GameColorCorrection"
		cc.Parent = Lighting
	end
	cc.Saturation = 0.14
	cc.Contrast = 0.08
	cc.Brightness = 0.0

	local bloom = Lighting:FindFirstChild("GameBloom") :: BloomEffect?
	if not bloom or not bloom:IsA("BloomEffect") then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "GameBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.14
	bloom.Size = 18
	bloom.Threshold = 2.15

	local sunRays = Lighting:FindFirstChild("GameSunRays") :: SunRaysEffect?
	if not sunRays or not sunRays:IsA("SunRaysEffect") then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "GameSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Intensity = 0.04
	sunRays.Spread = 0.25

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.52
	clouds.Density = 0.48
	clouds.Color = Color3.fromRGB(244, 249, 255)
	clouds.Parent = Workspace.Terrain
end

-- ============================================================================
-- PER-BIOME REGISTRIES
-- ============================================================================

ClassicStudBiomeBuilder.BIOME_1_ASSETS = {
	{ id = "PineTreeTall", title = "Pine Tree (Tall)", category = "Tree", catalogScale = 0.65, build = ClassicStudBiomeBuilder.BuildPineTreeTall },
	{ id = "LushVoxelTreeWithVines", title = "Lush Vine Canopy Tree", category = "Tree", catalogScale = 0.56, build = ClassicStudBiomeBuilder.BuildLushVoxelTreeWithVines },
	{ id = "OakTreeBroad", title = "Oak Tree (Broad)", category = "Tree", catalogScale = 0.68, build = ClassicStudBiomeBuilder.BuildOakTreeBroad },
	{ id = "BirchTreeForest", title = "Birch Tree", category = "Tree", catalogScale = 0.72, build = ClassicStudBiomeBuilder.BuildBirchTreeForest },
	{ id = "GrassTuftCluster", title = "Grass Tufts 3D", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildGrassTuftCluster },
	{ id = "MossyTurfPatch", title = "Mossy Turf Patch", category = "Flora", catalogScale = 0.85, build = ClassicStudBiomeBuilder.BuildMossyTurfPatch },
	{ id = "FernCluster", title = "Forest Ferns", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildFernCluster },
	{ id = "BerryBush", title = "Berry Bush", category = "Flora", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildBerryBush },
	{ id = "WildflowerPatch", title = "Wildflowers", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildWildflowerPatch },
	{ id = "VoxelWatchtower", title = "Forest Watchtower", category = "Prop", catalogScale = 0.42, build = function(cf, sc, p) return ClassicStudBiomeBuilder.BuildVoxelWatchtower(cf, sc, p, "Forest") end },
	{ id = "ForestStreamAndBridge", title = "Stream & Wood Bridge", category = "Prop", catalogScale = 0.44, build = ClassicStudBiomeBuilder.BuildForestStreamAndBridge },
	{ id = "VoxelFenceWithLantern", title = "Fence & Lantern", category = "Prop", catalogScale = 0.75, build = ClassicStudBiomeBuilder.BuildVoxelFenceWithLantern },
	{ id = "MossyBoulder", title = "Mossy Boulder", category = "Prop", catalogScale = 0.82, build = ClassicStudBiomeBuilder.BuildMossyBoulder },
	{ id = "FallenHollowLog", title = "Fallen Hollow Log", category = "Prop", catalogScale = 0.78, build = ClassicStudBiomeBuilder.BuildFallenHollowLog },
	{ id = "MushroomCluster", title = "Toadstool Trio", category = "Prop", catalogScale = 1.0, build = ClassicStudBiomeBuilder.BuildMushroomCluster },
} :: { AssetSpec }

ClassicStudBiomeBuilder.BIOME_2_ASSETS = {
	{ id = "SwampBanyanVineTree", title = "Swamp Banyan Vine Tree", category = "Tree", catalogScale = 0.54, build = ClassicStudBiomeBuilder.BuildSwampBanyanVineTree },
	{ id = "MangroveTreeArch", title = "Mangrove Tree Arch", category = "Tree", catalogScale = 0.68, build = ClassicStudBiomeBuilder.BuildMangroveTreeArch },
	{ id = "DeadSwampWillow", title = "Dead Swamp Willow", category = "Tree", catalogScale = 0.72, build = ClassicStudBiomeBuilder.BuildDeadSwampWillow },
	{ id = "GiantGlowMushroom", title = "Giant Glow Mushroom", category = "Tree", catalogScale = 0.72, build = ClassicStudBiomeBuilder.BuildGiantGlowMushroom },
	{ id = "CattailReedCluster", title = "Cattail Reeds", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildCattailReedCluster },
	{ id = "SwampLilyPadCluster", title = "Swamp Lily Pads", category = "Flora", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildSwampLilyPadCluster },
	{ id = "MudMossTurfPatch", title = "Mud & Moss Turf", category = "Flora", catalogScale = 0.82, build = ClassicStudBiomeBuilder.BuildMudMossTurfPatch },
	{ id = "SwampVineFern", title = "Swamp Vine Fern", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildSwampVineFern },
	{ id = "GlowSporeTrio", title = "Glow Spore Trio", category = "Flora", catalogScale = 1.0, build = ClassicStudBiomeBuilder.BuildGlowSporeTrio },
	{ id = "SwampWoodenCabinDock", title = "Swamp Cabin & Dock", category = "Prop", catalogScale = 0.48, build = ClassicStudBiomeBuilder.BuildSwampWoodenCabinDock },
	{ id = "SwampCrossLanternPost", title = "Swamp Cross Lantern", category = "Prop", catalogScale = 0.68, build = ClassicStudBiomeBuilder.BuildSwampCrossLanternPost },
	{ id = "SwampTotemShrine", title = "Swamp Totem Shrine", category = "Prop", catalogScale = 0.62, build = ClassicStudBiomeBuilder.BuildSwampTotemShrine },
	{ id = "MossySwampBoulder", title = "Mossy Swamp Boulder", category = "Prop", catalogScale = 0.85, build = ClassicStudBiomeBuilder.BuildMossySwampBoulder },
	{ id = "WoodenSwampDock", title = "Wooden Swamp Dock", category = "Prop", catalogScale = 0.78, build = ClassicStudBiomeBuilder.BuildWoodenSwampDock },
} :: { AssetSpec }

ClassicStudBiomeBuilder.BIOME_3_ASSETS = {
	{ id = "DesertStepPyramid", title = "Desert Step Pyramid", category = "Tree", catalogScale = 0.36, build = ClassicStudBiomeBuilder.BuildDesertStepPyramid },
	{ id = "AcaciaTreeFlat", title = "Savanna Acacia Tree", category = "Tree", catalogScale = 0.65, build = ClassicStudBiomeBuilder.BuildAcaciaTreeFlat },
	{ id = "DesertPalmTree", title = "Desert Palm Tree", category = "Tree", catalogScale = 0.72, build = ClassicStudBiomeBuilder.BuildDesertPalmTree },
	{ id = "SaguaroCactusGiant", title = "Saguaro Cactus", category = "Tree", catalogScale = 0.78, build = ClassicStudBiomeBuilder.BuildSaguaroCactusGiant },
	{ id = "VoxelFlowerCactus", title = "Flowering Cactus", category = "Flora", catalogScale = 0.82, build = ClassicStudBiomeBuilder.BuildVoxelFlowerCactus },
	{ id = "BarrelCactusCluster", title = "Barrel Cactus Cluster", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildBarrelCactusCluster },
	{ id = "SavannaGrassTuft", title = "Savanna Grass Tuft", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildSavannaGrassTuft },
	{ id = "DesertDeadScrub", title = "Desert Deadwood Scrub", category = "Flora", catalogScale = 1.0, build = ClassicStudBiomeBuilder.BuildDesertDeadScrub },
	{ id = "DesertStoneArchRuin", title = "Desert Arch Ruin", category = "Prop", catalogScale = 0.56, build = ClassicStudBiomeBuilder.BuildDesertStoneArchRuin },
	{ id = "DesertPedestalLantern", title = "Desert Pedestal Lamp", category = "Prop", catalogScale = 0.85, build = ClassicStudBiomeBuilder.BuildDesertPedestalLantern },
	{ id = "SandstoneMesaArch", title = "Sandstone Mesa Arch", category = "Prop", catalogScale = 0.72, build = ClassicStudBiomeBuilder.BuildSandstoneMesaArch },
	{ id = "OasisWaterPool", title = "Oasis Water Pool", category = "Prop", catalogScale = 0.75, build = ClassicStudBiomeBuilder.BuildOasisWaterPool },
	{ id = "DesertSkullBone", title = "Desert Skull & Bones", category = "Prop", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildDesertSkullBone },
} :: { AssetSpec }

ClassicStudBiomeBuilder.BIOME_4_ASSETS = {
	{ id = "GiantIceCrystalSpire", title = "Giant Ice Crystal Spire", category = "Tree", catalogScale = 0.52, build = ClassicStudBiomeBuilder.BuildGiantIceCrystalSpire },
	{ id = "SnowyPineTreeTall", title = "Snowy Pine (Tall)", category = "Tree", catalogScale = 0.65, build = ClassicStudBiomeBuilder.BuildSnowyPineTreeTall },
	{ id = "SnowyPineTreeTwin", title = "Snowy Pine (Twin)", category = "Tree", catalogScale = 0.68, build = ClassicStudBiomeBuilder.BuildSnowyPineTreeTwin },
	{ id = "FrostedBirchTree", title = "Frosted Birch Tree", category = "Tree", catalogScale = 0.7, build = ClassicStudBiomeBuilder.BuildFrostedBirchTree },
	{ id = "SnowDriftTurfPatch", title = "Snow Drift Turf", category = "Flora", catalogScale = 0.82, build = ClassicStudBiomeBuilder.BuildSnowDriftTurfPatch },
	{ id = "FrostGrassTuft", title = "Frost Grass Tuft", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildFrostGrassTuft },
	{ id = "IceBerryBush", title = "Ice Berry Bush", category = "Flora", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildIceBerryBush },
	{ id = "CrystalFrostFlower", title = "Crystal Frost Flowers", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildCrystalFrostFlower },
	{ id = "VoxelSnowIgloo", title = "Voxel Snow Igloo", category = "Prop", catalogScale = 0.48, build = ClassicStudBiomeBuilder.BuildVoxelSnowIgloo },
	{ id = "VoxelSnowman", title = "Voxel Snowman", category = "Prop", catalogScale = 0.78, build = ClassicStudBiomeBuilder.BuildVoxelSnowman },
	{ id = "FrozenIciclePergola", title = "Icicle Pergola", category = "Prop", catalogScale = 0.54, build = ClassicStudBiomeBuilder.BuildFrozenIciclePergola },
	{ id = "AlpineCyanLantern", title = "Alpine Cyan Lantern", category = "Prop", catalogScale = 0.85, build = ClassicStudBiomeBuilder.BuildAlpineCyanLantern },
	{ id = "IceCrystalCluster", title = "Ice Crystal Cluster", category = "Prop", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildIceCrystalCluster },
} :: { AssetSpec }

ClassicStudBiomeBuilder.BIOME_5_ASSETS = {
	{ id = "VolcanoCraterLandmark", title = "Volcano Crater Spire", category = "Tree", catalogScale = 0.40, build = ClassicStudBiomeBuilder.BuildVolcanoCraterLandmark },
	{ id = "VoxelCrimsonCanopyTree", title = "Crimson Canopy Tree", category = "Tree", catalogScale = 0.62, build = ClassicStudBiomeBuilder.BuildVoxelCrimsonCanopyTree },
	{ id = "CharredCrimsonTree", title = "Charred Crimson Tree", category = "Tree", catalogScale = 0.68, build = ClassicStudBiomeBuilder.BuildCharredCrimsonTree },
	{ id = "MagmaPalmTree", title = "Magma Palm Tree", category = "Tree", catalogScale = 0.72, build = ClassicStudBiomeBuilder.BuildMagmaPalmTree },
	{ id = "AshEmberGrassTuft", title = "Ash Ember Grass", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildAshEmberGrassTuft },
	{ id = "BasaltLavaTurfPatch", title = "Basalt & Lava Turf", category = "Flora", catalogScale = 0.82, build = ClassicStudBiomeBuilder.BuildBasaltLavaTurfPatch },
	{ id = "FirebloomFlowerPatch", title = "Firebloom Flowers", category = "Flora", catalogScale = 0.95, build = ClassicStudBiomeBuilder.BuildFirebloomFlowerPatch },
	{ id = "ScorchedThornBush", title = "Scorched Thorn Bush", category = "Flora", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildScorchedThornBush },
	{ id = "VolcanicBasaltGateRuin", title = "Basalt Gate Ruin", category = "Prop", catalogScale = 0.56, build = ClassicStudBiomeBuilder.BuildVolcanicBasaltGateRuin },
	{ id = "VolcanicFireBrazierPillar", title = "Fire Brazier Pillar", category = "Prop", catalogScale = 0.82, build = ClassicStudBiomeBuilder.BuildVolcanicFireBrazierPillar },
	{ id = "ObsidianMonolithRuins", title = "Obsidian Monolith", category = "Prop", catalogScale = 0.75, build = ClassicStudBiomeBuilder.BuildObsidianMonolithRuins },
	{ id = "MagmaVentGeyser", title = "Magma Vent Geyser", category = "Prop", catalogScale = 0.85, build = ClassicStudBiomeBuilder.BuildMagmaVentGeyser },
	{ id = "CrimsonCrystalCluster", title = "Crimson Crystals", category = "Prop", catalogScale = 0.9, build = ClassicStudBiomeBuilder.BuildCrimsonCrystalCluster },
} :: { AssetSpec }

ClassicStudBiomeBuilder.BIOME_ASSETS_BY_ID = {
	PineWoods = ClassicStudBiomeBuilder.BIOME_1_ASSETS,
	MangroveSwamp = ClassicStudBiomeBuilder.BIOME_2_ASSETS,
	SavannaCamp = ClassicStudBiomeBuilder.BIOME_3_ASSETS,
	AlpinePeaks = ClassicStudBiomeBuilder.BIOME_4_ASSETS,
	VolcanicJungle = ClassicStudBiomeBuilder.BIOME_5_ASSETS,
}

-- ============================================================================
-- SHOWROOM LABELS, BAY LAYOUT & 5-BIOME BUILDER (NO COLLIDERS!)
-- ============================================================================

local function attachCatalogLabel(model: Model, title: string, category: string, accent: Color3)
	local cf, sz = model:GetBoundingBox()
	local partCount = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPivot" then
			partCount += 1
		end
	end

	local anchor = makeStudPart({
		name = "CatalogTagAnchor",
		size = Vector3.new(0.1, 0.1, 0.1),
		cframe = CFrame.new(cf.Position.X, cf.Position.Y + sz.Y * 0.5 + 1.2, cf.Position.Z),
		color = Color3.new(1, 1, 1),
		studded = false,
		transparency = 1,
		castShadow = false,
		parent = model,
	})

	local bb = Instance.new("BillboardGui")
	bb.Name = "AssetCatalogTag"
	bb.Size = UDim2.new(6.2, 0, 1.65, 0)
	bb.MaxDistance = 85
	bb.Parent = anchor

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(16, 22, 30)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = bb
	Instance.new("UICorner", card).CornerRadius = UDim.new(0.2, 0)
	local st = Instance.new("UIStroke")
	st.Color = accent
	st.Thickness = 1.8
	st.Parent = card

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(0.94, 0, 0.52, 0)
	tLbl.Position = UDim2.new(0.03, 0, 0.05, 0)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.FredokaOne
	tLbl.TextScaled = true
	tLbl.TextColor3 = Color3.new(1, 1, 1)
	tLbl.Text = title
	tLbl.Parent = card

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(0.94, 0, 0.36, 0)
	sLbl.Position = UDim2.new(0.03, 0, 0.58, 0)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBold
	sLbl.TextScaled = true
	sLbl.TextColor3 = accent
	sLbl.Text = string.format("[%s • CLASSIC STUDS • %d Parts]", string.upper(category), partCount)
	sLbl.Parent = card
end

local function buildCatalogSignBoard(title: string, subText: string, pos: Vector3, width: number, accent: Color3, parent: Instance)
	local board = makeStudPart({
		name = "BiomeShowroomHeaderBoard",
		size = Vector3.new(width, 3.6, 0.4),
		cframe = CFrame.new(pos) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(18, 24, 34),
		material = Enum.Material.SmoothPlastic,
		studded = false,
		castShadow = false,
		parent = parent,
	})
	makeStudPart({
		name = "BoardAccentTrim",
		size = Vector3.new(width + 0.4, 0.22, 0.46),
		cframe = CFrame.new(pos + Vector3.new(0, 1.9, 0)),
		color = accent,
		material = Enum.Material.Neon,
		studded = false,
		castShadow = false,
		parent = parent,
	})
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 0.2
		sg.Parent = board

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(16, 22, 30)
		bg.BorderSizePixel = 0
		bg.Parent = sg

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0.96, 0, 0.54, 0)
		t.Position = UDim2.new(0.02, 0, 0.06, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = accent
		t.Text = title
		t.Parent = bg

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.96, 0, 0.30, 0)
		sub.Position = UDim2.new(0.02, 0, 0.64, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(224, 234, 244)
		sub.Text = subText
		sub.Parent = bg
	end
end

local SHOWROOM_BIOME_META = {
	{
		order = 1,
		id = "PineWoods",
		modelName = "Biome1_PineWoods_Showroom",
		title = "BIOME 1 • WHISPERING PINE WOODS",
		subtitle = "15 Classic Stud Assets • Trees • Ferns • Berry Bushes • Wildflowers • Logs • No Colliders",
		bayZ = -47,
		courtZ = 0,
		leftX = -48,
		rightX = 56,
		lawnColor = Color3.fromRGB(86, 158, 74),
		borderColor = Color3.fromRGB(58, 122, 54),
		trailColor = Color3.fromRGB(134, 102, 72),
		accent = Color3.fromRGB(92, 218, 122),
		assets = ClassicStudBiomeBuilder.BIOME_1_ASSETS,
	},
	{
		order = 2,
		id = "MangroveSwamp",
		modelName = "Biome2_MangroveSwamp_Showroom",
		title = "BIOME 2 • MUDDY MANGROVE SWAMP",
		subtitle = "13 Classic Stud Assets • Mangroves • Glow Mushrooms • Shrine • Reeds • Dock • No Colliders",
		bayZ = -87,
		courtZ = -32,
		leftX = -54,
		rightX = 62,
		lawnColor = Color3.fromRGB(82, 68, 48),
		borderColor = Color3.fromRGB(58, 118, 86),
		trailColor = Color3.fromRGB(52, 148, 122),
		accent = Color3.fromRGB(64, 214, 178),
		assets = ClassicStudBiomeBuilder.BIOME_2_ASSETS,
	},
	{
		order = 3,
		id = "SavannaCamp",
		modelName = "Biome3_SavannaCamp_Showroom",
		title = "BIOME 3 • SAVANNA & DESERT OASIS",
		subtitle = "13 Classic Stud Assets • Step Pyramid • Acacia • Palm • Cacti • Ruins • Oasis • No Colliders",
		bayZ = -127,
		courtZ = -68,
		leftX = -54,
		rightX = 56,
		lawnColor = Color3.fromRGB(214, 174, 88),
		borderColor = Color3.fromRGB(168, 124, 54),
		trailColor = Color3.fromRGB(192, 134, 72),
		accent = Color3.fromRGB(255, 184, 58),
		assets = ClassicStudBiomeBuilder.BIOME_3_ASSETS,
	},
	{
		order = 4,
		id = "AlpinePeaks",
		modelName = "Biome4_AlpinePeaks_Showroom",
		title = "BIOME 4 • FROSTBITE ALPINE PEAKS",
		subtitle = "13 Classic Stud Assets • Giant Ice Spire • Snowy Pines • Ice Arch • Cairn • No Colliders",
		bayZ = -167,
		courtZ = -108,
		leftX = -60,
		rightX = 60,
		lawnColor = Color3.fromRGB(224, 240, 250),
		borderColor = Color3.fromRGB(124, 184, 224),
		trailColor = Color3.fromRGB(142, 214, 248),
		accent = Color3.fromRGB(78, 208, 255),
		assets = ClassicStudBiomeBuilder.BIOME_4_ASSETS,
	},
	{
		order = 5,
		id = "VolcanicJungle",
		modelName = "Biome5_VolcanicJungle_Showroom",
		title = "BIOME 5 • VOLCANIC OBSIDIAN JUNGLE",
		subtitle = "13 Classic Stud Assets • Volcano Crater • Monolith • Magma Geysers • Crimson Trees • No Colliders",
		bayZ = -207,
		courtZ = -148,
		leftX = -63,
		rightX = 72,
		lawnColor = Color3.fromRGB(54, 46, 58),
		borderColor = Color3.fromRGB(214, 78, 32),
		trailColor = Color3.fromRGB(255, 96, 28),
		accent = Color3.fromRGB(255, 118, 48),
		assets = ClassicStudBiomeBuilder.BIOME_5_ASSETS,
	},
}

local function populateBiomeDiorama(biomeId: string, diorama: Model, cx: number, cz: number, floorY: number, meta: any)
	makeStudPart({
		name = "DioramaBaseGround",
		size = Vector3.new(56, 0.24, 34),
		cframe = CFrame.new(cx, SHOWROOM_FLOOR_Y + 0.12, cz),
		color = meta.lawnColor,
		castShadow = false,
		parent = diorama,
	})

	if biomeId == "PineWoods" then
		makeStudPart({ name = "ForestTrail", size = Vector3.new(9, 0.28, 34), cframe = CFrame.new(cx, SHOWROOM_FLOOR_Y + 0.14, cz), color = meta.trailColor, castShadow = false, parent = diorama })
		ClassicStudBiomeBuilder.BuildPineTreeTall(CFrame.new(cx - 18, floorY, cz + 10), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildPineTreeTwin(CFrame.new(cx + 18, floorY, cz + 9), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildOakTreeBroad(CFrame.new(cx - 17, floorY, cz - 9), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildBirchTreeForest(CFrame.new(cx + 17, floorY, cz - 10), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildMossyBoulder(CFrame.new(cx + 10, floorY, cz + 1), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildFallenHollowLog(CFrame.new(cx - 11, floorY, cz + 2) * CFrame.Angles(0, 0.5, 0), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildTreeStump(CFrame.new(cx + 9, floorY, cz - 9), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildMushroomCluster(CFrame.new(cx - 8, floorY, cz - 8), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildBerryBush(CFrame.new(cx + 21, floorY, cz - 1), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildWildflowerPatch(CFrame.new(cx - 8, floorY, cz + 10), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildFernCluster(CFrame.new(cx + 12, floorY, cz + 11), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildGrassTuftCluster(CFrame.new(cx - 21, floorY, cz - 1), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildRangerLanternPost(CFrame.new(cx - 6, floorY, cz + 8), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildRangerLanternPost(CFrame.new(cx + 6, floorY, cz - 6) * CFrame.Angles(0, math.pi, 0), 0.95, diorama)
	elseif biomeId == "MangroveSwamp" then
		makeStudPart({ name = "SwampLagoonStrip", size = Vector3.new(12, 0.28, 34), cframe = CFrame.new(cx, SHOWROOM_FLOOR_Y + 0.14, cz), color = meta.trailColor, castShadow = false, transparency = 0.22, parent = diorama })
		ClassicStudBiomeBuilder.BuildSwampTotemShrine(CFrame.new(cx - 15, floorY, cz - 11) * CFrame.Angles(0, math.rad(15), 0), 0.85, diorama)
		ClassicStudBiomeBuilder.BuildMangroveTreeArch(CFrame.new(cx + 16, floorY, cz + 8), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildDeadSwampWillow(CFrame.new(cx - 18, floorY, cz + 9), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildGiantGlowMushroom(CFrame.new(cx + 18, floorY, cz - 10), 0.88, diorama)
		ClassicStudBiomeBuilder.BuildWoodenSwampDock(CFrame.new(cx, floorY - 0.15, cz + 5) * CFrame.Angles(0, math.rad(90), 0), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildSwampLilyPadCluster(CFrame.new(cx - 1, floorY, cz - 8), 1.05, diorama)
		ClassicStudBiomeBuilder.BuildCattailReedCluster(CFrame.new(cx - 7.5, floorY, cz - 2), 1.05, diorama)
		ClassicStudBiomeBuilder.BuildCattailReedCluster(CFrame.new(cx + 7.5, floorY, cz + 10), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildSunkenHollowLog(CFrame.new(cx + 11, floorY, cz - 1) * CFrame.Angles(0, -0.4, 0), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildMossySwampBoulder(CFrame.new(cx - 14, floorY, cz + 1), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildGlowSporeTrio(CFrame.new(cx + 10, floorY, cz - 11), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildSwampLanternTotem(CFrame.new(cx - 7.5, floorY, cz + 11), 0.95, diorama)
	elseif biomeId == "SavannaCamp" then
		makeStudPart({ name = "DesertRoad", size = Vector3.new(9, 0.28, 34), cframe = CFrame.new(cx + 12, SHOWROOM_FLOOR_Y + 0.14, cz), color = meta.trailColor, castShadow = false, parent = diorama })
		ClassicStudBiomeBuilder.BuildDesertStepPyramid(CFrame.new(cx - 11, floorY, cz - 3), 0.72, diorama)
		ClassicStudBiomeBuilder.BuildOasisWaterPool(CFrame.new(cx + 15, floorY, cz + 8), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildDesertPalmTree(CFrame.new(cx + 21, floorY, cz + 11), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildAcaciaTreeFlat(CFrame.new(cx + 17, floorY, cz - 9), 0.85, diorama)
		ClassicStudBiomeBuilder.BuildSandstoneMesaArch(CFrame.new(cx - 17, floorY, cz + 11) * CFrame.Angles(0, math.rad(15), 0), 0.8, diorama)
		ClassicStudBiomeBuilder.BuildSandstoneRuinedPillar(CFrame.new(cx + 4, floorY, cz - 11), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildSaguaroCactusGiant(CFrame.new(cx + 5, floorY, cz + 9), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildBarrelCactusCluster(CFrame.new(cx - 22, floorY, cz + 3), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildDesertSkullBone(CFrame.new(cx + 6, floorY, cz - 2), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildDesertBrazierTorch(CFrame.new(cx - 2, floorY, cz + 11), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildSavannaGrassTuft(CFrame.new(cx + 22, floorY, cz - 2), 1.05, diorama)
	elseif biomeId == "AlpinePeaks" then
		makeStudPart({ name = "GlacierIceRiver", size = Vector3.new(10, 0.28, 34), cframe = CFrame.new(cx, SHOWROOM_FLOOR_Y + 0.14, cz), color = meta.trailColor, castShadow = false, transparency = 0.15, parent = diorama })
		ClassicStudBiomeBuilder.BuildGiantIceCrystalSpire(CFrame.new(cx - 15, floorY, cz - 4), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildFrozenIceArchway(CFrame.new(cx, floorY, cz + 8), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildSnowyPineTreeTall(CFrame.new(cx + 17, floorY, cz + 9), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildSnowyPineTreeTwin(CFrame.new(cx - 19, floorY, cz + 10), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildFrostedBirchTree(CFrame.new(cx + 18, floorY, cz - 10), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildGlacierBoulderSnowy(CFrame.new(cx + 11, floorY, cz - 1), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildIceCrystalCluster(CFrame.new(cx - 10, floorY, cz + 10), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildFrozenHollowLog(CFrame.new(cx - 14, floorY, cz - 12) * CFrame.Angles(0, 0.4, 0), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildAlpineStoneCairn(CFrame.new(cx + 7.5, floorY, cz - 9), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildIceBerryBush(CFrame.new(cx + 22, floorY, cz - 2), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildFrostGrassTuft(CFrame.new(cx - 8, floorY, cz - 1), 1.05, diorama)
	elseif biomeId == "VolcanicJungle" then
		makeStudPart({ name = "MagmaLavaTrench", size = Vector3.new(11, 0.28, 34), cframe = CFrame.new(cx + 8, SHOWROOM_FLOOR_Y + 0.14, cz), color = meta.trailColor, material = Enum.Material.Neon, studded = false, castShadow = false, parent = diorama })
		makeStudPart({ name = "ObsidianBridge", size = Vector3.new(15, 0.55, 8), cframe = CFrame.new(cx + 8, SHOWROOM_FLOOR_Y + 0.28, cz), color = Color3.fromRGB(36, 30, 44), castShadow = false, parent = diorama })
		ClassicStudBiomeBuilder.BuildVolcanoCraterLandmark(CFrame.new(cx - 13, floorY, cz - 2), 0.78, diorama)
		ClassicStudBiomeBuilder.BuildObsidianMonolithRuins(CFrame.new(cx + 19, floorY, cz - 10), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildCharredCrimsonTree(CFrame.new(cx + 18, floorY, cz + 10), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildObsidianDeadTree(CFrame.new(cx - 21, floorY, cz + 11), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildMagmaPalmTree(CFrame.new(cx + 21, floorY, cz - 1), 0.92, diorama)
		ClassicStudBiomeBuilder.BuildMagmaVentGeyser(CFrame.new(cx - 6, floorY, cz + 11), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildLavaCrackedBoulder(CFrame.new(cx - 5, floorY, cz - 12), 0.9, diorama)
		ClassicStudBiomeBuilder.BuildCrimsonCrystalCluster(CFrame.new(cx + 15, floorY, cz - 3), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier(CFrame.new(cx + 1, floorY, cz + 10), 0.95, diorama)
		ClassicStudBiomeBuilder.BuildFirebloomFlowerPatch(CFrame.new(cx - 19, floorY, cz - 11), 1.0, diorama)
		ClassicStudBiomeBuilder.BuildAshEmberGrassTuft(CFrame.new(cx + 1, floorY, cz - 11), 1.05, diorama)
	end
end

local function populateCourtDressing(meta: any, courtDressing: Model)
	for _, xSide in ipairs({ meta.leftX, meta.rightX }) do
		makeStudPart({
			name = meta.id .. "_CourtWing_" .. tostring(xSide),
			size = Vector3.new(13, 0.1, 20),
			cframe = CFrame.new(xSide, SHOWROOM_FLOOR_Y + 0.05, meta.courtZ + 4),
			color = meta.lawnColor,
			castShadow = false,
			parent = courtDressing,
		})
	end
	local y = SHOWROOM_FLOOR_Y + 0.1
	local assets = meta.assets :: { AssetSpec }
	local lx, rx, zc = meta.leftX, meta.rightX, meta.courtZ
	if assets[1] then assets[1].build(CFrame.new(lx - 1.5, y, zc - 1) * CFrame.Angles(0, 0.3, 0), math.min(0.85, (assets[1].catalogScale or 0.7) * 1.15), courtDressing) end
	if assets[2] then assets[2].build(CFrame.new(rx + 1.5, y, zc + 1) * CFrame.Angles(0, -0.4, 0), math.min(0.85, (assets[2].catalogScale or 0.7) * 1.15), courtDressing) end
	if assets[5] then assets[5].build(CFrame.new(lx + 2.5, y, zc + 7), 0.95, courtDressing) end
	if assets[6] then assets[6].build(CFrame.new(rx - 2.0, y, zc - 3), 0.88, courtDressing) end
	if assets[10] then assets[10].build(CFrame.new(lx + 2.0, y, zc - 3), 0.85, courtDressing) end
	if assets[13] then assets[13].build(CFrame.new(rx - 2.0, y, zc + 9) * CFrame.Angles(0, math.pi, 0), 0.9, courtDressing) end
end

function ClassicStudBiomeBuilder.BuildAllBiomesShowroom(stageParent: Instance?): Folder
	ClassicStudBiomeBuilder.EnsureClassicStudsVariant()

	local old = Workspace:FindFirstChild("BiomeAssetShowroom")
	if old then
		old:Destroy()
	end
	if stageParent then
		local oldInsideStage = stageParent:FindFirstChild("BiomeAssetShowroom")
		if oldInsideStage then
			oldInsideStage:Destroy()
		end
	end

	local root = Instance.new("Folder")
	root.Name = "BiomeAssetShowroom"
	root.Parent = Workspace

	local catalogX = -100
	local dioramaX = -164

	for _, meta in ipairs(SHOWROOM_BIOME_META) do
		local biomeModel = Instance.new("Model")
		biomeModel.Name = meta.modelName

		-- A. Modular Asset Kit Catalog Bay (X = -100, Z = meta.bayZ)
		local catalogFolder = Instance.new("Folder")
		catalogFolder.Name = "ModularAssetCatalog"
		catalogFolder.Parent = biomeModel

		makeStudPart({
			name = meta.id .. "_CatalogLawn",
			size = Vector3.new(56, 0.14, 34),
			cframe = CFrame.new(catalogX, SHOWROOM_FLOOR_Y + 0.07, meta.bayZ),
			color = meta.lawnColor,
			castShadow = false,
			parent = catalogFolder,
		})
		makeStudPart({
			name = meta.id .. "_CatalogBorder",
			size = Vector3.new(57.2, 0.08, 35.2),
			cframe = CFrame.new(catalogX, SHOWROOM_FLOOR_Y + 0.04, meta.bayZ),
			color = meta.borderColor,
			castShadow = false,
			parent = catalogFolder,
		})
		buildCatalogSignBoard(meta.title .. " (KIT)", meta.subtitle, Vector3.new(catalogX, 13.4, meta.bayZ + 16.5), 50, meta.accent, catalogFolder)

		local floorTopY = SHOWROOM_FLOOR_Y + 0.14
		local rows = {
			{ cat = "Tree", z = meta.bayZ + 10.5 },
			{ cat = "Flora", z = meta.bayZ },
			{ cat = "Prop", z = meta.bayZ - 10.5 },
		}
		for _, r in ipairs(rows) do
			local items: { AssetSpec } = {}
			for _, spec in ipairs(meta.assets :: { AssetSpec }) do
				if spec.category == r.cat then
					table.insert(items, spec)
				end
			end
			local count = #items
			local spacing = if count > 1 then math.min(12.5, 44 / (count - 1)) else 0
			local startX = catalogX - ((count - 1) * spacing) * 0.5
			for i, spec in ipairs(items) do
				local px = startX + (i - 1) * spacing
				local yaw = math.rad(if i % 2 == 0 then 12 else -10)
				local asset = spec.build(CFrame.new(px, floorTopY, r.z) * CFrame.Angles(0, yaw, 0), spec.catalogScale or 0.9, catalogFolder)
				asset:SetAttribute("BiomeId", meta.id)
				asset:SetAttribute("Category", spec.category)
				attachCatalogLabel(asset, spec.title, spec.category, meta.accent)
			end
		end

		-- B. Composed Miniature Biome Diorama (X = -164, Z = meta.bayZ)
		local diorama = Instance.new("Model")
		diorama.Name = meta.id .. "_ComposedDiorama"
		diorama.Parent = biomeModel
		buildCatalogSignBoard(meta.title .. " (DIORAMA)", "Full Scene Composition • No Colliders", Vector3.new(dioramaX, 13.4, meta.bayZ + 16.5), 48, meta.accent, diorama)
		populateBiomeDiorama(meta.id, diorama, dioramaX, meta.bayZ, SHOWROOM_FLOOR_Y + 0.24, meta)

		-- C. Court Perimeter Dressing beside central Pet Lineup Zone
		local dressing = Instance.new("Model")
		dressing.Name = meta.id .. "_CourtPerimeterDressing"
		dressing.Parent = biomeModel
		populateCourtDressing(meta, dressing)

		biomeModel.Parent = root
		task.wait()
	end

	return root
end

function ClassicStudBiomeBuilder.BuildBiome1Showroom(stageParent: Instance?): Folder
	return ClassicStudBiomeBuilder.BuildAllBiomesShowroom(stageParent)
end

return ClassicStudBiomeBuilder
