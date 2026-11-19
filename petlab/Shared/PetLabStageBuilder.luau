--!strict
-- PetLabStageBuilder.luau
-- Builds the 5-Biome Rarity-Segmented Showroom, anti-glare Studio Workbench floor,
-- turntable stage, scale dummy + height ruler, and ReplicatedStorage.PetLabPrefabs.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local VoxelPets = require(ReplicatedStorage.Modules.VoxelPets)
local AnimalVisualBuilder = require(ReplicatedStorage.Modules.AnimalVisualBuilder)
local VoxelCrateBuilder = require(ReplicatedStorage.Modules.VoxelCrateBuilder)

local PetLabStageBuilder = {}

PetLabStageBuilder.STAGE_TOP_Y = 0.80
PetLabStageBuilder.SHOWROOM_FLOOR_Y = 0.04
PetLabStageBuilder.BIOME_SPAWN_POS = Vector3.new(0, 0.05, 24)
PetLabStageBuilder.STAGING_CENTER_X = 128
PetLabStageBuilder.STAGING_SPAWN_POS = Vector3.new(128, 0.05, 14)
PetLabStageBuilder.TURNTABLESPAWN_POS = Vector3.new(0, 0.05, 26)
PetLabStageBuilder.SPAWN_POS = PetLabStageBuilder.TURNTABLESPAWN_POS
PetLabStageBuilder.TURNTABLE_POS = Vector3.new(0, 0.80, 42)
PetLabStageBuilder.LINEUP_Z = 4

export type BiomeZoneDef = {
	id: string,
	order: number,
	shortLabel: string,
	courtZ: number,
	teleportPos: Vector3,
	accent: Color3,
}

PetLabStageBuilder.BIOME_ZONES = {
	{
		id = "PineWoods",
		order = 1,
		shortLabel = "1 • Pine",
		courtZ = 0,
		teleportPos = Vector3.new(0, 0.05, 18),
		accent = Color3.fromRGB(92, 218, 122),
	},
	{
		id = "MangroveSwamp",
		order = 2,
		shortLabel = "2 • Swamp",
		courtZ = -32,
		teleportPos = Vector3.new(0, 0.05, -14),
		accent = Color3.fromRGB(64, 214, 178),
	},
	{
		id = "SavannaCamp",
		order = 3,
		shortLabel = "3 • Savanna",
		courtZ = -68,
		teleportPos = Vector3.new(0, 0.05, -50),
		accent = Color3.fromRGB(255, 184, 58),
	},
	{
		id = "AlpinePeaks",
		order = 4,
		shortLabel = "4 • Alpine",
		courtZ = -108,
		teleportPos = Vector3.new(0, 0.05, -90),
		accent = Color3.fromRGB(78, 208, 255),
	},
	{
		id = "VolcanicJungle",
		order = 5,
		shortLabel = "5 • Volcanic",
		courtZ = -148,
		teleportPos = Vector3.new(0, 0.05, -130),
		accent = Color3.fromRGB(255, 78, 174),
	},
} :: { BiomeZoneDef }

local BIOME_DEF_BY_ID: { [string]: any } = {}
for _, b in ipairs(BiomeConfig) do
	BIOME_DEF_BY_ID[b.id] = b
end

local function makePart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	canCollide: boolean?,
	transparency: number?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.shape then
		p.Shape = props.shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = props.transparency or 0
	p.Parent = props.parent
	return p
end

local function configureNeutralLighting()
	Lighting.Brightness = 2.0
	Lighting.ClockTime = 13.5
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(115, 122, 136)
	Lighting.OutdoorAmbient = Color3.fromRGB(145, 154, 170)

	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch:IsA("BloomEffect") then
			ch.Intensity = 0.08
			ch.Threshold = 1.6
		end
	end
end

local function buildScaleReference(parent: Instance, origin: Vector3?)
	local ref = Instance.new("Model")
	ref.Name = "ScaleReferenceModel"
	ref.Parent = parent

	local base = origin or Vector3.new(0, 0, 0)
	local dummyX = base.X + 8.0
	local dummyZ = base.Z
	local skin = Color3.fromRGB(206, 214, 226)
	local torsoCol = Color3.fromRGB(78, 134, 212)
	local legCol = Color3.fromRGB(54, 62, 78)

	-- Classic 5-stud blocky character proportions resting at Y = 0
	makePart({
		name = "LegL",
		size = Vector3.new(0.95, 2.0, 0.95),
		cframe = CFrame.new(dummyX - 0.5, 1.0, dummyZ),
		color = legCol,
		parent = ref,
	})
	makePart({
		name = "LegR",
		size = Vector3.new(0.95, 2.0, 0.95),
		cframe = CFrame.new(dummyX + 0.5, 1.0, dummyZ),
		color = legCol,
		parent = ref,
	})
	makePart({
		name = "Torso",
		size = Vector3.new(2.0, 2.0, 1.0),
		cframe = CFrame.new(dummyX, 3.0, dummyZ),
		color = torsoCol,
		parent = ref,
	})
	makePart({
		name = "ArmL",
		size = Vector3.new(0.95, 2.0, 0.95),
		cframe = CFrame.new(dummyX - 1.52, 3.0, dummyZ),
		color = skin,
		parent = ref,
	})
	makePart({
		name = "ArmR",
		size = Vector3.new(0.95, 2.0, 0.95),
		cframe = CFrame.new(dummyX + 1.52, 3.0, dummyZ),
		color = skin,
		parent = ref,
	})
	local head = makePart({
		name = "Head",
		size = Vector3.new(1.15, 1.15, 1.15),
		cframe = CFrame.new(dummyX, 4.575, dummyZ),
		color = skin,
		parent = ref,
	})

	local tag = Instance.new("BillboardGui")
	tag.Name = "DummyTag"
	tag.Size = UDim2.fromOffset(150, 32)
	tag.StudsOffset = Vector3.new(0, 1.25, 0)
	tag.MaxDistance = 80
	tag.Parent = head
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(220, 232, 250)
	tl.TextStrokeTransparency = 0.25
	tl.Text = "Player Ref (5 st)"
	tl.Parent = tag

	-- Height Ruler (1..12 studs) next to the dummy
	local rulerX = dummyX + 1.85
	makePart({
		name = "RulerPost",
		size = Vector3.new(0.14, 12.2, 0.14),
		cframe = CFrame.new(rulerX, 6.1, dummyZ),
		color = Color3.fromRGB(96, 108, 128),
		canCollide = false,
		parent = ref,
	})
	for h = 1, 12 do
		local tick = makePart({
			name = "RulerTick_" .. h,
			size = Vector3.new(0.45, 0.08, 0.16),
			cframe = CFrame.new(rulerX - 0.18, h, dummyZ),
			color = if h % 2 == 0 then Color3.fromRGB(88, 192, 255) else Color3.fromRGB(168, 180, 198),
			canCollide = false,
			parent = ref,
		})
		if h % 2 == 0 then
			local bb = Instance.new("BillboardGui")
			bb.Name = "RulerLbl_" .. h
			bb.Size = UDim2.fromOffset(64, 24)
			bb.StudsOffset = Vector3.new(0.75, 0, 0)
			bb.MaxDistance = 90
			bb.Parent = tick
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.fromRGB(156, 214, 255)
			lbl.TextStrokeTransparency = 0.2
			lbl.Text = tostring(h) .. " st"
			lbl.Parent = bb
		end
	end
end

type RaritySegment = {
	rarity: string,
	tier: number,
	items: { any },
}

local function groupByConsecutiveRarity(speciesList: { any }): { RaritySegment }
	local segments: { RaritySegment } = {}
	local current: RaritySegment? = nil
	for _, spec in ipairs(speciesList) do
		local tier = GameConfig.GetRarityTier(spec.rarity)
		if current and current.rarity == spec.rarity then
			table.insert(current.items, spec)
		else
			local nextSeg: RaritySegment = {
				rarity = spec.rarity,
				tier = tier,
				items = { spec },
			}
			table.insert(segments, nextSeg)
			current = nextSeg
		end
	end
	return segments
end

local function buildBiomeArch(zone: BiomeZoneDef, biomeName: string, maxRarity: string, totalSlots: number, voxelCount: number, parent: Instance)
	local archZ = zone.courtZ + 11.5

	for _, xSide in ipairs({ -20, 20 }) do
		local pillar = makePart({
			name = if xSide < 0 then "ArchPillarL" else "ArchPillarR",
			size = Vector3.new(0.9, 12.6, 0.9),
			cframe = CFrame.new(xSide, 6.3, archZ),
			color = Color3.fromRGB(22, 26, 36),
			canCollide = false,
			parent = parent,
		})
		pillar.CastShadow = false

		local pGlow = makePart({
			name = if xSide < 0 then "ArchGlowL" else "ArchGlowR",
			size = Vector3.new(0.24, 12.0, 0.94),
			cframe = CFrame.new(xSide, 6.3, archZ),
			color = zone.accent,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = parent,
		})
		pGlow.CastShadow = false
	end

	local bannerBoard = makePart({
		name = "BiomeBannerBoard",
		size = Vector3.new(41, 3.0, 0.28),
		cframe = CFrame.new(0, 12.0, archZ) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(16, 20, 30),
		canCollide = false,
		parent = parent,
	})
	bannerBoard.CastShadow = false

	local topGlow = makePart({
		name = "BiomeBannerGlowTop",
		size = Vector3.new(41, 0.12, 0.32),
		cframe = CFrame.new(0, 13.56, archZ),
		color = zone.accent,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
	})
	topGlow.CastShadow = false

	local botGlow = makePart({
		name = "BiomeBannerGlowBottom",
		size = Vector3.new(41, 0.12, 0.32),
		cframe = CFrame.new(0, 10.44, archZ),
		color = zone.accent,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = parent,
	})
	botGlow.CastShadow = false

	local sg = Instance.new("SurfaceGui")
	sg.Name = "BiomeBannerGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 36
	sg.LightInfluence = 0.25
	sg.Parent = bannerBoard

	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.fromScale(1, 1)
	bgFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = sg

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.96, 0, 0.54, 0)
	titleLbl.Position = UDim2.new(0.02, 0, 0.06, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.TextScaled = true
	titleLbl.TextColor3 = zone.accent
	titleLbl.TextStrokeTransparency = 0.2
	titleLbl.Text = string.format("BIOME %d  •  %s", zone.order, string.upper(biomeName))
	titleLbl.Parent = bgFrame

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(0.96, 0, 0.30, 0)
	subLbl.Position = UDim2.new(0.02, 0, 0.64, 0)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextScaled = true
	subLbl.TextColor3 = Color3.fromRGB(224, 234, 248)
	subLbl.TextStrokeTransparency = 0.25
	subLbl.Text = string.format("%d Slots  •  Common – %s  •  %d/%d Voxel 3D Ready", totalSlots, maxRarity, voxelCount, totalSlots)
	subLbl.Parent = bgFrame
end

local function buildRarityRow(
	zone: BiomeZoneDef,
	segments: { RaritySegment },
	rowOpts: {
		rowZ: number,
		slotSpacing: number,
		sidePad: number,
		segGap: number,
		daisDepth: number,
		computeDaisHeight: (number) -> number,
	},
	gallery: Folder,
	zoneModel: Model
)
	if #segments == 0 then
		return
	end

	local segWidths: { number } = {}
	local segSlotSpacings: { number } = {}
	local totalWidth = 0
	for i, seg in ipairs(segments) do
		local slotSp = if seg.tier >= 15 then math.max(rowOpts.slotSpacing, 14.5) else rowOpts.slotSpacing
		local sidePad = if seg.tier >= 15 then math.max(rowOpts.sidePad, 8.2) else rowOpts.sidePad
		local w = math.max(0, #seg.items - 1) * slotSp + sidePad * 2
		segWidths[i] = w
		segSlotSpacings[i] = slotSp
		totalWidth += w
		if i > 1 then
			totalWidth += rowOpts.segGap
		end
	end

	local cursorX = -totalWidth * 0.5
	for i, seg in ipairs(segments) do
		local segWidth = segWidths[i]
		local segCenterX = cursorX + segWidth * 0.5
		cursorX += segWidth + rowOpts.segGap

		local daisHeight = rowOpts.computeDaisHeight(seg.tier)
		local daisTopY = PetLabStageBuilder.SHOWROOM_FLOOR_Y + daisHeight
		local rarityCol = GameConfig.RARITY_COLORS[seg.rarity] or zone.accent

		local segModel = Instance.new("Model")
		segModel.Name = "Segment_" .. seg.rarity
		segModel.Parent = zoneModel

		makePart({
			name = "SegmentDais",
			size = Vector3.new(segWidth, daisHeight, rowOpts.daisDepth),
			cframe = CFrame.new(segCenterX, PetLabStageBuilder.SHOWROOM_FLOOR_Y + daisHeight * 0.5, rowOpts.rowZ),
			color = Color3.fromRGB(24, 29, 40),
			canCollide = true,
			parent = segModel,
		})

		local frontTrim = makePart({
			name = "DaisNeonTrim",
			size = Vector3.new(segWidth, 0.08, 0.16),
			cframe = CFrame.new(segCenterX, daisTopY - 0.04, rowOpts.rowZ + rowOpts.daisDepth * 0.5 + 0.06),
			color = rarityCol,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = segModel,
		})
		frontTrim.CastShadow = false

		-- Tilted floor-edge Rarity Segment Header Plaque facing +Z
		local signW = math.min(segWidth - 0.4, 7.6)
		local segSign = makePart({
			name = "SegmentSign",
			size = Vector3.new(signW, 0.72, 0.12),
			cframe = CFrame.new(segCenterX, daisTopY + 0.22, rowOpts.rowZ + rowOpts.daisDepth * 0.5 + 0.32)
				* CFrame.Angles(math.rad(-25), math.pi, 0),
			color = Color3.fromRGB(16, 20, 28),
			canCollide = false,
			parent = segModel,
		})
		segSign.CastShadow = false

		local signGui = Instance.new("SurfaceGui")
		signGui.Name = "SegmentSignGui"
		signGui.Face = Enum.NormalId.Front
		signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		signGui.PixelsPerStud = 40
		signGui.LightInfluence = 0.25
		signGui.Parent = segSign

		local signBg = Instance.new("Frame")
		signBg.Size = UDim2.fromScale(1, 1)
		signBg.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
		signBg.BorderSizePixel = 0
		signBg.Parent = signGui

		local signLbl = Instance.new("TextLabel")
		signLbl.Size = UDim2.new(0.94, 0, 0.84, 0)
		signLbl.Position = UDim2.new(0.03, 0, 0.08, 0)
		signLbl.BackgroundTransparency = 1
		signLbl.Font = Enum.Font.FredokaOne
		signLbl.TextScaled = true
		signLbl.TextColor3 = rarityCol
		signLbl.TextStrokeTransparency = 0.2
		signLbl.Text = string.format("%s (%d)", string.upper(seg.rarity), #seg.items)
		signLbl.Parent = signBg

		local segSlotSpacing = segSlotSpacings[i]
		local firstSlotX = segCenterX - ((#seg.items - 1) * segSlotSpacing) * 0.5
		for k, spec in ipairs(seg.items) do
			local pedX = firstSlotX + (k - 1) * segSlotSpacing
			local isVoxel = VoxelPets.IsVoxelRigSpecies(spec.id)

			local ped = Instance.new("Model")
			ped.Name = "GallerySlot_" .. spec.id
			ped:SetAttribute("BiomeId", zone.id)
			ped:SetAttribute("BiomeOrder", zone.order)
			ped:SetAttribute("Rarity", spec.rarity)
			ped:SetAttribute("IsVoxel", isVoxel)
			ped:SetAttribute("IsPlaceholder", not isVoxel)
			ped:SetAttribute("SpeciesId", spec.id)

			local strip = makePart({
				name = "FootStrip",
				size = Vector3.new(4.6, 0.03, 0.26),
				cframe = CFrame.new(pedX, daisTopY + 0.015, rowOpts.rowZ + rowOpts.daisDepth * 0.5 - 0.85),
				color = rarityCol,
				canCollide = false,
				parent = ped,
			})
			strip.CastShadow = false

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PetPosePrompt"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			if isVoxel then
				prompt.ActionText = "Cycle Animation"
				prompt.ObjectText = string.format("#%02d %s (%s)", spec.indexNumber, spec.name, spec.rarity)
			else
				prompt.ActionText = "Inspect on Turntable"
				prompt.ObjectText = string.format("#%02d %s (%s • TODO)", spec.indexNumber, spec.name, spec.rarity)
			end
			prompt.Parent = strip

			local mod = VoxelPets.GetSpeciesModule(spec.id)
			local petScale = if isVoxel then (if mod and mod.DefaultScale then mod.DefaultScale else 1.30) else 1.00
			local galleryPet: Model
			if isVoxel then
				local customVfx = if spec.id == "VharazhulCataclysm"
					then ReplicatedStorage:FindFirstChild("CustomVFXShowcase_VharazhulCataclysm")
					else nil
				if customVfx and customVfx:IsA("Model") then
					galleryPet = customVfx:Clone()
					galleryPet.Name = "Animal_VharazhulCataclysm"
				else
					galleryPet = VoxelPets.Build(spec.id, petScale, "None", false)
				end
			else
				galleryPet = AnimalVisualBuilder.BuildAnimalModel(spec.id, petScale, "None", true)
			end
			galleryPet:PivotTo(
				CFrame.lookAt(
					Vector3.new(pedX, daisTopY, rowOpts.rowZ),
					Vector3.new(pedX, daisTopY, rowOpts.rowZ + 10)
				)
			)
			galleryPet:SetAttribute("PetLabGallery", true)
			galleryPet.Parent = ped

			local _, boxSz = galleryPet:GetBoundingBox()
			local tagH = if isVoxel then math.max(6.5, boxSz.Y + 1.0) else 4.6
			local tagAnchor = makePart({
				name = "TagAnchor",
				size = Vector3.new(0.1, 0.1, 0.1),
				cframe = CFrame.new(pedX, daisTopY + tagH, rowOpts.rowZ),
				color = rarityCol,
				canCollide = false,
				transparency = 1,
				parent = ped,
			})
			tagAnchor.CastShadow = false

			local bb = Instance.new("BillboardGui")
			bb.Name = "GalleryTag"
			bb.Size = UDim2.new(6.8, 0, 1.85, 0)
			bb.StudsOffset = Vector3.zero
			bb.MaxDistance = 56
			bb.Parent = tagAnchor

			local card = Instance.new("Frame")
			card.Size = UDim2.fromScale(1, 1)
			card.BackgroundColor3 = if isVoxel then Color3.fromRGB(14, 24, 22) else Color3.fromRGB(20, 22, 32)
			card.BackgroundTransparency = 0.25
			card.BorderSizePixel = 0
			card.Parent = bb
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.22, 0)
			corner.Parent = card
			local stroke = Instance.new("UIStroke")
			stroke.Color = rarityCol
			stroke.Thickness = if isVoxel then 2.0 else 1.4
			stroke.Parent = card

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.94, 0, 0.50, 0)
			nameLbl.Position = UDim2.new(0.03, 0, 0.04, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.FredokaOne
			nameLbl.TextScaled = true
			nameLbl.TextColor3 = Color3.new(1, 1, 1)
			nameLbl.TextStrokeTransparency = 0.2
			nameLbl.Text = string.format("#%02d %s", spec.indexNumber, spec.name)
			nameLbl.Parent = card

			local tierLbl = Instance.new("TextLabel")
			tierLbl.Size = UDim2.new(0.94, 0, 0.40, 0)
			tierLbl.Position = UDim2.new(0.03, 0, 0.54, 0)
			tierLbl.BackgroundTransparency = 1
			tierLbl.Font = Enum.Font.GothamBold
			tierLbl.TextScaled = true
			tierLbl.TextStrokeTransparency = 0.2
			if isVoxel then
				tierLbl.TextColor3 = Color3.fromRGB(108, 255, 178)
				tierLbl.Text = string.format("[%s • VOXEL 3D]  $%s/s", string.upper(spec.rarity), FormatUtil.Number(spec.baseIncomePerSec))
			else
				tierLbl.TextColor3 = rarityCol
				tierLbl.Text = string.format("[%s • TODO • %s]  $%s/s", string.upper(spec.rarity), spec.shapeStyle, FormatUtil.Number(spec.baseIncomePerSec))
			end
			tierLbl.Parent = card

			ped.Parent = gallery
		end
	end
end

local function hasUserVfxDescendants(container: Instance): boolean
	for _, desc in ipairs(container:GetDescendants()) do
		if
			desc:IsA("ParticleEmitter")
			or desc:IsA("Beam")
			or desc:IsA("Trail")
			or desc:IsA("Sparkles")
			or desc:IsA("Fire")
			or desc:IsA("Smoke")
			or desc:IsA("Highlight")
		then
			return true
		end
	end
	return false
end

local function buildVoxelCrateShowcase(opts: {
	name: string,
	pos: Vector3,
	lookDirZ: number,
	crateScale: number,
	daisHeight: number,
	useCylinder: boolean,
	rarity: Types.AnimalRarity?,
	biomeId: string?,
	title: string,
	subtitle: string,
	parent: Instance,
}): Model
	local showcase = Instance.new("Model")
	showcase.Name = opts.name
	showcase.Parent = opts.parent

	local topY = opts.pos.Y + opts.daisHeight
	local crateRarity: Types.AnimalRarity = opts.rarity or "Primordial"
	local crateBiome = opts.biomeId or "VolcanicJungle"
	local accent = GameConfig.RARITY_COLORS[crateRarity] or Color3.fromRGB(255, 34, 78)

	if opts.useCylinder then
		makePart({
			name = "CratePlinthBase",
			size = Vector3.new(0.36, 8.6, 8.6),
			cframe = CFrame.new(opts.pos.X, opts.pos.Y + 0.18, opts.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(24, 20, 28),
			shape = Enum.PartType.Cylinder,
			parent = showcase,
		})
		makePart({
			name = "CratePlinthDeck",
			size = Vector3.new(math.max(0.2, opts.daisHeight - 0.36), 7.8, 7.8),
			cframe = CFrame.new(opts.pos.X, opts.pos.Y + 0.36 + (opts.daisHeight - 0.36) * 0.5, opts.pos.Z)
				* CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(36, 30, 44),
			shape = Enum.PartType.Cylinder,
			parent = showcase,
		})
		local ring = makePart({
			name = "CratePlinthRing",
			size = Vector3.new(0.10, 8.05, 8.05),
			cframe = CFrame.new(opts.pos.X, topY - 0.05, opts.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color = accent,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Cylinder,
			canCollide = false,
			parent = showcase,
		})
		ring.CastShadow = false
	else
		makePart({
			name = "CratePlinthDais",
			size = Vector3.new(8.2, opts.daisHeight, 8.8),
			cframe = CFrame.new(opts.pos.X, opts.pos.Y + opts.daisHeight * 0.5, opts.pos.Z),
			color = Color3.fromRGB(24, 20, 28),
			canCollide = true,
			parent = showcase,
		})
		local trim = makePart({
			name = "CratePlinthTrim",
			size = Vector3.new(8.2, 0.09, 0.18),
			cframe = CFrame.new(opts.pos.X, topY - 0.045, opts.pos.Z + 4.46),
			color = accent,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = showcase,
		})
		trim.CastShadow = false
	end

	local crateModel = AnimalVisualBuilder.BuildCrateModel(crateRarity, crateBiome, opts.crateScale, {
		isBuried = false,
		canCollide = true,
		showBeacon = false,
	})
	crateModel.Name = opts.name .. "_Model"
	crateModel:PivotTo(
		CFrame.lookAt(
			Vector3.new(opts.pos.X, topY, opts.pos.Z),
			Vector3.new(opts.pos.X, topY, opts.pos.Z + opts.lookDirZ * 10)
		)
	)
	crateModel:SetAttribute("PetLabCrateShowcase", true)
	crateModel:SetAttribute("ShowcaseRarity", crateRarity)
	crateModel:SetAttribute("ShowcaseBiome", crateBiome)
	crateModel.Parent = showcase

	if crateModel.PrimaryPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "InspectCrateShowcasePrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.ActionText = "Inspect Crate on Turntable"
		prompt.ObjectText = crateModel:GetAttribute("CrateTitle") or (crateRarity .. " Crate")
		prompt.Parent = crateModel.PrimaryPart
	end

	local _, crateSz = crateModel:GetBoundingBox()
	local tagAnchor = makePart({
		name = "TagAnchor",
		size = Vector3.new(0.1, 0.1, 0.1),
		cframe = CFrame.new(opts.pos.X, topY + math.max(6.8, crateSz.Y + 1.25), opts.pos.Z),
		color = accent,
		canCollide = false,
		transparency = 1,
		parent = showcase,
	})
	tagAnchor.CastShadow = false

	local bb = Instance.new("BillboardGui")
	bb.Name = "CrateShowcaseTag"
	bb.Size = UDim2.new(7.4, 0, 1.95, 0)
	bb.StudsOffset = Vector3.zero
	bb.MaxDistance = 72
	bb.Parent = tagAnchor

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(22, 14, 20)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2.2
	stroke.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0.94, 0, 0.50, 0)
	nameLbl.Position = UDim2.new(0.03, 0, 0.04, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextScaled = true
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.TextStrokeTransparency = 0.2
	nameLbl.Text = opts.title
	nameLbl.Parent = card

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(0.94, 0, 0.40, 0)
	subLbl.Position = UDim2.new(0.03, 0, 0.54, 0)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextScaled = true
	subLbl.TextColor3 = Color3.fromRGB(255, 168, 74)
	subLbl.TextStrokeTransparency = 0.2
	subLbl.Text = opts.subtitle
	subLbl.Parent = card

	return showcase
end

function PetLabStageBuilder.BuildStage(): Folder
	configureNeutralLighting()
	VoxelPets.EnsureMeshTemplatesLoaded()

	local oldCustomShowcase = ReplicatedStorage:FindFirstChild("CustomVFXShowcase_VharazhulCataclysm")
	if oldCustomShowcase then
		oldCustomShowcase:Destroy()
	end

	local old = Workspace:FindFirstChild("PetLabStage")
	if old then
		local oldTt = old:FindFirstChild("CenterTurntable")
		local oldTtShowcase = if oldTt then oldTt:FindFirstChild("VFXStudioShowcase_Turntable") else nil
		local oldGallery = old:FindFirstChild("LineupGallery")
		local oldSlot = if oldGallery then oldGallery:FindFirstChild("GallerySlot_VharazhulCataclysm") else nil
		local oldGalleryPet = if oldSlot then oldSlot:FindFirstChild("Animal_VharazhulCataclysm") else nil
		for _, candidate in ipairs({ oldTtShowcase, oldGalleryPet }) do
			if candidate and candidate:IsA("Model") and hasUserVfxDescendants(candidate) then
				local preserved = candidate:Clone()
				preserved.Name = "CustomVFXShowcase_VharazhulCataclysm"
				preserved.Parent = ReplicatedStorage
				break
			end
		end
		old:Destroy()
	end

	local stage = Instance.new("Folder")
	stage.Name = "PetLabStage"
	stage.Parent = Workspace

	local ttPos = PetLabStageBuilder.TURNTABLE_POS
	local ttX, ttZ = ttPos.X, ttPos.Z

	-- 1. Neutral Studio Floor spanning all 5 Biome Zones + East Candidate Staging Wing
	makePart({
		name = "StudioFloor",
		size = Vector3.new(440, 2, 320),
		cframe = CFrame.new(64, -1, -60),
		color = Color3.fromRGB(40, 46, 58),
		parent = stage,
	})

	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "MeasurementGrid"
	gridFolder.Parent = stage
	for i = -20, 20, 5 do
		local isMajor = (i % 10 == 0)
		local col = if isMajor then Color3.fromRGB(74, 86, 108) else Color3.fromRGB(54, 62, 78)
		local thick = if isMajor then 0.08 else 0.04
		makePart({
			name = "GridX_" .. i,
			size = Vector3.new(44, 0.02, thick),
			cframe = CFrame.new(ttX, 0.01, ttZ + i),
			color = col,
			canCollide = false,
			parent = gridFolder,
		})
		makePart({
			name = "GridZ_" .. i,
			size = Vector3.new(thick, 0.02, 44),
			cframe = CFrame.new(ttX + i, 0.01, ttZ),
			color = col,
			canCollide = false,
			parent = gridFolder,
		})
	end

	-- 2. Inspection Turntable at Z = 42 behind player spawn
	local turntable = Instance.new("Model")
	turntable.Name = "CenterTurntable"
	turntable.Parent = stage

	makePart({
		name = "TurntableBase",
		size = Vector3.new(0.4, 14.4, 14.4),
		cframe = CFrame.new(ttX, 0.2, ttZ) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(58, 66, 82),
		shape = Enum.PartType.Cylinder,
		parent = turntable,
	})
	makePart({
		name = "TurntableDeck",
		size = Vector3.new(0.4, 12.6, 12.6),
		cframe = CFrame.new(ttX, 0.6, ttZ) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(214, 222, 234),
		shape = Enum.PartType.Cylinder,
		parent = turntable,
	})
	makePart({
		name = "TurntableRing",
		size = Vector3.new(0.1, 12.9, 12.9),
		cframe = CFrame.new(ttX, 0.76, ttZ) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(188, 24, 34),
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		parent = turntable,
	})

	-- Edit-mode showcase for VharazhulCataclysm on the Center Turntable (clean rig for manual VFX)
	local showcaseBoss = VoxelPets.Build("VharazhulCataclysm", 1.50, "None", false)
	showcaseBoss.Name = "VFXStudioShowcase_Turntable"
	showcaseBoss:PivotTo(
		CFrame.lookAt(
			Vector3.new(ttX, PetLabStageBuilder.STAGE_TOP_Y, ttZ),
			Vector3.new(ttX, PetLabStageBuilder.STAGE_TOP_Y, ttZ - 10)
		)
	)
	showcaseBoss.Parent = turntable

	-- 3. 5-Stud Scale Dummy + Height Ruler next to the turntable + Hero Primordial Voxel Crate Showcase
	buildScaleReference(stage, Vector3.new(ttX, 0, ttZ))
	buildVoxelCrateShowcase({
		name = "Showcase_PrimordialCrate",
		pos = Vector3.new(ttX - 9.8, 0, ttZ),
		lookDirZ = -1,
		crateScale = 1.25,
		daisHeight = PetLabStageBuilder.STAGE_TOP_Y,
		useCylinder = true,
		rarity = "Primordial",
		biomeId = "VolcanicJungle",
		title = "PRIMORDIAL VOXEL BOX",
		subtitle = "[PRIMORDIAL CRATE • VOXEL 3D]  [E] Inspect",
		parent = stage,
	})

	-- 4. Dark Checkerboard Showroom Floor (8-stud tiles covering X = -64..64, Z = -168..32) & Back Wall
	local checkerFolder = Instance.new("Folder")
	checkerFolder.Name = "DarkCheckerboardBackdrop"

	local wallZ = -166.0
	makePart({
		name = "ShowroomBackWallBase",
		size = Vector3.new(136, 32, 0.4),
		cframe = CFrame.new(0, 15.8, wallZ - 0.15),
		color = Color3.fromRGB(26, 31, 41),
		canCollide = false,
		parent = checkerFolder,
	})

	local tileSize = 8
	local darkTile = Color3.fromRGB(28, 34, 45)
	local lightTile = Color3.fromRGB(38, 46, 60)

	for ix = -8, 7 do
		local cx = ix * tileSize + tileSize * 0.5
		for iy = 0, 3 do
			local cy = iy * tileSize + tileSize * 0.5
			local isLight = ((ix + iy) % 2 == 0)
			local t = makePart({
				name = string.format("WallTile_%d_%d", ix, iy),
				size = Vector3.new(tileSize, tileSize, 0.18),
				cframe = CFrame.new(cx, cy, wallZ + 0.08),
				color = if isLight then lightTile else darkTile,
				canCollide = false,
				parent = checkerFolder,
			})
			t.CastShadow = false
		end
	end

	for ix = -8, 7 do
		local cx = ix * tileSize + tileSize * 0.5
		for iz = -21, 3 do
			local cz = iz * tileSize + tileSize * 0.5
			local isLight = ((ix + iz) % 2 == 0)
			makePart({
				name = string.format("FloorTile_%d_%d", ix, iz),
				size = Vector3.new(tileSize, 0.08, tileSize),
				cframe = CFrame.new(cx, PetLabStageBuilder.SHOWROOM_FLOOR_Y - 0.04, cz),
				color = if isLight then Color3.fromRGB(36, 44, 58) else Color3.fromRGB(26, 32, 43),
				parent = checkerFolder,
			})
		end
	end

	-- East Wing Dark Checkerboard Court & Back Wall for New Candidate Staging Lab (X = 64..192, Z = -32..24)
	local stagingWallZ = -28.0
	makePart({
		name = "StagingBackWallBase",
		size = Vector3.new(128, 26, 0.4),
		cframe = CFrame.new(PetLabStageBuilder.STAGING_CENTER_X, 12.8, stagingWallZ - 0.15),
		color = Color3.fromRGB(24, 29, 40),
		canCollide = false,
		parent = checkerFolder,
	})
	for ix = 8, 23 do
		local cx = ix * tileSize + tileSize * 0.5
		for iy = 0, 2 do
			local cy = iy * tileSize + tileSize * 0.5
			local isLight = ((ix + iy) % 2 == 0)
			local wt = makePart({
				name = string.format("StagingWallTile_%d_%d", ix, iy),
				size = Vector3.new(tileSize, tileSize, 0.18),
				cframe = CFrame.new(cx, cy, stagingWallZ + 0.08),
				color = if isLight then lightTile else darkTile,
				canCollide = false,
				parent = checkerFolder,
			})
			wt.CastShadow = false
		end
		for iz = -4, 2 do
			local cz = iz * tileSize + tileSize * 0.5
			local isLight = ((ix + iz) % 2 == 0)
			makePart({
				name = string.format("StagingFloorTile_%d_%d", ix, iz),
				size = Vector3.new(tileSize, 0.08, tileSize),
				cframe = CFrame.new(cx, PetLabStageBuilder.SHOWROOM_FLOOR_Y - 0.04, cz),
				color = if isLight then Color3.fromRGB(36, 44, 58) else Color3.fromRGB(26, 32, 43),
				parent = checkerFolder,
			})
		end
	end
	checkerFolder.Parent = stage

	-- Sync SpawnLocation & subtle matte spawn ring at Z = 24
	local spawnLoc = Workspace:FindFirstChild("SpawnLocation")
	if spawnLoc and spawnLoc:IsA("SpawnLocation") then
		spawnLoc.CFrame = CFrame.new(PetLabStageBuilder.SPAWN_POS)
		spawnLoc.Size = Vector3.new(6, 0.1, 6)
		spawnLoc.Transparency = 1
		spawnLoc.CanCollide = false
		spawnLoc.Anchored = true
		spawnLoc.Duration = 0
	end
	local spawnPos = PetLabStageBuilder.SPAWN_POS
	local spawnRing = makePart({
		name = "ShowroomSpawnRing",
		size = Vector3.new(0.02, 5.6, 5.6),
		cframe = CFrame.new(spawnPos.X, PetLabStageBuilder.SHOWROOM_FLOOR_Y + 0.01, spawnPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(64, 148, 224),
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		parent = stage,
	})
	spawnRing.CastShadow = false
	local spawnInner = makePart({
		name = "ShowroomSpawnInner",
		size = Vector3.new(0.026, 5.1, 5.1),
		cframe = CFrame.new(spawnPos.X, PetLabStageBuilder.SHOWROOM_FLOOR_Y + 0.013, spawnPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(28, 34, 45),
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		parent = stage,
	})
	spawnInner.CastShadow = false

	-- 5. Five Biome Courts Segmented by Rarity Tier + LineupGallery
	local gallery = Instance.new("Folder")
	gallery.Name = "LineupGallery"
	gallery.Parent = stage

	local biomeZonesFolder = Instance.new("Folder")
	biomeZonesFolder.Name = "BiomeZones"
	biomeZonesFolder.Parent = gallery

	local oldPrefabs = ReplicatedStorage:FindFirstChild("PetLabPrefabs")
	if oldPrefabs then
		oldPrefabs:Destroy()
	end
	local prefabs = Instance.new("Folder")
	prefabs.Name = "PetLabPrefabs"
	prefabs.Parent = ReplicatedStorage

	for _, id in ipairs(VoxelPets.GetSpeciesIds()) do
		local prefab = VoxelPets.Build(id, 1.30, "None", false)
		prefab.Parent = prefabs
	end
	local crateRarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Divine", "Astral", "Singularity", "Primordial" }
	for _, cr in ipairs(crateRarities) do
		local cp = AnimalVisualBuilder.BuildCrateModel(cr :: any, "PineWoods", 1.0, {
			isBuried = false,
			canCollide = false,
			showBeacon = false,
		})
		cp.Name = cr .. "VoxelCrate"
		cp.Parent = prefabs
	end

	for _, zone in ipairs(PetLabStageBuilder.BIOME_ZONES) do
		local biomeDef = BIOME_DEF_BY_ID[zone.id]
		local biomeName = if biomeDef then biomeDef.name else zone.id
		local maxRarity = if biomeDef then biomeDef.maxRarity else "Legendary"

		local speciesInBiome = AnimalConfig.GetByBiome(zone.id)
		local voxelCount = 0
		for _, sp in ipairs(speciesInBiome) do
			if VoxelPets.IsVoxelRigSpecies(sp.id) then
				voxelCount += 1
			end
		end

		local zoneModel = Instance.new("Model")
		zoneModel.Name = string.format("BiomeZone_%d_%s", zone.order, zone.id)
		zoneModel.Parent = biomeZonesFolder

		buildBiomeArch(zone, biomeName, maxRarity, #speciesInBiome, voxelCount, zoneModel)

		local allSegments = groupByConsecutiveRarity(speciesInBiome)
		local stdSegments: { RaritySegment } = {}
		local apexSegments: { RaritySegment } = {}
		for _, seg in ipairs(allSegments) do
			if seg.tier <= 6 then
				table.insert(stdSegments, seg)
			else
				table.insert(apexSegments, seg)
			end
		end

		buildRarityRow(zone, stdSegments, {
			rowZ = zone.courtZ + 4.0,
			slotSpacing = 6.6,
			sidePad = 2.8,
			segGap = 1.8,
			daisDepth = 6.8,
			computeDaisHeight = function(tier: number): number
				return 0.12 + tier * 0.02
			end,
		}, gallery, zoneModel)

		buildRarityRow(zone, apexSegments, {
			rowZ = zone.courtZ - 8.0,
			slotSpacing = 8.4,
			sidePad = 3.8,
			segGap = 2.2,
			daisDepth = 8.8,
			computeDaisHeight = function(tier: number): number
				return if tier >= 15 then 0.92 else 0.42 + (tier - 7) * 0.04
			end,
		}, gallery, zoneModel)

		-- Showcase the Biome Max Crate in each biome zone
		local biomeMaxRarity = maxRarity
		local segApex = zoneModel:FindFirstChild("Segment_" .. biomeMaxRarity) or zoneModel:FindFirstChild("Segment_Primordial")
		local segDais = if segApex then segApex:FindFirstChild("SegmentDais") else nil
		local crateX = if segDais and segDais:IsA("BasePart")
			then segDais.Position.X + segDais.Size.X * 0.5 + 5.8
			else 26.0
		local crateZ = if segDais and segDais:IsA("BasePart")
			then segDais.Position.Z
			else (zone.courtZ - 8.0)

		local title = string.upper(VoxelCrateBuilder.GetTitle(biomeMaxRarity))
		local subtitle = string.format("[%s MAX • %s • VOXEL 3D]", string.upper(zone.id), string.upper(biomeMaxRarity))

		buildVoxelCrateShowcase({
			name = "Showcase_BiomeCrate_" .. zone.id,
			pos = Vector3.new(crateX, PetLabStageBuilder.SHOWROOM_FLOOR_Y, crateZ),
			lookDirZ = 1,
			crateScale = if biomeMaxRarity == "Primordial" then 1.35 else 1.25,
			daisHeight = if biomeMaxRarity == "Primordial" then 0.92 else 0.70,
			useCylinder = false,
			rarity = biomeMaxRarity,
			biomeId = zone.id,
			title = title,
			subtitle = subtitle,
			parent = zoneModel,
		})
	end

	-- 6. Dedicated Candidate Staging Wing (East Court @ X = 128): Voxel Front Row vs Lightweight Realistic Back Row
	local stagingPairs = VoxelPets.GetStagingPairs()
	if #stagingPairs > 0 then
		local stX = PetLabStageBuilder.STAGING_CENTER_X
		local stagingZone = Instance.new("Model")
		stagingZone.Name = "CandidateStagingWing"
		stagingZone.Parent = biomeZonesFolder

		local stAccent = Color3.fromRGB(72, 228, 255)
		local realAccent = Color3.fromRGB(98, 248, 184)
		local bannerZ = -27.2

		for _, xSide in ipairs({ stX - 52, stX + 52 }) do
			local p = makePart({
				name = if xSide < stX then "StagingPillarL" else "StagingPillarR",
				size = Vector3.new(1.0, 14.0, 1.0),
				cframe = CFrame.new(xSide, 7.0, bannerZ),
				color = Color3.fromRGB(22, 26, 36),
				canCollide = false,
				parent = stagingZone,
			})
			p.CastShadow = false
			local g = makePart({
				name = if xSide < stX then "StagingGlowL" else "StagingGlowR",
				size = Vector3.new(0.26, 13.4, 1.04),
				cframe = CFrame.new(xSide, 7.0, bannerZ),
				color = stAccent,
				material = Enum.Material.Neon,
				canCollide = false,
				parent = stagingZone,
			})
			g.CastShadow = false
		end

		local stBoard = makePart({
			name = "StagingBannerBoard",
			size = Vector3.new(86, 3.2, 0.28),
			cframe = CFrame.new(stX, 13.2, bannerZ) * CFrame.Angles(0, math.pi, 0),
			color = Color3.fromRGB(16, 20, 30),
			canCollide = false,
			parent = stagingZone,
		})
		stBoard.CastShadow = false

		for _, yOff in ipairs({ 1.66, -1.66 }) do
			local trim = makePart({
				name = if yOff > 0 then "StagingBannerGlowTop" else "StagingBannerGlowBottom",
				size = Vector3.new(86, 0.12, 0.32),
				cframe = CFrame.new(stX, 13.2 + yOff, bannerZ),
				color = if yOff > 0 then stAccent else realAccent,
				material = Enum.Material.Neon,
				canCollide = false,
				parent = stagingZone,
			})
			trim.CastShadow = false
		end

		local stSg = Instance.new("SurfaceGui")
		stSg.Name = "StagingBannerGui"
		stSg.Face = Enum.NormalId.Front
		stSg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		stSg.PixelsPerStud = 20
		stSg.LightInfluence = 0.25
		stSg.Parent = stBoard

		local stBg = Instance.new("Frame")
		stBg.Size = UDim2.fromScale(1, 1)
		stBg.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
		stBg.BorderSizePixel = 0
		stBg.Parent = stSg

		local stTitle = Instance.new("TextLabel")
		stTitle.Size = UDim2.new(0.96, 0, 0.54, 0)
		stTitle.Position = UDim2.new(0.02, 0, 0.06, 0)
		stTitle.BackgroundTransparency = 1
		stTitle.Font = Enum.Font.FredokaOne
		stTitle.TextScaled = true
		stTitle.TextColor3 = stAccent
		stTitle.TextStrokeTransparency = 0.2
		stTitle.Text = string.format("CANDIDATE STAGING LAB  •  %d NEW PETS (VOXEL vs REALISTIC)", #stagingPairs)
		stTitle.Parent = stBg

		local stSub = Instance.new("TextLabel")
		stSub.Size = UDim2.new(0.96, 0, 0.30, 0)
		stSub.Position = UDim2.new(0.02, 0, 0.64, 0)
		stSub.BackgroundTransparency = 1
		stSub.Font = Enum.Font.GothamBold
		stSub.TextScaled = true
		stSub.TextColor3 = Color3.fromRGB(224, 238, 248)
		stSub.TextStrokeTransparency = 0.25
		stSub.Text = "Front Row: Artisan Voxel 3D  •  Back Row: Lightweight Realistic 3D  •  [E] Cycle Animation  •  [1]-[5] Biomes"
		stSub.Parent = stBg

		-- Scale Dummy on East Wing right edge for instant visual size reference
		buildScaleReference(stagingZone, Vector3.new(stX + 46, 0, -11.5))

		local pairSpacing = 10.8
		local daisWidth = (#stagingPairs - 1) * pairSpacing + 10.4
		local rowDefs = {
			{
				style = "Voxel",
				title = string.format("ARTISAN VOXEL 3D (%d)", #stagingPairs),
				rowZ = -5.0,
				daisHeight = 0.18,
				daisDepth = 7.4,
				accent = stAccent,
			},
			{
				style = "Realistic",
				title = string.format("LIGHTWEIGHT REALISTIC 3D (%d)", #stagingPairs),
				rowZ = -18.2,
				daisHeight = 0.52,
				daisDepth = 7.8,
				accent = realAccent,
			},
		}

		for _, rDef in ipairs(rowDefs) do
			local daisTopY = PetLabStageBuilder.SHOWROOM_FLOOR_Y + rDef.daisHeight
			makePart({
				name = "StagingDais_" .. rDef.style,
				size = Vector3.new(daisWidth, rDef.daisHeight, rDef.daisDepth),
				cframe = CFrame.new(stX, PetLabStageBuilder.SHOWROOM_FLOOR_Y + rDef.daisHeight * 0.5, rDef.rowZ),
				color = Color3.fromRGB(24, 29, 40),
				canCollide = true,
				parent = stagingZone,
			})
			local dTrim = makePart({
				name = "StagingDaisTrim_" .. rDef.style,
				size = Vector3.new(daisWidth, 0.09, 0.18),
				cframe = CFrame.new(stX, daisTopY - 0.045, rDef.rowZ + rDef.daisDepth * 0.5 + 0.07),
				color = rDef.accent,
				material = Enum.Material.Neon,
				canCollide = false,
				parent = stagingZone,
			})
			dTrim.CastShadow = false

			local rSign = makePart({
				name = "StagingRowSign_" .. rDef.style,
				size = Vector3.new(11.6, 0.76, 0.12),
				cframe = CFrame.new(stX, daisTopY + 0.24, rDef.rowZ + rDef.daisDepth * 0.5 + 0.36)
					* CFrame.Angles(math.rad(-25), math.pi, 0),
				color = Color3.fromRGB(16, 20, 28),
				canCollide = false,
				parent = stagingZone,
			})
			rSign.CastShadow = false
			local rsGui = Instance.new("SurfaceGui")
			rsGui.Face = Enum.NormalId.Front
			rsGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			rsGui.PixelsPerStud = 40
			rsGui.LightInfluence = 0.25
			rsGui.Parent = rSign
			local rsBg = Instance.new("Frame")
			rsBg.Size = UDim2.fromScale(1, 1)
			rsBg.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
			rsBg.BorderSizePixel = 0
			rsBg.Parent = rsGui
			local rsLbl = Instance.new("TextLabel")
			rsLbl.Size = UDim2.new(0.94, 0, 0.84, 0)
			rsLbl.Position = UDim2.new(0.03, 0, 0.08, 0)
			rsLbl.BackgroundTransparency = 1
			rsLbl.Font = Enum.Font.FredokaOne
			rsLbl.TextScaled = true
			rsLbl.TextColor3 = rDef.accent
			rsLbl.TextStrokeTransparency = 0.2
			rsLbl.Text = rDef.title
			rsLbl.Parent = rsBg

			local firstX = stX - ((#stagingPairs - 1) * pairSpacing) * 0.5
			for idx, pair in ipairs(stagingPairs) do
				local spId = if rDef.style == "Realistic" then pair.realisticId else pair.voxelId
				if spId then
					local pedX = firstX + (idx - 1) * pairSpacing
					local mod = VoxelPets.GetSpeciesModule(spId)
					local petScale = if mod and mod.DefaultScale then mod.DefaultScale else 1.30
					local slotAccent = if mod and mod.AccentColor then mod.AccentColor else rDef.accent
					local cleanTitle = if mod then string.gsub(mod.DisplayName, " %(Realistic%)$", "") else spId

					local ped = Instance.new("Model")
					ped.Name = "GallerySlot_" .. spId
					ped:SetAttribute("BiomeId", "Staging")
					ped:SetAttribute("BiomeOrder", 0)
					ped:SetAttribute("IsStaging", true)
					ped:SetAttribute("StagingSlot", pair.slot)
					ped:SetAttribute("VisualStyle", rDef.style)
					ped:SetAttribute("IsVoxel", true)
					ped:SetAttribute("IsPlaceholder", false)
					ped:SetAttribute("SpeciesId", spId)

					local strip = makePart({
						name = "FootStrip",
						size = Vector3.new(5.4, 0.03, 0.28),
						cframe = CFrame.new(pedX, daisTopY + 0.015, rDef.rowZ + rDef.daisDepth * 0.5 - 0.85),
						color = rDef.accent,
						canCollide = false,
						parent = ped,
					})
					strip.CastShadow = false

					local galleryPet = VoxelPets.Build(spId, petScale, "None", false)
					galleryPet:PivotTo(
						CFrame.lookAt(
							Vector3.new(pedX, daisTopY, rDef.rowZ),
							Vector3.new(pedX, daisTopY, rDef.rowZ + 10)
						)
					)
					galleryPet:SetAttribute("PetLabGallery", true)
					galleryPet.Parent = ped

					local inspect = VoxelPets.InspectModel(galleryPet)

					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "PetPosePrompt"
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = 11
					prompt.RequiresLineOfSight = false
					prompt.ActionText = "Cycle Animation"
					prompt.ObjectText = string.format("#S%02d %s (%s)", pair.slot, cleanTitle, rDef.style)
					prompt.Parent = strip

					local tagAnchor = makePart({
						name = "TagAnchor",
						size = Vector3.new(0.1, 0.1, 0.1),
						cframe = CFrame.new(pedX, daisTopY + 6.8, rDef.rowZ),
						color = slotAccent,
						canCollide = false,
						transparency = 1,
						parent = ped,
					})
					tagAnchor.CastShadow = false

					local bb = Instance.new("BillboardGui")
					bb.Name = "GalleryTag"
					bb.Size = UDim2.new(7.4, 0, 1.95, 0)
					bb.StudsOffset = Vector3.zero
					bb.MaxDistance = 72
					bb.Parent = tagAnchor

					local card = Instance.new("Frame")
					card.Size = UDim2.fromScale(1, 1)
					card.BackgroundColor3 = if rDef.style == "Realistic"
						then Color3.fromRGB(14, 28, 24)
						else Color3.fromRGB(14, 22, 34)
					card.BackgroundTransparency = 0.22
					card.BorderSizePixel = 0
					card.Parent = bb
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0.22, 0)
					corner.Parent = card
					local stroke = Instance.new("UIStroke")
					stroke.Color = rDef.accent
					stroke.Thickness = 2.0
					stroke.Parent = card

					local nameLbl = Instance.new("TextLabel")
					nameLbl.Size = UDim2.new(0.94, 0, 0.50, 0)
					nameLbl.Position = UDim2.new(0.03, 0, 0.04, 0)
					nameLbl.BackgroundTransparency = 1
					nameLbl.Font = Enum.Font.FredokaOne
					nameLbl.TextScaled = true
					nameLbl.TextColor3 = Color3.new(1, 1, 1)
					nameLbl.TextStrokeTransparency = 0.2
					nameLbl.Text = string.format("#S%02d %s", pair.slot, cleanTitle)
					nameLbl.Parent = card

					local tierLbl = Instance.new("TextLabel")
					tierLbl.Size = UDim2.new(0.94, 0, 0.40, 0)
					tierLbl.Position = UDim2.new(0.03, 0, 0.54, 0)
					tierLbl.BackgroundTransparency = 1
					tierLbl.Font = Enum.Font.GothamBold
					tierLbl.TextScaled = true
					tierLbl.TextStrokeTransparency = 0.2
					tierLbl.TextColor3 = rDef.accent
					tierLbl.Text = if rDef.style == "Realistic"
						then string.format("[AI 3D MESH • %d Parts • Light]", inspect.partCount)
						else string.format("[VOXEL 3D • %d Parts • Rigged]", inspect.partCount)
					tierLbl.Parent = card

					ped.Parent = gallery
				end
			end
		end
	end

	return stage
end

return PetLabStageBuilder
