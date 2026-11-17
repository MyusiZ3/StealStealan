--!strict
-- PetLabStageBuilder.luau
-- Builds the clean, anti-glare Studio Workbench floor, turntable stage, scale dummy + height ruler,
-- lineup gallery pedestals, and ReplicatedStorage.PetLabPrefabs.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VoxelPets = require(ReplicatedStorage.Modules.VoxelPets)

local PetLabStageBuilder = {}

PetLabStageBuilder.STAGE_TOP_Y = 0.80

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

local function buildScaleReference(parent: Instance)
	local ref = Instance.new("Model")
	ref.Name = "ScaleReferenceModel"
	ref.Parent = parent

	local dummyX = 5.6
	local dummyZ = 0
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

	-- Height Ruler (1..8 studs) next to the dummy
	local rulerX = dummyX + 1.85
	makePart({
		name = "RulerPost",
		size = Vector3.new(0.14, 8.2, 0.14),
		cframe = CFrame.new(rulerX, 4.1, dummyZ),
		color = Color3.fromRGB(96, 108, 128),
		canCollide = false,
		parent = ref,
	})
	for h = 1, 8 do
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
			bb.MaxDistance = 70
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

function PetLabStageBuilder.BuildStage(): Folder
	configureNeutralLighting()

	local old = Workspace:FindFirstChild("PetLabStage")
	if old then
		old:Destroy()
	end

	local stage = Instance.new("Folder")
	stage.Name = "PetLabStage"
	stage.Parent = Workspace

	-- 1. Neutral Studio Floor + Subtle Stud Grid Crosshairs
	makePart({
		name = "StudioFloor",
		size = Vector3.new(180, 2, 180),
		cframe = CFrame.new(0, -1, 0),
		color = Color3.fromRGB(40, 46, 58),
		parent = stage,
	})

	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "MeasurementGrid"
	gridFolder.Parent = stage
	for i = -30, 30, 5 do
		local isMajor = (i % 10 == 0)
		local col = if isMajor then Color3.fromRGB(74, 86, 108) else Color3.fromRGB(54, 62, 78)
		local thick = if isMajor then 0.08 else 0.04
		makePart({
			name = "GridX_" .. i,
			size = Vector3.new(64, 0.02, thick),
			cframe = CFrame.new(0, 0.01, i),
			color = col,
			canCollide = false,
			parent = gridFolder,
		})
		makePart({
			name = "GridZ_" .. i,
			size = Vector3.new(thick, 0.02, 64),
			cframe = CFrame.new(i, 0.01, 0),
			color = col,
			canCollide = false,
			parent = gridFolder,
		})
	end

	-- 2. Center Inspection Turntable (top at Y = STAGE_TOP_Y = 0.80)
	local turntable = Instance.new("Model")
	turntable.Name = "CenterTurntable"
	turntable.Parent = stage

	makePart({
		name = "TurntableBase",
		size = Vector3.new(0.4, 11.2, 11.2),
		cframe = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(58, 66, 82),
		shape = Enum.PartType.Cylinder,
		parent = turntable,
	})
	makePart({
		name = "TurntableDeck",
		size = Vector3.new(0.4, 9.6, 9.6),
		cframe = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(214, 222, 234),
		shape = Enum.PartType.Cylinder,
		parent = turntable,
	})
	makePart({
		name = "TurntableRing",
		size = Vector3.new(0.1, 9.9, 9.9),
		cframe = CFrame.new(0, 0.76, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(68, 178, 255),
		shape = Enum.PartType.Cylinder,
		canCollide = false,
		parent = turntable,
	})

	-- 3. 5-Stud Scale Dummy + Height Ruler
	buildScaleReference(stage)

	-- 4. Lineup Gallery & ReplicatedStorage.PetLabPrefabs (Editable for Animation Editor)
	local gallery = Instance.new("Folder")
	gallery.Name = "LineupGallery"
	gallery.Parent = stage

	local oldPrefabs = ReplicatedStorage:FindFirstChild("PetLabPrefabs")
	if oldPrefabs then
		oldPrefabs:Destroy()
	end
	local prefabs = Instance.new("Folder")
	prefabs.Name = "PetLabPrefabs"
	prefabs.Parent = ReplicatedStorage

	local ids = VoxelPets.GetSpeciesIds()
	local spacing = 12
	local startX = -((#ids - 1) * spacing) * 0.5
	local galleryZ = -16

	for idx, id in ipairs(ids) do
		local mod = VoxelPets.GetSpeciesModule(id)
		local accent = if mod then mod.AccentColor else Color3.fromRGB(92, 178, 255)
		local pedX = startX + (idx - 1) * spacing

		-- Save clean AnimSaves-equipped prefab into ReplicatedStorage.PetLabPrefabs
		local prefab = VoxelPets.Build(id, 1.35, "None", false)
		prefab.Parent = prefabs

		local ped = Instance.new("Model")
		ped.Name = "GalleryPedestal_" .. id
		ped.Parent = gallery

		makePart({
			name = "Plinth",
			size = Vector3.new(0.4, 8.2, 8.2),
			cframe = CFrame.new(pedX, 0.2, galleryZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(58, 66, 82),
			shape = Enum.PartType.Cylinder,
			parent = ped,
		})
		local platter = makePart({
			name = "Stage",
			size = Vector3.new(0.4, 7.2, 7.2),
			cframe = CFrame.new(pedX, 0.6, galleryZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(214, 222, 234),
			shape = Enum.PartType.Cylinder,
			parent = ped,
		})
		makePart({
			name = "AccentRim",
			size = Vector3.new(0.1, 7.4, 7.4),
			cframe = CFrame.new(pedX, 0.76, galleryZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = accent,
			shape = Enum.PartType.Cylinder,
			canCollide = false,
			parent = ped,
		})

		local galleryPet = VoxelPets.Build(id, 1.35, "None", false)
		galleryPet:PivotTo(CFrame.lookAt(Vector3.new(pedX, PetLabStageBuilder.STAGE_TOP_Y, galleryZ), Vector3.new(pedX, PetLabStageBuilder.STAGE_TOP_Y, galleryZ + 10)))
		galleryPet:SetAttribute("PetLabGallery", true)
		galleryPet.Parent = ped

		local bb = Instance.new("BillboardGui")
		bb.Name = "GalleryTag"
		bb.Size = UDim2.fromOffset(200, 44)
		bb.StudsOffset = Vector3.new(0, 6.2, 0)
		bb.MaxDistance = 90
		bb.Parent = platter
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextStrokeTransparency = 0.15
		lbl.Text = (if mod then mod.DisplayName else id) .. "\n[" .. (if mod then mod.Archetype else "?") .. "]"
		lbl.Parent = bb
	end

	return stage
end

return PetLabStageBuilder
