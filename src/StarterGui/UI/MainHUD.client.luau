--!strict
-- MainHUD.client.luau
-- Complete Simulator HUD & Modal Suite styled to match reference screenshots:
-- Left Stack (Shop, Index, Slow Mode), Floating Bottom-Left Speed/Cash, Right Collapsible Active/Crates Drawer + Equip Best,
-- Bottom 3-Slot Hotbar, Top-Right Biome Recommended Banner, Bottom-Right Event Countdown,
-- Shop Modal (Featured + Passes + 10 Lassos + 10 Trails + 6 Vehicles + Fuse + Rebirth),
-- Index Modal (5 Zones, 63 Animals, Right External Tabs, Right Inspect Panel, Total Unlocked Bar),
-- All Pets Inventory Modal (Sell Toggle, Search, 6-Col Grid, Left External Tabs), & Settings Modal (Sliders + Switches).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local LassoConfig = require(ReplicatedStorage.Config.LassoConfig)
local TrailConfig = require(ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(ReplicatedStorage.Config.VehicleConfig)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local profile: Types.PlayerProfileSchema? = nil
local currentModal: string? = nil -- "Shop" | "Index" | "Settings" | "Inventory"
local shopSubTab = "Featured" -- "Featured" | "Passes" | "Lassos" | "Trails" | "Vehicles" | "Fuse" | "Rebirth"
local indexRightTab = "Normal" -- "Normal" | "Limited" | "Mutations"
local selectedIndexSpeciesId = AnimalConfig.ALL[1].id
local invLeftTab = "Pets" -- "Pets" | "Crates" | "Mounts" | "Fuse"
local sellModeActive = false
local invSearchQuery = ""
local selectedFuseUids: { string } = {}
local drawerMode = "Active" -- "Active" | "Crates"
local drawerCollapsed = false
local lastSpeedStat = 0
local lastStepGain = 0
local nextMythicWaveAt = os.time() + 600
local viewCratesEnabled = true

local gui = Instance.new("ScreenGui")
gui.Name = "MainGameHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- ============================================================================
-- VISUAL HELPERS
-- ============================================================================
local function makeCorner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function makeStroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2.5
	s.Color = color or Color3.fromRGB(14, 15, 18)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function makeTextStroke(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2.4
	s.Color = color or Color3.fromRGB(12, 12, 16)
	s.Parent = parent
	return s
end

local function makeGradient(parent: Instance, topCol: Color3, botCol: Color3, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topCol, botCol)
	g.Rotation = rot or 90
	g.Parent = parent
	return g
end

local function makeOutlinedLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3?, strokeThick: number?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = parent
	makeTextStroke(lbl, strokeThick or 2.4)
	return lbl
end

local function makeWindowHeader(parent: Frame, titleText: string, topCol: Color3, botCol: Color3, onClose: () -> ()): Frame
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.ClipsDescendants = true
	header.Parent = parent
	makeCorner(header, 10)
	makeStroke(header, 3)
	makeGradient(header, topCol, botCol, 90)

	-- Diagonal subtle glossy stripes matching reference Shop / Index / Settings headers
	for i = 1, 4 do
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 34, 2, 0)
		stripe.Position = UDim2.new(0.28 + i * 0.16, 0, -0.5, 0)
		stripe.Rotation = 22
		stripe.BackgroundColor3 = Color3.new(1, 1, 1)
		stripe.BackgroundTransparency = 0.80
		stripe.BorderSizePixel = 0
		stripe.Parent = header
	end

	local title = makeOutlinedLabel(header, titleText, UDim2.new(1, -68, 0.82, 0), UDim2.new(0, 14, 0.09, 0), Color3.new(1, 1, 1), 3)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(38, 38)
	closeBtn.Position = UDim2.new(1, -44, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(224, 34, 34)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextScaled = true
	closeBtn.ZIndex = 3
	closeBtn.Parent = header
	makeCorner(closeBtn, 8)
	makeStroke(closeBtn, 2.5)
	makeTextStroke(closeBtn, 2.2)
	makeGradient(closeBtn, Color3.fromRGB(255, 78, 78), Color3.fromRGB(186, 18, 24))
	closeBtn.MouseButton1Click:Connect(onClose)

	return header
end

local function makeAnimalIconFrame(parent: Instance, speciesId: string, mutation: Types.AnimalMutation?, locked: boolean?): Frame
	local spec = AnimalConfig.GetById(speciesId) or AnimalConfig.ALL[1]
	local rarityCol = GameConfig.RARITY_COLORS[spec.rarity] or Color3.fromRGB(150, 160, 175)
	local mutInfo = if mutation then GameConfig.MUTATIONS[mutation] else GameConfig.MUTATIONS.None

	local cardBg = if locked
		then Color3.fromRGB(36, 40, 48)
		elseif mutation and mutation ~= "None" then mutInfo.color
		else rarityCol

	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = cardBg
	box.Parent = parent
	makeCorner(box, 8)
	makeStroke(box, 2)
	if not locked then
		makeGradient(box, cardBg:Lerp(Color3.new(1, 1, 1), 0.25), cardBg:Lerp(Color3.new(0, 0, 0), 0.25))
	end

	local bodyCol = if locked then Color3.fromRGB(18, 20, 24) else spec.bodyColor
	local secCol = if locked then Color3.fromRGB(14, 16, 20) else spec.secondaryColor
	if not locked and mutation == "Golden" then
		bodyCol = Color3.fromRGB(255, 206, 54)
		secCol = Color3.fromRGB(224, 152, 24)
	elseif not locked and mutation == "Albino" then
		bodyCol = Color3.fromRGB(246, 248, 255)
		secCol = Color3.fromRGB(218, 224, 236)
	elseif not locked and mutation == "Diamond" then
		bodyCol = Color3.fromRGB(112, 232, 255)
		secCol = Color3.fromRGB(205, 248, 255)
	elseif not locked and mutation == "Celestial" then
		bodyCol = Color3.fromRGB(78, 34, 148)
		secCol = Color3.fromRGB(255, 214, 92)
	end

	-- Blocky Ears / Horns
	for _, ex in { 0.23, 0.61 } do
		local ear = Instance.new("Frame")
		ear.Size = UDim2.fromScale(0.16, 0.20)
		ear.Position = UDim2.fromScale(ex, 0.11)
		ear.BackgroundColor3 = secCol
		ear.BorderSizePixel = 0
		ear.Parent = box
		makeCorner(ear, 3)
	end

	-- Blocky Head
	local head = Instance.new("Frame")
	head.Size = UDim2.fromScale(0.58, 0.50)
	head.Position = UDim2.fromScale(0.21, 0.24)
	head.BackgroundColor3 = bodyCol
	head.BorderSizePixel = 0
	head.Parent = box
	makeCorner(head, 6)
	makeStroke(head, 1.5)

	if not locked then
		-- Eyes
		for _, lx in { 0.22, 0.64 } do
			local eye = Instance.new("Frame")
			eye.Size = UDim2.fromScale(0.14, 0.22)
			eye.Position = UDim2.fromScale(lx, 0.30)
			eye.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
			eye.BorderSizePixel = 0
			eye.Parent = head
			makeCorner(eye, 2)
		end
		-- Snout
		local snout = Instance.new("Frame")
		snout.Size = UDim2.fromScale(0.42, 0.26)
		snout.Position = UDim2.fromScale(0.29, 0.62)
		snout.BackgroundColor3 = secCol
		snout.BorderSizePixel = 0
		snout.Parent = head
		makeCorner(snout, 3)
	end

	return box
end

-- ============================================================================
-- 1. TOP-LEFT SETTINGS GEAR + RIDE BUTTON + TOASTS & BIOME BANNER
-- ============================================================================
local topLeftRow = Instance.new("Frame")
topLeftRow.Size = UDim2.fromOffset(175, 44)
topLeftRow.Position = UDim2.new(0, 14, 0, 12)
topLeftRow.BackgroundTransparency = 1
topLeftRow.Parent = gui

local settingsGearBtn = Instance.new("TextButton")
settingsGearBtn.Name = "SettingsGearButton"
settingsGearBtn.Size = UDim2.fromOffset(42, 42)
settingsGearBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 44)
settingsGearBtn.Text = "⚙️"
settingsGearBtn.TextColor3 = Color3.new(1, 1, 1)
settingsGearBtn.TextScaled = true
settingsGearBtn.Parent = topLeftRow
makeCorner(settingsGearBtn, 21)
makeStroke(settingsGearBtn, 2.5)

local rideTopBtn = Instance.new("TextButton")
rideTopBtn.Name = "RideTopButton"
rideTopBtn.Size = UDim2.fromOffset(112, 38)
rideTopBtn.Position = UDim2.fromOffset(50, 2)
rideTopBtn.BackgroundColor3 = Color3.fromRGB(52, 184, 108)
rideTopBtn.Text = "🚙 Ride (V)"
rideTopBtn.TextColor3 = Color3.new(1, 1, 1)
rideTopBtn.Font = Enum.Font.FredokaOne
rideTopBtn.TextScaled = true
rideTopBtn.Parent = topLeftRow
makeCorner(rideTopBtn, 10)
makeStroke(rideTopBtn, 2.5)
makeTextStroke(rideTopBtn, 2)
makeGradient(rideTopBtn, Color3.fromRGB(82, 224, 134), Color3.fromRGB(32, 146, 76))
rideTopBtn.MouseButton1Click:Connect(function()
	localPlayer:SetAttribute("ToggleVehicleRequest", not (localPlayer:GetAttribute("ToggleVehicleRequest") == true))
end)

-- Top-Right Biome Entry Banner (Screenshot 7)
local biomeBanner = Instance.new("Frame")
biomeBanner.Name = "BiomeBanner"
biomeBanner.Size = UDim2.fromOffset(310, 68)
biomeBanner.Position = UDim2.new(1, -326, 0, 14)
biomeBanner.BackgroundTransparency = 1
biomeBanner.Visible = false
biomeBanner.Parent = gui

local biomeTitleLbl = makeOutlinedLabel(biomeBanner, "Pine Woods", UDim2.new(1, 0, 0.56, 0), UDim2.fromScale(0, 0), Color3.fromRGB(255, 218, 102), 2.8)
biomeTitleLbl.TextXAlignment = Enum.TextXAlignment.Right
local biomeRecLbl = makeOutlinedLabel(biomeBanner, "Recommended: 👟 18 Speed", UDim2.new(1, 0, 0.42, 0), UDim2.new(0, 0, 0.56, 0), Color3.fromRGB(118, 224, 255), 2.4)
biomeRecLbl.TextXAlignment = Enum.TextXAlignment.Right

-- Center Top Global Event Banner & Notification Toast
local eventBanner = Instance.new("TextLabel")
eventBanner.Name = "GlobalEventBanner"
eventBanner.Size = UDim2.fromOffset(620, 40)
eventBanner.Position = UDim2.new(0.5, -310, 0, 12)
eventBanner.BackgroundColor3 = Color3.fromRGB(34, 24, 52)
eventBanner.TextColor3 = Color3.fromRGB(255, 214, 64)
eventBanner.Font = Enum.Font.FredokaOne
eventBanner.TextScaled = true
eventBanner.Visible = false
eventBanner.Parent = gui
makeCorner(eventBanner, 10)
makeStroke(eventBanner, 2.5, Color3.fromRGB(255, 214, 64))
makeTextStroke(eventBanner, 2.2)

local toastLbl = Instance.new("TextLabel")
toastLbl.Name = "ToastLabel"
toastLbl.Size = UDim2.fromOffset(480, 32)
toastLbl.Position = UDim2.new(0.5, -240, 0, 58)
toastLbl.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
toastLbl.BackgroundTransparency = 0.2
toastLbl.TextColor3 = Color3.new(1, 1, 1)
toastLbl.Font = Enum.Font.FredokaOne
toastLbl.TextScaled = true
toastLbl.Visible = false
toastLbl.Parent = gui
makeCorner(toastLbl, 8)
makeTextStroke(toastLbl, 2)

-- ============================================================================
-- 2. LEFT STACK: STEP POP + SHOP + INDEX + SLOW MODE (Screenshot 1)
-- ============================================================================
local leftStack = Instance.new("Frame")
leftStack.Name = "LeftActionStack"
leftStack.Size = UDim2.fromOffset(180, 185)
leftStack.Position = UDim2.new(0, 14, 0.37, 0)
leftStack.BackgroundTransparency = 1
leftStack.Parent = gui

local stepPopLbl = makeOutlinedLabel(leftStack, "👟 +2/Step", UDim2.fromOffset(170, 26), UDim2.fromOffset(4, 0), Color3.fromRGB(88, 224, 255), 2.4)
stepPopLbl.TextXAlignment = Enum.TextXAlignment.Left

local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopButton"
shopBtn.Size = UDim2.fromOffset(132, 46)
shopBtn.Position = UDim2.fromOffset(0, 30)
shopBtn.BackgroundColor3 = Color3.new(1, 1, 1)
shopBtn.Text = "🛒 Shop"
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.Font = Enum.Font.FredokaOne
shopBtn.TextScaled = true
shopBtn.Parent = leftStack
makeCorner(shopBtn, 8)
makeStroke(shopBtn, 2.8)
makeTextStroke(shopBtn, 2.5)
makeGradient(shopBtn, Color3.fromRGB(128, 255, 48), Color3.fromRGB(52, 198, 20))

local shopBadge = Instance.new("TextLabel")
shopBadge.Size = UDim2.fromOffset(22, 22)
shopBadge.Position = UDim2.new(1, -12, 0, -8)
shopBadge.BackgroundColor3 = Color3.fromRGB(224, 38, 38)
shopBadge.Text = "!"
shopBadge.TextColor3 = Color3.new(1, 1, 1)
shopBadge.Font = Enum.Font.FredokaOne
shopBadge.TextScaled = true
shopBadge.Parent = shopBtn
makeCorner(shopBadge, 11)
makeStroke(shopBadge, 2)

local indexBtn = Instance.new("TextButton")
indexBtn.Name = "IndexButton"
indexBtn.Size = UDim2.fromOffset(132, 46)
indexBtn.Position = UDim2.fromOffset(0, 84)
indexBtn.BackgroundColor3 = Color3.new(1, 1, 1)
indexBtn.Text = "📖 Index"
indexBtn.TextColor3 = Color3.new(1, 1, 1)
indexBtn.Font = Enum.Font.FredokaOne
indexBtn.TextScaled = true
indexBtn.Parent = leftStack
makeCorner(indexBtn, 8)
makeStroke(indexBtn, 2.8)
makeTextStroke(indexBtn, 2.5)
makeGradient(indexBtn, Color3.fromRGB(64, 224, 255), Color3.fromRGB(18, 142, 232))

-- Slow Mode Switch Row
local slowSwitchTrack = Instance.new("TextButton")
slowSwitchTrack.Name = "SlowModeSwitch"
slowSwitchTrack.Size = UDim2.fromOffset(74, 32)
slowSwitchTrack.Position = UDim2.fromOffset(0, 140)
slowSwitchTrack.BackgroundColor3 = Color3.fromRGB(56, 72, 22)
slowSwitchTrack.Text = ""
slowSwitchTrack.Parent = leftStack
makeCorner(slowSwitchTrack, 6)
makeStroke(slowSwitchTrack, 2.5)

local slowKnob = Instance.new("Frame")
slowKnob.Size = UDim2.fromOffset(26, 24)
slowKnob.Position = UDim2.fromOffset(4, 4)
slowKnob.BackgroundColor3 = Color3.fromRGB(218, 46, 46)
slowKnob.Parent = slowSwitchTrack
makeCorner(slowKnob, 4)
makeStroke(slowKnob, 2)

local slowText = makeOutlinedLabel(leftStack, "Slow Mode", UDim2.fromOffset(92, 28), UDim2.fromOffset(82, 142), Color3.new(1, 1, 1), 2.3)
slowText.TextXAlignment = Enum.TextXAlignment.Left

local function updateSlowModeVisual(on: boolean)
	slowKnob.Position = if on then UDim2.fromOffset(44, 4) else UDim2.fromOffset(4, 4)
	slowKnob.BackgroundColor3 = if on then Color3.fromRGB(72, 224, 72) else Color3.fromRGB(218, 46, 46)
end

slowSwitchTrack.MouseButton1Click:Connect(function()
	localPlayer:SetAttribute("ToggleSlowModeRequest", not (localPlayer:GetAttribute("ToggleSlowModeRequest") == true))
end)
localPlayer.AttributeChanged:Connect(function(attr)
	if attr == "SlowMode" then
		updateSlowModeVisual(localPlayer:GetAttribute("SlowMode") == true)
	end
end)

-- ============================================================================
-- 3. BOTTOM-LEFT FLOATING SPEED & CASH DISPLAY (No Box, Thick Outline)
-- ============================================================================
local statsCorner = Instance.new("Frame")
statsCorner.Name = "BottomLeftStats"
statsCorner.Size = UDim2.fromOffset(360, 88)
statsCorner.Position = UDim2.new(0, 14, 1, -98)
statsCorner.BackgroundTransparency = 1
statsCorner.Parent = gui

local speedIconBtn = Instance.new("TextButton")
speedIconBtn.Size = UDim2.fromOffset(38, 38)
speedIconBtn.Position = UDim2.fromOffset(0, 4)
speedIconBtn.BackgroundTransparency = 1
speedIconBtn.Text = "👟"
speedIconBtn.TextScaled = true
speedIconBtn.Parent = statsCorner
local speedPlus = makeOutlinedLabel(speedIconBtn, "+", UDim2.fromOffset(18, 18), UDim2.fromOffset(22, 20), Color3.fromRGB(255, 214, 62), 2)
speedPlus.ZIndex = 2

local speedValLbl = makeOutlinedLabel(statsCorner, "0", UDim2.fromOffset(150, 38), UDim2.fromOffset(44, 2), Color3.fromRGB(118, 96, 255), 3)
speedValLbl.TextXAlignment = Enum.TextXAlignment.Left
local speedMultLbl = makeOutlinedLabel(statsCorner, "(x1.25)", UDim2.fromOffset(145, 36), UDim2.fromOffset(192, 4), Color3.fromRGB(76, 248, 86), 2.8)
speedMultLbl.TextXAlignment = Enum.TextXAlignment.Left

local cashIconLbl = makeOutlinedLabel(statsCorner, "💵", UDim2.fromOffset(38, 38), UDim2.fromOffset(0, 46), Color3.new(1, 1, 1), 1.5)
cashIconLbl.BackgroundTransparency = 1
local cashValLbl = makeOutlinedLabel(statsCorner, "$150", UDim2.fromOffset(170, 40), UDim2.fromOffset(44, 44), Color3.fromRGB(76, 248, 86), 3)
cashValLbl.TextXAlignment = Enum.TextXAlignment.Left
local cashRateLbl = makeOutlinedLabel(statsCorner, "+$0/s", UDim2.fromOffset(140, 32), UDim2.fromOffset(214, 48), Color3.fromRGB(142, 255, 132), 2.5)
cashRateLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================================
-- 4. RIGHT EDGE TOGGLES + COLLAPSIBLE DRAWER (Active Pets & Pending Crates)
-- ============================================================================
local rightEdgeBtns = Instance.new("Frame")
rightEdgeBtns.Name = "RightEdgeToggles"
rightEdgeBtns.Size = UDim2.fromOffset(50, 108)
rightEdgeBtns.Position = UDim2.new(1, -60, 0.42, 0)
rightEdgeBtns.BackgroundTransparency = 1
rightEdgeBtns.Parent = gui

local cratesEdgeBtn = Instance.new("TextButton")
cratesEdgeBtn.Size = UDim2.fromOffset(48, 48)
cratesEdgeBtn.BackgroundColor3 = Color3.fromRGB(208, 48, 40)
cratesEdgeBtn.Text = "📦"
cratesEdgeBtn.TextScaled = true
cratesEdgeBtn.Parent = rightEdgeBtns
makeCorner(cratesEdgeBtn, 8)
makeStroke(cratesEdgeBtn, 2.5)

local petsEdgeBtn = Instance.new("TextButton")
petsEdgeBtn.Size = UDim2.fromOffset(48, 48)
petsEdgeBtn.Position = UDim2.fromOffset(0, 56)
petsEdgeBtn.BackgroundColor3 = Color3.fromRGB(196, 130, 58)
petsEdgeBtn.Text = "🐾"
petsEdgeBtn.TextScaled = true
petsEdgeBtn.Parent = rightEdgeBtns
makeCorner(petsEdgeBtn, 8)
makeStroke(petsEdgeBtn, 2.5)

local rightDrawerWrap = Instance.new("Frame")
rightDrawerWrap.Name = "RightSideDrawer"
rightDrawerWrap.Size = UDim2.fromOffset(256, 270)
rightDrawerWrap.Position = UDim2.new(1, -326, 0.36, 0)
rightDrawerWrap.BackgroundTransparency = 1
rightDrawerWrap.Parent = gui

local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.fromOffset(32, 38)
collapseBtn.Position = UDim2.fromOffset(-38, 92)
collapseBtn.BackgroundColor3 = Color3.fromRGB(218, 28, 22)
collapseBtn.Text = ">"
collapseBtn.TextColor3 = Color3.new(1, 1, 1)
collapseBtn.Font = Enum.Font.FredokaOne
collapseBtn.TextScaled = true
collapseBtn.Parent = rightDrawerWrap
makeCorner(collapseBtn, 6)
makeStroke(collapseBtn, 2.5)
makeTextStroke(collapseBtn, 2)

local drawerBox = Instance.new("Frame")
drawerBox.Size = UDim2.fromOffset(256, 215)
drawerBox.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
drawerBox.BackgroundTransparency = 0.08
drawerBox.Parent = rightDrawerWrap
makeCorner(drawerBox, 8)
makeStroke(drawerBox, 2.8)

local drawerHead = Instance.new("Frame")
drawerHead.Size = UDim2.new(1, 0, 0, 34)
drawerHead.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
drawerHead.Parent = drawerBox
makeCorner(drawerHead, 8)
makeStroke(drawerHead, 2)

local drawerTitleLbl = makeOutlinedLabel(drawerHead, "0/8 Active", UDim2.new(0.56, -8, 0.9, 0), UDim2.fromOffset(8, 2), Color3.fromRGB(255, 206, 52), 2.2)
drawerTitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local drawerTopActionBtn = Instance.new("TextButton")
drawerTopActionBtn.Size = UDim2.fromOffset(92, 24)
drawerTopActionBtn.Position = UDim2.new(1, -98, 0, 5)
drawerTopActionBtn.BackgroundColor3 = Color3.fromRGB(168, 134, 48)
drawerTopActionBtn.Text = "UPGRADE"
drawerTopActionBtn.TextColor3 = Color3.new(1, 1, 1)
drawerTopActionBtn.Font = Enum.Font.FredokaOne
drawerTopActionBtn.TextScaled = true
drawerTopActionBtn.Parent = drawerHead
makeCorner(drawerTopActionBtn, 6)
makeStroke(drawerTopActionBtn, 2)
makeTextStroke(drawerTopActionBtn, 1.8)

local drawerScroll = Instance.new("ScrollingFrame")
drawerScroll.Size = UDim2.new(1, -12, 1, -44)
drawerScroll.Position = UDim2.fromOffset(6, 38)
drawerScroll.BackgroundTransparency = 1
drawerScroll.ScrollBarThickness = 6
drawerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
drawerScroll.CanvasSize = UDim2.fromScale(0, 0)
drawerScroll.Parent = drawerBox

local drawerListLayout = Instance.new("UIListLayout")
drawerListLayout.Padding = UDim.new(0, 6)
drawerListLayout.Parent = drawerScroll

local equipBestBtn = Instance.new("TextButton")
equipBestBtn.Name = "EquipBestButton"
equipBestBtn.Size = UDim2.fromOffset(256, 42)
equipBestBtn.Position = UDim2.fromOffset(0, 222)
equipBestBtn.BackgroundColor3 = Color3.new(1, 1, 1)
equipBestBtn.Text = "Equip Best"
equipBestBtn.TextColor3 = Color3.new(1, 1, 1)
equipBestBtn.Font = Enum.Font.FredokaOne
equipBestBtn.TextScaled = true
equipBestBtn.Parent = rightDrawerWrap
makeCorner(equipBestBtn, 8)
makeStroke(equipBestBtn, 2.8)
makeTextStroke(equipBestBtn, 2.5)
makeGradient(equipBestBtn, Color3.fromRGB(128, 255, 48), Color3.fromRGB(42, 188, 18))

local function renderRightDrawer()
	for _, ch in ipairs(drawerScroll:GetChildren()) do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	if not profile then return end

	if drawerMode == "Active" then
		drawerTitleLbl.Text = string.format("%d/%d Active", #profile.roamingAnimalUids, profile.penCapacity)
		drawerTopActionBtn.Text = "UPGRADE"
		drawerTopActionBtn.BackgroundColor3 = Color3.fromRGB(168, 134, 48)
		equipBestBtn.Visible = not drawerCollapsed

		for _, uid in ipairs(profile.roamingAnimalUids) do
			local animal = profile.inventoryAnimals[uid]
			if animal then
				local spec = AnimalConfig.GetById(animal.speciesId)
				local inc = AnimalConfig.ComputeIncomePerSec(animal)
				local card = Instance.new("Frame")
				card.Size = UDim2.new(1, -4, 0, 50)
				card.BackgroundColor3 = Color3.fromRGB(142, 88, 42)
				card.Parent = drawerScroll
				makeCorner(card, 8)
				makeStroke(card, 2)

				local iconHolder = Instance.new("Frame")
				iconHolder.Size = UDim2.fromOffset(40, 40)
				iconHolder.Position = UDim2.fromOffset(5, 5)
				iconHolder.BackgroundTransparency = 1
				iconHolder.Parent = card
				makeAnimalIconFrame(iconHolder, animal.speciesId, animal.mutation, false)

				local nLbl = makeOutlinedLabel(card, spec and spec.name or animal.speciesId, UDim2.new(1, -138, 0, 22), UDim2.fromOffset(52, 4), Color3.fromRGB(118, 214, 255), 2)
				nLbl.TextXAlignment = Enum.TextXAlignment.Left
				local incLbl = makeOutlinedLabel(card, "($" .. FormatUtil.Number(inc) .. "/s)", UDim2.new(1, -138, 0, 18), UDim2.fromOffset(52, 26), Color3.fromRGB(122, 255, 132), 1.8)
				incLbl.TextXAlignment = Enum.TextXAlignment.Left

				local unBtn = Instance.new("TextButton")
				unBtn.Size = UDim2.fromOffset(78, 32)
				unBtn.Position = UDim2.new(1, -84, 0, 9)
				unBtn.BackgroundColor3 = Color3.fromRGB(198, 48, 38)
				unBtn.Text = "Unequip"
				unBtn.TextColor3 = Color3.new(1, 1, 1)
				unBtn.Font = Enum.Font.FredokaOne
				unBtn.TextScaled = true
				unBtn.Parent = card
				makeCorner(unBtn, 6)
				makeStroke(unBtn, 2)
				makeTextStroke(unBtn, 1.8)
				unBtn.MouseButton1Click:Connect(function()
					Remotes.Get("UnequipPenAnimal"):FireServer(uid)
				end)
			end
		end
	else
		local pendingList: { Types.CrateInstance } = {}
		for _, c in pairs(profile.pendingCrates) do
			table.insert(pendingList, c)
		end
		drawerTitleLbl.Text = string.format("Growing Crates (%d)", #pendingList)
		drawerTopActionBtn.Text = "Open All"
		drawerTopActionBtn.BackgroundColor3 = Color3.fromRGB(224, 152, 34)
		equipBestBtn.Visible = false

		for _, crate in ipairs(pendingList) do
			local rem = math.max(0, crate.unlockAt - os.time())
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -4, 0, 48)
			card.BackgroundColor3 = Color3.fromRGB(58, 64, 78)
			card.Parent = drawerScroll
			makeCorner(card, 8)
			makeStroke(card, 2)

			local tLbl = makeOutlinedLabel(card, string.format("[%s] %s", crate.rarity, crate.biomeId), UDim2.new(1, -92, 0, 22), UDim2.fromOffset(8, 4), GameConfig.RARITY_COLORS[crate.rarity], 2)
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			local sLbl = makeOutlinedLabel(card, if rem > 0 then ("Ready in " .. FormatUtil.Time(rem)) else "READY TO OPEN!", UDim2.new(1, -92, 0, 18), UDim2.fromOffset(8, 25), Color3.fromRGB(235, 240, 248), 1.8)
			sLbl.TextXAlignment = Enum.TextXAlignment.Left

			local opBtn = Instance.new("TextButton")
			opBtn.Size = UDim2.fromOffset(74, 32)
			opBtn.Position = UDim2.new(1, -80, 0, 8)
			opBtn.BackgroundColor3 = if rem > 0 then Color3.fromRGB(96, 104, 122) else Color3.fromRGB(72, 206, 86)
			opBtn.Text = if rem > 0 then FormatUtil.Time(rem) else "OPEN"
			opBtn.TextColor3 = Color3.new(1, 1, 1)
			opBtn.Font = Enum.Font.FredokaOne
			opBtn.TextScaled = true
			opBtn.Parent = card
			makeCorner(opBtn, 6)
			makeStroke(opBtn, 2)
			opBtn.MouseButton1Click:Connect(function()
				Remotes.Get("OpenPendingCrate"):FireServer(crate.uid)
			end)
		end
	end
end

drawerTopActionBtn.MouseButton1Click:Connect(function()
	if drawerMode == "Active" then
		Remotes.Get("UpgradePen"):FireServer()
	elseif profile then
		for uid, _ in pairs(profile.pendingCrates) do
			Remotes.Get("OpenPendingCrate"):FireServer(uid)
		end
	end
end)
equipBestBtn.MouseButton1Click:Connect(function()
	Remotes.Get("EquipBestAnimals"):FireServer()
end)

local function setDrawerCollapsed(collapsed: boolean, mode: string?)
	if mode then drawerMode = mode end
	drawerCollapsed = collapsed
	drawerBox.Visible = not collapsed
	equipBestBtn.Visible = (not collapsed) and (drawerMode == "Active")
	collapseBtn.Text = if collapsed then "<" else ">"
	collapseBtn.Position = if collapsed then UDim2.fromOffset(224, 92) else UDim2.fromOffset(-38, 92)
	renderRightDrawer()
end

collapseBtn.MouseButton1Click:Connect(function()
	setDrawerCollapsed(not drawerCollapsed, nil)
end)
cratesEdgeBtn.MouseButton1Click:Connect(function()
	if drawerCollapsed or drawerMode ~= "Crates" then
		setDrawerCollapsed(false, "Crates")
	else
		setDrawerCollapsed(true, nil)
	end
end)
petsEdgeBtn.MouseButton1Click:Connect(function()
	if drawerCollapsed or drawerMode ~= "Active" then
		setDrawerCollapsed(false, "Active")
	else
		setDrawerCollapsed(true, nil)
	end
end)

-- ============================================================================
-- 5. BOTTOM-CENTER 3-SLOT HOTBAR & BOTTOM-RIGHT MYTHIC TIMER
-- ============================================================================
local hotbar = Instance.new("Frame")
hotbar.Name = "BottomHotbar"
hotbar.Size = UDim2.fromOffset(192, 62)
hotbar.Position = UDim2.new(0.5, -96, 1, -68)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui

local hbLayout = Instance.new("UIListLayout")
hbLayout.FillDirection = Enum.FillDirection.Horizontal
hbLayout.Padding = UDim.new(0, 8)
hbLayout.Parent = hotbar

local function makeHotbarSlot(keyNum: string, icon: string, label: string, onClick: () -> ()): TextButton
	local slot = Instance.new("TextButton")
	slot.Size = UDim2.fromOffset(58, 58)
	slot.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
	slot.BackgroundTransparency = 0.15
	slot.Text = ""
	slot.Parent = hotbar
	makeCorner(slot, 8)
	makeStroke(slot, 2.5)

	local k = makeOutlinedLabel(slot, keyNum, UDim2.fromOffset(16, 16), UDim2.fromOffset(4, 2), Color3.new(1, 1, 1), 1.8)
	k.TextXAlignment = Enum.TextXAlignment.Left
	local ic = Instance.new("TextLabel")
	ic.Size = UDim2.fromOffset(34, 30)
	ic.Position = UDim2.fromOffset(12, 8)
	ic.BackgroundTransparency = 1
	ic.Text = icon
	ic.TextScaled = true
	ic.Parent = slot
	makeOutlinedLabel(slot, label, UDim2.new(1, -6, 0, 14), UDim2.new(0, 3, 1, -16), Color3.new(1, 1, 1), 1.8)

	slot.MouseButton1Click:Connect(onClick)
	return slot
end

local eventTimerBox = Instance.new("Frame")
eventTimerBox.Name = "BottomRightTimer"
eventTimerBox.Size = UDim2.fromOffset(175, 44)
eventTimerBox.Position = UDim2.new(1, -186, 1, -52)
eventTimerBox.BackgroundTransparency = 1
eventTimerBox.Parent = gui
makeOutlinedLabel(eventTimerBox, "❄️", UDim2.fromOffset(40, 40), UDim2.fromOffset(0, 2), Color3.fromRGB(142, 234, 255), 2)
local timerLbl = makeOutlinedLabel(eventTimerBox, "In: 10:00", UDim2.fromOffset(130, 36), UDim2.fromOffset(44, 4), Color3.new(1, 1, 1), 2.6)
timerLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================================
-- 6. MODAL WINDOWS: SHOP | INDEX | ALL PETS INVENTORY | SETTINGS
-- ============================================================================
-- Forward declare renderers
local renderActiveModal: () -> ()

local function openModal(name: string?)
	currentModal = if currentModal == name then nil else name
	renderActiveModal()
end

-- A. SHOP MODAL (Screenshots 2 & 3)
local shopWindow = Instance.new("Frame")
shopWindow.Name = "ShopModal"
shopWindow.Size = UDim2.fromOffset(670, 435)
shopWindow.Position = UDim2.new(0.5, -335, 0.5, -220)
shopWindow.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
shopWindow.Visible = false
shopWindow.Parent = gui
makeCorner(shopWindow, 12)
makeStroke(shopWindow, 3)

makeWindowHeader(shopWindow, "Shop", Color3.fromRGB(132, 255, 42), Color3.fromRGB(64, 198, 18), function()
	openModal(nil)
end)

local shopTabsBar = Instance.new("Frame")
shopTabsBar.Size = UDim2.new(1, -24, 0, 34)
shopTabsBar.Position = UDim2.fromOffset(12, 54)
shopTabsBar.BackgroundTransparency = 1
shopTabsBar.Parent = shopWindow
local stLayout = Instance.new("UIListLayout")
stLayout.FillDirection = Enum.FillDirection.Horizontal
stLayout.Padding = UDim.new(0, 6)
stLayout.Parent = shopTabsBar

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Size = UDim2.new(1, -24, 1, -102)
shopScroll.Position = UDim2.fromOffset(12, 92)
shopScroll.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
shopScroll.ScrollBarThickness = 8
shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopScroll.CanvasSize = UDim2.fromScale(0, 0)
shopScroll.Parent = shopWindow
makeCorner(shopScroll, 8)
local ssLayout = Instance.new("UIListLayout")
ssLayout.Padding = UDim.new(0, 10)
ssLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ssLayout.Parent = shopScroll
local ssPad = Instance.new("UIPadding")
ssPad.PaddingTop = UDim.new(0, 8)
ssPad.PaddingBottom = UDim.new(0, 8)
ssPad.Parent = shopScroll

local function renderShopModal()
	for _, ch in ipairs(shopTabsBar:GetChildren()) do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	for _, ch in ipairs(shopScroll:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end

	local subTabs = {
		{ id = "Featured", label = "Featured & Passes" },
		{ id = "Lassos", label = "Lassos (10)" },
		{ id = "Trails", label = "Trails (10)" },
		{ id = "Vehicles", label = "Vehicles (6)" },
		{ id = "Fuse", label = "Fuse Machine" },
		{ id = "Rebirth", label = "Rebirth/Daily" },
	}
	for _, st in ipairs(subTabs) do
		local tb = Instance.new("TextButton")
		tb.Size = UDim2.new(0.16, 0, 1, 0)
		tb.BackgroundColor3 = if shopSubTab == st.id then Color3.fromRGB(84, 212, 54) else Color3.fromRGB(48, 52, 64)
		tb.Text = st.label
		tb.TextColor3 = Color3.new(1, 1, 1)
		tb.Font = Enum.Font.FredokaOne
		tb.TextScaled = true
		tb.Parent = shopTabsBar
		makeCorner(tb, 6)
		makeStroke(tb, 2)
		makeTextStroke(tb, 1.8)
		tb.MouseButton1Click:Connect(function()
			shopSubTab = st.id
			renderShopModal()
		end)
	end

	if not profile then return end

	if shopSubTab == "Featured" then
		makeOutlinedLabel(shopScroll, "~ Featured ~", UDim2.new(0.95, 0, 0, 28), UDim2.new(), Color3.fromRGB(255, 224, 102), 2.5)

		-- Ornate Gold Featured Banner (Screenshot 2)
		local featCard = Instance.new("Frame")
		featCard.Size = UDim2.new(0.96, 0, 0, 198)
		featCard.BackgroundColor3 = Color3.fromRGB(64, 88, 178)
		featCard.Parent = shopScroll
		makeCorner(featCard, 10)
		makeStroke(featCard, 3.5, Color3.fromRGB(255, 204, 52))
		makeGradient(featCard, Color3.fromRGB(88, 126, 232), Color3.fromRGB(38, 48, 118))

		local tagNew = makeOutlinedLabel(featCard, "NEW!", UDim2.fromOffset(64, 26), UDim2.fromOffset(10, 10), Color3.new(1, 1, 1), 2)
		tagNew.BackgroundColor3 = Color3.fromRGB(218, 38, 38)
		tagNew.BackgroundTransparency = 0
		makeCorner(tagNew, 6)
		makeStroke(tagNew, 2)

		local fTitle = makeOutlinedLabel(featCard, "FANTASY RESCUE PACK", UDim2.fromOffset(280, 36), UDim2.fromOffset(82, 6), Color3.fromRGB(255, 214, 62), 2.8)
		fTitle.TextXAlignment = Enum.TextXAlignment.Left
		makeOutlinedLabel(featCard, "Limited Time! Top Rare & Mythic Pets", UDim2.fromOffset(260, 20), UDim2.fromOffset(84, 40), Color3.fromRGB(240, 245, 255), 2).TextXAlignment = Enum.TextXAlignment.Left

		-- 6 Featured Showcase Animal Cards
		local featuredSpecies = {
			{ id = "AntlerStag", chance = "48%" },
			{ id = "AlbinoGator", chance = "30.9%" },
			{ id = "SolarManeLion", chance = "15%" },
			{ id = "GlacierMammoth", chance = "5%" },
			{ id = "InfernoPhoenix", chance = "1%" },
			{ id = "MythicWhiteTiger", chance = "0.1%" },
		}
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -20, 0, 82)
		row.Position = UDim2.fromOffset(10, 68)
		row.BackgroundTransparency = 1
		row.Parent = featCard
		local rLay = Instance.new("UIListLayout")
		rLay.FillDirection = Enum.FillDirection.Horizontal
		rLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rLay.Padding = UDim.new(0, 6)
		rLay.Parent = row

		for _, item in ipairs(featuredSpecies) do
			local sc = Instance.new("Frame")
			sc.Size = UDim2.fromOffset(92, 80)
			sc.BackgroundTransparency = 1
			sc.Parent = row
			local box = makeAnimalIconFrame(sc, item.id, "None", false)
			local chLbl = makeOutlinedLabel(box, item.chance, UDim2.new(1, -6, 0, 20), UDim2.new(0, 3, 1, -22), Color3.new(1, 1, 1), 2)
			chLbl.TextXAlignment = Enum.TextXAlignment.Right
		end

		local packBtn = Instance.new("TextButton")
		packBtn.Size = UDim2.fromOffset(220, 34)
		packBtn.Position = UDim2.new(0.5, -110, 1, -42)
		packBtn.BackgroundColor3 = Color3.fromRGB(64, 214, 48)
		packBtn.Text = "Starter Ranger Pack (99 R$)"
		packBtn.TextColor3 = Color3.new(1, 1, 1)
		packBtn.Font = Enum.Font.FredokaOne
		packBtn.TextScaled = true
		packBtn.Parent = featCard
		makeCorner(packBtn, 8)
		makeStroke(packBtn, 2.5)
		makeTextStroke(packBtn, 2)
		packBtn.MouseButton1Click:Connect(function()
			Remotes.Get("PromptProduct"):FireServer("StarterPack")
		end)

		-- ~ Game Passes ~ 2-Column Gradient Grid (Screenshot 3)
		makeOutlinedLabel(shopScroll, "~ Game Passes ~", UDim2.new(0.95, 0, 0, 28), UDim2.new(), Color3.fromRGB(255, 224, 102), 2.5)

		local gpGridHolder = Instance.new("Frame")
		gpGridHolder.Size = UDim2.new(0.96, 0, 0, 390)
		gpGridHolder.BackgroundTransparency = 1
		gpGridHolder.Parent = shopScroll
		local gpGrid = Instance.new("UIGridLayout")
		gpGrid.CellSize = UDim2.fromOffset(298, 120)
		gpGrid.CellPadding = UDim2.fromOffset(10, 10)
		gpGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gpGrid.Parent = gpGridHolder

		local gpConfigs = {
			{ key = "DoublePull", icon = "🪢", topC = Color3.fromRGB(48, 224, 255), botC = Color3.fromRGB(24, 118, 232) },
			{ key = "VIP", icon = "💵", topC = Color3.fromRGB(255, 224, 72), botC = Color3.fromRGB(244, 138, 28) },
			{ key = "DoubleSpeed", icon = "👟", topC = Color3.fromRGB(238, 86, 255), botC = Color3.fromRGB(118, 48, 232) },
			{ key = "AutoUnboxCollect", icon = "📦", topC = Color3.fromRGB(255, 168, 52), botC = Color3.fromRGB(224, 58, 48) },
			{ key = "DualTowHook", icon = "🪝", topC = Color3.fromRGB(72, 238, 162), botC = Color3.fromRGB(28, 152, 108) },
			{ key = "ExtraZooCapacity", icon = "🐾", topC = Color3.fromRGB(255, 112, 178), botC = Color3.fromRGB(182, 48, 118) },
		}
		for _, gpc in ipairs(gpConfigs) do
			local def = (MonetizationConfig.GAME_PASSES :: any)[gpc.key]
			local card = Instance.new("Frame")
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.Parent = gpGridHolder
			makeCorner(card, 10)
			makeStroke(card, 2.8)
			makeGradient(card, gpc.topC, gpc.botC)

			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.fromOffset(64, 64)
			badge.Position = UDim2.fromOffset(10, 10)
			badge.BackgroundColor3 = Color3.fromRGB(28, 36, 52)
			badge.BackgroundTransparency = 0.2
			badge.Text = gpc.icon
			badge.TextScaled = true
			badge.Parent = card
			makeCorner(badge, 32)
			makeStroke(badge, 2.5)

			makeOutlinedLabel(card, def.name, UDim2.new(1, -86, 0, 24), UDim2.fromOffset(80, 6), Color3.new(1, 1, 1), 2.2).TextXAlignment = Enum.TextXAlignment.Left
			local desc = makeOutlinedLabel(card, def.description, UDim2.new(1, -86, 0, 38), UDim2.fromOffset(80, 32), Color3.fromRGB(224, 255, 224), 1.8)
			desc.TextXAlignment = Enum.TextXAlignment.Left

			local buyBtn = Instance.new("TextButton")
			buyBtn.Size = UDim2.new(1, -92, 0, 32)
			buyBtn.Position = UDim2.fromOffset(82, 78)
			buyBtn.BackgroundColor3 = Color3.fromRGB(72, 224, 48)
			buyBtn.Text = "R$ " .. tostring(def.priceRobux)
			buyBtn.TextColor3 = Color3.new(1, 1, 1)
			buyBtn.Font = Enum.Font.FredokaOne
			buyBtn.TextScaled = true
			buyBtn.Parent = card
			makeCorner(buyBtn, 8)
			makeStroke(buyBtn, 2.2)
			makeTextStroke(buyBtn, 2)
			buyBtn.MouseButton1Click:Connect(function()
				Remotes.Get("PromptGamePass"):FireServer(gpc.key)
			end)
		end
	else
		local function addShopRow(titleStr: string, subStr: string, btnStr: string, btnCol: Color3, cb: () -> ())
			local r = Instance.new("Frame")
			r.Size = UDim2.new(0.95, 0, 0, 56)
			r.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
			r.Parent = shopScroll
			makeCorner(r, 8)
			makeStroke(r, 2)

			makeOutlinedLabel(r, titleStr, UDim2.new(0.68, -12, 0, 26), UDim2.fromOffset(10, 4), Color3.new(1, 1, 1), 2).TextXAlignment = Enum.TextXAlignment.Left
			makeOutlinedLabel(r, subStr, UDim2.new(0.68, -12, 0, 18), UDim2.fromOffset(10, 32), Color3.fromRGB(192, 212, 238), 1.6).TextXAlignment = Enum.TextXAlignment.Left

			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0.28, -10, 0, 40)
			b.Position = UDim2.new(0.71, 0, 0, 8)
			b.BackgroundColor3 = btnCol
			b.Text = btnStr
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Font = Enum.Font.FredokaOne
			b.TextScaled = true
			b.Parent = r
			makeCorner(b, 8)
			makeStroke(b, 2)
			makeTextStroke(b, 1.8)
			b.MouseButton1Click:Connect(cb)
		end

		if shopSubTab == "Lassos" then
			for _, l in ipairs(LassoConfig) do
				local owned = profile.ownedLassos[l.id] == true
				local eq = profile.equippedLasso == l.id
				addShopRow(
					string.format("T%d: %s (%s Power)", l.tier, l.name, FormatUtil.Number(l.pullPower)),
					l.description,
					if eq then "EQUIPPED" elseif owned then "EQUIP" elseif l.cost == 0 then "FREE" else "$" .. FormatUtil.Number(l.cost),
					if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(72, 214, 52),
					function()
						if owned then Remotes.Get("EquipLasso"):FireServer(l.id)
						else Remotes.Get("BuyLasso"):FireServer(l.id) end
					end
				)
			end
		elseif shopSubTab == "Trails" then
			for _, t in ipairs(TrailConfig) do
				local owned = profile.ownedTrails[t.id] == true
				local eq = profile.equippedTrail == t.id
				addShopRow(
					string.format("T%d: %s (%gx Speed | +%d%% Cash)", t.tier, t.name, t.speedMultiplier, math.floor(t.cashBonus * 100)),
					t.description,
					if eq then "EQUIPPED" elseif owned then "EQUIP" else "$" .. FormatUtil.Number(t.cost),
					if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(0, 198, 224),
					function()
						if owned then Remotes.Get("EquipTrail"):FireServer(t.id)
						else Remotes.Get("BuyTrail"):FireServer(t.id) end
					end
				)
			end
		elseif shopSubTab == "Vehicles" then
			for _, v in ipairs(VehicleConfig) do
				local owned = profile.ownedVehicles[v.id] == true
				local eq = profile.equippedVehicle == v.id
				addShopRow(
					string.format("T%d: %s (+%d Speed | %d Tow)", v.tier, v.name, v.baseSpeedBonus, v.towCapacity),
					v.description,
					if eq then "EQUIPPED" elseif owned then "EQUIP" else "$" .. FormatUtil.Number(v.cost),
					if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(64, 198, 98),
					function()
						if owned then Remotes.Get("EquipVehicle"):FireServer(v.id)
						else Remotes.Get("BuyVehicle"):FireServer(v.id) end
					end
				)
			end
		elseif shopSubTab == "Fuse" then
			addShopRow("3-in-1 Mutation Merge (" .. #selectedFuseUids .. "/3 Selected)", "Combine 3 identical species & mutation to evolve!", "MERGE (3)", Color3.fromRGB(178, 86, 255), function()
				if #selectedFuseUids == 3 then
					Remotes.Get("RequestMergeAnimals"):FireServer(selectedFuseUids)
					table.clear(selectedFuseUids)
				end
			end)
			addShopRow("Cross-Fuse (" .. #selectedFuseUids .. "/3 Selected)", "Combine any 3 animals for high mutation luck!", "FUSE (3)", Color3.fromRGB(238, 86, 178), function()
				if #selectedFuseUids == 3 then
					Remotes.Get("RequestCrossFuse"):FireServer(selectedFuseUids)
					table.clear(selectedFuseUids)
				end
			end)
			for uid, a in pairs(profile.inventoryAnimals) do
				local spec = AnimalConfig.GetById(a.speciesId)
				local isSel = table.find(selectedFuseUids, uid) ~= nil
				addShopRow(
					string.format("[%s] %s (%.2fx)", a.mutation, spec and spec.name or a.speciesId, a.sizeRatio),
					"Select 3 animals to Fuse or Merge",
					if isSel then "SELECTED" else "SELECT",
					if isSel then Color3.fromRGB(72, 214, 88) else Color3.fromRGB(68, 76, 98),
					function()
						local idx = table.find(selectedFuseUids, uid)
						if idx then table.remove(selectedFuseUids, idx)
						elseif #selectedFuseUids < 3 then table.insert(selectedFuseUids, uid) end
						renderShopModal()
					end
				)
			end
		elseif shopSubTab == "Rebirth" then
			local reqSpd = math.floor(GameConfig.ECONOMY.REBIRTH_BASE_SPEED * math.pow(2.1, profile.rebirths))
			local reqCoins = math.floor(GameConfig.ECONOMY.REBIRTH_BASE_COINS * math.pow(GameConfig.ECONOMY.REBIRTH_GROWTH, profile.rebirths))
			addShopRow(
				string.format("REBIRTH #%d (+75%% Permanent Cash)", profile.rebirths + 1),
				string.format("Needs %s Speed & $%s Coins", FormatUtil.Number(reqSpd), FormatUtil.Number(reqCoins)),
				"REBIRTH",
				Color3.fromRGB(238, 68, 122),
				function() Remotes.Get("RequestRebirth"):FireServer() end
			)
			addShopRow(
				string.format("Claim Daily Reward (Streak Day %d)", profile.dailyReward.streak),
				"Free Coins & Speed every 24h!",
				"CLAIM DAILY",
				Color3.fromRGB(244, 178, 44),
				function() Remotes.Get("ClaimDailyReward"):FireServer() end
			)
		end
	end
end

-- B. INDEX MODAL (Screenshots 4 & 5)
local indexWindow = Instance.new("Frame")
indexWindow.Name = "IndexModal"
indexWindow.Size = UDim2.fromOffset(690, 440)
indexWindow.Position = UDim2.new(0.5, -345, 0.5, -220)
indexWindow.BackgroundColor3 = Color3.fromRGB(26, 36, 18)
indexWindow.Visible = false
indexWindow.Parent = gui
makeCorner(indexWindow, 12)
makeStroke(indexWindow, 3)

makeWindowHeader(indexWindow, "Index", Color3.fromRGB(255, 118, 245), Color3.fromRGB(184, 52, 232), function()
	openModal(nil)
end)

-- Right External Filter Tabs sticking out of Index Window (Normal / Limited / Mutations)
local indexRightTabs = Instance.new("Frame")
indexRightTabs.Size = UDim2.fromOffset(110, 150)
indexRightTabs.Position = UDim2.new(1, 4, 0, 56)
indexRightTabs.BackgroundTransparency = 1
indexRightTabs.Parent = indexWindow

local indexScroll = Instance.new("ScrollingFrame")
indexScroll.Size = UDim2.new(0.68, -16, 1, -124)
indexScroll.Position = UDim2.fromOffset(12, 56)
indexScroll.BackgroundColor3 = Color3.fromRGB(20, 26, 16)
indexScroll.ScrollBarThickness = 8
indexScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
indexScroll.CanvasSize = UDim2.fromScale(0, 0)
indexScroll.Parent = indexWindow
makeCorner(indexScroll, 8)
local idxLayout = Instance.new("UIListLayout")
idxLayout.Padding = UDim.new(0, 10)
idxLayout.Parent = indexScroll
local idxPad = Instance.new("UIPadding")
idxPad.PaddingTop = UDim.new(0, 8)
idxPad.PaddingLeft = UDim.new(0, 8)
idxPad.PaddingRight = UDim.new(0, 8)
idxPad.PaddingBottom = UDim.new(0, 8)
idxPad.Parent = indexScroll

-- Right Inspect Panel (Brushed Silver Card)
local inspectPanel = Instance.new("Frame")
inspectPanel.Size = UDim2.new(0.32, -14, 1, -68)
inspectPanel.Position = UDim2.new(0.68, 4, 0, 56)
inspectPanel.BackgroundColor3 = Color3.fromRGB(224, 228, 236)
inspectPanel.Parent = indexWindow
makeCorner(inspectPanel, 8)
makeStroke(inspectPanel, 2.5)
makeGradient(inspectPanel, Color3.fromRGB(240, 244, 250), Color3.fromRGB(168, 176, 192))

-- Bottom-Left Total Progress Bar
local totalIndexBar = Instance.new("Frame")
totalIndexBar.Size = UDim2.new(0.68, -16, 0, 44)
totalIndexBar.Position = UDim2.new(0, 12, 1, -56)
totalIndexBar.BackgroundColor3 = Color3.fromRGB(36, 46, 30)
totalIndexBar.Parent = indexWindow
makeCorner(totalIndexBar, 8)
makeStroke(totalIndexBar, 2.5)

local function renderIndexModal()
	for _, ch in ipairs(indexRightTabs:GetChildren()) do ch:Destroy() end
	for _, ch in ipairs(indexScroll:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	for _, ch in ipairs(inspectPanel:GetChildren()) do
		if not ch:IsA("UICorner") and not ch:IsA("UIStroke") and not ch:IsA("UIGradient") then ch:Destroy() end
	end
	for _, ch in ipairs(totalIndexBar:GetChildren()) do
		if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then ch:Destroy() end
	end

	local rtDefs = {
		{ id = "Normal", col1 = Color3.fromRGB(82, 224, 255), col2 = Color3.fromRGB(28, 152, 238) },
		{ id = "Limited", col1 = Color3.fromRGB(255, 224, 72), col2 = Color3.fromRGB(224, 142, 28) },
		{ id = "Mutations", col1 = Color3.fromRGB(255, 96, 212), col2 = Color3.fromRGB(132, 68, 255) },
	}
	for i, rt in ipairs(rtDefs) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(102, 38)
		b.Position = UDim2.fromOffset(0, (i - 1) * 44)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.Text = rt.id
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.Parent = indexRightTabs
		makeCorner(b, 8)
		makeStroke(b, if indexRightTab == rt.id then 3 else 2, if indexRightTab == rt.id then Color3.fromRGB(255, 240, 120) else Color3.fromRGB(14, 15, 18))
		makeTextStroke(b, 2)
		makeGradient(b, rt.col1, rt.col2)
		b.MouseButton1Click:Connect(function()
			indexRightTab = rt.id
			renderIndexModal()
		end)
	end

	if not profile then return end

	local totalUnlocked = 0
	for _ in pairs(profile.discoveredIndex) do totalUnlocked += 1 end

	-- Render Each of the 5 Biomes as a Zone Container Block
	for _, biome in ipairs(BiomeConfig) do
		local pool = AnimalConfig.GetByBiome(biome.id)
		local rows = math.ceil(#pool / 4)
		local containerH = math.max(150, rows * 76 + 52)

		local zCard = Instance.new("Frame")
		zCard.Size = UDim2.new(1, 0, 0, containerH)
		zCard.BackgroundColor3 = Color3.fromRGB(16, 20, 16)
		zCard.Parent = indexScroll
		makeCorner(zCard, 8)
		makeStroke(zCard, 2)

		-- Left Vertical Biome Strip
		local banner = Instance.new("Frame")
		banner.Size = UDim2.new(0, 74, 1, -12)
		banner.Position = UDim2.fromOffset(6, 6)
		banner.BackgroundColor3 = biome.groundColor
		banner.Parent = zCard
		makeCorner(banner, 6)
		makeStroke(banner, 2)
		makeGradient(banner, biome.groundColor, biome.cliffColor)
		makeOutlinedLabel(banner, string.format("Z%d\n%s", biome.order, biome.id), UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05), Color3.new(1, 1, 1), 2)

		-- Center 4-Column Animal Grid
		local gridBox = Instance.new("Frame")
		gridBox.Size = UDim2.new(1, -92, 1, -48)
		gridBox.Position = UDim2.fromOffset(86, 6)
		gridBox.BackgroundTransparency = 1
		gridBox.Parent = zCard
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(74, 70)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.Parent = gridBox

		local zUnlocked = 0
		for _, spec in ipairs(pool) do
			local entry = profile.discoveredIndex[spec.id]
			local isDisc = entry ~= nil
			if isDisc then zUnlocked += 1 end

			local btn = Instance.new("TextButton")
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.Parent = gridBox

			local mutShow: Types.AnimalMutation = "None"
			if isDisc and indexRightTab == "Mutations" then
				for mKey, found in pairs(entry.mutationsFound) do
					if found and mKey ~= "None" then mutShow = mKey :: Types.AnimalMutation break end
				end
			end
			local iconBox = makeAnimalIconFrame(btn, spec.id, mutShow, not isDisc)
			makeOutlinedLabel(iconBox, if isDisc then spec.name else "???", UDim2.new(1, -4, 0, 18), UDim2.fromOffset(2, 2), Color3.new(1, 1, 1), 1.8)

			btn.MouseButton1Click:Connect(function()
				selectedIndexSpeciesId = spec.id
				renderIndexModal()
			end)
		end

		-- Bottom Green Progress Bar inside Zone Block
		local pTrack = Instance.new("Frame")
		pTrack.Size = UDim2.new(1, -92, 0, 28)
		pTrack.Position = UDim2.new(0, 86, 1, -34)
		pTrack.BackgroundColor3 = Color3.fromRGB(48, 56, 44)
		pTrack.Parent = zCard
		makeCorner(pTrack, 6)
		makeStroke(pTrack, 2)

		local pFill = Instance.new("Frame")
		pFill.Size = UDim2.fromScale(math.clamp(zUnlocked / math.max(1, #pool), 0, 1), 1)
		pFill.BackgroundColor3 = Color3.fromRGB(118, 255, 42)
		pFill.BorderSizePixel = 0
		pFill.Parent = pTrack
		makeCorner(pFill, 6)

		makeOutlinedLabel(pTrack, string.format("%d/%d", zUnlocked, #pool), UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1), 2.2)
	end

	-- Populate Right Inspect Panel
	local selSpec = AnimalConfig.GetById(selectedIndexSpeciesId) or AnimalConfig.ALL[1]
	local selEntry = profile.discoveredIndex[selSpec.id]
	local previewHolder = Instance.new("Frame")
	previewHolder.Size = UDim2.fromOffset(118, 108)
	previewHolder.Position = UDim2.new(0.5, -59, 0, 12)
	previewHolder.BackgroundTransparency = 1
	previewHolder.Parent = inspectPanel
	makeAnimalIconFrame(previewHolder, selSpec.id, "None", selEntry == nil)

	makeOutlinedLabel(inspectPanel, if selEntry then selSpec.name else "??? (" .. selSpec.biomeId .. ")", UDim2.new(1, -12, 0, 32), UDim2.fromOffset(6, 124), Color3.new(1, 1, 1), 2.3)
	makeOutlinedLabel(inspectPanel, selSpec.rarity, UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 154), GameConfig.RARITY_COLORS[selSpec.rarity], 2.2)
	makeOutlinedLabel(inspectPanel, "$" .. FormatUtil.Number(selSpec.baseIncomePerSec) .. "/s", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 178), Color3.fromRGB(92, 248, 92), 2.4)

	local rewBox = Instance.new("Frame")
	rewBox.Size = UDim2.new(1, -16, 0, 134)
	rewBox.Position = UDim2.fromOffset(8, 214)
	rewBox.BackgroundColor3 = Color3.fromRGB(28, 36, 22)
	rewBox.Parent = inspectPanel
	makeCorner(rewBox, 8)
	makeStroke(rewBox, 2)

	makeOutlinedLabel(rewBox, "Rewards:", UDim2.new(1, -10, 0, 22), UDim2.fromOffset(6, 4), Color3.new(1, 1, 1), 1.8).TextXAlignment = Enum.TextXAlignment.Left
	local rewCoins = FormatUtil.Number(selSpec.baseIncomePerSec * 120)
	makeOutlinedLabel(rewBox, "💵 $" .. rewCoins, UDim2.new(1, -12, 0, 40), UDim2.fromOffset(6, 30), Color3.fromRGB(118, 255, 118), 2.2)

	local claimBtn = Instance.new("TextButton")
	claimBtn.Size = UDim2.new(1, -16, 0, 42)
	claimBtn.Position = UDim2.new(0, 8, 1, -48)
	claimBtn.BackgroundColor3 = if selEntry and not selEntry.rewardClaimed then Color3.fromRGB(72, 224, 52) else Color3.fromRGB(152, 158, 172)
	claimBtn.Text = if not selEntry then "Locked" elseif selEntry.rewardClaimed then "Claimed" else "Claim!"
	claimBtn.TextColor3 = Color3.new(1, 1, 1)
	claimBtn.Font = Enum.Font.FredokaOne
	claimBtn.TextScaled = true
	claimBtn.Parent = rewBox
	makeCorner(claimBtn, 8)
	makeStroke(claimBtn, 2.2)
	makeTextStroke(claimBtn, 2)
	claimBtn.MouseButton1Click:Connect(function()
		if selEntry and not selEntry.rewardClaimed then
			Remotes.Get("ClaimIndexReward"):FireServer(selSpec.id)
		end
	end)

	-- Bottom-Left Total Progress Bar + Claim All
	local totFill = Instance.new("Frame")
	totFill.Size = UDim2.fromScale(math.clamp(totalUnlocked / #AnimalConfig.ALL, 0, 1), 1)
	totFill.BackgroundColor3 = Color3.fromRGB(64, 178, 255)
	totFill.BorderSizePixel = 0
	totFill.Parent = totalIndexBar
	makeCorner(totFill, 8)

	makeOutlinedLabel(totalIndexBar, string.format("📖 Unlocked: %d/%d", totalUnlocked, #AnimalConfig.ALL), UDim2.new(0.68, 0, 1, 0), UDim2.fromOffset(10, 0), Color3.new(1, 1, 1), 2.4).TextXAlignment = Enum.TextXAlignment.Left

	local claimAllBtn = Instance.new("TextButton")
	claimAllBtn.Size = UDim2.fromOffset(118, 32)
	claimAllBtn.Position = UDim2.new(1, -124, 0, 6)
	claimAllBtn.BackgroundColor3 = Color3.fromRGB(244, 182, 42)
	claimAllBtn.Text = "Claim All"
	claimAllBtn.TextColor3 = Color3.new(1, 1, 1)
	claimAllBtn.Font = Enum.Font.FredokaOne
	claimAllBtn.TextScaled = true
	claimAllBtn.Parent = totalIndexBar
	makeCorner(claimAllBtn, 6)
	makeStroke(claimAllBtn, 2)
	makeTextStroke(claimAllBtn, 1.8)
	claimAllBtn.MouseButton1Click:Connect(function()
		Remotes.Get("ClaimAllIndexRewards"):FireServer()
	end)
end

-- C. ALL PETS INVENTORY WINDOW (Screenshot 9 — Above Bottom Hotbar)
local invWindow = Instance.new("Frame")
invWindow.Name = "InventoryModal"
invWindow.Size = UDim2.fromOffset(650, 310)
invWindow.Position = UDim2.new(0.5, -325, 1, -390)
invWindow.BackgroundColor3 = Color3.fromRGB(78, 96, 36)
invWindow.Visible = false
invWindow.Parent = gui
makeCorner(invWindow, 10)
makeStroke(invWindow, 3)

local sellToggleBtn = Instance.new("TextButton")
sellToggleBtn.Size = UDim2.fromOffset(112, 40)
sellToggleBtn.Position = UDim2.fromOffset(0, -48)
sellToggleBtn.BackgroundColor3 = Color3.fromRGB(218, 34, 34)
sellToggleBtn.Text = "🗑️ Sell"
sellToggleBtn.TextColor3 = Color3.new(1, 1, 1)
sellToggleBtn.Font = Enum.Font.FredokaOne
sellToggleBtn.TextScaled = true
sellToggleBtn.Parent = invWindow
makeCorner(sellToggleBtn, 8)
makeStroke(sellToggleBtn, 2.5)
makeTextStroke(sellToggleBtn, 2)

local invLeftTabs = Instance.new("Frame")
invLeftTabs.Size = UDim2.fromOffset(58, 250)
invLeftTabs.Position = UDim2.fromOffset(-64, 12)
invLeftTabs.BackgroundTransparency = 1
invLeftTabs.Parent = invWindow

local invTitleLbl = makeOutlinedLabel(invWindow, "All Pets", UDim2.fromOffset(140, 30), UDim2.fromOffset(12, 4), Color3.new(1, 1, 1), 2.5)
invTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
local invCountLbl = makeOutlinedLabel(invWindow, "Pets: 0/80", UDim2.fromOffset(140, 22), UDim2.fromOffset(12, 32), Color3.fromRGB(220, 232, 198), 2)
invCountLbl.TextXAlignment = Enum.TextXAlignment.Left

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.fromOffset(195, 32)
searchBox.Position = UDim2.new(1, -242, 0, 10)
searchBox.BackgroundColor3 = Color3.fromRGB(64, 72, 48)
searchBox.PlaceholderText = "Search"
searchBox.Text = ""
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.Font = Enum.Font.FredokaOne
searchBox.TextScaled = true
searchBox.Parent = invWindow
makeCorner(searchBox, 6)
makeStroke(searchBox, 2)

local invCloseBtn = Instance.new("TextButton")
invCloseBtn.Size = UDim2.fromOffset(32, 32)
invCloseBtn.Position = UDim2.new(1, -40, 0, 10)
invCloseBtn.BackgroundColor3 = Color3.fromRGB(224, 34, 34)
invCloseBtn.Text = "X"
invCloseBtn.TextColor3 = Color3.new(1, 1, 1)
invCloseBtn.Font = Enum.Font.FredokaOne
invCloseBtn.TextScaled = true
invCloseBtn.Parent = invWindow
makeCorner(invCloseBtn, 6)
makeStroke(invCloseBtn, 2)
invCloseBtn.MouseButton1Click:Connect(function() openModal(nil) end)

local invScroll = Instance.new("ScrollingFrame")
invScroll.Size = UDim2.new(1, -20, 1, -64)
invScroll.Position = UDim2.fromOffset(10, 56)
invScroll.BackgroundColor3 = Color3.fromRGB(48, 60, 22)
invScroll.ScrollBarThickness = 8
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.CanvasSize = UDim2.fromScale(0, 0)
invScroll.Parent = invWindow
makeCorner(invScroll, 8)
local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.fromOffset(96, 94)
invGrid.CellPadding = UDim2.fromOffset(6, 6)
invGrid.Parent = invScroll
local invPad = Instance.new("UIPadding")
invPad.PaddingTop = UDim.new(0, 6)
invPad.PaddingLeft = UDim.new(0, 6)
invPad.Parent = invScroll

local function renderInventoryModal()
	for _, ch in ipairs(invLeftTabs:GetChildren()) do ch:Destroy() end
	for _, ch in ipairs(invScroll:GetChildren()) do
		if not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end

	local catTabs = {
		{ id = "Pets", icon = "🐾", label = "Pets" },
		{ id = "Crates", icon = "📦", label = "Crates" },
		{ id = "Mounts", icon = "🚙", label = "Vehicles" },
		{ id = "Fuse", icon = "⚡", label = "Fuse" },
	}
	for i, ct in ipairs(catTabs) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(56, 56)
		b.Position = UDim2.fromOffset(0, (i - 1) * 62)
		b.BackgroundColor3 = if invLeftTab == ct.id then Color3.fromRGB(132, 168, 54) else Color3.fromRGB(168, 122, 62)
		b.Text = ct.icon .. "\n" .. ct.label
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.Parent = invLeftTabs
		makeCorner(b, 8)
		makeStroke(b, 2.5)
		makeTextStroke(b, 1.8)
		b.MouseButton1Click:Connect(function()
			invLeftTab = ct.id
			renderInventoryModal()
		end)
	end

	sellToggleBtn.Text = if sellModeActive then "🗑️ SELL: ON" else "🗑️ Sell"
	sellToggleBtn.BackgroundColor3 = if sellModeActive then Color3.fromRGB(255, 62, 62) else Color3.fromRGB(196, 36, 36)

	if not profile then return end

	if invLeftTab == "Pets" then
		local count = 0
		local q = string.lower(invSearchQuery)
		for uid, animal in pairs(profile.inventoryAnimals) do
			count += 1
			local spec = AnimalConfig.GetById(animal.speciesId)
			local nameStr = spec and spec.name or animal.speciesId
			if q == "" or string.find(string.lower(nameStr), q, 1, true) then
				local btn = Instance.new("TextButton")
				btn.BackgroundTransparency = 1
				btn.Text = ""
				btn.Parent = invScroll

				local box = makeAnimalIconFrame(btn, animal.speciesId, animal.mutation, false)
				makeOutlinedLabel(box, nameStr, UDim2.new(1, -6, 0, 18), UDim2.fromOffset(3, 52), Color3.fromRGB(122, 232, 255), 1.8)
				makeOutlinedLabel(box, string.format("(%.1fKG)", animal.weightKg), UDim2.new(1, -6, 0, 18), UDim2.fromOffset(3, 72), Color3.fromRGB(118, 255, 132), 1.8)

				if animal.locked then
					makeOutlinedLabel(box, "🔒", UDim2.fromOffset(20, 20), UDim2.fromOffset(2, 2), Color3.new(1, 1, 1), 1.5)
				end
				btn.MouseButton1Click:Connect(function()
					if sellModeActive then
						Remotes.Get("SellAnimal"):FireServer(uid)
					else
						Remotes.Get("EquipAnimalToPen"):FireServer(uid)
					end
				end)
			end
		end
		invTitleLbl.Text = if sellModeActive then "CLICK PET TO SELL" else "All Pets"
		invCountLbl.Text = string.format("Pets: %d/%d", count, GameConfig.PEN.MAX_INVENTORY_FREE)

	elseif invLeftTab == "Crates" then
		invTitleLbl.Text = "Pending Crates"
		local cnt = 0
		for uid, crate in pairs(profile.pendingCrates) do
			cnt += 1
			local rem = math.max(0, crate.unlockAt - os.time())
			local btn = Instance.new("TextButton")
			btn.BackgroundColor3 = GameConfig.RARITY_COLORS[crate.rarity] or Color3.fromRGB(120, 130, 140)
			btn.Text = string.format("📦 %s\n%s", crate.rarity, if rem > 0 then FormatUtil.Time(rem) else "OPEN!")
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.FredokaOne
			btn.TextScaled = true
			btn.Parent = invScroll
			makeCorner(btn, 8)
			makeStroke(btn, 2)
			makeTextStroke(btn, 1.8)
			btn.MouseButton1Click:Connect(function()
				Remotes.Get("OpenPendingCrate"):FireServer(uid)
			end)
		end
		invCountLbl.Text = "Crates: " .. cnt

	elseif invLeftTab == "Mounts" then
		invTitleLbl.Text = "Vehicles"
		for _, v in ipairs(VehicleConfig) do
			local owned = profile.ownedVehicles[v.id] == true
			local eq = profile.equippedVehicle == v.id
			local btn = Instance.new("TextButton")
			btn.BackgroundColor3 = if eq then Color3.fromRGB(72, 206, 88) elseif owned then Color3.fromRGB(64, 142, 212) else Color3.fromRGB(58, 62, 74)
			btn.Text = string.format("🚙 %s\n%s", v.name, if eq then "EQUIPPED" elseif owned then "EQUIP" else "$" .. FormatUtil.Number(v.cost))
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.FredokaOne
			btn.TextScaled = true
			btn.Parent = invScroll
			makeCorner(btn, 8)
			makeStroke(btn, 2)
			makeTextStroke(btn, 1.8)
			btn.MouseButton1Click:Connect(function()
				if owned then Remotes.Get("EquipVehicle"):FireServer(v.id)
				else Remotes.Get("BuyVehicle"):FireServer(v.id) end
			end)
		end

	elseif invLeftTab == "Fuse" then
		invTitleLbl.Text = "Fuse (" .. #selectedFuseUids .. "/3)"
		local fuseBtn = Instance.new("TextButton")
		fuseBtn.BackgroundColor3 = Color3.fromRGB(178, 86, 255)
		fuseBtn.Text = "⚡ MERGE\n(" .. #selectedFuseUids .. "/3)"
		fuseBtn.TextColor3 = Color3.new(1, 1, 1)
		fuseBtn.Font = Enum.Font.FredokaOne
		fuseBtn.TextScaled = true
		fuseBtn.Parent = invScroll
		makeCorner(fuseBtn, 8)
		makeStroke(fuseBtn, 2)
		makeTextStroke(fuseBtn, 1.8)
		fuseBtn.MouseButton1Click:Connect(function()
			if #selectedFuseUids == 3 then
				Remotes.Get("RequestMergeAnimals"):FireServer(selectedFuseUids)
				table.clear(selectedFuseUids)
			end
		end)
		for uid, a in pairs(profile.inventoryAnimals) do
			local spec = AnimalConfig.GetById(a.speciesId)
			local isSel = table.find(selectedFuseUids, uid) ~= nil
			local btn = Instance.new("TextButton")
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.Parent = invScroll
			local box = makeAnimalIconFrame(btn, a.speciesId, a.mutation, false)
			if isSel then makeStroke(box, 3, Color3.fromRGB(84, 255, 112)) end
			makeOutlinedLabel(box, (spec and spec.name or a.speciesId), UDim2.new(1, -6, 0, 18), UDim2.fromOffset(3, 52), Color3.new(1, 1, 1), 1.8)
			makeOutlinedLabel(box, if isSel then "SELECTED" else a.mutation, UDim2.new(1, -6, 0, 18), UDim2.fromOffset(3, 72), Color3.fromRGB(255, 224, 92), 1.8)
			btn.MouseButton1Click:Connect(function()
				local idx = table.find(selectedFuseUids, uid)
				if idx then table.remove(selectedFuseUids, idx)
				elseif #selectedFuseUids < 3 then table.insert(selectedFuseUids, uid) end
				renderInventoryModal()
			end)
		end
	end
end

sellToggleBtn.MouseButton1Click:Connect(function()
	sellModeActive = not sellModeActive
	renderInventoryModal()
end)
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	invSearchQuery = searchBox.Text
	if currentModal == "Inventory" then
		renderInventoryModal()
	end
end)

-- D. SETTINGS MODAL (Screenshot 10 — Silver Header + Sliders + Switches)
local settingsWindow = Instance.new("Frame")
settingsWindow.Name = "SettingsModal"
settingsWindow.Size = UDim2.fromOffset(540, 365)
settingsWindow.Position = UDim2.new(0.5, -270, 0.5, -182)
settingsWindow.BackgroundColor3 = Color3.fromRGB(36, 38, 44)
settingsWindow.Visible = false
settingsWindow.Parent = gui
makeCorner(settingsWindow, 12)
makeStroke(settingsWindow, 3)

makeWindowHeader(settingsWindow, "Settings", Color3.fromRGB(236, 240, 246), Color3.fromRGB(132, 138, 152), function()
	openModal(nil)
end)

local settingsBody = Instance.new("Frame")
settingsBody.Size = UDim2.new(1, -24, 1, -64)
settingsBody.Position = UDim2.fromOffset(12, 54)
settingsBody.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
settingsBody.Parent = settingsWindow
makeCorner(settingsBody, 8)
local sbLayout = Instance.new("UIListLayout")
sbLayout.Padding = UDim.new(0, 8)
sbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sbLayout.Parent = settingsBody
local sbPad = Instance.new("UIPadding")
sbPad.PaddingTop = UDim.new(0, 8)
sbPad.Parent = settingsBody

local function renderSettingsModal()
	for _, ch in ipairs(settingsBody:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	if not profile then return end
	local s = profile.settings

	local function addSliderRow(titleStr: string, subStr: string, currentVal: number, onCommit: (number) -> ())
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.96, 0, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
		row.Parent = settingsBody
		makeCorner(row, 6)
		makeStroke(row, 2)

		makeOutlinedLabel(row, titleStr, UDim2.fromOffset(180, 26), UDim2.fromOffset(10, 4), Color3.new(1, 1, 1), 2.2).TextXAlignment = Enum.TextXAlignment.Left
		makeOutlinedLabel(row, subStr, UDim2.fromOffset(180, 16), UDim2.fromOffset(10, 30), Color3.fromRGB(210, 215, 224), 1.6).TextXAlignment = Enum.TextXAlignment.Left

		local track = Instance.new("TextButton")
		track.Size = UDim2.new(0.52, 0, 0, 18)
		track.Position = UDim2.new(0.45, 0, 0.5, -9)
		track.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
		track.Text = ""
		track.Parent = row
		makeCorner(track, 4)
		makeStroke(track, 2)

		local thumb = Instance.new("Frame")
		thumb.Size = UDim2.fromOffset(22, 24)
		thumb.Position = UDim2.new(math.clamp(currentVal, 0, 1), -11, 0.5, -12)
		thumb.BackgroundColor3 = Color3.fromRGB(248, 204, 34)
		thumb.Parent = track
		makeCorner(thumb, 4)
		makeStroke(thumb, 2)

		local function applyFromX(mouseX: number)
			local absPos = track.AbsolutePosition.X
			local absSize = math.max(1, track.AbsoluteSize.X)
			local ratio = math.clamp((mouseX - absPos) / absSize, 0, 1)
			thumb.Position = UDim2.new(ratio, -11, 0.5, -12)
			onCommit(math.floor(ratio * 100 + 0.5) / 100)
		end

		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				applyFromX(inp.Position.X)
			end
		end)
	end

	local function addSwitchRow(titleStr: string, isOn: boolean, onToggle: () -> ())
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.96, 0, 0, 50)
		row.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
		row.Parent = settingsBody
		makeCorner(row, 6)
		makeStroke(row, 2)

		makeOutlinedLabel(row, titleStr, UDim2.new(0.62, 0, 0.72, 0), UDim2.new(0, 12, 0.14, 0), Color3.new(1, 1, 1), 2.3).TextXAlignment = Enum.TextXAlignment.Left

		makeOutlinedLabel(row, if isOn then "ON" else "OFF", UDim2.fromOffset(52, 28), UDim2.new(0.64, 0, 0.5, -14), Color3.new(1, 1, 1), 2)

		local track = Instance.new("TextButton")
		track.Size = UDim2.fromOffset(74, 30)
		track.Position = UDim2.new(1, -86, 0.5, -15)
		track.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
		track.Text = ""
		track.Parent = row
		makeCorner(track, 6)
		makeStroke(track, 2)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(26, 22)
		knob.Position = if isOn then UDim2.fromOffset(44, 4) else UDim2.fromOffset(4, 4)
		knob.BackgroundColor3 = if isOn then Color3.fromRGB(78, 232, 72) else Color3.fromRGB(218, 46, 46)
		knob.Parent = track
		makeCorner(knob, 4)
		makeStroke(knob, 2)

		track.MouseButton1Click:Connect(onToggle)
	end

	addSliderRow("Music", "Background Music!", if s.musicEnabled then s.musicVolume else 0, function(val)
		Remotes.Get("UpdateSettings"):FireServer({ musicEnabled = val > 0.02, musicVolume = val })
	end)
	addSliderRow("SFX", "Sfx Volume!", if s.sfxEnabled then s.sfxVolume else 0, function(val)
		Remotes.Get("UpdateSettings"):FireServer({ sfxEnabled = val > 0.02, sfxVolume = val })
	end)
	addSwitchRow("View others Pets", not s.hideOtherAnimals, function()
		Remotes.Get("UpdateSettings"):FireServer({ hideOtherAnimals = not s.hideOtherAnimals })
	end)
	addSwitchRow("View my Pets", not s.hideOwnAnimals, function()
		Remotes.Get("UpdateSettings"):FireServer({ hideOwnAnimals = not s.hideOwnAnimals })
	end)
	addSwitchRow("View my Crates", viewCratesEnabled, function()
		viewCratesEnabled = not viewCratesEnabled
		Remotes.Get("UpdateSettings"):FireServer({ lowVFX = not viewCratesEnabled })
		renderSettingsModal()
	end)
end

-- Master Modal Switcher
renderActiveModal = function()
	shopWindow.Visible = (currentModal == "Shop")
	indexWindow.Visible = (currentModal == "Index")
	invWindow.Visible = (currentModal == "Inventory")
	settingsWindow.Visible = (currentModal == "Settings")

	if currentModal == "Shop" then renderShopModal()
	elseif currentModal == "Index" then renderIndexModal()
	elseif currentModal == "Inventory" then renderInventoryModal()
	elseif currentModal == "Settings" then renderSettingsModal() end
end

-- Bind Buttons & Hotbar Slots
shopBtn.MouseButton1Click:Connect(function() openModal("Shop") end)
indexBtn.MouseButton1Click:Connect(function() openModal("Index") end)
settingsGearBtn.MouseButton1Click:Connect(function() openModal("Settings") end)
speedIconBtn.MouseButton1Click:Connect(function()
	shopSubTab = "Trails"
	openModal("Shop")
end)

makeHotbarSlot("1", "🪢", "Lasso", function()
	shopSubTab = "Lassos"
	openModal("Shop")
end)
makeHotbarSlot("2", "🐾", "Pets", function()
	invLeftTab = "Pets"
	openModal("Inventory")
end)
makeHotbarSlot("3", "🚙", "Vehicle", function()
	localPlayer:SetAttribute("ToggleVehicleRequest", not (localPlayer:GetAttribute("ToggleVehicleRequest") == true))
end)

-- Keyboard shortcuts for hotbar 2 (Inventory)
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.Two then
		invLeftTab = "Pets"
		openModal("Inventory")
	end
end)

-- Open matching modal when Hub ProximityPrompts trigger
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= localPlayer then return end
	if prompt.Name == "LassoShopPrompt" then
		shopSubTab = "Lassos"; currentModal = "Shop"; renderActiveModal()
	elseif prompt.Name == "TrailShopPrompt" then
		shopSubTab = "Trails"; currentModal = "Shop"; renderActiveModal()
	elseif prompt.Name == "VehicleShopPrompt" then
		shopSubTab = "Vehicles"; currentModal = "Shop"; renderActiveModal()
	elseif prompt.Name == "FusePrompt" then
		shopSubTab = "Fuse"; currentModal = "Shop"; renderActiveModal()
	elseif prompt.Name == "RebirthPrompt" then
		shopSubTab = "Rebirth"; currentModal = "Shop"; renderActiveModal()
	elseif prompt.Name == "IndexPrompt" then
		currentModal = "Index"; renderActiveModal()
	end
end)

-- ============================================================================
-- 7. REMOTES & REALTIME TELEMETRY LOOP
-- ============================================================================
Remotes.Get("ProfileSync").OnClientEvent:Connect(function(newProfile)
	if type(newProfile) ~= "table" then return end
	if profile and newProfile.speedStat > lastSpeedStat then
		lastStepGain = newProfile.speedStat - lastSpeedStat
		stepPopLbl.Text = "👟 +" .. FormatUtil.Number(lastStepGain) .. "/Step"
	end
	lastSpeedStat = newProfile.speedStat
	profile = newProfile

	-- Trail Speed Multiplier
	local trailMult = 1.0
	for _, t in ipairs(TrailConfig) do
		if t.id == newProfile.equippedTrail then trailMult = t.speedMultiplier break end
	end
	local penIncome = 0
	for _, uid in ipairs(newProfile.roamingAnimalUids) do
		local a = newProfile.inventoryAnimals[uid]
		if a then penIncome += AnimalConfig.ComputeIncomePerSec(a) end
	end

	speedValLbl.Text = FormatUtil.Number(newProfile.speedStat)
	speedMultLbl.Text = "(x" .. FormatUtil.Number(trailMult) .. ")"
	cashValLbl.Text = "$" .. FormatUtil.Number(newProfile.coins)
	cashRateLbl.Text = "+$" .. FormatUtil.Number(penIncome) .. "/s"

	renderRightDrawer()
	if currentModal then renderActiveModal() end
end)

Remotes.Get("TrainingPulse").OnClientEvent:Connect(function(gain)
	if type(gain) == "number" then
		stepPopLbl.Text = "👟 +" .. FormatUtil.Number(gain) .. "/Step"
	end
end)

Remotes.Get("NotifyClient").OnClientEvent:Connect(function(msg, color)
	toastLbl.Text = tostring(msg)
	toastLbl.TextColor3 = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1)
	toastLbl.Visible = true
	task.delay(3.5, function()
		if toastLbl.Text == tostring(msg) then toastLbl.Visible = false end
	end)
end)

Remotes.Get("GlobalEventBanner").OnClientEvent:Connect(function(msg, color, duration)
	eventBanner.Text = tostring(msg)
	eventBanner.TextColor3 = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 214, 64)
	eventBanner.Visible = true
	task.delay(tonumber(duration) or 8, function()
		if eventBanner.Text == tostring(msg) then eventBanner.Visible = false end
	end)
end)

-- Biome Entry Detection + Event Countdown Ticker
local checkAccum = 0
RunService.Heartbeat:Connect(function(dt: number)
	checkAccum += dt
	if checkAccum < 0.35 then return end
	checkAccum = 0

	local rem = nextMythicWaveAt - os.time()
	if rem <= 0 then
		nextMythicWaveAt = os.time() + 600
		rem = 600
	end
	local mins = math.floor(rem / 60)
	local secs = rem % 60
	timerLbl.Text = string.format("In: %02d:%02d", mins, secs)

	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local z = root.Position.Z
		local foundBiome = nil
		for _, b in ipairs(BiomeConfig) do
			if z >= b.zStart and z <= b.zEnd then
				foundBiome = b
				break
			end
		end
		if foundBiome then
			biomeBanner.Visible = true
			biomeTitleLbl.Text = foundBiome.name .. " 🌲"
			biomeTitleLbl.TextColor3 = foundBiome.accentColor:Lerp(Color3.new(1, 1, 1), 0.35)
			biomeRecLbl.Text = "Recommended: 👟 " .. FormatUtil.Number(foundBiome.recommendedSpeed) .. " Speed"
		else
			biomeBanner.Visible = false
		end
	end
end)
