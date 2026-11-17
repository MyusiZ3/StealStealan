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

type MutationVisualProfile = {
	primary: Color3?,
	secondary: Color3?,
	material: Enum.Material,
	transparency: number,
	accentNeon: boolean?,
	particleColor: ColorSequence?,
	particleRate: number,
	particleSpeed: NumberRange,
	particleSize: NumberSequence?,
	lightColor: Color3?,
	highlightFill: Color3?,
	highlightOutline: Color3?,
	ornamentStyle: string?,
}

local MUTATION_PROFILES: { [string]: MutationVisualProfile } = {
	None = { material = Enum.Material.SmoothPlastic, transparency = 0, particleRate = 0, particleSpeed = NumberRange.new(1, 2) },
	Albino = {
		primary = Color3.fromRGB(248, 250, 255),
		secondary = Color3.fromRGB(232, 236, 246),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
		particleColor = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		particleRate = 4,
		particleSpeed = NumberRange.new(0.8, 1.8),
		highlightFill = Color3.fromRGB(255, 255, 255),
		highlightOutline = Color3.fromRGB(220, 232, 255),
	},
	Silver = {
		primary = Color3.fromRGB(206, 220, 236),
		secondary = Color3.fromRGB(240, 246, 255),
		material = Enum.Material.Metal,
		transparency = 0,
		particleColor = ColorSequence.new(Color3.fromRGB(225, 240, 255), Color3.fromRGB(168, 192, 224)),
		particleRate = 7,
		particleSpeed = NumberRange.new(1.2, 2.5),
		lightColor = Color3.fromRGB(205, 226, 255),
		highlightFill = Color3.fromRGB(190, 215, 245),
		highlightOutline = Color3.fromRGB(255, 255, 255),
	},
	Bloom = {
		primary = Color3.fromRGB(255, 164, 216),
		secondary = Color3.fromRGB(255, 236, 248),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(255, 148, 206), Color3.fromRGB(255, 232, 168)),
		particleRate = 10,
		particleSpeed = NumberRange.new(1.0, 2.8),
		lightColor = Color3.fromRGB(255, 162, 220),
		highlightOutline = Color3.fromRGB(255, 128, 202),
		ornamentStyle = "BloomPetals",
	},
	Golden = {
		primary = Color3.fromRGB(255, 206, 54),
		secondary = Color3.fromRGB(255, 242, 142),
		material = Enum.Material.Metal,
		transparency = 0,
		particleColor = ColorSequence.new(Color3.fromRGB(255, 232, 92), Color3.fromRGB(255, 178, 36)),
		particleRate = 10,
		particleSpeed = NumberRange.new(1.5, 3.6),
		lightColor = Color3.fromRGB(255, 206, 72),
		highlightFill = Color3.fromRGB(255, 212, 62),
		highlightOutline = Color3.fromRGB(255, 248, 180),
	},
	Fractured = {
		primary = Color3.fromRGB(48, 34, 72),
		secondary = Color3.fromRGB(178, 92, 255),
		material = Enum.Material.Slate,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(186, 98, 255), Color3.fromRGB(92, 228, 255)),
		particleRate = 12,
		particleSpeed = NumberRange.new(2.0, 4.5),
		lightColor = Color3.fromRGB(168, 86, 255),
		highlightFill = Color3.fromRGB(132, 54, 255),
		highlightOutline = Color3.fromRGB(218, 168, 255),
		ornamentStyle = "FractureShards",
	},
	Diamond = {
		primary = Color3.fromRGB(116, 232, 255),
		secondary = Color3.fromRGB(208, 250, 255),
		material = Enum.Material.Ice,
		transparency = 0.16,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(142, 244, 255), Color3.fromRGB(255, 255, 255)),
		particleRate = 12,
		particleSpeed = NumberRange.new(1.8, 3.8),
		lightColor = Color3.fromRGB(112, 238, 255),
		highlightFill = Color3.fromRGB(82, 218, 255),
		highlightOutline = Color3.fromRGB(224, 252, 255),
	},
	SpiritBloom = {
		primary = Color3.fromRGB(98, 224, 214),
		secondary = Color3.fromRGB(214, 255, 248),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.04,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(112, 255, 232), Color3.fromRGB(255, 198, 246)),
		particleRate = 14,
		particleSpeed = NumberRange.new(1.8, 4.2),
		lightColor = Color3.fromRGB(118, 255, 236),
		highlightFill = Color3.fromRGB(92, 245, 224),
		highlightOutline = Color3.fromRGB(238, 255, 252),
		ornamentStyle = "SpiritOrbit",
	},
	Parasite = {
		primary = Color3.fromRGB(46, 38, 56),
		secondary = Color3.fromRGB(142, 255, 58),
		material = Enum.Material.Slate,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(148, 255, 54), Color3.fromRGB(84, 24, 128)),
		particleRate = 15,
		particleSpeed = NumberRange.new(1.4, 3.6),
		lightColor = Color3.fromRGB(142, 255, 58),
		highlightFill = Color3.fromRGB(112, 232, 42),
		highlightOutline = Color3.fromRGB(198, 255, 118),
		ornamentStyle = "ParasiteSpines",
	},
	Neon = {
		primary = Color3.fromRGB(48, 228, 148),
		secondary = Color3.fromRGB(68, 255, 162),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(68, 255, 162), Color3.fromRGB(64, 212, 255)),
		particleRate = 12,
		particleSpeed = NumberRange.new(2.2, 4.5),
		lightColor = Color3.fromRGB(72, 255, 178),
		highlightOutline = Color3.fromRGB(132, 255, 212),
	},
	Scrambled = {
		primary = Color3.fromRGB(255, 232, 82),
		secondary = Color3.fromRGB(255, 68, 198),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 68)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(68, 236, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 56, 176)),
		}),
		particleRate = 16,
		particleSpeed = NumberRange.new(2.8, 5.5),
		lightColor = Color3.fromRGB(255, 214, 92),
		highlightOutline = Color3.fromRGB(255, 92, 224),
		ornamentStyle = "GlitchCubes",
	},
	Monstrous = {
		primary = Color3.fromRGB(34, 26, 34),
		secondary = Color3.fromRGB(255, 48, 66),
		material = Enum.Material.Slate,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(255, 68, 42), Color3.fromRGB(22, 12, 18)),
		particleRate = 18,
		particleSpeed = NumberRange.new(2.4, 5.0),
		lightColor = Color3.fromRGB(255, 52, 52),
		highlightFill = Color3.fromRGB(210, 28, 46),
		highlightOutline = Color3.fromRGB(255, 112, 68),
		ornamentStyle = "MonsterHorns",
	},
	Rainbow = {
		primary = Color3.fromRGB(255, 118, 214),
		secondary = Color3.fromRGB(92, 245, 255),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 82, 118)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(82, 255, 178)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(98, 138, 255)),
		}),
		particleRate = 16,
		particleSpeed = NumberRange.new(2.0, 4.5),
		lightColor = Color3.fromRGB(255, 142, 238),
		highlightOutline = Color3.fromRGB(255, 255, 255),
		ornamentStyle = "OrbitHalo",
	},
	Celestial = {
		primary = Color3.fromRGB(64, 28, 136),
		secondary = Color3.fromRGB(255, 222, 92),
		material = Enum.Material.SmoothPlastic,
		transparency = 0,
		accentNeon = true,
		particleColor = ColorSequence.new(Color3.fromRGB(255, 232, 118), Color3.fromRGB(168, 92, 255)),
		particleRate = 22,
		particleSpeed = NumberRange.new(2.2, 5.2),
		lightColor = Color3.fromRGB(196, 128, 255),
		highlightFill = Color3.fromRGB(142, 72, 255),
		highlightOutline = Color3.fromRGB(255, 232, 122),
		ornamentStyle = "CelestialHalo",
	},
}

local function resolveMutationStyle(spec: Types.AnimalSpeciesDefinition, mutation: Types.AnimalMutation): (Color3, Color3, Enum.Material, number, MutationVisualProfile)
	local prof = MUTATION_PROFILES[mutation] or MUTATION_PROFILES.None
	return prof.primary or spec.bodyColor, prof.secondary or spec.secondaryColor, prof.material, prof.transparency, prof
end

local function attachMutationOrnaments(model: Model, root: Part, s: number, prof: MutationVisualProfile, secondaryCol: Color3)
	local style = prof.ornamentStyle
	if not style then
		return
	end
	if style == "BloomPetals" then
		for i = 1, 4 do
			local ang = (i / 4) * math.pi * 2
			local petal = makeBox(
				"BloomPetal_" .. i,
				Vector3.new(0.55 * s, 0.28 * s, 0.55 * s),
				CFrame.new(math.cos(ang) * 0.48 * s, 3.05 * s, -1.45 * s + math.sin(ang) * 0.48 * s),
				if i % 2 == 0 then secondaryCol else Color3.fromRGB(255, 122, 198),
				Enum.Material.SmoothPlastic,
				model
			)
			petal:SetAttribute("MutationPart", true)
		end
	elseif style == "FractureShards" then
		for i = -1, 1 do
			local shard = makeBox(
				"FractureShard_" .. (i + 2),
				Vector3.new(0.32 * s, 1.05 * s, 0.32 * s),
				CFrame.new(i * 0.65 * s, 2.35 * s, 0.2 * s) * CFrame.Angles(math.rad(18 * i), 0, math.rad(-22 * i)),
				secondaryCol,
				Enum.Material.SmoothPlastic,
				model
			)
			shard:SetAttribute("MutationPart", true)
		end
	elseif style == "ParasiteSpines" then
		for i = 0, 3 do
			local zOff = (-0.6 + i * 0.65) * s
			local spine = makeBox(
				"ParasitePod_" .. i,
				Vector3.new(0.46 * s, 0.72 * s, 0.46 * s),
				CFrame.new(math.sin(i * 1.4) * 0.35 * s, 2.25 * s, zOff) * CFrame.Angles(math.rad(15), 0, math.rad(i * 18 - 25)),
				secondaryCol,
				Enum.Material.SmoothPlastic,
				model
			)
			spine.Shape = Enum.PartType.Ball
			spine:SetAttribute("MutationPart", true)
		end
	elseif style == "MonsterHorns" then
		for _, sx in { -0.78 * s, 0.78 * s } do
			local horn = makeBox(
				"MonsterHorn",
				Vector3.new(0.36 * s, 1.35 * s, 0.36 * s),
				CFrame.new(sx, 3.4 * s, -1.35 * s) * CFrame.Angles(math.rad(-20), 0, math.rad(if sx < 0 then 24 else -24)),
				secondaryCol,
				Enum.Material.SmoothPlastic,
				model
			)
			horn:SetAttribute("MutationPart", true)
		end
		for i = 0, 2 do
			local ridge = makeBox(
				"MonsterSpike_" .. i,
				Vector3.new(0.38 * s, 0.85 * s, 0.42 * s),
				CFrame.new(0, 2.35 * s, (-0.4 + i * 0.75) * s) * CFrame.Angles(math.rad(-25), 0, 0),
				secondaryCol,
				Enum.Material.SmoothPlastic,
				model
			)
			ridge:SetAttribute("MutationPart", true)
		end
	elseif style == "GlitchCubes" then
		local gCols = { Color3.fromRGB(255, 232, 68), Color3.fromRGB(68, 240, 255), Color3.fromRGB(255, 68, 198) }
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2
			local cub = makeBox(
				"GlitchCube_" .. i,
				Vector3.new(0.42 * s, 0.42 * s, 0.42 * s),
				CFrame.new(math.cos(a) * 1.65 * s, (1.4 + (i % 2) * 0.7) * s, math.sin(a) * 1.65 * s),
				gCols[(i % #gCols) + 1],
				Enum.Material.SmoothPlastic,
				model
			)
			cub:SetAttribute("OrbitRing", true)
			cub:SetAttribute("OrbitRadius", 1.75 * s)
			cub:SetAttribute("OrbitPhase", (i / 4) * math.pi * 2)
			cub:SetAttribute("OrbitY", (1.45 + (i % 2) * 0.65) * s)
		end
	elseif style == "SpiritOrbit" or style == "OrbitHalo" or style == "CelestialHalo" then
		local orbCount = if style == "CelestialHalo" then 6 else 4
		local radius = (if style == "CelestialHalo" then 2.15 else 1.85) * s
		local yH = (if style == "CelestialHalo" then 2.9 else 2.2) * s
		for i = 1, orbCount do
			local a = (i / orbCount) * math.pi * 2
			local col = if style == "OrbitHalo"
				then Color3.fromHSV((i - 1) / orbCount, 0.85, 1)
				elseif style == "CelestialHalo" and i % 2 == 0 then Color3.fromRGB(168, 108, 255)
				else secondaryCol
			local orb = makeBox(
				"OrbitStar_" .. i,
				Vector3.new(0.44 * s, 0.44 * s, 0.44 * s),
				CFrame.new(math.cos(a) * radius, yH, math.sin(a) * radius),
				col,
				Enum.Material.SmoothPlastic,
				model
			)
			orb.Shape = Enum.PartType.Ball
			orb:SetAttribute("OrbitRing", true)
			orb:SetAttribute("OrbitRadius", radius)
			orb:SetAttribute("OrbitPhase", a)
			orb:SetAttribute("OrbitY", yH)
		end
	end
end

function AnimalVisualBuilder.BuildAnimalModel(speciesId: string, sizeRatio: number, mutation: Types.AnimalMutation, lowVFX: boolean?): Model
	local spec = AnimalConfig.GetById(speciesId) or AnimalConfig.ALL[1]
	local primaryCol, secondaryCol, mat, transparency, prof = resolveMutationStyle(spec, mutation)
	local accentMat = if prof.accentNeon then Enum.Material.SmoothPlastic else mat
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
		local leg = makeBox("Leg_" .. idx, Vector3.new(0.55 * s, 0.9 * s, 0.55 * s), CFrame.new(off), secondaryCol, accentMat, model)
		leg.Transparency = transparency
	end

	-- Head & Snout (facing -Z forward)
	local headSize = if spec.shapeStyle == "Bear" then Vector3.new(2.0 * s, 1.8 * s, 1.8 * s) else Vector3.new(1.7 * s, 1.5 * s, 1.6 * s)
	local head = makeBox("Head", headSize, CFrame.new(0, 2.15 * s, -1.45 * s), primaryCol, mat, model)
	head.Transparency = transparency

	local snoutColor = if spec.shapeStyle == "Bird" then Color3.fromRGB(255, 186, 48) else secondaryCol
	local snoutSize = if spec.shapeStyle == "Bird" then Vector3.new(0.6 * s, 0.45 * s, 0.9 * s) else Vector3.new(1.0 * s, 0.65 * s, 0.7 * s)
	local snout = makeBox("Snout", snoutSize, CFrame.new(0, 1.9 * s, -2.35 * s), snoutColor, accentMat, model)
	snout.Transparency = transparency

	-- Cute Eyes
	for _, ex in { -0.45 * s, 0.45 * s } do
		makeBox("Eye", Vector3.new(0.28 * s, 0.34 * s, 0.2 * s), CFrame.new(ex, 2.35 * s, -2.26 * s), spec.eyeColor, Enum.Material.Neon, model)
	end

	-- Silhouette Details (Ears, Antlers, Wings, or Tail)
	if spec.shapeStyle == "Canine" or spec.shapeStyle == "Feline" or spec.shapeStyle == "Critter" then
		for _, ex in { -0.58 * s, 0.58 * s } do
			local ear = makeBox("Ear", Vector3.new(0.4 * s, 0.65 * s, 0.35 * s), CFrame.new(ex, 3.15 * s, -1.3 * s), secondaryCol, accentMat, model)
			ear.Transparency = transparency
		end
		local tail = makeBox("Tail", Vector3.new(0.55 * s, 0.55 * s, 1.2 * s), CFrame.new(0, 1.6 * s, 1.8 * s) * CFrame.Angles(math.rad(25), 0, 0), secondaryCol, accentMat, model)
		tail.Transparency = transparency
	elseif spec.shapeStyle == "Hooved" then
		for _, ex in { -0.6 * s, 0.6 * s } do
			makeBox("Horn", Vector3.new(0.26 * s, 0.95 * s, 0.26 * s), CFrame.new(ex, 3.25 * s, -1.2 * s) * CFrame.Angles(0, 0, math.rad(if ex < 0 then 14 else -14)), secondaryCol, accentMat, model)
		end
	elseif spec.shapeStyle == "Bird" then
		for _, wx in { -1.3 * s, 1.3 * s } do
			local wing = makeBox("Wing", Vector3.new(0.45 * s, 1.1 * s, 1.8 * s), CFrame.new(wx, 1.45 * s, 0), secondaryCol, accentMat, model)
			wing.Transparency = transparency
		end
	elseif spec.shapeStyle == "Reptile" then
		local tail = makeBox("Tail", Vector3.new(0.8 * s, 0.55 * s, 1.9 * s), CFrame.new(0, 1.0 * s, 2.1 * s), secondaryCol, accentMat, model)
		tail.Transparency = transparency
		for sp = -0.5, 0.7, 0.6 do
			makeBox("Ridge", Vector3.new(0.35 * s, 0.4 * s, 0.4 * s), CFrame.new(0, 2.15 * s, sp * s), secondaryCol, accentMat, model)
		end
	end

	-- Distinct 3D geometric ornaments on body for mutated species (visible in Viewport AND World!)
	attachMutationOrnaments(model, root, s, prof, secondaryCol)

	-- Subtle Body VFX for world animals (ParticleEmitter + Soft Highlight; no stacking PointLights in pens!)
	if not lowVFX and mutation ~= "None" then
		if prof.particleRate > 0 and prof.particleColor then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "MutationVFX"
			emitter.Rate = math.max(3, math.round(prof.particleRate * 0.55))
			emitter.Lifetime = NumberRange.new(0.75, 1.35)
			emitter.Speed = prof.particleSpeed
			emitter.SpreadAngle = Vector2.new(360, 360)
			emitter.Size = prof.particleSize or NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.34 * s),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.LightEmission = 0.22
			emitter.Color = prof.particleColor
			emitter.Parent = root
		end

		if prof.highlightFill or prof.highlightOutline then
			local hl = Instance.new("Highlight")
			hl.Name = "MutationHighlight"
			hl.Adornee = model
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.FillColor = prof.highlightFill or secondaryCol
			hl.FillTransparency = if prof.highlightFill then 0.88 else 1
			hl.OutlineColor = prof.highlightOutline or secondaryCol
			hl.OutlineTransparency = 0.38
			hl.Parent = model
		end
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
		accentCol = Color3.fromRGB(238, 88, 34)
		accentMat = Enum.Material.SmoothPlastic
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
	-- Ground-anchored bottom pivot (Y = 0) so ScaleTo expands upward naturally without sinking
	root.PivotOffset = CFrame.new(0, -baseY, 0)
	crateModel.PrimaryPart = root
	crateModel.WorldPivot = CFrame.new(0, 0, 0)

	local rootCF = root.CFrame
	local hx, hy, hz = boxDims.X * 0.5, boxDims.Y * 0.5, boxDims.Z * 0.5

	-- Textured Nest / Swirl Pedestal Ring underneath (Image 11 style!)
	local discSize = math.max(boxDims.X, boxDims.Z) * 1.38
	local pedestal = makeBox(
		"PedestalBase",
		Vector3.new(0.42 * s, discSize, discSize),
		CFrame.new(0, 0.22 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		accentCol:Lerp(rarityColor, 0.38),
		Enum.Material.Cobblestone,
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
		-- Archetype 3: Octagonal Relic Pod with Crisp Core + Dome Cap
		local podOrb = makeBox("RelicCore", Vector3.new(boxDims.X * 0.78, boxDims.Y * 1.15, boxDims.Z * 0.78), rootCF, rarityColor, Enum.Material.SmoothPlastic, crateModel)
		podOrb.Shape = Enum.PartType.Ball
		podOrb.Transparency = 0.22
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
				local crys = makeBox(
					"IceCrystal",
					Vector3.new(0.55 * s, 1.3 * s, 0.55 * s),
					rootCF * CFrame.new(cx * hx, hy + 0.45 * s, cz * hz) * CFrame.Angles(math.rad(cx * 15), 0, math.rad(cz * -15)),
					Color3.fromRGB(168, 238, 255),
					Enum.Material.Glass,
					crateModel
				)
				crys.Transparency = 0.15
			elseif biomeId == "VolcanicJungle" then
				makeBox(
					"ObsidianHorn",
					Vector3.new(0.52 * s, 1.45 * s, 0.52 * s),
					rootCF * CFrame.new(cx * (hx + 0.1 * s), hy + 0.48 * s, cz * (hz + 0.1 * s)) * CFrame.Angles(math.rad(cz * -18), 0, math.rad(cx * 18)),
					accentCol,
					Enum.Material.SmoothPlastic,
					crateModel
				)
			elseif rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" then
				makeBox(
					"RarityStud",
					Vector3.new(0.56 * s, 0.38 * s, 0.56 * s),
					rootCF * CFrame.new(cx * hx, hy + 0.25 * s, cz * hz),
					rarityColor,
					Enum.Material.SmoothPlastic,
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
				if biomeId == "VolcanicJungle" then Enum.Material.SmoothPlastic else barMat,
				crateModel
			)
		end
	end

	-- Biome side/top trim detail + crisp rarity band
	makeBox(
		"RarityBand",
		Vector3.new(boxDims.X + 0.24 * s, 0.36 * s, boxDims.Z + 0.24 * s),
		rootCF * CFrame.new(0, 0, 0),
		rarityColor,
		Enum.Material.SmoothPlastic,
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

	local tier = GameConfig.GetRarityTier(rarity)
	local secColor = (GameConfig.RARITY_SECONDARY_COLORS :: any)[rarity] or rarityColor

	-- Epic..Primordial crest + Cosmic+ Crown + top tow ring
	if tier >= 4 then
		makeBox(
			"CrestRing",
			Vector3.new(boxDims.X * 0.46, 0.42 * s, boxDims.Z * 0.46),
			rootCF * CFrame.new(0, hy + 0.48 * s, 0) * CFrame.Angles(0, math.rad(45), 0),
			rarityColor,
			Enum.Material.SmoothPlastic,
			crateModel
		)
	end
	if tier >= GameConfig.COSMIC_TIER_THRESHOLD then
		makeBox(
			"CosmicCrownStar",
			Vector3.new(boxDims.X * 0.34, 0.45 * s, boxDims.Z * 0.34),
			rootCF * CFrame.new(0, hy + 0.92 * s, 0) * CFrame.Angles(math.rad(15), math.rad(22), math.rad(-15)),
			secColor,
			Enum.Material.SmoothPlastic,
			crateModel
		)
	end

	local ring = makeBox("TowRing", Vector3.new(1.05 * s, 1.05 * s, 1.05 * s), rootCF * CFrame.new(0, hy + 0.95 * s, 0), rarityColor, Enum.Material.SmoothPlastic, crateModel)
	ring.Shape = Enum.PartType.Ball

	if showBeacon and tier >= 3 then
		local beamHeight = if tier >= GameConfig.COSMIC_TIER_THRESHOLD then 48 + (tier - 6) * 6 else 32
		local beamWidth = if tier >= GameConfig.COSMIC_TIER_THRESHOLD then 1.35 * s else 1.0 * s
		local beacon = makeBox("RarityBeacon", Vector3.new(beamWidth, beamHeight, beamWidth), rootCF * CFrame.new(0, beamHeight * 0.5 + hy, 0), rarityColor, Enum.Material.SmoothPlastic, crateModel)
		beacon.Transparency = 0.82
		if tier >= GameConfig.COSMIC_TIER_THRESHOLD then
			local innerCore = makeBox("CosmicBeaconCore", Vector3.new(0.42 * s, beamHeight + 8, 0.42 * s), rootCF * CFrame.new(0, beamHeight * 0.5 + hy, 0), secColor, Enum.Material.Neon, crateModel)
			innerCore.Transparency = 0.68
		end
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
