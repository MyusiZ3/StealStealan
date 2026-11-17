--!strict
-- MainHUD.client.luau
-- Complete Simulator HUD & Modal Suite styled to match reference screenshots:
-- Left Stack (Shop, Index, Slow Mode), Floating Bottom-Left Speed/Cash, Right Collapsible Active/Crates Drawer + Equip Best,
-- Bottom 3-Slot Hotbar, Top-Right Biome Recommended Banner, Bottom-Right Event Countdown,
-- Shop Modal (Featured + Passes + 10 Lassos + 10 Trails + 6 Vehicles + Fuse + Rebirth),
-- Index Modal (5 Zones, 63 Animals, Right External Tabs, Right Inspect Panel, Total Unlocked Bar),
-- All Pets Inventory Modal (Sell Toggle, Search, 6-Col Grid, Left External Tabs), & Settings Modal (Sliders + Switches).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
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
local SoundConfig = require(ReplicatedStorage.Config.SoundConfig)
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local AnimalVisualBuilder = require(ReplicatedStorage.Modules.AnimalVisualBuilder)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Disable Roblox's built-in CoreGui Backpack so Backquote (`) and the 1-0 hotbar exclusively use MainHUD
local function disableCoreBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end
disableCoreBackpack()
task.delay(0.5, disableCoreBackpack)

local function playClickSFX()
	local s = Instance.new("Sound")
	s.SoundId = SoundConfig.SFX.ButtonClick
	local sfxGroup = SoundService:FindFirstChild(SoundConfig.GROUPS.SFX)
	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		s.SoundGroup = sfxGroup
	end
	s.Volume = 0.65
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local profile: Types.PlayerProfileSchema? = nil
local currentModal: string? = nil -- "Shop" | "Trails" | "Lassos" | "Vehicles" | "Fuse" | "Rebirth" | "Index" | "Settings" | "Inventory"
local indexRightTab = "Normal" -- "Normal" | "Limited" | "Mutations"
local selectedIndexSpeciesId = AnimalConfig.ALL[1].id
local invLeftTab = "Pets" -- "Pets" | "Crates" | "Mounts" | "Fuse"
local sellModeActive = false
local invSearchQuery = ""
local selectedFuseUids: { string } = {}
local fuseSlotUids: { [number]: string? } = {}
local fusePickerSlot: number? = nil
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

local function setViewportThumbnail(holder: Instance, modelBuilder: () -> Model?)
	for _, ch in ipairs(holder:GetChildren()) do
		ch:Destroy()
	end
	if holder:IsA("GuiObject") then
		holder.Interactable = false
	end
	local m = modelBuilder()
	if not m then
		return
	end
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Interactable = false
	vp.Ambient = Color3.fromRGB(190, 200, 215)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.ZIndex = if holder:IsA("GuiObject") then holder.ZIndex + 1 else 2
	vp.Parent = holder

	local wm = Instance.new("WorldModel")
	wm.Parent = vp

	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() - cf.Position)
	m.Parent = wm

	local maxDim = math.max(size.X, size.Y, size.Z, 1.0)
	local dist = maxDim * 1.42
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.58, dist * 0.36, -dist * 0.92), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
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
		then rarityCol:Lerp(Color3.fromRGB(16, 18, 22), 0.55)
		elseif mutation and mutation ~= "None" then mutInfo.color
		else rarityCol

	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = cardBg
	box.Parent = parent
	makeCorner(box, 8)
	makeStroke(box, 2)
	makeGradient(box, cardBg:Lerp(Color3.new(1, 1, 1), if locked then 0.08 else 0.25), cardBg:Lerp(Color3.new(0, 0, 0), 0.25))

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
-- 1. NATIVE-STYLE TOPBAR CONTROLS (Beside Mic: Backpack & Settings, Image 2)
-- ============================================================================
local topBarGui = Instance.new("ScreenGui")
topBarGui.Name = "TopBarControlsGui"
topBarGui.ResetOnSpawn = false
topBarGui.IgnoreGuiInset = true
topBarGui.ScreenInsets = Enum.ScreenInsets.None
topBarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
topBarGui.DisplayOrder = 5
topBarGui.Parent = playerGui

local topBarPillRow = Instance.new("Frame")
topBarPillRow.Name = "TopBarCustomButtons"
topBarPillRow.Size = UDim2.fromOffset(96, 44)
topBarPillRow.Position = UDim2.fromOffset(196, 12)
topBarPillRow.BackgroundTransparency = 1
topBarPillRow.Parent = topBarGui

local function makeTopBarCircleButton(name: string, xPos: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromOffset(44, 44)
	btn.Position = UDim2.fromOffset(xPos, 0)
	btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	btn.BackgroundTransparency = 0.30
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = topBarPillRow
	makeCorner(btn, 22)
	local ring = makeStroke(btn, 1.4, Color3.new(1, 1, 1))
	ring.Transparency = 0.85

	btn.MouseEnter:Connect(function()
		btn.BackgroundTransparency = 0.16
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundTransparency = 0.30
	end)
	return btn
end

local backpackTopBtn = makeTopBarCircleButton("TopBarBackpackButton", 0)
-- Monochrome White Outline Backpack Glyph matching native Roblox TopBar icons
do
	local handle = Instance.new("Frame")
	handle.Size = UDim2.fromOffset(10, 6)
	handle.Position = UDim2.fromOffset(17, 10)
	handle.BackgroundTransparency = 1
	handle.Parent = backpackTopBtn
	makeCorner(handle, 3)
	makeStroke(handle, 2, Color3.new(1, 1, 1))

	local packBody = Instance.new("Frame")
	packBody.Size = UDim2.fromOffset(18, 20)
	packBody.Position = UDim2.fromOffset(13, 14)
	packBody.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	packBody.BackgroundTransparency = 0.55
	packBody.Parent = backpackTopBtn
	makeCorner(packBody, 5)
	makeStroke(packBody, 2, Color3.new(1, 1, 1))

	local pocket = Instance.new("Frame")
	pocket.Size = UDim2.fromOffset(12, 8)
	pocket.Position = UDim2.fromOffset(3, 9)
	pocket.BackgroundTransparency = 1
	pocket.Parent = packBody
	makeCorner(pocket, 3)
	makeStroke(pocket, 1.8, Color3.new(1, 1, 1))
end

local settingsTopBtn = makeTopBarCircleButton("TopBarSettingsButton", 52)
settingsTopBtn.Text = "⚙️"
settingsTopBtn.TextColor3 = Color3.fromRGB(238, 244, 255)
settingsTopBtn.TextSize = 22

local function syncTopBarRowPosition()
	local ti = GuiService.TopbarInset
	local minX = if ti and ti.Min.X >= 100 then math.round(ti.Min.X + 8) else 196
	local barH = if ti and ti.Height >= 44 then ti.Height else 58
	local topY = math.max(8, math.round((barH - 44) * 0.5))
	topBarPillRow.Position = UDim2.fromOffset(minX, topY)
end
syncTopBarRowPosition()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(syncTopBarRowPosition)

local topLeftRow = Instance.new("Frame")
topLeftRow.Name = "TopLeftActions"
topLeftRow.Size = UDim2.fromOffset(120, 36)
topLeftRow.Position = UDim2.new(0, 12, 0, 8)
topLeftRow.BackgroundTransparency = 1
topLeftRow.Parent = gui

local inviteFriendsBtn = Instance.new("TextButton")
inviteFriendsBtn.Name = "InviteFriendsButton"
inviteFriendsBtn.Size = UDim2.fromOffset(112, 34)
inviteFriendsBtn.Position = UDim2.fromOffset(0, 1)
inviteFriendsBtn.BackgroundColor3 = Color3.fromRGB(72, 152, 248)
inviteFriendsBtn.Text = "👥 +10% Boost"
inviteFriendsBtn.TextColor3 = Color3.new(1, 1, 1)
inviteFriendsBtn.Font = Enum.Font.FredokaOne
inviteFriendsBtn.TextScaled = true
inviteFriendsBtn.Parent = topLeftRow
makeCorner(inviteFriendsBtn, 10)
makeStroke(inviteFriendsBtn, 2.5)
makeTextStroke(inviteFriendsBtn, 2)
makeGradient(inviteFriendsBtn, Color3.fromRGB(102, 186, 255), Color3.fromRGB(48, 114, 218))
inviteFriendsBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	pcall(function()
		SocialService:PromptGameInvite(localPlayer)
	end)
end)

-- Top-Center Biome Entry Banner (leaves Top-Right free for Roblox leaderstats PlayerList!)
local biomeBanner = Instance.new("Frame")
biomeBanner.Name = "BiomeBanner"
biomeBanner.AnchorPoint = Vector2.new(0.5, 0)
biomeBanner.Size = UDim2.fromOffset(400, 58)
biomeBanner.Position = UDim2.new(0.5, 0, 0, 8)
biomeBanner.BackgroundTransparency = 1
biomeBanner.Visible = false
biomeBanner.Parent = gui

local biomeTitleLbl = makeOutlinedLabel(biomeBanner, "Pine Woods 😠", UDim2.new(1, 0, 0.56, 0), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), 2.8)
biomeTitleLbl.TextXAlignment = Enum.TextXAlignment.Center
local biomeRecLbl = makeOutlinedLabel(biomeBanner, "Recommended: 👟 50 Speed", UDim2.new(1, 0, 0.42, 0), UDim2.new(0, 0, 0.56, 0), Color3.new(1, 1, 1), 2.4)
biomeRecLbl.RichText = true
biomeRecLbl.TextXAlignment = Enum.TextXAlignment.Center

local BIOME_BANNER_DISPLAY: { [string]: { title: string, emoji: string } } = {
	PineWoods = { title = "Pine Woods Zone", emoji = "😠" },
	MangroveSwamp = { title = "Swamp Zone", emoji = "😢" },
	SavannaCamp = { title = "Savanna Zone", emoji = "😰" },
	AlpinePeaks = { title = "Alpine Zone", emoji = "😡" },
	VolcanicJungle = { title = "Volcanic Zone", emoji = "😈" },
}

-- Center Top Global Event Banner & Notification Toast
local eventBanner = Instance.new("TextLabel")
eventBanner.Name = "GlobalEventBanner"
eventBanner.AnchorPoint = Vector2.new(0.5, 0)
eventBanner.Size = UDim2.fromOffset(560, 34)
eventBanner.Position = UDim2.new(0.5, 0, 0, 70)
eventBanner.BackgroundColor3 = Color3.fromRGB(34, 24, 52)
eventBanner.TextColor3 = Color3.fromRGB(255, 214, 64)
eventBanner.Font = Enum.Font.FredokaOne
eventBanner.TextScaled = true
eventBanner.Visible = false
eventBanner.Parent = gui
makeCorner(eventBanner, 10)
local eventBannerStroke = makeStroke(eventBanner, 2.5, Color3.fromRGB(255, 214, 64))
makeTextStroke(eventBanner, 2.2)

local crateAnnounceLbl = makeOutlinedLabel(gui, "", UDim2.fromOffset(660, 32), UDim2.new(0.5, 0, 0, 72), Color3.fromRGB(255, 224, 92), 2.8)
crateAnnounceLbl.Name = "CrateSpawnBanner"
crateAnnounceLbl.AnchorPoint = Vector2.new(0.5, 0)
crateAnnounceLbl.ZIndex = 19
crateAnnounceLbl.Visible = false
local crateAnnounceStroke = crateAnnounceLbl:FindFirstChildOfClass("UIStroke")

local toastLbl = Instance.new("TextLabel")
toastLbl.Name = "ToastLabel"
toastLbl.AnchorPoint = Vector2.new(0.5, 0)
toastLbl.Size = UDim2.fromOffset(460, 30)
toastLbl.Position = UDim2.new(0.5, 0, 0, 108)
toastLbl.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
toastLbl.BackgroundTransparency = 0.2
toastLbl.TextColor3 = Color3.new(1, 1, 1)
toastLbl.Font = Enum.Font.FredokaOne
toastLbl.TextScaled = true
toastLbl.Visible = false
toastLbl.Parent = gui
makeCorner(toastLbl, 8)
makeTextStroke(toastLbl, 2)

-- Danger Red Edge Vignette & Bold "RUN!" Chase Banner (shown while carrying crates / hunted by Poachers)
local runVignette = Instance.new("Frame")
runVignette.Name = "RunDangerVignette"
runVignette.Size = UDim2.fromScale(1, 1)
runVignette.BackgroundTransparency = 1
runVignette.ZIndex = 1
runVignette.Visible = false
runVignette.Parent = gui

local runEdgeStrips: { { bar: Frame, grad: UIGradient } } = {}
local edgeDefs = {
	{ size = UDim2.new(1, 0, 0.16, 0), pos = UDim2.fromScale(0, 0), rot = 90 },
	{ size = UDim2.new(1, 0, 0.16, 0), pos = UDim2.fromScale(0, 0.84), rot = 270 },
	{ size = UDim2.new(0.11, 0, 1, 0), pos = UDim2.fromScale(0, 0), rot = 0 },
	{ size = UDim2.new(0.11, 0, 1, 0), pos = UDim2.fromScale(0.89, 0), rot = 180 },
}
for idx, ed in ipairs(edgeDefs) do
	local bar = Instance.new("Frame")
	bar.Name = "RunEdge_" .. idx
	bar.Size = ed.size
	bar.Position = ed.pos
	bar.BackgroundColor3 = Color3.fromRGB(255, 22, 36)
	bar.BorderSizePixel = 0
	bar.ZIndex = 1
	bar.Parent = runVignette
	local gr = Instance.new("UIGradient")
	gr.Rotation = ed.rot
	gr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.65, 0.72),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	gr.Parent = bar
	table.insert(runEdgeStrips, { bar = bar, grad = gr })
end

local runAlertBanner = Instance.new("TextLabel")
runAlertBanner.Name = "RunAlertBanner"
runAlertBanner.AnchorPoint = Vector2.new(0.5, 0)
runAlertBanner.Size = UDim2.fromOffset(220, 56)
runAlertBanner.Position = UDim2.new(0.5, 0, 0, 68)
runAlertBanner.BackgroundColor3 = Color3.fromRGB(64, 66, 82)
runAlertBanner.Text = "RUN!"
runAlertBanner.TextColor3 = Color3.new(1, 1, 1)
runAlertBanner.Font = Enum.Font.FredokaOne
runAlertBanner.TextScaled = true
runAlertBanner.ZIndex = 20
runAlertBanner.Visible = false
runAlertBanner.Parent = gui
makeCorner(runAlertBanner, 10)
makeStroke(runAlertBanner, 3.5, Color3.fromRGB(255, 42, 54))
makeTextStroke(runAlertBanner, 3.0)
local isPoacherChasing = false

local rescueSuccessLbl = makeOutlinedLabel(gui, "", UDim2.fromOffset(580, 48), UDim2.new(0.5, 0, 0, 96), Color3.fromRGB(118, 255, 148), 3.4)
rescueSuccessLbl.Name = "RescueSuccessLabel"
rescueSuccessLbl.AnchorPoint = Vector2.new(0.5, 0)
rescueSuccessLbl.ZIndex = 22
rescueSuccessLbl.Visible = false

-- ============================================================================
-- 2. LEFT STACK: REBIRTH + SHOP + INDEX + SLOW MODE
-- ============================================================================
local leftStack = Instance.new("Frame")
leftStack.Name = "LeftActionStack"
leftStack.AnchorPoint = Vector2.new(0, 0.5)
leftStack.Size = UDim2.fromOffset(166, 192)
leftStack.Position = UDim2.new(0, 12, 0.45, 0)
leftStack.BackgroundTransparency = 1
leftStack.Parent = gui

local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthButton"
rebirthBtn.Size = UDim2.fromOffset(124, 38)
rebirthBtn.Position = UDim2.fromOffset(0, 0)
rebirthBtn.BackgroundColor3 = Color3.new(1, 1, 1)
rebirthBtn.Text = ""
rebirthBtn.Parent = leftStack
makeCorner(rebirthBtn, 8)
makeStroke(rebirthBtn, 2.8)
makeGradient(rebirthBtn, Color3.fromRGB(255, 118, 212), Color3.fromRGB(198, 36, 132))

-- Steal & Ride a Pet inspired circular Rebirth Emblem + Label
local rebIconRing = Instance.new("Frame")
rebIconRing.Size = UDim2.fromOffset(28, 28)
rebIconRing.Position = UDim2.fromOffset(6, 5)
rebIconRing.BackgroundColor3 = Color3.fromRGB(255, 224, 62)
rebIconRing.Parent = rebirthBtn
makeCorner(rebIconRing, 14)
makeStroke(rebIconRing, 2, Color3.fromRGB(28, 14, 24))
local rebArrows = makeOutlinedLabel(rebIconRing, "♻️", UDim2.fromScale(0.95, 0.95), UDim2.fromScale(0.025, 0.025), Color3.new(1, 1, 1), 1.4)
rebArrows.TextScaled = true

local rebText = makeOutlinedLabel(rebirthBtn, "Rebirth", UDim2.new(1, -38, 1, -4), UDim2.fromOffset(35, 2), Color3.new(1, 1, 1), 2.4)
rebText.TextXAlignment = Enum.TextXAlignment.Center

local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopButton"
shopBtn.Size = UDim2.fromOffset(124, 40)
shopBtn.Position = UDim2.fromOffset(0, 50)
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
shopBadge.Size = UDim2.fromOffset(20, 20)
shopBadge.Position = UDim2.new(1, -10, 0, -7)
shopBadge.BackgroundColor3 = Color3.fromRGB(224, 38, 38)
shopBadge.Text = "!"
shopBadge.TextColor3 = Color3.new(1, 1, 1)
shopBadge.Font = Enum.Font.FredokaOne
shopBadge.TextScaled = true
shopBadge.Parent = shopBtn
makeCorner(shopBadge, 10)
makeStroke(shopBadge, 2)

local indexBtn = Instance.new("TextButton")
indexBtn.Name = "IndexButton"
indexBtn.Size = UDim2.fromOffset(124, 40)
indexBtn.Position = UDim2.fromOffset(0, 102)
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
slowSwitchTrack.Size = UDim2.fromOffset(64, 28)
slowSwitchTrack.Position = UDim2.fromOffset(0, 156)
slowSwitchTrack.BackgroundColor3 = Color3.fromRGB(56, 72, 22)
slowSwitchTrack.Text = ""
slowSwitchTrack.Parent = leftStack
makeCorner(slowSwitchTrack, 6)
makeStroke(slowSwitchTrack, 2.5)

local slowKnob = Instance.new("Frame")
slowKnob.Size = UDim2.fromOffset(22, 20)
slowKnob.Position = UDim2.fromOffset(4, 4)
slowKnob.BackgroundColor3 = Color3.fromRGB(218, 46, 46)
slowKnob.Parent = slowSwitchTrack
makeCorner(slowKnob, 4)
makeStroke(slowKnob, 2)

local slowText = makeOutlinedLabel(leftStack, "Slow Mode", UDim2.fromOffset(88, 24), UDim2.fromOffset(72, 158), Color3.new(1, 1, 1), 2.1)
slowText.TextXAlignment = Enum.TextXAlignment.Left

local function updateSlowModeVisual(on: boolean)
	slowKnob.Position = if on then UDim2.fromOffset(38, 4) else UDim2.fromOffset(4, 4)
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
-- 3. BOTTOM-LEFT FLOATING SPEED & CASH DISPLAY (No Box, Screenshot 3 Layout)
-- ============================================================================
local statsCorner = Instance.new("Frame")
statsCorner.Name = "BottomLeftStats"
statsCorner.AnchorPoint = Vector2.new(0, 1)
statsCorner.Size = UDim2.fromOffset(0, 76)
statsCorner.AutomaticSize = Enum.AutomaticSize.X
statsCorner.Position = UDim2.new(0, 12, 1, -10)
statsCorner.BackgroundTransparency = 1
statsCorner.Parent = gui

local speedRow = Instance.new("Frame")
speedRow.Name = "SpeedRow"
speedRow.Size = UDim2.fromOffset(0, 36)
speedRow.AutomaticSize = Enum.AutomaticSize.X
speedRow.Position = UDim2.fromOffset(0, 0)
speedRow.BackgroundTransparency = 1
speedRow.Parent = statsCorner
local speedRowLayout = Instance.new("UIListLayout")
speedRowLayout.FillDirection = Enum.FillDirection.Horizontal
speedRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
speedRowLayout.Padding = UDim.new(0, 6)
speedRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
speedRowLayout.Parent = speedRow

local speedIconBtn = Instance.new("TextButton")
speedIconBtn.LayoutOrder = 1
speedIconBtn.Size = UDim2.fromOffset(34, 34)
speedIconBtn.BackgroundTransparency = 1
speedIconBtn.Text = "👟"
speedIconBtn.TextScaled = true
speedIconBtn.Parent = speedRow
local speedPlus = Instance.new("TextLabel")
speedPlus.Size = UDim2.fromOffset(14, 14)
speedPlus.Position = UDim2.fromOffset(20, 18)
speedPlus.BackgroundColor3 = Color3.fromRGB(255, 214, 48)
speedPlus.Text = "+"
speedPlus.TextColor3 = Color3.fromRGB(16, 18, 22)
speedPlus.Font = Enum.Font.FredokaOne
speedPlus.TextScaled = true
speedPlus.ZIndex = 2
speedPlus.Parent = speedIconBtn
makeCorner(speedPlus, 4)
makeStroke(speedPlus, 1.8)

local speedValLbl = makeOutlinedLabel(speedRow, "0", UDim2.fromOffset(0, 34), UDim2.fromOffset(0, 0), Color3.fromRGB(98, 108, 255), 3.0)
speedValLbl.LayoutOrder = 2
speedValLbl.AutomaticSize = Enum.AutomaticSize.X
speedValLbl.TextScaled = false
speedValLbl.TextSize = 26
speedValLbl.TextXAlignment = Enum.TextXAlignment.Left

local speedMultLbl = makeOutlinedLabel(speedRow, "(x1.25)", UDim2.fromOffset(0, 32), UDim2.fromOffset(0, 0), Color3.fromRGB(76, 248, 86), 2.8)
speedMultLbl.LayoutOrder = 3
speedMultLbl.AutomaticSize = Enum.AutomaticSize.X
speedMultLbl.TextScaled = false
speedMultLbl.TextSize = 24
speedMultLbl.TextXAlignment = Enum.TextXAlignment.Left

local cashRow = Instance.new("Frame")
cashRow.Name = "CashRow"
cashRow.Size = UDim2.fromOffset(0, 36)
cashRow.AutomaticSize = Enum.AutomaticSize.X
cashRow.Position = UDim2.fromOffset(0, 38)
cashRow.BackgroundTransparency = 1
cashRow.Parent = statsCorner
local cashRowLayout = Instance.new("UIListLayout")
cashRowLayout.FillDirection = Enum.FillDirection.Horizontal
cashRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
cashRowLayout.Padding = UDim.new(0, 6)
cashRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
cashRowLayout.Parent = cashRow

local cashIconLbl = makeOutlinedLabel(cashRow, "💵", UDim2.fromOffset(34, 34), UDim2.fromOffset(0, 0), Color3.new(1, 1, 1), 1.5)
cashIconLbl.LayoutOrder = 1
cashIconLbl.BackgroundTransparency = 1

local cashValLbl = makeOutlinedLabel(cashRow, "$150", UDim2.fromOffset(0, 36), UDim2.fromOffset(0, 0), Color3.fromRGB(76, 248, 86), 3.0)
cashValLbl.LayoutOrder = 2
cashValLbl.AutomaticSize = Enum.AutomaticSize.X
cashValLbl.TextScaled = false
cashValLbl.TextSize = 27
cashValLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================================
-- 4. RIGHT EDGE TOGGLES + COLLAPSIBLE DRAWER (Active Pets & Pending Crates)
-- ============================================================================
local rightEdgeBtns = Instance.new("Frame")
rightEdgeBtns.Name = "RightEdgeToggles"
rightEdgeBtns.AnchorPoint = Vector2.new(1, 0.5)
rightEdgeBtns.Size = UDim2.fromOffset(46, 100)
rightEdgeBtns.Position = UDim2.new(1, -10, 0.45, 0)
rightEdgeBtns.BackgroundTransparency = 1
rightEdgeBtns.Parent = gui

local cratesEdgeBtn = Instance.new("TextButton")
cratesEdgeBtn.Size = UDim2.fromOffset(44, 44)
cratesEdgeBtn.Position = UDim2.fromOffset(1, 0)
cratesEdgeBtn.BackgroundColor3 = Color3.fromRGB(208, 48, 40)
cratesEdgeBtn.Text = "📦"
cratesEdgeBtn.TextScaled = true
cratesEdgeBtn.Parent = rightEdgeBtns
makeCorner(cratesEdgeBtn, 8)
makeStroke(cratesEdgeBtn, 2.5)

local petsEdgeBtn = Instance.new("TextButton")
petsEdgeBtn.Size = UDim2.fromOffset(44, 44)
petsEdgeBtn.Position = UDim2.fromOffset(1, 52)
petsEdgeBtn.BackgroundColor3 = Color3.fromRGB(196, 130, 58)
petsEdgeBtn.Text = "🐾"
petsEdgeBtn.TextScaled = true
petsEdgeBtn.Parent = rightEdgeBtns
makeCorner(petsEdgeBtn, 8)
makeStroke(petsEdgeBtn, 2.5)

local rightDrawerWrap = Instance.new("Frame")
rightDrawerWrap.Name = "RightSideDrawer"
rightDrawerWrap.AnchorPoint = Vector2.new(1, 0.5)
rightDrawerWrap.Size = UDim2.fromOffset(256, 264)
rightDrawerWrap.Position = UDim2.new(1, -62, 0.45, 0)
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
-- 5. BOTTOM-CENTER 10-SLOT FROSTED HOTBAR (1-2 GEAR + 3-0 DRAG & DROP SLOTS, Image 1)
-- ============================================================================
type HotbarSlotItem = { kind: "Crate" | "Pet", uid: string }
type DragPayload = {
	kind: "Crate" | "Pet",
	uid: string,
	fromSlot: number?,
	label: string,
	builder: (() -> Model?)?,
	onClick: () -> (),
}

local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 10

local selectedHotbarSlot = 0 -- 0 = empty hands, 1 = Lasso, 2 = Vehicle, 3..10 = Crates / Pets
local selectedCustomCrateUid: string? = nil
local hotbarItems: { [number]: HotbarSlotItem } = {}
local customHotbarPins: { [number]: HotbarSlotItem } = {}
local hotbarPinsInitialized = false
local knownPinUids: { [string]: boolean } = {}
local lastMountThumbKey = ""

local bottomCenterHud = Instance.new("Frame")
bottomCenterHud.Name = "BottomCenterHUD"
bottomCenterHud.AnchorPoint = Vector2.new(0.5, 1)
bottomCenterHud.Size = UDim2.fromOffset(704, 122)
bottomCenterHud.Position = UDim2.new(0.5, 0, 1, -8)
bottomCenterHud.BackgroundTransparency = 1
bottomCenterHud.Parent = gui

local mountActionBtn = Instance.new("TextButton")
mountActionBtn.Name = "MountActionButton"
mountActionBtn.AnchorPoint = Vector2.new(0.5, 0)
mountActionBtn.Size = UDim2.fromOffset(220, 44)
mountActionBtn.Position = UDim2.new(0.5, 0, 0, 0)
mountActionBtn.BackgroundColor3 = Color3.new(1, 1, 1)
mountActionBtn.Text = ""
mountActionBtn.ZIndex = 10
mountActionBtn.Parent = bottomCenterHud
makeCorner(mountActionBtn, 10)
makeStroke(mountActionBtn, 3)
local mountBtnGrad = makeGradient(mountActionBtn, Color3.fromRGB(132, 255, 42), Color3.fromRGB(64, 198, 18))

local mountIconHolder = Instance.new("Frame")
mountIconHolder.Name = "MountIconHolder"
mountIconHolder.Size = UDim2.fromOffset(38, 38)
mountIconHolder.Position = UDim2.fromOffset(10, 3)
mountIconHolder.BackgroundTransparency = 1
mountIconHolder.ZIndex = 11
mountIconHolder.Parent = mountActionBtn

local mountIconLbl = Instance.new("TextLabel")
mountIconLbl.Size = UDim2.fromScale(1, 1)
mountIconLbl.BackgroundTransparency = 1
mountIconLbl.Text = ""
mountIconLbl.TextScaled = true
mountIconLbl.ZIndex = 11
mountIconLbl.Parent = mountIconHolder

local mountTextLbl = makeOutlinedLabel(mountActionBtn, "Ride", UDim2.new(1, -56, 1, -8), UDim2.fromOffset(52, 4), Color3.new(1, 1, 1), 2.8)
mountTextLbl.TextXAlignment = Enum.TextXAlignment.Center
mountTextLbl.ZIndex = 11

local dropCrateBtn = Instance.new("TextButton")
dropCrateBtn.Name = "DropCrateButton"
dropCrateBtn.AnchorPoint = Vector2.new(0.5, 0)
dropCrateBtn.Size = UDim2.fromOffset(170, 42)
dropCrateBtn.Position = UDim2.new(0.5, 0, 0, 1)
dropCrateBtn.BackgroundColor3 = Color3.new(1, 1, 1)
dropCrateBtn.Text = ""
dropCrateBtn.ZIndex = 10
dropCrateBtn.Visible = false
dropCrateBtn.Parent = bottomCenterHud
makeCorner(dropCrateBtn, 10)
makeStroke(dropCrateBtn, 3)
makeGradient(dropCrateBtn, Color3.fromRGB(94, 98, 118), Color3.fromRGB(58, 60, 76))
makeOutlinedLabel(dropCrateBtn, "Drop", UDim2.new(1, -12, 1, -6), UDim2.fromOffset(6, 3), Color3.new(1, 1, 1), 2.6).ZIndex = 11
dropCrateBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	Remotes.Get("DropCarriedCrate"):FireServer()
end)

local hotbar = Instance.new("Frame")
hotbar.Name = "BottomHotbar"
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Size = UDim2.fromOffset(704, 66)
hotbar.Position = UDim2.new(0.5, 0, 1, 0)
hotbar.BackgroundTransparency = 1
hotbar.Parent = bottomCenterHud

local hbLayout = Instance.new("UIListLayout")
hbLayout.FillDirection = Enum.FillDirection.Horizontal
hbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hbLayout.Padding = UDim.new(0, 6)
hbLayout.SortOrder = Enum.SortOrder.LayoutOrder
hbLayout.Parent = hotbar

local refreshMountButton: () -> ()
local renderHotbar: () -> ()
local openModal: (string?) -> ()
local invWindowRef: Frame? = nil
local invScrollRef: ScrollingFrame? = nil
local renderInventoryModalRef: (() -> ())? = nil

local function findVehicleDefById(id: string): Types.VehicleDefinition
	for _, v in ipairs(VehicleConfig) do
		if v.id == id then return v end
	end
	return VehicleConfig[1]
end

local function findLassoDefById(id: string): Types.LassoDefinition
	for _, l in ipairs(LassoConfig) do
		if l.id == id then return l end
	end
	return LassoConfig[1]
end

local function syncHeldItemFromHotbar()
	local hType = ""
	local hId = ""
	local hSpecies = ""
	local hMutation = ""
	local hBiome = ""
	local hRarity = ""
	local hScale = 1

	if selectedCustomCrateUid and profile and type(profile.crateInventory) == "table" then
		local invC = profile.crateInventory[selectedCustomCrateUid]
		if invC then
			hType = "Crate"
			hId = invC.uid
			hBiome = invC.biomeId
			hRarity = invC.rarity
			hScale = invC.sizeScale or 1
		else
			selectedCustomCrateUid = nil
		end
	elseif selectedHotbarSlot == 1 and profile then
		hType = "Lasso"
		hId = profile.equippedLasso
	elseif selectedHotbarSlot == 2 and profile then
		hType = "Vehicle"
		hId = profile.equippedVehicle
	elseif selectedHotbarSlot >= CUSTOM_SLOT_MIN and selectedHotbarSlot <= CUSTOM_SLOT_MAX and profile then
		local entry = hotbarItems[selectedHotbarSlot]
		if entry and entry.kind == "Crate" and type(profile.crateInventory) == "table" then
			local crate = profile.crateInventory[entry.uid]
			if crate then
				hType = "Crate"
				hId = crate.uid
				hBiome = crate.biomeId
				hRarity = crate.rarity
				hScale = crate.sizeScale or 1
			end
		elseif entry and entry.kind == "Pet" then
			local animal = profile.inventoryAnimals[entry.uid]
			if animal then
				hType = "Pet"
				hId = entry.uid
				hSpecies = animal.speciesId
				hMutation = animal.mutation
			end
		end
	end

	localPlayer:SetAttribute("HeldItemType", hType)
	localPlayer:SetAttribute("HeldItemId", hId)
	localPlayer:SetAttribute("HeldItemSpecies", hSpecies)
	localPlayer:SetAttribute("HeldItemMutation", hMutation)
	localPlayer:SetAttribute("HeldItemBiome", hBiome)
	localPlayer:SetAttribute("HeldItemRarity", hRarity)
	localPlayer:SetAttribute("HeldItemScale", hScale)
	Remotes.Get("SetHeldItem"):FireServer(hType, hId)
end

refreshMountButton = function()
	local isVeh = localPlayer:GetAttribute("IsRidingVehicle") == true
	local activeMountUid = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "")
	local show = false
	local thumbKey = ""
	local labelTxt = "Ride"
	local isDismount = false

	if isVeh then
		show = true
		local vId = if profile then profile.equippedVehicle else "StarterATV"
		thumbKey = "Veh:" .. vId
		labelTxt = "Dismount"
		isDismount = true
	elseif activeMountUid ~= "" then
		show = true
		local sId = tostring(localPlayer:GetAttribute("MountedAnimalId") or "RustyFox")
		local mut = tostring(localPlayer:GetAttribute("MountedAnimalMutation") or "None")
		thumbKey = "Pet:" .. sId .. ":" .. mut
		labelTxt = "Get Off"
		isDismount = true
	elseif selectedHotbarSlot == 2 then
		show = true
		local vId = if profile then profile.equippedVehicle else "StarterATV"
		thumbKey = "Veh:" .. vId
		labelTxt = "Ride"
	elseif selectedHotbarSlot >= CUSTOM_SLOT_MIN and selectedHotbarSlot <= CUSTOM_SLOT_MAX then
		local entry = hotbarItems[selectedHotbarSlot]
		local animal = if entry and entry.kind == "Pet" and profile then profile.inventoryAnimals[entry.uid] else nil
		if entry and animal then
			show = true
			thumbKey = "Pet:" .. animal.speciesId .. ":" .. animal.mutation
			labelTxt = "Mount"
		end
	end

	local carryingCount = tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0
	local hideForInventory = (currentModal == "Inventory")
	local showDrop = carryingCount > 0 and not hideForInventory
	dropCrateBtn.Visible = showDrop

	mountActionBtn.Visible = show and not hideForInventory
	mountTextLbl.Text = labelTxt
	if show and showDrop then
		mountActionBtn.Size = UDim2.fromOffset(180, 42)
		mountActionBtn.Position = UDim2.new(0.5, -96, 0, 1)
		dropCrateBtn.Size = UDim2.fromOffset(156, 42)
		dropCrateBtn.Position = UDim2.new(0.5, 92, 0, 1)
	elseif show then
		mountActionBtn.Size = UDim2.fromOffset(220, 44)
		mountActionBtn.Position = UDim2.new(0.5, 0, 0, 0)
	elseif showDrop then
		dropCrateBtn.Size = UDim2.fromOffset(186, 42)
		dropCrateBtn.Position = UDim2.new(0.5, 0, 0, 1)
	end
	if show and thumbKey ~= lastMountThumbKey then
		lastMountThumbKey = thumbKey
		mountIconLbl.Visible = false
		if string.sub(thumbKey, 1, 4) == "Veh:" then
			local vDef = findVehicleDefById(string.sub(thumbKey, 5))
			setViewportThumbnail(mountIconHolder, function()
				return AnimalVisualBuilder.BuildVehicleModel(vDef, 1.0)
			end)
		elseif string.sub(thumbKey, 1, 4) == "Pet:" then
			local parts = string.split(thumbKey, ":")
			local sId = parts[2] or "RustyFox"
			local mut = (parts[3] or "None") :: Types.AnimalMutation
			setViewportThumbnail(mountIconHolder, function()
				return AnimalVisualBuilder.BuildAnimalModel(sId, 1.0, mut, true)
			end)
		end
	end
	if isDismount then
		mountBtnGrad.Color = ColorSequence.new(Color3.fromRGB(255, 112, 68), Color3.fromRGB(204, 46, 34))
	else
		mountBtnGrad.Color = ColorSequence.new(Color3.fromRGB(132, 255, 42), Color3.fromRGB(64, 198, 18))
	end
end

mountActionBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	local isVeh = localPlayer:GetAttribute("IsRidingVehicle") == true
	local activeMountUid = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "")
	if isVeh then
		localPlayer:SetAttribute("ToggleVehicleRequest", not (localPlayer:GetAttribute("ToggleVehicleRequest") == true))
	elseif activeMountUid ~= "" then
		Remotes.Get("MountAnimal"):FireServer("")
	elseif selectedHotbarSlot == 2 then
		localPlayer:SetAttribute("ToggleVehicleRequest", not (localPlayer:GetAttribute("ToggleVehicleRequest") == true))
	elseif selectedHotbarSlot >= CUSTOM_SLOT_MIN and selectedHotbarSlot <= CUSTOM_SLOT_MAX then
		local entry = hotbarItems[selectedHotbarSlot]
		if entry and entry.kind == "Pet" then
			Remotes.Get("MountAnimal"):FireServer(entry.uid)
		end
	end
end)

local function refreshHotbarSelectionVisuals(dragHoverSlot: number?)
	for _, ch in ipairs(hotbar:GetChildren()) do
		if ch:IsA("TextButton") then
			local idx = ch.LayoutOrder
			local isSel = (idx == selectedHotbarSlot)
			local isHover = (dragHoverSlot ~= nil and idx == dragHoverSlot)
			ch.BackgroundColor3 = if isHover then Color3.fromRGB(62, 74, 92) elseif isSel then Color3.fromRGB(48, 56, 68) else Color3.fromRGB(16, 18, 22)
			ch.BackgroundTransparency = if isSel or isHover then 0.12 else 0.28
			local st = ch:FindFirstChild("SlotStroke")
			if st and st:IsA("UIStroke") then
				st.Thickness = if isHover then 2.8 elseif isSel then 2.5 else 1.5
				st.Color = if isHover then Color3.fromRGB(128, 255, 96) elseif isSel then Color3.new(1, 1, 1) else Color3.fromRGB(0, 0, 0)
				st.Transparency = if isSel or isHover then 0 else 0.35
			end
		end
	end
end

local function selectHotbarSlot(idx: number)
	selectedCustomCrateUid = nil
	if selectedHotbarSlot == idx then
		selectedHotbarSlot = 0
	else
		selectedHotbarSlot = idx
	end
	refreshHotbarSelectionVisuals()
	syncHeldItemFromHotbar()
	refreshMountButton()
end

-- Unified Drag-and-Drop Controller between Backpack & Hotbar Slots (3..10)
local activeDragPress: {
	payload: DragPayload,
	startPos: Vector2,
	dragging: boolean,
}? = nil
local dragGhostFrame: Frame? = nil

local function destroyDragGhost()
	if dragGhostFrame then
		dragGhostFrame:Destroy()
		dragGhostFrame = nil
	end
	refreshHotbarSelectionVisuals()
end

local function toHudSpacePos(screenPos: Vector2): Vector2
	local insetTopLeft, _ = GuiService:GetGuiInset()
	return Vector2.new(screenPos.X - insetTopLeft.X, screenPos.Y - insetTopLeft.Y)
end

local function isPointInGuiObject(hudPt: Vector2, obj: GuiObject): boolean
	local pos = obj.AbsolutePosition
	local sz = obj.AbsoluteSize
	return hudPt.X >= pos.X and hudPt.X <= pos.X + sz.X and hudPt.Y >= pos.Y and hudPt.Y <= pos.Y + sz.Y
end

local function findHoveredCustomHotbarSlot(screenPos: Vector2): number?
	local hudPt = toHudSpacePos(screenPos)
	for _, ch in ipairs(hotbar:GetChildren()) do
		if ch:IsA("TextButton") and ch.LayoutOrder >= CUSTOM_SLOT_MIN and ch.LayoutOrder <= CUSTOM_SLOT_MAX then
			if isPointInGuiObject(hudPt, ch) then
				return ch.LayoutOrder
			end
		end
	end
	return nil
end

local function attachDragAndDrop(btn: TextButton, payload: DragPayload)
	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			local loc = UserInputService:GetMouseLocation()
			activeDragPress = {
				payload = payload,
				startPos = loc,
				dragging = false,
			}
			if not payload.fromSlot and invScrollRef then
				invScrollRef.ScrollingEnabled = false
			end
		end
	end)
end

UserInputService.InputChanged:Connect(function(inp)
	if not activeDragPress then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local loc = UserInputService:GetMouseLocation()
	if not activeDragPress.dragging then
		if (loc - activeDragPress.startPos).Magnitude >= 8 then
			activeDragPress.dragging = true
			local gf = Instance.new("Frame")
			gf.Name = "BackpackDragGhost"
			gf.AnchorPoint = Vector2.new(0.5, 0.5)
			gf.Size = UDim2.fromOffset(62, 62)
			gf.Position = UDim2.fromOffset(loc.X, loc.Y)
			gf.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
			gf.BackgroundTransparency = 0.2
			gf.ZIndex = 40
			gf.Parent = topBarGui
			makeCorner(gf, 8)
			makeStroke(gf, 2.2, Color3.new(1, 1, 1))
			local vpHolder = Instance.new("Frame")
			vpHolder.Size = UDim2.new(1, -10, 1, -20)
			vpHolder.Position = UDim2.fromOffset(5, 4)
			vpHolder.BackgroundTransparency = 1
			vpHolder.ZIndex = 41
			vpHolder.Parent = gf
			if activeDragPress.payload.builder then
				setViewportThumbnail(vpHolder, activeDragPress.payload.builder)
			end
			makeOutlinedLabel(gf, activeDragPress.payload.label, UDim2.new(1, -6, 0, 16), UDim2.new(0, 3, 1, -17), Color3.new(1, 1, 1), 1.6).ZIndex = 42
			dragGhostFrame = gf
		end
	end
	if activeDragPress.dragging and dragGhostFrame then
		dragGhostFrame.Position = UDim2.fromOffset(loc.X, loc.Y)
		local hoverSlot = findHoveredCustomHotbarSlot(loc)
		refreshHotbarSelectionVisuals(hoverSlot)
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	if not activeDragPress then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local state = activeDragPress
	activeDragPress = nil
	if invScrollRef then
		invScrollRef.ScrollingEnabled = true
	end
	local loc = UserInputService:GetMouseLocation()

	if not state.dragging then
		destroyDragGhost()
		playClickSFX()
		state.payload.onClick()
		return
	end

	local targetSlot = findHoveredCustomHotbarSlot(loc)
	local pld = state.payload
	if targetSlot then
		if pld.fromSlot then
			-- Swap two Hotbar slots cleanly
			local prevTarget = customHotbarPins[targetSlot]
			customHotbarPins[targetSlot] = { kind = pld.kind, uid = pld.uid }
			if prevTarget then
				customHotbarPins[pld.fromSlot] = prevTarget
			else
				customHotbarPins[pld.fromSlot] = nil
			end
			if selectedHotbarSlot == pld.fromSlot then
				selectedHotbarSlot = targetSlot
			end
		else
			-- Dragged from Backpack into specific Hotbar slot
			for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
				if customHotbarPins[s] and customHotbarPins[s].uid == pld.uid then
					customHotbarPins[s] = nil
				end
			end
			customHotbarPins[targetSlot] = { kind = pld.kind, uid = pld.uid }
			selectedCustomCrateUid = nil
			selectedHotbarSlot = targetSlot
		end
		playClickSFX()
		renderHotbar()
		refreshMountButton()
		if renderInventoryModalRef and currentModal == "Inventory" then
			renderInventoryModalRef()
		end
	elseif pld.fromSlot then
		-- Dragged from Hotbar back out (unslot back into Backpack)
		local hudPt = toHudSpacePos(loc)
		local inInv = invWindowRef and invWindowRef.Visible and isPointInGuiObject(hudPt, invWindowRef)
		if inInv or currentModal == "Inventory" then
			customHotbarPins[pld.fromSlot] = nil
			if selectedHotbarSlot == pld.fromSlot then
				selectedHotbarSlot = 0
			end
			playClickSFX()
			renderHotbar()
			refreshMountButton()
			if renderInventoryModalRef and currentModal == "Inventory" then
				renderInventoryModalRef()
			end
		end
	end
	destroyDragGhost()
end)

local function isItemPinnedInHotbar(uid: string): number?
	for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
		local item = customHotbarPins[s]
		if item and item.uid == uid then
			return s
		end
	end
	return nil
end

local function assignOrSelectItemInHotbar(kind: "Crate" | "Pet", uid: string)
	local pinnedSlot = isItemPinnedInHotbar(uid)
	if not pinnedSlot then
		local openSlot: number? = nil
		for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
			if not customHotbarPins[s] then
				openSlot = s
				break
			end
		end
		pinnedSlot = openSlot or CUSTOM_SLOT_MAX
		customHotbarPins[pinnedSlot :: number] = { kind = kind, uid = uid }
		renderHotbar()
	end
	selectedCustomCrateUid = nil
	if selectedHotbarSlot == pinnedSlot then
		selectedHotbarSlot = 0
	else
		selectedHotbarSlot = pinnedSlot :: number
	end
	refreshHotbarSelectionVisuals()
	syncHeldItemFromHotbar()
	refreshMountButton()
end

local function createHotbarSlot(slotIndex: number, modelBuilder: (() -> Model?)?, fallbackIcon: string, label: string, _isLocked: boolean, isSelected: boolean, _borderCol: Color3?, onClick: () -> ()): TextButton
	local slot = Instance.new("TextButton")
	slot.Name = "Slot_" .. tostring(slotIndex)
	slot.LayoutOrder = slotIndex
	slot.Size = UDim2.fromOffset(64, 64)
	slot.BackgroundColor3 = if isSelected then Color3.fromRGB(48, 56, 68) else Color3.fromRGB(16, 18, 22)
	slot.BackgroundTransparency = if isSelected then 0.12 else 0.28
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = hotbar
	makeCorner(slot, 8)
	local slotStroke = makeStroke(slot, if isSelected then 2.5 else 1.5, if isSelected then Color3.new(1, 1, 1) else Color3.fromRGB(0, 0, 0))
	slotStroke.Transparency = if isSelected then 0 else 0.35
	slotStroke.Name = "SlotStroke"

	local keyTxt = if slotIndex == 10 then "0" else tostring(slotIndex)
	local k = makeOutlinedLabel(slot, keyTxt, UDim2.fromOffset(16, 16), UDim2.fromOffset(5, 2), Color3.new(1, 1, 1), 1.6)
	k.TextXAlignment = Enum.TextXAlignment.Left
	k.ZIndex = 3

	local thumbBox = Instance.new("Frame")
	thumbBox.Size = UDim2.fromOffset(48, 42)
	thumbBox.Position = UDim2.fromOffset(8, 6)
	thumbBox.BackgroundTransparency = 1
	thumbBox.Interactable = false
	thumbBox.ZIndex = 2
	thumbBox.Parent = slot

	if modelBuilder then
		setViewportThumbnail(thumbBox, modelBuilder)
	elseif fallbackIcon ~= "" then
		local ic = Instance.new("TextLabel")
		ic.Size = UDim2.fromScale(1, 1)
		ic.BackgroundTransparency = 1
		ic.Text = fallbackIcon
		ic.TextScaled = true
		ic.Interactable = false
		ic.ZIndex = 2
		ic.Parent = thumbBox
	end

	if label ~= "" then
		local nmLbl = makeOutlinedLabel(slot, label, UDim2.new(1, -4, 0, 15), UDim2.new(0, 2, 1, -16), Color3.new(1, 1, 1), 1.6)
		nmLbl.Interactable = false
		nmLbl.ZIndex = 3
	end

	if slotIndex < CUSTOM_SLOT_MIN then
		slot.MouseButton1Click:Connect(function()
			playClickSFX()
			onClick()
		end)
	end
	return slot
end

local function reconcileHotbarPins()
	if not profile then
		table.clear(customHotbarPins)
		return
	end

	-- Prune stale or duplicated pins
	local seen: { [string]: boolean } = {}
	for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
		local item = customHotbarPins[s]
		if item then
			local exists = if item.kind == "Crate"
				then (type(profile.crateInventory) == "table" and profile.crateInventory[item.uid] ~= nil)
				else (profile.inventoryAnimals[item.uid] ~= nil)
			if not exists or seen[item.uid] then
				customHotbarPins[s] = nil
			else
				seen[item.uid] = true
			end
		end
	end

	local candidateList: { HotbarSlotItem } = {}
	if type(profile.crateInventory) == "table" then
		local invCrates: { Types.InventoryCrate } = {}
		for _, c in pairs(profile.crateInventory) do
			table.insert(invCrates, c)
		end
		table.sort(invCrates, function(a, b) return (a.acquiredAt or 0) > (b.acquiredAt or 0) end)
		for _, c in ipairs(invCrates) do
			table.insert(candidateList, { kind = "Crate", uid = c.uid })
		end
	end
	local petList: { { uid: string, income: number } } = {}
	for uid, a in pairs(profile.inventoryAnimals) do
		table.insert(petList, { uid = uid, income = AnimalConfig.ComputeIncomePerSec(a) })
	end
	table.sort(petList, function(a, b) return a.income > b.income end)
	for _, p in ipairs(petList) do
		table.insert(candidateList, { kind = "Pet", uid = p.uid })
	end

	if not hotbarPinsInitialized then
		hotbarPinsInitialized = true
		for _, cand in ipairs(candidateList) do
			knownPinUids[cand.uid] = true
			if not seen[cand.uid] then
				for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
					if not customHotbarPins[s] then
						customHotbarPins[s] = cand
						seen[cand.uid] = true
						break
					end
				end
			end
		end
	else
		-- Auto-slot newly acquired items cleanly into open hotbar slots without overwriting user's layout
		for _, cand in ipairs(candidateList) do
			if not knownPinUids[cand.uid] then
				knownPinUids[cand.uid] = true
				if not seen[cand.uid] then
					for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
						if not customHotbarPins[s] then
							customHotbarPins[s] = cand
							seen[cand.uid] = true
							break
						end
					end
				end
			end
		end
	end
end

local renderedHotbarKeys: { [number]: string } = {}

local function upsertHotbarSlot(slotIndex: number, renderKey: string, factoryFn: () -> TextButton)
	local existing = hotbar:FindFirstChild("Slot_" .. tostring(slotIndex))
	if existing and renderedHotbarKeys[slotIndex] == renderKey then
		return
	end
	if existing then
		existing:Destroy()
	end
	renderedHotbarKeys[slotIndex] = renderKey
	factoryFn()
end

renderHotbar = function()
	table.clear(hotbarItems)
	reconcileHotbarPins()

	-- Slot 1: Equipped Lasso (only rebuild if equippedLasso changes -> zero blink!)
	local lassoId = if profile then profile.equippedLasso else "RopeLasso"
	local lassoDef = findLassoDefById(lassoId)
	local lassoName = string.gsub(lassoDef.name, " Lasso", "")
	upsertHotbarSlot(1, "Lasso:" .. lassoId, function()
		return createHotbarSlot(1, function()
			return AnimalVisualBuilder.BuildLassoModel(lassoDef.beamColor, 1.15)
		end, "🤠", lassoName, true, selectedHotbarSlot == 1, nil, function()
			selectHotbarSlot(1)
		end)
	end)

	-- Slot 2: Equipped Vehicle (only rebuild if equippedVehicle changes -> zero blink!)
	local vehId = if profile then profile.equippedVehicle else "StarterATV"
	local vehDef = findVehicleDefById(vehId)
	local vehName = string.gsub(vehDef.name, "Starter ", "")
	upsertHotbarSlot(2, "Veh:" .. vehId, function()
		return createHotbarSlot(2, function()
			return AnimalVisualBuilder.BuildVehicleModel(vehDef, 1.0)
		end, "🚙", vehName, true, selectedHotbarSlot == 2, nil, function()
			selectHotbarSlot(2)
		end)
	end)

	-- Slots 3..10 (Displayed 3..9, 0): Drag-and-Drop Customizable Slots!
	for slotIdx = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
		local entry = customHotbarPins[slotIdx]
		if entry and profile then
			if entry.kind == "Crate" and type(profile.crateInventory) == "table" and profile.crateInventory[entry.uid] then
				local c = profile.crateInventory[entry.uid]
				local sp = AnimalConfig.GetById(c.speciesId)
				local varIdx = if sp then ((sp.indexNumber % 3) + 1) else 1
				local cTitle = AnimalVisualBuilder.GetCrateVariantInfo(c.biomeId, c.rarity, varIdx)
				hotbarItems[slotIdx] = entry
				upsertHotbarSlot(slotIdx, "Crate:" .. entry.uid, function()
					local builderFn = function()
						return AnimalVisualBuilder.BuildCrateModel(c.rarity, c.biomeId, 1.0, {
							isBuried = false, canCollide = false, showBeacon = false, variant = varIdx,
						})
					end
					local slotBtn = createHotbarSlot(slotIdx, builderFn, "📦", cTitle, false, selectedHotbarSlot == slotIdx, nil, function()
						selectHotbarSlot(slotIdx)
					end)
					attachDragAndDrop(slotBtn, {
						kind = "Crate",
						uid = entry.uid,
						fromSlot = slotIdx,
						label = cTitle,
						builder = builderFn,
						onClick = function() selectHotbarSlot(slotIdx) end,
					})
					return slotBtn
				end)
			elseif entry.kind == "Pet" and profile.inventoryAnimals[entry.uid] then
				local a = profile.inventoryAnimals[entry.uid]
				local sp = AnimalConfig.GetById(a.speciesId)
				local pName = sp and sp.name or a.speciesId
				hotbarItems[slotIdx] = entry
				upsertHotbarSlot(slotIdx, "Pet:" .. entry.uid .. ":" .. tostring(a.mutation), function()
					local builderFn = function()
						return AnimalVisualBuilder.BuildAnimalModel(a.speciesId, 1.0, a.mutation, true)
					end
					local slotBtn = createHotbarSlot(slotIdx, builderFn, "🐾", pName, false, selectedHotbarSlot == slotIdx, nil, function()
						selectHotbarSlot(slotIdx)
					end)
					attachDragAndDrop(slotBtn, {
						kind = "Pet",
						uid = entry.uid,
						fromSlot = slotIdx,
						label = pName,
						builder = builderFn,
						onClick = function() selectHotbarSlot(slotIdx) end,
					})
					return slotBtn
				end)
			else
				upsertHotbarSlot(slotIdx, "Empty", function()
					local es = createHotbarSlot(slotIdx, nil, "", "", false, selectedHotbarSlot == slotIdx, nil, function()
						selectHotbarSlot(slotIdx)
					end)
					es.MouseButton1Click:Connect(function()
						playClickSFX()
						selectHotbarSlot(slotIdx)
					end)
					return es
				end)
			end
		else
			upsertHotbarSlot(slotIdx, "Empty", function()
				local es = createHotbarSlot(slotIdx, nil, "", "", false, selectedHotbarSlot == slotIdx, nil, function()
					selectHotbarSlot(slotIdx)
				end)
				es.MouseButton1Click:Connect(function()
					playClickSFX()
					selectHotbarSlot(slotIdx)
				end)
				return es
			end)
		end
	end
	refreshHotbarSelectionVisuals()
	syncHeldItemFromHotbar()
end

local eventTimerBox = Instance.new("Frame")
eventTimerBox.Name = "BottomRightTimer"
eventTimerBox.AnchorPoint = Vector2.new(1, 1)
eventTimerBox.Size = UDim2.fromOffset(164, 40)
eventTimerBox.Position = UDim2.new(1, -12, 1, -10)
eventTimerBox.BackgroundTransparency = 1
eventTimerBox.Parent = gui
makeOutlinedLabel(eventTimerBox, "❄️", UDim2.fromOffset(36, 36), UDim2.fromOffset(0, 2), Color3.fromRGB(142, 234, 255), 2)
local timerLbl = makeOutlinedLabel(eventTimerBox, "In: 10:00", UDim2.fromOffset(122, 34), UDim2.fromOffset(40, 3), Color3.new(1, 1, 1), 2.5)
timerLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ============================================================================
-- 6. DEDICATED MODALS: SHOP | TRAILS | LASSOS | VEHICLES | FUSE | REBIRTH | INDEX | INVENTORY | SETTINGS
-- ============================================================================
local renderActiveModal: () -> ()
local lastAutoZoneModal: string? = nil
local dismissedStandZoneModal: string? = nil

openModal = function(name: string?, fromStandZone: boolean?)
	if name == nil and not fromStandZone and lastAutoZoneModal then
		dismissedStandZoneModal = lastAutoZoneModal
	end
	if fromStandZone then
		currentModal = name
	else
		currentModal = if currentModal == name then nil else name
	end
	if currentModal == "Fuse" then
		fusePickerSlot = nil
	end
	renderActiveModal()
end

local function makeDedicatedModal(modalName: string, titleText: string, topCol: Color3, botCol: Color3, useGrid: boolean, cellW: number?, cellH: number?): (Frame, ScrollingFrame)
	local win = Instance.new("Frame")
	win.Name = modalName
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Size = UDim2.fromOffset(670, 435)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	win.Visible = false
	win.Parent = gui
	makeCorner(win, 12)
	makeStroke(win, 3)

	makeWindowHeader(win, titleText, topCol, botCol, function()
		openModal(nil)
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -24, 1, -64)
	scroll.Position = UDim2.fromOffset(12, 54)
	scroll.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.Parent = win
	makeCorner(scroll, 8)

	if useGrid then
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(cellW or 196, cellH or 220)
		gl.CellPadding = UDim2.fromOffset(10, 10)
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gl.Parent = scroll
	else
		local ll = Instance.new("UIListLayout")
		ll.Padding = UDim.new(0, 10)
		ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ll.Parent = scroll
	end

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll

	return win, scroll
end

local function clearScrollItems(scroll: ScrollingFrame)
	for _, ch in ipairs(scroll:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local function addActionRow(scroll: ScrollingFrame, titleStr: string, subStr: string, btnStr: string, btnCol: Color3, cb: () -> ())
	local r = Instance.new("Frame")
	r.Size = UDim2.new(0.96, 0, 0, 58)
	r.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
	r.Parent = scroll
	makeCorner(r, 8)
	makeStroke(r, 2)

	makeOutlinedLabel(r, titleStr, UDim2.new(0.68, -12, 0, 26), UDim2.fromOffset(10, 4), Color3.new(1, 1, 1), 2).TextXAlignment = Enum.TextXAlignment.Left
	makeOutlinedLabel(r, subStr, UDim2.new(0.68, -12, 0, 20), UDim2.fromOffset(10, 32), Color3.fromRGB(192, 212, 238), 1.6).TextXAlignment = Enum.TextXAlignment.Left

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.28, -10, 0, 40)
	b.Position = UDim2.new(0.71, 0, 0, 9)
	b.BackgroundColor3 = btnCol
	b.Text = btnStr
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Parent = r
	makeCorner(b, 8)
	makeStroke(b, 2)
	makeTextStroke(b, 1.8)
	b.MouseButton1Click:Connect(function()
		playClickSFX()
		cb()
	end)
end

local function addShopGridCard(
	scroll: ScrollingFrame,
	cardTitle: string,
	statLine1: string,
	statLine2: string,
	accentCol: Color3,
	btnText: string,
	btnCol: Color3,
	previewBuilder: ((Frame) -> ())?,
	onBuyClick: () -> ()
)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(38, 42, 52)
	card.Parent = scroll
	makeCorner(card, 10)
	makeStroke(card, 2.5, Color3.fromRGB(18, 20, 26))
	makeGradient(card, Color3.fromRGB(54, 58, 70), Color3.fromRGB(30, 34, 42))

	local tLbl = makeOutlinedLabel(card, cardTitle, UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 6), Color3.new(1, 1, 1), 2.2)
	tLbl.TextXAlignment = Enum.TextXAlignment.Center

	local previewFrame = Instance.new("Frame")
	previewFrame.Size = UDim2.new(1, -24, 0, 96)
	previewFrame.Position = UDim2.fromOffset(12, 36)
	previewFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	previewFrame.Parent = card
	makeCorner(previewFrame, 8)
	makeStroke(previewFrame, 2, accentCol)
	if previewBuilder then
		previewBuilder(previewFrame)
	end

	makeOutlinedLabel(card, statLine1, UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 136), accentCol, 2)
	makeOutlinedLabel(card, statLine2, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 158), Color3.fromRGB(220, 232, 248), 1.6)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -18, 0, 34)
	btn.Position = UDim2.new(0, 9, 1, -41)
	btn.BackgroundColor3 = btnCol
	btn.Text = btnText
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.FredokaOne
	btn.TextScaled = true
	btn.Parent = card
	makeCorner(btn, 8)
	makeStroke(btn, 2)
	makeTextStroke(btn, 1.8)
	btn.MouseButton1Click:Connect(function()
		playClickSFX()
		onBuyClick()
	end)
	return btn
end

-- A1. FEATURED & ROBUX SHOP MODAL (Strictly Passes & Packs — not merged with Trails/Lassos/Vehicles!)
local shopWindow, shopScroll = makeDedicatedModal("ShopModal", "Shop", Color3.fromRGB(132, 255, 42), Color3.fromRGB(64, 198, 18), false)

local function renderShopModal()
	clearScrollItems(shopScroll)
	if not profile then return end

	makeOutlinedLabel(shopScroll, "~ Featured ~", UDim2.new(0.95, 0, 0, 28), UDim2.new(), Color3.fromRGB(255, 224, 102), 2.5)

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
end

-- A2. DEDICATED TRAILS SHOP MODAL (Zero-Blink In-Place Updates!)
local trailsWindow, trailsScroll = makeDedicatedModal("TrailsModal", "Trails Shop", Color3.fromRGB(58, 224, 255), Color3.fromRGB(22, 138, 228), true, 198, 286)
local trailCardCache: { [string]: { eqBtn: TextButton, cashBtn: TextButton, rbxBtn: TextButton? } } = {}

local function refreshTrailCardState(t: Types.TrailDefinition, refs: { eqBtn: TextButton, cashBtn: TextButton, rbxBtn: TextButton? })
	if not profile then return end
	local owned = profile.ownedTrails[t.id] == true
	local eq = profile.equippedTrail == t.id
	refs.eqBtn.Visible = owned
	refs.eqBtn.BackgroundColor3 = if eq then Color3.fromRGB(142, 224, 52) else Color3.fromRGB(88, 224, 52)
	refs.eqBtn.Text = if eq then "Unequip" else "Equip"
	refs.cashBtn.Visible = not owned
	if refs.rbxBtn then
		refs.rbxBtn.Visible = not owned
	end
end

local function renderTrailsModal()
	if not profile then return end
	if next(trailCardCache) ~= nil then
		for _, t in ipairs(TrailConfig) do
			local refs = trailCardCache[t.id]
			if refs then
				refreshTrailCardState(t, refs)
			end
		end
		return
	end

	clearScrollItems(trailsScroll)
	for _, t in ipairs(TrailConfig) do
		local robuxCost = t.robuxPrice or 0

		local card = Instance.new("Frame")
		card.Name = "TrailCard_" .. t.id
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Parent = trailsScroll
		makeCorner(card, 10)
		makeStroke(card, 2.8, Color3.fromRGB(16, 18, 24))
		makeGradient(card, t.colorPrimary:Lerp(Color3.new(1, 1, 1), 0.45), t.colorSecondary:Lerp(Color3.fromRGB(18, 22, 34), 0.15), 90)

		-- Bold Trail Name + Rarity Subtitle
		makeOutlinedLabel(card, t.name, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 6), Color3.new(1, 1, 1), 2.5)
		makeOutlinedLabel(card, t.rarity or "Common", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 34), t.colorPrimary:Lerp(Color3.fromRGB(255, 214, 92), 0.35), 2.0)

		-- Stylized Running Silhouette + Sweeping Cape Preview
		local vpBox = Instance.new("Frame")
		vpBox.Size = UDim2.new(1, -18, 0, 140)
		vpBox.Position = UDim2.fromOffset(9, 56)
		vpBox.BackgroundTransparency = 1
		vpBox.Parent = card
		setViewportThumbnail(vpBox, function()
			return AnimalVisualBuilder.BuildTrailRunnerPreview(t.colorPrimary, t.colorSecondary)
		end)

		-- Dark Translucent Speed Pill Badge (e.g. "x4K Speed")
		local pill = Instance.new("Frame")
		pill.Size = UDim2.new(1, -18, 0, 30)
		pill.Position = UDim2.fromOffset(9, 198)
		pill.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
		pill.BackgroundTransparency = 0.25
		pill.ZIndex = 4
		pill.Parent = card
		makeCorner(pill, 6)
		makeStroke(pill, 1.8)
		local speedLbl = makeOutlinedLabel(
			pill,
			string.format("<font color=\"#78FF4A\">x%s</font> Speed", FormatUtil.Multiplier(t.speedMultiplier)),
			UDim2.new(1, -8, 1, -4),
			UDim2.fromOffset(4, 2),
			Color3.new(1, 1, 1),
			2.0
		)
		speedLbl.RichText = true
		speedLbl.ZIndex = 5

		-- Bottom Action Row: Equip/Unequip OR Cash + Robux side-by-side
		local actRow = Instance.new("Frame")
		actRow.Size = UDim2.new(1, -16, 0, 42)
		actRow.Position = UDim2.new(0, 8, 1, -49)
		actRow.BackgroundTransparency = 1
		actRow.ZIndex = 4
		actRow.Parent = card

		local eqBtn = Instance.new("TextButton")
		eqBtn.Size = UDim2.fromScale(1, 1)
		eqBtn.BackgroundColor3 = Color3.fromRGB(88, 224, 52)
		eqBtn.Text = "Equip"
		eqBtn.TextColor3 = Color3.new(1, 1, 1)
		eqBtn.Font = Enum.Font.FredokaOne
		eqBtn.TextScaled = true
		eqBtn.Parent = actRow
		makeCorner(eqBtn, 8)
		makeStroke(eqBtn, 2.2)
		makeTextStroke(eqBtn, 2.0)
		eqBtn.MouseButton1Click:Connect(function()
			playClickSFX()
			local isEqNow = profile and profile.equippedTrail == t.id
			Remotes.Get("EquipTrail"):FireServer(if isEqNow then "" else t.id)
		end)

		local hasRobux = robuxCost > 0
		local cashBtn = Instance.new("TextButton")
		cashBtn.Size = if hasRobux then UDim2.new(0.58, -3, 1, 0) else UDim2.fromScale(1, 1)
		cashBtn.BackgroundColor3 = Color3.fromRGB(88, 224, 52)
		cashBtn.Text = if t.cost == 0 then "FREE" else ("$" .. FormatUtil.Number(t.cost))
		cashBtn.TextColor3 = Color3.new(1, 1, 1)
		cashBtn.Font = Enum.Font.FredokaOne
		cashBtn.TextScaled = true
		cashBtn.Parent = actRow
		makeCorner(cashBtn, 8)
		makeStroke(cashBtn, 2.2)
		makeTextStroke(cashBtn, 2.0)
		cashBtn.MouseButton1Click:Connect(function()
			playClickSFX()
			Remotes.Get("BuyTrail"):FireServer(t.id)
		end)

		local rbxBtn: TextButton? = nil
		if hasRobux then
			local rb = Instance.new("TextButton")
			rb.Size = UDim2.new(0.42, -3, 1, 0)
			rb.Position = UDim2.new(0.58, 3, 0, 0)
			rb.BackgroundColor3 = Color3.fromRGB(168, 72, 245)
			rb.Text = "⏣ " .. tostring(robuxCost)
			rb.TextColor3 = Color3.new(1, 1, 1)
			rb.Font = Enum.Font.FredokaOne
			rb.TextScaled = true
			rb.Parent = actRow
			makeCorner(rb, 8)
			makeStroke(rb, 2.2)
			makeTextStroke(rb, 2.0)
			rb.MouseButton1Click:Connect(function()
				playClickSFX()
				Remotes.Get("PromptProduct"):FireServer(t.id)
			end)
			rbxBtn = rb
		end

		local refs = { eqBtn = eqBtn, cashBtn = cashBtn, rbxBtn = rbxBtn }
		trailCardCache[t.id] = refs
		refreshTrailCardState(t, refs)
	end
end

-- A3. DEDICATED LASSO SHOP MODAL (Zero-Blink In-Place Updates!)
local lassosWindow, lassosScroll = makeDedicatedModal("LassosModal", "Lasso Shop", Color3.fromRGB(255, 198, 64), Color3.fromRGB(218, 118, 24), true, 196, 222)
local lassoCardBtns: { [string]: TextButton } = {}

local function renderLassosModal()
	if not profile then return end
	if next(lassoCardBtns) ~= nil then
		for _, l in ipairs(LassoConfig) do
			local btn = lassoCardBtns[l.id]
			if btn then
				local owned = profile.ownedLassos[l.id] == true
				local eq = profile.equippedLasso == l.id
				btn.Text = if eq then "EQUIPPED" elseif owned then "EQUIP" elseif l.cost == 0 then "FREE" else "$" .. FormatUtil.Number(l.cost)
				btn.BackgroundColor3 = if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(72, 214, 52)
			end
		end
		return
	end
	clearScrollItems(lassosScroll)
	for _, l in ipairs(LassoConfig) do
		local owned = profile.ownedLassos[l.id] == true
		local eq = profile.equippedLasso == l.id
		local lassoRef = l
		local btn = addShopGridCard(
			lassosScroll,
			string.format("T%d: %s", l.tier, l.name),
			"🤠 Power: " .. FormatUtil.Number(l.pullPower),
			"Range: " .. tostring(l.maxRange) .. " studs",
			l.beamColor,
			if eq then "EQUIPPED" elseif owned then "EQUIP" elseif l.cost == 0 then "FREE" else "$" .. FormatUtil.Number(l.cost),
			if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(72, 214, 52),
			function(previewFrame)
				setViewportThumbnail(previewFrame, function()
					return AnimalVisualBuilder.BuildLassoModel(lassoRef.beamColor, 1.35)
				end)
			end,
			function()
				local isOwned = profile and profile.ownedLassos[lassoRef.id] == true
				if isOwned then Remotes.Get("EquipLasso"):FireServer(lassoRef.id)
				else Remotes.Get("BuyLasso"):FireServer(lassoRef.id) end
			end
		)
		lassoCardBtns[l.id] = btn
	end
end

-- A4. DEDICATED VEHICLE GARAGE MODAL (Zero-Blink In-Place Updates!)
local vehiclesWindow, vehiclesScroll = makeDedicatedModal("VehiclesModal", "Vehicle Garage", Color3.fromRGB(72, 238, 148), Color3.fromRGB(28, 156, 86), true, 196, 222)
local vehicleCardBtns: { [string]: TextButton } = {}

local function renderVehiclesModal()
	if not profile then return end
	if next(vehicleCardBtns) ~= nil then
		for _, v in ipairs(VehicleConfig) do
			local btn = vehicleCardBtns[v.id]
			if btn then
				local owned = profile.ownedVehicles[v.id] == true
				local eq = profile.equippedVehicle == v.id
				btn.Text = if eq then "EQUIPPED" elseif owned then "EQUIP" elseif v.cost == 0 then "FREE" else "$" .. FormatUtil.Number(v.cost)
				btn.BackgroundColor3 = if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(64, 198, 98)
			end
		end
		return
	end
	clearScrollItems(vehiclesScroll)
	for _, v in ipairs(VehicleConfig) do
		local owned = profile.ownedVehicles[v.id] == true
		local eq = profile.equippedVehicle == v.id
		local vRef = v
		local btn = addShopGridCard(
			vehiclesScroll,
			v.name,
			string.format("🚙 x%s Speed | %d Tow", FormatUtil.Number(v.speedMultiplier), v.towCapacity),
			if v.shieldHits > 0 then (tostring(v.shieldHits) .. " Tackle Shield(s)") elseif v.ignoresTerrainPenalty then "Ignores Mud/Ice" else "Starter Quadbike",
			v.primaryColor,
			if eq then "EQUIPPED" elseif owned then "EQUIP" elseif v.cost == 0 then "FREE" else "$" .. FormatUtil.Number(v.cost),
			if eq then Color3.fromRGB(82, 92, 112) elseif owned then Color3.fromRGB(58, 168, 232) else Color3.fromRGB(64, 198, 98),
			function(previewFrame)
				setViewportThumbnail(previewFrame, function()
					return AnimalVisualBuilder.BuildVehicleModel(vRef, 1.0)
				end)
			end,
			function()
				local isOwned = profile and profile.ownedVehicles[vRef.id] == true
				if isOwned then Remotes.Get("EquipVehicle"):FireServer(vRef.id)
				else Remotes.Get("BuyVehicle"):FireServer(vRef.id) end
			end
		)
		vehicleCardBtns[v.id] = btn
	end
end

-- A5. DEDICATED UNIFIED MERGE PETS MACHINE MODAL (2 Clean Views: 3-Slot Workbench <-> Auto-Filtered Pet Picker)
local fuseWindow, fuseScroll = makeDedicatedModal("FuseModal", "Merge Pets", Color3.fromRGB(56, 174, 255), Color3.fromRGB(26, 108, 224), false)

local MUTATION_SORT_RANK: { [string]: number } = {
	Celestial = 7,
	Rainbow = 6,
	Neon = 5,
	Diamond = 4,
	Golden = 3,
	Albino = 2,
	None = 1,
}

local function renderFuseModal()
	clearScrollItems(fuseScroll)
	if not profile then return end

	-- Prune stale UIDs & deduplicate across slots
	local usedElsewhere: { [string]: boolean } = {}
	for slotIdx = 1, 3 do
		local u = fuseSlotUids[slotIdx]
		if type(u) ~= "string" or not profile.inventoryAnimals[u] or usedElsewhere[u] then
			fuseSlotUids[slotIdx] = nil
		else
			usedElsewhere[u] = true
		end
	end

	-- Determine locked speciesId from any currently filled slot (excluding the slot currently being picked if replacing)
	local targetSpeciesId: string? = nil
	for slotIdx = 1, 3 do
		if slotIdx ~= fusePickerSlot then
			local u = fuseSlotUids[slotIdx]
			local a = if u then profile.inventoryAnimals[u] else nil
			if a then
				targetSpeciesId = a.speciesId
				break
			end
		end
	end

	-- Root clean container filling FuseModal interior
	local container = Instance.new("Frame")
	container.Name = "MergeContainer"
	container.Size = UDim2.new(0.98, 0, 0, 348)
	container.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
	container.Parent = fuseScroll
	makeCorner(container, 10)
	makeStroke(container, 2.5, Color3.fromRGB(52, 168, 255))

	makeOutlinedLabel(container, "Merge 3 of the same pets!", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 5), Color3.new(1, 1, 1), 2.2)
	makeOutlinedLabel(container, "More KG = Bigger CRATE", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 28), Color3.fromRGB(118, 212, 255), 1.6)

	if fusePickerSlot ~= nil then
		-- VIEW B: CLEAN "Select Pet to Merge" GRID PICKER (Image 5 Style: vibrant rarity gradient cards + Name + (XKG)!)
		local pickSlot = fusePickerSlot :: number
		local pickerPanel = Instance.new("Frame")
		pickerPanel.Name = "SelectPetPanel"
		pickerPanel.Size = UDim2.new(1, -18, 1, -56)
		pickerPanel.Position = UDim2.fromOffset(9, 48)
		pickerPanel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		pickerPanel.Parent = container
		makeCorner(pickerPanel, 8)
		makeStroke(pickerPanel, 2.2, Color3.fromRGB(14, 16, 20))

		local specObj = if targetSpeciesId then AnimalConfig.GetById(targetSpeciesId) else nil
		local headerText = if specObj then ("Select " .. specObj.name) else "Select Pet to Merge"
		makeOutlinedLabel(pickerPanel, headerText, UDim2.new(1, -110, 0, 26), UDim2.fromOffset(12, 6), Color3.new(1, 1, 1), 1.9).TextXAlignment = Enum.TextXAlignment.Left

		local backBtn = Instance.new("TextButton")
		backBtn.Name = "PickerBackButton"
		backBtn.Size = UDim2.fromOffset(86, 26)
		backBtn.Position = UDim2.new(1, -94, 0, 6)
		backBtn.BackgroundColor3 = Color3.fromRGB(208, 62, 74)
		backBtn.Text = "< Back"
		backBtn.TextColor3 = Color3.new(1, 1, 1)
		backBtn.Font = Enum.Font.FredokaOne
		backBtn.TextScaled = true
		backBtn.Parent = pickerPanel
		makeCorner(backBtn, 6)
		makeStroke(backBtn, 1.8)
		makeTextStroke(backBtn, 1.5)
		backBtn.MouseButton1Click:Connect(function()
			playClickSFX()
			fusePickerSlot = nil
			renderFuseModal()
		end)

		local blockedUids: { [string]: boolean } = {}
		for slotIdx = 1, 3 do
			if slotIdx ~= pickSlot and type(fuseSlotUids[slotIdx]) == "string" then
				blockedUids[fuseSlotUids[slotIdx] :: string] = true
			end
		end

		local candidates: { { uid: string, animal: Types.AnimalInstance, earn: number, mutRank: number } } = {}
		for uid, a in pairs(profile.inventoryAnimals) do
			if not blockedUids[uid] and (targetSpeciesId == nil or a.speciesId == targetSpeciesId) then
				table.insert(candidates, {
					uid = uid,
					animal = a,
					earn = AnimalConfig.ComputeIncomePerSec(a),
					mutRank = MUTATION_SORT_RANK[a.mutation] or 1,
				})
			end
		end

		-- Smart auto-sort: species grouped, best mutation & heaviest KG / Cash/s first!
		table.sort(candidates, function(a, b)
			if a.animal.speciesId == b.animal.speciesId then
				if a.mutRank ~= b.mutRank then
					return a.mutRank > b.mutRank
				end
				if math.abs(a.animal.weightKg - b.animal.weightKg) > 0.01 then
					return a.animal.weightKg > b.animal.weightKg
				end
				return a.earn > b.earn
			end
			return a.earn > b.earn
		end)

		if #candidates == 0 then
			local emptyLbl = makeOutlinedLabel(pickerPanel, "NO PETS", UDim2.new(1, -24, 0, 62), UDim2.new(0, 12, 0.5, -36), Color3.fromRGB(132, 138, 152), 2.4)
			emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
			local subEmpty = makeOutlinedLabel(
				pickerPanel,
				if specObj then string.format("No other %s available in your backpack/pen", specObj.name) else "Rescue & hatch crates to collect pets!",
				UDim2.new(1, -24, 0, 24),
				UDim2.new(0, 12, 0.5, 28),
				Color3.fromRGB(168, 178, 198),
				1.5
			)
			subEmpty.TextXAlignment = Enum.TextXAlignment.Center
			return
		end

		local gridScroll = Instance.new("ScrollingFrame")
		gridScroll.Name = "PickerGridScroll"
		gridScroll.Size = UDim2.new(1, -16, 1, -44)
		gridScroll.Position = UDim2.fromOffset(8, 38)
		gridScroll.BackgroundTransparency = 1
		gridScroll.ScrollBarThickness = 6
		gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		gridScroll.CanvasSize = UDim2.fromScale(0, 0)
		gridScroll.Parent = pickerPanel

		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(108, 110)
		gl.CellPadding = UDim2.fromOffset(8, 8)
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		gl.Parent = gridScroll

		for _, entry in ipairs(candidates) do
			local a = entry.animal
			local sp = AnimalConfig.GetById(a.speciesId)
			local mutInfo = GameConfig.MUTATIONS[a.mutation] or GameConfig.MUTATIONS.None
			local cardBg = if a.mutation ~= "None" then mutInfo.color else (sp and GameConfig.RARITY_COLORS[sp.rarity] or Color3.fromRGB(82, 88, 102))

			local card = Instance.new("TextButton")
			card.Name = "PetPick_" .. entry.uid
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.Text = ""
			card.Parent = gridScroll
			makeCorner(card, 8)
			makeStroke(card, 2.4, Color3.fromRGB(14, 16, 22))
			makeGradient(card, cardBg:Lerp(Color3.new(1, 1, 1), 0.32), cardBg:Lerp(Color3.fromRGB(20, 24, 34), 0.25), 90)

			local thumb = Instance.new("Frame")
			thumb.Size = UDim2.fromOffset(88, 66)
			thumb.Position = UDim2.new(0.5, -44, 0, 4)
			thumb.BackgroundTransparency = 1
			thumb.Parent = card
			setViewportThumbnail(thumb, function()
				return AnimalVisualBuilder.BuildAnimalModel(a.speciesId, 1.0, a.mutation, true)
			end)

			if a.mutation ~= "None" then
				makeOutlinedLabel(card, a.mutation, UDim2.new(1, -8, 0, 14), UDim2.fromOffset(4, 2), Color3.new(1, 1, 1), 1.6).TextXAlignment = Enum.TextXAlignment.Left
			end
			makeOutlinedLabel(card, sp and sp.name or a.speciesId, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 1, -38), Color3.new(1, 1, 1), 1.8)
			makeOutlinedLabel(card, string.format("(%sKG)", FormatUtil.Number(math.floor(a.weightKg + 0.5))), UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 1, -20), Color3.fromRGB(118, 224, 255), 1.8)

			card.MouseButton1Click:Connect(function()
				playClickSFX()
				fuseSlotUids[pickSlot] = entry.uid
				fusePickerSlot = nil
				renderFuseModal()
			end)
		end
		return
	end

	-- VIEW A: CLEAN 3-SLOT MERGE WORKBENCH (No cluttered pet list below!)
	local filledCount = 0
	local orderedUids: { string } = {}
	local selectedInputs: { { sizeRatio: number, mutation: string } } = {}
	local activeSpecId: string? = nil

	for slotNum = 1, 3 do
		local uid = fuseSlotUids[slotNum]
		local a = if uid then profile.inventoryAnimals[uid] else nil
		if a then
			filledCount += 1
			table.insert(orderedUids, uid :: string)
			table.insert(selectedInputs, { sizeRatio = a.sizeRatio, mutation = a.mutation })
			activeSpecId = a.speciesId
		end
	end

	-- Connecting Pipes (Light up bright cyan-blue when their slot is filled!)
	local slotXs = { 0.19, 0.50, 0.81 }
	for slotNum = 1, 3 do
		local isLit = fuseSlotUids[slotNum] ~= nil
		local pipeCol = if isLit then Color3.fromRGB(72, 206, 255) else Color3.fromRGB(22, 24, 30)

		local vert = Instance.new("Frame")
		vert.Name = "PipeVert_" .. slotNum
		vert.Size = UDim2.fromOffset(14, if slotNum == 2 then 42 else 74)
		vert.Position = UDim2.new(slotXs[slotNum], -7, 0, 134)
		vert.BackgroundColor3 = pipeCol
		vert.BorderSizePixel = 0
		vert.ZIndex = 1
		vert.Parent = container
		makeStroke(vert, 1.8)

		if slotNum ~= 2 then
			local horiz = Instance.new("Frame")
			horiz.Name = "PipeHoriz_" .. slotNum
			horiz.Size = UDim2.new(0.31, 0, 0, 14)
			horiz.Position = if slotNum == 1 then UDim2.new(0.19, -7, 0, 198) else UDim2.new(0.50, 7, 0, 198)
			horiz.BackgroundColor3 = pipeCol
			horiz.BorderSizePixel = 0
			horiz.ZIndex = 1
			horiz.Parent = container
			makeStroke(horiz, 1.8)
		end
	end

	-- Top 3 Input Pet Slots
	for slotNum = 1, 3 do
		local uid = fuseSlotUids[slotNum]
		local a = if uid then profile.inventoryAnimals[uid] else nil
		local slotX = if slotNum == 1 then 0.05 elseif slotNum == 2 then 0.36 else 0.67

		local box = Instance.new("Frame")
		box.Name = "MergeSlot_" .. slotNum
		box.Size = UDim2.new(0.28, 0, 0, 86)
		box.Position = UDim2.new(slotX, 0, 0, 52)
		box.BackgroundColor3 = if a then Color3.fromRGB(46, 54, 70) else Color3.fromRGB(42, 44, 52)
		box.ZIndex = 2
		box.Parent = container
		makeCorner(box, 8)
		makeStroke(box, 2.4, if a then Color3.fromRGB(92, 232, 138) else Color3.fromRGB(16, 18, 22))

		if a then
			local sp = AnimalConfig.GetById(a.speciesId)
			local mutText = if a.mutation ~= "None" then ("[" .. a.mutation .. "] ") else ""
			local thumb = Instance.new("Frame")
			thumb.Size = UDim2.fromOffset(50, 44)
			thumb.Position = UDim2.new(1, -54, 0, 26)
			thumb.BackgroundTransparency = 1
			thumb.ZIndex = 3
			thumb.Parent = box
			setViewportThumbnail(thumb, function()
				return AnimalVisualBuilder.BuildAnimalModel(a.speciesId, 1.0, a.mutation, true)
			end)
			makeOutlinedLabel(box, sp and sp.name or a.speciesId, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 4), Color3.new(1, 1, 1), 1.6).ZIndex = 3
			makeOutlinedLabel(box, string.format("%s%.1fkg", mutText, a.weightKg), UDim2.new(1, -58, 0, 18), UDim2.fromOffset(6, 26), Color3.fromRGB(168, 224, 255), 1.4).ZIndex = 3

			local rmBtn = Instance.new("TextButton")
			rmBtn.Name = "RemoveBtn_" .. slotNum
			rmBtn.Size = UDim2.new(0.56, 0, 0, 26)
			rmBtn.Position = UDim2.new(0, 6, 1, -32)
			rmBtn.BackgroundColor3 = Color3.fromRGB(224, 228, 238)
			rmBtn.Text = "Remove"
			rmBtn.TextColor3 = Color3.fromRGB(214, 48, 62)
			rmBtn.Font = Enum.Font.FredokaOne
			rmBtn.TextScaled = true
			rmBtn.ZIndex = 4
			rmBtn.Parent = box
			makeCorner(rmBtn, 6)
			makeStroke(rmBtn, 1.8, Color3.fromRGB(186, 46, 58))
			rmBtn.MouseButton1Click:Connect(function()
				playClickSFX()
				fuseSlotUids[slotNum] = nil
				renderFuseModal()
			end)
		else
			makeOutlinedLabel(box, "(Pet Needed)", UDim2.new(1, -8, 0, 24), UDim2.fromOffset(4, 10), Color3.fromRGB(230, 234, 242), 1.7).ZIndex = 3

			local addBtn = Instance.new("TextButton")
			addBtn.Name = "AddBtn_" .. slotNum
			addBtn.Size = UDim2.new(0.84, 0, 0, 32)
			addBtn.Position = UDim2.new(0.08, 0, 1, -40)
			addBtn.BackgroundColor3 = Color3.fromRGB(118, 232, 48)
			addBtn.Text = "Add"
			addBtn.TextColor3 = Color3.new(1, 1, 1)
			addBtn.Font = Enum.Font.FredokaOne
			addBtn.TextScaled = true
			addBtn.ZIndex = 4
			addBtn.Parent = box
			makeCorner(addBtn, 6)
			makeStroke(addBtn, 2)
			makeTextStroke(addBtn, 1.8)
			addBtn.MouseButton1Click:Connect(function()
				playClickSFX()
				fusePickerSlot = slotNum
				renderFuseModal()
			end)
		end
	end

	-- Center Result Output Box (Vertical Fill Bar 0/3 -> 3/3 + Output Preview!)
	local resultBox = Instance.new("Frame")
	resultBox.Name = "OutputChamber"
	resultBox.Size = UDim2.fromOffset(224, 114)
	resultBox.AnchorPoint = Vector2.new(0.5, 0)
	resultBox.Position = UDim2.new(0.5, 0, 0, 170)
	resultBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	resultBox.ClipsDescendants = true
	resultBox.ZIndex = 3
	resultBox.Parent = container
	makeCorner(resultBox, 8)
	makeStroke(resultBox, 2.5, if filledCount == 3 then Color3.fromRGB(92, 238, 255) else Color3.fromRGB(12, 14, 18))

	-- Progress fill bar rising from bottom
	local fillRatio = filledCount / 3
	if fillRatio > 0 then
		local fillBar = Instance.new("Frame")
		fillBar.Name = "ChargeFill"
		fillBar.Size = UDim2.fromScale(1, fillRatio)
		fillBar.AnchorPoint = Vector2.new(0, 1)
		fillBar.Position = UDim2.fromScale(0, 1)
		fillBar.BackgroundColor3 = Color3.fromRGB(148, 226, 248)
		fillBar.BorderSizePixel = 0
		fillBar.ZIndex = 3
		fillBar.Parent = resultBox
	end

	if activeSpecId then
		local previewThumb = Instance.new("Frame")
		previewThumb.Size = UDim2.fromOffset(92, 74)
		previewThumb.AnchorPoint = Vector2.new(0.5, 0)
		previewThumb.Position = UDim2.new(0.5, 0, 0, 4)
		previewThumb.BackgroundTransparency = 1
		previewThumb.ZIndex = 4
		previewThumb.Parent = resultBox
		local boostedSize, _, chances = GameConfig.ComputeMergeForecast(selectedInputs)
		local topMut = (chances[1] and chances[1].mutation or "None") :: Types.AnimalMutation
		setViewportThumbnail(previewThumb, function()
			return AnimalVisualBuilder.BuildAnimalModel(activeSpecId, 1.0, if filledCount == 3 then topMut else "None", true)
		end)

		local chanceParts: { string } = {}
		for i = 1, math.min(2, #chances) do
			local c = chances[i]
			table.insert(chanceParts, string.format("%d%% %s", c.chance, if c.mutation == "None" then "Normal" else c.mutation))
		end
		makeOutlinedLabel(
			resultBox,
			string.format("Crate %.2fx • %s", boostedSize, table.concat(chanceParts, " / ")),
			UDim2.new(1, -12, 0, 24),
			UDim2.new(0, 6, 1, -28),
			Color3.fromRGB(255, 236, 128),
			1.6
		).ZIndex = 5
	end

	-- Bottom Merge CTA Button ("3 Pets Left" / "2 Pets Left" / "1 Pet Left" -> "Merge!")
	local remaining = math.max(0, 3 - filledCount)
	local mergeBtn = Instance.new("TextButton")
	mergeBtn.Name = "MergeExecuteButton"
	mergeBtn.Size = UDim2.fromOffset(238, 44)
	mergeBtn.AnchorPoint = Vector2.new(0.5, 1)
	mergeBtn.Position = UDim2.new(0.5, 0, 1, -10)
	mergeBtn.BackgroundColor3 = if remaining == 0 then Color3.fromRGB(72, 232, 82) else Color3.fromRGB(118, 232, 48)
	mergeBtn.Text = if remaining == 0 then "Merge!" else string.format("%d Pet%s Left", remaining, if remaining == 1 then "" else "s")
	mergeBtn.TextColor3 = Color3.new(1, 1, 1)
	mergeBtn.Font = Enum.Font.FredokaOne
	mergeBtn.TextScaled = true
	mergeBtn.ZIndex = 4
	mergeBtn.Parent = container
	makeCorner(mergeBtn, 8)
	makeStroke(mergeBtn, 2.4, if remaining == 0 then Color3.fromRGB(118, 255, 152) else Color3.fromRGB(16, 18, 22))
	makeTextStroke(mergeBtn, 2)
	mergeBtn.MouseButton1Click:Connect(function()
		playClickSFX()
		if #orderedUids < 3 then
			localPlayer:SetAttribute("ClientToastSeq", (tonumber(localPlayer:GetAttribute("ClientToastSeq")) or 0) + 1)
			localPlayer:SetAttribute("ClientToastText", "Add 3 of the same pets first!")
			return
		end
		Remotes.Get("RequestMergeAnimals"):FireServer(orderedUids)
		table.clear(fuseSlotUids)
		fusePickerSlot = nil
		renderFuseModal()
	end)
end

-- A6. DEDICATED REBIRTH & DAILY REWARDS MODAL (Dual Progress Bars: Speed & Coins!)
local rebirthWindow, rebirthScroll = makeDedicatedModal("RebirthModal", "Rebirth & Daily Rewards", Color3.fromRGB(255, 92, 162), Color3.fromRGB(192, 34, 102), false)

local function makeRebirthProgressBar(parent: Frame, labelText: string, curVal: number, reqVal: number, posY: number, fillCol1: Color3, fillCol2: Color3)
	local ratio = math.clamp(curVal / math.max(1, reqVal), 0, 1)
	local pct = math.floor(ratio * 100)
	local check = if curVal >= reqVal then " ✅" else ""
	makeOutlinedLabel(
		parent,
		string.format("%s: %s / %s (%d%%)%s", labelText, FormatUtil.Number(curVal), FormatUtil.Number(reqVal), pct, check),
		UDim2.new(1, -24, 0, 22),
		UDim2.fromOffset(12, posY),
		if curVal >= reqVal then Color3.fromRGB(118, 255, 148) else Color3.new(1, 1, 1),
		1.7
	).TextXAlignment = Enum.TextXAlignment.Left

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 18)
	track.Position = UDim2.fromOffset(12, posY + 23)
	track.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	track.Parent = parent
	makeCorner(track, 6)
	makeStroke(track, 1.8)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(ratio, 1)
	fill.BackgroundColor3 = fillCol1
	fill.Parent = track
	makeCorner(fill, 6)
	makeGradient(fill, fillCol1, fillCol2)
end

local function renderRebirthModal()
	clearScrollItems(rebirthScroll)
	if not profile then return end
	local reqSpd = math.floor(GameConfig.ECONOMY.REBIRTH_BASE_SPEED * math.pow(2.1, profile.rebirths))
	local reqCoins = math.floor(GameConfig.ECONOMY.REBIRTH_BASE_COINS * math.pow(GameConfig.ECONOMY.REBIRTH_GROWTH, profile.rebirths))
	local meetsSpd = profile.speedStat >= reqSpd
	local meetsCoins = profile.coins >= reqCoins
	local ready = meetsSpd and meetsCoins

	local rCard = Instance.new("Frame")
	rCard.Size = UDim2.new(0.96, 0, 0, 206)
	rCard.BackgroundColor3 = Color3.fromRGB(38, 36, 48)
	rCard.Parent = rebirthScroll
	makeCorner(rCard, 10)
	makeStroke(rCard, 2.5, Color3.fromRGB(255, 92, 162))

	makeOutlinedLabel(rCard, string.format("REBIRTH #%d (+%d%% Permanent Cash!)", profile.rebirths + 1, (profile.rebirths + 1) * 75), UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 6), Color3.fromRGB(255, 156, 212), 2.2)
	makeOutlinedLabel(rCard, "Resets Coins ONLY — keeps Speed, Pets, Crates, Lassos & Upgrades!", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 34), Color3.fromRGB(210, 226, 245), 1.6)

	makeRebirthProgressBar(rCard, "👟 Required Speed", profile.speedStat, reqSpd, 58, Color3.fromRGB(68, 198, 255), Color3.fromRGB(28, 118, 228))
	makeRebirthProgressBar(rCard, "💵 Required Cash ($)", profile.coins, reqCoins, 106, Color3.fromRGB(88, 245, 128), Color3.fromRGB(36, 178, 72))

	local rbBtn = Instance.new("TextButton")
	rbBtn.Size = UDim2.new(0.62, 0, 0, 40)
	rbBtn.Position = UDim2.new(0.19, 0, 1, -48)
	rbBtn.BackgroundColor3 = if ready then Color3.fromRGB(238, 68, 138) else Color3.fromRGB(72, 74, 88)
	rbBtn.Text = if ready then "REBIRTH NOW!" else "COMPLETE BOTH BARS TO REBIRTH"
	rbBtn.TextColor3 = Color3.new(1, 1, 1)
	rbBtn.Font = Enum.Font.FredokaOne
	rbBtn.TextScaled = true
	rbBtn.Parent = rCard
	makeCorner(rbBtn, 8)
	makeStroke(rbBtn, 2.4, if ready then Color3.fromRGB(255, 186, 224) else Color3.fromRGB(18, 20, 24))
	makeTextStroke(rbBtn, 2)
	rbBtn.MouseButton1Click:Connect(function()
		playClickSFX()
		Remotes.Get("RequestRebirth"):FireServer()
	end)

	addActionRow(
		rebirthScroll,
		string.format("Claim Daily Reward (Streak Day %d)", profile.dailyReward.streak),
		"Free Coins & Speed every 24h!",
		"CLAIM DAILY",
		Color3.fromRGB(244, 178, 44),
		function() Remotes.Get("ClaimDailyReward"):FireServer() end
	)
end

-- B. INDEX MODAL (Screenshots 4 & 5)
local indexWindow = Instance.new("Frame")
indexWindow.Name = "IndexModal"
indexWindow.AnchorPoint = Vector2.new(0.5, 0.5)
indexWindow.Size = UDim2.fromOffset(690, 440)
indexWindow.Position = UDim2.fromScale(0.5, 0.5)
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

	local ZONE_REWARD_TAGS: { [string]: string } = {
		PineWoods = "👟+15%",
		MangroveSwamp = "💵+25%",
		SavannaCamp = "🐾+1 Cap",
		AlpinePeaks = "👟+50%",
		VolcanicJungle = "👟+100%",
	}

	local totalUnlocked = 0
	local unclaimedRewards = 0
	for _, entry in pairs(profile.discoveredIndex) do
		totalUnlocked += 1
		if not entry.rewardClaimed then
			unclaimedRewards += 1
		end
	end

	-- Badge "!" on Normal right tab when claimable index rewards exist (Image 3 style)
	local normalTab = indexRightTabs:FindFirstChildOfClass("TextButton")
	if normalTab and unclaimedRewards > 0 then
		local dot = makeOutlinedLabel(normalTab, "!", UDim2.fromOffset(20, 20), UDim2.new(1, -14, 0, -6), Color3.new(1, 1, 1), 2)
		dot.BackgroundColor3 = Color3.fromRGB(235, 36, 44)
		dot.BackgroundTransparency = 0
		dot.ZIndex = 5
		makeCorner(dot, 10)
		makeStroke(dot, 2)
	end

	-- Render Each of the 5 Biomes as a Zone Container Block (Image 3 Style)
	for _, biome in ipairs(BiomeConfig) do
		local pool = AnimalConfig.GetByBiome(biome.id)
		local rows = math.ceil(#pool / 4)
		local containerH = math.max(162, rows * 76 + 52)

		local zCard = Instance.new("Frame")
		zCard.Size = UDim2.new(1, 0, 0, containerH)
		zCard.BackgroundColor3 = Color3.fromRGB(16, 20, 16)
		zCard.Parent = indexScroll
		makeCorner(zCard, 8)
		makeStroke(zCard, 2)

		-- Left Vertical Stylized Biome Banner
		local banner = Instance.new("Frame")
		banner.Size = UDim2.new(0, 74, 1, -12)
		banner.Position = UDim2.fromOffset(6, 6)
		banner.BackgroundColor3 = biome.groundColor
		banner.Parent = zCard
		makeCorner(banner, 6)
		makeStroke(banner, 2)
		makeGradient(banner, biome.groundColor:Lerp(Color3.new(1, 1, 1), 0.18), biome.cliffColor, 90)
		makeOutlinedLabel(banner, string.format("Z%d\n%s", biome.order, biome.id), UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05), Color3.new(1, 1, 1), 2)

		-- Center 4-Column Animal Grid with 3D Models + Rarity Glow Backgrounds
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

			local rarityCol = GameConfig.RARITY_COLORS[spec.rarity] or Color3.fromRGB(150, 160, 175)
			local mutInfo = GameConfig.MUTATIONS[mutShow] or GameConfig.MUTATIONS.None
			local cardBg = if not isDisc
				then rarityCol:Lerp(Color3.fromRGB(12, 14, 18), 0.58)
				elseif mutShow ~= "None" then mutInfo.color
				else rarityCol

			local cardFrame = Instance.new("Frame")
			cardFrame.Size = UDim2.fromScale(1, 1)
			cardFrame.BackgroundColor3 = cardBg
			cardFrame.Parent = btn
			makeCorner(cardFrame, 8)
			local isSel = (spec.id == selectedIndexSpeciesId)
			makeStroke(cardFrame, if isSel then 2.8 else 2.0, if isSel then Color3.new(1, 1, 1) else Color3.fromRGB(14, 16, 20))
			makeGradient(cardFrame, cardBg:Lerp(Color3.new(1, 1, 1), if isDisc then 0.28 else 0.08), cardBg:Lerp(Color3.new(0, 0, 0), 0.25), 90)

			local vpHolder = Instance.new("Frame")
			vpHolder.Size = UDim2.new(1, -6, 1, -20)
			vpHolder.Position = UDim2.fromOffset(3, 18)
			vpHolder.BackgroundTransparency = 1
			vpHolder.Parent = cardFrame
			setViewportThumbnail(vpHolder, function()
				local m = AnimalVisualBuilder.BuildAnimalModel(spec.id, 1.0, mutShow, true)
				if not isDisc then
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Color = Color3.fromRGB(16, 18, 22)
							d.Material = Enum.Material.SmoothPlastic
						end
					end
				end
				return m
			end)

			local nameLbl = makeOutlinedLabel(cardFrame, if isDisc then spec.name else "???", UDim2.new(1, -4, 0, 18), UDim2.fromOffset(2, 2), Color3.new(1, 1, 1), 1.8)
			nameLbl.ZIndex = 4

			btn.MouseButton1Click:Connect(function()
				playClickSFX()
				selectedIndexSpeciesId = spec.id
				renderIndexModal()
			end)
		end

		-- Bottom Green Progress Bar + Biome Milestone Reward Icon inside Zone Block
		local pTrack = Instance.new("Frame")
		pTrack.Size = UDim2.new(1, -148, 0, 28)
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

		local zClaimed = profile.zoneIndexBonusesClaimed[biome.id] == true
		local zRewBox = Instance.new("Frame")
		zRewBox.Size = UDim2.fromOffset(48, 28)
		zRewBox.Position = UDim2.new(1, -56, 1, -34)
		zRewBox.BackgroundColor3 = if zClaimed then Color3.fromRGB(88, 224, 52) else Color3.fromRGB(42, 46, 56)
		zRewBox.Parent = zCard
		makeCorner(zRewBox, 6)
		makeStroke(zRewBox, 2)
		makeOutlinedLabel(zRewBox, ZONE_REWARD_TAGS[biome.id] or "🎁", UDim2.fromScale(0.92, 0.9), UDim2.fromScale(0.04, 0.05), Color3.new(1, 1, 1), 1.6)
	end

	-- Populate Right Inspect Panel (Image 3 Clean Silver Card)
	local selSpec = AnimalConfig.GetById(selectedIndexSpeciesId) or AnimalConfig.ALL[1]
	local selEntry = profile.discoveredIndex[selSpec.id]
	local showcaseCard = Instance.new("Frame")
	showcaseCard.Size = UDim2.new(1, -16, 0, 118)
	showcaseCard.Position = UDim2.fromOffset(8, 10)
	showcaseCard.BackgroundColor3 = Color3.fromRGB(224, 228, 236)
	showcaseCard.Parent = inspectPanel
	makeCorner(showcaseCard, 8)
	makeStroke(showcaseCard, 2.2, Color3.fromRGB(28, 32, 38))
	makeGradient(showcaseCard, Color3.fromRGB(246, 248, 252), Color3.fromRGB(186, 194, 206), 45)

	local vpInspect = Instance.new("Frame")
	vpInspect.Size = UDim2.new(1, -12, 1, -10)
	vpInspect.Position = UDim2.fromOffset(6, 5)
	vpInspect.BackgroundTransparency = 1
	vpInspect.Parent = showcaseCard
	setViewportThumbnail(vpInspect, function()
		local m = AnimalVisualBuilder.BuildAnimalModel(selSpec.id, 1.0, "None", true)
		if selEntry == nil then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = Color3.fromRGB(16, 18, 22)
					d.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		return m
	end)

	makeOutlinedLabel(inspectPanel, if selEntry then selSpec.name else "???", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 132), Color3.new(1, 1, 1), 2.3)
	makeOutlinedLabel(inspectPanel, selSpec.rarity, UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 160), GameConfig.RARITY_COLORS[selSpec.rarity] or Color3.new(1, 1, 1), 2.1)
	makeOutlinedLabel(inspectPanel, "$" .. FormatUtil.Number(selSpec.baseIncomePerSec) .. "/s", UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 184), Color3.fromRGB(92, 248, 92), 2.3)

	local rewBox = Instance.new("Frame")
	rewBox.Size = UDim2.new(1, -16, 0, 144)
	rewBox.Position = UDim2.fromOffset(8, 214)
	rewBox.BackgroundColor3 = Color3.fromRGB(28, 32, 38)
	rewBox.Parent = inspectPanel
	makeCorner(rewBox, 8)
	makeStroke(rewBox, 2)

	makeOutlinedLabel(rewBox, "Rewards:", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(6, 4), Color3.new(1, 1, 1), 1.8).TextXAlignment = Enum.TextXAlignment.Left

	local rewCoins = FormatUtil.Number(selSpec.baseIncomePerSec * 120)
	local cashTile = Instance.new("Frame")
	cashTile.Size = UDim2.fromOffset(78, 56)
	cashTile.Position = UDim2.fromOffset(10, 28)
	cashTile.BackgroundColor3 = Color3.fromRGB(46, 52, 64)
	cashTile.Parent = rewBox
	makeCorner(cashTile, 6)
	makeStroke(cashTile, 1.8)
	makeOutlinedLabel(cashTile, "💵", UDim2.fromScale(1, 0.52), UDim2.fromScale(0, 0.04), Color3.new(1, 1, 1), 1.5)
	makeOutlinedLabel(cashTile, "$" .. rewCoins, UDim2.fromScale(0.94, 0.42), UDim2.fromScale(0.03, 0.56), Color3.fromRGB(118, 255, 118), 1.6)

	local zoneTile = Instance.new("Frame")
	zoneTile.Size = UDim2.fromOffset(78, 56)
	zoneTile.Position = UDim2.fromOffset(96, 28)
	zoneTile.BackgroundColor3 = Color3.fromRGB(46, 52, 64)
	zoneTile.Parent = rewBox
	makeCorner(zoneTile, 6)
	makeStroke(zoneTile, 1.8)
	makeOutlinedLabel(zoneTile, "📖", UDim2.fromScale(1, 0.52), UDim2.fromScale(0, 0.04), Color3.new(1, 1, 1), 1.5)
	makeOutlinedLabel(zoneTile, "#" .. string.format("%02d", selSpec.indexNumber), UDim2.fromScale(0.94, 0.42), UDim2.fromScale(0.03, 0.56), Color3.fromRGB(118, 224, 255), 1.6)

	local claimBtn = Instance.new("TextButton")
	claimBtn.Size = UDim2.new(1, -16, 0, 42)
	claimBtn.Position = UDim2.new(0, 8, 1, -48)
	claimBtn.BackgroundColor3 = if selEntry and not selEntry.rewardClaimed then Color3.fromRGB(72, 224, 52) elseif selEntry then Color3.fromRGB(205, 212, 222) else Color3.fromRGB(92, 98, 110)
	claimBtn.Text = if not selEntry then "Locked" elseif selEntry.rewardClaimed then "Claimed" else "Claim!"
	claimBtn.TextColor3 = Color3.new(1, 1, 1)
	claimBtn.Font = Enum.Font.FredokaOne
	claimBtn.TextScaled = true
	claimBtn.Parent = rewBox
	makeCorner(claimBtn, 8)
	makeStroke(claimBtn, 2.2)
	makeTextStroke(claimBtn, 2)
	claimBtn.MouseButton1Click:Connect(function()
		playClickSFX()
		if selEntry and not selEntry.rewardClaimed then
			Remotes.Get("ClaimIndexReward"):FireServer(selSpec.id)
		end
	end)

	-- Bottom-Left Full Blue Striped Claim Button (Image 3 "Claim!(1)")
	local claimAllBtn = Instance.new("TextButton")
	claimAllBtn.Size = UDim2.fromScale(1, 1)
	claimAllBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	claimAllBtn.Text = if unclaimedRewards > 0 then string.format("📖 Claim!(%d)", unclaimedRewards) else string.format("📖 Unlocked: %d/%d", totalUnlocked, #AnimalConfig.ALL)
	claimAllBtn.TextColor3 = Color3.new(1, 1, 1)
	claimAllBtn.Font = Enum.Font.FredokaOne
	claimAllBtn.TextScaled = true
	claimAllBtn.Parent = totalIndexBar
	makeCorner(claimAllBtn, 8)
	makeTextStroke(claimAllBtn, 2.4)
	makeGradient(
		claimAllBtn,
		if unclaimedRewards > 0 then Color3.fromRGB(82, 218, 255) else Color3.fromRGB(82, 168, 224),
		if unclaimedRewards > 0 then Color3.fromRGB(28, 138, 238) else Color3.fromRGB(36, 98, 162),
		90
	)
	claimAllBtn.MouseButton1Click:Connect(function()
		playClickSFX()
		Remotes.Get("ClaimAllIndexRewards"):FireServer()
	end)
end

-- C. CLEAN TRANSLUCENT FROSTED BACKPACK & DRAG-AND-DROP INVENTORY (Image 1 Style)
local invWindow = Instance.new("Frame")
invWindow.Name = "InventoryModal"
invWindow.AnchorPoint = Vector2.new(0.5, 1)
invWindow.Size = UDim2.fromOffset(664, 300)
invWindow.Position = UDim2.new(0.5, 0, 1, -76)
invWindow.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
invWindow.BackgroundTransparency = 0.22
invWindow.Visible = false
invWindow.Parent = gui
makeCorner(invWindow, 10)
do
	local invSt = makeStroke(invWindow, 1.8, Color3.new(1, 1, 1))
	invSt.Transparency = 0.80
end
invWindowRef = invWindow

local sellToggleBtn = Instance.new("TextButton")
sellToggleBtn.Size = UDim2.fromOffset(96, 38)
sellToggleBtn.Position = UDim2.fromOffset(0, -46)
sellToggleBtn.BackgroundColor3 = Color3.fromRGB(218, 34, 34)
sellToggleBtn.Text = "Sell"
sellToggleBtn.TextColor3 = Color3.new(1, 1, 1)
sellToggleBtn.Font = Enum.Font.FredokaOne
sellToggleBtn.TextScaled = true
sellToggleBtn.Parent = invWindow
makeCorner(sellToggleBtn, 8)
makeStroke(sellToggleBtn, 2.2)
makeTextStroke(sellToggleBtn, 2)

local invLeftTabs = Instance.new("Frame")
invLeftTabs.Size = UDim2.fromOffset(58, 260)
invLeftTabs.Position = UDim2.fromOffset(-66, 8)
invLeftTabs.BackgroundTransparency = 1
invLeftTabs.Parent = invWindow

local invTitleLbl = makeOutlinedLabel(invWindow, "All Pets", UDim2.fromOffset(220, 28), UDim2.fromOffset(14, 8), Color3.new(1, 1, 1), 2.2)
invTitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.fromOffset(204, 30)
searchBox.Position = UDim2.new(1, -252, 0, 7)
searchBox.BackgroundColor3 = Color3.fromRGB(78, 82, 92)
searchBox.BackgroundTransparency = 0.35
searchBox.PlaceholderText = "Search"
searchBox.PlaceholderColor3 = Color3.fromRGB(198, 204, 214)
searchBox.Text = ""
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.Font = Enum.Font.FredokaOne
searchBox.TextScaled = true
searchBox.Parent = invWindow
makeCorner(searchBox, 6)
do
	local sbSt = makeStroke(searchBox, 1.4, Color3.new(1, 1, 1))
	sbSt.Transparency = 0.78
end

local invCloseBtn = Instance.new("TextButton")
invCloseBtn.Name = "BackpackCloseButton"
invCloseBtn.Size = UDim2.fromOffset(30, 30)
invCloseBtn.Position = UDim2.new(1, -38, 0, 7)
invCloseBtn.BackgroundColor3 = Color3.fromRGB(220, 44, 52)
invCloseBtn.BackgroundTransparency = 0.08
invCloseBtn.Text = "X"
invCloseBtn.TextColor3 = Color3.new(1, 1, 1)
invCloseBtn.Font = Enum.Font.FredokaOne
invCloseBtn.TextScaled = true
invCloseBtn.ZIndex = 12
invCloseBtn.Parent = invWindow
makeCorner(invCloseBtn, 8)
makeStroke(invCloseBtn, 2.0)
makeTextStroke(invCloseBtn, 1.8)
invCloseBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal(nil)
end)

local invScroll = Instance.new("ScrollingFrame")
invScroll.Size = UDim2.new(1, -20, 1, -50)
invScroll.Position = UDim2.fromOffset(10, 42)
invScroll.BackgroundTransparency = 1
invScroll.ScrollBarThickness = 6
invScroll.ScrollBarImageColor3 = Color3.fromRGB(210, 218, 232)
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.CanvasSize = UDim2.fromScale(0, 0)
invScroll.Parent = invWindow
invScrollRef = invScroll
local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.fromOffset(96, 94)
invGrid.CellPadding = UDim2.fromOffset(8, 8)
invGrid.Parent = invScroll
local invPad = Instance.new("UIPadding")
invPad.PaddingTop = UDim.new(0, 4)
invPad.PaddingLeft = UDim.new(0, 4)
invPad.Parent = invScroll

local invTabRefs: { [string]: { btn: TextButton, st: UIStroke } } = {}
local invGearListSig = ""
local invGearCards: { { id: string, btn: TextButton, stroke: UIStroke, accent: Color3 } } = {}

local function renderInventoryModal()
	local catTabs = {
		{ id = "Pets", icon = "🐾", label = "Pets" },
		{ id = "Crates", icon = "🥚", label = "Crates" },
		{ id = "Mounts", icon = "🏇", label = "Mounted" },
		{ id = "Gear", icon = "🤠", label = "Lassos" },
	}
	if next(invTabRefs) == nil then
		for i, ct in ipairs(catTabs) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(56, 56)
			b.Position = UDim2.fromOffset(0, (i - 1) * 62)
			b.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
			b.Text = ""
			b.Parent = invLeftTabs
			makeCorner(b, 8)
			local tabSt = makeStroke(b, 1.4, Color3.fromRGB(0, 0, 0))
			makeOutlinedLabel(b, ct.icon, UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0.06), Color3.new(1, 1, 1), 1.4)
			makeOutlinedLabel(b, ct.label, UDim2.fromScale(0.94, 0.30), UDim2.fromScale(0.03, 0.66), Color3.new(1, 1, 1), 1.6)
			b.MouseButton1Click:Connect(function()
				playClickSFX()
				invLeftTab = ct.id
				invGearListSig = ""
				renderInventoryModal()
			end)
			invTabRefs[ct.id] = { btn = b, st = tabSt }
		end
	end
	for _, ct in ipairs(catTabs) do
		local ref = invTabRefs[ct.id]
		if ref then
			local isAct = (invLeftTab == ct.id)
			ref.btn.BackgroundTransparency = if isAct then 0.14 else 0.30
			ref.st.Thickness = if isAct then 2.5 else 1.4
			ref.st.Color = if isAct then Color3.new(1, 1, 1) else Color3.fromRGB(0, 0, 0)
			ref.st.Transparency = if isAct then 0 else 0.45
		end
	end

	local canReuseGearGrid = (invLeftTab == "Mounts" or invLeftTab == "Gear") and profile ~= nil
	if not canReuseGearGrid then
		invGearListSig = ""
		table.clear(invGearCards)
		for _, ch in ipairs(invScroll:GetChildren()) do
			if not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
		end
	end

	sellToggleBtn.Visible = (invLeftTab == "Pets")
	sellToggleBtn.Text = if sellModeActive then "SELL: ON" else "Sell"
	sellToggleBtn.BackgroundColor3 = if sellModeActive then Color3.fromRGB(255, 62, 62) else Color3.fromRGB(212, 36, 36)

	invGrid.CellSize = if (invLeftTab == "Mounts" or invLeftTab == "Gear") then UDim2.fromOffset(132, 134) else UDim2.fromOffset(96, 94)

	if not profile then return end

	if invLeftTab == "Pets" then
		local count = 0
		local q = string.lower(invSearchQuery)
		local sortedPets: { { uid: string, animal: Types.AnimalInstance, name: string, income: number } } = {}
		for uid, animal in pairs(profile.inventoryAnimals) do
			count += 1
			local spec = AnimalConfig.GetById(animal.speciesId)
			local nameStr = spec and spec.name or animal.speciesId
			if q == "" or string.find(string.lower(nameStr), q, 1, true) then
				table.insert(sortedPets, {
					uid = uid,
					animal = animal,
					name = nameStr,
					income = AnimalConfig.ComputeIncomePerSec(animal),
				})
			end
		end
		table.sort(sortedPets, function(a, b) return a.income > b.income end)

		for _, item in ipairs(sortedPets) do
			local uid = item.uid
			local animal = item.animal
			local nameStr = item.name
			local isPinned = isItemPinnedInHotbar(uid) ~= nil
			local isMounted = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") == uid

			local card = Instance.new("TextButton")
			card.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
			card.BackgroundTransparency = 0.25
			card.Text = ""
			card.AutoButtonColor = false
			card.Parent = invScroll
			makeCorner(card, 8)
			local cSt = makeStroke(card, if isMounted or isPinned then 2.2 else 1.4, if isMounted then Color3.fromRGB(84, 255, 132) elseif isPinned then Color3.new(1, 1, 1) else Color3.fromRGB(0, 0, 0))
			cSt.Transparency = if isMounted or isPinned then 0 else 0.35

			local vpBox = Instance.new("Frame")
			vpBox.Size = UDim2.new(1, -12, 0, 56)
			vpBox.Position = UDim2.fromOffset(6, 4)
			vpBox.BackgroundTransparency = 1
			vpBox.Parent = card
			local builderFn = function()
				return AnimalVisualBuilder.BuildAnimalModel(animal.speciesId, 1.0, animal.mutation, true)
			end
			setViewportThumbnail(vpBox, builderFn)

			makeOutlinedLabel(card, nameStr, UDim2.new(1, -6, 0, 16), UDim2.new(0, 3, 1, -34), Color3.new(1, 1, 1), 1.7)
			makeOutlinedLabel(card, string.format("(%sKG)", FormatUtil.Number(math.floor(animal.weightKg + 0.5))), UDim2.new(1, -6, 0, 15), UDim2.new(0, 3, 1, -17), Color3.fromRGB(210, 224, 240), 1.6)

			if animal.locked then
				makeOutlinedLabel(card, "🔒", UDim2.fromOffset(18, 18), UDim2.fromOffset(3, 2), Color3.new(1, 1, 1), 1.4)
			end

			attachDragAndDrop(card, {
				kind = "Pet",
				uid = uid,
				fromSlot = nil,
				label = nameStr,
				builder = builderFn,
				onClick = function()
					if sellModeActive then
						Remotes.Get("SellAnimal"):FireServer(uid)
					else
						assignOrSelectItemInHotbar("Pet", uid)
					end
				end,
			})
		end
		invTitleLbl.Text = if sellModeActive then "Click Pet to Sell" else string.format("All Pets (%d/%d)", count, GameConfig.PEN.MAX_INVENTORY_FREE)

	elseif invLeftTab == "Crates" then
		local q = string.lower(invSearchQuery)
		local cnt = 0
		if type(profile.crateInventory) == "table" then
			for uid, crate in pairs(profile.crateInventory) do
				local sp = AnimalConfig.GetById(crate.speciesId)
				local varIdx = if sp then ((sp.indexNumber % 3) + 1) else 1
				local cTitle = AnimalVisualBuilder.GetCrateVariantInfo(crate.biomeId, crate.rarity, varIdx)
				if q == "" or string.find(string.lower(cTitle .. " " .. crate.rarity), q, 1, true) then
					cnt += 1
					local isPinned = isItemPinnedInHotbar(uid) ~= nil
					local rarCol = GameConfig.RARITY_COLORS[crate.rarity] or Color3.new(1, 1, 1)

					local card = Instance.new("TextButton")
					card.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
					card.BackgroundTransparency = 0.25
					card.Text = ""
					card.AutoButtonColor = false
					card.Parent = invScroll
					makeCorner(card, 8)
					local cSt = makeStroke(card, if isPinned then 2.2 else 1.4, if isPinned then Color3.new(1, 1, 1) else rarCol)
					cSt.Transparency = if isPinned then 0 else 0.35

					local vpBox = Instance.new("Frame")
					vpBox.Size = UDim2.new(1, -12, 0, 56)
					vpBox.Position = UDim2.fromOffset(6, 4)
					vpBox.BackgroundTransparency = 1
					vpBox.Parent = card
					local crRef = crate
					local builderFn = function()
						return AnimalVisualBuilder.BuildCrateModel(crRef.rarity, crRef.biomeId, 1.0, {
							isBuried = false, canCollide = false, showBeacon = false, variant = varIdx,
						})
					end
					setViewportThumbnail(vpBox, builderFn)
					makeOutlinedLabel(card, cTitle, UDim2.new(1, -6, 0, 16), UDim2.new(0, 3, 1, -34), Color3.new(1, 1, 1), 1.7)
					makeOutlinedLabel(card, crate.rarity, UDim2.new(1, -6, 0, 15), UDim2.new(0, 3, 1, -17), rarCol, 1.6)

					attachDragAndDrop(card, {
						kind = "Crate",
						uid = uid,
						fromSlot = nil,
						label = cTitle,
						builder = builderFn,
						onClick = function()
							assignOrSelectItemInHotbar("Crate", uid)
							openModal(nil)
							localPlayer:SetAttribute("ClientToastSeq", (tonumber(localPlayer:GetAttribute("ClientToastSeq")) or 0) + 1)
							localPlayer:SetAttribute("ClientToastText", "Click an open spot inside your Pen to place Crate!")
						end,
					})
				end
			end
		end
		invTitleLbl.Text = string.format("Crates (%d)", cnt)

	elseif invLeftTab == "Mounts" then
		invTitleLbl.Text = "Owned Mounts"
		local activeMountUid = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "")
		local q = string.lower(invSearchQuery)
		local ownedIds: { string } = {}
		local ownedList: { Types.VehicleDefinition } = {}
		for _, v in ipairs(VehicleConfig) do
			if profile.ownedVehicles[v.id] == true and (q == "" or string.find(string.lower(v.name), q, 1, true)) then
				table.insert(ownedIds, v.id)
				table.insert(ownedList, v)
			end
		end
		local listSig = "Mounts|" .. activeMountUid .. "|" .. table.concat(ownedIds, ",")
		if listSig == invGearListSig and #invGearCards > 0 then
			for _, rec in ipairs(invGearCards) do
				local eq = profile.equippedVehicle == rec.id
				rec.btn.Text = if eq then "EQUIPPED" else "EQUIP"
				rec.btn.BackgroundColor3 = if eq then Color3.fromRGB(76, 178, 86) else Color3.fromRGB(48, 138, 224)
				rec.stroke.Thickness = if eq then 2.4 else 1.5
				rec.stroke.Color = if eq then Color3.new(1, 1, 1) else rec.accent
			end
			return
		end

		invGearListSig = listSig
		table.clear(invGearCards)
		for _, ch in ipairs(invScroll:GetChildren()) do
			if not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
		end

		if activeMountUid ~= "" then
			local disBtn = Instance.new("TextButton")
			disBtn.BackgroundColor3 = Color3.fromRGB(168, 52, 42)
			disBtn.BackgroundTransparency = 0.15
			disBtn.Text = "🐎 Dismount\n" .. tostring(localPlayer:GetAttribute("MountedAnimalId") or "Pet")
			disBtn.TextColor3 = Color3.new(1, 1, 1)
			disBtn.Font = Enum.Font.FredokaOne
			disBtn.TextScaled = true
			disBtn.Parent = invScroll
			makeCorner(disBtn, 8)
			makeStroke(disBtn, 1.8)
			makeTextStroke(disBtn, 1.8)
			disBtn.MouseButton1Click:Connect(function()
				playClickSFX()
				Remotes.Get("MountAnimal"):FireServer("")
			end)
		end

		for _, v in ipairs(ownedList) do
			local eq = profile.equippedVehicle == v.id
			local vRef = v
			local card = Instance.new("Frame")
			card.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
			card.BackgroundTransparency = 0.22
			card.Parent = invScroll
			makeCorner(card, 8)
			local cSt = makeStroke(card, if eq then 2.4 else 1.5, if eq then Color3.new(1, 1, 1) else v.primaryColor)

			local vpBox = Instance.new("Frame")
			vpBox.Size = UDim2.new(1, -16, 0, 56)
			vpBox.Position = UDim2.fromOffset(8, 4)
			vpBox.BackgroundTransparency = 1
			vpBox.Parent = card
			setViewportThumbnail(vpBox, function()
				return AnimalVisualBuilder.BuildVehicleModel(vRef, 1.0)
			end)

			makeOutlinedLabel(card, v.name, UDim2.new(1, -8, 0, 17), UDim2.new(0, 4, 0, 62), Color3.new(1, 1, 1), 1.6)
			makeOutlinedLabel(card, string.format("x%s Spd | %d Tow", FormatUtil.Number(v.speedMultiplier), v.towCapacity), UDim2.new(1, -8, 0, 15), UDim2.new(0, 4, 0, 79), v.primaryColor:Lerp(Color3.new(1, 1, 1), 0.35), 1.5)

			local eqBtn = Instance.new("TextButton")
			eqBtn.Size = UDim2.new(1, -14, 0, 26)
			eqBtn.Position = UDim2.new(0, 7, 1, -32)
			eqBtn.BackgroundColor3 = if eq then Color3.fromRGB(76, 178, 86) else Color3.fromRGB(48, 138, 224)
			eqBtn.Text = if eq then "EQUIPPED" else "EQUIP"
			eqBtn.TextColor3 = Color3.new(1, 1, 1)
			eqBtn.Font = Enum.Font.FredokaOne
			eqBtn.TextScaled = true
			eqBtn.Parent = card
			makeCorner(eqBtn, 6)
			makeStroke(eqBtn, 1.6)
			makeTextStroke(eqBtn, 1.5)
			eqBtn.MouseButton1Click:Connect(function()
				playClickSFX()
				if profile and profile.equippedVehicle ~= vRef.id then
					Remotes.Get("EquipVehicle"):FireServer(vRef.id)
				end
			end)
			table.insert(invGearCards, { id = v.id, btn = eqBtn, stroke = cSt, accent = v.primaryColor })
		end

	elseif invLeftTab == "Gear" then
		invTitleLbl.Text = "Owned Lassos"
		local q = string.lower(invSearchQuery)
		local ownedIds: { string } = {}
		local ownedList: { Types.LassoDefinition } = {}
		for _, l in ipairs(LassoConfig) do
			if profile.ownedLassos[l.id] == true and (q == "" or string.find(string.lower(l.name), q, 1, true)) then
				table.insert(ownedIds, l.id)
				table.insert(ownedList, l)
			end
		end
		local listSig = "Gear|" .. table.concat(ownedIds, ",")
		if listSig == invGearListSig and #invGearCards > 0 then
			for _, rec in ipairs(invGearCards) do
				local eq = profile.equippedLasso == rec.id
				rec.btn.Text = if eq then "EQUIPPED" else "EQUIP"
				rec.btn.BackgroundColor3 = if eq then Color3.fromRGB(76, 178, 86) else Color3.fromRGB(48, 138, 224)
				rec.stroke.Thickness = if eq then 2.4 else 1.5
				rec.stroke.Color = if eq then Color3.new(1, 1, 1) else rec.accent
			end
			return
		end

		invGearListSig = listSig
		table.clear(invGearCards)
		for _, ch in ipairs(invScroll:GetChildren()) do
			if not ch:IsA("UIGridLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
		end

		for _, l in ipairs(ownedList) do
			local eq = profile.equippedLasso == l.id
			local lRef = l
			local card = Instance.new("Frame")
			card.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
			card.BackgroundTransparency = 0.22
			card.Parent = invScroll
			makeCorner(card, 8)
			local cSt = makeStroke(card, if eq then 2.4 else 1.5, if eq then Color3.new(1, 1, 1) else l.beamColor)

			local vpBox = Instance.new("Frame")
			vpBox.Size = UDim2.new(1, -16, 0, 56)
			vpBox.Position = UDim2.fromOffset(8, 4)
			vpBox.BackgroundTransparency = 1
			vpBox.Parent = card
			setViewportThumbnail(vpBox, function()
				return AnimalVisualBuilder.BuildLassoModel(lRef.beamColor, 1.2)
			end)

			makeOutlinedLabel(card, l.name, UDim2.new(1, -8, 0, 17), UDim2.new(0, 4, 0, 62), Color3.new(1, 1, 1), 1.6)
			makeOutlinedLabel(card, string.format("⚡ %s | %dm", FormatUtil.Number(l.pullPower), l.maxRange), UDim2.new(1, -8, 0, 15), UDim2.new(0, 4, 0, 79), l.beamColor:Lerp(Color3.new(1, 1, 1), 0.3), 1.5)

			local eqBtn = Instance.new("TextButton")
			eqBtn.Size = UDim2.new(1, -14, 0, 26)
			eqBtn.Position = UDim2.new(0, 7, 1, -32)
			eqBtn.BackgroundColor3 = if eq then Color3.fromRGB(76, 178, 86) else Color3.fromRGB(48, 138, 224)
			eqBtn.Text = if eq then "EQUIPPED" else "EQUIP"
			eqBtn.TextColor3 = Color3.new(1, 1, 1)
			eqBtn.Font = Enum.Font.FredokaOne
			eqBtn.TextScaled = true
			eqBtn.Parent = card
			makeCorner(eqBtn, 6)
			makeStroke(eqBtn, 1.6)
			makeTextStroke(eqBtn, 1.5)
			eqBtn.MouseButton1Click:Connect(function()
				playClickSFX()
				if profile and profile.equippedLasso ~= lRef.id then
					Remotes.Get("EquipLasso"):FireServer(lRef.id)
				end
			end)
			table.insert(invGearCards, { id = l.id, btn = eqBtn, stroke = cSt, accent = l.beamColor })
		end
	end
end
renderInventoryModalRef = renderInventoryModal

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

-- D. SETTINGS MODAL (Screenshot 10 — Silver Header + Sliders + Switches + Graphics Quality)
local settingsWindow = Instance.new("Frame")
settingsWindow.Name = "SettingsModal"
settingsWindow.AnchorPoint = Vector2.new(0.5, 0.5)
settingsWindow.Size = UDim2.fromOffset(540, 425)
settingsWindow.Position = UDim2.fromScale(0.5, 0.5)
settingsWindow.BackgroundColor3 = Color3.fromRGB(36, 38, 44)
settingsWindow.Visible = false
settingsWindow.Parent = gui
makeCorner(settingsWindow, 12)
makeStroke(settingsWindow, 3)

makeWindowHeader(settingsWindow, "Settings", Color3.fromRGB(236, 240, 246), Color3.fromRGB(132, 138, 152), function()
	playClickSFX()
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
		playClickSFX()
		viewCratesEnabled = not viewCratesEnabled
		Remotes.Get("UpdateSettings"):FireServer({ lowVFX = not viewCratesEnabled })
		renderSettingsModal()
	end)

	-- Graphics Quality Cyclic Row (Low | Medium | High)
	local gRow = Instance.new("Frame")
	gRow.Name = "GraphicsQualityRow"
	gRow.Size = UDim2.new(0.96, 0, 0, 52)
	gRow.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
	gRow.Parent = settingsBody
	makeCorner(gRow, 6)
	makeStroke(gRow, 2)

	makeOutlinedLabel(gRow, "Graphics Quality", UDim2.fromOffset(180, 26), UDim2.fromOffset(10, 4), Color3.new(1, 1, 1), 2.2).TextXAlignment = Enum.TextXAlignment.Left
	makeOutlinedLabel(gRow, "Colors, Bloom & VFX!", UDim2.fromOffset(180, 16), UDim2.fromOffset(10, 30), Color3.fromRGB(210, 215, 224), 1.6).TextXAlignment = Enum.TextXAlignment.Left

	local gVal = tostring((s :: any).graphicsQuality or "Medium")
	local gBtn = Instance.new("TextButton")
	gBtn.Name = "GraphicsQualityButton"
	gBtn.Size = UDim2.fromOffset(132, 34)
	gBtn.Position = UDim2.new(1, -144, 0.5, -17)
	gBtn.BackgroundColor3 = if gVal == "High" then Color3.fromRGB(72, 206, 88) elseif gVal == "Medium" then Color3.fromRGB(64, 152, 232) else Color3.fromRGB(168, 124, 52)
	gBtn.Text = string.upper(gVal)
	gBtn.TextColor3 = Color3.new(1, 1, 1)
	gBtn.Font = Enum.Font.FredokaOne
	gBtn.TextScaled = true
	gBtn.Parent = gRow
	makeCorner(gBtn, 6)
	makeStroke(gBtn, 2)
	makeTextStroke(gBtn, 1.8)
	gBtn.MouseButton1Click:Connect(function()
		playClickSFX()
		local nextVal = if gVal == "Low" then "Medium" elseif gVal == "Medium" then "High" else "Low"
		if profile and type(profile.settings) == "table" then
			(profile.settings :: any).graphicsQuality = nextVal
		end
		Remotes.Get("UpdateSettings"):FireServer({ graphicsQuality = nextVal })
		renderSettingsModal()
	end)
end

-- Master Modal Switcher
renderActiveModal = function()
	shopWindow.Visible = (currentModal == "Shop")
	trailsWindow.Visible = (currentModal == "Trails")
	lassosWindow.Visible = (currentModal == "Lassos")
	vehiclesWindow.Visible = (currentModal == "Vehicles")
	fuseWindow.Visible = (currentModal == "Fuse")
	rebirthWindow.Visible = (currentModal == "Rebirth")
	indexWindow.Visible = (currentModal == "Index")
	invWindow.Visible = (currentModal == "Inventory")
	settingsWindow.Visible = (currentModal == "Settings")
	local showRightHud = (currentModal ~= "Inventory")
	rightDrawerWrap.Visible = showRightHud
	rightEdgeBtns.Visible = showRightHud

	if currentModal == "Shop" then renderShopModal()
	elseif currentModal == "Trails" then renderTrailsModal()
	elseif currentModal == "Lassos" then renderLassosModal()
	elseif currentModal == "Vehicles" then renderVehiclesModal()
	elseif currentModal == "Fuse" then renderFuseModal()
	elseif currentModal == "Rebirth" then renderRebirthModal()
	elseif currentModal == "Index" then renderIndexModal()
	elseif currentModal == "Inventory" then renderInventoryModal()
	elseif currentModal == "Settings" then renderSettingsModal() end
	refreshMountButton()
end

-- Bind Buttons & Hotbar Slots
rebirthBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal("Rebirth")
end)
shopBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal("Shop")
end)
indexBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal("Index")
end)
backpackTopBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal("Inventory")
end)
settingsTopBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal("Settings")
end)
speedIconBtn.MouseButton1Click:Connect(function()
	playClickSFX()
	openModal("Trails")
end)

renderHotbar()
refreshMountButton()

local HOTBAR_KEYCODES: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

-- Keyboard shortcuts for 10-slot hotbar (1-9, 0) + Backquote (`) Backpack toggle
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.Backquote then
		playClickSFX()
		openModal("Inventory")
		return
	end
	local idx = HOTBAR_KEYCODES[inp.KeyCode]
	if idx then
		selectHotbarSlot(idx)
	end
end)

local refreshSpeedAndCashDisplay: () -> ()

localPlayer.AttributeChanged:Connect(function(attrName)
	if attrName == "IsRidingVehicle" or attrName == "MountedAnimalUid" or attrName == "MountedAnimalId" or attrName == "MountedAnimalMutation" or attrName == "TowedCrateCount" then
		refreshMountButton()
		if refreshSpeedAndCashDisplay then
			refreshSpeedAndCashDisplay()
		end
	elseif attrName == "ClearHeldSlotRequest" then
		selectedHotbarSlot = 0
		selectedCustomCrateUid = nil
		refreshHotbarSelectionVisuals()
		syncHeldItemFromHotbar()
		refreshMountButton()
	elseif attrName == "ClientToastSeq" then
		local msg = tostring(localPlayer:GetAttribute("ClientToastText") or "")
		if msg ~= "" then
			toastLbl.Text = msg
			toastLbl.TextColor3 = Color3.fromRGB(255, 196, 62)
			toastLbl.Visible = true
			task.delay(3.5, function()
				if toastLbl.Text == msg then
					toastLbl.Visible = false
				end
			end)
		end
	elseif attrName == "EffectiveSpeedStat" or attrName == "TotalSpeedMult" or attrName == "BaseSpeedMult" or attrName == "VehicleSpeedMult" then
		if refreshSpeedAndCashDisplay then
			refreshSpeedAndCashDisplay()
		end
	end
end)

Remotes.Get("PoacherAlertSync").OnClientEvent:Connect(function(active)
	isPoacherChasing = (active == true)
end)

-- Open matching standalone modal when Hub ProximityPrompts trigger (NOT one merged universal shop)
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= localPlayer then return end
	if prompt.Name == "LassoShopPrompt" then
		currentModal = "Lassos"; renderActiveModal()
	elseif prompt.Name == "TrailShopPrompt" then
		currentModal = "Trails"; renderActiveModal()
	elseif prompt.Name == "VehicleShopPrompt" then
		currentModal = "Vehicles"; renderActiveModal()
	elseif prompt.Name == "FusePrompt" then
		fusePickerSlot = nil
		currentModal = "Fuse"; renderActiveModal()
	elseif prompt.Name == "RebirthPrompt" then
		currentModal = "Rebirth"; renderActiveModal()
	elseif prompt.Name == "IndexPrompt" then
		currentModal = "Index"; renderActiveModal()
	end
end)

-- ============================================================================
-- 7. REMOTES, FLOATING POPUPS, YOUR BASE MARKER & REALTIME TELEMETRY LOOP
-- ============================================================================
local currentPenIncome = 0
local currentSpeedMult = 1.0

local function spawnFloatingStepPop(gain: number, totalMult: number?, isTreadmill: boolean?)
	if profile and profile.settings and profile.settings.lowVFX then
		return
	end
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "StepPopVFX"
	bb.Size = UDim2.fromOffset(175, 42)
	local rx = (math.random(-24, 24)) / 10
	local ry = (math.random(18, 34)) / 10
	local rz = (math.random(-12, 12)) / 10
	bb.StudsOffsetWorldSpace = Vector3.new(rx, ry, rz)
	bb.AlwaysOnTop = true
	bb.Active = false
	bb.Parent = root

	local multTag = if totalMult and totalMult > 1.005 then string.format(" (x%s)", FormatUtil.Multiplier(totalMult)) else ""
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.format("+%s 👟%s", FormatUtil.Number(gain), multTag)
	lbl.TextColor3 = if isTreadmill then Color3.fromRGB(92, 198, 255) else Color3.fromRGB(118, 248, 132)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb

	local st = Instance.new("UIStroke")
	st.Thickness = 2.6
	st.Color = Color3.fromRGB(12, 14, 18)
	st.Parent = lbl

	TweenService:Create(bb, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(rx, ry + 3.4, rz),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(st, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	task.delay(0.9, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local function spawnFloatingCashPop(amount: number)
	if amount <= 0 then return end
	local pop = Instance.new("TextLabel")
	pop.Name = "FloatingCashPop"
	pop.Size = UDim2.fromOffset(145, 24)
	local rx = math.random(-4, 14)
	local baseX = 38 + rx
	pop.Position = UDim2.fromOffset(baseX, -2)
	pop.BackgroundTransparency = 1
	pop.Text = "+$" .. FormatUtil.Number(amount)
	pop.TextColor3 = Color3.fromRGB(118, 255, 112)
	pop.Font = Enum.Font.FredokaOne
	pop.TextScaled = true
	pop.TextXAlignment = Enum.TextXAlignment.Left
	pop.ZIndex = 12
	pop.Parent = statsCorner
	local st = makeTextStroke(pop, 2.2)

	TweenService:Create(pop, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(baseX, -34),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(st, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	task.delay(0.9, function()
		if pop.Parent then
			pop:Destroy()
		end
	end)
end

-- Floating "Your Base" Hologram Marker over Player's Owned Plot
local yourBaseAnchor = Instance.new("Part")
yourBaseAnchor.Name = "YourBaseMarkerAnchor"
yourBaseAnchor.Size = Vector3.new(1, 1, 1)
yourBaseAnchor.Anchored = true
yourBaseAnchor.CanCollide = false
yourBaseAnchor.CanQuery = false
yourBaseAnchor.Transparency = 1
yourBaseAnchor.Parent = Workspace

local yourBaseGui = Instance.new("BillboardGui")
yourBaseGui.Name = "YourBaseBillboard"
yourBaseGui.Size = UDim2.fromOffset(145, 95)
yourBaseGui.AlwaysOnTop = true
yourBaseGui.Active = false
yourBaseGui.MaxDistance = 550
yourBaseGui.Enabled = false
yourBaseGui.Parent = yourBaseAnchor

local ybIcon = Instance.new("TextLabel")
ybIcon.Size = UDim2.fromScale(1, 0.62)
ybIcon.BackgroundTransparency = 1
ybIcon.Text = "🏠"
ybIcon.TextColor3 = Color3.fromRGB(82, 188, 255)
ybIcon.TextScaled = true
ybIcon.Parent = yourBaseGui

local ybText = Instance.new("TextLabel")
ybText.Size = UDim2.fromScale(1, 0.36)
ybText.Position = UDim2.fromScale(0, 0.62)
ybText.BackgroundTransparency = 1
ybText.Text = "Your Base"
ybText.TextColor3 = Color3.new(1, 1, 1)
ybText.Font = Enum.Font.FredokaOne
ybText.TextScaled = true
ybText.Parent = yourBaseGui
local ybStroke = Instance.new("UIStroke")
ybStroke.Thickness = 2.8
ybStroke.Color = Color3.fromRGB(12, 14, 18)
ybStroke.Parent = ybText

local lastDrawerSig = ""
local lastHotbarSig = ""
local lastModalContentSig = ""

local function computeProfileUISignatures(p: Types.PlayerProfileSchema): (string, string, string)
	local invCount = 0
	for _ in pairs(p.inventoryAnimals) do invCount += 1 end
	local crateCount = 0
	for _ in pairs(p.pendingCrates) do crateCount += 1 end
	local invCrateCount = 0
	local invCrateUids = {}
	if type(p.crateInventory) == "table" then
		for uid in pairs(p.crateInventory) do
			invCrateCount += 1
			table.insert(invCrateUids, uid)
		end
		table.sort(invCrateUids)
	end
	local discCount, claimedIdxCount, ownedTrailCount = 0, 0, 0
	for _, de in pairs(p.discoveredIndex) do
		discCount += 1
		if de.rewardClaimed then claimedIdxCount += 1 end
	end
	for _, owned in pairs(p.ownedTrails) do
		if owned then ownedTrailCount += 1 end
	end
	local roamStr = table.concat(p.roamingAnimalUids, ",")
	local crateSigStr = table.concat(invCrateUids, ",")
	local drawerSig = string.format("%s|%d|%d|%d|%d", roamStr, p.penCapacity, crateCount, invCount, invCrateCount)
	local hotbarSig = string.format("%s|%s|%d|%s|%s", p.equippedLasso, p.equippedVehicle, invCount, roamStr, crateSigStr)
	local modalSig = string.format("%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%s|%s",
		p.equippedLasso, p.equippedTrail, p.equippedVehicle, invCount, crateCount, invCrateCount, p.rebirths,
		discCount, claimedIdxCount, ownedTrailCount,
		tostring(p.settings and (p.settings :: any).graphicsQuality), tostring(p.settings and p.settings.lowVFX)
	)
	return drawerSig, hotbarSig, modalSig
end

refreshSpeedAndCashDisplay = function()
	if not profile then return end
	local trailMult = 1.0
	for _, t in ipairs(TrailConfig) do
		if t.id == profile.equippedTrail then trailMult = t.speedMultiplier break end
	end
	local isRidingVeh = localPlayer:GetAttribute("IsRidingVehicle") == true
	local vehMult = findVehicleDefById(profile.equippedVehicle).speedMultiplier

	local baseMultAttr = tonumber(localPlayer:GetAttribute("BaseSpeedMult"))
	local baseMult = if baseMultAttr and baseMultAttr > 0 then baseMultAttr else trailMult
	local effectiveMult = baseMult + (if isRidingVeh then vehMult else 0)
	local displayedSpeed = profile.speedStat * (if isRidingVeh then vehMult else 1)

	-- Prefer authoritative server EffectiveSpeedStat when vehicle state matches
	local srvEffective = tonumber(localPlayer:GetAttribute("EffectiveSpeedStat"))
	if srvEffective and math.abs(srvEffective - displayedSpeed) <= math.max(1, displayedSpeed * 0.01) then
		displayedSpeed = srvEffective
	end

	currentSpeedMult = effectiveMult
	speedValLbl.Text = FormatUtil.Number(displayedSpeed)
	speedMultLbl.Text = "(x" .. FormatUtil.Multiplier(effectiveMult) .. ")"
	cashValLbl.Text = "$" .. FormatUtil.Number(profile.coins)
end

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(newProfile)
	if type(newProfile) ~= "table" then return end
	if profile and newProfile.speedStat > lastSpeedStat then
		lastStepGain = newProfile.speedStat - lastSpeedStat
	end
	lastSpeedStat = newProfile.speedStat
	profile = newProfile

	local penIncome = 0
	for _, uid in ipairs(newProfile.roamingAnimalUids) do
		local a = newProfile.inventoryAnimals[uid]
		if a then penIncome += AnimalConfig.ComputeIncomePerSec(a) end
	end
	currentPenIncome = penIncome

	refreshSpeedAndCashDisplay()

	local dSig, hSig, mSig = computeProfileUISignatures(newProfile)
	if dSig ~= lastDrawerSig then
		lastDrawerSig = dSig
		renderRightDrawer()
	end
	if hSig ~= lastHotbarSig then
		lastHotbarSig = hSig
		renderHotbar()
	end
	refreshMountButton()
	if currentModal and mSig ~= lastModalContentSig then
		lastModalContentSig = mSig
		renderActiveModal()
	elseif mSig ~= lastModalContentSig then
		lastModalContentSig = mSig
	end
end)

Remotes.Get("TrainingPulse").OnClientEvent:Connect(function(gain, totalMult, isTreadmill)
	if type(gain) == "number" then
		local multShown = if type(totalMult) == "number" then totalMult else currentSpeedMult
		spawnFloatingStepPop(gain, multShown, isTreadmill == true)
	end
end)

Remotes.Get("CrateDelivered").OnClientEvent:Connect(function(deliveredCount, firstCrateUid)
	local cnt = tonumber(deliveredCount) or 1
	local msg = if cnt > 1 then string.format("You saved %d Animals!", cnt) else "You saved the Animal!"
	rescueSuccessLbl.Text = msg
	rescueSuccessLbl.Visible = true
	task.delay(3.0, function()
		if rescueSuccessLbl.Text == msg then
			rescueSuccessLbl.Visible = false
		end
	end)

	-- Keep the rescued crate visibly held in hand & ensure it's in the bottom hotbar
	if type(firstCrateUid) == "string" and firstCrateUid ~= "" then
		task.defer(function()
			local pinned = isItemPinnedInHotbar(firstCrateUid)
			if not pinned then
				local targetS: number? = nil
				for s = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
					if not customHotbarPins[s] then
						targetS = s
						break
					end
				end
				if not targetS then
					targetS = CUSTOM_SLOT_MAX
				end
				customHotbarPins[targetS :: number] = { kind = "Crate", uid = firstCrateUid }
				knownPinUids[firstCrateUid] = true
				pinned = targetS
				renderHotbar()
			end
			if pinned then
				selectedCustomCrateUid = nil
				selectedHotbarSlot = pinned
				refreshHotbarSelectionVisuals()
				syncHeldItemFromHotbar()
				refreshMountButton()
			end
		end)
	end
end)

local liveWavePhase = "OPEN"
local liveWaveEndsAt = os.time() + 300
Remotes.Get("BiomeWaveSync").OnClientEvent:Connect(function(info)
	if type(info) == "table" then
		if type(info.phase) == "string" then
			liveWavePhase = info.phase
		end
		if type(info.endsAt) == "number" then
			liveWaveEndsAt = info.endsAt
		elseif type(info.remainingSec) == "number" then
			liveWaveEndsAt = os.time() + info.remainingSec
		end
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
	local col = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 214, 64)
	eventBanner.Text = tostring(msg)
	eventBanner.TextColor3 = col
	eventBannerStroke.Color = col
	eventBanner.Visible = true
	task.delay(tonumber(duration) or 8, function()
		if eventBanner.Text == tostring(msg) then eventBanner.Visible = false end
	end)
end)

local crateAnnounceQueue: { { msg: string, color: Color3 } } = {}
local crateAnnounceRunning = false

local function updateCrateAnnouncePosition()
	if not crateAnnounceLbl.Visible then return end
	local targetY = 72
	if rescueSuccessLbl.Visible or (eventBanner.Visible and toastLbl.Visible) then
		targetY = 146
	elseif runAlertBanner.Visible then
		targetY = 130
	elseif eventBanner.Visible or toastLbl.Visible then
		targetY = 112
	end
	crateAnnounceLbl.Position = UDim2.new(0.5, 0, 0, targetY)
end

local function processCrateAnnounceQueue()
	if crateAnnounceRunning then return end
	crateAnnounceRunning = true
	task.spawn(function()
		while #crateAnnounceQueue > 0 do
			local item = table.remove(crateAnnounceQueue, 1)
			if item then
				crateAnnounceLbl.Text = item.msg
				crateAnnounceLbl.TextColor3 = item.color
				crateAnnounceLbl.TextTransparency = 1
				if crateAnnounceStroke then
					crateAnnounceStroke.Transparency = 1
				end
				crateAnnounceLbl.Visible = true
				updateCrateAnnouncePosition()

				TweenService:Create(crateAnnounceLbl, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				}):Play()
				if crateAnnounceStroke then
					TweenService:Create(crateAnnounceStroke, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Transparency = 0,
					}):Play()
				end

				local holdSec = if #crateAnnounceQueue > 0 then 2.3 else 3.8
				task.wait(holdSec)

				TweenService:Create(crateAnnounceLbl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TextTransparency = 1,
				}):Play()
				if crateAnnounceStroke then
					TweenService:Create(crateAnnounceStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Transparency = 1,
					}):Play()
				end
				task.wait(0.27)
			end
		end
		crateAnnounceLbl.Visible = false
		crateAnnounceRunning = false
	end)
end

Remotes.Get("CrateSpawnAnnounce").OnClientEvent:Connect(function(payload, fallbackColor)
	local msg = ""
	local col = Color3.fromRGB(255, 224, 92)
	if type(payload) == "table" then
		msg = tostring(payload.message or "")
		if typeof(payload.color) == "Color3" then
			col = payload.color
		end
	else
		msg = tostring(payload)
		if typeof(fallbackColor) == "Color3" then
			col = fallbackColor
		end
	end
	if msg == "" then return end
	if #crateAnnounceQueue >= 6 then
		table.remove(crateAnnounceQueue, 1)
	end
	table.insert(crateAnnounceQueue, { msg = msg, color = col })
	processCrateAnnounceQueue()
end)

-- Biome Entry Detection + Shop Green-Zone Auto Open/Close + RUN! Danger Vignette Pulse
local checkAccum = 0
local secAccum = 0

RunService.Heartbeat:Connect(function(dt: number)
	checkAccum += dt
	secAccum += dt
	updateCrateAnnouncePosition()

	local carryingCrates = (tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0) > 0
	local inDanger = isPoacherChasing or carryingCrates
	runVignette.Visible = inDanger
	runAlertBanner.Visible = inDanger
	if inDanger then
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 7.5)
		local edgeAlpha = 0.10 + pulse * 0.28
		for _, strip in ipairs(runEdgeStrips) do
			strip.bar.BackgroundTransparency = edgeAlpha
		end
		runAlertBanner.BackgroundColor3 = Color3.fromRGB(72 + math.round(pulse * 58), 42, 54)
	end

	-- Fast Shop StandZone auto-open & auto-close (direct scan handles StreamingEnabled instantly!)
	if checkAccum < 0.14 then return end
	checkAccum = 0

	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local gw = Workspace:FindFirstChild("GameWorld")
		local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
		local activeZoneModal: string? = nil
		if hub then
			for _, ch in ipairs(hub:GetChildren()) do
				if ch:IsA("BasePart") then
					local modalTag = ch:GetAttribute("ShopZoneModal")
					if type(modalTag) == "string" then
						local rad = tonumber(ch:GetAttribute("ShopZoneRadius")) or 5.5
						local dx = root.Position.X - ch.Position.X
						local dz = root.Position.Z - ch.Position.Z
						if math.sqrt(dx * dx + dz * dz) <= rad and math.abs(root.Position.Y - ch.Position.Y) <= 10 then
							activeZoneModal = modalTag
							break
						end
					end
				end
			end
		end
		if activeZoneModal then
			if dismissedStandZoneModal ~= activeZoneModal and currentModal ~= activeZoneModal then
				lastAutoZoneModal = activeZoneModal
				openModal(activeZoneModal, true)
			elseif currentModal == activeZoneModal then
				lastAutoZoneModal = activeZoneModal
			end
		else
			if lastAutoZoneModal and currentModal == lastAutoZoneModal then
				openModal(nil, true)
			end
			lastAutoZoneModal = nil
			dismissedStandZoneModal = nil
		end
	end

	if secAccum >= 1.0 then
		secAccum = 0
		if currentPenIncome > 0 then
			spawnFloatingCashPop(currentPenIncome)
		end
		local gw = Workspace:FindFirstChild("GameWorld")
		local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
		local plots = if hub then hub:FindFirstChild("Plots") else nil
		local foundPlot: Model? = nil
		if plots then
			for _, pm in ipairs(plots:GetChildren()) do
				if pm:IsA("Model") and pm:GetAttribute("OwnerUserId") == localPlayer.UserId then
					foundPlot = pm
					break
				end
			end
		end
		if foundPlot then
			local targetAnchorPart = (foundPlot:FindFirstChild("OpenPaddockFloor") or foundPlot.PrimaryPart) :: BasePart?
			if targetAnchorPart then
				yourBaseAnchor.Position = targetAnchorPart.Position + Vector3.new(0, 21, 0)
				yourBaseGui.Enabled = true
			else
				yourBaseGui.Enabled = false
			end
		else
			yourBaseGui.Enabled = false
		end
	end

	local rem = math.max(0, liveWaveEndsAt - os.time())
	local mins = math.floor(rem / 60)
	local secs = rem % 60
	if liveWavePhase == "RESETTING" then
		timerLbl.Text = string.format("Gate: %02d:%02d", mins, secs)
		timerLbl.TextColor3 = Color3.fromRGB(255, 118, 92)
	else
		timerLbl.Text = string.format("In: %02d:%02d", mins, secs)
		timerLbl.TextColor3 = Color3.new(1, 1, 1)
	end

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
			local disp = BIOME_BANNER_DISPLAY[foundBiome.id] or { title = foundBiome.name, emoji = "⚠️" }
			biomeTitleLbl.Text = string.format("%s %s", disp.title, disp.emoji)
			biomeTitleLbl.TextColor3 = foundBiome.accentColor:Lerp(Color3.new(1, 1, 1), 0.55)
			biomeRecLbl.Text = string.format("Recommended: 👟 <font color=\"#52E0FF\">%s Speed</font>", FormatUtil.Number(foundBiome.recommendedSpeed))
		else
			biomeBanner.Visible = false
		end
	end
end)

-- ============================================================================
-- 10. RESPONSIVE UI SCALING (Prevents Overlap & Oversized HUD Across Screens)
-- ============================================================================
local hudScaleTargets: { GuiObject } = {
	topLeftRow,
	biomeBanner,
	eventBanner,
	crateAnnounceLbl,
	runAlertBanner,
	rescueSuccessLbl,
	toastLbl,
	leftStack,
	statsCorner,
	rightEdgeBtns,
	rightDrawerWrap,
	bottomCenterHud,
	eventTimerBox,
}

local modalScaleTargets: { GuiObject } = {
	shopWindow,
	trailsWindow,
	lassosWindow,
	vehiclesWindow,
	fuseWindow,
	rebirthWindow,
	indexWindow,
	invWindow,
	settingsWindow,
}

local function ensureUiScale(target: GuiObject): UIScale
	local existing = target:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local s = Instance.new("UIScale")
	s.Name = "ResponsiveScale"
	s.Parent = target
	return s
end

local function updateResponsiveScales()
	local cam = Workspace.CurrentCamera
	local vp = gui.AbsoluteSize
	if vp.X < 100 or vp.Y < 100 then
		vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	end
	if vp.X < 100 or vp.Y < 100 then
		vp = Vector2.new(1280, 720)
	end
	local hudScale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.52, 1.15)
	local modalScale = math.clamp(math.min((vp.X - 36) / 720, (vp.Y - 36) / 480), 0.44, 1.15)

	for _, target in ipairs(hudScaleTargets) do
		ensureUiScale(target).Scale = hudScale
	end
	for _, modal in ipairs(modalScaleTargets) do
		ensureUiScale(modal).Scale = modalScale
	end

	-- Reposition stacked/sibling containers relative to the live HUD scale
	eventBanner.Position = UDim2.new(0.5, 0, 0, math.round(8 + 62 * hudScale))
	rescueSuccessLbl.Position = UDim2.new(0.5, 0, 0, math.round(8 + 88 * hudScale))
	toastLbl.Position = UDim2.new(0.5, 0, 0, math.round(8 + 100 * hudScale))
	rightDrawerWrap.Position = UDim2.new(1, -math.round(10 + 52 * hudScale), 0.45, 0)
	invWindow.Position = UDim2.new(0.5, 0, 1, -math.round(22 + 70 * hudScale))
end

local activeViewportConn: RBXScriptConnection? = nil
local function bindCameraViewportSignal()
	if activeViewportConn then
		activeViewportConn:Disconnect()
		activeViewportConn = nil
	end
	local cam = Workspace.CurrentCamera
	if cam then
		activeViewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScales)
	end
	updateResponsiveScales()
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveScales)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraViewportSignal)
bindCameraViewportSignal()
task.defer(updateResponsiveScales)
