--!strict
-- PetLabInspector.client.luau
-- Interactive Studio Workbench UI + 60 FPS Turntable, Joint Pivot Overlay, Camera Presets,
-- Rainbow Hue Cycling, and Live Geometry Validator for VoxelPets.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local AnimalConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AnimalConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local VoxelPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VoxelPets"))
local AnimalVisualBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimalVisualBuilder"))
local CinematicVFX = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CinematicVFX"))
local PetLabStageBuilder = require(ReplicatedStorage:WaitForChild("PetLab"):WaitForChild("PetLabStageBuilder"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local camera = Workspace.CurrentCamera

local STAGE_TOP_Y = PetLabStageBuilder.STAGE_TOP_Y
local TURNTABLE_POS = PetLabStageBuilder.TURNTABLE_POS or Vector3.new(0, STAGE_TOP_Y, 42)
local STAGING_CENTER_X = PetLabStageBuilder.STAGING_CENTER_X or 128
local STAGING_SPAWN_POS = PetLabStageBuilder.STAGING_SPAWN_POS or Vector3.new(STAGING_CENTER_X, 0.05, 14)
local WALK_SPEED = 32
local SPRINT_SPEED = 60
local POSE_CYCLE = { "Sync", "Idle", "Walk", "Fly", "Ride", "StressTest", "BaseC0" }

type InspectorMode = VoxelPets.AnimMode | "BaseC0" | "Pause"
type CameraPreset = "Lineup" | "Orbit34" | "Head" | "Side" | "Top" | "Player"

local speciesList = VoxelPets.GetSpeciesIds()
local stagingPairs = VoxelPets.GetStagingPairs()
local selectedSpecies = "VharazhulCataclysm"
local selectedScale = 1.50
local selectedMutation: Types.AnimalMutation = "None"
local selectedMode: InspectorMode = "Idle"
local previewCrateMode = false
local selectedCrateRarity: Types.AnimalRarity = "Primordial"
local selectedCrateBiome: string = "VolcanicJungle"

local spinSpeedIndex = 1
local SPIN_LABELS = { "Spin: OFF", "Spin: Slow", "Spin: Fast" }
local SPIN_RATES = { 0, 0.45, 1.35 }

local showPivots = false
local showScaleDummy = true
local showPlaceholders = true
local showAuraVFX = true
local focusedBiomeOrder = 5
local uiVisible = true
local isSprinting = false
local cameraPreset: CameraPreset = "Player"
local camYaw = math.rad(18)
local camPitch = math.rad(14)
local camZoom = 1.0
local isDraggingCam = false
local spinAngle = 0
local animTime = 0

local activeModel: Model? = nil
local rainbowParts: { BasePart } = {}
local pivotMarkers: { { motor: Motor6D, dot: Part } } = {}
local pivotFolder: Folder? = nil

type DragState = {
	target: Frame,
	startMouse: Vector2,
	startPos: Vector2,
}

type FloatingWindow = {
	id: string,
	root: Frame,
	headerBar: Frame,
	body: Frame,
	collapseBtn: TextButton,
	closeBtn: TextButton,
	isCollapsed: () -> boolean,
	setCollapsed: (collapsed: boolean) -> (),
	isHidden: () -> boolean,
	setVisible: (visible: boolean) -> (),
	setBodyHeight: (height: number) -> (),
	clamp: () -> (),
	syncGlobalVisibility: () -> (),
}

local activeDrag: DragState? = nil
local userMovedWindow: { [GuiObject]: boolean } = {}
local zCounter = 10

-- UI References
local gui: ScreenGui
local diagBanner: TextLabel
local diagFrame: Frame
local biomeBar: Frame
local camRow: Frame
local launcherBar: Frame
local hideAllBtn: TextButton
local launcherChips: { [string]: TextButton } = {}
local leftWin: FloatingWindow
local topWin: FloatingWindow
local ctrlWin: FloatingWindow
local biomeButtons: { [number]: TextButton } = {}
local speciesButtons: { [string]: TextButton } = {}
local scaleButtons: { [number]: TextButton } = {}
local mutButtons: { [string]: TextButton } = {}
local modeButtons: { [string]: TextButton } = {}
local camButtons: { [string]: TextButton } = {}
local crateToggleBtn: TextButton
local spinBtn: TextButton
local pivotsBtn: TextButton
local dummyBtn: TextButton
local placeholdersBtn: TextButton
local auraBtn: TextButton

local function styleBtn(btn: TextButton, active: boolean, activeCol: Color3?)
	btn.BackgroundColor3 = if active then (activeCol or Color3.fromRGB(48, 138, 232)) else Color3.fromRGB(36, 42, 54)
	btn.TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(205, 214, 230)
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if active then Color3.fromRGB(160, 215, 255) else Color3.fromRGB(64, 74, 92)
		stroke.Thickness = if active then 1.8 else 1
	end
end

local function makeButton(parent: Instance, text: string, size: UDim2, pos: UDim2?, fontSize: number?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	if pos then
		b.Position = pos
	end
	b.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.TextSize = fontSize or 12
	b.TextColor3 = Color3.fromRGB(215, 224, 238)
	b.TextWrapped = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(64, 74, 92)
	stroke.Thickness = 1
	stroke.Parent = b
	return b
end

local HEADER_H = 26

local function getCanvasSize(): Vector2
	if gui and gui.AbsoluteSize.X > 100 and gui.AbsoluteSize.Y > 100 then
		return gui.AbsoluteSize
	end
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return Vector2.new(vp.X, math.max(200, vp.Y - 58))
end

local function clampWindowPos(target: Frame, rawX: number, rawY: number): Vector2
	local vp = getCanvasSize()
	local sizeX = if target.Size.X.Offset > 0 then target.Size.X.Offset else target.AbsoluteSize.X
	local sizeY = if target.Size.Y.Offset > 0 then target.Size.Y.Offset else target.AbsoluteSize.Y
	local margin = 8
	local maxX = math.max(margin, vp.X - sizeX - margin)
	local maxY = math.max(margin, vp.Y - sizeY - margin)
	return Vector2.new(
		math.clamp(math.round(rawX), margin, maxX),
		math.clamp(math.round(rawY), margin, maxY)
	)
end

local function attachDragHandle(handle: GuiObject, target: Frame, onFocus: (() -> ())?)
	handle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if onFocus then
				onFocus()
			end
			activeDrag = {
				target = target,
				startMouse = Vector2.new(input.Position.X, input.Position.Y),
				startPos = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset),
			}
		end
	end)
end

local function makeFloatingWindow(opts: {
	id: string,
	title: string,
	width: number,
	bodyHeight: number,
	pos: Vector2,
	accent: Color3?,
	parent: Instance,
	onVisibilityChanged: (() -> ())?,
}): FloatingWindow
	local collapsed = false
	local userHidden = false
	local width = opts.width
	local bodyH = opts.bodyHeight
	local accent = opts.accent or Color3.fromRGB(78, 138, 224)

	local root = Instance.new("Frame")
	root.Name = "Win_" .. opts.id
	root.Size = UDim2.fromOffset(width, HEADER_H + bodyH)
	root.Position = UDim2.fromOffset(opts.pos.X, opts.pos.Y)
	root.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	root.BackgroundTransparency = 0.14
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	zCounter += 1
	root.ZIndex = zCounter
	root.Parent = opts.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(68, 78, 102)
	stroke.Thickness = 1.3
	stroke.Parent = root

	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, HEADER_H)
	headerBar.Position = UDim2.fromOffset(0, 0)
	headerBar.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
	headerBar.BackgroundTransparency = 0.06
	headerBar.BorderSizePixel = 0
	headerBar.Parent = root

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 2)
	accentBar.Position = UDim2.new(0, 0, 1, -2)
	accentBar.BackgroundColor3 = accent
	accentBar.BackgroundTransparency = 0.35
	accentBar.BorderSizePixel = 0
	accentBar.Parent = headerBar

	local dragRegion = Instance.new("Frame")
	dragRegion.Name = "DragRegion"
	dragRegion.Size = UDim2.new(1, -54, 1, 0)
	dragRegion.Position = UDim2.fromOffset(0, 0)
	dragRegion.BackgroundTransparency = 1
	dragRegion.Active = true
	dragRegion.Parent = headerBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -10, 1, 0)
	titleLbl.Position = UDim2.fromOffset(8, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 11
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextColor3 = Color3.fromRGB(220, 228, 244)
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.Text = "⠿  " .. opts.title
	titleLbl.Parent = dragRegion

	local collapseBtn = makeButton(headerBar, "–", UDim2.fromOffset(22, 18), UDim2.new(1, -50, 0, 4), 12)
	collapseBtn.Name = "CollapseBtn"
	styleBtn(collapseBtn, false, Color3.fromRGB(64, 118, 198))

	local closeBtn = makeButton(headerBar, "×", UDim2.fromOffset(22, 18), UDim2.new(1, -25, 0, 4), 12)
	closeBtn.Name = "CloseBtn"
	closeBtn.BackgroundColor3 = Color3.fromRGB(68, 36, 44)
	closeBtn.TextColor3 = Color3.fromRGB(255, 190, 196)
	local closeStroke = closeBtn:FindFirstChildOfClass("UIStroke")
	if closeStroke then
		closeStroke.Color = Color3.fromRGB(132, 68, 82)
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, bodyH)
	body.Position = UDim2.fromOffset(0, HEADER_H)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = root

	local function bringToFront()
		zCounter += 1
		root.ZIndex = zCounter
		if launcherBar then
			launcherBar.ZIndex = zCounter + 10
		end
	end

	local function clampSelf()
		local cur = Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
		local c = clampWindowPos(root, cur.X, cur.Y)
		root.Position = UDim2.fromOffset(c.X, c.Y)
	end

	local function setCollapsed(c: boolean)
		collapsed = c
		body.Visible = not c
		collapseBtn.Text = if c then "+" else "–"
		root.Size = UDim2.fromOffset(width, if c then HEADER_H else (HEADER_H + bodyH))
		styleBtn(collapseBtn, c, Color3.fromRGB(64, 118, 198))
		clampSelf()
	end

	local function syncGlobalVisibility()
		root.Visible = uiVisible and (not userHidden)
	end

	local function setVisible(v: boolean)
		userHidden = not v
		syncGlobalVisibility()
		if v then
			bringToFront()
			clampSelf()
		end
		if opts.onVisibilityChanged then
			opts.onVisibilityChanged()
		end
	end

	local function setBodyHeight(newH: number)
		bodyH = newH
		body.Size = UDim2.new(1, 0, 0, bodyH)
		if not collapsed then
			root.Size = UDim2.fromOffset(width, HEADER_H + bodyH)
		end
		clampSelf()
	end

	attachDragHandle(dragRegion, root, bringToFront)
	root.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			bringToFront()
		end
	end)

	collapseBtn.MouseButton1Click:Connect(function()
		bringToFront()
		setCollapsed(not collapsed)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		setVisible(false)
	end)

	clampSelf()

	return {
		id = opts.id,
		root = root,
		headerBar = headerBar,
		body = body,
		collapseBtn = collapseBtn,
		closeBtn = closeBtn,
		isCollapsed = function()
			return collapsed
		end,
		setCollapsed = setCollapsed,
		isHidden = function()
			return userHidden
		end,
		setVisible = setVisible,
		setBodyHeight = setBodyHeight,
		clamp = clampSelf,
		syncGlobalVisibility = syncGlobalVisibility,
	}
end

local function clearPivotOverlay()
	table.clear(pivotMarkers)
	if pivotFolder then
		pivotFolder:Destroy()
		pivotFolder = nil
	end
end

local function rebuildPivotOverlay()
	clearPivotOverlay()
	if not showPivots or not activeModel then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PetLabPivotMarkers"
	folder.Parent = Workspace
	pivotFolder = folder

	for _, desc in ipairs(activeModel:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part0 then
			local dot = Instance.new("Part")
			dot.Name = "Pivot_" .. desc.Name
			dot.Shape = Enum.PartType.Ball
			dot.Size = Vector3.new(0.22, 0.22, 0.22) * math.max(0.7, selectedScale * 0.7)
			dot.Color = if desc.Name == "HeadJoint" or desc.Name == "NeckJoint"
				then Color3.fromRGB(255, 212, 64)
				else Color3.fromRGB(68, 228, 255)
			dot.Material = Enum.Material.SmoothPlastic
			dot.Anchored = true
			dot.CanCollide = false
			dot.CanQuery = false
			dot.CanTouch = false
			dot.Parent = folder
			table.insert(pivotMarkers, { motor = desc, dot = dot })
		end
	end
end

local function applyDummyVisibility()
	local stage = Workspace:FindFirstChild("PetLabStage")
	local ref = if stage then stage:FindFirstChild("ScaleReferenceModel") else nil
	if not ref then
		return
	end
	local trMod = if showScaleDummy then 0 else 1
	for _, d in ipairs(ref:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = trMod
		elseif d:IsA("BillboardGui") then
			d.Enabled = showScaleDummy
		end
	end
end

local function applyPlaceholderVisibility()
	local stage = Workspace:FindFirstChild("PetLabStage")
	local gallery = if stage then stage:FindFirstChild("LineupGallery") else nil
	if not gallery then
		return
	end
	local trMod = if showPlaceholders then 0 else 1
	for _, slot in ipairs(gallery:GetChildren()) do
		if slot:IsA("Model") and slot:GetAttribute("IsPlaceholder") == true then
			for _, d in ipairs(slot:GetDescendants()) do
				if d:IsA("BasePart") then
					if d.Name ~= "FootStrip" and d.Name ~= "TagAnchor" then
						d.LocalTransparencyModifier = trMod
					end
				elseif d:IsA("BillboardGui") and d.Name == "GalleryTag" then
					d.Enabled = showPlaceholders
				elseif d:IsA("ProximityPrompt") and d.Name == "PetPosePrompt" then
					d.Enabled = showPlaceholders
				end
			end
		end
	end
end

local function applyAuraInContainer(container: Instance?)
	if not container then
		return
	end
	for _, d in ipairs(container:GetDescendants()) do
		if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and d:GetAttribute("VFXStudioAura") == true then
			d.Enabled = showAuraVFX
		end
	end
end

local function applyAuraVisibility()
	applyAuraInContainer(activeModel)
	local stage = Workspace:FindFirstChild("PetLabStage")
	local gallery = if stage then stage:FindFirstChild("LineupGallery") else nil
	applyAuraInContainer(gallery)
end

local function updateDiagnosticBanner()
	if not activeModel then
		diagBanner.Text = "No active model"
		diagFrame.BackgroundColor3 = Color3.fromRGB(48, 52, 66)
		return
	end
	if previewCrateMode then
		local title = if activeModel then (activeModel:GetAttribute("CrateTitle") or selectedCrateRarity) else selectedCrateRarity
		local pCount = 0
		if activeModel then
			for _, d in ipairs(activeModel:GetDescendants()) do
				if d:IsA("BasePart") then
					pCount += 1
				end
			end
		end
		diagBanner.Text = string.format("CRATE PREVIEW  |  %s (%s)  |  Scale %.2fx  |  %d Parts", tostring(title), selectedCrateRarity, selectedScale, pCount)
		diagFrame.BackgroundColor3 = if selectedCrateRarity == "Primordial" then Color3.fromRGB(118, 22, 46) else Color3.fromRGB(38, 62, 102)
		return
	end
	if not VoxelPets.IsVoxelRigSpecies(selectedSpecies) then
		local spec = AnimalConfig.GetById(selectedSpecies)
		if spec then
			diagBanner.Text = string.format(
				"TODO PLACEHOLDER  |  #%02d %s  |  %s  |  Shape: %s  |  [V] Free Walk",
				spec.indexNumber,
				spec.name,
				spec.rarity,
				spec.shapeStyle
			)
		else
			diagBanner.Text = "TODO PLACEHOLDER  |  " .. selectedSpecies
		end
		diagFrame.BackgroundColor3 = Color3.fromRGB(118, 78, 34)
		return
	end
	local res = VoxelPets.InspectModel(activeModel)
	local mod = VoxelPets.GetSpeciesModule(selectedSpecies)
	local styleTag = if mod and mod.VisualStyle == "Realistic" then "AI 3D MESH OK" else "VOXEL 3D OK"
	if res.ok then
		diagBanner.Text = string.format(
			"%s  |  %d Parts  |  %d Motors  |  Ground %.2f st  |  0 Warnings",
			styleTag,
			res.partCount,
			res.motorCount,
			res.groundOffset
		)
		diagFrame.BackgroundColor3 = if mod and mod.VisualStyle == "Realistic"
			then Color3.fromRGB(22, 108, 84)
			else Color3.fromRGB(26, 98, 58)
	else
		diagBanner.Text = string.format(
			"WARN (%d)  |  %s",
			#res.warnings,
			table.concat(res.warnings, " ; ")
		)
		diagFrame.BackgroundColor3 = Color3.fromRGB(158, 74, 28)
	end
end

local function refreshButtonHighlights()
	for id, btn in pairs(speciesButtons) do
		styleBtn(btn, (not previewCrateMode) and (id == selectedSpecies), Color3.fromRGB(46, 134, 228))
	end
	styleBtn(crateToggleBtn, previewCrateMode, Color3.fromRGB(168, 92, 232))

	for order, btn in pairs(biomeButtons) do
		local col: Color3
		if order == 0 then
			col = Color3.fromRGB(72, 228, 255)
		else
			local zone = PetLabStageBuilder.BIOME_ZONES[order]
			col = if zone then zone.accent else Color3.fromRGB(78, 178, 255)
		end
		styleBtn(btn, order == focusedBiomeOrder, col:Lerp(Color3.fromRGB(22, 28, 40), 0.35))
	end

	for sc, btn in pairs(scaleButtons) do
		styleBtn(btn, math.abs(sc - selectedScale) < 0.01, Color3.fromRGB(42, 168, 118))
	end
	for _, mName in ipairs(GameConfig.MUTATION_ORDER) do
		local btn = mutButtons[mName]
		if btn then
			local mInfo = (GameConfig.MUTATIONS :: any)[mName]
			local col = if mInfo and mInfo.color then mInfo.color else Color3.fromRGB(92, 168, 255)
			styleBtn(btn, mName == selectedMutation, col:Lerp(Color3.fromRGB(28, 34, 48), 0.35))
		end
	end
	for mId, btn in pairs(modeButtons) do
		local actCol = if mId == "StressTest" then Color3.fromRGB(214, 108, 28) else Color3.fromRGB(54, 148, 232)
		styleBtn(btn, mId == selectedMode, actCol)
	end
	for cId, btn in pairs(camButtons) do
		styleBtn(btn, cId == cameraPreset, Color3.fromRGB(88, 128, 224))
	end
	spinBtn.Text = SPIN_LABELS[spinSpeedIndex]
	styleBtn(spinBtn, spinSpeedIndex > 1, Color3.fromRGB(68, 152, 228))
	styleBtn(pivotsBtn, showPivots, Color3.fromRGB(36, 178, 188))
	styleBtn(dummyBtn, showScaleDummy, Color3.fromRGB(78, 142, 206))
	if placeholdersBtn then
		placeholdersBtn.Text = if showPlaceholders then "TODO: ON [P]" else "TODO: OFF [P]"
		styleBtn(placeholdersBtn, showPlaceholders, Color3.fromRGB(196, 134, 48))
	end
	if auraBtn then
		auraBtn.Text = if showAuraVFX then "Aura: ON [G]" else "Aura: OFF [G]"
		styleBtn(auraBtn, showAuraVFX, Color3.fromRGB(224, 72, 168))
	end
	local chipColors: { [string]: Color3 } = {
		Inspector = Color3.fromRGB(58, 134, 224),
		Zones = Color3.fromRGB(48, 168, 132),
		Controls = Color3.fromRGB(142, 102, 226),
	}
	for id, chip in pairs(launcherChips) do
		local winRef = if id == "Inspector" then leftWin elseif id == "Zones" then topWin else ctrlWin
		local isShown = if winRef then (not winRef.isHidden()) else true
		styleBtn(chip, isShown, chipColors[id])
	end
end

local function rebuildActiveModel()
	clearPivotOverlay()
	table.clear(rainbowParts)
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end

	local m: Model
	if previewCrateMode then
		m = AnimalVisualBuilder.BuildCrateModel(selectedCrateRarity, selectedCrateBiome, selectedScale, {
			isBuried = false,
			canCollide = false,
			showBeacon = false,
		})
	elseif VoxelPets.IsVoxelRigSpecies(selectedSpecies) then
		local customVfxTemplate = if selectedSpecies == "VharazhulCataclysm"
				and math.abs(selectedScale - 1.50) < 0.01
				and selectedMutation == "None"
			then ReplicatedStorage:FindFirstChild("CustomVFXShowcase_VharazhulCataclysm")
			else nil
		if customVfxTemplate and customVfxTemplate:IsA("Model") then
			m = customVfxTemplate:Clone()
			m.Name = "Animal_VharazhulCataclysm"
		else
			m = VoxelPets.Build(selectedSpecies, selectedScale, selectedMutation, false)
		end
	else
		m = AnimalVisualBuilder.BuildAnimalModel(selectedSpecies, selectedScale, selectedMutation, false)
	end

	m:PivotTo(CFrame.new(TURNTABLE_POS) * CFrame.Angles(0, spinAngle, 0))
	m.Parent = if cameraPreset == "Lineup" then nil else Workspace
	activeModel = m

	for _, desc in ipairs(m:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("RainbowTarget") == true then
			table.insert(rainbowParts, desc)
		end
	end

	-- Evaluate bind-pose ground clearance before stepping procedural idle/walk offsets
	updateDiagnosticBanner()

	if not previewCrateMode and m:GetAttribute("VoxelRig") == true then
		if selectedMode == "BaseC0" then
			VoxelPets.ResetRig(m)
		elseif selectedMode ~= "Pause" then
			VoxelPets.StepRig(m, selectedMode :: VoxelPets.AnimMode, animTime, 0)
		end
	end

	rebuildPivotOverlay()
	applyAuraInContainer(activeModel)
	refreshButtonHighlights()
end

local function applyCameraPreset(preset: CameraPreset)
	cameraPreset = preset
	if activeModel then
		activeModel.Parent = if preset == "Lineup" then nil else Workspace
	end
	if preset == "Lineup" then
		camYaw = math.rad(0)
		camPitch = math.rad(14)
		camZoom = 1.0
	elseif preset == "Orbit34" then
		camYaw = math.rad(38)
		camPitch = math.rad(16)
		camZoom = 1.0
	elseif preset == "Head" then
		camYaw = math.rad(56)
		camPitch = math.rad(8)
		camZoom = 0.56
	elseif preset == "Side" then
		camYaw = math.rad(90)
		camPitch = math.rad(8)
		camZoom = 1.0
	elseif preset == "Top" then
		camYaw = math.rad(25)
		camPitch = math.rad(58)
		camZoom = 1.15
	elseif preset == "Player" then
		camera.CameraType = Enum.CameraType.Custom
		local ch = localPlayer.Character
		local hum = if ch then ch:FindFirstChildOfClass("Humanoid") else nil
		if hum then
			camera.CameraSubject = hum
		end
		refreshButtonHighlights()
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	refreshButtonHighlights()
end

local function jumpToBiome(biomeOrder: number, forceWalkMode: boolean)
	if biomeOrder == 0 then
		focusedBiomeOrder = 0
		if forceWalkMode or cameraPreset ~= "Lineup" then
			applyCameraPreset("Player")
			local ch = localPlayer.Character
			local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
			if hrp and hrp:IsA("BasePart") then
				local dest = STAGING_SPAWN_POS + Vector3.new(0, 3.0, 0)
				hrp.CFrame = CFrame.lookAt(dest, Vector3.new(STAGING_CENTER_X, dest.Y, -12))
			end
		else
			refreshButtonHighlights()
		end
		return
	end

	local zone = PetLabStageBuilder.BIOME_ZONES[biomeOrder]
	if not zone then
		return
	end
	focusedBiomeOrder = biomeOrder
	if forceWalkMode or cameraPreset ~= "Lineup" then
		applyCameraPreset("Player")
		local ch = localPlayer.Character
		local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
		if hrp and hrp:IsA("BasePart") then
			local dest = zone.teleportPos + Vector3.new(0, 3.0, 0)
			hrp.CFrame = CFrame.lookAt(dest, Vector3.new(0, dest.Y, zone.courtZ - 6))
		end
	else
		refreshButtonHighlights()
	end
end

local function jumpToTurntable(useOrbitCam: boolean)
	if useOrbitCam then
		applyCameraPreset("Orbit34")
		return
	end
	applyCameraPreset("Player")
	local ch = localPlayer.Character
	local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
	if hrp and hrp:IsA("BasePart") then
		local dest = Vector3.new(TURNTABLE_POS.X, 3.2, TURNTABLE_POS.Z - 12)
		hrp.CFrame = CFrame.lookAt(dest, Vector3.new(TURNTABLE_POS.X, 3.2, TURNTABLE_POS.Z))
	end
end

-- Build Clean Studio Inspector ScreenGui
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

gui = Instance.new("ScreenGui")
gui.Name = "PetLabInspectorGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local initVp = getCanvasSize()

-- Persistent Draggable Top-Right Launcher Bar (never hidden by Tab/H; collapses to compact pill)
launcherBar = Instance.new("Frame")
launcherBar.Name = "LauncherBar"
launcherBar.Size = UDim2.fromOffset(346, 30)
launcherBar.Position = UDim2.fromOffset(math.max(8, initVp.X - 354), 8)
launcherBar.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
launcherBar.BackgroundTransparency = 0.12
launcherBar.BorderSizePixel = 0
launcherBar.ZIndex = 50
launcherBar.Parent = gui
local lbCorner = Instance.new("UICorner")
lbCorner.CornerRadius = UDim.new(0, 8)
lbCorner.Parent = launcherBar
local lbStroke = Instance.new("UIStroke")
lbStroke.Color = Color3.fromRGB(74, 88, 116)
lbStroke.Thickness = 1.3
lbStroke.Parent = launcherBar

local launcherGrip = Instance.new("Frame")
launcherGrip.Name = "LauncherGrip"
launcherGrip.Size = UDim2.fromOffset(22, 30)
launcherGrip.Position = UDim2.fromOffset(0, 0)
launcherGrip.BackgroundTransparency = 1
launcherGrip.Active = true
launcherGrip.Parent = launcherBar
local gripText = Instance.new("TextLabel")
gripText.Size = UDim2.fromScale(1, 1)
gripText.BackgroundTransparency = 1
gripText.Font = Enum.Font.GothamBold
gripText.TextSize = 13
gripText.TextColor3 = Color3.fromRGB(160, 180, 214)
gripText.Text = "⠿"
gripText.Parent = launcherGrip
attachDragHandle(launcherGrip, launcherBar)

local launcherDivider = Instance.new("Frame")
launcherDivider.Size = UDim2.new(0, 1, 1, -10)
launcherDivider.Position = UDim2.fromOffset(22, 5)
launcherDivider.BackgroundColor3 = Color3.fromRGB(66, 78, 102)
launcherDivider.BorderSizePixel = 0
launcherDivider.Parent = launcherBar

local chipHost = Instance.new("Frame")
chipHost.Size = UDim2.new(1, -28, 1, 0)
chipHost.Position = UDim2.fromOffset(24, 0)
chipHost.BackgroundTransparency = 1
chipHost.Parent = launcherBar
local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.Padding = UDim.new(0, 4)
chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipLayout.Parent = chipHost

local function setUiVisible(visible: boolean)
	uiVisible = visible
	if leftWin then
		leftWin.syncGlobalVisibility()
	end
	if topWin then
		topWin.syncGlobalVisibility()
	end
	if ctrlWin then
		ctrlWin.syncGlobalVisibility()
	end
	for _, chip in pairs(launcherChips) do
		chip.Visible = visible
	end
	hideAllBtn.Text = if visible then "Hide UI [Tab]" else "Show UI [Tab]"
	styleBtn(hideAllBtn, visible, Color3.fromRGB(44, 56, 78))

	local oldW = launcherBar.Size.X.Offset
	local newW = if visible then 346 else 134
	local newH = if visible then 30 else 28
	launcherGrip.Size = UDim2.fromOffset(22, newH)
	launcherBar.Size = UDim2.fromOffset(newW, newH)
	local targetX = launcherBar.Position.X.Offset + (oldW - newW)
	local clamped = clampWindowPos(launcherBar, targetX, launcherBar.Position.Y.Offset)
	launcherBar.Position = UDim2.fromOffset(clamped.X, clamped.Y)
	refreshButtonHighlights()
end

local LAUNCHER_SPECS: { { id: string, label: string, w: number } } = {
	{ id = "Inspector", label = "Inspector", w = 72 },
	{ id = "Zones", label = "Zones", w = 54 },
	{ id = "Controls", label = "Controls", w = 66 },
}
for idx, spec in ipairs(LAUNCHER_SPECS) do
	local chip = makeButton(chipHost, spec.label, UDim2.fromOffset(spec.w, 22), nil, 10)
	chip.Name = "Chip_" .. spec.id
	chip.LayoutOrder = idx
	chip.TextWrapped = false
	chip.MouseButton1Click:Connect(function()
		local winRef = if spec.id == "Inspector" then leftWin elseif spec.id == "Zones" then topWin else ctrlWin
		if winRef then
			if not uiVisible then
				setUiVisible(true)
			end
			winRef.setVisible(winRef.isHidden())
		end
	end)
	launcherChips[spec.id] = chip
end

hideAllBtn = makeButton(chipHost, "Hide UI [Tab]", UDim2.fromOffset(98, 22), nil, 10)
hideAllBtn.Name = "HideAllBtn"
hideAllBtn.LayoutOrder = 10
hideAllBtn.TextWrapped = false
styleBtn(hideAllBtn, true, Color3.fromRGB(44, 56, 78))
hideAllBtn.MouseButton1Click:Connect(function()
	setUiVisible(not uiVisible)
end)

-- Top Draggable Status & Zone Teleport Window ([0] Stage + [1]-[5] Biomes + [T] Table)
topWin = makeFloatingWindow({
	id = "Zones",
	title = "STATUS & TELEPORT",
	width = 536,
	bodyHeight = 62,
	pos = Vector2.new(math.clamp(math.floor((initVp.X - 536) * 0.5), 244, math.max(244, initVp.X - 544)), 44),
	accent = Color3.fromRGB(56, 178, 136),
	parent = gui,
	onVisibilityChanged = refreshButtonHighlights,
})

diagFrame = Instance.new("Frame")
diagFrame.Size = UDim2.fromOffset(520, 24)
diagFrame.Position = UDim2.fromOffset(8, 4)
diagFrame.BackgroundColor3 = Color3.fromRGB(26, 98, 58)
diagFrame.BorderSizePixel = 0
diagFrame.Parent = topWin.body
local diagCorner = Instance.new("UICorner")
diagCorner.CornerRadius = UDim.new(0, 6)
diagCorner.Parent = diagFrame
local diagStroke = Instance.new("UIStroke")
diagStroke.Color = Color3.fromRGB(22, 26, 36)
diagStroke.Thickness = 1.4
diagStroke.Parent = diagFrame
diagBanner = Instance.new("TextLabel")
diagBanner.Size = UDim2.new(1, -12, 1, 0)
diagBanner.Position = UDim2.fromOffset(6, 0)
diagBanner.BackgroundTransparency = 1
diagBanner.Font = Enum.Font.GothamBold
diagBanner.TextSize = 11
diagBanner.TextColor3 = Color3.new(1, 1, 1)
diagBanner.TextTruncate = Enum.TextTruncate.AtEnd
diagBanner.Text = "Pet Lab Initializing..."
diagBanner.Parent = diagFrame

biomeBar = Instance.new("Frame")
biomeBar.Size = UDim2.fromOffset(520, 26)
biomeBar.Position = UDim2.fromOffset(8, 32)
biomeBar.BackgroundTransparency = 1
biomeBar.BorderSizePixel = 0
biomeBar.Parent = topWin.body
local bBarLayout = Instance.new("UIListLayout")
bBarLayout.FillDirection = Enum.FillDirection.Horizontal
bBarLayout.Padding = UDim.new(0, 4)
bBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
bBarLayout.Parent = biomeBar

local stagingBtn = makeButton(biomeBar, "[0] Stage", UDim2.fromOffset(74, 24), nil, 10)
stagingBtn.TextWrapped = false
stagingBtn.Visible = (#stagingPairs > 0)
stagingBtn.MouseButton1Click:Connect(function()
	jumpToBiome(0, false)
end)
biomeButtons[0] = stagingBtn

local BIOME_SHORT_BTNS: { { label: string, w: number } } = {
	{ label = "[1] Pine", w = 64 },
	{ label = "[2] Swamp", w = 70 },
	{ label = "[3] Savanna", w = 76 },
	{ label = "[4] Alpine", w = 68 },
	{ label = "[5] Volcanic", w = 76 },
}
for i, zone in ipairs(PetLabStageBuilder.BIOME_ZONES) do
	local spec = BIOME_SHORT_BTNS[i]
	local lbl = if spec then spec.label else zone.shortLabel
	local bw = if spec then spec.w else 70
	local btn = makeButton(biomeBar, lbl, UDim2.fromOffset(bw, 24), nil, 10)
	btn.TextWrapped = false
	btn.MouseButton1Click:Connect(function()
		jumpToBiome(zone.order, false)
	end)
	biomeButtons[zone.order] = btn
end

local ttJumpBtn = makeButton(biomeBar, "[T] Table", UDim2.fromOffset(68, 24), nil, 10)
ttJumpBtn.TextWrapped = false
styleBtn(ttJumpBtn, false, Color3.fromRGB(88, 128, 224))
ttJumpBtn.MouseButton1Click:Connect(function()
	jumpToTurntable(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
end)

-- Left Draggable Inspector Window (Species, Scale, Mutations, VFX Test)
leftWin = makeFloatingWindow({
	id = "Inspector",
	title = "PET INSPECTOR",
	width = 224,
	bodyHeight = math.clamp(initVp.Y - 42, 180, 440),
	pos = Vector2.new(12, 8),
	accent = Color3.fromRGB(68, 146, 232),
	parent = gui,
	onVisibilityChanged = refreshButtonHighlights,
})

local lpScroll = Instance.new("ScrollingFrame")
lpScroll.Size = UDim2.new(1, -10, 1, -8)
lpScroll.Position = UDim2.fromOffset(5, 4)
lpScroll.BackgroundTransparency = 1
lpScroll.BorderSizePixel = 0
lpScroll.ScrollBarThickness = 4
lpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
lpScroll.CanvasSize = UDim2.new()
lpScroll.Parent = leftWin.body

local lpLayout = Instance.new("UIListLayout")
lpLayout.Padding = UDim.new(0, 6)
lpLayout.SortOrder = Enum.SortOrder.LayoutOrder
lpLayout.Parent = lpScroll

local function addSectionHeader(titleText: string, order: number)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -4, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = Color3.fromRGB(142, 182, 236)
	lbl.Text = "  " .. titleText
	lbl.LayoutOrder = order
	lbl.Parent = lpScroll
end

local stagingVoxelIds: { string } = {}
local stagingRealIds: { string } = {}
local assignedBiomeIds: { string } = {}

for _, id in ipairs(speciesList) do
	local mod = VoxelPets.GetSpeciesModule(id)
	if mod and mod.StagingSlot and mod.StagingSlot > 0 then
		if mod.VisualStyle == "Realistic" then
			table.insert(stagingRealIds, id)
		else
			table.insert(stagingVoxelIds, id)
		end
	else
		table.insert(assignedBiomeIds, id)
	end
end

local function addSpeciesSection(headerTitle: string, ids: { string }, baseOrder: number)
	if #ids == 0 then
		return
	end
	addSectionHeader(string.format("%s (%d)", headerTitle, #ids), baseOrder)
	for idx, id in ipairs(ids) do
		local mod = VoxelPets.GetSpeciesModule(id)
		local label = if mod then mod.DisplayName else id
		if mod and mod.StagingSlot and mod.StagingSlot > 0 then
			local clean = string.gsub(label, " %(Realistic%)$", "")
			label = string.format("#S%02d %s", mod.StagingSlot, clean)
		end
		local btn = makeButton(lpScroll, label, UDim2.new(1, -6, 0, 28), nil, 11)
		btn.LayoutOrder = baseOrder + idx
		btn.MouseButton1Click:Connect(function()
			previewCrateMode = false
			selectedSpecies = id
			selectedScale = if mod and mod.DefaultScale then mod.DefaultScale else 1.35
			if cameraPreset == "Lineup" then
				applyCameraPreset("Orbit34")
			end
			rebuildActiveModel()
		end)
		speciesButtons[id] = btn
	end
end

addSpeciesSection("STAGING • VOXEL 3D", stagingVoxelIds, 10)
addSpeciesSection("STAGING • REALISTIC 3D", stagingRealIds, 30)
addSpeciesSection("ASSIGNED BIOME VOXELS", assignedBiomeIds, 50)

crateToggleBtn = makeButton(lpScroll, "Preview Crate (Click to Cycle)", UDim2.new(1, -6, 0, 28), nil, 11)
crateToggleBtn.LayoutOrder = 72
local CRATE_RARITIES: { Types.AnimalRarity } = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary",
	"Mythic", "Cosmic", "Secret", "Eternal", "Divine",
	"Infinity", "Astral", "Omega", "Singularity", "Primordial"
}
crateToggleBtn.MouseButton1Click:Connect(function()
	if not previewCrateMode then
		previewCrateMode = true
	else
		local idx = table.find(CRATE_RARITIES, selectedCrateRarity) or 1
		selectedCrateRarity = CRATE_RARITIES[(idx % #CRATE_RARITIES) + 1]
	end
	crateToggleBtn.Text = if previewCrateMode then ("Crate: " .. selectedCrateRarity) else "Preview Crate"
	rebuildActiveModel()
end)

addSectionHeader("SCALE / KG RATIO", 80)
local scaleGridHost = Instance.new("Frame")
scaleGridHost.Size = UDim2.new(1, -4, 0, 56)
scaleGridHost.BackgroundTransparency = 1
scaleGridHost.LayoutOrder = 85
scaleGridHost.Parent = lpScroll
local sgLayout = Instance.new("UIGridLayout")
sgLayout.CellSize = UDim2.new(0.32, 0, 0, 24)
sgLayout.CellPadding = UDim2.fromOffset(4, 4)
sgLayout.Parent = scaleGridHost

for _, sc in ipairs({ 0.55, 1.00, 1.35, 1.85, 2.60, 3.50 }) do
	local btn = makeButton(scaleGridHost, string.format("%.2fx", sc), UDim2.new(), nil, 11)
	btn.MouseButton1Click:Connect(function()
		selectedScale = sc
		rebuildActiveModel()
	end)
	scaleButtons[sc] = btn
end

addSectionHeader("MUTATIONS (" .. tostring(#GameConfig.MUTATION_ORDER) .. ")", 90)
local mutGridHost = Instance.new("Frame")
mutGridHost.Size = UDim2.new(1, -4, 0, math.ceil(#GameConfig.MUTATION_ORDER / 2) * 28)
mutGridHost.BackgroundTransparency = 1
mutGridHost.LayoutOrder = 95
mutGridHost.Parent = lpScroll
local mgLayout = Instance.new("UIGridLayout")
mgLayout.CellSize = UDim2.new(0.48, 0, 0, 24)
mgLayout.CellPadding = UDim2.fromOffset(4, 4)
mgLayout.Parent = mutGridHost

for _, mutId in ipairs(GameConfig.MUTATION_ORDER) do
	local info = (GameConfig.MUTATIONS :: any)[mutId]
	local btn = makeButton(mutGridHost, if info then info.label else mutId, UDim2.new(), nil, 11)
	btn.MouseButton1Click:Connect(function()
		previewCrateMode = false
		selectedMutation = mutId :: Types.AnimalMutation
		rebuildActiveModel()
	end)
	mutButtons[mutId] = btn
end

addSectionHeader("CINEMATIC VFX TEST", 105)
local VFX_BIOMES = { "AlpinePeaks", "VolcanicJungle", "SavannaCamp", "MangroveSwamp", "PineWoods" }
local VFX_BIOME_LABELS: { [string]: string } = {
	AlpinePeaks = "Biome D: AlpinePeaks",
	VolcanicJungle = "Biome E: VolcanicJungle",
	SavannaCamp = "Biome C: SavannaCamp",
	MangroveSwamp = "Biome B: Mangrove",
	PineWoods = "Biome A: PineWoods",
}
local VFX_RARITIES: { string } = { "Singularity", "Primordial", "Omega", "Astral", "Infinity", "Divine", "Cosmic", "Mythic", "Legendary", "Common" }
local vfxBiomeIdx = 2
local vfxRarityIdx = 2

local vfxBiomeBtn = makeButton(lpScroll, VFX_BIOME_LABELS[VFX_BIOMES[vfxBiomeIdx]], UDim2.new(1, -6, 0, 26), nil, 11)
vfxBiomeBtn.LayoutOrder = 110
vfxBiomeBtn.MouseButton1Click:Connect(function()
	vfxBiomeIdx = (vfxBiomeIdx % #VFX_BIOMES) + 1
	vfxBiomeBtn.Text = VFX_BIOME_LABELS[VFX_BIOMES[vfxBiomeIdx]] or VFX_BIOMES[vfxBiomeIdx]
end)

local vfxRarityBtn = makeButton(lpScroll, "Rarity: " .. VFX_RARITIES[vfxRarityIdx], UDim2.new(1, -6, 0, 26), nil, 11)
vfxRarityBtn.LayoutOrder = 111
vfxRarityBtn.MouseButton1Click:Connect(function()
	vfxRarityIdx = (vfxRarityIdx % #VFX_RARITIES) + 1
	vfxRarityBtn.Text = "Rarity: " .. VFX_RARITIES[vfxRarityIdx]
end)

local function getVfxSpawnCFrame(): CFrame
	if cameraPreset == "Player" then
		local ch = localPlayer.Character
		local hrp = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
		if hrp and hrp:IsA("BasePart") then
			local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
			if look.Magnitude < 0.05 then
				look = Vector3.new(0, 0, -1)
			else
				look = look.Unit
			end
			local targetXZ = Vector3.new(hrp.Position.X, 0, hrp.Position.Z) + look * 11
			local floorY = if targetXZ.Z <= 32.0 then PetLabStageBuilder.SHOWROOM_FLOOR_Y else 0.02
			local spawnPos = Vector3.new(targetXZ.X, floorY, targetXZ.Z)
			return CFrame.lookAt(spawnPos, Vector3.new(hrp.Position.X, floorY, hrp.Position.Z))
		end
	end
	return CFrame.new(TURNTABLE_POS)
end

local vfxHatchRunning = false
local playHatchBtn = makeButton(lpScroll, "Play Hatch VFX", UDim2.new(1, -6, 0, 28), nil, 12)
playHatchBtn.LayoutOrder = 112
styleBtn(playHatchBtn, true, Color3.fromRGB(154, 72, 232))
playHatchBtn.MouseButton1Click:Connect(function()
	if vfxHatchRunning then
		return
	end
	vfxHatchRunning = true
	if cameraPreset ~= "Player" and activeModel then
		activeModel:Destroy()
		activeModel = nil
		clearPivotOverlay()
	end
	local r = VFX_RARITIES[vfxRarityIdx]
	local b = VFX_BIOMES[vfxBiomeIdx]
	CinematicVFX.PlayCrateHatchSequence({
		baseCF = getVfxSpawnCFrame(),
		rarity = r,
		biomeId = b,
		sizeScale = GameConfig.ComputeCrateScale(r, selectedScale),
		speciesId = selectedSpecies,
		mutation = selectedMutation,
		sizeRatio = selectedScale,
		weightKg = 42.5 * selectedScale,
		oddsDenom = GameConfig.ComputePullOddsDenominator(r, selectedMutation),
		openerPlayer = localPlayer,
		isLocalOpener = true,
		lowVFX = false,
		playerGui = playerGui,
		onComplete = function()
			vfxHatchRunning = false
			if not activeModel then
				rebuildActiveModel()
			end
		end,
	})
end)

local playMergeBtn = makeButton(lpScroll, "Play Merge VFX", UDim2.new(1, -6, 0, 26), nil, 11)
playMergeBtn.LayoutOrder = 113
styleBtn(playMergeBtn, true, Color3.fromRGB(48, 168, 188))
playMergeBtn.MouseButton1Click:Connect(function()
	CinematicVFX.PlayMergeBurst(
		getVfxSpawnCFrame().Position + Vector3.new(0, 1.8, 0),
		VFX_RARITIES[vfxRarityIdx],
		selectedMutation,
		1.35,
		false
	)
end)

-- Bottom Draggable Control Window (3 Compact Rows: Poses, Debug/Aura, Camera Presets)
ctrlWin = makeFloatingWindow({
	id = "Controls",
	title = "POSE, AURA & CAMERA",
	width = 608,
	bodyHeight = 98,
	pos = Vector2.new(math.clamp(math.floor((initVp.X - 608) * 0.5), 244, math.max(244, initVp.X - 616)), math.max(138, initVp.Y - 132)),
	accent = Color3.fromRGB(148, 108, 232),
	parent = gui,
	onVisibilityChanged = refreshButtonHighlights,
})

-- Row 1: Animation Modes + Stress Test
local modeRow = Instance.new("Frame")
modeRow.Size = UDim2.new(1, -16, 0, 28)
modeRow.Position = UDim2.fromOffset(8, 4)
modeRow.BackgroundTransparency = 1
modeRow.Parent = ctrlWin.body
local mrLayout = Instance.new("UIListLayout")
mrLayout.FillDirection = Enum.FillDirection.Horizontal
mrLayout.Padding = UDim.new(0, 5)
mrLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mrLayout.VerticalAlignment = Enum.VerticalAlignment.Center
mrLayout.Parent = modeRow

local modeSpecs: { { id: InspectorMode, label: string, w: number, fs: number? } } = {
	{ id = "Idle", label = "Idle", w = 64 },
	{ id = "Walk", label = "Walk", w = 64 },
	{ id = "Fly", label = "Fly", w = 64 },
	{ id = "Ride", label = "Ride", w = 64 },
	{ id = "StressTest", label = "Stress Test", w = 96 },
	{ id = "BaseC0", label = "BaseC0 (Bind)", w = 88, fs = 10 },
	{ id = "Pause", label = "Pause", w = 64 },
}
for _, ms in ipairs(modeSpecs) do
	local btn = makeButton(modeRow, ms.label, UDim2.fromOffset(ms.w, 24), nil, ms.fs or 11)
	btn.TextWrapped = false
	btn.MouseButton1Click:Connect(function()
		selectedMode = ms.id
		if activeModel and not previewCrateMode and activeModel:GetAttribute("VoxelRig") == true then
			if ms.id == "BaseC0" then
				VoxelPets.ResetRig(activeModel)
			elseif ms.id ~= "Pause" then
				VoxelPets.StepRig(activeModel, ms.id :: VoxelPets.AnimMode, animTime, 0)
			end
		end
		refreshButtonHighlights()
	end)
	modeButtons[ms.id] = btn
end

-- Row 2: Turntable Spin, Debug Overlays, Placeholders, Aura VFX
local utilRow = Instance.new("Frame")
utilRow.Size = UDim2.new(1, -16, 0, 28)
utilRow.Position = UDim2.fromOffset(8, 35)
utilRow.BackgroundTransparency = 1
utilRow.Parent = ctrlWin.body
local urLayout = Instance.new("UIListLayout")
urLayout.FillDirection = Enum.FillDirection.Horizontal
urLayout.Padding = UDim.new(0, 6)
urLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
urLayout.VerticalAlignment = Enum.VerticalAlignment.Center
urLayout.Parent = utilRow

spinBtn = makeButton(utilRow, SPIN_LABELS[1], UDim2.fromOffset(84, 24), nil, 10)
spinBtn.TextWrapped = false
spinBtn.MouseButton1Click:Connect(function()
	spinSpeedIndex = (spinSpeedIndex % #SPIN_RATES) + 1
	refreshButtonHighlights()
end)

pivotsBtn = makeButton(utilRow, "Joint Pivots", UDim2.fromOffset(88, 24), nil, 10)
pivotsBtn.TextWrapped = false
pivotsBtn.MouseButton1Click:Connect(function()
	showPivots = not showPivots
	rebuildPivotOverlay()
	refreshButtonHighlights()
end)

dummyBtn = makeButton(utilRow, "Scale Dummy", UDim2.fromOffset(90, 24), nil, 10)
dummyBtn.TextWrapped = false
dummyBtn.MouseButton1Click:Connect(function()
	showScaleDummy = not showScaleDummy
	applyDummyVisibility()
	refreshButtonHighlights()
end)

placeholdersBtn = makeButton(utilRow, "TODO: ON [P]", UDim2.fromOffset(104, 24), nil, 10)
placeholdersBtn.TextWrapped = false
placeholdersBtn.MouseButton1Click:Connect(function()
	showPlaceholders = not showPlaceholders
	applyPlaceholderVisibility()
	refreshButtonHighlights()
end)

auraBtn = makeButton(utilRow, "Aura: ON [G]", UDim2.fromOffset(94, 24), nil, 10)
auraBtn.TextWrapped = false
auraBtn.MouseButton1Click:Connect(function()
	showAuraVFX = not showAuraVFX
	applyAuraVisibility()
	refreshButtonHighlights()
end)

-- Row 3: Camera Presets + Free Walk
camRow = Instance.new("Frame")
camRow.Size = UDim2.new(1, -16, 0, 28)
camRow.Position = UDim2.fromOffset(8, 66)
camRow.BackgroundTransparency = 1
camRow.Parent = ctrlWin.body
local crLayout = Instance.new("UIListLayout")
crLayout.FillDirection = Enum.FillDirection.Horizontal
crLayout.Padding = UDim.new(0, 6)
crLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
crLayout.VerticalAlignment = Enum.VerticalAlignment.Center
crLayout.Parent = camRow

local camSpecs: { { id: CameraPreset, label: string, w: number } } = {
	{ id = "Lineup", label = "Lineup Row", w = 84 },
	{ id = "Orbit34", label = "Orbit 3/4", w = 76 },
	{ id = "Head", label = "Head Close", w = 82 },
	{ id = "Side", label = "Side", w = 56 },
	{ id = "Top", label = "Top", w = 52 },
	{ id = "Player", label = "Free Walk [V]", w = 98 },
}
for _, cs in ipairs(camSpecs) do
	local btn = makeButton(camRow, cs.label, UDim2.fromOffset(cs.w, 24), nil, 10)
	btn.TextWrapped = false
	btn.MouseButton1Click:Connect(function()
		applyCameraPreset(cs.id)
	end)
	camButtons[cs.id] = btn
end

local function relayoutForViewport()
	local curVp = getCanvasSize()
	if curVp.X <= 100 or curVp.Y <= 100 then
		return
	end
	leftWin.setBodyHeight(math.clamp(curVp.Y - 42, 180, 440))
	if not userMovedWindow[launcherBar] then
		local lw = launcherBar.Size.X.Offset
		launcherBar.Position = UDim2.fromOffset(math.max(8, curVp.X - lw - 8), 8)
	end
	if not userMovedWindow[leftWin.root] then
		leftWin.root.Position = UDim2.fromOffset(12, 8)
	end
	if not userMovedWindow[topWin.root] then
		topWin.root.Position = UDim2.fromOffset(
			math.clamp(math.floor((curVp.X - 536) * 0.5), 244, math.max(244, curVp.X - 544)),
			44
		)
	end
	if not userMovedWindow[ctrlWin.root] then
		ctrlWin.root.Position = UDim2.fromOffset(
			math.clamp(math.floor((curVp.X - 608) * 0.5), 244, math.max(244, curVp.X - 616)),
			math.max(138, curVp.Y - 132)
		)
	end
	leftWin.clamp()
	topWin.clamp()
	ctrlWin.clamp()
	local lc = clampWindowPos(launcherBar, launcherBar.Position.X.Offset, launcherBar.Position.Y.Offset)
	launcherBar.Position = UDim2.fromOffset(lc.X, lc.Y)
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayoutForViewport)
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayoutForViewport)
end
task.defer(relayoutForViewport)

-- [E] ProximityPrompt: Primordial Crate showcase or Voxel Pets cycle poses, TODO placeholders open on turntable
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= localPlayer then
		return
	end
	if prompt.Name == "InspectCrateShowcasePrompt" then
		previewCrateMode = true
		local targetModel = prompt:FindFirstAncestorWhichIsA("Model")
		local r = (targetModel and targetModel:GetAttribute("ShowcaseRarity")) or "Primordial"
		local b = (targetModel and targetModel:GetAttribute("ShowcaseBiome")) or "VolcanicJungle"
		selectedCrateRarity = r :: Types.AnimalRarity
		selectedCrateBiome = tostring(b)
		selectedScale = 1.35
		crateToggleBtn.Text = "Crate: " .. r
		rebuildActiveModel()
		applyCameraPreset("Orbit34")
		return
	end
	if prompt.Name ~= "PetPosePrompt" then
		return
	end
	local slot = prompt:FindFirstAncestorWhichIsA("Model")
	if not slot or string.sub(slot.Name, 1, 12) ~= "GallerySlot_" then
		return
	end
	if slot:GetAttribute("IsVoxel") == true then
		local currentPose = (slot:GetAttribute("OverrideAnimMode") :: string?) or "Sync"
		local idx = table.find(POSE_CYCLE, currentPose) or 1
		local nextPose = POSE_CYCLE[(idx % #POSE_CYCLE) + 1]
		slot:SetAttribute("OverrideAnimMode", nextPose)

		local baseObj = prompt:GetAttribute("BaseObjectText")
		if typeof(baseObj) ~= "string" then
			baseObj = prompt.ObjectText
			prompt:SetAttribute("BaseObjectText", baseObj)
		end
		prompt.ObjectText = string.format("%s  [%s]", baseObj, nextPose)
	else
		local spId = slot:GetAttribute("SpeciesId")
		if typeof(spId) == "string" and spId ~= "" then
			previewCrateMode = false
			selectedSpecies = spId
			rebuildActiveModel()
			applyCameraPreset("Orbit34")
		end
	end
end)

-- Studio Mouse Orbit + Scroll Zoom + Window Drag + Showroom Hotkeys (0 Staging, 1-5 Biomes, T Turntable, P TODOs, G Aura, Tab/H UI, V Free Walk, Shift Sprint)
local KEY_TO_BIOME = {
	[Enum.KeyCode.Zero] = 0,
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

UserInputService.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = true
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Tab or (not gp and input.KeyCode == Enum.KeyCode.H) then
		setUiVisible(not uiVisible)
		return
	end
	if gp then
		return
	end
	local biomeIdx = KEY_TO_BIOME[input.KeyCode]
	if biomeIdx then
		jumpToBiome(biomeIdx, true)
	elseif input.KeyCode == Enum.KeyCode.T then
		jumpToTurntable(false)
	elseif input.KeyCode == Enum.KeyCode.P then
		showPlaceholders = not showPlaceholders
		applyPlaceholderVisibility()
		refreshButtonHighlights()
	elseif input.KeyCode == Enum.KeyCode.G then
		showAuraVFX = not showAuraVFX
		applyAuraVisibility()
		refreshButtonHighlights()
	elseif input.KeyCode == Enum.KeyCode.V then
		applyCameraPreset("Player")
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and cameraPreset ~= "Player" then
		isDraggingCam = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		isDraggingCam = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeDrag = nil
	end
end)
UserInputService.InputChanged:Connect(function(input, gp)
	if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local mousePos = Vector2.new(input.Position.X, input.Position.Y)
		local delta = mousePos - activeDrag.startMouse
		if delta.Magnitude >= 2 then
			userMovedWindow[activeDrag.target] = true
		end
		local clamped = clampWindowPos(activeDrag.target, activeDrag.startPos.X + delta.X, activeDrag.startPos.Y + delta.Y)
		activeDrag.target.Position = UDim2.fromOffset(clamped.X, clamped.Y)
		return
	end
	if cameraPreset == "Player" then
		return
	end
	if isDraggingCam and input.UserInputType == Enum.UserInputType.MouseMovement then
		camYaw -= input.Delta.X * 0.008
		camPitch = math.clamp(camPitch + input.Delta.Y * 0.006, math.rad(-25), math.rad(78))
	elseif not gp and input.UserInputType == Enum.UserInputType.MouseWheel then
		camZoom = math.clamp(camZoom - input.Position.Z * 0.12, 0.35, 3.2)
	end
end)

local function onCharacterAdded(char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.WalkSpeed = if isSprinting then SPRINT_SPEED else WALK_SPEED
		if cameraPreset == "Player" then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = hum
		end
	end
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if hrp and hrp:IsA("BasePart") then
		task.defer(function()
			if hrp.Parent then
				if math.abs(hrp.Position.X) < 30 and hrp.Position.Z > 22 then
					hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(TURNTABLE_POS.X, hrp.Position.Y, TURNTABLE_POS.Z))
				else
					local targetZ = if hrp.Position.X > 60 then -12 else PetLabStageBuilder.LINEUP_Z
					hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(hrp.Position.X, hrp.Position.Y, targetZ))
				end
			end
		end)
	end
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end

-- Remove Edit-mode turntable preview before Client mounts live animated activeModel
do
	local stg = Workspace:FindFirstChild("PetLabStage")
	local tt = if stg then stg:FindFirstChild("CenterTurntable") else nil
	if tt then
		for _, prevName in ipairs({ "VFXStudioShowcase_Turntable", "VFXStudioShowcase_FaeLaceDragon" }) do
			local editPreview = tt:FindFirstChild(prevName)
			if editPreview then
				editPreview:Destroy()
			end
		end
	end
end

-- Init Workbench (Default: Free Walk facing VHARAZHUL VFX Studio Aura Showcase on Turntable)
rebuildActiveModel()
applyDummyVisibility()
applyPlaceholderVisibility()
applyAuraVisibility()
applyCameraPreset("Player")

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()

	-- Enforce responsive showroom walk / Shift-sprint speed
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		local desiredSpeed = if isSprinting then SPRINT_SPEED else WALK_SPEED
		if hum.WalkSpeed ~= desiredSpeed then
			hum.WalkSpeed = desiredSpeed
		end
	end

	local spinRate = SPIN_RATES[spinSpeedIndex]
	if spinRate > 0 then
		spinAngle = (spinAngle + spinRate * dt) % (math.pi * 2)
		if activeModel then
			activeModel:PivotTo(CFrame.new(TURNTABLE_POS) * CFrame.Angles(0, spinAngle, 0))
		end
	end

	if selectedMode ~= "Pause" and selectedMode ~= "BaseC0" then
		animTime += dt
	end

	if activeModel and not previewCrateMode then
		if activeModel:GetAttribute("VoxelRig") == true then
			if selectedMode ~= "Pause" and selectedMode ~= "BaseC0" then
				VoxelPets.StepRig(activeModel, selectedMode :: VoxelPets.AnimMode, animTime, 0)
			end
		end

		if #rainbowParts > 0 then
			local col = Color3.fromHSV((now * 0.32) % 1, 0.85, 1)
			for _, rp in ipairs(rainbowParts) do
				if rp.Parent then
					rp.Color = col
				end
			end
		end
		local mutHl = activeModel:FindFirstChild("MutationHighlight")
		if mutHl and mutHl:IsA("Highlight") and mutHl:GetAttribute("RainbowHighlight") == true then
			local col = Color3.fromHSV((now * 0.32) % 1, 0.85, 1)
			mutHl.FillColor = col
			mutHl.OutlineColor = col
		end

		if showPivots then
			for _, entry in ipairs(pivotMarkers) do
				if entry.motor.Parent and entry.motor.Part0 then
					entry.dot.Position = (entry.motor.Part0.CFrame * entry.motor.C0).Position
				end
			end
		end
	end

	-- Sync rigged VoxelPets in LineupGallery (skip static placeholders for 60 FPS performance)
	local stage = Workspace:FindFirstChild("PetLabStage")
	local gallery = if stage then stage:FindFirstChild("LineupGallery") else nil
	if gallery then
		for idx, ch in ipairs(gallery:GetChildren()) do
			if ch:IsA("Model") and ch:GetAttribute("IsVoxel") == true then
				local pet = ch:FindFirstChildWhichIsA("Model")
				if pet and pet:GetAttribute("VoxelRig") == true then
					local overrideMode = ch:GetAttribute("OverrideAnimMode")
					local effectiveMode = if typeof(overrideMode) == "string" and overrideMode ~= "Sync"
						then overrideMode
						else selectedMode
					if effectiveMode == "BaseC0" then
						VoxelPets.ResetRig(pet)
					elseif effectiveMode ~= "Pause" then
						VoxelPets.StepRig(pet, effectiveMode :: VoxelPets.AnimMode, animTime, idx * 0.8)
					end
				end
			end
		end
	end

	-- Studio Camera Framing
	if cameraPreset ~= "Player" then
		camera.CameraType = Enum.CameraType.Scriptable
		local lookTarget: Vector3
		local baseDist: number
		if cameraPreset == "Lineup" then
			if focusedBiomeOrder == 0 then
				lookTarget = Vector3.new(STAGING_CENTER_X, 3.6, -11.5)
				baseDist = 56 * camZoom
			else
				local zone = PetLabStageBuilder.BIOME_ZONES[focusedBiomeOrder] or PetLabStageBuilder.BIOME_ZONES[1]
				local zCenter = if zone then (zone.courtZ - 2) else PetLabStageBuilder.LINEUP_Z
				lookTarget = Vector3.new(0, 3.2, zCenter)
				baseDist = 42 * camZoom
			end
		else
			local spMod = if previewCrateMode then nil else VoxelPets.GetSpeciesModule(selectedSpecies)
			local hOff = if spMod and spMod.CameraHeightOffset then spMod.CameraHeightOffset else 1.5
			local dMult = if spMod and spMod.CameraDistMult then spMod.CameraDistMult else 1.0
			lookTarget = TURNTABLE_POS + Vector3.new(0, hOff * selectedScale, 0)
			if activeModel and cameraPreset == "Head" then
				local hp = activeModel:FindFirstChild("Head")
				if hp and hp:IsA("BasePart") then
					lookTarget = hp.Position
				end
			end
			baseDist = (if cameraPreset == "Head" then 5.4 else 8.8) * math.max(0.75, selectedScale * 0.85) * dMult * camZoom
		end
		local offset = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(-camPitch, 0, 0) * Vector3.new(0, 0, baseDist)
		camera.CFrame = CFrame.lookAt(lookTarget + offset, lookTarget)
	end
end)
