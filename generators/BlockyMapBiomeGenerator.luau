--!strict
-- BlockyMapBiomeGenerator.luau
-- Generates all 5 Stylized Blocky Studded Biomes (Steal an Egg / Steal a Pet style)
-- Combines custom BlockyStud* MaterialVariants, Classic Studs Modular Environment Assets,
-- Landmark Dioramas, Crate Spawn Anchors, and Poacher Patrol Waypoints.
-- STRICT USER CONSTRAINT: All decorative environment assets (trees, rocks, flora, ruins, props)
-- have CanCollide = false, CanQuery = false, CanTouch = false so player & vehicle movement is 100% unobstructed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local ClassicStudBiomeBuilder = require(ReplicatedStorage.Modules.ClassicStudBiomeBuilder)

local BlockyMapBiomeGenerator = {}

local function makeBlock(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	materialVariant: string?,
	studded: boolean?,
	canCollide: boolean?,
	canQuery: boolean?,
	canTouch: boolean?,
	castShadow: boolean?,
	transparency: number?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.materialVariant and props.materialVariant ~= "" then
		p.MaterialVariant = props.materialVariant
	end
	p.TopSurface = if props.studded ~= false then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	p.CanQuery = if props.canQuery ~= nil then props.canQuery else true
	p.CanTouch = if props.canTouch ~= nil then props.canTouch else true
	p.CastShadow = if props.castShadow ~= nil then props.castShadow else false
	p.Transparency = props.transparency or 0
	p.Parent = props.parent
	return p
end

local function addBiomeDividerLine(zPos: number, biome: any, parent: Instance)
	makeBlock({
		name = "BiomeDivider_" .. biome.id,
		size = Vector3.new(188, 0.25, 2.2),
		cframe = CFrame.new(0, 0.22, zPos),
		color = biome.accentColor,
		material = Enum.Material.SmoothPlastic,
		studded = false,
		canCollide = false,
		canQuery = false,
		canTouch = false,
		parent = parent,
	})
end

local function placeClassicAsset(buildFn: (cf: CFrame, sc: number?, p: Instance?) -> Model, cf: CFrame, scale: number?, parent: Instance): Model
	local m = buildFn(cf, scale, parent)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
		end
	end
	return m
end

local function findCuratedTemplate(packPath: { string }): Instance?
	local curr: Instance? = ReplicatedStorage:FindFirstChild("CuratedAssets")
	for _, seg in packPath do
		if not curr then
			return nil
		end
		curr = curr:FindFirstChild(seg)
	end
	return curr
end

local function placeCuratedProp(template: Instance?, pos: Vector3, yawRad: number, scaleMult: number, parent: Instance)
	if not template then return end
	local clone = template:Clone()
	if clone:IsA("Model") then
		if scaleMult ~= 1 then
			pcall(function()
				clone:ScaleTo(clone:GetScale() * scaleMult)
			end)
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			elseif d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		clone:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yawRad, 0))
		clone.Parent = parent
		local cf, size = clone:GetBoundingBox()
		local currentBottomY = cf.Position.Y - size.Y * 0.5
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, pos.Y - 0.1 - currentBottomY, 0))
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Size = clone.Size * scaleMult
		clone.CFrame = CFrame.new(pos + Vector3.new(0, clone.Size.Y * 0.5 - 0.1, 0)) * CFrame.Angles(0, yawRad, 0)
		clone.Parent = parent
	else
		clone:Destroy()
	end
end

-- ============================================================================
-- BIOME-SPECIFIC PROCEDURAL ENVIRONMENT POPULATION (CLASSIC STUDS)
-- ============================================================================

local function populatePineWoodsDecor(propsFolder: Folder, biome: any, plateauTopY: number, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	-- 1. Hero Campsite Clearing (Floor, Left)
	local campZ = biome.zStart + lenZ * 0.38
	placeClassicAsset(ClassicStudBiomeBuilder.BuildTreeStump, CFrame.new(-44, 0, campZ), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildTreeStump, CFrame.new(-48, 0, campZ + 4), 0.95, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildTreeStump, CFrame.new(-41, 0, campZ + 3.5), 0.95, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildFallenHollowLog, CFrame.new(-45, 0, campZ - 5) * CFrame.Angles(0, 0.4, 0), 1.0, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildRangerLanternPost, CFrame.new(-38, 0, campZ + 1), 1.05, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildRangerLanternPost, CFrame.new(-50, 0, campZ - 2) * CFrame.Angles(0, math.pi, 0), 1.05, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildMushroomCluster, CFrame.new(-40, 0, campZ - 4), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildBerryBush, CFrame.new(-52, 0, campZ + 3), 1.1, propsFolder)

	-- 2. Scenic Grove Clearing (Floor, Right)
	local groveZ = biome.zStart + lenZ * 0.68
	placeClassicAsset(ClassicStudBiomeBuilder.BuildPineTreeTwin, CFrame.new(50, 0, groveZ), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildOakTreeBroad, CFrame.new(58, 0, groveZ - 8), 1.05, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildMossyBoulder, CFrame.new(42, 0, groveZ + 3), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildWildflowerPatch, CFrame.new(45, 0, groveZ - 6), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildFernCluster, CFrame.new(54, 0, groveZ + 6), 1.1, propsFolder)

	-- 3. Trailside Ranger Lanterns along Central Road Borders
	for z = biome.zStart + 35, biome.zEnd - 35, 65 do
		placeClassicAsset(ClassicStudBiomeBuilder.BuildRangerLanternPost, CFrame.new(-19, 0.45, z), 0.95, propsFolder)
		placeClassicAsset(ClassicStudBiomeBuilder.BuildRangerLanternPost, CFrame.new(19, 0.45, z + 32) * CFrame.Angles(0, math.pi, 0), 0.95, propsFolder)
	end

	-- 4. Floor Foliage & Woodland Trees (Left & Right Flanks)
	local floorTrees = {
		ClassicStudBiomeBuilder.BuildPineTreeTall,
		ClassicStudBiomeBuilder.BuildPineTreeTwin,
		ClassicStudBiomeBuilder.BuildOakTreeBroad,
		ClassicStudBiomeBuilder.BuildBirchTreeForest,
	}
	local floorFlora = {
		ClassicStudBiomeBuilder.BuildWildflowerPatch,
		ClassicStudBiomeBuilder.BuildBerryBush,
		ClassicStudBiomeBuilder.BuildFernCluster,
		ClassicStudBiomeBuilder.BuildGrassTuftCluster,
		ClassicStudBiomeBuilder.BuildMushroomCluster,
		ClassicStudBiomeBuilder.BuildMossyBoulder,
		ClassicStudBiomeBuilder.BuildTreeStump,
		ClassicStudBiomeBuilder.BuildFallenHollowLog,
	}

	for sideSign in ipairs({ -1, 1 }) do
		local sign = if sideSign == 1 then -1 else 1
		for step = 1, 12 do
			local z = biome.zStart + 25 + ((step - 1) / 11) * (lenZ - 50) + rng:NextNumber(-8, 8)
			local treeFn = floorTrees[rng:NextInteger(1, #floorTrees)]
			local tx = sign * rng:NextNumber(28, 74)
			placeClassicAsset(treeFn, CFrame.new(tx, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.25), propsFolder)

			local floraFn = floorFlora[rng:NextInteger(1, #floorFlora)]
			local fx = sign * rng:NextNumber(22, 70)
			placeClassicAsset(floraFn, CFrame.new(fx, 0, z + rng:NextNumber(-10, 10)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.95, 1.2), propsFolder)
		end
	end

	-- 5. Upper Cliff Plateau Skyline (Dense Forest Horizon)
	for _, sideSign in { -1, 1 } do
		for idx = 1, 13 do
			local z = biome.zStart + 20 + ((idx - 1) / 12) * (lenZ - 40) + rng:NextNumber(-8, 8)
			local px = sideSign * rng:NextNumber(104, 148)
			local tFn = floorTrees[rng:NextInteger(1, #floorTrees)]
			placeClassicAsset(tFn, CFrame.new(px, plateauTopY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1.05, 1.45), propsFolder)
			if idx % 2 == 0 then
				placeClassicAsset(ClassicStudBiomeBuilder.BuildMossyBoulder, CFrame.new(px + sideSign * 4, plateauTopY, z - 3), rng:NextNumber(1.0, 1.3), propsFolder)
			end
		end
	end
end

local function populateMangroveSwampDecor(propsFolder: Folder, biome: any, plateauTopY: number, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	-- 1. Hero Swamp Totem Shrine (Floor, Left)
	local shrineZ = biome.zStart + lenZ * 0.35
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampTotemShrine, CFrame.new(-50, 0, shrineZ) * CFrame.Angles(0, math.rad(20), 0), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampLanternTotem, CFrame.new(-38, 0, shrineZ + 6), 1.05, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildGiantGlowMushroom, CFrame.new(-58, 0, shrineZ - 6), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildGlowSporeTrio, CFrame.new(-42, 0, shrineZ - 5), 1.2, propsFolder)

	-- 2. Hero Wooden Swamp Dock over Lagoon (Floor, Right)
	local dockZ = biome.zStart + lenZ * 0.65
	placeClassicAsset(ClassicStudBiomeBuilder.BuildWoodenSwampDock, CFrame.new(46, 0.15, dockZ) * CFrame.Angles(0, math.rad(90), 0), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampLanternTotem, CFrame.new(38, 0, dockZ - 5), 1.0, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampLilyPadCluster, CFrame.new(54, 0.22, dockZ + 4), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildCattailReedCluster, CFrame.new(40, 0, dockZ + 7), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSunkenHollowLog, CFrame.new(55, 0, dockZ - 7) * CFrame.Angles(0, -0.5, 0), 1.1, propsFolder)

	-- 3. Trailside Swamp Lantern Totems
	for z = biome.zStart + 40, biome.zEnd - 40, 75 do
		placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampLanternTotem, CFrame.new(-19, 0.45, z), 0.95, propsFolder)
		placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampLanternTotem, CFrame.new(19, 0.45, z + 38) * CFrame.Angles(0, math.pi, 0), 0.95, propsFolder)
	end

	-- 4. Floor Foliage & Sprawling Mangrove Trees
	local swampTrees = {
		ClassicStudBiomeBuilder.BuildMangroveTreeArch,
		ClassicStudBiomeBuilder.BuildDeadSwampWillow,
	}
	local swampFlora = {
		ClassicStudBiomeBuilder.BuildGiantGlowMushroom,
		ClassicStudBiomeBuilder.BuildSwampLilyPadCluster,
		ClassicStudBiomeBuilder.BuildCattailReedCluster,
		ClassicStudBiomeBuilder.BuildGlowSporeTrio,
		ClassicStudBiomeBuilder.BuildSunkenHollowLog,
		ClassicStudBiomeBuilder.BuildMossySwampBoulder,
	}

	for sideSign in ipairs({ -1, 1 }) do
		local sign = if sideSign == 1 then -1 else 1
		for step = 1, 12 do
			local z = biome.zStart + 25 + ((step - 1) / 11) * (lenZ - 50) + rng:NextNumber(-8, 8)
			local treeFn = swampTrees[rng:NextInteger(1, #swampTrees)]
			local tx = sign * rng:NextNumber(30, 72)
			placeClassicAsset(treeFn, CFrame.new(tx, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.2), propsFolder)

			local floraFn = swampFlora[rng:NextInteger(1, #swampFlora)]
			local fx = sign * rng:NextNumber(22, 68)
			placeClassicAsset(floraFn, CFrame.new(fx, 0, z + rng:NextNumber(-9, 9)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.95, 1.25), propsFolder)
		end
	end

	-- 5. Upper Cliff Plateau Skyline (Mushroom & Gnarled Willow Ridge)
	for _, sideSign in { -1, 1 } do
		for idx = 1, 12 do
			local z = biome.zStart + 22 + ((idx - 1) / 11) * (lenZ - 44) + rng:NextNumber(-8, 8)
			local px = sideSign * rng:NextNumber(104, 146)
			if idx % 2 == 0 then
				placeClassicAsset(ClassicStudBiomeBuilder.BuildGiantGlowMushroom, CFrame.new(px, plateauTopY, z), rng:NextNumber(1.05, 1.35), propsFolder)
			else
				placeClassicAsset(ClassicStudBiomeBuilder.BuildDeadSwampWillow, CFrame.new(px, plateauTopY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1.0, 1.3), propsFolder)
			end
			if idx % 3 == 0 then
				placeClassicAsset(ClassicStudBiomeBuilder.BuildSwampLanternTotem, CFrame.new(px + sideSign * 4, plateauTopY, z + 3), 1.0, propsFolder)
			end
		end
	end
end

local function populateSavannaCampDecor(propsFolder: Folder, biome: any, plateauTopY: number, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	-- 1. Hero Desert Step Pyramid (Floor, Left Clearing)
	local pyrZ = biome.zStart + lenZ * 0.42
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertStepPyramid, CFrame.new(-54, 0, pyrZ), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertBrazierTorch, CFrame.new(-38, 0, pyrZ + 8), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertBrazierTorch, CFrame.new(-38, 0, pyrZ - 8), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertSkullBone, CFrame.new(-42, 0, pyrZ), 1.2, propsFolder)

	-- 2. Hero Oasis Water Pool & Palm Grove (Floor, Right Clearing)
	local oasisZ = biome.zStart + lenZ * 0.70
	placeClassicAsset(ClassicStudBiomeBuilder.BuildOasisWaterPool, CFrame.new(50, 0, oasisZ), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertPalmTree, CFrame.new(58, 0, oasisZ + 6) * CFrame.Angles(0, 0.4, 0), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertPalmTree, CFrame.new(42, 0, oasisZ - 6) * CFrame.Angles(0, -0.5, 0), 1.05, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSavannaGrassTuft, CFrame.new(46, 0, oasisZ + 8), 1.2, propsFolder)

	-- 3. Hero Sandstone Mesa Arch
	local archZ = biome.zStart + lenZ * 0.86
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSandstoneMesaArch, CFrame.new(-50, 0, archZ) * CFrame.Angles(0, math.rad(15), 0), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSandstoneRuinedPillar, CFrame.new(-38, 0, archZ - 6), 1.1, propsFolder)

	-- 4. Trailside Desert Brazier Torches
	for z = biome.zStart + 40, biome.zEnd - 40, 75 do
		placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertBrazierTorch, CFrame.new(-19, 0.45, z), 0.95, propsFolder)
		placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertBrazierTorch, CFrame.new(19, 0.45, z + 38) * CFrame.Angles(0, math.pi, 0), 0.95, propsFolder)
	end

	-- 5. Floor Trees, Giant Cacti & Desert Props
	local savannaTrees = {
		ClassicStudBiomeBuilder.BuildDesertPalmTree,
		ClassicStudBiomeBuilder.BuildAcaciaTreeFlat,
	}
	local savannaFlora = {
		ClassicStudBiomeBuilder.BuildSaguaroCactusGiant,
		ClassicStudBiomeBuilder.BuildBarrelCactusCluster,
		ClassicStudBiomeBuilder.BuildSavannaGrassTuft,
		ClassicStudBiomeBuilder.BuildSandstoneRuinedPillar,
		ClassicStudBiomeBuilder.BuildDesertSkullBone,
	}

	for sideSign in ipairs({ -1, 1 }) do
		local sign = if sideSign == 1 then -1 else 1
		for step = 1, 12 do
			local z = biome.zStart + 25 + ((step - 1) / 11) * (lenZ - 50) + rng:NextNumber(-8, 8)
			local treeFn = savannaTrees[rng:NextInteger(1, #savannaTrees)]
			local tx = sign * rng:NextNumber(28, 72)
			placeClassicAsset(treeFn, CFrame.new(tx, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.2), propsFolder)

			local floraFn = savannaFlora[rng:NextInteger(1, #savannaFlora)]
			local fx = sign * rng:NextNumber(22, 68)
			placeClassicAsset(floraFn, CFrame.new(fx, 0, z + rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.95, 1.25), propsFolder)
		end
	end

	-- 6. Upper Cliff Plateau Skyline (Secondary Step Pyramid + Giant Cacti + Acacias)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildDesertStepPyramid, CFrame.new(128, plateauTopY, biome.zStart + lenZ * 0.5), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSandstoneMesaArch, CFrame.new(-128, plateauTopY, biome.zStart + lenZ * 0.5) * CFrame.Angles(0, math.rad(90), 0), 1.1, propsFolder)

	for _, sideSign in { -1, 1 } do
		for idx = 1, 11 do
			local z = biome.zStart + 25 + ((idx - 1) / 10) * (lenZ - 50) + rng:NextNumber(-8, 8)
			local px = sideSign * rng:NextNumber(104, 146)
			if idx % 2 == 0 then
				placeClassicAsset(ClassicStudBiomeBuilder.BuildAcaciaTreeFlat, CFrame.new(px, plateauTopY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1.0, 1.3), propsFolder)
			else
				placeClassicAsset(ClassicStudBiomeBuilder.BuildSaguaroCactusGiant, CFrame.new(px, plateauTopY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1.05, 1.35), propsFolder)
			end
		end
	end
end

local function populateAlpinePeaksDecor(propsFolder: Folder, biome: any, plateauTopY: number, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	-- 1. Hero Giant Ice Crystal Spire (Floor, Right Clearing)
	local spireZ = biome.zStart + lenZ * 0.40
	placeClassicAsset(ClassicStudBiomeBuilder.BuildGiantIceCrystalSpire, CFrame.new(52, 0, spireZ), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildIceCrystalCluster, CFrame.new(42, 0, spireZ + 6), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildIceCrystalCluster, CFrame.new(42, 0, spireZ - 6), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildAlpineStoneCairn, CFrame.new(38, 0, spireZ), 1.15, propsFolder)

	-- 2. Hero Frozen Ice Archway (Floor, Left Clearing)
	local archZ = biome.zStart + lenZ * 0.68
	placeClassicAsset(ClassicStudBiomeBuilder.BuildFrozenIceArchway, CFrame.new(-48, 0, archZ) * CFrame.Angles(0, math.rad(15), 0), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildSnowyPineTreeTall, CFrame.new(-58, 0, archZ + 6), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildGlacierBoulderSnowy, CFrame.new(-40, 0, archZ - 5), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildIceBerryBush, CFrame.new(-42, 0, archZ + 6), 1.1, propsFolder)

	-- 3. Trailside Alpine Stone Cairns
	for z = biome.zStart + 40, biome.zEnd - 40, 75 do
		placeClassicAsset(ClassicStudBiomeBuilder.BuildAlpineStoneCairn, CFrame.new(-19, 0.45, z), 0.95, propsFolder)
		placeClassicAsset(ClassicStudBiomeBuilder.BuildAlpineStoneCairn, CFrame.new(19, 0.45, z + 38) * CFrame.Angles(0, math.pi, 0), 0.95, propsFolder)
	end

	-- 4. Floor Foliage & Frosted Pines
	local alpineTrees = {
		ClassicStudBiomeBuilder.BuildSnowyPineTreeTall,
		ClassicStudBiomeBuilder.BuildSnowyPineTreeTwin,
		ClassicStudBiomeBuilder.BuildFrostedBirchTree,
	}
	local alpineFlora = {
		ClassicStudBiomeBuilder.BuildIceBerryBush,
		ClassicStudBiomeBuilder.BuildFrostGrassTuft,
		ClassicStudBiomeBuilder.BuildGlacierBoulderSnowy,
		ClassicStudBiomeBuilder.BuildIceCrystalCluster,
		ClassicStudBiomeBuilder.BuildFrozenHollowLog,
		ClassicStudBiomeBuilder.BuildAlpineStoneCairn,
	}

	for sideSign in ipairs({ -1, 1 }) do
		local sign = if sideSign == 1 then -1 else 1
		for step = 1, 12 do
			local z = biome.zStart + 25 + ((step - 1) / 11) * (lenZ - 50) + rng:NextNumber(-8, 8)
			local treeFn = alpineTrees[rng:NextInteger(1, #alpineTrees)]
			local tx = sign * rng:NextNumber(28, 72)
			placeClassicAsset(treeFn, CFrame.new(tx, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.25), propsFolder)

			local floraFn = alpineFlora[rng:NextInteger(1, #alpineFlora)]
			local fx = sign * rng:NextNumber(22, 68)
			placeClassicAsset(floraFn, CFrame.new(fx, 0, z + rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.95, 1.25), propsFolder)
		end
	end

	-- 5. Upper Cliff Plateau Skyline (Giant Ice Spires + Snowy Pines on Ridges)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildGiantIceCrystalSpire, CFrame.new(-126, plateauTopY, biome.zStart + lenZ * 0.35), 1.25, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildGiantIceCrystalSpire, CFrame.new(128, plateauTopY, biome.zStart + lenZ * 0.72), 1.25, propsFolder)

	for _, sideSign in { -1, 1 } do
		for idx = 1, 12 do
			local z = biome.zStart + 22 + ((idx - 1) / 11) * (lenZ - 44) + rng:NextNumber(-8, 8)
			local px = sideSign * rng:NextNumber(104, 146)
			local tFn = alpineTrees[rng:NextInteger(1, #alpineTrees)]
			placeClassicAsset(tFn, CFrame.new(px, plateauTopY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1.05, 1.45), propsFolder)
			if idx % 3 == 0 then
				placeClassicAsset(ClassicStudBiomeBuilder.BuildIceCrystalCluster, CFrame.new(px + sideSign * 4, plateauTopY, z + 2), 1.2, propsFolder)
			end
		end
	end
end

local function populateVolcanicJungleDecor(propsFolder: Folder, biome: any, plateauTopY: number, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	-- 1. Hero Volcano Crater Landmark (Floor, Left Clearing)
	local craterZ = biome.zStart + lenZ * 0.40
	placeClassicAsset(ClassicStudBiomeBuilder.BuildVolcanoCraterLandmark, CFrame.new(-52, 0, craterZ), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildMagmaVentGeyser, CFrame.new(-38, 0, craterZ + 8), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildMagmaVentGeyser, CFrame.new(-38, 0, craterZ - 8), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildCrimsonCrystalCluster, CFrame.new(-42, 0, craterZ), 1.2, propsFolder)

	-- 2. Hero Obsidian Monolith Ruins (Floor, Right Clearing)
	local monolithZ = biome.zStart + lenZ * 0.72
	placeClassicAsset(ClassicStudBiomeBuilder.BuildObsidianMonolithRuins, CFrame.new(50, 0, monolithZ) * CFrame.Angles(0, math.rad(25), 0), 1.2, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier, CFrame.new(38, 0, monolithZ + 6), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier, CFrame.new(38, 0, monolithZ - 6), 1.1, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildLavaCrackedBoulder, CFrame.new(58, 0, monolithZ), 1.15, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildFirebloomFlowerPatch, CFrame.new(44, 0, monolithZ + 7), 1.2, propsFolder)

	-- 3. Trailside Volcanic Skull Braziers
	for z = biome.zStart + 40, biome.zEnd - 40, 75 do
		placeClassicAsset(ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier, CFrame.new(-19, 0.45, z), 0.95, propsFolder)
		placeClassicAsset(ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier, CFrame.new(19, 0.45, z + 38) * CFrame.Angles(0, math.pi, 0), 0.95, propsFolder)
	end

	-- 4. Floor Foliage & Charred Trees
	local volcanicTrees = {
		ClassicStudBiomeBuilder.BuildCharredCrimsonTree,
		ClassicStudBiomeBuilder.BuildObsidianDeadTree,
		ClassicStudBiomeBuilder.BuildMagmaPalmTree,
	}
	local volcanicFlora = {
		ClassicStudBiomeBuilder.BuildFirebloomFlowerPatch,
		ClassicStudBiomeBuilder.BuildAshEmberGrassTuft,
		ClassicStudBiomeBuilder.BuildMagmaVentGeyser,
		ClassicStudBiomeBuilder.BuildLavaCrackedBoulder,
		ClassicStudBiomeBuilder.BuildCrimsonCrystalCluster,
		ClassicStudBiomeBuilder.BuildVolcanicSkullBrazier,
	}

	for sideSign in ipairs({ -1, 1 }) do
		local sign = if sideSign == 1 then -1 else 1
		for step = 1, 12 do
			local z = biome.zStart + 25 + ((step - 1) / 11) * (lenZ - 50) + rng:NextNumber(-8, 8)
			local treeFn = volcanicTrees[rng:NextInteger(1, #volcanicTrees)]
			local tx = sign * rng:NextNumber(28, 72)
			placeClassicAsset(treeFn, CFrame.new(tx, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.25), propsFolder)

			local floraFn = volcanicFlora[rng:NextInteger(1, #volcanicFlora)]
			local fx = sign * rng:NextNumber(22, 68)
			placeClassicAsset(floraFn, CFrame.new(fx, 0, z + rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.95, 1.25), propsFolder)
		end
	end

	-- 5. Upper Cliff Plateau Skyline (Secondary Volcano Crater + Monoliths + Geysers)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildVolcanoCraterLandmark, CFrame.new(128, plateauTopY, biome.zStart + lenZ * 0.45), 1.25, propsFolder)
	placeClassicAsset(ClassicStudBiomeBuilder.BuildObsidianMonolithRuins, CFrame.new(-128, plateauTopY, biome.zStart + lenZ * 0.65) * CFrame.Angles(0, math.rad(90), 0), 1.2, propsFolder)

	for _, sideSign in { -1, 1 } do
		for idx = 1, 12 do
			local z = biome.zStart + 22 + ((idx - 1) / 11) * (lenZ - 44) + rng:NextNumber(-8, 8)
			local px = sideSign * rng:NextNumber(104, 146)
			local tFn = volcanicTrees[rng:NextInteger(1, #volcanicTrees)]
			placeClassicAsset(tFn, CFrame.new(px, plateauTopY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(1.05, 1.45), propsFolder)
			if idx % 2 == 0 then
				placeClassicAsset(ClassicStudBiomeBuilder.BuildMagmaVentGeyser, CFrame.new(px + sideSign * 4, plateauTopY, z + 2), 1.15, propsFolder)
			end
		end
	end
end

-- ============================================================================
-- MAIN BUILDER ENTRY POINT
-- ============================================================================

function BlockyMapBiomeGenerator.Build(worldFolder: Folder): Folder
	ClassicStudBiomeBuilder.EnsureClassicStudsVariant()

	if not worldFolder:FindFirstChild("BrushedDecor") then
		local brushed = Instance.new("Folder")
		brushed.Name = "BrushedDecor"
		brushed.Parent = worldFolder
	end

	local existing = worldFolder:FindFirstChild("Biomes")
	if existing then
		existing:Destroy()
	end

	local biomesFolder = Instance.new("Folder")
	biomesFolder.Name = "Biomes"
	biomesFolder.Parent = worldFolder

	local rng = Random.new(42069)
	local mapWidth = 220

	for _, biome in ipairs(BiomeConfig) do
		local biomeModel = Instance.new("Folder")
		biomeModel.Name = biome.id
		biomeModel:SetAttribute("BiomeId", biome.id)
		biomeModel:SetAttribute("ZStart", biome.zStart)
		biomeModel:SetAttribute("ZEnd", biome.zEnd)
		biomeModel.Parent = biomesFolder

		local lenZ = biome.zEnd - biome.zStart
		local centerZ = (biome.zStart + biome.zEnd) / 2

		-- 1. Custom Blocky Checkerboard Studded Ground + Stepped Terrain Islands
		local terrainGroup = Instance.new("Folder")
		terrainGroup.Name = "BlockyTerrain"
		terrainGroup.Parent = biomeModel

		makeBlock({
			name = "BiomeMainFloor",
			size = Vector3.new(mapWidth, 4, lenZ),
			cframe = CFrame.new(0, -2, centerZ),
			color = biome.groundColor,
			material = biome.materialName,
			materialVariant = biome.materialVariant,
			studded = true,
			parent = terrainGroup,
		})

		-- Floating Sky-Island tapered rock strata underneath each Biome
		local bHull1 = makeBlock({
			name = "BiomeIslandHullUpper",
			size = Vector3.new(mapWidth - 10, 18, lenZ - 4),
			cframe = CFrame.new(0, -13, centerZ),
			color = biome.cliffColor,
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
			canTouch = false,
			parent = terrainGroup,
		})
		bHull1.CastShadow = false

		local bHull2 = makeBlock({
			name = "BiomeIslandHullKeel",
			size = Vector3.new(mapWidth - 74, 24, lenZ - 24),
			cframe = CFrame.new(0, -32, centerZ),
			color = biome.cliffColor:Lerp(Color3.fromRGB(28, 24, 34), 0.35),
			material = Enum.Material.Basalt,
			canCollide = false,
			canQuery = false,
			canTouch = false,
			parent = terrainGroup,
		})
		bHull2.CastShadow = false

		-- Mosaic Checkerboard Stud Tiles flanking the center trail
		local tileW = 24
		local tileZ = 28
		local rowIdx = 0
		for z = biome.zStart + tileZ * 0.5, biome.zEnd - tileZ * 0.5, tileZ do
			rowIdx += 1
			for colIdx, cx in ipairs({ -74, -50, -28, 28, 50, 74 }) do
				if (rowIdx + colIdx) % 2 == 0 then
					makeBlock({
						name = "MosaicTile",
						size = Vector3.new(tileW - 1, 0.14, tileZ - 1),
						cframe = CFrame.new(cx, 0.05, z),
						color = biome.groundColor:Lerp(biome.accentColor, 0.24),
						material = biome.materialName,
						materialVariant = biome.materialVariant,
						studded = true,
						canCollide = false,
						canQuery = false,
						canTouch = false,
						parent = terrainGroup,
					})
				end
			end
		end

		-- Walkable Stepped Terrain Mounds / Knolls on outer sides
		for idx = 1, 6 do
			local sideSign = if idx % 2 == 0 then 1 else -1
			local mz = biome.zStart + 32 + ((idx - 1) / 5) * (lenZ - 64)
			local mx = sideSign * rng:NextNumber(52, 74)
			local mw = rng:NextNumber(18, 28)
			local md = rng:NextNumber(22, 34)
			makeBlock({
				name = "TerrainKnollLow",
				size = Vector3.new(mw, 0.9, md),
				cframe = CFrame.new(mx, 0.45, mz),
				color = biome.groundColor:Lerp(Color3.new(1, 1, 1), 0.08),
				material = biome.materialName,
				materialVariant = biome.materialVariant,
				studded = true,
				parent = terrainGroup,
			})
			makeBlock({
				name = "TerrainKnollTop",
				size = Vector3.new(mw * 0.58, 0.85, md * 0.58),
				cframe = CFrame.new(mx + sideSign * 2.5, 1.25, mz),
				color = biome.groundColor:Lerp(biome.accentColor, 0.2),
				material = biome.materialName,
				materialVariant = biome.materialVariant,
				studded = true,
				parent = terrainGroup,
			})
		end

		-- Central Stepped Cobble / Accent Expedition Road (clear driving strip down the middle)
		makeBlock({
			name = "ExpeditionTrail",
			size = Vector3.new(34, 0.45, lenZ),
			cframe = CFrame.new(0, 0.2, centerZ),
			color = biome.accentColor,
			material = Enum.Material.SmoothPlastic,
			studded = true,
			parent = terrainGroup,
		})
		for _, curbX in { -17.5, 17.5 } do
			makeBlock({
				name = "TrailBorderTrim",
				size = Vector3.new(1.8, 0.55, lenZ),
				cframe = CFrame.new(curbX, 0.25, centerZ),
				color = biome.accentColor:Lerp(Color3.new(1, 1, 1), 0.25),
				material = Enum.Material.Cobblestone,
				studded = true,
				canQuery = false,
				parent = terrainGroup,
			})
		end

		-- 2. Custom Cartoon Cliff Walls
		local cliffHeight = 24
		local capThickness = 3.0
		local plateauTopY = cliffHeight + capThickness -- 27.0
		local plateauWidth = 68
		local plateauCenterX = 94 + plateauWidth * 0.5 -- X spans 94..162

		local warmCliffTint = if biome.id == "PineWoods" then Color3.fromRGB(186, 108, 86)
			elseif biome.id == "MangroveSwamp" then Color3.fromRGB(108, 84, 66)
			elseif biome.id == "SavannaCamp" then Color3.fromRGB(204, 134, 72)
			elseif biome.id == "AlpinePeaks" then Color3.fromRGB(132, 168, 206)
			else Color3.fromRGB(48, 36, 52)

		for _, sideSign in { -1, 1 } do
			makeBlock({
				name = "CliffWall_" .. tostring(sideSign),
				size = Vector3.new(plateauWidth, cliffHeight, lenZ),
				cframe = CFrame.new(sideSign * plateauCenterX, cliffHeight * 0.5, centerZ),
				color = warmCliffTint,
				material = Enum.Material.Slate,
				materialVariant = "CartoonCliffWall",
				studded = false,
				canQuery = false,
				castShadow = true,
				parent = terrainGroup,
			})
			makeBlock({
				name = "CliffTopPlateau_" .. tostring(sideSign),
				size = Vector3.new(plateauWidth + 4.8, capThickness, lenZ),
				cframe = CFrame.new(sideSign * (plateauCenterX - 2.4), cliffHeight + capThickness * 0.5, centerZ),
				color = biome.groundColor,
				material = biome.materialName,
				materialVariant = biome.materialVariant,
				studded = true,
				canQuery = false,
				parent = terrainGroup,
			})
			local sliceStep = 64
			for z = biome.zStart + 32, biome.zEnd - 32, sliceStep do
				local ledgeH = rng:NextInteger(7, 13)
				local lw = rng:NextInteger(10, 15)
				makeBlock({
					name = "CliffLedge",
					size = Vector3.new(lw, ledgeH, 32),
					cframe = CFrame.new(sideSign * 89, ledgeH * 0.5, z),
					color = warmCliffTint:Lerp(Color3.new(0, 0, 0), 0.14),
					material = Enum.Material.Slate,
					materialVariant = "CartoonCliffWall",
					studded = false,
					canQuery = false,
					parent = terrainGroup,
				})
				makeBlock({
					name = "CliffLedgeCap",
					size = Vector3.new(lw + 1.4, 1.8, 33),
					cframe = CFrame.new(sideSign * 89, ledgeH + 0.9, z),
					color = biome.groundColor,
					material = biome.materialName,
					materialVariant = biome.materialVariant,
					studded = true,
					canQuery = false,
					parent = terrainGroup,
				})
			end
		end

		-- Biome-specific custom terrain pools, ruins, stepping islands
		if biome.id == "PineWoods" then
			for z = biome.zStart + 55, biome.zEnd - 45, 95 do
				local side = if math.floor(z) % 2 == 0 then 1 else -1
				makeBlock({
					name = "ForestMossClearing",
					size = Vector3.new(26, 0.35, 22),
					cframe = CFrame.new(side * 44, 0.18, z),
					color = Color3.fromRGB(118, 206, 86),
					material = Enum.Material.Grass,
					materialVariant = "BlockyStudGrass",
					studded = true,
					parent = terrainGroup,
				})
			end
		elseif biome.id == "MangroveSwamp" then
			for z = biome.zStart + 45, biome.zEnd - 45, 72 do
				local poolX = rng:NextNumber(-46, 46)
				if math.abs(poolX) < 28 then poolX = (if poolX >= 0 then 38 else -38) end
				makeBlock({
					name = "SwampMudRim",
					size = Vector3.new(44, 0.4, 34),
					cframe = CFrame.new(poolX, 0.16, z),
					color = Color3.fromRGB(64, 52, 34),
					material = Enum.Material.Mud,
					materialVariant = "BlockyStudMud",
					studded = true,
					parent = terrainGroup,
				})
				makeBlock({
					name = "SwampLagoonWater",
					size = Vector3.new(34, 0.45, 24),
					cframe = CFrame.new(poolX, 0.2, z),
					color = Color3.fromRGB(58, 168, 138),
					material = Enum.Material.Glass,
					studded = false,
					transparency = 0.25,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = terrainGroup,
				})
				makeBlock({
					name = "SwampStepStone",
					size = Vector3.new(8, 0.65, 8),
					cframe = CFrame.new(poolX - 6, 0.32, z + 3) * CFrame.Angles(0, 0.3, 0),
					color = Color3.fromRGB(88, 174, 98),
					material = Enum.Material.Grass,
					studded = true,
					parent = terrainGroup,
				})
			end
		elseif biome.id == "SavannaCamp" then
			for z = biome.zStart + 55, biome.zEnd - 55, 110 do
				local oasisX = if z % 220 < 110 then -48 else 48
				makeBlock({
					name = "OasisSandRim",
					size = Vector3.new(34, 0.45, 28),
					cframe = CFrame.new(oasisX, 0.2, z),
					color = Color3.fromRGB(238, 198, 112),
					material = Enum.Material.Sand,
					materialVariant = "BlockyStudSavanna",
					studded = true,
					parent = terrainGroup,
				})
				makeBlock({
					name = "OasisWater",
					size = Vector3.new(24, 0.5, 18),
					cframe = CFrame.new(oasisX, 0.26, z),
					color = Color3.fromRGB(52, 198, 224),
					material = Enum.Material.Glass,
					studded = false,
					transparency = 0.22,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = terrainGroup,
				})
			end
		elseif biome.id == "AlpinePeaks" then
			for z = biome.zStart + 45, biome.zEnd - 45, 78 do
				local px = rng:NextNumber(-48, 48)
				if math.abs(px) < 28 then px = (if px >= 0 then 42 else -42) end
				makeBlock({
					name = "GlacierIcePatch",
					size = Vector3.new(38, 0.55, 32),
					cframe = CFrame.new(px, 0.24, z),
					color = Color3.fromRGB(132, 224, 255),
					material = Enum.Material.Ice,
					studded = true,
					parent = terrainGroup,
				})
				makeBlock({
					name = "SnowBankShelf",
					size = Vector3.new(22, 1.35, 18),
					cframe = CFrame.new(-px, 0.65, z + 12),
					color = Color3.fromRGB(240, 248, 255),
					material = Enum.Material.Snow,
					materialVariant = "BlockyStudSnow",
					studded = true,
					parent = terrainGroup,
				})
			end
		elseif biome.id == "VolcanicJungle" then
			for z = biome.zStart + 55, biome.zEnd - 55, 85 do
				makeBlock({
					name = "LavaTrench",
					size = Vector3.new(152, 0.32, 18),
					cframe = CFrame.new(0, 0.14, z),
					color = Color3.fromRGB(214, 78, 28),
					material = Enum.Material.SmoothPlastic,
					studded = false,
					parent = terrainGroup,
				})
				makeBlock({
					name = "ObsidianBridge",
					size = Vector3.new(36, 1.25, 22),
					cframe = CFrame.new(0, 0.65, z),
					color = Color3.fromRGB(48, 42, 58),
					material = Enum.Material.Basalt,
					materialVariant = "BlockyStudVolcanic",
					studded = true,
					parent = terrainGroup,
				})
				for _, sx in { -44, 44 } do
					makeBlock({
						name = "BasaltIsland",
						size = Vector3.new(16, 1.1, 14),
						cframe = CFrame.new(sx, 0.52, z),
						color = Color3.fromRGB(62, 50, 68),
						material = Enum.Material.Basalt,
						materialVariant = "BlockyStudVolcanic",
						studded = true,
						parent = terrainGroup,
					})
				end
			end
		end

		-- 3. Subtle Ground Zone Divider
		if biome.order > 1 then
			addBiomeDividerLine(biome.zStart, biome, biomeModel)
		end

		-- 4. Classic Studs Modular Foliage, Trees, Landmarks & Props (NO COLLIDERS!)
		local propsFolder = Instance.new("Folder")
		propsFolder.Name = "CuratedDecor"
		propsFolder.Parent = biomeModel

		local biomeRng = Random.new(biome.order * 1000 + 42)
		if biome.id == "PineWoods" then
			populatePineWoodsDecor(propsFolder, biome, plateauTopY, biomeRng)
		elseif biome.id == "MangroveSwamp" then
			populateMangroveSwampDecor(propsFolder, biome, plateauTopY, biomeRng)
		elseif biome.id == "SavannaCamp" then
			populateSavannaCampDecor(propsFolder, biome, plateauTopY, biomeRng)
		elseif biome.id == "AlpinePeaks" then
			populateAlpinePeaksDecor(propsFolder, biome, plateauTopY, biomeRng)
		elseif biome.id == "VolcanicJungle" then
			populateVolcanicJungleDecor(propsFolder, biome, plateauTopY, biomeRng)
		end

		-- Place Poacher Watchtower outpost in each biome (No Colliders)
		local towerTpl = findCuratedTemplate({ "Hero_PoacherWatchtower" })
		if towerTpl then
			local side = if biome.order % 2 == 1 then 1 else -1
			placeCuratedProp(towerTpl, Vector3.new(side * 48, 0, centerZ), if side > 0 then -math.pi / 2 else math.pi / 2, 1.1, propsFolder)
		end

		-- 5. Deterministic Crate Spawn Anchors (12 per biome, including Onboarding Crate)
		local crateSpawnsFolder = Instance.new("Folder")
		crateSpawnsFolder.Name = "CrateSpawns"
		crateSpawnsFolder.Parent = biomeModel

		if biome.order == 1 then
			local onboardingAnchor = makeBlock({
				name = "OnboardingCrateSpawn",
				size = Vector3.new(4, 0.4, 4),
				cframe = CFrame.new(10, 0.25, 174),
				color = Color3.fromRGB(242, 206, 78),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				canTouch = false,
				transparency = 0.6,
				parent = crateSpawnsFolder,
			})
			onboardingAnchor:SetAttribute("IsOnboarding", true)
			onboardingAnchor:SetAttribute("BiomeId", biome.id)
		end

		for s = 1, 11 do
			local side = if s % 2 == 0 then 1 else -1
			local sx = side * rng:NextNumber(20, 68)
			local sz = biome.zStart + 30 + ((s - 1) / 10) * (lenZ - 65)
			local anchor = makeBlock({
				name = "CrateSpawn_" .. tostring(s),
				size = Vector3.new(4, 0.3, 4),
				cframe = CFrame.new(sx, 0.2, sz),
				color = biome.accentColor,
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				canTouch = false,
				transparency = 0.75,
				parent = crateSpawnsFolder,
			})
			anchor:SetAttribute("BiomeId", biome.id)
		end

		-- 6. Poacher Patrol Waypoints
		local patrolFolder = Instance.new("Folder")
		patrolFolder.Name = "PoacherPatrol"
		patrolFolder.Parent = biomeModel

		local waypoints = {
			Vector3.new(-32, 3, biome.zStart + lenZ * 0.25),
			Vector3.new(32, 3, biome.zStart + lenZ * 0.45),
			Vector3.new(-28, 3, biome.zStart + lenZ * 0.70),
			Vector3.new(28, 3, biome.zStart + lenZ * 0.85),
		}
		for idx, wp in ipairs(waypoints) do
			local marker = makeBlock({
				name = "Waypoint_" .. idx,
				size = Vector3.new(2, 2, 2),
				cframe = CFrame.new(wp),
				color = Color3.fromRGB(255, 64, 64),
				canCollide = false,
				canQuery = false,
				canTouch = false,
				transparency = 1,
				parent = patrolFolder,
			})
			marker:SetAttribute("Order", idx)
		end

		task.wait()
	end

	-- Invisible Abyss Barrier at end of Biome 5
	local endZ = BiomeConfig[#BiomeConfig].zEnd + 6
	local endBarrier = makeBlock({
		name = "EndOfWorldWall",
		size = Vector3.new(mapWidth + 24, 42, 8),
		cframe = CFrame.new(0, 21, endZ),
		color = Color3.fromRGB(32, 24, 34),
		canCollide = true,
		canQuery = false,
		transparency = 1,
		parent = biomesFolder,
	})
	endBarrier.CastShadow = false

	makeBlock({
		name = "EndOfWorldCurb",
		size = Vector3.new(mapWidth, 1.0, 4),
		cframe = CFrame.new(0, 0.35, endZ - 6),
		color = Color3.fromRGB(255, 108, 42),
		material = Enum.Material.Basalt,
		studded = true,
		parent = biomesFolder,
	})

	return biomesFolder
end

return BlockyMapBiomeGenerator
