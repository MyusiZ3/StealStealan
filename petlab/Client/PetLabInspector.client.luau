--!strict
-- PetLabInspector.client.luau
-- Interactive Studio Workbench UI + 60 FPS Turntable, Joint Pivot Overlay, Camera Presets,
-- Rainbow Hue Cycling, and Live Geometry Validator for VoxelPets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local VoxelPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VoxelPets"))
local AnimalVisualBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimalVisualBuilder"))
local CinematicVFX = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CinematicVFX"))
local PetLabStageBuilder = require(ReplicatedStorage:WaitForChild("PetLab"):WaitForChild("PetLabStageBuilder"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local camera = Workspace.CurrentCamera

local STAGE_TOP_Y = PetLabStageBuilder.STAGE_TOP_Y

type InspectorMode = VoxelPets.AnimMode | "BaseC0" | "Pause"
type CameraPreset = "Orbit34" | "Head" | "Side" | "Top" | "Player"

local speciesList = VoxelPets.GetSpeciesIds()
local selectedSpecies = speciesList[1] or "FaeLaceDragon"
local selectedScale = 1.35
local selectedMutation: Types.AnimalMutation = "None"
local selectedMode: InspectorMode = "Idle"
local previewCrateMode = false
local selectedCrateRarity: Types.AnimalRarity = "Astral"

local spinSpeedIndex = 1
local SPIN_LABELS = { "Spin: OFF", "Spin: Slow", "Spin: Fast" }
local SPIN_RATES = { 0, 0.45, 1.35 }

local showPivots = false
local showScaleDummy = true
local cameraPreset: CameraPreset = "Orbit34"
local camYaw = math.rad(38)
local camPitch = math.rad(16)
local camZoom = 1.0
local isDraggingCam = false
local spinAngle = 0
local animTime = 0

local activeModel: Model? = nil
local rainbowParts: { BasePart } = {}
local pivotMarkers: { { motor: Motor6D, dot: Part } } = {}
local pivotFolder: Folder? = nil

-- UI References
local diagBanner: TextLabel
local diagFrame: Frame
local speciesButtons: { [string]: TextButton } = {}
local scaleButtons: { [number]: TextButton } = {}
local mutButtons: { [string]: TextButton } = {}
local modeButtons: { [string]: TextButton } = {}
local camButtons: { [string]: TextButton } = {}
local crateToggleBtn: TextButton
local spinBtn: TextButton
local pivotsBtn: TextButton
local dummyBtn: TextButton

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

local function updateDiagnosticBanner()
	if not activeModel then
		diagBanner.Text = "No active model"
		diagFrame.BackgroundColor3 = Color3.fromRGB(48, 52, 66)
		return
	end
	if previewCrateMode then
		diagBanner.Text = string.format("CRATE PREVIEW  |  %s  |  Scale %.2fx", selectedCrateRarity, selectedScale)
		diagFrame.BackgroundColor3 = Color3.fromRGB(38, 62, 102)
		return
	end
	local res = VoxelPets.InspectModel(activeModel)
	if res.ok then
		diagBanner.Text = string.format(
			"OK  |  %d Parts  |  %d Motors  |  Ground %.2f st  |  0 Warnings",
			res.partCount,
			res.motorCount,
			res.groundOffset
		)
		diagFrame.BackgroundColor3 = Color3.fromRGB(26, 98, 58)
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
		m = AnimalVisualBuilder.BuildCrateModel(selectedCrateRarity, "VolcanicJungle", selectedScale, {
			isBuried = false,
			canCollide = false,
			showBeacon = false,
		})
	else
		m = VoxelPets.Build(selectedSpecies, selectedScale, selectedMutation, false)
	end

	m:PivotTo(CFrame.new(0, STAGE_TOP_Y, 0) * CFrame.Angles(0, spinAngle, 0))
	m.Parent = Workspace
	activeModel = m

	for _, desc in ipairs(m:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("RainbowTarget") == true then
			table.insert(rainbowParts, desc)
		end
	end

	if not previewCrateMode then
		if selectedMode == "BaseC0" then
			VoxelPets.ResetRig(m)
		elseif selectedMode ~= "Pause" then
			VoxelPets.StepRig(m, selectedMode :: VoxelPets.AnimMode, animTime, 0)
		end
	end

	rebuildPivotOverlay()
	updateDiagnosticBanner()
	refreshButtonHighlights()
end

local function applyCameraPreset(preset: CameraPreset)
	cameraPreset = preset
	if preset == "Orbit34" then
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

-- Build Clean Studio Inspector ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "PetLabInspectorGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Top Diagnostic Pill
diagFrame = Instance.new("Frame")
diagFrame.Size = UDim2.fromOffset(560, 34)
diagFrame.Position = UDim2.new(0.5, -280, 0, 12)
diagFrame.BackgroundColor3 = Color3.fromRGB(26, 98, 58)
diagFrame.BorderSizePixel = 0
diagFrame.Parent = gui
local diagCorner = Instance.new("UICorner")
diagCorner.CornerRadius = UDim.new(0, 10)
diagCorner.Parent = diagFrame
local diagStroke = Instance.new("UIStroke")
diagStroke.Color = Color3.fromRGB(22, 26, 36)
diagStroke.Thickness = 2
diagStroke.Parent = diagFrame
diagBanner = Instance.new("TextLabel")
diagBanner.Size = UDim2.new(1, -16, 1, 0)
diagBanner.Position = UDim2.fromOffset(8, 0)
diagBanner.BackgroundTransparency = 1
diagBanner.Font = Enum.Font.GothamBold
diagBanner.TextSize = 13
diagBanner.TextColor3 = Color3.new(1, 1, 1)
diagBanner.TextTruncate = Enum.TextTruncate.AtEnd
diagBanner.Text = "Pet Lab Initializing..."
diagBanner.Parent = diagFrame

-- Left Inspector Panel (Species, Scale, Mutations)
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.fromOffset(228, 510)
leftPanel.Position = UDim2.new(0, 14, 0.5, -255)
leftPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
leftPanel.BackgroundTransparency = 0.14
leftPanel.BorderSizePixel = 0
leftPanel.Parent = gui
local lpCorner = Instance.new("UICorner")
lpCorner.CornerRadius = UDim.new(0, 12)
lpCorner.Parent = leftPanel
local lpStroke = Instance.new("UIStroke")
lpStroke.Color = Color3.fromRGB(64, 74, 96)
lpStroke.Thickness = 1.5
lpStroke.Parent = leftPanel

local lpScroll = Instance.new("ScrollingFrame")
lpScroll.Size = UDim2.new(1, -12, 1, -12)
lpScroll.Position = UDim2.fromOffset(6, 6)
lpScroll.BackgroundTransparency = 1
lpScroll.BorderSizePixel = 0
lpScroll.ScrollBarThickness = 4
lpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
lpScroll.CanvasSize = UDim2.new()
lpScroll.Parent = leftPanel

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

addSectionHeader("VOXEL PET SPECIES", 10)
for idx, id in ipairs(speciesList) do
	local mod = VoxelPets.GetSpeciesModule(id)
	local label = if mod then mod.DisplayName else id
	local btn = makeButton(lpScroll, label, UDim2.new(1, -6, 0, 30), nil, 12)
	btn.LayoutOrder = 10 + idx
	btn.MouseButton1Click:Connect(function()
		previewCrateMode = false
		selectedSpecies = id
		rebuildActiveModel()
	end)
	speciesButtons[id] = btn
end

crateToggleBtn = makeButton(lpScroll, "Preview Crate (Click to Cycle)", UDim2.new(1, -6, 0, 28), nil, 11)
crateToggleBtn.LayoutOrder = 40
local CRATE_RARITIES: { Types.AnimalRarity } = { "Common", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Astral", "Infinity", "Primordial" }
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

addSectionHeader("SCALE / KG RATIO", 50)
local scaleGridHost = Instance.new("Frame")
scaleGridHost.Size = UDim2.new(1, -4, 0, 56)
scaleGridHost.BackgroundTransparency = 1
scaleGridHost.LayoutOrder = 55
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

addSectionHeader("MUTATIONS (" .. tostring(#GameConfig.MUTATION_ORDER) .. ")", 70)
local mutGridHost = Instance.new("Frame")
mutGridHost.Size = UDim2.new(1, -4, 0, math.ceil(#GameConfig.MUTATION_ORDER / 2) * 28)
mutGridHost.BackgroundTransparency = 1
mutGridHost.LayoutOrder = 75
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

addSectionHeader("CINEMATIC VFX TEST", 85)
local VFX_BIOMES = { "AlpinePeaks", "VolcanicJungle", "SavannaCamp", "MangroveSwamp", "PineWoods" }
local VFX_BIOME_LABELS: { [string]: string } = {
	AlpinePeaks = "Biome D: AlpinePeaks",
	VolcanicJungle = "Biome E: VolcanicJungle",
	SavannaCamp = "Biome C: SavannaCamp",
	MangroveSwamp = "Biome B: Mangrove",
	PineWoods = "Biome A: PineWoods",
}
local VFX_RARITIES: { string } = { "Singularity", "Primordial", "Omega", "Astral", "Infinity", "Divine", "Cosmic", "Mythic", "Legendary", "Common" }
local vfxBiomeIdx = 1
local vfxRarityIdx = 1

local vfxBiomeBtn = makeButton(lpScroll, VFX_BIOME_LABELS[VFX_BIOMES[vfxBiomeIdx]], UDim2.new(1, -6, 0, 26), nil, 11)
vfxBiomeBtn.LayoutOrder = 90
vfxBiomeBtn.MouseButton1Click:Connect(function()
	vfxBiomeIdx = (vfxBiomeIdx % #VFX_BIOMES) + 1
	vfxBiomeBtn.Text = VFX_BIOME_LABELS[VFX_BIOMES[vfxBiomeIdx]] or VFX_BIOMES[vfxBiomeIdx]
end)

local vfxRarityBtn = makeButton(lpScroll, "Rarity: " .. VFX_RARITIES[vfxRarityIdx], UDim2.new(1, -6, 0, 26), nil, 11)
vfxRarityBtn.LayoutOrder = 91
vfxRarityBtn.MouseButton1Click:Connect(function()
	vfxRarityIdx = (vfxRarityIdx % #VFX_RARITIES) + 1
	vfxRarityBtn.Text = "Rarity: " .. VFX_RARITIES[vfxRarityIdx]
end)

local vfxHatchRunning = false
local playHatchBtn = makeButton(lpScroll, "Play Hatch VFX", UDim2.new(1, -6, 0, 28), nil, 12)
playHatchBtn.LayoutOrder = 92
styleBtn(playHatchBtn, true, Color3.fromRGB(154, 72, 232))
playHatchBtn.MouseButton1Click:Connect(function()
	if vfxHatchRunning then
		return
	end
	vfxHatchRunning = true
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end
	clearPivotOverlay()
	local r = VFX_RARITIES[vfxRarityIdx]
	local b = VFX_BIOMES[vfxBiomeIdx]
	CinematicVFX.PlayCrateHatchSequence({
		baseCF = CFrame.new(0, STAGE_TOP_Y, 0),
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
			rebuildActiveModel()
		end,
	})
end)

local playMergeBtn = makeButton(lpScroll, "Play Merge VFX", UDim2.new(1, -6, 0, 26), nil, 11)
playMergeBtn.LayoutOrder = 93
styleBtn(playMergeBtn, true, Color3.fromRGB(48, 168, 188))
playMergeBtn.MouseButton1Click:Connect(function()
	CinematicVFX.PlayMergeBurst(
		Vector3.new(0, STAGE_TOP_Y + 1.8, 0),
		VFX_RARITIES[vfxRarityIdx],
		selectedMutation,
		1.35,
		false
	)
end)

-- Bottom Control Bar (Animation Modes, Stress Test, Spin, Pivots, Camera Presets)
local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.fromOffset(820, 86)
bottomBar.Position = UDim2.new(0.5, -410, 1, -98)
bottomBar.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
bottomBar.BackgroundTransparency = 0.14
bottomBar.BorderSizePixel = 0
bottomBar.Parent = gui
local bbCorner = Instance.new("UICorner")
bbCorner.CornerRadius = UDim.new(0, 12)
bbCorner.Parent = bottomBar
local bbStroke = Instance.new("UIStroke")
bbStroke.Color = Color3.fromRGB(64, 74, 96)
bbStroke.Thickness = 1.5
bbStroke.Parent = bottomBar

-- Row 1: Animation Modes + Stress Test
local modeRow = Instance.new("Frame")
modeRow.Size = UDim2.new(1, -16, 0, 34)
modeRow.Position = UDim2.fromOffset(8, 8)
modeRow.BackgroundTransparency = 1
modeRow.Parent = bottomBar
local mrLayout = Instance.new("UIListLayout")
mrLayout.FillDirection = Enum.FillDirection.Horizontal
mrLayout.Padding = UDim.new(0, 6)
mrLayout.VerticalAlignment = Enum.VerticalAlignment.Center
mrLayout.Parent = modeRow

local modeSpecs: { { id: InspectorMode, label: string, w: number } } = {
	{ id = "Idle", label = "Idle", w = 74 },
	{ id = "Walk", label = "Walk", w = 74 },
	{ id = "Fly", label = "Fly", w = 74 },
	{ id = "Ride", label = "Ride", w = 74 },
	{ id = "StressTest", label = "Stress Test", w = 112 },
	{ id = "BaseC0", label = "BaseC0 (Bind)", w = 104 },
	{ id = "Pause", label = "Pause", w = 74 },
}
for _, ms in ipairs(modeSpecs) do
	local btn = makeButton(modeRow, ms.label, UDim2.fromOffset(ms.w, 28), nil, 12)
	btn.MouseButton1Click:Connect(function()
		selectedMode = ms.id
		if activeModel and not previewCrateMode then
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

-- Row 2: Turntable, Debug Toggles, Camera Presets
local utilRow = Instance.new("Frame")
utilRow.Size = UDim2.new(1, -16, 0, 34)
utilRow.Position = UDim2.fromOffset(8, 46)
utilRow.BackgroundTransparency = 1
utilRow.Parent = bottomBar
local urLayout = Instance.new("UIListLayout")
urLayout.FillDirection = Enum.FillDirection.Horizontal
urLayout.Padding = UDim.new(0, 6)
urLayout.VerticalAlignment = Enum.VerticalAlignment.Center
urLayout.Parent = utilRow

spinBtn = makeButton(utilRow, SPIN_LABELS[1], UDim2.fromOffset(92, 26), nil, 11)
spinBtn.MouseButton1Click:Connect(function()
	spinSpeedIndex = (spinSpeedIndex % #SPIN_RATES) + 1
	refreshButtonHighlights()
end)

pivotsBtn = makeButton(utilRow, "Joint Pivots", UDim2.fromOffset(96, 26), nil, 11)
pivotsBtn.MouseButton1Click:Connect(function()
	showPivots = not showPivots
	rebuildPivotOverlay()
	refreshButtonHighlights()
end)

dummyBtn = makeButton(utilRow, "Scale Dummy", UDim2.fromOffset(96, 26), nil, 11)
dummyBtn.MouseButton1Click:Connect(function()
	showScaleDummy = not showScaleDummy
	applyDummyVisibility()
	refreshButtonHighlights()
end)

local camSpecs: { { id: CameraPreset, label: string, w: number } } = {
	{ id = "Orbit34", label = "Orbit 3/4", w = 86 },
	{ id = "Head", label = "Head Close", w = 92 },
	{ id = "Side", label = "Side", w = 68 },
	{ id = "Top", label = "Top", w = 64 },
	{ id = "Player", label = "Player Walk", w = 94 },
}
for _, cs in ipairs(camSpecs) do
	local btn = makeButton(utilRow, cs.label, UDim2.fromOffset(cs.w, 26), nil, 11)
	btn.MouseButton1Click:Connect(function()
		applyCameraPreset(cs.id)
	end)
	camButtons[cs.id] = btn
end

-- Studio Mouse Orbit + Scroll Zoom when in Scriptable camera presets
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and cameraPreset ~= "Player" then
		isDraggingCam = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isDraggingCam = false
	end
end)
UserInputService.InputChanged:Connect(function(input, gp)
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

-- Init Workbench
rebuildActiveModel()
applyDummyVisibility()
applyCameraPreset("Orbit34")

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	local spinRate = SPIN_RATES[spinSpeedIndex]
	if spinRate > 0 then
		spinAngle = (spinAngle + spinRate * dt) % (math.pi * 2)
		if activeModel then
			activeModel:PivotTo(CFrame.new(0, STAGE_TOP_Y, 0) * CFrame.Angles(0, spinAngle, 0))
		end
	end

	if activeModel and not previewCrateMode then
		if selectedMode ~= "Pause" and selectedMode ~= "BaseC0" then
			animTime += dt
			VoxelPets.StepRig(activeModel, selectedMode :: VoxelPets.AnimMode, animTime, 0)
		end

		if #rainbowParts > 0 then
			local col = Color3.fromHSV((now * 0.32) % 1, 0.85, 1)
			for _, rp in ipairs(rainbowParts) do
				if rp.Parent then
					rp.Color = col
				end
			end
		end

		if showPivots then
			for _, entry in ipairs(pivotMarkers) do
				if entry.motor.Parent and entry.motor.Part0 then
					entry.dot.Position = (entry.motor.Part0.CFrame * entry.motor.C0).Position
				end
			end
		end
	end

	-- Keep background gallery lineup animated gently in Idle
	local stage = Workspace:FindFirstChild("PetLabStage")
	local gallery = if stage then stage:FindFirstChild("LineupGallery") else nil
	if gallery then
		for idx, ch in ipairs(gallery:GetChildren()) do
			local pet = ch:FindFirstChildWhichIsA("Model")
			if pet and pet:GetAttribute("VoxelRig") == true then
				VoxelPets.StepRig(pet, "Idle", now, idx * 1.4)
			end
		end
	end

	-- Studio Camera Framing
	if cameraPreset ~= "Player" then
		camera.CameraType = Enum.CameraType.Scriptable
		local lookTarget = Vector3.new(0, STAGE_TOP_Y + 1.5 * selectedScale, 0)
		if activeModel and cameraPreset == "Head" then
			local hp = activeModel:FindFirstChild("Head")
			if hp and hp:IsA("BasePart") then
				lookTarget = hp.Position
			end
		end
		local baseDist = (if cameraPreset == "Head" then 5.4 else 8.8) * math.max(0.75, selectedScale * 0.85) * camZoom
		local offset = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(-camPitch, 0, 0) * Vector3.new(0, 0, baseDist)
		camera.CFrame = CFrame.lookAt(lookTarget + offset, lookTarget)
	end
end)
