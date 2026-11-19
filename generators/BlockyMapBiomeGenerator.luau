--!strict
-- BlockyMapBiomeGenerator.luau
-- Full Voxel Environment Generator for all 5 Stylized Biomes (PineWoods, MangroveSwamp, SavannaCamp, AlpinePeaks, VolcanicJungle)
-- Features stepped voxel strata terraces, variegated mosaic ground & paths, waterfalls/lavafalls,
-- flanking floating sky islands, foreground/midground/background composition, and warm reference lighting.
-- STRICT RULE: Main pathways, floors, terrace bases, bridges, CrateSpawns, PoacherPatrol & EndOfWorldWall stay intact & unobstructed.
-- All decorative assets strictly enforce CanCollide = false, CanQuery = false, CanTouch = false.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local DefaultBuilder = require(ReplicatedStorage.Modules.ClassicStudBiomeBuilder)

local BlockyMapBiomeGenerator = {}

type TerraceSeg = {
	zCenter: number,
	t1X: number,
	t1Y: number,
	t2X: number,
	t2Y: number,
	t3X: number,
	t3Y: number,
}

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
	local mat = props.material or Enum.Material.Plastic
	p.Material = mat
	if props.materialVariant and props.materialVariant ~= "" then
		p.MaterialVariant = props.materialVariant
	elseif props.studded ~= false and mat == Enum.Material.Plastic then
		p.MaterialVariant = "Studs"
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

local function placeDecorModel(model: Model, parent: Instance): Model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

local function addBiomeDividerLine(zPos: number, biome: any, parent: Instance)
	makeBlock({
		name = "BiomeDivider_" .. biome.id,
		size = Vector3.new(188, 0.25, 2.2),
		cframe = CFrame.new(0, 0.24, zPos),
		color = biome.accentColor,
		material = Enum.Material.SmoothPlastic,
		studded = false,
		canCollide = false,
		canQuery = false,
		canTouch = false,
		parent = parent,
	})
end

local function addSurfaceParticles(part: BasePart, rate: number, colA: Color3, colB: Color3, sizeSeq: NumberSequence, dir: Enum.NormalId, lightEmit: number, speed: NumberRange, life: NumberRange)
	local em = Instance.new("ParticleEmitter")
	em.Name = "EnvParticle"
	em.Color = ColorSequence.new(colA, colB)
	em.Rate = rate
	em.Size = sizeSeq
	em.EmissionDirection = dir
	em.LightEmission = lightEmit
	em.Speed = speed
	em.Lifetime = life
	em.SpreadAngle = Vector2.new(45, 45)
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	em.Parent = part
end

-- ============================================================================
-- DYNAMIC SCALE VARIATION HELPERS
-- ============================================================================

local function randTreeScale(rng: Random): number
	local r = rng:NextNumber()
	if r < 0.26 then
		return rng:NextNumber(0.68, 0.85)
	elseif r < 0.74 then
		return rng:NextNumber(0.95, 1.25)
	else
		return rng:NextNumber(1.38, 1.78)
	end
end

local function randFloraScale(rng: Random): number
	local r = rng:NextNumber()
	if r < 0.34 then
		return rng:NextNumber(0.68, 0.88)
	elseif r < 0.80 then
		return rng:NextNumber(0.95, 1.22)
	else
		return rng:NextNumber(1.32, 1.65)
	end
end

local function randRockScale(rng: Random): number
	local r = rng:NextNumber()
	if r < 0.32 then
		return rng:NextNumber(0.65, 0.86)
	elseif r < 0.76 then
		return rng:NextNumber(0.95, 1.25)
	else
		return rng:NextNumber(1.38, 1.82)
	end
end

-- ============================================================================
-- STEPPED VOXEL TERRACES, WATERFALLS & VARIEGATED MOSAIC FLOOR
-- ============================================================================

local TERRACE_PALETTES = {
	PineWoods = {
		strataA = Color3.fromRGB(132, 86, 54),
		strataB = Color3.fromRGB(108, 70, 42),
		cap = Color3.fromRGB(86, 168, 68),
		capAlt = Color3.fromRGB(108, 188, 74),
		trailShades = { Color3.fromRGB(64, 134, 52), Color3.fromRGB(74, 148, 58), Color3.fromRGB(54, 118, 46) },
		floorShades = { Color3.fromRGB(98, 174, 72), Color3.fromRGB(78, 146, 62), Color3.fromRGB(116, 190, 78) },
		fallKind = "Water",
	},
	MangroveSwamp = {
		strataA = Color3.fromRGB(88, 66, 46),
		strataB = Color3.fromRGB(68, 52, 36),
		cap = Color3.fromRGB(88, 132, 62),
		capAlt = Color3.fromRGB(74, 108, 52),
		trailShades = { Color3.fromRGB(108, 78, 52), Color3.fromRGB(92, 66, 44), Color3.fromRGB(118, 114, 104) },
		floorShades = { Color3.fromRGB(82, 108, 56), Color3.fromRGB(94, 72, 48), Color3.fromRGB(68, 118, 64) },
		fallKind = "Water",
	},
	SavannaCamp = {
		strataA = Color3.fromRGB(224, 164, 88),
		strataB = Color3.fromRGB(186, 108, 54),
		cap = Color3.fromRGB(238, 198, 108),
		capAlt = Color3.fromRGB(224, 178, 92),
		trailShades = { Color3.fromRGB(224, 174, 84), Color3.fromRGB(236, 188, 96), Color3.fromRGB(204, 148, 72) },
		floorShades = { Color3.fromRGB(234, 192, 102), Color3.fromRGB(214, 164, 82), Color3.fromRGB(242, 206, 118) },
		fallKind = "Water",
	},
	AlpinePeaks = {
		strataA = Color3.fromRGB(122, 186, 232),
		strataB = Color3.fromRGB(94, 152, 204),
		cap = Color3.fromRGB(238, 246, 255),
		capAlt = Color3.fromRGB(198, 230, 250),
		trailShades = { Color3.fromRGB(112, 184, 240), Color3.fromRGB(142, 204, 248), Color3.fromRGB(182, 224, 252) },
		floorShades = { Color3.fromRGB(232, 244, 255), Color3.fromRGB(192, 226, 248), Color3.fromRGB(244, 250, 255) },
		fallKind = "Water",
	},
	VolcanicJungle = {
		strataA = Color3.fromRGB(54, 44, 58),
		strataB = Color3.fromRGB(38, 30, 42),
		cap = Color3.fromRGB(68, 54, 72),
		capAlt = Color3.fromRGB(48, 38, 52),
		trailShades = { Color3.fromRGB(72, 62, 74), Color3.fromRGB(58, 50, 62), Color3.fromRGB(84, 72, 86) },
		floorShades = { Color3.fromRGB(52, 42, 54), Color3.fromRGB(68, 54, 68), Color3.fromRGB(42, 34, 46) },
		fallKind = "Lava",
	},
}

local function buildTerracesAndMosaic(biome: any, terrainGroup: Folder, propsFolder: Folder, rng: Random): { [number]: { TerraceSeg } }
	local pal = TERRACE_PALETTES[biome.id] or TERRACE_PALETTES.PineWoods
	local lenZ = biome.zEnd - biome.zStart
	local centerZ = (biome.zStart + biome.zEnd) * 0.5

	-- Central Road Mosaic Tiles (subtle color checkerboard along ExpeditionTrail, non-colliding thin veneer at Y = 0.43)
	for z = biome.zStart + 6, biome.zEnd - 6, 12 do
		for rowXIdx, tx in ipairs({ -12.5, -4.2, 4.2, 12.5 }) do
			if rng:NextNumber() < 0.72 then
				local col = pal.trailShades[rng:NextInteger(1, #pal.trailShades)]
				makeBlock({
					name = "TrailMosaicTile",
					size = Vector3.new(7.8, 0.06, 11.4),
					cframe = CFrame.new(tx, 0.43, z),
					color = col,
					studded = true,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = terrainGroup,
				})
			end
		end
	end

	-- Flanking Floor Mosaic Tiles & Subtle Glow/Water Accents
	for z = biome.zStart + 9, biome.zEnd - 9, 18 do
		for _, cx in ipairs({ -44, -27, 27, 44 }) do
			local col = pal.floorShades[rng:NextInteger(1, #pal.floorShades)]
			makeBlock({
				name = "FloorMosaicTile",
				size = Vector3.new(15.5, 0.14, 16.5),
				cframe = CFrame.new(cx, 0.06, z),
				color = col,
				studded = true,
				canCollide = false,
				canQuery = false,
				canTouch = false,
				parent = terrainGroup,
			})
		end
	end

	-- Biome-specific flanking floor surface features (lagoons, lava veins, ice sheets, moss pools)
	if biome.id == "PineWoods" then
		for z = biome.zStart + 60, biome.zEnd - 60, 110 do
			local side = if math.floor(z) % 2 == 0 then 1 else -1
			makeBlock({
				name = "ForestMossClearing",
				size = Vector3.new(24, 0.24, 22),
				cframe = CFrame.new(side * 38, 0.14, z),
				color = Color3.fromRGB(118, 206, 78),
				studded = true,
				canCollide = false,
				canQuery = false,
				canTouch = false,
				parent = terrainGroup,
			})
		end
	elseif biome.id == "MangroveSwamp" then
		for z = biome.zStart + 42, biome.zEnd - 42, 74 do
			local side = if (math.floor(z / 74) % 2 == 0) then 1 else -1
			local poolX = side * 38
			makeBlock({
				name = "SwampMudRim",
				size = Vector3.new(32, 0.32, 42),
				cframe = CFrame.new(poolX, 0.14, z),
				color = Color3.fromRGB(68, 52, 34),
				studded = true,
				parent = terrainGroup,
			})
			makeBlock({
				name = "SwampLagoonWater",
				size = Vector3.new(26, 0.36, 34),
				cframe = CFrame.new(poolX, 0.19, z),
				color = Color3.fromRGB(54, 152, 126),
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
				size = Vector3.new(7, 0.55, 7),
				cframe = CFrame.new(poolX - side * 5, 0.28, z + 4) * CFrame.Angles(0, 0.25, 0),
				color = Color3.fromRGB(92, 148, 68),
				studded = true,
				parent = terrainGroup,
			})
		end
	elseif biome.id == "SavannaCamp" then
		for z = biome.zStart + 70, biome.zEnd - 70, 140 do
			local oasisX = if (math.floor(z) % 280 < 140) then -38 else 38
			makeBlock({
				name = "OasisSandRim",
				size = Vector3.new(28, 0.32, 30),
				cframe = CFrame.new(oasisX, 0.16, z),
				color = Color3.fromRGB(238, 198, 112),
				studded = true,
				parent = terrainGroup,
			})
			makeBlock({
				name = "OasisWaterPoolSurface",
				size = Vector3.new(20, 0.38, 22),
				cframe = CFrame.new(oasisX, 0.22, z),
				color = Color3.fromRGB(52, 198, 228),
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
		for z = biome.zStart + 48, biome.zEnd - 48, 86 do
			local side = if (math.floor(z / 86) % 2 == 0) then 1 else -1
			makeBlock({
				name = "GlacierIcePool",
				size = Vector3.new(26, 0.36, 36),
				cframe = CFrame.new(side * 38, 0.18, z),
				color = Color3.fromRGB(98, 204, 250),
				material = Enum.Material.Ice,
				studded = false,
				canCollide = false,
				canQuery = false,
				canTouch = false,
				parent = terrainGroup,
			})
		end
	elseif biome.id == "VolcanicJungle" then
		-- Magma road edge glow cracks (very low profile, walkable floor underneath)
		for _, curbEdgeX in ipairs({ -18.8, 18.8 }) do
			makeBlock({
				name = "RoadsideLavaGlow",
				size = Vector3.new(2.2, 0.16, lenZ - 12),
				cframe = CFrame.new(curbEdgeX, 0.12, centerZ),
				color = Color3.fromRGB(255, 112, 24),
				material = Enum.Material.Neon,
				studded = false,
				canCollide = false,
				canQuery = false,
				canTouch = false,
				parent = terrainGroup,
			})
		end
		-- Flanking molten lava pools & safe basalt stepping paths
		for z = biome.zStart + 50, biome.zEnd - 50, 82 do
			for _, side in ipairs({ -1, 1 }) do
				makeBlock({
					name = "FlankLavaChannel",
					size = Vector3.new(24, 0.16, 48),
					cframe = CFrame.new(side * 36, 0.10, z),
					color = Color3.fromRGB(255, 96, 22),
					material = Enum.Material.Neon,
					studded = false,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = terrainGroup,
				})
				makeBlock({
					name = "BasaltSteppingSlab",
					size = Vector3.new(12, 0.65, 14),
					cframe = CFrame.new(side * 36, 0.30, z + 6),
					color = Color3.fromRGB(54, 44, 58),
					studded = true,
					parent = terrainGroup,
				})
			end
		end
	end

	-- 3-Tier Stepped Voxel Terraces flanking both sides (Replaces flat 24-stud CliffWall!)
	local segMap: { [number]: { TerraceSeg } } = { [-1] = {}, [1] = {} }
	local segLen = 26
	local segCount = math.max(8, math.floor(lenZ / segLen))
	local actualSegLen = lenZ / segCount

	for _, sideSign in ipairs({ -1, 1 }) do
		for i = 1, segCount do
			local zC = biome.zStart + (i - 0.5) * actualSegLen
			local t1H = rng:NextNumber(3.6, 5.0)
			local t2H = rng:NextNumber(8.2, 10.6)
			local t3H = rng:NextNumber(13.6, 17.4)

			local t1InX = sideSign * (52 + rng:NextNumber(-3, 3))
			local t2InX = sideSign * (68 + rng:NextNumber(-3, 3))
			local t3InX = sideSign * (88 + rng:NextNumber(-3, 3))

			local t1W = 24
			local t2W = 26
			local t3W = 36

			local t1CenterX = t1InX + sideSign * (t1W * 0.5)
			local t2CenterX = t2InX + sideSign * (t2W * 0.5)
			local t3CenterX = t3InX + sideSign * (t3W * 0.5)

			-- Tier 1
			makeBlock({
				name = "Terrace1_Strata",
				size = Vector3.new(t1W, t1H - 0.9, actualSegLen + 0.6),
				cframe = CFrame.new(t1CenterX, (t1H - 0.9) * 0.5, zC),
				color = pal.strataA,
				canQuery = false,
				parent = terrainGroup,
			})
			makeBlock({
				name = "Terrace1_Cap",
				size = Vector3.new(t1W + 1.2, 0.9, actualSegLen + 0.8),
				cframe = CFrame.new(t1CenterX - sideSign * 0.3, t1H - 0.45, zC),
				color = if i % 2 == 0 then pal.cap else pal.capAlt,
				parent = terrainGroup,
			})

			-- Tier 2
			makeBlock({
				name = "Terrace2_Strata",
				size = Vector3.new(t2W, t2H - 1.0, actualSegLen + 0.6),
				cframe = CFrame.new(t2CenterX, (t2H - 1.0) * 0.5, zC),
				color = pal.strataB,
				canQuery = false,
				parent = terrainGroup,
			})
			makeBlock({
				name = "Terrace2_Cap",
				size = Vector3.new(t2W + 1.2, 1.0, actualSegLen + 0.8),
				cframe = CFrame.new(t2CenterX - sideSign * 0.3, t2H - 0.5, zC),
				color = if i % 2 == 1 then pal.cap else pal.capAlt,
				parent = terrainGroup,
			})

			-- Tier 3 Outer Horizon Ridge (keeps sky open above Y ~ 16 so floating islands shine!)
			makeBlock({
				name = "Terrace3_Strata",
				size = Vector3.new(t3W, t3H - 1.2, actualSegLen + 0.6),
				cframe = CFrame.new(t3CenterX, (t3H - 1.2) * 0.5, zC),
				color = if i % 2 == 0 then pal.strataA else pal.strataB,
				canQuery = false,
				parent = terrainGroup,
			})
			makeBlock({
				name = "Terrace3_Cap",
				size = Vector3.new(t3W + 1.4, 1.2, actualSegLen + 0.8),
				cframe = CFrame.new(t3CenterX - sideSign * 0.4, t3H - 0.6, zC),
				color = pal.cap,
				canQuery = false,
				parent = terrainGroup,
			})

			table.insert(segMap[sideSign], {
				zCenter = zC,
				t1X = t1InX + sideSign * 8,
				t1Y = t1H,
				t2X = t2InX + sideSign * 10,
				t2Y = t2H,
				t3X = t3InX + sideSign * 12,
				t3Y = t3H,
			})
		end

		-- Add 1 dramatic Terrace Cascade Waterfall / Lavafall per side flowing down the steps!
		local fallIdx = if sideSign == -1 then math.max(2, math.floor(segCount * 0.35)) else math.max(3, math.floor(segCount * 0.72))
		local fSeg = segMap[sideSign][fallIdx]
		if fSeg then
			local startX = fSeg.t3X - sideSign * 10
			local endX = fSeg.t1X - sideSign * 10
			local midX = (startX + endX) * 0.5
			if pal.fallKind == "Lava" then
				local fall = makeBlock({
					name = "TerraceLavaCascade",
					size = Vector3.new(math.abs(startX - endX) + 4, fSeg.t3Y + 0.5, 7.5),
					cframe = CFrame.new(midX, fSeg.t3Y * 0.5, fSeg.zCenter),
					color = Color3.fromRGB(255, 108, 24),
					material = Enum.Material.Neon,
					studded = false,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = propsFolder,
				})
				addSurfaceParticles(fall, 5, Color3.fromRGB(255, 210, 64), Color3.fromRGB(255, 74, 22), NumberSequence.new(0.3, 0.05), Enum.NormalId.Top, 0.8, NumberRange.new(2, 4), NumberRange.new(1, 2))
			else
				local fall = makeBlock({
					name = "TerraceWaterfall",
					size = Vector3.new(3.2, fSeg.t3Y + 0.5, 7.5),
					cframe = CFrame.new(midX, fSeg.t3Y * 0.5, fSeg.zCenter),
					color = Color3.fromRGB(74, 206, 250),
					material = Enum.Material.Glass,
					studded = false,
					transparency = 0.22,
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = propsFolder,
				})
				makeBlock({
					name = "WaterfallSplashFoam",
					size = Vector3.new(8.5, 0.75, 10.5),
					cframe = CFrame.new(endX - sideSign * 4, 0.42, fSeg.zCenter),
					color = Color3.fromRGB(238, 250, 255),
					canCollide = false,
					canQuery = false,
					canTouch = false,
					parent = propsFolder,
				})
				addSurfaceParticles(fall, 6, Color3.fromRGB(220, 248, 255), Color3.fromRGB(255, 255, 255), NumberSequence.new(0.8, 2.0), Enum.NormalId.Top, 0.2, NumberRange.new(1.5, 3.5), NumberRange.new(1, 1.8))
			end
		end
	end

	return segMap
end

-- ============================================================================
-- BIOME-SPECIFIC DENSE FOREGROUND / MIDGROUND / TERRACE COMPOSITION
-- ============================================================================

local function populatePineWoodsDecor(propsFolder: Folder, biome: any, segMap: { [number]: { TerraceSeg } }, builder: any, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	-- Horizon Archway framing entry
	placeDecorModel(builder.BuildBiomeHorizonArchway(CFrame.new(0, 0.25, biome.zStart + 10), 1.0, propsFolder, "PineWoods"), propsFolder)

	-- Hero Left: Forest Watchtower + Ranger Campsite (placed neatly on flat left pocket)
	local towerZ = biome.zStart + lenZ * 0.34
	placeDecorModel(builder.BuildVoxelWatchtower(CFrame.new(-35, 0, towerZ) * CFrame.Angles(0, math.rad(15), 0), 1.35, propsFolder, "Forest"), propsFolder)
	placeDecorModel(builder.BuildTreeStump(CFrame.new(-42, 0, towerZ + 14), 1.15, propsFolder), propsFolder)
	placeDecorModel(builder.BuildFallenHollowLog(CFrame.new(-32, 0, towerZ + 18) * CFrame.Angles(0, 0.4, 0), 1.15, propsFolder), propsFolder)

	-- Hero Right: Stream, Small Arched Wood Bridge & Grove
	local streamZ = biome.zStart + lenZ * 0.62
	placeDecorModel(builder.BuildForestStreamAndBridge(CFrame.new(36, 0.05, streamZ) * CFrame.Angles(0, math.rad(90), 0), 1.32, propsFolder), propsFolder)
	placeDecorModel(builder.BuildLushVoxelTreeWithVines(CFrame.new(44, 0, streamZ - 26), 1.38, propsFolder), propsFolder)

	-- Roadside Foreground: Wood Fences + Glowing Lanterns & Wildflowers every ~44 studs
	for z = biome.zStart + 26, biome.zEnd - 22, 44 do
		placeDecorModel(builder.BuildVoxelFenceWithLantern(CFrame.new(-20.5, 0.25, z) * CFrame.Angles(0, math.rad(90), 0), 0.92, propsFolder), propsFolder)
		placeDecorModel(builder.BuildVoxelFenceWithLantern(CFrame.new(20.5, 0.25, z + 22) * CFrame.Angles(0, math.rad(90), 0), 0.92, propsFolder), propsFolder)
		placeDecorModel(builder.BuildWildflowerPatch(CFrame.new(-24, 0, z + 10) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
		placeDecorModel(builder.BuildWildflowerPatch(CFrame.new(24, 0, z - 6) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
	end

	-- Midground & Upper Terrace Dense Vegetation
	local trees = { builder.BuildLushVoxelTreeWithVines, builder.BuildPineTreeTall, builder.BuildPineTreeTwin, builder.BuildOakTreeBroad, builder.BuildBirchTreeForest }
	local flora = { builder.BuildWildflowerPatch, builder.BuildBerryBush, builder.BuildFernCluster, builder.BuildGrassTuftCluster, builder.BuildMushroomCluster }
	local props = { builder.BuildMossyBoulder, builder.BuildRockCluster, builder.BuildTreeStump, builder.BuildFallenHollowLog }

	for _, sideSign in ipairs({ -1, 1 }) do
		for _, seg in ipairs(segMap[sideSign]) do
			-- Avoid crowding hero structures directly
			local skipHeroL = (sideSign == -1 and math.abs(seg.zCenter - towerZ) < 18)
			local skipHeroR = (sideSign == 1 and math.abs(seg.zCenter - streamZ) < 18)

			if not skipHeroL and not skipHeroR then
				local fx = sideSign * rng:NextNumber(26, 46)
				local fz = seg.zCenter + rng:NextNumber(-8, 8)
				if rng:NextNumber() < 0.65 then
					local tFn = trees[rng:NextInteger(1, #trees)]
					placeDecorModel(tFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
				else
					local pFn = props[rng:NextInteger(1, #props)]
					placeDecorModel(pFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randRockScale(rng), propsFolder), propsFolder)
				end
				local flFn = flora[rng:NextInteger(1, #flora)]
				placeDecorModel(flFn(CFrame.new(sideSign * rng:NextNumber(22, 47), 0, seg.zCenter + rng:NextNumber(-9, 9)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randFloraScale(rng), propsFolder), propsFolder)
			end

			-- Tier 1 Top Dressing (grounded strictly at seg.t1Y)
			if rng:NextNumber() < 0.85 then
				local tFn1 = trees[rng:NextInteger(1, #trees)]
				placeDecorModel(tFn1(CFrame.new(seg.t1X, seg.t1Y, seg.zCenter + rng:NextNumber(-7, 7)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 0.9, propsFolder), propsFolder)
			end
			local fl1 = flora[rng:NextInteger(1, #flora)]
			placeDecorModel(fl1(CFrame.new(seg.t1X - sideSign * 3, seg.t1Y, seg.zCenter + rng:NextNumber(-7, 7)), randFloraScale(rng), propsFolder), propsFolder)

			-- Tier 2 & Tier 3 Background Skyline Trees (grounded at seg.t2Y / seg.t3Y)
			local tFn2 = trees[rng:NextInteger(1, #trees)]
			placeDecorModel(tFn2(CFrame.new(seg.t2X, seg.t2Y, seg.zCenter + rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.1, propsFolder), propsFolder)

			local tFn3 = trees[rng:NextInteger(1, #trees)]
			placeDecorModel(tFn3(CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.25, propsFolder), propsFolder)
		end
	end
end

local function populateMangroveSwampDecor(propsFolder: Folder, biome: any, segMap: { [number]: { TerraceSeg } }, builder: any, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	placeDecorModel(builder.BuildBiomeHorizonArchway(CFrame.new(0, 0.25, biome.zStart + 10), 1.0, propsFolder, "MangroveSwamp"), propsFolder)

	-- Hero Left: Swamp Totem Shrine & Banyan Vine Tree
	local shrineZ = biome.zStart + lenZ * 0.34
	placeDecorModel(builder.BuildSwampTotemShrine(CFrame.new(-38, 0, shrineZ) * CFrame.Angles(0, math.rad(25), 0), 1.32, propsFolder), propsFolder)
	placeDecorModel(builder.BuildSwampBanyanVineTree(CFrame.new(-44, 0, shrineZ + 22), 1.45, propsFolder), propsFolder)

	-- Hero Right: Swamp Watchtower + Wooden Cabin & Dock over Lagoon
	local towerZ = biome.zStart + lenZ * 0.30
	placeDecorModel(builder.BuildVoxelWatchtower(CFrame.new(37, 0, towerZ) * CFrame.Angles(0, math.rad(-18), 0), 1.32, propsFolder, "Swamp"), propsFolder)
	local cabinZ = biome.zStart + lenZ * 0.66
	placeDecorModel(builder.BuildSwampWoodenCabinDock(CFrame.new(38, 0.15, cabinZ) * CFrame.Angles(0, math.rad(15), 0), 1.28, propsFolder), propsFolder)

	-- Roadside Foreground: Cross-Arm Lantern Posts, Cattail Reeds & Lily Pads
	for z = biome.zStart + 28, biome.zEnd - 24, 48 do
		placeDecorModel(builder.BuildSwampCrossLanternPost(CFrame.new(-20.5, 0.25, z), 0.92, propsFolder), propsFolder)
		placeDecorModel(builder.BuildSwampCrossLanternPost(CFrame.new(20.5, 0.25, z + 24) * CFrame.Angles(0, math.pi, 0), 0.92, propsFolder), propsFolder)
		placeDecorModel(builder.BuildCattailReedCluster(CFrame.new(-25, 0, z + 10), randFloraScale(rng), propsFolder), propsFolder)
		placeDecorModel(builder.BuildSwampLilyPadCluster(CFrame.new(28, 0.18, z - 8), randFloraScale(rng), propsFolder), propsFolder)
	end

	local trees = { builder.BuildSwampBanyanVineTree, builder.BuildMangroveTreeArch, builder.BuildDeadSwampWillow }
	local flora = { builder.BuildGiantGlowMushroom, builder.BuildSwampLilyPadCluster, builder.BuildCattailReedCluster, builder.BuildGlowSporeTrio, builder.BuildSwampVineFern }
	local props = { builder.BuildSunkenHollowLog, builder.BuildMossySwampBoulder, builder.BuildWoodenSwampDock }

	for _, sideSign in ipairs({ -1, 1 }) do
		for i, seg in ipairs(segMap[sideSign]) do
			local skipHero = (sideSign == -1 and math.abs(seg.zCenter - shrineZ) < 18)
				or (sideSign == 1 and (math.abs(seg.zCenter - towerZ) < 16 or math.abs(seg.zCenter - cabinZ) < 18))

			if not skipHero then
				local fx = sideSign * rng:NextNumber(26, 46)
				local fz = seg.zCenter + rng:NextNumber(-8, 8)
				if i % 2 == 0 then
					local tFn = trees[rng:NextInteger(1, #trees)]
					placeDecorModel(tFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
				else
					local pFn = props[rng:NextInteger(1, #props)]
					placeDecorModel(pFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randRockScale(rng), propsFolder), propsFolder)
				end
				local flFn = flora[rng:NextInteger(1, #flora)]
				placeDecorModel(flFn(CFrame.new(sideSign * rng:NextNumber(23, 47), 0.12, seg.zCenter + rng:NextNumber(-9, 9)), randFloraScale(rng), propsFolder), propsFolder)
			end

			-- Tier 1..3 Swamp Skyline
			local t1 = trees[rng:NextInteger(1, #trees)]
			placeDecorModel(t1(CFrame.new(seg.t1X, seg.t1Y, seg.zCenter + rng:NextNumber(-7, 7)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 0.92, propsFolder), propsFolder)
			local t2 = if i % 3 == 0 then builder.BuildGiantGlowMushroom else trees[rng:NextInteger(1, #trees)]
			placeDecorModel(t2(CFrame.new(seg.t2X, seg.t2Y, seg.zCenter + rng:NextNumber(-7, 7)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.1, propsFolder), propsFolder)
			local t3 = builder.BuildSwampBanyanVineTree
			if i % 2 == 1 then
				placeDecorModel(t3(CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-7, 7)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.25, propsFolder), propsFolder)
			end
		end
	end
end

local function populateSavannaCampDecor(propsFolder: Folder, biome: any, segMap: { [number]: { TerraceSeg } }, builder: any, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	placeDecorModel(builder.BuildBiomeHorizonArchway(CFrame.new(0, 0.25, biome.zStart + 10), 1.0, propsFolder, "SavannaCamp"), propsFolder)

	-- Hero Left: Desert Watchtower & Step Pyramid
	local towerZ = biome.zStart + lenZ * 0.26
	placeDecorModel(builder.BuildVoxelWatchtower(CFrame.new(-35, 0, towerZ) * CFrame.Angles(0, math.rad(14), 0), 1.32, propsFolder, "Desert"), propsFolder)
	local pyrZ = biome.zStart + lenZ * 0.56
	placeDecorModel(builder.BuildDesertStepPyramid(CFrame.new(-42, 0, pyrZ), 1.32, propsFolder), propsFolder)

	-- Hero Right: Sandstone Ruin Arch & Oasis Water Pool with Palms
	local ruinZ = biome.zStart + lenZ * 0.36
	placeDecorModel(builder.BuildDesertStoneArchRuin(CFrame.new(36, 0, ruinZ) * CFrame.Angles(0, math.rad(-25), 0), 1.28, propsFolder), propsFolder)
	local oasisZ = biome.zStart + lenZ * 0.72
	placeDecorModel(builder.BuildOasisWaterPool(CFrame.new(40, 0, oasisZ), 1.25, propsFolder), propsFolder)
	placeDecorModel(builder.BuildDesertPalmTree(CFrame.new(47, 0, oasisZ + 8), 1.45, propsFolder), propsFolder)
	placeDecorModel(builder.BuildDesertPalmTree(CFrame.new(33, 0, oasisZ - 8), 1.15, propsFolder), propsFolder)

	-- Roadside Foreground: Pedestal Lanterns, Flowering Cacti & Deadwood Scrubs
	for z = biome.zStart + 26, biome.zEnd - 22, 46 do
		placeDecorModel(builder.BuildDesertPedestalLantern(CFrame.new(-20.5, 0.25, z), 0.95, propsFolder), propsFolder)
		placeDecorModel(builder.BuildDesertPedestalLantern(CFrame.new(20.5, 0.25, z + 23), 0.95, propsFolder), propsFolder)
		placeDecorModel(builder.BuildVoxelFlowerCactus(CFrame.new(-24, 0, z + 11) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
		placeDecorModel(builder.BuildDesertDeadScrub(CFrame.new(24, 0, z - 8) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
	end

	local cactiAndTrees = { builder.BuildVoxelFlowerCactus, builder.BuildSaguaroCactusGiant, builder.BuildAcaciaTreeFlat, builder.BuildDesertPalmTree }
	local flora = { builder.BuildBarrelCactusCluster, builder.BuildSavannaGrassTuft, builder.BuildDesertDeadScrub, builder.BuildDesertScrubBush }
	local props = { builder.BuildSandstoneRuinedPillar, builder.BuildDesertSkullBone }

	for _, sideSign in ipairs({ -1, 1 }) do
		for i, seg in ipairs(segMap[sideSign]) do
			local skipHero = (sideSign == -1 and (math.abs(seg.zCenter - towerZ) < 16 or math.abs(seg.zCenter - pyrZ) < 22))
				or (sideSign == 1 and (math.abs(seg.zCenter - ruinZ) < 16 or math.abs(seg.zCenter - oasisZ) < 20))

			if not skipHero then
				local fx = sideSign * rng:NextNumber(26, 46)
				local fz = seg.zCenter + rng:NextNumber(-8, 8)
				if i % 3 == 0 then
					local pFn = props[rng:NextInteger(1, #props)]
					placeDecorModel(pFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randRockScale(rng), propsFolder), propsFolder)
				else
					local cFn = cactiAndTrees[rng:NextInteger(1, #cactiAndTrees)]
					placeDecorModel(cFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
				end
				local flFn = flora[rng:NextInteger(1, #flora)]
				placeDecorModel(flFn(CFrame.new(sideSign * rng:NextNumber(22, 47), 0, seg.zCenter + rng:NextNumber(-8, 8)), randFloraScale(rng), propsFolder), propsFolder)
			end

			-- Tier 1..3 Cacti, Mesa Arches & Acacias
			local c1 = cactiAndTrees[rng:NextInteger(1, #cactiAndTrees)]
			placeDecorModel(c1(CFrame.new(seg.t1X, seg.t1Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
			local c2 = if i % 4 == 0 then builder.BuildSandstoneMesaArch else cactiAndTrees[rng:NextInteger(1, #cactiAndTrees)]
			placeDecorModel(c2(CFrame.new(seg.t2X, seg.t2Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.1, propsFolder), propsFolder)
			if i % 2 == 0 then
				placeDecorModel(builder.BuildSaguaroCactusGiant(CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.25, propsFolder), propsFolder)
			end
		end
	end
end

local function populateAlpinePeaksDecor(propsFolder: Folder, biome: any, segMap: { [number]: { TerraceSeg } }, builder: any, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	placeDecorModel(builder.BuildBiomeHorizonArchway(CFrame.new(0, 0.25, biome.zStart + 10), 1.0, propsFolder, "AlpinePeaks"), propsFolder)

	-- Subtle Overhead Falling Snow Anchor over the middle of AlpinePeaks
	local snowCloud = makeBlock({
		name = "AlpineSnowEmitterAnchor",
		size = Vector3.new(120, 1, 220),
		cframe = CFrame.new(0, 42, biome.zStart + lenZ * 0.5),
		color = Color3.new(1, 1, 1),
		transparency = 1,
		canCollide = false,
		canQuery = false,
		canTouch = false,
		parent = propsFolder,
	})
	addSurfaceParticles(snowCloud, 14, Color3.fromRGB(240, 248, 255), Color3.fromRGB(204, 236, 255), NumberSequence.new(0.28, 0.14), Enum.NormalId.Bottom, 0.3, NumberRange.new(4, 7), NumberRange.new(4.5, 6.5))

	-- Hero Left: Cozy Snow Igloo + Friendly Voxel Snowman + Ice Crystals
	local iglooZ = biome.zStart + lenZ * 0.34
	placeDecorModel(builder.BuildVoxelSnowIgloo(CFrame.new(-38, 0, iglooZ) * CFrame.Angles(0, math.rad(135), 0), 1.32, propsFolder), propsFolder)
	placeDecorModel(builder.BuildVoxelSnowman(CFrame.new(-28, 0, iglooZ - 10) * CFrame.Angles(0, math.rad(145), 0), 1.22, propsFolder), propsFolder)

	-- Hero Right: Frozen Icicle Pergola & Giant Ice Crystal Spire
	local pergZ = biome.zStart + lenZ * 0.52
	placeDecorModel(builder.BuildFrozenIciclePergola(CFrame.new(36, 0, pergZ) * CFrame.Angles(0, math.rad(-25), 0), 1.32, propsFolder), propsFolder)
	local spireZ = biome.zStart + lenZ * 0.78
	placeDecorModel(builder.BuildGiantIceCrystalSpire(CFrame.new(44, 0, spireZ), 1.4, propsFolder), propsFolder)

	-- Roadside Foreground: Cyan Glowing Frost Lanterns & Ice Crystal Clusters
	for z = biome.zStart + 26, biome.zEnd - 22, 46 do
		placeDecorModel(builder.BuildAlpineCyanLantern(CFrame.new(-20.5, 0.25, z), 0.95, propsFolder), propsFolder)
		placeDecorModel(builder.BuildAlpineCyanLantern(CFrame.new(20.5, 0.25, z + 23), 0.95, propsFolder), propsFolder)
		placeDecorModel(builder.BuildIceCrystalCluster(CFrame.new(-24, 0, z + 11) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
		placeDecorModel(builder.BuildIceCrystalCluster(CFrame.new(24, 0, z - 8) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
	end

	local trees = { builder.BuildSnowyPineTreeTall, builder.BuildSnowyPineTreeTwin, builder.BuildFrostedBirchTree }
	local flora = { builder.BuildIceCrystalCluster, builder.BuildCrystalFrostFlower, builder.BuildIceBerryBush, builder.BuildFrostGrassTuft }
	local props = { builder.BuildGlacierBoulderSnowy, builder.BuildAlpineStoneCairn, builder.BuildFrozenHollowLog }

	for _, sideSign in ipairs({ -1, 1 }) do
		for i, seg in ipairs(segMap[sideSign]) do
			local skipHero = (sideSign == -1 and math.abs(seg.zCenter - iglooZ) < 18)
				or (sideSign == 1 and (math.abs(seg.zCenter - pergZ) < 16 or math.abs(seg.zCenter - spireZ) < 18))

			if not skipHero then
				local fx = sideSign * rng:NextNumber(27, 46)
				local fz = seg.zCenter + rng:NextNumber(-8, 8)
				if i % 3 == 0 then
					local pFn = props[rng:NextInteger(1, #props)]
					placeDecorModel(pFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randRockScale(rng), propsFolder), propsFolder)
				else
					local tFn = trees[rng:NextInteger(1, #trees)]
					placeDecorModel(tFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
				end
				local flFn = flora[rng:NextInteger(1, #flora)]
				placeDecorModel(flFn(CFrame.new(sideSign * rng:NextNumber(22, 47), 0, seg.zCenter + rng:NextNumber(-8, 8)), randFloraScale(rng), propsFolder), propsFolder)
			end

			-- Tier 1..3 Snowy Pines & Ice Spires
			local t1 = trees[rng:NextInteger(1, #trees)]
			placeDecorModel(t1(CFrame.new(seg.t1X, seg.t1Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
			local t2 = if i % 5 == 0 then builder.BuildGiantIceCrystalSpire else trees[rng:NextInteger(1, #trees)]
			placeDecorModel(t2(CFrame.new(seg.t2X, seg.t2Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.15, propsFolder), propsFolder)
			if i % 2 == 1 then
				local t3 = trees[rng:NextInteger(1, #trees)]
				placeDecorModel(t3(CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-6, 6)), randTreeScale(rng) * 1.3, propsFolder), propsFolder)
			end
		end
	end
end

local function populateVolcanicJungleDecor(propsFolder: Folder, biome: any, segMap: { [number]: { TerraceSeg } }, builder: any, rng: Random)
	local lenZ = biome.zEnd - biome.zStart

	placeDecorModel(builder.BuildBiomeHorizonArchway(CFrame.new(0, 0.25, biome.zStart + 10), 1.0, propsFolder, "VolcanicJungle"), propsFolder)

	-- Hero Left: Basalt Gate Ruin + Volcano Crater Landmark
	local gateZ = biome.zStart + lenZ * 0.30
	placeDecorModel(builder.BuildVolcanicBasaltGateRuin(CFrame.new(-36, 0, gateZ) * CFrame.Angles(0, math.rad(18), 0), 1.32, propsFolder), propsFolder)
	local craterZ = biome.zStart + lenZ * 0.62
	placeDecorModel(builder.BuildVolcanoCraterLandmark(CFrame.new(-44, 0, craterZ), 1.38, propsFolder), propsFolder)

	-- Hero Right: Obsidian Monolith Ruins
	local monoZ = biome.zStart + lenZ * 0.56
	placeDecorModel(builder.BuildObsidianMonolithRuins(CFrame.new(40, 0, monoZ) * CFrame.Angles(0, math.rad(-22), 0), 1.35, propsFolder), propsFolder)

	-- Roadside Foreground: Blazing Fire Brazier Pillars & Glowing Crimson Crystals
	for z = biome.zStart + 26, biome.zEnd - 22, 48 do
		placeDecorModel(builder.BuildVolcanicFireBrazierPillar(CFrame.new(-20.5, 0.25, z), 0.96, propsFolder), propsFolder)
		placeDecorModel(builder.BuildVolcanicFireBrazierPillar(CFrame.new(20.5, 0.25, z + 24), 0.96, propsFolder), propsFolder)
		placeDecorModel(builder.BuildCrimsonCrystalCluster(CFrame.new(-24.5, 0, z + 10) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
		placeDecorModel(builder.BuildCrimsonCrystalCluster(CFrame.new(24.5, 0, z - 8) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), randFloraScale(rng), propsFolder), propsFolder)
	end

	local trees = { builder.BuildVoxelCrimsonCanopyTree, builder.BuildCharredCrimsonTree, builder.BuildObsidianDeadTree, builder.BuildMagmaPalmTree }
	local flora = { builder.BuildCrimsonCrystalCluster, builder.BuildFirebloomFlowerPatch, builder.BuildAshEmberGrassTuft, builder.BuildScorchedThornBush }
	local props = { builder.BuildMagmaVentGeyser, builder.BuildLavaCrackedBoulder, builder.BuildVolcanicSkullBrazier }

	for _, sideSign in ipairs({ -1, 1 }) do
		for i, seg in ipairs(segMap[sideSign]) do
			local skipHero = (sideSign == -1 and (math.abs(seg.zCenter - gateZ) < 16 or math.abs(seg.zCenter - craterZ) < 20))
				or (sideSign == 1 and math.abs(seg.zCenter - monoZ) < 18)

			if not skipHero then
				local fx = sideSign * rng:NextNumber(27, 46)
				local fz = seg.zCenter + rng:NextNumber(-8, 8)
				if i % 3 == 0 then
					local pFn = props[rng:NextInteger(1, #props)]
					placeDecorModel(pFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randRockScale(rng), propsFolder), propsFolder)
				else
					local tFn = trees[rng:NextInteger(1, #trees)]
					placeDecorModel(tFn(CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
				end
				local flFn = flora[rng:NextInteger(1, #flora)]
				placeDecorModel(flFn(CFrame.new(sideSign * rng:NextNumber(22, 47), 0, seg.zCenter + rng:NextNumber(-8, 8)), randFloraScale(rng), propsFolder), propsFolder)
			end

			-- Tier 1..3 Crimson Trees, Monoliths & Magma Geysers
			local t1 = trees[rng:NextInteger(1, #trees)]
			placeDecorModel(t1(CFrame.new(seg.t1X, seg.t1Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng), propsFolder), propsFolder)
			local t2 = if i % 4 == 0 then builder.BuildMagmaVentGeyser else trees[rng:NextInteger(1, #trees)]
			placeDecorModel(t2(CFrame.new(seg.t2X, seg.t2Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.15, propsFolder), propsFolder)
			if i % 2 == 0 then
				local t3 = builder.BuildVoxelCrimsonCanopyTree
				placeDecorModel(t3(CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), randTreeScale(rng) * 1.25, propsFolder), propsFolder)
			end
		end
	end
end

-- ============================================================================
-- MAIN BUILDER ENTRY POINT
-- ============================================================================

function BlockyMapBiomeGenerator.Build(worldFolder: Folder, builderOverride: any?): Folder
	local builder = builderOverride or DefaultBuilder
	builder.EnsureClassicStudsVariant()
	builder.ApplyReferenceLighting()

	if not worldFolder:FindFirstChild("BrushedDecor") then
		local brushed = Instance.new("Folder")
		brushed.Name = "BrushedDecor"
		brushed.Parent = worldFolder
	end

	local skyFolder = worldFolder:FindFirstChild("SkyIslands")
	if not skyFolder then
		skyFolder = Instance.new("Folder")
		skyFolder.Name = "SkyIslands"
		skyFolder.Parent = worldFolder
	end
	for _, ch in ipairs(skyFolder:GetChildren()) do
		if string.sub(ch.Name, 1, 15) == "BiomeSkyIsland_" or ch.Name == "ColossalHorizonVolcano" then
			ch:Destroy()
		end
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

		local terrainGroup = Instance.new("Folder")
		terrainGroup.Name = "BlockyTerrain"
		terrainGroup.Parent = biomeModel

		-- Base Main Floor (Preserved exact bounds, height & collision)
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

		-- Floating Sky-Island Strata Under-Hull
		makeBlock({
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
		makeBlock({
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

		-- Central Expedition Pathway (Preserved exact X=0, Width=34, Y=0.2)
		makeBlock({
			name = "ExpeditionTrail",
			size = Vector3.new(34, 0.45, lenZ),
			cframe = CFrame.new(0, 0.2, centerZ),
			color = biome.accentColor,
			material = Enum.Material.Plastic,
			materialVariant = "Studs",
			studded = true,
			parent = terrainGroup,
		})
		for _, curbX in ipairs({ -17.5, 17.5 }) do
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

		if biome.order > 1 then
			addBiomeDividerLine(biome.zStart, biome, biomeModel)
		end

		local propsFolder = Instance.new("Folder")
		propsFolder.Name = "CuratedDecor"
		propsFolder.Parent = biomeModel

		local biomeRng = Random.new(biome.order * 1000 + 42)
		local segMap = buildTerracesAndMosaic(biome, terrainGroup, propsFolder, biomeRng)

		if biome.id == "PineWoods" then
			populatePineWoodsDecor(propsFolder, biome, segMap, builder, biomeRng)
		elseif biome.id == "MangroveSwamp" then
			populateMangroveSwampDecor(propsFolder, biome, segMap, builder, biomeRng)
		elseif biome.id == "SavannaCamp" then
			populateSavannaCampDecor(propsFolder, biome, segMap, builder, biomeRng)
		elseif biome.id == "AlpinePeaks" then
			populateAlpinePeaksDecor(propsFolder, biome, segMap, builder, biomeRng)
		elseif biome.id == "VolcanicJungle" then
			populateVolcanicJungleDecor(propsFolder, biome, segMap, builder, biomeRng)
		end

		-- Per-Biome Floating Sky Islands flanking left & right horizon (4 per biome, placed in SkyIslands for streaming)
		local skySpots = {
			{ x = -154, y = 36, z = biome.zStart + lenZ * 0.28, sc = 1.15, fall = true, fallSide = 1 },
			{ x = 158, y = 40, z = biome.zStart + lenZ * 0.48, sc = 1.25, fall = true, fallSide = -1 },
			{ x = -168, y = 46, z = biome.zStart + lenZ * 0.72, sc = 1.32, fall = false, fallSide = 1 },
			{ x = 162, y = 44, z = biome.zStart + lenZ * 0.88, sc = 1.18, fall = true, fallSide = -1 },
		}
		for _, ss in ipairs(skySpots) do
			placeDecorModel(
				builder.BuildBiomeFloatingSkyIsland(CFrame.new(ss.x, ss.y, ss.z), ss.sc, skyFolder, biome.id, ss.fall, ss.fallSide),
				skyFolder
			)
		end

		-- Deterministic Crate Spawn Anchors (safely on playable X = 20..48 ground)
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
			local sx = side * rng:NextNumber(20, 46)
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

		-- Poacher Patrol Waypoints
		local patrolFolder = Instance.new("Folder")
		patrolFolder.Name = "PoacherPatrol"
		patrolFolder.Parent = biomeModel

		local waypoints = {
			Vector3.new(-30, 3, biome.zStart + lenZ * 0.25),
			Vector3.new(30, 3, biome.zStart + lenZ * 0.45),
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

	-- Invisible Abyss Barrier at end of Biome 5 + Colossal Horizon Volcano backdrop!
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

	placeDecorModel(builder.BuildColossalHorizonVolcano(CFrame.new(0, -4, endZ + 85), 1.2, skyFolder), skyFolder)

	return biomesFolder
end

return BlockyMapBiomeGenerator
