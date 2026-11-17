--!strict
-- AnimalVisualBuilder.luau
-- Builds stylized blocky/cute 3D animal models & buried crates with dynamic sizeRatio & mutation VFX

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Shared.Types)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local AnimalConfig = require(script.Parent.Parent.Config.AnimalConfig)

local AnimalVisualBuilder = {}

local function makeBox(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function resolveMutationStyle(spec: Types.AnimalSpeciesDefinition, mutation: Types.AnimalMutation): (Color3, Color3, Enum.Material, number)
	if mutation == "Albino" then
		return Color3.fromRGB(248, 250, 255), Color3.fromRGB(232, 236, 244), Enum.Material.SmoothPlastic, 0
	elseif mutation == "Golden" then
		return Color3.fromRGB(255, 206, 54), Color3.fromRGB(235, 168, 28), Enum.Material.Metal, 0
	elseif mutation == "Diamond" then
		return Color3.fromRGB(116, 232, 255), Color3.fromRGB(198, 248, 255), Enum.Material.Ice, 0.18
	elseif mutation == "Neon" then
		return spec.bodyColor, Color3.fromRGB(84, 255, 188), Enum.Material.Neon, 0
	elseif mutation == "Rainbow" then
		return Color3.fromRGB(255, 118, 214), Color3.fromRGB(92, 245, 255), Enum.Material.SmoothPlastic, 0
	elseif mutation == "Celestial" then
		return Color3.fromRGB(72, 34, 138), Color3.fromRGB(255, 218, 96), Enum.Material.Neon, 0
	end
	return spec.bodyColor, spec.secondaryColor, Enum.Material.SmoothPlastic, 0
end

function AnimalVisualBuilder.BuildAnimalModel(speciesId: string, sizeRatio: number, mutation: Types.AnimalMutation, lowVFX: boolean?): Model
	local spec = AnimalConfig.GetById(speciesId) or AnimalConfig.ALL[1]
	local primaryCol, secondaryCol, mat, transparency = resolveMutationStyle(spec, mutation)
	local s = math.clamp(sizeRatio, 0.42, 6.0)

	local model = Instance.new("Model")
	model.Name = "Animal_" .. spec.id
	model:SetAttribute("SpeciesId", spec.id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("SizeRatio", s)

	-- Root pivot anchored at exact bottom center of the 4 feet (Y = 0) so :PivotTo(groundCF) never sinks legs
	local root = makeBox("Root", Vector3.new(2.2 * s, 1.5 * s, 2.8 * s), CFrame.new(0, 1.3 * s, 0), primaryCol, mat, model)
	root.Transparency = transparency
	root.PivotOffset = CFrame.new(0, -1.3 * s, 0)
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new(0, 0, 0)

	-- 4 Blocky Legs
	local legOffsets = {
		Vector3.new(-0.7 * s, 0.45 * s, -0.9 * s),
		Vector3.new(0.7 * s, 0.45 * s, -0.9 * s),
		Vector3.new(-0.7 * s, 0.45 * s, 0.9 * s),
		Vector3.new(0.7 * s, 0.45 * s, 0.9 * s),
	}
	for idx, off in ipairs(legOffsets) do
		local leg = makeBox("Leg_" .. idx, Vector3.new(0.55 * s, 0.9 * s, 0.55 * s), CFrame.new(off), secondaryCol, mat, model)
		leg.Transparency = transparency
	end

	-- Head & Snout (facing -Z forward)
	local headSize = if spec.shapeStyle == "Bear" then Vector3.new(2.0 * s, 1.8 * s, 1.8 * s) else Vector3.new(1.7 * s, 1.5 * s, 1.6 * s)
	local head = makeBox("Head", headSize, CFrame.new(0, 2.15 * s, -1.45 * s), primaryCol, mat, model)
	head.Transparency = transparency

	local snoutColor = if spec.shapeStyle == "Bird" then Color3.fromRGB(255, 186, 48) else secondaryCol
	local snoutSize = if spec.shapeStyle == "Bird" then Vector3.new(0.6 * s, 0.45 * s, 0.9 * s) else Vector3.new(1.0 * s, 0.65 * s, 0.7 * s)
	local snout = makeBox("Snout", snoutSize, CFrame.new(0, 1.9 * s, -2.35 * s), snoutColor, mat, model)
	snout.Transparency = transparency

	-- Cute Eyes
	for _, ex in { -0.45 * s, 0.45 * s } do
		makeBox("Eye", Vector3.new(0.28 * s, 0.34 * s, 0.2 * s), CFrame.new(ex, 2.35 * s, -2.26 * s), spec.eyeColor, Enum.Material.Neon, model)
	end

	-- Silhouette Details (Ears, Antlers, Wings, or Tail)
	if spec.shapeStyle == "Canine" or spec.shapeStyle == "Feline" or spec.shapeStyle == "Critter" then
		for _, ex in { -0.58 * s, 0.58 * s } do
			local ear = makeBox("Ear", Vector3.new(0.4 * s, 0.65 * s, 0.35 * s), CFrame.new(ex, 3.15 * s, -1.3 * s), secondaryCol, mat, model)
			ear.Transparency = transparency
		end
		local tail = makeBox("Tail", Vector3.new(0.55 * s, 0.55 * s, 1.2 * s), CFrame.new(0, 1.6 * s, 1.8 * s) * CFrame.Angles(math.rad(25), 0, 0), secondaryCol, mat, model)
		tail.Transparency = transparency
	elseif spec.shapeStyle == "Hooved" then
		for _, ex in { -0.6 * s, 0.6 * s } do
			makeBox("Horn", Vector3.new(0.26 * s, 0.95 * s, 0.26 * s), CFrame.new(ex, 3.25 * s, -1.2 * s) * CFrame.Angles(0, 0, math.rad(if ex < 0 then 14 else -14)), secondaryCol, Enum.Material.SmoothPlastic, model)
		end
	elseif spec.shapeStyle == "Bird" then
		for _, wx in { -1.3 * s, 1.3 * s } do
			local wing = makeBox("Wing", Vector3.new(0.45 * s, 1.1 * s, 1.8 * s), CFrame.new(wx, 1.45 * s, 0), secondaryCol, mat, model)
			wing.Transparency = transparency
		end
	elseif spec.shapeStyle == "Reptile" then
		local tail = makeBox("Tail", Vector3.new(0.8 * s, 0.55 * s, 1.9 * s), CFrame.new(0, 1.0 * s, 2.1 * s), secondaryCol, mat, model)
		tail.Transparency = transparency
		for sp = -0.5, 0.7, 0.6 do
			makeBox("Ridge", Vector3.new(0.35 * s, 0.4 * s, 0.4 * s), CFrame.new(0, 2.15 * s, sp * s), secondaryCol, mat, model)
		end
	end

	-- Mutation Sparkle / Celestial VFX
	if not lowVFX and (mutation == "Golden" or mutation == "Diamond" or mutation == "Rainbow" or mutation == "Celestial") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "MutationVFX"
		emitter.Rate = if mutation == "Celestial" then 14 else 7
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1.5, 3.5)
		emitter.Size = NumberSequence.new(0.35 * s, 0)
		local mutInfo = GameConfig.MUTATIONS[mutation]
		emitter.Color = ColorSequence.new(mutInfo.color)
		emitter.Parent = root
	end

	return model
end

local BIOME_CRATE_VARIANTS: { [string]: { string } } = {
	PineWoods = { "Pine Crate", "Timber Chest", "Forest Relic" },
	MangroveSwamp = { "Bamboo Cage", "Mire Chest", "Lotus Pod" },
	SavannaCamp = { "Safari Crate", "Bone Trunk", "Sun Totem" },
	AlpinePeaks = { "Frost Chest", "Glacier Vault", "Crystal Pod" },
	VolcanicJungle = { "Basalt Coffer", "Magma Vault", "Obsidian Pod" },
}

function AnimalVisualBuilder.GetCrateVariantInfo(biomeId: string, _rarity: Types.AnimalRarity?, variantIndex: number?): (string, number)
	local list = BIOME_CRATE_VARIANTS[biomeId] or BIOME_CRATE_VARIANTS.PineWoods
	local idx = ((math.max(1, math.floor(variantIndex or 1)) - 1) % #list) + 1
	return list[idx], idx
end

function AnimalVisualBuilder.BuildCrateModel(
	rarity: Types.AnimalRarity,
	biomeId: string,
	sizeScale: number?,
	opts: { isBuried: boolean?, canCollide: boolean?, showBeacon: boolean?, variant: number? }?
): Model
	local s = sizeScale or GameConfig.ComputeCrateScale(rarity)
	local rarityColor = GameConfig.RARITY_COLORS[rarity] or Color3.fromRGB(168, 182, 172)
	local isBuried = if opts and opts.isBuried ~= nil then opts.isBuried else true
	local canCollide = if opts and opts.canCollide ~= nil then opts.canCollide else false
	local showBeacon = if opts and opts.showBeacon ~= nil then opts.showBeacon else isBuried
	local crateName, styleIdx = AnimalVisualBuilder.GetCrateVariantInfo(biomeId, rarity, opts and opts.variant)

	local crateModel = Instance.new("Model")
	crateModel.Name = string.format("Crate_%s_%s", biomeId, rarity)
	crateModel:SetAttribute("BiomeId", biomeId)
	crateModel:SetAttribute("Rarity", rarity)
	crateModel:SetAttribute("SizeScale", s)
	crateModel:SetAttribute("CrateVariant", styleIdx)
	crateModel:SetAttribute("CrateTitle", crateName)

	local tilt = if isBuried then CFrame.Angles(math.rad(12), math.rad(10), math.rad(-8)) else CFrame.new()
	local baseY = (2.1 * s)

	-- Biome-specific palette, silhouette, and structural theme
	local frameCol = Color3.fromRGB(128, 86, 50)
	local frameMat = Enum.Material.Wood
	local accentCol = Color3.fromRGB(58, 132, 64)
	local accentMat = Enum.Material.Grass
	local barCol = Color3.fromRGB(54, 58, 66)
	local barMat = Enum.Material.Metal
	local outerTrans = 0
	local boxDims = Vector3.new(4.2 * s, 3.6 * s, 4.2 * s)

	if biomeId == "MangroveSwamp" then
		frameCol = Color3.fromRGB(98, 78, 46)
		frameMat = Enum.Material.WoodPlanks
		accentCol = Color3.fromRGB(72, 224, 158)
		accentMat = Enum.Material.Neon
		barCol = Color3.fromRGB(142, 118, 66)
		barMat = Enum.Material.Wood
		boxDims = Vector3.new(4.6 * s, 3.1 * s, 3.8 * s)
	elseif biomeId == "SavannaCamp" then
		frameCol = Color3.fromRGB(68, 72, 82)
		frameMat = Enum.Material.DiamondPlate
		accentCol = Color3.fromRGB(224, 158, 52)
		accentMat = Enum.Material.Metal
		barCol = Color3.fromRGB(38, 40, 46)
		barMat = Enum.Material.Metal
		boxDims = Vector3.new(4.0 * s, 4.1 * s, 4.6 * s)
	elseif biomeId == "AlpinePeaks" then
		frameCol = Color3.fromRGB(148, 222, 255)
		frameMat = Enum.Material.Ice
		accentCol = Color3.fromRGB(228, 246, 255)
		accentMat = Enum.Material.Glass
		barCol = Color3.fromRGB(92, 136, 186)
		barMat = Enum.Material.Metal
		outerTrans = 0.25
		boxDims = Vector3.new(4.3 * s, 3.9 * s, 4.3 * s)
	elseif biomeId == "VolcanicJungle" then
		frameCol = Color3.fromRGB(42, 34, 46)
		frameMat = Enum.Material.Basalt
		accentCol = Color3.fromRGB(255, 86, 28)
		accentMat = Enum.Material.Neon
		barCol = Color3.fromRGB(28, 24, 30)
		barMat = Enum.Material.Basalt
		boxDims = Vector3.new(4.4 * s, 4.0 * s, 4.4 * s)
	end

	-- Distinct silhouette proportions per variant style (1: Blocky Crate, 2: Arched Trunk Chest, 3: Relic Pod on Ring Base)
	if styleIdx == 2 then
		boxDims = Vector3.new(boxDims.X * 1.15, boxDims.Y * 0.85, boxDims.Z * 0.88)
	elseif styleIdx == 3 then
		boxDims = Vector3.new(boxDims.X * 0.88, boxDims.Y * 1.12, boxDims.Z * 0.88)
	end

	local root = makeBox("CrateRoot", boxDims, CFrame.new(0, baseY, 0) * tilt, frameCol, frameMat, crateModel)
	root.Transparency = outerTrans
	root.CanCollide = canCollide
	root.CanQuery = true
	crateModel.PrimaryPart = root

	local rootCF = root.CFrame
	local hx, hy, hz = boxDims.X * 0.5, boxDims.Y * 0.5, boxDims.Z * 0.5

	-- Textured Nest / Swirl Pedestal Ring underneath (Image 11 style!)
	local discSize = math.max(boxDims.X, boxDims.Z) * 1.38
	local pedestal = makeBox(
		"PedestalBase",
		Vector3.new(0.42 * s, discSize, discSize),
		CFrame.new(0, 0.22 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		accentCol:Lerp(rarityColor, 0.38),
		if rarity == "Legendary" or rarity == "Mythic" then Enum.Material.Neon else Enum.Material.Cobblestone,
		crateModel
	)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.TopSurface = Enum.SurfaceType.Studs

	if styleIdx == 2 then
		-- Archetype 2: Arched Dome Lid + Side Handles
		local archLid = makeBox(
			"ArchedLid",
			Vector3.new(boxDims.X * 0.94, 0.85 * s, boxDims.Z * 0.84),
			rootCF * CFrame.new(0, hy + 0.35 * s, 0),
			accentCol,
			accentMat,
			crateModel
		)
		archLid.TopSurface = Enum.SurfaceType.Studs
		for _, sx in { -1, 1 } do
			makeBox("SideHandle", Vector3.new(0.32 * s, 0.72 * s, 1.45 * s), rootCF * CFrame.new(sx * (hx + 0.2 * s), 0.1 * s, 0), rarityColor, Enum.Material.Metal, crateModel)
		end
	elseif styleIdx == 3 then
		-- Archetype 3: Octagonal Relic Pod with Glowing Outer Ribs + Dome Cap
		local podOrb = makeBox("RelicCore", Vector3.new(boxDims.X * 0.78, boxDims.Y * 1.15, boxDims.Z * 0.78), rootCF, rarityColor, Enum.Material.Neon, crateModel)
		podOrb.Shape = Enum.PartType.Ball
		podOrb.Transparency = 0.25
		makeBox("RelicCap", Vector3.new(boxDims.X * 0.92, 0.5 * s, boxDims.Z * 0.92), rootCF * CFrame.new(0, hy + 0.2 * s, 0) * CFrame.Angles(0, math.rad(45), 0), accentCol, Enum.Material.SmoothPlastic, crateModel)
	end

	-- Corner structural pillars / ribs tinted with biome material + rarity
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			local pillar = makeBox(
				"CornerPillar",
				Vector3.new(0.46 * s, boxDims.Y + 0.35 * s, 0.46 * s),
				rootCF * CFrame.new(cx * hx, 0, cz * hz),
				barCol,
				barMat,
				crateModel
			)
			pillar.TopSurface = Enum.SurfaceType.Studs

			if biomeId == "AlpinePeaks" then
				makeBox(
					"IceCrystal",
					Vector3.new(0.55 * s, 1.3 * s, 0.55 * s),
					rootCF * CFrame.new(cx * hx, hy + 0.45 * s, cz * hz) * CFrame.Angles(math.rad(cx * 15), 0, math.rad(cz * -15)),
					Color3.fromRGB(168, 238, 255),
					Enum.Material.Neon,
					crateModel
				)
			elseif biomeId == "VolcanicJungle" then
				makeBox(
					"ObsidianHorn",
					Vector3.new(0.52 * s, 1.45 * s, 0.52 * s),
					rootCF * CFrame.new(cx * (hx + 0.1 * s), hy + 0.48 * s, cz * (hz + 0.1 * s)) * CFrame.Angles(math.rad(cz * -18), 0, math.rad(cx * 18)),
					accentCol,
					Enum.Material.Neon,
					crateModel
				)
			elseif rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" then
				makeBox(
					"RarityStud",
					Vector3.new(0.56 * s, 0.38 * s, 0.56 * s),
					rootCF * CFrame.new(cx * hx, hy + 0.25 * s, cz * hz),
					rarityColor,
					Enum.Material.Neon,
					crateModel
				)
			end
		end
	end

	-- Front & back cage bars + top/bottom frame rims
	for _, bz in { -hz - 0.08 * s, hz + 0.08 * s } do
		for bx = -1, 1 do
			makeBox(
				"CageBar",
				Vector3.new(0.28 * s, boxDims.Y - 0.4 * s, 0.28 * s),
				rootCF * CFrame.new(bx * 0.9 * s, 0, bz),
				if biomeId == "VolcanicJungle" then accentCol else barCol,
				if biomeId == "VolcanicJungle" then Enum.Material.Neon else barMat,
				crateModel
			)
		end
	end

	-- Biome side/top trim detail + glowing rarity band
	makeBox(
		"RarityBand",
		Vector3.new(boxDims.X + 0.24 * s, 0.36 * s, boxDims.Z + 0.24 * s),
		rootCF * CFrame.new(0, 0, 0),
		rarityColor,
		Enum.Material.Neon,
		crateModel
	)
	makeBox(
		"BiomeRoofTrim",
		Vector3.new(boxDims.X * 0.72, 0.34 * s, boxDims.Z * 0.72),
		rootCF * CFrame.new(0, hy + 0.16 * s, 0),
		accentCol,
		accentMat,
		crateModel
	)

	-- Padlock & Keyhole on front face
	makeBox(
		"Padlock",
		Vector3.new(0.85 * s, 0.95 * s, 0.42 * s),
		rootCF * CFrame.new(0, -0.25 * s, -hz - 0.22 * s),
		rarityColor,
		Enum.Material.Metal,
		crateModel
	)

	-- Epic/Legendary/Mythic crest + top tow ring
	if rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" then
		makeBox(
			"CrestRing",
			Vector3.new(boxDims.X * 0.46, 0.42 * s, boxDims.Z * 0.46),
			rootCF * CFrame.new(0, hy + 0.48 * s, 0) * CFrame.Angles(0, math.rad(45), 0),
			rarityColor,
			Enum.Material.Neon,
			crateModel
		)
	end

	local ring = makeBox("TowRing", Vector3.new(1.05 * s, 1.05 * s, 1.05 * s), rootCF * CFrame.new(0, hy + 0.95 * s, 0), rarityColor, Enum.Material.Neon, crateModel)
	ring.Shape = Enum.PartType.Ball

	if showBeacon and (rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic") then
		local beacon = makeBox("RarityBeacon", Vector3.new(1.1 * s, 32, 1.1 * s), rootCF * CFrame.new(0, 16 + hy, 0), rarityColor, Enum.Material.Neon, crateModel)
		beacon.Transparency = 0.72
	end

	return crateModel
end

function AnimalVisualBuilder.BuildBuriedCrate(rarity: Types.AnimalRarity, biomeId: string, sizeScale: number?, variantIndex: number?): Model
	return AnimalVisualBuilder.BuildCrateModel(rarity, biomeId, sizeScale, {
		isBuried = true,
		canCollide = true,
		showBeacon = true,
		variant = variantIndex,
	})
end

function AnimalVisualBuilder.BuildVehicleModel(def: Types.VehicleDefinition, scaleFactor: number?): Model
	local sc = scaleFactor or 1.0
	local ca = ReplicatedStorage:FindFirstChild("CuratedAssets")
	local tpl = if ca then ca:FindFirstChild("Hero_SafariATV") else nil
	if tpl and tpl:IsA("Model") then
		local m = tpl:Clone()
		m.Name = "VehicleVisual_" .. def.id
		if sc ~= 1.0 then
			pcall(function()
				m:ScaleTo(m:GetScale() * sc)
			end)
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if def.tier > 1 then
					if d.Name == "frame_geom" then
						if d:IsA("MeshPart") then
							d.TextureID = ""
						end
						d.Color = def.primaryColor
					elseif d.Name == "front fork_geom" or d.Name == "handlebars_geom" then
						d.Color = def.accentColor
					end
				end
			elseif d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		if not m.PrimaryPart then
			local firstPart = m:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				m.PrimaryPart = firstPart
			end
		end
		return m
	end

	local m = Instance.new("Model")
	m.Name = "VehicleVisual_" .. def.id
	local body = makeBox("Body", Vector3.new(3.6 * sc, 1.4 * sc, 5.2 * sc), CFrame.new(), def.primaryColor, Enum.Material.SmoothPlastic, m)
	m.PrimaryPart = body
	makeBox("Accent", Vector3.new(2.8 * sc, 0.8 * sc, 2.2 * sc), CFrame.new(0, 1.0 * sc, 0.4 * sc), def.accentColor, Enum.Material.Neon, m)
	return m
end

function AnimalVisualBuilder.GetModelVerticalBounds(model: Model): (number, number)
	local pivY = model:GetPivot().Position.Y
	local minY = math.huge
	local maxY = -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local b = d.Position.Y - d.Size.Y * 0.5
			local t = d.Position.Y + d.Size.Y * 0.5
			if b < minY then minY = b end
			if t > maxY then maxY = t end
		end
	end
	if minY == math.huge then
		local cf, sz = model:GetBoundingBox()
		return (cf.Position.Y - sz.Y * 0.5) - pivY, (cf.Position.Y + sz.Y * 0.5) - pivY
	end
	return minY - pivY, maxY - pivY
end

function AnimalVisualBuilder.BuildLassoModel(beamColor: Color3, scaleFactor: number?): Model
	local sc = scaleFactor or 1.0
	local m = Instance.new("Model")
	m.Name = "LassoVisual"
	local handle = makeBox("Handle", Vector3.new(0.26 * sc, 0.26 * sc, 1.25 * sc), CFrame.new(0, 0, 0), Color3.fromRGB(132, 84, 44), Enum.Material.Wood, m)
	m.PrimaryPart = handle
	for i = 0, 5 do
		local a = (i / 6) * math.pi * 2
		local seg = makeBox(
			"Coil_" .. i,
			Vector3.new(0.24 * sc, 0.24 * sc, 0.68 * sc),
			CFrame.new(math.cos(a) * 0.58 * sc, 0.1 * sc, -0.75 * sc + math.sin(a) * 0.58 * sc) * CFrame.Angles(0, -a, 0),
			beamColor,
			Enum.Material.Neon,
			m
		)
		seg.Shape = Enum.PartType.Cylinder
	end
	return m
end

-- Stylized Running Silhouette + Sweeping Cape Ribbon for Trails Shop ViewportFrame (Image 6 style)
function AnimalVisualBuilder.BuildTrailRunnerPreview(colorPrimary: Color3, colorSecondary: Color3): Model
	local m = Instance.new("Model")
	m.Name = "TrailRunnerPreview"
	local leanCF = CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(-14), math.rad(16), math.rad(-6))
	local torso = makeBox("Torso", Vector3.new(1.5, 1.85, 0.85), leanCF, colorPrimary, Enum.Material.Neon, m)
	m.PrimaryPart = torso

	makeBox("Head", Vector3.new(1.05, 1.05, 1.05), leanCF * CFrame.new(0, 1.55, -0.08), colorPrimary:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Neon, m)
	makeBox("ArmL", Vector3.new(0.55, 1.55, 0.55), leanCF * CFrame.new(-1.1, 0.15, -0.35) * CFrame.Angles(math.rad(-42), 0, math.rad(10)), colorPrimary, Enum.Material.SmoothPlastic, m)
	makeBox("ArmR", Vector3.new(0.55, 1.55, 0.55), leanCF * CFrame.new(1.1, -0.1, 0.38) * CFrame.Angles(math.rad(48), 0, math.rad(-10)), colorSecondary, Enum.Material.Neon, m)
	makeBox("LegL", Vector3.new(0.62, 1.65, 0.62), leanCF * CFrame.new(-0.42, -1.65, -0.45) * CFrame.Angles(math.rad(-35), 0, 0), colorSecondary, Enum.Material.SmoothPlastic, m)
	makeBox("LegR", Vector3.new(0.62, 1.65, 0.62), leanCF * CFrame.new(0.42, -1.55, 0.52) * CFrame.Angles(math.rad(42), 0, 0), colorPrimary, Enum.Material.Neon, m)

	-- Sweeping Cape Trail Ribbon fanning backwards behind shoulders
	for idx = 1, 4 do
		local t = idx / 4
		local col = colorPrimary:Lerp(colorSecondary, t)
		local seg = makeBox(
			"CapeTrail_" .. idx,
			Vector3.new(1.6 + idx * 0.22, 0.16, 1.15),
			leanCF * CFrame.new(0, 0.35 - idx * 0.32, 0.8 + idx * 0.72) * CFrame.Angles(math.rad(16 - idx * 5), 0, math.rad(idx * 4)),
			col,
			Enum.Material.Neon,
			m
		)
		seg.Transparency = 0.08 * idx
	end
	return m
end

return AnimalVisualBuilder
