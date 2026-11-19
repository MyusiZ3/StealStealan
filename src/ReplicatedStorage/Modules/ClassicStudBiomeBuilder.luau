--!strict
-- ClassicStudBiomeBuilder.luau
-- Generates Classic Studs Biome 1 (Whispering Pine Woods) modular environment assets
-- (trees, grass tufts, mossy turf, ferns, berry bushes, wildflowers, boulders, hollow logs,
-- stumps, mushrooms, ranger lanterns) and populates PetLab_Showroom with zero colliders (CanCollide = false).

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
	-- Strict no-collider rule: players pass cleanly through all biome environment assets
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

local function createBlock(m: Model, originCF: CFrame, s: number, name: string, size: Vector3, localCF: CFrame, color: Color3, mat: Enum.Material?, studded: boolean?)
	local pos = localCF.Position * s
	local rot = localCF - localCF.Position
	makeStudPart({
		name = name,
		size = size * s,
		cframe = originCF * CFrame.new(pos) * rot,
		color = color,
		material = mat,
		studded = studded,
		parent = m,
	})
end

-- ============================================================================
-- BIOME 1: WHISPERING PINE WOODS — TREES (4)
-- ============================================================================

-- 1. Tall 5-Tier Conical Voxel Pine Tree
function ClassicStudBiomeBuilder.BuildPineTreeTall(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("PineTreeTall", cframe, parent)

	local barkDark = Color3.fromRGB(92, 58, 36)
	local barkMid = Color3.fromRGB(110, 72, 46)
	local leafDeep = Color3.fromRGB(38, 102, 48)
	local leafMid = Color3.fromRGB(54, 134, 62)
	local leafBright = Color3.fromRGB(78, 166, 76)

	-- Stepped root buttresses
	for idx, off in ipairs({
		Vector3.new(1.1, 0.45, 0),
		Vector3.new(-1.1, 0.45, 0),
		Vector3.new(0, 0.45, 1.1),
		Vector3.new(0, 0.45, -1.1),
	}) do
		createBlock(m, cframe, s, "Root_" .. idx, Vector3.new(1.3, 0.9, 1.3), CFrame.new(off), barkDark)
	end

	-- Main timber trunk
	createBlock(m, cframe, s, "TrunkLower", Vector3.new(1.8, 5.5, 1.8), CFrame.new(0, 2.75, 0), barkMid)
	createBlock(m, cframe, s, "TrunkUpper", Vector3.new(1.3, 9.0, 1.3), CFrame.new(0, 8.8, 0), barkDark)

	-- 5 stepped foliage tiers with crisp stud highlights
	local tiers = {
		{ y = 5.4, w = 8.4, h = 2.1, col = leafDeep },
		{ y = 7.7, w = 6.9, h = 2.0, col = leafMid },
		{ y = 9.9, w = 5.4, h = 1.9, col = leafDeep },
		{ y = 12.0, w = 3.9, h = 1.8, col = leafBright },
		{ y = 13.9, w = 2.3, h = 1.7, col = leafMid },
	}
	for idx, t in ipairs(tiers) do
		createBlock(m, cframe, s, "FoliageTier_" .. idx, Vector3.new(t.w, t.h, t.w), CFrame.new(0, t.y, 0), t.col)
		if idx < 5 then
			createBlock(
				m,
				cframe,
				s,
				"FoliageCrownCap_" .. idx,
				Vector3.new(t.w - 1.1, 0.55, t.w - 1.1),
				CFrame.new(0, t.y + t.h * 0.5 + 0.25, 0),
				leafBright
			)
		end
	end
	createBlock(m, cframe, s, "PineTipSpire", Vector3.new(1.1, 1.4, 1.1), CFrame.new(0, 15.3, 0), leafBright)
	return m
end

-- 2. Asymmetric Twin-Trunk Pine Cluster
function ClassicStudBiomeBuilder.BuildPineTreeTwin(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("PineTreeTwin", cframe, parent)

	local bark = Color3.fromRGB(98, 64, 42)
	local barkShade = Color3.fromRGB(80, 52, 34)
	local pineA = Color3.fromRGB(44, 118, 56)
	local pineB = Color3.fromRGB(66, 150, 72)

	-- Primary pine slightly off-center
	createBlock(m, cframe, s, "MainTrunk", Vector3.new(1.6, 8.2, 1.6), CFrame.new(-0.9, 4.1, -0.3), bark)
	createBlock(m, cframe, s, "MainRoot", Vector3.new(2.6, 0.8, 2.6), CFrame.new(-0.9, 0.4, -0.3), barkShade)
	for idx, t in ipairs({
		{ y = 5.2, w = 6.8, h = 1.8, col = pineA },
		{ y = 7.2, w = 5.2, h = 1.7, col = pineB },
		{ y = 9.0, w = 3.6, h = 1.6, col = pineA },
		{ y = 10.6, w = 2.0, h = 1.4, col = pineB },
	}) do
		createBlock(m, cframe, s, "MainTier_" .. idx, Vector3.new(t.w, t.h, t.w), CFrame.new(-0.9, t.y, -0.3), t.col)
	end

	-- Companion younger pine beside it
	createBlock(m, cframe, s, "SideTrunk", Vector3.new(1.2, 5.4, 1.2), CFrame.new(2.2, 2.7, 1.1), barkShade)
	for idx, t in ipairs({
		{ y = 3.7, w = 4.6, h = 1.5, col = pineB },
		{ y = 5.3, w = 3.3, h = 1.4, col = pineA },
		{ y = 6.7, w = 1.9, h = 1.2, col = pineB },
	}) do
		createBlock(m, cframe, s, "SideTier_" .. idx, Vector3.new(t.w, t.h, t.w), CFrame.new(2.2, t.y, 1.1), t.col)
	end
	return m
end

-- 3. Broad Blocky Forest Oak Tree
function ClassicStudBiomeBuilder.BuildOakTreeBroad(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("OakTreeBroad", cframe, parent)

	local bark = Color3.fromRGB(116, 74, 44)
	local barkDeep = Color3.fromRGB(92, 58, 34)
	local oakDark = Color3.fromRGB(56, 134, 52)
	local oakMid = Color3.fromRGB(78, 168, 64)
	local oakBright = Color3.fromRGB(108, 194, 78)

	createBlock(m, cframe, s, "OakRootBase", Vector3.new(3.4, 1.0, 3.4), CFrame.new(0, 0.5, 0), barkDeep)
	createBlock(m, cframe, s, "OakTrunk", Vector3.new(2.2, 5.8, 2.2), CFrame.new(0, 3.3, 0), bark)
	createBlock(m, cframe, s, "OakBranchL", Vector3.new(2.8, 1.1, 1.2), CFrame.new(-1.8, 5.6, 0.2) * CFrame.Angles(0, 0, math.rad(-18)), barkDeep)
	createBlock(m, cframe, s, "OakBranchR", Vector3.new(2.6, 1.1, 1.2), CFrame.new(1.7, 5.3, -0.3) * CFrame.Angles(0, 0, math.rad(16)), barkDeep)

	-- Clustered rounded voxel foliage blocks
	createBlock(m, cframe, s, "CanopyCore", Vector3.new(7.4, 4.2, 7.4), CFrame.new(0, 7.6, 0), oakDark)
	createBlock(m, cframe, s, "CanopyMid", Vector3.new(8.8, 2.6, 6.6), CFrame.new(0, 7.9, 0), oakMid)
	createBlock(m, cframe, s, "CanopyCross", Vector3.new(6.6, 2.6, 8.8), CFrame.new(0, 7.9, 0), oakMid)
	createBlock(m, cframe, s, "CanopyUpper", Vector3.new(5.6, 2.0, 5.6), CFrame.new(0, 10.3, 0), oakBright)
	createBlock(m, cframe, s, "CanopyCrown", Vector3.new(3.2, 1.2, 3.2), CFrame.new(0.4, 11.7, -0.3), oakBright)
	return m
end

-- 4. Classic Stud White Birch Tree
function ClassicStudBiomeBuilder.BuildBirchTreeForest(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("BirchTreeForest", cframe, parent)

	local birchWhite = Color3.fromRGB(234, 232, 224)
	local birchSpot = Color3.fromRGB(54, 56, 60)
	local leafLime = Color3.fromRGB(116, 198, 72)
	local leafLeaf = Color3.fromRGB(88, 168, 58)

	createBlock(m, cframe, s, "BirchBase", Vector3.new(1.8, 0.7, 1.8), CFrame.new(0, 0.35, 0), birchSpot)
	createBlock(m, cframe, s, "BirchTrunk", Vector3.new(1.25, 7.2, 1.25), CFrame.new(0, 3.8, 0), birchWhite)
	for idx, by in ipairs({ 1.6, 3.0, 4.4, 5.8 }) do
		createBlock(
			m,
			cframe,
			s,
			"BarkStripe_" .. idx,
			Vector3.new(1.32, 0.38, 1.32),
			CFrame.new(0, by, 0),
			birchSpot
		)
	end

	createBlock(m, cframe, s, "BirchLeavesLow", Vector3.new(6.0, 2.5, 6.0), CFrame.new(0, 8.2, 0), leafLeaf)
	createBlock(m, cframe, s, "BirchLeavesSide", Vector3.new(7.0, 1.9, 4.6), CFrame.new(0.3, 8.7, 0.2), leafLime)
	createBlock(m, cframe, s, "BirchLeavesTop", Vector3.new(4.4, 2.0, 4.4), CFrame.new(-0.2, 10.3, 0), leafLime)
	return m
end

-- ============================================================================
-- BIOME 1: GRASS, BUSHES & FOREST FLORA (5)
-- ============================================================================

-- 5. 3D Studded Grass Tuft Cluster
function ClassicStudBiomeBuilder.BuildGrassTuftCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("GrassTuftCluster", cframe, parent)

	local gDeep = Color3.fromRGB(72, 152, 62)
	local gMid = Color3.fromRGB(98, 184, 74)
	local gTip = Color3.fromRGB(130, 212, 88)

	createBlock(m, cframe, s, "TurfPad", Vector3.new(3.2, 0.22, 3.2), CFrame.new(0, 0.11, 0), gDeep)
	local blades = {
		{ pos = Vector3.new(-0.85, 0.85, -0.5), sz = Vector3.new(0.45, 1.6, 0.45), tilt = Vector3.new(-10, 15, 12), col = gMid },
		{ pos = Vector3.new(-0.15, 1.15, 0.1), sz = Vector3.new(0.48, 2.2, 0.48), tilt = Vector3.new(6, -10, -5), col = gTip },
		{ pos = Vector3.new(0.75, 0.95, -0.35), sz = Vector3.new(0.42, 1.8, 0.42), tilt = Vector3.new(-8, 28, -14), col = gMid },
		{ pos = Vector3.new(0.3, 0.75, 0.85), sz = Vector3.new(0.44, 1.4, 0.44), tilt = Vector3.new(14, -20, 8), col = gTip },
		{ pos = Vector3.new(-0.65, 0.7, 0.7), sz = Vector3.new(0.4, 1.3, 0.4), tilt = Vector3.new(12, 18, 10), col = gDeep },
		{ pos = Vector3.new(0.95, 0.65, 0.65), sz = Vector3.new(0.38, 1.2, 0.38), tilt = Vector3.new(9, 40, -12), col = gTip },
	}
	for idx, b in ipairs(blades) do
		local ang = CFrame.Angles(math.rad(b.tilt.X), math.rad(b.tilt.Y), math.rad(b.tilt.Z))
		createBlock(m, cframe, s, "Blade_" .. idx, b.sz, CFrame.new(b.pos) * ang, b.col)
	end
	return m
end

-- 6. Stepped Mossy Turf Ground Patch
function ClassicStudBiomeBuilder.BuildMossyTurfPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MossyTurfPatch", cframe, parent)

	createBlock(m, cframe, s, "MossBase", Vector3.new(6.8, 0.28, 6.2), CFrame.new(0, 0.14, 0), Color3.fromRGB(78, 152, 66))
	createBlock(m, cframe, s, "MossLayerMid", Vector3.new(4.6, 0.36, 4.2), CFrame.new(-0.5, 0.36, 0.3), Color3.fromRGB(98, 182, 74))
	createBlock(m, cframe, s, "MossLayerTop", Vector3.new(2.4, 0.32, 2.2), CFrame.new(-0.8, 0.62, 0.2), Color3.fromRGB(124, 206, 86))
	createBlock(m, cframe, s, "CloverPad", Vector3.new(2.1, 0.26, 2.3), CFrame.new(1.5, 0.32, -1.1), Color3.fromRGB(112, 194, 78))
	createBlock(m, cframe, s, "PebbleA", Vector3.new(0.8, 0.45, 0.8), CFrame.new(1.8, 0.42, 1.2), Color3.fromRGB(142, 146, 152))
	createBlock(m, cframe, s, "PebbleB", Vector3.new(0.55, 0.35, 0.55), CFrame.new(2.4, 0.35, 0.6), Color3.fromRGB(164, 168, 174))
	return m
end

-- 7. Radial Classic Stud Forest Fern
function ClassicStudBiomeBuilder.BuildFernCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FernCluster", cframe, parent)

	local fernCore = Color3.fromRGB(48, 126, 56)
	local fernLeaf = Color3.fromRGB(76, 168, 68)
	local fernTip = Color3.fromRGB(108, 198, 82)

	createBlock(m, cframe, s, "FernHub", Vector3.new(1.2, 0.7, 1.2), CFrame.new(0, 0.35, 0), fernCore)
	for idx = 0, 5 do
		local yaw = math.rad(idx * 60)
		local frondCF = CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.75, 1.2) * CFrame.Angles(math.rad(22), 0, 0)
		createBlock(m, cframe, s, "FrondBase_" .. idx, Vector3.new(0.7, 0.28, 1.9), frondCF, fernLeaf)
		local tipCF = CFrame.Angles(0, yaw, 0) * CFrame.new(0, 1.05, 2.25) * CFrame.Angles(math.rad(-8), 0, 0)
		createBlock(m, cframe, s, "FrondTip_" .. idx, Vector3.new(0.5, 0.24, 1.1), tipCF, fernTip)
	end
	return m
end

-- 8. Forest Berry Bush
function ClassicStudBiomeBuilder.BuildBerryBush(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("BerryBush", cframe, parent)

	local bushDeep = Color3.fromRGB(46, 118, 48)
	local bushBright = Color3.fromRGB(72, 158, 62)
	local berryRed = Color3.fromRGB(224, 54, 66)
	local berryBlue = Color3.fromRGB(64, 148, 242)

	createBlock(m, cframe, s, "BushCore", Vector3.new(3.6, 2.2, 3.6), CFrame.new(0, 1.1, 0), bushDeep)
	createBlock(m, cframe, s, "BushSideL", Vector3.new(2.2, 1.6, 2.4), CFrame.new(-1.3, 0.8, 0.3), bushBright)
	createBlock(m, cframe, s, "BushSideR", Vector3.new(2.2, 1.5, 2.2), CFrame.new(1.2, 0.75, -0.4), bushBright)
	createBlock(m, cframe, s, "BushTop", Vector3.new(2.3, 1.2, 2.3), CFrame.new(0, 2.4, 0), bushBright)

	local berries = {
		{ pos = Vector3.new(-1.85, 1.35, 0.6), col = berryRed },
		{ pos = Vector3.new(-0.7, 1.75, 1.85), col = berryBlue },
		{ pos = Vector3.new(1.1, 1.95, 1.65), col = berryRed },
		{ pos = Vector3.new(1.85, 1.15, -0.6), col = berryBlue },
		{ pos = Vector3.new(-0.3, 2.75, -1.15), col = berryRed },
		{ pos = Vector3.new(0.9, 2.25, -1.75), col = berryRed },
	}
	for idx, b in ipairs(berries) do
		createBlock(m, cframe, s, "Berry_" .. idx, Vector3.new(0.45, 0.45, 0.45), CFrame.new(b.pos), b.col)
	end
	return m
end

-- 9. Woodland Wildflower Patch
function ClassicStudBiomeBuilder.BuildWildflowerPatch(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("WildflowerPatch", cframe, parent)

	createBlock(m, cframe, s, "FlowerTurf", Vector3.new(3.8, 0.2, 3.8), CFrame.new(0, 0.1, 0), Color3.fromRGB(90, 174, 72))
	local flowers = {
		{ x = -1.0, z = -0.8, h = 1.1, petal = Color3.fromRGB(255, 214, 62), center = Color3.fromRGB(218, 128, 32) },
		{ x = 0.8, z = -0.9, h = 1.35, petal = Color3.fromRGB(244, 246, 250), center = Color3.fromRGB(255, 206, 56) },
		{ x = 0.1, z = 0.3, h = 1.5, petal = Color3.fromRGB(94, 186, 255), center = Color3.fromRGB(246, 248, 255) },
		{ x = -0.7, z = 1.0, h = 1.0, petal = Color3.fromRGB(255, 118, 152), center = Color3.fromRGB(255, 224, 92) },
		{ x = 1.1, z = 0.8, h = 1.2, petal = Color3.fromRGB(255, 214, 62), center = Color3.fromRGB(218, 128, 32) },
	}
	for idx, fl in ipairs(flowers) do
		createBlock(m, cframe, s, "Stem_" .. idx, Vector3.new(0.22, fl.h, 0.22), CFrame.new(fl.x, fl.h * 0.5 + 0.15, fl.z), Color3.fromRGB(64, 148, 56))
		createBlock(m, cframe, s, "Leaf_" .. idx, Vector3.new(0.55, 0.18, 0.25), CFrame.new(fl.x + 0.22, fl.h * 0.45 + 0.15, fl.z), Color3.fromRGB(88, 178, 68))
		createBlock(m, cframe, s, "Petals_" .. idx, Vector3.new(0.82, 0.22, 0.82), CFrame.new(fl.x, fl.h + 0.24, fl.z), fl.petal)
		createBlock(m, cframe, s, "Core_" .. idx, Vector3.new(0.38, 0.28, 0.38), CFrame.new(fl.x, fl.h + 0.34, fl.z), fl.center)
	end
	return m
end

-- ============================================================================
-- BIOME 1: ROCKS, WOOD & FOREST PROPS (6)
-- ============================================================================

-- 10. Multi-Tiered Mossy Boulder
function ClassicStudBiomeBuilder.BuildMossyBoulder(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MossyBoulder", cframe, parent)

	local stoneDark = Color3.fromRGB(108, 114, 122)
	local stoneLight = Color3.fromRGB(134, 140, 148)
	local mossCol = Color3.fromRGB(82, 164, 68)
	local mossTip = Color3.fromRGB(108, 192, 78)

	createBlock(m, cframe, s, "BoulderBase", Vector3.new(5.2, 2.2, 4.6), CFrame.new(0, 1.1, 0), stoneDark)
	createBlock(m, cframe, s, "BoulderMid", Vector3.new(3.8, 1.6, 3.6), CFrame.new(-0.3, 2.7, 0.2), stoneLight)
	createBlock(m, cframe, s, "BoulderLedge", Vector3.new(2.2, 1.3, 2.6), CFrame.new(1.8, 0.65, -0.8), stoneLight)
	createBlock(m, cframe, s, "MossCapMain", Vector3.new(3.9, 0.42, 3.7), CFrame.new(-0.3, 3.65, 0.2), mossCol)
	createBlock(m, cframe, s, "MossCapSide", Vector3.new(2.1, 0.35, 2.3), CFrame.new(1.75, 1.42, -0.8), mossTip)
	return m
end

-- 11. Low Forest Rock Trio
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

-- 12. Fallen Hollow Log with Moss & Shelf Mushrooms
function ClassicStudBiomeBuilder.BuildFallenHollowLog(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("FallenHollowLog", cframe, parent)

	local bark = Color3.fromRGB(106, 68, 40)
	local barkDark = Color3.fromRGB(82, 52, 30)
	local heartWood = Color3.fromRGB(194, 156, 102)
	local moss = Color3.fromRGB(88, 172, 68)

	createBlock(m, cframe, s, "LogBody", Vector3.new(6.8, 1.9, 2.0), CFrame.new(0, 0.95, 0), bark)
	createBlock(m, cframe, s, "LogBarkRidge", Vector3.new(5.2, 0.35, 2.2), CFrame.new(-0.3, 0.5, 0), barkDark)
	createBlock(m, cframe, s, "LogCoreL", Vector3.new(0.24, 1.35, 1.45), CFrame.new(-3.36, 0.95, 0), heartWood)
	createBlock(m, cframe, s, "LogCoreR", Vector3.new(0.24, 1.35, 1.45), CFrame.new(3.36, 0.95, 0), heartWood)
	createBlock(m, cframe, s, "LogMossStripA", Vector3.new(2.8, 0.3, 1.4), CFrame.new(-1.1, 2.0, 0.1), moss)
	createBlock(m, cframe, s, "LogMossStripB", Vector3.new(1.7, 0.28, 1.2), CFrame.new(1.8, 1.98, -0.15), moss)
	-- Shelf mushrooms on the side
	createBlock(m, cframe, s, "ShelfShroomA", Vector3.new(0.8, 0.22, 0.7), CFrame.new(-0.6, 1.2, 1.15), Color3.fromRGB(238, 198, 128))
	createBlock(m, cframe, s, "ShelfShroomB", Vector3.new(0.65, 0.2, 0.55), CFrame.new(0.25, 0.95, 1.12), Color3.fromRGB(224, 176, 104))
	return m
end

-- 13. Cut Pine Tree Stump
function ClassicStudBiomeBuilder.BuildTreeStump(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("TreeStump", cframe, parent)

	local bark = Color3.fromRGB(108, 68, 42)
	local barkDark = Color3.fromRGB(84, 52, 32)
	local innerWood = Color3.fromRGB(208, 172, 114)

	createBlock(m, cframe, s, "StumpRoots", Vector3.new(3.2, 0.65, 3.2), CFrame.new(0, 0.32, 0), barkDark)
	createBlock(m, cframe, s, "StumpBody", Vector3.new(2.3, 1.75, 2.3), CFrame.new(0, 1.0, 0), bark)
	createBlock(m, cframe, s, "StumpCore", Vector3.new(1.75, 0.2, 1.75), CFrame.new(0, 1.92, 0), innerWood)
	createBlock(m, cframe, s, "StumpRing", Vector3.new(0.85, 0.24, 0.85), CFrame.new(0, 1.94, 0), Color3.fromRGB(184, 144, 88))
	createBlock(m, cframe, s, "SproutStem", Vector3.new(0.28, 0.9, 0.28), CFrame.new(1.25, 1.15, 0.2), Color3.fromRGB(72, 158, 58))
	createBlock(m, cframe, s, "SproutLeaf", Vector3.new(0.85, 0.25, 0.65), CFrame.new(1.5, 1.65, 0.2), Color3.fromRGB(110, 198, 82))
	return m
end

-- 14. Forest Toadstool Mushroom Trio
function ClassicStudBiomeBuilder.BuildMushroomCluster(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("MushroomCluster", cframe, parent)

	local stemCol = Color3.fromRGB(238, 228, 206)
	local capRed = Color3.fromRGB(218, 56, 56)
	local spotCol = Color3.fromRGB(248, 246, 240)

	local shrooms = {
		{ x = 0, z = 0, stemH = 1.25, stemW = 0.52, capW = 1.55, capH = 0.62 },
		{ x = -0.95, z = 0.65, stemH = 0.85, stemW = 0.38, capW = 1.1, capH = 0.45 },
		{ x = 0.9, z = -0.55, stemH = 0.65, stemW = 0.32, capW = 0.9, capH = 0.38 },
	}
	for idx, sh in ipairs(shrooms) do
		createBlock(m, cframe, s, "Stem_" .. idx, Vector3.new(sh.stemW, sh.stemH, sh.stemW), CFrame.new(sh.x, sh.stemH * 0.5, sh.z), stemCol)
		createBlock(m, cframe, s, "Cap_" .. idx, Vector3.new(sh.capW, sh.capH, sh.capW), CFrame.new(sh.x, sh.stemH + sh.capH * 0.45, sh.z), capRed)
		createBlock(
			m,
			cframe,
			s,
			"CapTop_" .. idx,
			Vector3.new(sh.capW * 0.65, 0.22, sh.capW * 0.65),
			CFrame.new(sh.x, sh.stemH + sh.capH * 0.9 + 0.08, sh.z),
			capRed
		)
		createBlock(
			m,
			cframe,
			s,
			"Spot_" .. idx,
			Vector3.new(sh.capW * 0.25, 0.14, sh.capW * 0.25),
			CFrame.new(sh.x + sh.capW * 0.16, sh.stemH + sh.capH * 1.05, sh.z - sh.capW * 0.12),
			spotCol
		)
	end
	return m
end

-- 15. Woodland Ranger Lantern Post
function ClassicStudBiomeBuilder.BuildRangerLanternPost(cframe: CFrame, scale: number?, parent: Instance?): Model
	local s = scale or 1
	local m = newAssetModel("RangerLanternPost", cframe, parent)

	local wood = Color3.fromRGB(112, 72, 42)
	local iron = Color3.fromRGB(48, 54, 64)
	local glow = Color3.fromRGB(255, 206, 94)

	createBlock(m, cframe, s, "PostFooting", Vector3.new(1.5, 0.6, 1.5), CFrame.new(0, 0.3, 0), Color3.fromRGB(118, 124, 132))
	createBlock(m, cframe, s, "PostShaft", Vector3.new(0.85, 6.2, 0.85), CFrame.new(0, 3.4, 0), wood)
	createBlock(m, cframe, s, "CrossArm", Vector3.new(2.2, 0.55, 0.65), CFrame.new(0.85, 6.1, 0), wood)
	createBlock(m, cframe, s, "LanternCap", Vector3.new(1.3, 0.35, 1.3), CFrame.new(1.65, 5.45, 0), iron)
	createBlock(m, cframe, s, "LanternGlow", Vector3.new(0.9, 1.0, 0.9), CFrame.new(1.65, 4.78, 0), glow, Enum.Material.Neon, false)
	createBlock(m, cframe, s, "LanternBase", Vector3.new(1.15, 0.28, 1.15), CFrame.new(1.65, 4.18, 0), iron)
	return m
end

ClassicStudBiomeBuilder.BIOME_1_ASSETS = {
	{ id = "PineTreeTall", title = "Pine Tree (Tall)", category = "Tree", build = ClassicStudBiomeBuilder.BuildPineTreeTall },
	{ id = "PineTreeTwin", title = "Pine Tree (Twin)", category = "Tree", build = ClassicStudBiomeBuilder.BuildPineTreeTwin },
	{ id = "OakTreeBroad", title = "Oak Tree (Broad)", category = "Tree", build = ClassicStudBiomeBuilder.BuildOakTreeBroad },
	{ id = "BirchTreeForest", title = "Birch Tree", category = "Tree", build = ClassicStudBiomeBuilder.BuildBirchTreeForest },
	{ id = "GrassTuftCluster", title = "Grass Tufts 3D", category = "Flora", build = ClassicStudBiomeBuilder.BuildGrassTuftCluster },
	{ id = "MossyTurfPatch", title = "Mossy Turf Patch", category = "Flora", build = ClassicStudBiomeBuilder.BuildMossyTurfPatch },
	{ id = "FernCluster", title = "Forest Ferns", category = "Flora", build = ClassicStudBiomeBuilder.BuildFernCluster },
	{ id = "BerryBush", title = "Berry Bush", category = "Flora", build = ClassicStudBiomeBuilder.BuildBerryBush },
	{ id = "WildflowerPatch", title = "Wildflowers", category = "Flora", build = ClassicStudBiomeBuilder.BuildWildflowerPatch },
	{ id = "MossyBoulder", title = "Mossy Boulder", category = "Prop", build = ClassicStudBiomeBuilder.BuildMossyBoulder },
	{ id = "RockCluster", title = "Forest Rock Trio", category = "Prop", build = ClassicStudBiomeBuilder.BuildRockCluster },
	{ id = "FallenHollowLog", title = "Fallen Hollow Log", category = "Prop", build = ClassicStudBiomeBuilder.BuildFallenHollowLog },
	{ id = "TreeStump", title = "Cut Tree Stump", category = "Prop", build = ClassicStudBiomeBuilder.BuildTreeStump },
	{ id = "MushroomCluster", title = "Toadstool Trio", category = "Prop", build = ClassicStudBiomeBuilder.BuildMushroomCluster },
	{ id = "RangerLanternPost", title = "Ranger Lantern Post", category = "Prop", build = ClassicStudBiomeBuilder.BuildRangerLanternPost },
} :: { AssetSpec }

local function attachCatalogLabel(model: Model, title: string, category: string)
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
		cframe = CFrame.new(cf.Position.X, cf.Position.Y + sz.Y * 0.5 + 1.4, cf.Position.Z),
		color = Color3.new(1, 1, 1),
		studded = false,
		transparency = 1,
		castShadow = false,
		parent = model,
	})

	local bb = Instance.new("BillboardGui")
	bb.Name = "AssetCatalogTag"
	bb.Size = UDim2.new(6.8, 0, 1.8, 0)
	bb.MaxDistance = 85
	bb.Parent = anchor

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(16, 26, 20)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Parent = bb
	Instance.new("UICorner", card).CornerRadius = UDim.new(0.2, 0)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(92, 218, 122)
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
	sLbl.TextColor3 = Color3.fromRGB(122, 236, 148)
	sLbl.Text = string.format("[%s • CLASSIC STUDS • %d Parts • NoCollide]", string.upper(category), partCount)
	sLbl.Parent = card
end

local function buildCatalogSignBoard(title: string, subText: string, pos: Vector3, width: number, parent: Instance)
	local board = makeStudPart({
		name = "BiomeShowroomHeaderBoard",
		size = Vector3.new(width, 4.2, 0.45),
		cframe = CFrame.new(pos) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(22, 34, 26),
		studded = false,
		castShadow = false,
		parent = parent,
	})
	makeStudPart({
		name = "BoardAccentTrim",
		size = Vector3.new(width + 0.4, 0.25, 0.5),
		cframe = CFrame.new(pos + Vector3.new(0, 2.15, 0)),
		color = Color3.fromRGB(92, 218, 122),
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
		bg.BackgroundColor3 = Color3.fromRGB(18, 30, 22)
		bg.BorderSizePixel = 0
		bg.Parent = sg

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(0.96, 0, 0.54, 0)
		t.Position = UDim2.new(0.02, 0, 0.06, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(118, 240, 146)
		t.Text = title
		t.Parent = bg

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.96, 0, 0.30, 0)
		sub.Position = UDim2.new(0.02, 0, 0.64, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(220, 238, 226)
		sub.Text = subText
		sub.Parent = bg
	end
end

function ClassicStudBiomeBuilder.BuildBiome1Showroom(stageParent: Instance?): Folder
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

	local b1 = Instance.new("Model")
	b1.Name = "Biome1_PineWoods_Showroom"
	b1.Parent = root

	-- A. Modular Asset Kit Catalog (West Courtyard X = -128 .. -72, Z = -28 .. -90)
	-- Note: TreadmillCollection occupies X = -124..-82, Z = -17..+37, so Z <= -28 keeps clean clearance.
	local catalogFolder = Instance.new("Folder")
	catalogFolder.Name = "ModularAssetCatalog"
	catalogFolder.Parent = b1

	local lawnCenterX = -100
	local lawnWidth = 60
	makeStudPart({
		name = "Biome1CatalogLawn",
		size = Vector3.new(lawnWidth, 0.14, 62),
		cframe = CFrame.new(lawnCenterX, SHOWROOM_FLOOR_Y + 0.07, -59),
		color = Color3.fromRGB(86, 158, 74),
		castShadow = false,
		parent = catalogFolder,
	})
	makeStudPart({
		name = "Biome1CatalogBorder",
		size = Vector3.new(lawnWidth + 1.4, 0.08, 63.4),
		cframe = CFrame.new(lawnCenterX, SHOWROOM_FLOOR_Y + 0.04, -59),
		color = Color3.fromRGB(58, 122, 54),
		castShadow = false,
		parent = catalogFolder,
	})

	buildCatalogSignBoard(
		"BIOME 1 • WHISPERING PINE WOODS (CLASSIC STUDS KIT)",
		"Trees • Grass Tufts • Ferns • Berry Bushes • Wildflowers • Mossy Rocks • Logs • No Colliders",
		Vector3.new(lawnCenterX, 11.5, -92),
		54,
		catalogFolder
	)

	local floorTopY = SHOWROOM_FLOOR_Y + 0.14
	local rowSpecs = {
		{ category = "Tree", z = -40, xs = { -118, -106, -94, -82 }, scale = 0.88 },
		{ category = "Flora", z = -58, xs = { -120, -110, -100, -90, -80 }, scale = 1.05 },
		{ category = "Prop", z = -76, xs = { -121, -112.5, -104, -95.5, -87, -78.5 }, scale = 1.0 },
	}
	for _, r in ipairs(rowSpecs) do
		local slotIdx = 0
		for _, spec in ipairs(ClassicStudBiomeBuilder.BIOME_1_ASSETS) do
			if spec.category == r.category then
				slotIdx += 1
				local xPos = r.xs[slotIdx]
				if xPos then
					local cf = CFrame.new(xPos, floorTopY, r.z) * CFrame.Angles(0, math.rad((slotIdx % 2 == 0) and 12 or -10), 0)
					local asset = spec.build(cf, r.scale, catalogFolder)
					asset:SetAttribute("BiomeId", "PineWoods")
					asset:SetAttribute("Category", spec.category)
					attachCatalogLabel(asset, spec.title, spec.category)
				end
			end
		end
	end

	-- B. Composed Biome 1 Forest Diorama Slice (X = -128 .. -72, Z = -96 .. -142)
	local diorama = Instance.new("Model")
	diorama.Name = "Biome1_ComposedDiorama"
	diorama.Parent = b1

	local dioCenterZ = -119
	makeStudPart({
		name = "DioramaBaseGrass",
		size = Vector3.new(58, 0.24, 44),
		cframe = CFrame.new(lawnCenterX, SHOWROOM_FLOOR_Y + 0.12, dioCenterZ),
		color = Color3.fromRGB(86, 158, 74),
		castShadow = false,
		parent = diorama,
	})
	makeStudPart({
		name = "DioramaDirtTrail",
		size = Vector3.new(10, 0.30, 44),
		cframe = CFrame.new(lawnCenterX, SHOWROOM_FLOOR_Y + 0.15, dioCenterZ),
		color = Color3.fromRGB(134, 102, 72),
		castShadow = false,
		parent = diorama,
	})
	makeStudPart({
		name = "DioramaTrailCurbL",
		size = Vector3.new(1.2, 0.34, 44),
		cframe = CFrame.new(lawnCenterX - 5.4, SHOWROOM_FLOOR_Y + 0.17, dioCenterZ),
		color = Color3.fromRGB(108, 82, 58),
		castShadow = false,
		parent = diorama,
	})
	makeStudPart({
		name = "DioramaTrailCurbR",
		size = Vector3.new(1.2, 0.34, 44),
		cframe = CFrame.new(lawnCenterX + 5.4, SHOWROOM_FLOOR_Y + 0.17, dioCenterZ),
		color = Color3.fromRGB(108, 82, 58),
		castShadow = false,
		parent = diorama,
	})
	makeStudPart({
		name = "DioramaMossClearing",
		size = Vector3.new(18, 0.36, 16),
		cframe = CFrame.new(lawnCenterX - 16, SHOWROOM_FLOOR_Y + 0.18, dioCenterZ - 6),
		color = Color3.fromRGB(108, 188, 80),
		castShadow = false,
		parent = diorama,
	})

	local dFloorY = SHOWROOM_FLOOR_Y + 0.24
	ClassicStudBiomeBuilder.BuildPineTreeTall(CFrame.new(lawnCenterX - 20, dFloorY, -104) * CFrame.Angles(0, 0.3, 0), 1.05, diorama)
	ClassicStudBiomeBuilder.BuildPineTreeTwin(CFrame.new(lawnCenterX + 19, dFloorY, -106) * CFrame.Angles(0, -0.5, 0), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildOakTreeBroad(CFrame.new(lawnCenterX - 19, dFloorY + 0.12, -126) * CFrame.Angles(0, 0.8, 0), 0.95, diorama)
	ClassicStudBiomeBuilder.BuildBirchTreeForest(CFrame.new(lawnCenterX + 18, dFloorY, -131) * CFrame.Angles(0, -0.4, 0), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildPineTreeTall(CFrame.new(lawnCenterX - 11, dFloorY, -135) * CFrame.Angles(0, 1.1, 0), 0.92, diorama)

	ClassicStudBiomeBuilder.BuildRangerLanternPost(CFrame.new(lawnCenterX - 7.5, dFloorY, -105) * CFrame.Angles(0, math.rad(15), 0), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildRangerLanternPost(CFrame.new(lawnCenterX + 7.5, dFloorY, -128) * CFrame.Angles(0, math.rad(195), 0), 1.0, diorama)

	ClassicStudBiomeBuilder.BuildMossyBoulder(CFrame.new(lawnCenterX + 14, dFloorY, -118) * CFrame.Angles(0, 0.4, 0), 0.95, diorama)
	ClassicStudBiomeBuilder.BuildFallenHollowLog(CFrame.new(lawnCenterX - 14, dFloorY, -114) * CFrame.Angles(0, math.rad(32), 0), 0.95, diorama)
	ClassicStudBiomeBuilder.BuildTreeStump(CFrame.new(lawnCenterX + 11, dFloorY, -109) * CFrame.Angles(0, 0.6, 0), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildRockCluster(CFrame.new(lawnCenterX - 9, dFloorY, -128), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildMushroomCluster(CFrame.new(lawnCenterX - 10.5, dFloorY + 0.12, -119), 1.05, diorama)
	ClassicStudBiomeBuilder.BuildBerryBush(CFrame.new(lawnCenterX + 12, dFloorY, -134), 1.05, diorama)
	ClassicStudBiomeBuilder.BuildBerryBush(CFrame.new(lawnCenterX - 24, dFloorY, -116), 0.95, diorama)
	ClassicStudBiomeBuilder.BuildWildflowerPatch(CFrame.new(lawnCenterX + 9, dFloorY, -102), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildWildflowerPatch(CFrame.new(lawnCenterX - 10, dFloorY, -102), 1.0, diorama)
	ClassicStudBiomeBuilder.BuildFernCluster(CFrame.new(lawnCenterX + 22, dFloorY, -122), 1.1, diorama)
	ClassicStudBiomeBuilder.BuildMossyTurfPatch(CFrame.new(lawnCenterX + 15, dFloorY, -125), 0.9, diorama)

	for _, gPos in ipairs({
		Vector3.new(lawnCenterX - 8, dFloorY, -109),
		Vector3.new(lawnCenterX + 15, dFloorY, -102),
		Vector3.new(lawnCenterX - 23, dFloorY, -134),
		Vector3.new(lawnCenterX + 8, dFloorY, -123),
		Vector3.new(lawnCenterX - 15, dFloorY + 0.12, -123),
		Vector3.new(lawnCenterX + 23, dFloorY, -114),
	}) do
		ClassicStudBiomeBuilder.BuildGrassTuftCluster(CFrame.new(gPos) * CFrame.Angles(0, gPos.X * 0.4, 0), 1.0, diorama)
	end

	-- C. BiomeZone_1_PineWoods Court Perimeter Dressing inside Showroom (keeps pet pedestals clear!)
	local courtDressing = Instance.new("Model")
	courtDressing.Name = "Biome1_CourtPerimeterDressing"
	courtDressing.Parent = b1

	-- Pet zone floor strips left & right + back border around courtZ = 0
	for _, xSide in ipairs({ -48, 56 }) do
		makeStudPart({
			name = if xSide < 0 then "PineCourtWingGrassL" else "PineCourtWingGrassR",
			size = Vector3.new(16, 0.1, 20),
			cframe = CFrame.new(xSide, SHOWROOM_FLOOR_Y + 0.05, 5),
			color = Color3.fromRGB(86, 158, 74),
			castShadow = false,
			parent = courtDressing,
		})
	end

	ClassicStudBiomeBuilder.BuildPineTreeTall(CFrame.new(-49, SHOWROOM_FLOOR_Y + 0.1, -1.5) * CFrame.Angles(0, 0.3, 0), 0.9, courtDressing)
	ClassicStudBiomeBuilder.BuildPineTreeTwin(CFrame.new(-46, SHOWROOM_FLOOR_Y + 0.1, 10.5) * CFrame.Angles(0, -0.4, 0), 0.85, courtDressing)
	ClassicStudBiomeBuilder.BuildBerryBush(CFrame.new(-42, SHOWROOM_FLOOR_Y + 0.1, 3.5), 0.95, courtDressing)
	ClassicStudBiomeBuilder.BuildGrassTuftCluster(CFrame.new(-43, SHOWROOM_FLOOR_Y + 0.1, -3.0), 1.0, courtDressing)
	ClassicStudBiomeBuilder.BuildMushroomCluster(CFrame.new(-41, SHOWROOM_FLOOR_Y + 0.1, 9.0), 1.0, courtDressing)

	ClassicStudBiomeBuilder.BuildOakTreeBroad(CFrame.new(57, SHOWROOM_FLOOR_Y + 0.1, -1.0) * CFrame.Angles(0, -0.5, 0), 0.9, courtDressing)
	ClassicStudBiomeBuilder.BuildBirchTreeForest(CFrame.new(55, SHOWROOM_FLOOR_Y + 0.1, 11.0) * CFrame.Angles(0, 0.6, 0), 0.88, courtDressing)
	ClassicStudBiomeBuilder.BuildMossyBoulder(CFrame.new(51, SHOWROOM_FLOOR_Y + 0.1, 4.5), 0.85, courtDressing)
	ClassicStudBiomeBuilder.BuildFernCluster(CFrame.new(50, SHOWROOM_FLOOR_Y + 0.1, -3.5), 1.0, courtDressing)
	ClassicStudBiomeBuilder.BuildWildflowerPatch(CFrame.new(51, SHOWROOM_FLOOR_Y + 0.1, 11.5), 0.95, courtDressing)
	ClassicStudBiomeBuilder.BuildRangerLanternPost(CFrame.new(-41, SHOWROOM_FLOOR_Y + 0.1, 13.5) * CFrame.Angles(0, math.rad(25), 0), 0.95, courtDressing)
	ClassicStudBiomeBuilder.BuildRangerLanternPost(CFrame.new(50, SHOWROOM_FLOOR_Y + 0.1, 13.5) * CFrame.Angles(0, math.rad(155), 0), 0.95, courtDressing)

	return root
end

return ClassicStudBiomeBuilder
