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
local JungleBiomeAssetBuilder = require(ReplicatedStorage.Modules.JungleBiomeAssetBuilder)

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

local function collectPineWoodsCrates(biomeModel: Instance?, biome: any, fallbackRng: Random?): { Vector3 }
	local coords: { Vector3 } = {}
	if biomeModel then
		local cs = biomeModel:FindFirstChild("CrateSpawns")
		if cs then
			for _, ch in ipairs(cs:GetChildren()) do
				if ch:IsA("BasePart") then
					table.insert(coords, ch.Position)
				end
			end
		end
	end
	if #coords == 0 then
		-- Exact deterministic coordinates generated for PineWoods CrateSpawns
		local lenZ = biome.zEnd - biome.zStart
		local detRng = fallbackRng or Random.new(42069)
		table.insert(coords, Vector3.new(10, 0.25, 174))
		for s = 1, 11 do
			local side = if s % 2 == 0 then 1 else -1
			local sx = side * detRng:NextNumber(20, 46)
			local sz = biome.zStart + 30 + ((s - 1) / 10) * (lenZ - 65)
			table.insert(coords, Vector3.new(sx, 0.2, sz))
		end
	end
	return coords
end

local function populatePineWoodsDecor(
	propsFolder: Folder,
	biome: any,
	segMap: { [number]: { TerraceSeg } },
	builder: any,
	rng: Random,
	crateCoordsOverride: { Vector3 }?,
	assetBuilderOverride: any?
)
	local jbab = assetBuilderOverride or JungleBiomeAssetBuilder
	jbab.EnsureLibrary()

	local lenZ = biome.zEnd - biome.zStart
	local crateCoords = crateCoordsOverride or collectPineWoodsCrates(propsFolder.Parent, biome)

	-- Horizon Archway framing biome entry
	placeDecorModel(builder.BuildBiomeHorizonArchway(CFrame.new(0, 0.25, biome.zStart + 10), 1.0, propsFolder, "PineWoods"), propsFolder)

	local function isNearCrate(x: number, z: number, minDist: number): boolean
		local minSq = minDist * minDist
		for _, c in ipairs(crateCoords) do
			local dx = x - c.X
			local dz = z - c.Z
			if dx * dx + dz * dz < minSq then
				return true
			end
		end
		return false
	end

	local heroSpots: { Vector3 } = {}
	local function isNearHero(x: number, z: number, minDist: number): boolean
		local minSq = minDist * minDist
		for _, h in ipairs(heroSpots) do
			local dx = x - h.X
			local dz = z - h.Z
			if dx * dx + dz * dz < minSq then
				return true
			end
		end
		return false
	end

	local function findSafeGroundX(prefX: number, z: number, sideSign: number, minCrateDist: number): number?
		for _, shift in ipairs({ 0, -4 * sideSign, 4 * sideSign, -8 * sideSign, 8 * sideSign }) do
			local candX = math.clamp(math.abs(prefX + shift), 22, 47) * sideSign
			if not isNearCrate(candX, z, minCrateDist) and not isNearHero(candX, z, 9.5) then
				return candX
			end
		end
		return nil
	end

	local function spawnAsset(category: string, assetName: string, cframe: CFrame, scale: number?): Model
		return jbab.SpawnFromLibrary(category, assetName, cframe, scale, propsFolder)
	end

	local giantTreeNames = {
		"GiantJungleTree_CanopyArch",
		"GiantJungleTree_TwinFork",
		"GiantJungleTree_AncientBanyan",
		"GiantJungleTree_LayeredPine",
		"GiantJungleTree_OverhangLimb",
	}
	local smallTreeNames = {
		"SmallJungleTree_Broadleaf",
		"SmallJungleTree_TropicalPalm",
		"SmallJungleTree_SplitUmbrella",
		"SmallJungleTree_SteppedCanopy",
		"SmallJungleTree_SpruceSapling",
	}
	local bushNames = {
		"Bush_DenseBlocky",
		"Bush_UprightBerry",
		"Bush_PinkBlossom",
		"Bush_RedBlossom",
		"Bush_PurpleBlossom",
		"Bush_WideLowThicket",
	}
	local plantNames = {
		"Plant_TallGrassTuft",
		"Plant_BroadBananaLeaf",
		"Plant_LushJungleFern",
		"Plant_SpireSapling",
		"Plant_TropicalReeds",
		"Plant_SpreadingLowFern",
		"Plant_BroadMonstera",
		"Plant_MossyCloverPatch",
	}
	local flowerNames = {
		"Flower_BlueVioletStalks",
		"Flower_RedOrangeCluster",
		"Flower_PurpleLavenderDuo",
		"Flower_SunnyWildflowerMix",
		"Flower_TropicalOrchidPatch",
	}
	local rockNames = {
		"Rock_TallMossyBoulder",
		"Rock_MediumMossyMound",
		"Rock_LowFlatMossStone",
		"Rock_LayeredMonolith",
		"Rock_CobbleScatterCluster",
		"Rock_SteppedCliffOutcrop",
	}
	local mushroomNames = {
		"Mushroom_RedSpottedTrio",
		"Mushroom_GiantRedToadstool",
		"Mushroom_BrownShelfCluster",
		"Mushroom_GlowJungleShrooms",
	}
	local rootNames = {
		"TreeRoot_GiantArch",
		"TreeRoot_TwistedSprawl",
		"TreeRoot_MossyButtress",
		"TreeRoot_ExposedKnuckle",
	}
	local logNames = {
		"FallenLog_HollowMossy",
		"FallenLog_SplitTimber",
		"FallenLog_VineBridge",
	}
	local lanternNames = {
		"Lantern_OverhangArmPost",
		"Lantern_StandingPathPost",
		"Lantern_FencePostLamp",
	}

	local cursors: { [string]: number } = {}
	local function pickNext(key: string, list: { string }): string
		local idx = ((cursors[key] or 0) % #list) + 1
		cursors[key] = idx
		return list[idx]
	end

	local function spawnNaturalCluster(cx: number, cy: number, cz: number, sideSign: number, includeShroom: boolean)
		local bushCount = rng:NextInteger(1, 2)
		for _ = 1, bushCount do
			local bx = cx + rng:NextNumber(-4.2, 4.2)
			local bz = cz + rng:NextNumber(-4.2, 4.2)
			if math.abs(bx) >= 21 and math.abs(bx) <= 49 and not isNearCrate(bx, bz, 5.2) then
				spawnAsset("Bushes", pickNext("bush", bushNames), CFrame.new(bx, cy, bz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.82, 1.24))
			end
		end
		local plantCount = rng:NextInteger(1, 2)
		for _ = 1, plantCount do
			local px = cx + rng:NextNumber(-4.6, 4.6)
			local pz = cz + rng:NextNumber(-4.6, 4.6)
			if math.abs(px) >= 20.5 and math.abs(px) <= 49 and not isNearCrate(px, pz, 4.5) then
				spawnAsset("Plants", pickNext("plant", plantNames), CFrame.new(px, cy, pz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.84, 1.28))
			end
		end
		local fx = cx + rng:NextNumber(-3.6, 3.6)
		local fz = cz + rng:NextNumber(-3.6, 3.6)
		if math.abs(fx) >= 20.5 and math.abs(fx) <= 49 and not isNearCrate(fx, fz, 4.5) then
			if includeShroom then
				spawnAsset("Mushrooms", pickNext("shroom", mushroomNames), CFrame.new(fx, cy, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.88, 1.25))
			else
				spawnAsset("Flowers", pickNext("flower", flowerNames), CFrame.new(fx, cy, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.88, 1.24))
			end
		end
		if rng:NextNumber() < 0.45 then
			local rx = cx - sideSign * rng:NextNumber(1.6, 3.8)
			local rz = cz + rng:NextNumber(-3.4, 3.4)
			if math.abs(rx) >= 22 and math.abs(rx) <= 48 and not isNearCrate(rx, rz, 5.5) then
				spawnAsset("Rocks", pickNext("rock", rockNames), CFrame.new(rx, cy, rz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.75, 1.15))
			end
		end
	end

	-- 1. Hero WaterFeatures (Ponds & Animated Mini Waterfalls) nestled in clearings facing road
	local waterPlacements = {
		{ name = "WaterFeature_MiniWaterfallPond", x = -38, z = biome.zStart + 104, sc = 1.12, side = -1 },
		{ name = "WaterFeature_CascadeRockBasin", x = 38, z = biome.zStart + 126, sc = 1.10, side = 1 },
		{ name = "WaterFeature_MiniWaterfallPond", x = 37, z = biome.zStart + 214, sc = 1.14, side = 1 },
		{ name = "WaterFeature_LilyPadPond", x = 36, z = biome.zStart + 40, sc = 1.08, side = 1 },
		{ name = "WaterFeature_StoneLotusPool", x = -36, z = biome.zStart + 154, sc = 1.08, side = -1 },
		{ name = "WaterFeature_LilyPadPond", x = -37, z = biome.zStart + 250, sc = 1.05, side = -1 },
	}
	for _, wp in ipairs(waterPlacements) do
		local gx = findSafeGroundX(wp.x, wp.z, wp.side, 10.5)
		if gx then
			local yaw = math.rad(-wp.side * 76)
			spawnAsset("WaterFeatures", wp.name, CFrame.new(gx, 0, wp.z) * CFrame.Angles(0, yaw, 0), wp.sc)
			table.insert(heroSpots, Vector3.new(gx, 0, wp.z))
			spawnNaturalCluster(gx, 0, wp.z, wp.side, false)
		end
	end

	-- 2. Ancient Mossy Stone Ruins (All 3 Ruin variants placed along asymmetric clearings)
	local ruinPlacements = {
		{ name = "Ruin_MossyStoneArchway", x = -36, z = biome.zStart + 52, yawDeg = 24, sc = 1.15, side = -1 },
		{ name = "Ruin_BrokenArchWall", x = 36, z = biome.zStart + 92, yawDeg = -22, sc = 1.12, side = 1 },
		{ name = "Ruin_PillarAndPawBanner", x = -30, z = biome.zStart + 126, yawDeg = 76, sc = 1.05, side = -1 },
		{ name = "Ruin_MossyStoneArchway", x = 37, z = biome.zStart + 190, yawDeg = -20, sc = 1.12, side = 1 },
		{ name = "Ruin_BrokenArchWall", x = -37, z = biome.zStart + 228, yawDeg = 18, sc = 1.10, side = -1 },
		{ name = "Ruin_PillarAndPawBanner", x = 31, z = biome.zStart + 262, yawDeg = -82, sc = 1.05, side = 1 },
	}
	for _, rp in ipairs(ruinPlacements) do
		local gx = findSafeGroundX(rp.x, rp.z, rp.side, 10.5)
		if gx then
			spawnAsset("Ruins", rp.name, CFrame.new(gx, 0, rp.z) * CFrame.Angles(0, math.rad(rp.yawDeg), 0), rp.sc)
			table.insert(heroSpots, Vector3.new(gx, 0, rp.z))
			spawnNaturalCluster(gx, 0, rp.z, rp.side, true)
		end
	end

	-- 3. Giant Jungle Tree Side Landmarks + Flanked Tree Roots & Fallen Logs
	local giantLandmarks = {
		{ name = "GiantJungleTree_CanopyArch", x = -43, z = biome.zStart + 36, sc = 1.38, side = -1 },
		{ name = "GiantJungleTree_AncientBanyan", x = 44, z = biome.zStart + 62, sc = 1.32, side = 1 },
		{ name = "GiantJungleTree_LayeredPine", x = -42, z = biome.zStart + 100, sc = 1.34, side = -1 },
		{ name = "GiantJungleTree_TwinFork", x = 43, z = biome.zStart + 146, sc = 1.35, side = 1 },
		{ name = "GiantJungleTree_OverhangLimb", x = -43, z = biome.zStart + 190, sc = 1.34, side = -1 },
		{ name = "GiantJungleTree_CanopyArch", x = 43, z = biome.zStart + 224, sc = 1.38, side = 1 },
		{ name = "GiantJungleTree_AncientBanyan", x = -42, z = biome.zStart + 264, sc = 1.28, side = -1 },
		{ name = "GiantJungleTree_LayeredPine", x = 43, z = biome.zStart + 278, sc = 1.30, side = 1 },
	}
	for idx, gt in ipairs(giantLandmarks) do
		local gx = findSafeGroundX(gt.x, gt.z, gt.side, 10.5)
		if gx then
			local yaw = rng:NextNumber(0, 6.28)
			spawnAsset("Trees", gt.name, CFrame.new(gx, 0, gt.z) * CFrame.Angles(0, yaw, 0), gt.sc)
			table.insert(heroSpots, Vector3.new(gx, 0, gt.z))
			local rootZ = gt.z + (if idx % 2 == 0 then -4.2 else 4.2)
			local rootX = gx - gt.side * 3.6
			if math.abs(rootX) >= 22 and not isNearCrate(rootX, rootZ, 6.5) then
				spawnAsset("Decorations", pickNext("root", rootNames), CFrame.new(rootX, 0, rootZ) * CFrame.Angles(0, yaw + 0.6, 0), rng:NextNumber(0.92, 1.18))
			end
			spawnNaturalCluster(gx - gt.side * 2.5, 0, gt.z, gt.side, idx % 2 == 1)
		end
	end

	-- Fallen Logs tucked naturally in forest glades
	for idx, lg in ipairs({
		{ x = -32, z = biome.zStart + 48, side = -1, name = "FallenLog_HollowMossy" },
		{ x = 31, z = biome.zStart + 114, side = 1, name = "FallenLog_SplitTimber" },
		{ x = -33, z = biome.zStart + 174, side = -1, name = "FallenLog_VineBridge" },
		{ x = 33, z = biome.zStart + 244, side = 1, name = "FallenLog_HollowMossy" },
	}) do
		local gx = findSafeGroundX(lg.x, lg.z, lg.side, 7.2)
		if gx then
			spawnAsset("Decorations", lg.name, CFrame.new(gx, 0, lg.z) * CFrame.Angles(0, rng:NextNumber(-0.8, 0.8), 0), rng:NextNumber(0.95, 1.15))
			table.insert(heroSpots, Vector3.new(gx, 0, lg.z))
			if idx % 2 == 1 then
				spawnAsset("Mushrooms", pickNext("shroom", mushroomNames), CFrame.new(gx - lg.side * 2.4, 0, lg.z + 2.0), rng:NextNumber(0.95, 1.25))
			end
		end
	end

	-- 4. Asymmetric Non-Uniform Roadside Lanterns & Flora Pockets (X = +/- 21.0..23.5)
	for _, sideSign in ipairs({ -1, 1 }) do
		local z = biome.zStart + rng:NextNumber(22, 30)
		while z <= biome.zEnd - 20 do
			local lx = sideSign * 21.4
			local placeZ = z
			if isNearCrate(lx, placeZ, 6.2) then
				placeZ += 8.5
			end
			if placeZ <= biome.zEnd - 18 and not isNearCrate(lx, placeZ, 6.2) then
				local lName = pickNext("lantern_" .. tostring(sideSign), lanternNames)
				local yaw = if lName == "Lantern_FencePostLamp"
					then (if sideSign == -1 then 0 else math.pi)
					elseif lName == "Lantern_OverhangArmPost" then (if sideSign == -1 then 0 else math.pi)
					else rng:NextNumber(0, 6.28)
				spawnAsset("Decorations", lName, CFrame.new(lx, 0.2, placeZ) * CFrame.Angles(0, yaw, 0), rng:NextNumber(0.88, 0.98))

				local pocketX = sideSign * rng:NextNumber(23.5, 26.0)
				if not isNearCrate(pocketX, placeZ + 3.2, 5.2) then
					spawnAsset("Plants", pickNext("plant", plantNames), CFrame.new(pocketX, 0, placeZ + 3.2) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.88, 1.2))
				end
				if not isNearCrate(pocketX, placeZ - 3.6, 5.2) then
					local pickFlora = if rng:NextNumber() < 0.65 then "Flowers" else "Bushes"
					local fName = if pickFlora == "Flowers" then pickNext("flower", flowerNames) else pickNext("bush", bushNames)
					spawnAsset(pickFlora, fName, CFrame.new(pocketX, 0, placeZ - 3.6) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.85, 1.18))
				end
			end
			z += rng:NextNumber(34, 52)
		end
	end

	-- 5. Organic Mid-Flank Small Trees & Stepped 3-Tier Skyline Canopies
	for _, sideSign in ipairs({ -1, 1 }) do
		for segIdx, seg in ipairs(segMap[sideSign]) do
			-- Playable mid-flank natural clusters (with glade breathing gaps)
			local fz = seg.zCenter + rng:NextNumber(-7.5, 7.5)
			local fx = sideSign * rng:NextNumber(27, 45)
			if not isNearHero(fx, fz, 9.5) and not isNearCrate(fx, fz, 7.2) then
				if rng:NextNumber() < 0.72 then
					local treeName = pickNext("smallTree", smallTreeNames)
					spawnAsset("Trees", treeName, CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.92, 1.32))
					spawnNaturalCluster(fx, 0, fz, sideSign, segIdx % 3 == 0)
				else
					spawnAsset("Rocks", pickNext("rock", rockNames), CFrame.new(fx, 0, fz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.85, 1.32))
					spawnNaturalCluster(fx, 0, fz, sideSign, true)
				end
			elseif rng:NextNumber() < 0.55 then
				local fxAlt = sideSign * rng:NextNumber(23, 28)
				if not isNearHero(fxAlt, fz, 7.5) and not isNearCrate(fxAlt, fz, 5.5) then
					spawnNaturalCluster(fxAlt, 0, fz, sideSign, false)
				end
			end

			-- Tier 1 Top Dressing (strictly grounded at seg.t1Y)
			local t1z = seg.zCenter + rng:NextNumber(-6.5, 6.5)
			if segIdx % 4 == 2 then
				local gt1 = pickNext("giantTier", giantTreeNames)
				spawnAsset("Trees", gt1, CFrame.new(seg.t1X, seg.t1Y, t1z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.12, 1.32))
			elseif rng:NextNumber() < 0.85 then
				local st1 = pickNext("smallT1", smallTreeNames)
				spawnAsset("Trees", st1, CFrame.new(seg.t1X, seg.t1Y, t1z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.88, 1.24))
			end
			spawnAsset("Bushes", pickNext("bushT1", bushNames), CFrame.new(seg.t1X - sideSign * rng:NextNumber(2.8, 5.5), seg.t1Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.85, 1.22))
			if segIdx % 2 == 0 then
				spawnAsset("Plants", pickNext("plantT1", plantNames), CFrame.new(seg.t1X - sideSign * 4.5, seg.t1Y, seg.zCenter + rng:NextNumber(-5, 5)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.9, 1.25))
			end

			-- Tier 2 Canopy & Boulders (strictly grounded at seg.t2Y)
			local t2Name = if segIdx % 5 == 0 then pickNext("giantTier", giantTreeNames) else pickNext("smallT2", smallTreeNames)
			spawnAsset("Trees", t2Name, CFrame.new(seg.t2X, seg.t2Y, seg.zCenter + rng:NextNumber(-7, 7)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.02, 1.35))
			if segIdx % 3 == 1 then
				spawnAsset("Rocks", pickNext("rockT2", rockNames), CFrame.new(seg.t2X - sideSign * 4, seg.t2Y, seg.zCenter + rng:NextNumber(-5, 5)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.95, 1.35))
			end

			-- Tier 3 Outer Skyline (strictly grounded at seg.t3Y)
			if segIdx % 2 == 1 then
				spawnAsset("Trees", pickNext("giantTier3", giantTreeNames), CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.18, 1.48))
			else
				spawnAsset("Trees", pickNext("smallT3", smallTreeNames), CFrame.new(seg.t3X, seg.t3Y, seg.zCenter + rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.08, 1.38))
			end

			if segIdx % 2 == 0 then
				task.wait()
			end
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
		if string.sub(ch.Name, 1, 15) == "BiomeSkyIsland_" then
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

		-- Invisible Side Perimeter Barriers so players cannot climb off the low terraces or leave the map
		for _, sideSign in ipairs({ -1, 1 }) do
			makeBlock({
				name = "BiomeSideWall_" .. tostring(sideSign),
				size = Vector3.new(4, 72, lenZ + 4),
				cframe = CFrame.new(sideSign * 70, 34, centerZ),
				color = Color3.fromRGB(32, 32, 32),
				material = Enum.Material.SmoothPlastic,
				studded = false,
				canCollide = true,
				canQuery = false,
				canTouch = false,
				castShadow = false,
				transparency = 1,
				parent = terrainGroup,
			})
			makeBlock({
				name = "BiomeOuterSideWall_" .. tostring(sideSign),
				size = Vector3.new(4, 72, lenZ + 4),
				cframe = CFrame.new(sideSign * 112, 34, centerZ),
				color = Color3.fromRGB(32, 32, 32),
				material = Enum.Material.SmoothPlastic,
				studded = false,
				canCollide = true,
				canQuery = false,
				canTouch = false,
				castShadow = false,
				transparency = 1,
				parent = terrainGroup,
			})
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
			{ x = -168, y = 46, z = biome.zStart + lenZ * 0.72, sc = 1.32, fall = true, fallSide = 1 },
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

	-- Seal SanctuaryHub-to-Biome 1 corner transition wings (Z = 150, |X| = 68..136)
	for _, sideSign in ipairs({ -1, 1 }) do
		makeBlock({
			name = "HubToBiomeWingWall_" .. tostring(sideSign),
			size = Vector3.new(68, 72, 4),
			cframe = CFrame.new(sideSign * 102, 34, BiomeConfig[1].zStart),
			color = Color3.fromRGB(32, 32, 32),
			material = Enum.Material.SmoothPlastic,
			studded = false,
			canCollide = true,
			canQuery = false,
			canTouch = false,
			castShadow = false,
			transparency = 1,
			parent = biomesFolder,
		})
	end

	-- Invisible Abyss Barrier at end of Biome 5 + Colossal Horizon Volcano backdrop!
	local endZ = BiomeConfig[#BiomeConfig].zEnd + 6
	makeBlock({
		name = "EndOfWorldWall",
		size = Vector3.new(mapWidth + 28, 72, 8),
		cframe = CFrame.new(0, 34, endZ),
		color = Color3.fromRGB(32, 24, 34),
		material = Enum.Material.SmoothPlastic,
		studded = false,
		canCollide = true,
		canQuery = false,
		canTouch = false,
		castShadow = false,
		transparency = 1,
		parent = biomesFolder,
	})

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

-- Rebuilds ONLY PineWoods.CuratedDecor in-place without disturbing BlockyTerrain, CrateSpawns, PoacherPatrol, Biomes 2-5, or SkyIslands.
function BlockyMapBiomeGenerator.RebuildPineWoodsDecor(worldFolder: Folder, builderOverride: any?, assetBuilderOverride: any?): Folder
	local builder = builderOverride or DefaultBuilder
	local jbab = assetBuilderOverride or JungleBiomeAssetBuilder
	builder.EnsureClassicStudsVariant()
	jbab.EnsureLibrary()

	local biomesFolder = worldFolder:FindFirstChild("Biomes")
	local biomeModel = if biomesFolder then biomesFolder:FindFirstChild("PineWoods") else nil
	if not biomeModel then
		error("[BlockyMapBiomeGenerator] Workspace.GameWorld.Biomes.PineWoods not found")
	end

	local pineBiome = BiomeConfig[1]
	local terrainGroup = biomeModel:FindFirstChild("BlockyTerrain")
	local propsFolder = biomeModel:FindFirstChild("CuratedDecor")
	if not propsFolder or not propsFolder:IsA("Folder") then
		propsFolder = Instance.new("Folder")
		propsFolder.Name = "CuratedDecor"
		propsFolder.Parent = biomeModel
	end

	-- Preserve TerraceWaterfall & WaterfallSplashFoam parts already in CuratedDecor
	local preservedWaterfalls: { Instance } = {}
	for _, ch in ipairs(propsFolder:GetChildren()) do
		if ch.Name == "TerraceWaterfall" or ch.Name == "WaterfallSplashFoam" then
			ch.Parent = nil
			table.insert(preservedWaterfalls, ch)
		end
	end

	-- Clear existing PineWoods decor in responsive chunks
	local existingChildren = propsFolder:GetChildren()
	for i, ch in ipairs(existingChildren) do
		ch:Destroy()
		if i % 60 == 0 then
			task.wait()
		end
	end

	for _, wf in ipairs(preservedWaterfalls) do
		wf.Parent = propsFolder
	end

	-- Reconstruct live segMap from existing BlockyTerrain Terrace1/2/3_Cap parts
	local segMap: { [number]: { TerraceSeg } } = { [-1] = {}, [1] = {} }
	if terrainGroup then
		local t1Caps: { [number]: { BasePart } } = { [-1] = {}, [1] = {} }
		local t2Caps: { [number]: { BasePart } } = { [-1] = {}, [1] = {} }
		local t3Caps: { [number]: { BasePart } } = { [-1] = {}, [1] = {} }
		for _, ch in ipairs(terrainGroup:GetChildren()) do
			if ch:IsA("BasePart") then
				local side = if ch.Position.X < 0 then -1 else 1
				if ch.Name == "Terrace1_Cap" then
					table.insert(t1Caps[side], ch)
				elseif ch.Name == "Terrace2_Cap" then
					table.insert(t2Caps[side], ch)
				elseif ch.Name == "Terrace3_Cap" then
					table.insert(t3Caps[side], ch)
				end
			end
		end
		local function byZ(a: BasePart, b: BasePart): boolean
			return a.Position.Z < b.Position.Z
		end
		for _, sideSign in ipairs({ -1, 1 }) do
			table.sort(t1Caps[sideSign], byZ)
			table.sort(t2Caps[sideSign], byZ)
			table.sort(t3Caps[sideSign], byZ)
			local count = math.min(#t1Caps[sideSign], #t2Caps[sideSign], #t3Caps[sideSign])
			for i = 1, count do
				local c1 = t1Caps[sideSign][i]
				local c2 = t2Caps[sideSign][i]
				local c3 = t3Caps[sideSign][i]
				table.insert(segMap[sideSign], {
					zCenter = c1.Position.Z,
					t1X = c1.Position.X - sideSign * 3.7,
					t1Y = c1.Position.Y + c1.Size.Y * 0.5,
					t2X = c2.Position.X - sideSign * 2.7,
					t2Y = c2.Position.Y + c2.Size.Y * 0.5,
					t3X = c3.Position.X - sideSign * 5.6,
					t3Y = c3.Position.Y + c3.Size.Y * 0.5,
				})
			end
		end
	end

	local crateCoords = collectPineWoodsCrates(biomeModel, pineBiome)
	local biomeRng = Random.new(pineBiome.order * 1000 + 42)
	populatePineWoodsDecor(propsFolder :: Folder, pineBiome, segMap, builder, biomeRng, crateCoords, jbab)

	return propsFolder :: Folder
end

return BlockyMapBiomeGenerator
