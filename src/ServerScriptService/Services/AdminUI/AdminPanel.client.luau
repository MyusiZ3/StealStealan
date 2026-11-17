--!strict
-- AdminPanel.client.luau (PROVISIONED SERVER-SIDE ONLY via ServerScriptService.Services.AdminUI)
-- Server-cloned into PlayerGui exclusively for verified Rank >= 2 Admin / Owner players.
-- Features: Global Live Search across all tools/events/pets, Custom Event Duration (seconds),
-- Full Moderation/Economy/Spawn/Rates/Abuse/Self-Tools suite, and live 1s countdown updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local WorkspaceService = game:GetService("Workspace")

local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local adminState: any = {
	rank = 0,
	title = "",
	isRoot = false,
	activeEvents = {},
	eventsCatalog = {},
	liveTuners = {},
	selfTools = {},
	players = {},
}

local uiState = {
	activeTab = "Mod",
	searchQuery = "",
	selectedTargetUserId = localPlayer.UserId,
	selectedBiomeIdx = 1,
	selectedRarityIdx = 5, -- Legendary
	selectedSpeciesIdx = #AnimalConfig.ALL,
	useSelectedSpeciesForCrate = false,
	selectedMutationIdx = 6, -- Rainbow
	selectedSizeRatio = 2.5,
	selectedRateRarityIdx = 15, -- Primordial
	selectedRateMutIdx = 14, -- Celestial
	customEventSeconds = 120,
	useDefaultEventDuration = false,
}

local RARITIES: { string } = GameConfig.RARITY_ORDER

local C = {
	ModalBg = Color3.fromRGB(18, 22, 33),
	PanelBg = Color3.fromRGB(12, 15, 24),
	CardBg = Color3.fromRGB(26, 32, 48),
	CardStroke = Color3.fromRGB(46, 56, 82),
	InputBg = Color3.fromRGB(14, 18, 28),
	TabIdle = Color3.fromRGB(30, 36, 54),
	TextMain = Color3.fromRGB(244, 247, 252),
	TextMuted = Color3.fromRGB(148, 163, 184),
	AccentBlue = Color3.fromRGB(37, 99, 235),
	AccentGreen = Color3.fromRGB(22, 163, 74),
	AccentRed = Color3.fromRGB(204, 42, 54),
	AccentAmber = Color3.fromRGB(202, 138, 4),
	AccentPurple = Color3.fromRGB(126, 34, 206),
	AccentTeal = Color3.fromRGB(13, 148, 136),
	AccentPink = Color3.fromRGB(219, 39, 119),
}

local function addPad(inst: Instance, px: number, py: number?)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	if py and py > 0 then
		p.PaddingTop = UDim.new(0, py)
		p.PaddingBottom = UDim.new(0, py)
	end
	p.Parent = inst
end

local function addStroke(inst: Instance, thickness: number, color: Color3): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local gui: ScreenGui
if script.Parent and script.Parent:IsA("ScreenGui") then
	gui = script.Parent
	gui.DisplayOrder = 20
else
	gui = Instance.new("ScreenGui")
	gui.Name = "AdminControlPanel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Parent = playerGui
end

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "AdminToggleButton"
toggleBtn.AnchorPoint = Vector2.new(1, 0)
toggleBtn.Size = UDim2.fromOffset(132, 32)
toggleBtn.Position = UDim2.new(1, -12, 0, 10)
toggleBtn.BackgroundColor3 = C.AccentPink
toggleBtn.Text = "ADMIN (F2)"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.FredokaOne
toggleBtn.TextSize = 15
toggleBtn.Visible = false
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
addStroke(toggleBtn, 1.8, Color3.fromRGB(12, 14, 20))
local toggleScale = Instance.new("UIScale")
toggleScale.Name = "ResponsiveScale"
toggleScale.Parent = toggleBtn

local frame = Instance.new("Frame")
frame.Name = "AdminModalFrame"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromOffset(700, 526)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = C.ModalBg
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
local fStroke = addStroke(frame, 2, C.CardStroke)

local frameScale = Instance.new("UIScale")
frameScale.Name = "ResponsiveScale"
frameScale.Parent = frame

do
	local vpConn: RBXScriptConnection? = nil
	local function updateAdminScale()
		local cam = WorkspaceService.CurrentCamera
		local vp = gui.AbsoluteSize
		if vp.X < 100 or vp.Y < 100 then
			vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		end
		if vp.X < 100 or vp.Y < 100 then
			vp = Vector2.new(1280, 720)
		end
		toggleScale.Scale = math.clamp(math.min(vp.X / 1366, vp.Y / 768), 0.45, 1.15)
		frameScale.Scale = math.clamp(math.min((vp.X - 36) / 740, (vp.Y - 36) / 560), 0.45, 1.12)
	end
	local function bindAdminCamera()
		if vpConn then
			vpConn:Disconnect()
			vpConn = nil
		end
		local cam = WorkspaceService.CurrentCamera
		if cam then
			vpConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateAdminScale)
		end
		updateAdminScale()
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateAdminScale)
	WorkspaceService:GetPropertyChangedSignal("CurrentCamera"):Connect(bindAdminCamera)
	bindAdminCamera()
	task.defer(updateAdminScale)
end

-- Header Bar
local title = Instance.new("TextLabel")
title.Name = "HeaderTitle"
title.Size = UDim2.new(1, -68, 0, 30)
title.Position = UDim2.fromOffset(14, 8)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SERVER ADMIN PANEL"
title.TextColor3 = Color3.fromRGB(255, 208, 72)
title.Font = Enum.Font.FredokaOne
title.TextSize = 20
title.TextTruncate = Enum.TextTruncate.AtEnd
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseAdminModal"
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -40, 0, 9)
closeBtn.BackgroundColor3 = C.AccentRed
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 15
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)
closeBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Global Search Bar (searches across ALL tabs, events, tools, and pets)
local searchBarFrame = Instance.new("Frame")
searchBarFrame.Name = "AdminSearchBar"
searchBarFrame.Size = UDim2.new(1, -28, 0, 32)
searchBarFrame.Position = UDim2.fromOffset(14, 42)
searchBarFrame.BackgroundColor3 = C.InputBg
searchBarFrame.Parent = frame
Instance.new("UICorner", searchBarFrame).CornerRadius = UDim.new(0, 8)
local searchStroke = addStroke(searchBarFrame, 1.3, C.CardStroke)

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.fromOffset(28, 32)
searchIcon.Position = UDim2.fromOffset(4, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextSize = 14
searchIcon.TextColor3 = C.TextMuted
searchIcon.Parent = searchBarFrame

local searchInput = Instance.new("TextBox")
searchInput.Name = "SearchInput"
searchInput.Size = UDim2.new(1, -68, 1, 0)
searchInput.Position = UDim2.fromOffset(32, 0)
searchInput.BackgroundTransparency = 1
searchInput.PlaceholderText = "Cari tool, event (x2 cash, speed), pet, crate, ban..."
searchInput.PlaceholderColor3 = C.TextMuted
searchInput.Text = ""
searchInput.ClearTextOnFocus = false
searchInput.TextXAlignment = Enum.TextXAlignment.Left
searchInput.TextColor3 = C.TextMain
searchInput.Font = Enum.Font.GothamBold
searchInput.TextSize = 13
searchInput.Parent = searchBarFrame

local clearSearchBtn = Instance.new("TextButton")
clearSearchBtn.Name = "ClearSearchBtn"
clearSearchBtn.Size = UDim2.fromOffset(26, 24)
clearSearchBtn.Position = UDim2.new(1, -30, 0, 4)
clearSearchBtn.BackgroundColor3 = C.TabIdle
clearSearchBtn.Text = "✕"
clearSearchBtn.TextColor3 = C.TextMain
clearSearchBtn.Font = Enum.Font.GothamBold
clearSearchBtn.TextSize = 13
clearSearchBtn.Visible = false
clearSearchBtn.Parent = searchBarFrame
Instance.new("UICorner", clearSearchBtn).CornerRadius = UDim.new(0, 6)

-- Tabs Row
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -28, 0, 32)
tabBar.Position = UDim2.fromOffset(14, 80)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame
local tbLayout = Instance.new("UIListLayout")
tbLayout.FillDirection = Enum.FillDirection.Horizontal
tbLayout.SortOrder = Enum.SortOrder.LayoutOrder
tbLayout.Padding = UDim.new(0, 6)
tbLayout.Parent = tabBar

-- Pinned Target Strip
local targetBar = Instance.new("Frame")
targetBar.Name = "PinnedTargetBar"
targetBar.Size = UDim2.new(1, -28, 0, 32)
targetBar.Position = UDim2.fromOffset(14, 118)
targetBar.BackgroundColor3 = C.PanelBg
targetBar.Parent = frame
Instance.new("UICorner", targetBar).CornerRadius = UDim.new(0, 8)
addStroke(targetBar, 1.2, C.CardStroke)

local targetLbl = Instance.new("TextLabel")
targetLbl.Size = UDim2.new(1, -170, 1, 0)
targetLbl.Position = UDim2.fromOffset(10, 0)
targetLbl.BackgroundTransparency = 1
targetLbl.TextXAlignment = Enum.TextXAlignment.Left
targetLbl.Text = "Target: @self"
targetLbl.TextColor3 = C.TextMain
targetLbl.Font = Enum.Font.GothamBold
targetLbl.TextSize = 13
targetLbl.TextTruncate = Enum.TextTruncate.AtEnd
targetLbl.Parent = targetBar

local selectMeBtn = Instance.new("TextButton")
selectMeBtn.Name = "SelectSelfBtn"
selectMeBtn.Size = UDim2.fromOffset(50, 24)
selectMeBtn.Position = UDim2.new(1, -160, 0, 4)
selectMeBtn.BackgroundColor3 = C.AccentTeal
selectMeBtn.Text = "Me"
selectMeBtn.TextColor3 = Color3.new(1, 1, 1)
selectMeBtn.Font = Enum.Font.GothamBold
selectMeBtn.TextSize = 12
selectMeBtn.Parent = targetBar
Instance.new("UICorner", selectMeBtn).CornerRadius = UDim.new(0, 6)

local cycleTargetBtn = Instance.new("TextButton")
cycleTargetBtn.Name = "NextTargetBtn"
cycleTargetBtn.Size = UDim2.fromOffset(98, 24)
cycleTargetBtn.Position = UDim2.new(1, -104, 0, 4)
cycleTargetBtn.BackgroundColor3 = C.TabIdle
cycleTargetBtn.Text = "Next Player"
cycleTargetBtn.TextColor3 = C.TextMain
cycleTargetBtn.Font = Enum.Font.GothamBold
cycleTargetBtn.TextSize = 12
cycleTargetBtn.Parent = targetBar
Instance.new("UICorner", cycleTargetBtn).CornerRadius = UDim.new(0, 6)

-- Content Scrolling Panel
local content = Instance.new("ScrollingFrame")
content.Name = "AdminContentScroll"
content.Size = UDim2.new(1, -28, 1, -166)
content.Position = UDim2.fromOffset(14, 156)
content.BackgroundColor3 = C.PanelBg
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = Color3.fromRGB(92, 108, 138)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.fromScale(0, 0)
content.Parent = frame
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 10)
addStroke(content, 1.2, C.CardStroke)

local cLayout = Instance.new("UIListLayout")
cLayout.Padding = UDim.new(0, 7)
cLayout.SortOrder = Enum.SortOrder.LayoutOrder
cLayout.Parent = content
addPad(content, 10, 10)

local tabButtons: { { id: string, label: string, btn: TextButton, stroke: UIStroke } } = {}
local liveEventSubLabels: { [string]: { label: TextLabel, def: any } } = {}
local liveDurationBoxRef: TextBox? = nil

local function sendAdmin(action: string, payload: { [string]: any }?)
	Remotes.Get("AdminCommand"):FireServer(action, payload or {})
end

local function clearContent()
	table.clear(liveEventSubLabels)
	liveDurationBoxRef = nil
	for _, ch in ipairs(content:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local function getTargetInfo(): (string, string)
	for _, p in ipairs(adminState.players or {}) do
		if p.userId == uiState.selectedTargetUserId then
			local role = if p.title ~= "" and p.title ~= nil then p.title else "Player"
			return string.format("%s (@%s)", p.displayName, p.name), role
		end
	end
	return tostring(uiState.selectedTargetUserId), "Player"
end

local function updateTargetBar()
	local nameStr, roleStr = getTargetInfo()
	local prefix = if roleStr == "Owner" then "👑 " elseif roleStr == "Admin" then "🛡️ " else "👤 "
	targetLbl.Text = string.format("Active Target:  %s%s  [%s]", prefix, nameStr, string.upper(roleStr))
	targetLbl.TextColor3 = if roleStr == "Owner" then Color3.fromRGB(255, 214, 84) elseif roleStr == "Admin" then Color3.fromRGB(255, 132, 172) else C.TextMain
end

local function makeChipButton(parent: Instance, label: string, bg: Color3, cb: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = bg
	b.Text = label
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	addPad(b, 6, 0)
	b.MouseButton1Click:Connect(cb)
	return b
end

-- Search & Scoped Row Builder State
local renderAdminPanel: (resetScroll: boolean?) -> ()
local scopeState = {
	tabId = "",
	tabName = "",
	sectionTitle = "",
	sectionColor = C.TextMuted,
	sectionEmitted = false,
	matchCount = 0,
}

local function trimLower(s: string): string
	local t = string.gsub(s, "^%s*(.-)%s*$", "%1")
	return string.lower(t)
end

local function isSearching(): boolean
	return uiState.searchQuery ~= ""
end

local function matchesKeywords(haystack: string): boolean
	if not isSearching() then
		return scopeState.tabId == uiState.activeTab
	end
	local lowerHay = string.lower(haystack .. " " .. scopeState.tabName .. " " .. scopeState.sectionTitle)
	for token in string.gmatch(uiState.searchQuery, "%S+") do
		if string.find(lowerHay, token, 1, true) == nil then
			return false
		end
	end
	scopeState.matchCount += 1
	return true
end

local function renderSectionHeader(text: string, color: Color3?)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.TextColor3 = color or C.TextMuted
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.Parent = content
end

local function setTabScope(tabId: string, tabName: string)
	scopeState.tabId = tabId
	scopeState.tabName = tabName
	scopeState.sectionTitle = ""
	scopeState.sectionEmitted = false
end

local function addSectionHeader(text: string, color: Color3?)
	scopeState.sectionTitle = text
	scopeState.sectionColor = color or C.TextMuted
	scopeState.sectionEmitted = false
	if not isSearching() and scopeState.tabId == uiState.activeTab then
		scopeState.sectionEmitted = true
		renderSectionHeader(text, scopeState.sectionColor)
	end
end

local function ensureSearchSectionHeader()
	if isSearching() and not scopeState.sectionEmitted then
		scopeState.sectionEmitted = true
		local label = if scopeState.sectionTitle ~= ""
			then string.format("[%s]  %s", string.upper(scopeState.tabName), scopeState.sectionTitle)
			else string.format("[%s]", string.upper(scopeState.tabName))
		renderSectionHeader(label, scopeState.sectionColor)
	end
end

local function addActionGrid(buttons: { { text: string, color: Color3, keywords: string?, onClick: () -> () } }, cols: number?, groupKeywords: string?)
	local combinedKw = groupKeywords or ""
	for _, b in ipairs(buttons) do
		combinedKw ..= " " .. b.text .. " " .. (b.keywords or "")
	end
	if not matchesKeywords(combinedKw) then
		return
	end
	ensureSearchSectionHeader()

	local colCount = cols or #buttons
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundTransparency = 1
	row.Parent = content

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / colCount, -6, 0, 36)
	grid.CellPadding = UDim2.fromOffset(8, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row

	for i, item in ipairs(buttons) do
		local b = makeChipButton(row, item.text, item.color, item.onClick)
		b.LayoutOrder = i
	end
end

local function addActionRow(labelText: string, subText: string?, btnText: string, col: Color3, cb: () -> (), keywords: string?)
	local hay = labelText .. " " .. (subText or "") .. " " .. btnText .. " " .. (keywords or "")
	if not matchesKeywords(hay) then
		return
	end
	ensureSearchSectionHeader()

	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, 0, 0, if subText then 52 else 42)
	r.BackgroundColor3 = C.CardBg
	r.Parent = content
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)
	addStroke(r, 1, C.CardStroke)

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -150, 0, if subText then 24 else 42)
	l.Position = UDim2.fromOffset(12, if subText then 5 else 0)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = labelText
	l.TextColor3 = C.TextMain
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = r

	if subText then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -150, 0, 18)
		sub.Position = UDim2.fromOffset(12, 28)
		sub.BackgroundTransparency = 1
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = subText
		sub.TextColor3 = C.TextMuted
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 12
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		sub.Parent = r
	end

	local b = makeChipButton(r, btnText, col, cb)
	b.Size = UDim2.fromOffset(124, 30)
	b.Position = UDim2.new(1, -134, 0.5, -15)
end

local function addInputRow(placeholder: string, btnText: string, col: Color3, cb: (string) -> (), keywords: string?)
	local hay = placeholder .. " " .. btnText .. " " .. (keywords or "")
	if not matchesKeywords(hay) then
		return
	end
	ensureSearchSectionHeader()

	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, 0, 0, 44)
	r.BackgroundColor3 = C.CardBg
	r.Parent = content
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)
	addStroke(r, 1, C.CardStroke)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -152, 0, 32)
	box.Position = UDim2.fromOffset(8, 6)
	box.BackgroundColor3 = C.InputBg
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = C.TextMuted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextColor3 = C.TextMain
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.Parent = r
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
	addStroke(box, 1, C.CardStroke)
	addPad(box, 10, 0)

	local b = makeChipButton(r, btnText, col, function()
		cb(box.Text)
	end)
	b.Size = UDim2.fromOffset(124, 32)
	b.Position = UDim2.new(1, -134, 0, 6)
end

local function formatEventSubText(def: any, rem: number?): string
	local desc = tostring(def.description or "")
	if rem and rem > 0 then
		return string.format("🟢 AKTIF • %s (%ds)  |  %s", FormatUtil.Time(rem), rem, desc)
	else
		return string.format("⚪ Nonaktif (Def %ds)  |  %s", tonumber(def.durationSeconds) or 120, desc)
	end
end

local function resolveDurationSecondsForEvent(def: any): number
	if liveDurationBoxRef then
		local typed = tonumber(liveDurationBoxRef.Text)
		if typed and typed > 0 then
			uiState.customEventSeconds = math.clamp(math.floor(typed), 5, 86400)
			uiState.useDefaultEventDuration = false
			return uiState.customEventSeconds
		end
	end
	if uiState.useDefaultEventDuration then
		return tonumber(def.durationSeconds) or 120
	end
	return math.clamp(math.floor(uiState.customEventSeconds), 5, 86400)
end

local function addEventDurationController()
	if not matchesKeywords("durasi duration detik timer seconds waktu event abuse preset 30 60 120 300 600") then
		return
	end
	ensureSearchSectionHeader()

	local card = Instance.new("Frame")
	card.Name = "EventDurationControls"
	card.Size = UDim2.new(1, 0, 0, 80)
	card.BackgroundColor3 = C.CardBg
	card.Parent = content
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	addStroke(card, 1.2, C.AccentAmber)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.48, -10, 0, 32)
	lbl.Position = UDim2.fromOffset(10, 6)
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = if uiState.useDefaultEventDuration
		then "⏱️ Durasi Event: DEFAULT per event"
		else string.format("⏱️ Durasi Custom: %d detik (%s)", uiState.customEventSeconds, FormatUtil.Time(uiState.customEventSeconds))
	lbl.TextColor3 = Color3.fromRGB(255, 224, 96)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = card

	local durBox = Instance.new("TextBox")
	durBox.Name = "CustomDurationInput"
	durBox.Size = UDim2.new(0.28, -6, 0, 30)
	durBox.Position = UDim2.new(0.48, 0, 0, 7)
	durBox.BackgroundColor3 = C.InputBg
	durBox.PlaceholderText = "Detik (misal 45)..."
	durBox.PlaceholderColor3 = C.TextMuted
	durBox.Text = if uiState.useDefaultEventDuration then "" else tostring(uiState.customEventSeconds)
	durBox.ClearTextOnFocus = false
	durBox.TextColor3 = C.TextMain
	durBox.Font = Enum.Font.GothamBold
	durBox.TextSize = 13
	durBox.Parent = card
	Instance.new("UICorner", durBox).CornerRadius = UDim.new(0, 6)
	addStroke(durBox, 1, C.CardStroke)
	addPad(durBox, 8, 0)
	liveDurationBoxRef = durBox

	durBox.FocusLost:Connect(function()
		local n = tonumber(durBox.Text)
		if n and n > 0 then
			uiState.customEventSeconds = math.clamp(math.floor(n), 5, 86400)
			uiState.useDefaultEventDuration = false
			lbl.Text = string.format("⏱️ Durasi Custom: %d detik (%s)", uiState.customEventSeconds, FormatUtil.Time(uiState.customEventSeconds))
		end
	end)

	local setBtn = makeChipButton(card, "Set Detik", C.AccentAmber, function()
		local n = tonumber(durBox.Text)
		if n and n > 0 then
			uiState.customEventSeconds = math.clamp(math.floor(n), 5, 86400)
			uiState.useDefaultEventDuration = false
			renderAdminPanel()
		end
	end)
	setBtn.Size = UDim2.new(0.24, -14, 0, 30)
	setBtn.Position = UDim2.new(0.76, 4, 0, 7)

	local presetsFrame = Instance.new("Frame")
	presetsFrame.Size = UDim2.new(1, -20, 0, 28)
	presetsFrame.Position = UDim2.fromOffset(10, 44)
	presetsFrame.BackgroundTransparency = 1
	presetsFrame.Parent = card

	local pGrid = Instance.new("UIGridLayout")
	pGrid.CellSize = UDim2.new(1 / 6, -5, 0, 28)
	pGrid.CellPadding = UDim2.fromOffset(6, 0)
	pGrid.SortOrder = Enum.SortOrder.LayoutOrder
	pGrid.Parent = presetsFrame

	local presets = {
		{ label = "30s", sec = 30 },
		{ label = "60s (1m)", sec = 60 },
		{ label = "120s (2m)", sec = 120 },
		{ label = "300s (5m)", sec = 300 },
		{ label = "600s (10m)", sec = 600 },
		{ label = "Default", sec = 0 },
	}
	for i, pr in ipairs(presets) do
		local isAct = if pr.sec == 0
			then uiState.useDefaultEventDuration
			else (not uiState.useDefaultEventDuration and uiState.customEventSeconds == pr.sec)
		local b = makeChipButton(presetsFrame, pr.label, if isAct then C.AccentGreen else C.TabIdle, function()
			if pr.sec == 0 then
				uiState.useDefaultEventDuration = true
			else
				uiState.useDefaultEventDuration = false
				uiState.customEventSeconds = pr.sec
			end
			renderAdminPanel()
		end)
		b.LayoutOrder = i
	end
end

local function addEventCard(def: any)
	local hay = string.format("%s %s %s %s admin abuse event buff multiplier", tostring(def.id), tostring(def.shortLabel or ""), tostring(def.title), tostring(def.description or ""))
	if not matchesKeywords(hay) then
		return
	end
	ensureSearchSectionHeader()

	local rem = (adminState.activeEvents or {})[def.id]
	local isAct = type(rem) == "number" and rem > 0
	local accentCol: Color3 = if typeof(def.color) == "Color3" then def.color else C.AccentPurple

	local r = Instance.new("Frame")
	r.Name = "EventCard_" .. tostring(def.id)
	r.Size = UDim2.new(1, 0, 0, 58)
	r.BackgroundColor3 = C.CardBg
	r.Parent = content
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)
	addStroke(r, if isAct then 1.5 else 1.0, if isAct then accentCol else C.CardStroke)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, -12)
	bar.Position = UDim2.fromOffset(6, 6)
	bar.BackgroundColor3 = accentCol
	bar.BorderSizePixel = 0
	bar.Parent = r
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -242, 0, 24)
	titleLbl.Position = UDim2.fromOffset(16, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = string.format("%s  %s  —  %s", tostring(def.icon or "🔥"), tostring(def.shortLabel or def.id), tostring(def.title))
	titleLbl.TextColor3 = if isAct then Color3.fromRGB(255, 244, 168) else C.TextMain
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 14
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.Parent = r

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -242, 0, 20)
	subLbl.Position = UDim2.fromOffset(16, 32)
	subLbl.BackgroundTransparency = 1
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.Text = formatEventSubText(def, rem)
	subLbl.TextColor3 = if isAct then Color3.fromRGB(110, 245, 168) else C.TextMuted
	subLbl.Font = if isAct then Enum.Font.GothamBold else Enum.Font.Gotham
	subLbl.TextSize = 11
	subLbl.TextTruncate = Enum.TextTruncate.AtEnd
	subLbl.Parent = r

	liveEventSubLabels[def.id] = { label = subLbl, def = def }

	local btnRow = Instance.new("Frame")
	btnRow.Size = UDim2.fromOffset(222, 32)
	btnRow.Position = UDim2.new(1, -230, 0.5, -16)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = r

	local durHint = if uiState.useDefaultEventDuration then (tostring(def.durationSeconds or 120) .. "s") else (tostring(uiState.customEventSeconds) .. "s")
	local startBtn = makeChipButton(btnRow, if isAct then ("Set " .. durHint) else ("▶ " .. durHint), if isAct then C.AccentBlue else C.AccentPurple, function()
		sendAdmin("TriggerEvent", { eventId = def.id, durationSeconds = resolveDurationSecondsForEvent(def), mode = "set" })
	end)
	startBtn.Size = UDim2.fromOffset(76, 32)
	startBtn.Position = UDim2.fromOffset(0, 0)

	local extBtn = makeChipButton(btnRow, "+" .. durHint, C.AccentGreen, function()
		sendAdmin("TriggerEvent", { eventId = def.id, durationSeconds = resolveDurationSecondsForEvent(def), mode = "extend" })
	end)
	extBtn.Size = UDim2.fromOffset(72, 32)
	extBtn.Position = UDim2.fromOffset(80, 0)

	local stopBtn = makeChipButton(btnRow, "Stop", if isAct then C.AccentRed else Color3.fromRGB(58, 66, 86), function()
		if isAct then
			sendAdmin("StopEvent", { eventId = def.id })
		end
	end)
	stopBtn.Size = UDim2.fromOffset(66, 32)
	stopBtn.Position = UDim2.fromOffset(156, 0)
end

local function updateTabStyles()
	local myRank = tonumber(adminState.rank) or 0
	local activeCol = if myRank >= 3 or adminState.title == "Owner" then C.AccentAmber else C.AccentPink
	local searching = isSearching()
	for _, entry in ipairs(tabButtons) do
		local isAct = (not searching) and (uiState.activeTab == entry.id)
		entry.btn.BackgroundColor3 = if isAct then activeCol else C.TabIdle
		entry.btn.TextColor3 = if isAct then Color3.new(1, 1, 1) else C.TextMuted
		entry.stroke.Color = if isAct then Color3.new(1, 1, 1) else C.CardStroke
		entry.stroke.Thickness = if isAct then 1.8 else 1.0
	end
end

selectMeBtn.MouseButton1Click:Connect(function()
	uiState.selectedTargetUserId = localPlayer.UserId
	updateTargetBar()
	if frame.Visible then
		renderAdminPanel()
	end
end)

cycleTargetBtn.MouseButton1Click:Connect(function()
	local list = adminState.players or {}
	if #list == 0 then return end
	local idx = 1
	for i, p in ipairs(list) do
		if p.userId == uiState.selectedTargetUserId then
			idx = (i % #list) + 1
			break
		end
	end
	uiState.selectedTargetUserId = list[idx].userId
	updateTargetBar()
	if frame.Visible then
		renderAdminPanel()
	end
end)

renderAdminPanel = function(resetScroll: boolean?)
	local savedPos = if resetScroll then Vector2.zero else content.CanvasPosition
	clearContent()
	updateTabStyles()
	updateTargetBar()

	scopeState.matchCount = 0
	local searching = isSearching()
	clearSearchBtn.Visible = searching
	searchStroke.Color = if searching then C.AccentAmber else C.CardStroke

	if searching then
		renderSectionHeader("🔎 HASIL PENCARIAN LINTAS TAB: \"" .. searchInput.Text .. "\"", Color3.fromRGB(255, 214, 72))
	end

	local myRank = tonumber(adminState.rank) or 0
	local selId = uiState.selectedTargetUserId

	-- TAB 1: PLAYERS / MODERATION
	setTabScope("Mod", "Players")
	addSectionHeader("SERVER PLAYERS", C.TextMuted)
	for _, p in ipairs(adminState.players or {}) do
		local isSel = (p.userId == selId)
		local tag = if p.title == "Owner" then "👑 OWNER  •  " elseif p.title == "Admin" then "🛡️ ADMIN  •  " else ""
		addActionRow(
			string.format("%s%s", tag, p.displayName),
			string.format("@%s  |  ID: %d", p.name, p.userId),
			if isSel then "SELECTED" else "Select",
			if isSel then C.AccentGreen else C.AccentBlue,
			function()
				uiState.selectedTargetUserId = p.userId
				renderAdminPanel()
			end,
			"player target pilih select mod " .. tostring(p.name) .. " " .. tostring(p.displayName)
		)
	end

	addSectionHeader("PLAYER MODERATION & MOVEMENT", C.TextMuted)
	addActionGrid({
		{ text = "Kill Player", color = C.AccentRed, keywords = "bunuh mati", onClick = function() sendAdmin("Kill", { targetUserId = selId }) end },
		{ text = "TP To Player", color = C.AccentBlue, keywords = "teleport goto", onClick = function() sendAdmin("TeleportTo", { targetUserId = selId }) end },
		{ text = "Bring Player", color = C.AccentTeal, keywords = "tarik bawa summon", onClick = function() sendAdmin("Bring", { targetUserId = selId }) end },
	}, 3, "player movement")
	addActionGrid({
		{ text = "TP -> Their Plot", color = C.AccentPurple, keywords = "base kandang rumah sanctuary", onClick = function() sendAdmin("TeleportToPlot", { targetUserId = selId }) end },
		{ text = "Heal & Unstun", color = C.AccentGreen, keywords = "sembuh darah health pulih", onClick = function() sendAdmin("HealUnstun", { targetUserId = selId }) end },
		{ text = "Freeze", color = Color3.fromRGB(71, 85, 105), keywords = "beku tahan", onClick = function() sendAdmin("Freeze", { targetUserId = selId }) end },
		{ text = "Unfreeze", color = C.AccentTeal, keywords = "cair lepas gerak", onClick = function() sendAdmin("Unfreeze", { targetUserId = selId }) end },
	}, 4, "moderation status")

	addSectionHeader("TELEPORT TARGET TO ZONE", C.TextMuted)
	addActionGrid({
		{ text = "Safe Zone", color = C.AccentGreen, keywords = "hub spawn", onClick = function() sendAdmin("TeleportToZone", { targetUserId = selId, zoneId = "SafeZone" }) end },
		{ text = "Pine Wood", color = Color3.fromRGB(46, 125, 50), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selId, zoneId = "PineWoods" }) end },
		{ text = "Swamp", color = Color3.fromRGB(101, 86, 52), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selId, zoneId = "MangroveSwamp" }) end },
	}, 3, "teleport zone biome")
	addActionGrid({
		{ text = "Savanna", color = Color3.fromRGB(180, 120, 32), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selId, zoneId = "SavannaCamp" }) end },
		{ text = "Alpine", color = Color3.fromRGB(2, 132, 199), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selId, zoneId = "AlpinePeaks" }) end },
		{ text = "Volcanic", color = Color3.fromRGB(185, 56, 36), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selId, zoneId = "VolcanicJungle" }) end },
	}, 3, "teleport zone biome")

	addSectionHeader("KICK & BAN", C.TextMuted)
	addInputRow("Kick reason (optional)...", "Kick Player", C.AccentAmber, function(txt)
		sendAdmin("Kick", { targetUserId = selId, reason = if txt ~= "" then txt else "Kicked by Admin" })
	end, "kick tendang keluarkan")
	addInputRow("Temp Ban Hours (e.g. 24)...", "Temp Ban", C.AccentRed, function(txt)
		local hrs = math.max(1, tonumber(txt) or 24)
		sendAdmin("Ban", { targetUserId = selId, durationSeconds = math.floor(hrs * 3600), reason = string.format("Temp Banned (%dh) by Admin", math.floor(hrs)) })
	end, "ban temp blokir jam")
	addInputRow("Permanent ban reason...", "Perm Ban", Color3.fromRGB(153, 27, 27), function(txt)
		sendAdmin("Ban", { targetUserId = selId, durationSeconds = 0, reason = if txt ~= "" then txt else "Banned by Admin" })
	end, "perm ban blokir permanen")
	addInputRow("Enter UserId to unban...", "Unban ID", C.AccentGreen, function(txt)
		local uid = tonumber(txt)
		if uid then sendAdmin("Unban", { targetUserId = uid }) end
	end, "unban buka blokir")

	if myRank >= 3 then
		addSectionHeader("SUPERADMIN (OWNER) — TITLES & DATA", Color3.fromRGB(255, 208, 72))
		addActionGrid({
			{ text = "Give [Admin]", color = C.AccentPink, onClick = function() sendAdmin("GrantTitle", { targetUserId = selId, title = "Admin" }) end },
			{ text = "Give [Owner]", color = C.AccentAmber, onClick = function() sendAdmin("GrantTitle", { targetUserId = selId, title = "Owner" }) end },
			{ text = "Revoke Title", color = Color3.fromRGB(100, 116, 139), onClick = function() sendAdmin("RevokeTitle", { targetUserId = selId }) end },
		}, 3, "rank title admin owner role promote")
		addInputRow("Offline Grant Admin: UserId,Username", "Grant Admin", C.AccentPink, function(txt)
			local uidStr, uname = string.match(txt, "^%s*(%d+)%s*,%s*([%w_]+)%s*$")
			if uidStr and uname then
				sendAdmin("GrantTitle", { targetUserId = tonumber(uidStr), targetUsername = uname, title = "Admin" })
			end
		end, "offline admin grant role")
		addActionRow("Wipe Target Save Data", "Resets target coins, speed & inventory to new profile", "Wipe Data", C.AccentRed, function()
			sendAdmin("ResetPlayerData", { targetUserId = selId })
		end, "reset wipe hapus data")
	end

	-- TAB 2: ECONOMY
	setTabScope("Economy", "Economy")
	addSectionHeader("SPEED, MONEY & REBIRTH CONTROLS", C.TextMuted)
	addInputRow("Set exact speed (e.g. 500, 50K, 10B)...", "Set Speed", C.AccentBlue, function(txt)
		sendAdmin("SetSpeed", { targetUserId = selId, amount = if txt ~= "" then txt else "500" })
	end, "speed kecepatan lari")
	addInputRow("Add speed (+amount, e.g. 250, 50K)...", "Give Speed", C.AccentTeal, function(txt)
		sendAdmin("GiveSpeed", { targetUserId = selId, amount = if txt ~= "" then txt else "500" })
	end, "speed tambah lari")
	addInputRow("Give coins (+amount, e.g. 500K, 25M)...", "Give Money", C.AccentGreen, function(txt)
		sendAdmin("GiveCoins", { targetUserId = selId, amount = if txt ~= "" then txt else "1M" })
	end, "cash money uang duit koin coins")
	addInputRow("Set exact coins (e.g. 0, 10M, 5T)...", "Set Money", Color3.fromRGB(21, 128, 61), function(txt)
		sendAdmin("SetCoins", { targetUserId = selId, amount = if txt ~= "" then txt else "0" })
	end, "cash money uang duit koin coins")
	addInputRow("Give Rebirths (+count, default 1)...", "Give Rebirth", C.AccentPink, function(txt)
		sendAdmin("GiveRebirth", { targetUserId = selId, amount = tonumber(txt) or 1 })
	end, "rebirth prestige")

	addSectionHeader("PROGRESSION & LIVE MULTIPLIERS", C.TextMuted)
	addActionGrid({
		{ text = "Set Pen Cap (20)", color = C.AccentPurple, keywords = "kandang kapasitas", onClick = function() sendAdmin("SetPenCapacity", { targetUserId = selId, capacity = 20 }) end },
		{ text = "Treadmill Lv.15", color = C.AccentBlue, keywords = "speed lari upgrade", onClick = function() sendAdmin("SetTreadmillLevel", { targetUserId = selId, level = 15 }) end },
		{ text = "Unlock All Gear/Idx", color = C.AccentAmber, keywords = "lasso trail vehicle index", onClick = function() sendAdmin("UnlockAll", { targetUserId = selId }) end },
	}, 3, "progression unlock")

	local tuners = adminState.liveTuners or {}
	addInputRow(string.format("Live Cash Mult (Current: %.2gx)", tonumber(tuners.cashMult) or 1), "Set Cash Mult", C.AccentTeal, function(txt)
		sendAdmin("SetLiveMultiplier", { key = "cashMult", value = tonumber(txt) or 1 })
	end, "x2 cash multiplier uang koin")
	addInputRow(string.format("Live Speed Mult (Current: %.2gx)", tonumber(tuners.speedMult) or 1), "Set Speed Mult", C.AccentBlue, function(txt)
		sendAdmin("SetLiveMultiplier", { key = "speedMult", value = tonumber(txt) or 1 })
	end, "x2 speed multiplier treadmill")
	addInputRow(string.format("Live Resistance Mult (Current: %.2gx)", tonumber(tuners.resistanceMult) or 1), "Set Res Mult", C.AccentTeal, function(txt)
		sendAdmin("SetLiveMultiplier", { key = "resistanceMult", value = tonumber(txt) or 1 })
	end, "tarik lasso pull mudah")
	addInputRow(string.format("Live Poacher Speed Mult (Current: %.2gx)", tonumber(tuners.poacherSpeedMult) or 1), "Set Poach Spd", C.AccentAmber, function(txt)
		sendAdmin("SetLiveMultiplier", { key = "poacherSpeedMult", value = tonumber(txt) or 1 })
	end, "poacher musuh enemy speed")
	addActionRow("Reset All Multipliers to 1x", "Resets Cash, Speed, Resistance & Poacher multipliers", "Reset 1x", C.AccentRed, function()
		sendAdmin("ResetMultipliers")
	end, "reset multiplier normal x2 cash speed")

	-- TAB 3: SPAWN CRATES & GIVE PETS
	setTabScope("Spawn", "Spawn")
	local biome = BiomeConfig[uiState.selectedBiomeIdx] or BiomeConfig[1]
	local rarity = RARITIES[uiState.selectedRarityIdx] or "Legendary"
	local spec = AnimalConfig.ALL[uiState.selectedSpeciesIdx] or AnimalConfig.ALL[1]
	local mut = GameConfig.MUTATION_ORDER[uiState.selectedMutationIdx] or "None"

	addSectionHeader("1. SPAWN OR GIVE CRATES", Color3.fromRGB(250, 204, 21))
	addActionRow("Biome: " .. biome.name, "Select biome for world/inventory crate", "Next Biome", C.AccentTeal, function()
		uiState.selectedBiomeIdx = (uiState.selectedBiomeIdx % #BiomeConfig) + 1
		renderAdminPanel()
	end, "biome zone crate kotak")
	addActionRow("Crate Rarity: " .. rarity, "Determines tier, visual aura & hatch pool", "Next Rarity", C.AccentAmber, function()
		uiState.selectedRarityIdx = (uiState.selectedRarityIdx % #RARITIES) + 1
		renderAdminPanel()
	end, "rarity langka mythic singularity")
	addActionRow(
		"Crate Pet Mode: " .. if uiState.useSelectedSpeciesForCrate then ("🎯 Force " .. spec.name) else "🎲 Random Biome/Rarity Pet",
		"Toggle between rolling valid pet or forcing Section 2's pet",
		if uiState.useSelectedSpeciesForCrate then "Forced Pet" else "Random Pet",
		if uiState.useSelectedSpeciesForCrate then C.AccentPurple else Color3.fromRGB(71, 85, 105),
		function()
			uiState.useSelectedSpeciesForCrate = not uiState.useSelectedSpeciesForCrate
			renderAdminPanel()
		end,
		"crate species random force mode"
	)
	addActionGrid({
		{
			text = "🎒 Give Crate (Inv)",
			color = C.AccentPurple,
			keywords = "inventory tas kotak peti",
			onClick = function()
				sendAdmin("GiveCrate", {
					targetUserId = selId,
					biomeId = biome.id,
					rarity = rarity,
					speciesId = spec.id,
					useSelectedSpecies = uiState.useSelectedSpeciesForCrate,
				})
			end,
		},
		{
			text = "🏡 Ready Crate -> Pen",
			color = C.AccentAmber,
			keywords = "kandang pen instant hatch",
			onClick = function()
				sendAdmin("GivePenCrate", {
					targetUserId = selId,
					biomeId = biome.id,
					rarity = rarity,
					speciesId = spec.id,
					useSelectedSpecies = uiState.useSelectedSpeciesForCrate,
					instantReady = true,
				})
			end,
		},
		{
			text = "📍 Spawn Near Me",
			color = C.AccentBlue,
			keywords = "world crate dekat",
			onClick = function()
				sendAdmin("SpawnWorldCrate", {
					biomeId = biome.id,
					rarity = rarity,
					speciesId = spec.id,
					useSelectedSpecies = uiState.useSelectedSpeciesForCrate,
					nearAdmin = true,
				})
			end,
		},
		{
			text = "🌲 Spawn in Biome",
			color = C.AccentGreen,
			keywords = "world crate biome",
			onClick = function()
				sendAdmin("SpawnWorldCrate", {
					biomeId = biome.id,
					rarity = rarity,
					speciesId = spec.id,
					useSelectedSpecies = uiState.useSelectedSpeciesForCrate,
					nearAdmin = false,
				})
			end,
		},
	}, 2, "crate spawn give kotak")
	addActionRow("⚡ Instant Ready Target's Pen Crates", "Sets unlock timer to 0s on all crates inside target's Pen", "Ready Crates", C.AccentAmber, function()
		sendAdmin("InstantReadyCrates", { targetUserId = selId })
	end, "unbox hatch cepat instant ready crate")

	addSectionHeader("2. GIVE PET DIRECTLY TO TARGET PLAYER", Color3.fromRGB(192, 132, 252))
	addActionGrid({
		{
			text = "◀ Prev Pet",
			color = C.TabIdle,
			onClick = function()
				uiState.selectedSpeciesIdx = ((uiState.selectedSpeciesIdx - 2) % #AnimalConfig.ALL) + 1
				renderAdminPanel()
			end,
		},
		{
			text = "Next Pet ▶",
			color = C.AccentBlue,
			onClick = function()
				uiState.selectedSpeciesIdx = (uiState.selectedSpeciesIdx % #AnimalConfig.ALL) + 1
				renderAdminPanel()
			end,
		},
	}, 2, "species pet animal hewan " .. spec.name)
	addActionRow(string.format("Selected (#%02d/%d): %s", spec.indexNumber, #AnimalConfig.ALL, spec.name), string.format("%s | %s", spec.biomeId, spec.rarity), "Give Pet", C.AccentPurple, function()
		sendAdmin("GivePet", {
			targetUserId = selId,
			speciesId = spec.id,
			mutation = mut,
			sizeRatio = uiState.selectedSizeRatio,
		})
	end, "give pet hewan " .. spec.name .. " " .. spec.rarity)
	addActionRow("Mutation: " .. mut, "Applies mutation multiplier & visual finish", "Next Mutation", C.AccentPurple, function()
		uiState.selectedMutationIdx = (uiState.selectedMutationIdx % #GameConfig.MUTATION_ORDER) + 1
		renderAdminPanel()
	end, "mutation rainbow golden astral celestial")
	addInputRow("Size ratio (Current: " .. tostring(uiState.selectedSizeRatio) .. "x, e.g. 5.0)", "Set Size", C.AccentAmber, function(txt)
		uiState.selectedSizeRatio = math.clamp(tonumber(txt) or 2.5, 0.5, 10.0)
		renderAdminPanel()
	end, "size ukuran raksasa giant")

	-- TAB 4: RATES (OWNER)
	setTabScope("Rates", "Rates")
	if myRank < 3 then
		addSectionHeader("OWNER (SUPERADMIN) ONLY", C.AccentRed)
		addActionRow("Locked", "Only Owner / Superadmin can modify spawn & mutation rates.", "Rank 3+", Color3.fromRGB(71, 85, 105), function() end, "rates luck locked")
	else
		local rOverrides = adminState.rarityWeightOverrides or {}
		local mOverrides = adminState.mutationWeightOverrides or {}
		local rKey = RARITIES[uiState.selectedRateRarityIdx] or "Primordial"
		local rDefW = (GameConfig.RARITY_WEIGHTS :: any)[rKey] or 1.0
		local rCurW = if rOverrides[rKey] ~= nil then rOverrides[rKey] else rDefW
		local mKey = GameConfig.MUTATION_ORDER[uiState.selectedRateMutIdx] or "Celestial"
		local mDefW = (GameConfig.MUTATIONS[mKey] and GameConfig.MUTATIONS[mKey].weight) or 1.0
		local mCurW = if mOverrides[mKey] ~= nil then mOverrides[mKey] else mDefW
		local forcedMut = tostring(adminState.forcedWildMutation or "Random")

		addSectionHeader("GLOBAL SPAWN & MUTATION LUCK (OWNER)", Color3.fromRGB(250, 204, 21))
		addInputRow(string.format("Rarity Luck Mult (Current: %.2fx)", tonumber(tuners.rarityLuckMult) or 1), "Set Rarity Luck", C.AccentAmber, function(txt)
			sendAdmin("SetRarityLuck", { value = tonumber(txt) or 1 })
		end, "rarity luck peluang")
		addInputRow(string.format("Mutation Luck Mult (Current: %.2fx)", tonumber(tuners.mutationLuckMult) or 1), "Set Mut Luck", C.AccentPurple, function(txt)
			sendAdmin("SetMutationLuck", { value = tonumber(txt) or 1 })
		end, "mutation luck peluang")
		addActionGrid({
			{ text = "Respawn All Biomes", color = C.AccentGreen, keywords = "wave reset respawn crate", onClick = function() sendAdmin("TriggerWaveReset") end },
			{ text = "Reset All Rates", color = C.AccentRed, keywords = "default normal", onClick = function() sendAdmin("ResetSpawnRates") end },
		}, 2, "rates wave respawn")

		addSectionHeader("PER-RARITY CRATE SPAWN WEIGHT", C.TextMuted)
		addActionRow(string.format("Rarity: %s (Weight: %.4g | Def: %.4g)", rKey, rCurW, rDefW), "Only spawns in biomes allowing this rarity tier", "Next Tier", C.AccentBlue, function()
			uiState.selectedRateRarityIdx = (uiState.selectedRateRarityIdx % #RARITIES) + 1
			renderAdminPanel()
		end, "weight rarity tier")
		addInputRow("New weight for " .. rKey .. " (empty or -1 to reset)", "Apply Weight", C.AccentTeal, function(txt)
			local num = tonumber(txt)
			sendAdmin("SetRarityWeight", { rarity = rKey, weight = if num ~= nil then num else -1 })
		end, "weight rarity")

		addSectionHeader("PER-MUTATION SPAWN WEIGHT & OVERRIDE", Color3.fromRGB(192, 132, 252))
		addActionRow(string.format("Mutation: %s (Weight: %.4g | Def: %.4g)", mKey, mCurW, mDefW), "Adjust drop rate weight for this visual mutation", "Next Mut", C.AccentPurple, function()
			uiState.selectedRateMutIdx = (uiState.selectedRateMutIdx % #GameConfig.MUTATION_ORDER) + 1
			renderAdminPanel()
		end, "mutation weight peluang")
		addInputRow("New weight for " .. mKey .. " (empty or -1 to reset)", "Apply Mut W", C.AccentTeal, function(txt)
			local num = tonumber(txt)
			sendAdmin("SetMutationWeight", { mutation = mKey, weight = if num ~= nil then num else -1 })
		end, "mutation weight")
		addActionRow("Forced Hatch/Wild Mutation: " .. forcedMut, "Cycles Random -> next mutation for all new hatches", "Cycle Force", C.AccentPink, function()
			if forcedMut == "Random" then
				sendAdmin("SetForcedMutation", { mutation = GameConfig.MUTATION_ORDER[2] })
			else
				local idx = table.find(GameConfig.MUTATION_ORDER, forcedMut) or 0
				local nxt = GameConfig.MUTATION_ORDER[idx + 1] or "Random"
				sendAdmin("SetForcedMutation", { mutation = nxt })
			end
		end, "force mutation override")
	end

	-- TAB 5: EVENTS / ADMIN ABUSE
	setTabScope("Abuse", "Events")
	addSectionHeader("GLOBAL ANNOUNCEMENT & CUSTOM EVENT DURATION", Color3.fromRGB(250, 204, 21))
	addInputRow("Broadcast message to all players...", "Broadcast", C.AccentAmber, function(txt)
		if txt ~= "" then sendAdmin("Broadcast", { message = txt }) end
	end, "pengumuman chat banner announce broadcast")
	addEventDurationController()

	addSectionHeader("ADMIN ABUSE & SERVER EVENTS (CUSTOM DETIK + TIMER HUD)", Color3.fromRGB(224, 92, 255))
	for _, def in ipairs(adminState.eventsCatalog or {}) do
		addEventCard(def)
	end
	addActionRow("Stop All Active Events & Multipliers", "Clears all event timers & resets Cash/Speed multipliers to 1x", "Stop All", C.AccentRed, function()
		sendAdmin("StopAllEvents")
	end, "stop matikan hentikan event semua")

	-- TAB 6: TOOLS (SELF ADMIN UTILITIES)
	setTabScope("Tools", "Tools")
	addSectionHeader("PERSONAL ADMIN SELF-TOOLS", C.TextMuted)
	local st = adminState.selfTools or {}
	local function addSelfToggle(key: string, label: string, sub: string, kw: string)
		local on = st[key] == true
		addActionRow(label, sub, if on then "ENABLED" else "DISABLED", if on then C.AccentGreen else Color3.fromRGB(71, 85, 105), function()
			sendAdmin("ToggleSelfTool", { tool = key })
		end, kw .. " self tool admin toggle")
	end
	addSelfToggle("godMode", "🛡️ God Mode", "Poachers ignore you while pulling or carrying crates", "kebal godmode invulnerable")
	addSelfToggle("instantPull", "⚡ Instant Lasso Pull", "1-tap extracts any crate immediately", "lasso tarik cepat pull")
	addSelfToggle("instantUnbox", "📦 Instant Crate Unbox", "Zero hatch wait time on your Sanctuary Pen", "unbox hatch buka cepat instant")
	addSelfToggle("superSpeed", "🚀 Admin Super Speed", "Grants ultra high movement speed (140)", "speed lari cepat fly gerak")
	addSelfToggle("invisible", "👻 Invisible Mode", "Turns your character & admin tag invisible", "hilang invisible tembus")

	addSectionHeader("QUICK SELF SHORTCUTS", C.TextMuted)
	addActionGrid({
		{ text = "🏠 TP to My Plot", color = C.AccentBlue, keywords = "pulang base kandang", onClick = function() sendAdmin("TeleportToPlot", { targetUserId = localPlayer.UserId }) end },
		{ text = "⚡ Ready My Crates", color = C.AccentAmber, keywords = "hatch unbox", onClick = function() sendAdmin("InstantReadyCrates", { targetUserId = localPlayer.UserId }) end },
		{ text = "💚 Heal & Unstun Me", color = C.AccentGreen, keywords = "heal pulih", onClick = function() sendAdmin("HealUnstun", { targetUserId = localPlayer.UserId }) end },
		{ text = "💰 +1M Cash (Self)", color = C.AccentTeal, keywords = "uang duit money", onClick = function() sendAdmin("GiveCoins", { targetUserId = localPlayer.UserId, amount = "1M" }) end },
	}, 2, "shortcut quick self me")

	-- BONUS QUICK-SEARCH PET RESULTS (when typing pet names like "fae", "cat", "singularity", etc.)
	if searching then
		setTabScope("PetSearch", "Pet Quick-Give")
		local shown = 0
		for _, s in ipairs(AnimalConfig.ALL) do
			local hay = string.format("%s %s %s %s pet animal hewan", s.name, s.id, s.rarity, s.biomeId)
			local matched = true
			local lh = string.lower(hay)
			for token in string.gmatch(uiState.searchQuery, "%S+") do
				if string.find(lh, token, 1, true) == nil then
					matched = false
					break
				end
			end
			if matched then
				if shown == 0 then
					renderSectionHeader(string.format("[PET CATALOG]  Quick-Give Matching Pets (Mut: %s | %.1fx)", mut, uiState.selectedSizeRatio), Color3.fromRGB(192, 132, 252))
				end
				shown += 1
				scopeState.matchCount += 1

				local r = Instance.new("Frame")
				r.Size = UDim2.new(1, 0, 0, 50)
				r.BackgroundColor3 = C.CardBg
				r.Parent = content
				Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)
				addStroke(r, 1, GameConfig.RARITY_COLORS[s.rarity] or C.CardStroke)

				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, -210, 0, 22)
				l.Position = UDim2.fromOffset(12, 4)
				l.BackgroundTransparency = 1
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Text = string.format("#%02d %s", s.indexNumber, s.name)
				l.TextColor3 = GameConfig.RARITY_COLORS[s.rarity] or C.TextMain
				l.Font = Enum.Font.GothamBold
				l.TextSize = 14
				l.TextTruncate = Enum.TextTruncate.AtEnd
				l.Parent = r

				local sub = Instance.new("TextLabel")
				sub.Size = UDim2.new(1, -210, 0, 18)
				sub.Position = UDim2.fromOffset(12, 26)
				sub.BackgroundTransparency = 1
				sub.TextXAlignment = Enum.TextXAlignment.Left
				sub.Text = string.format("%s  •  %s", s.rarity, s.biomeId)
				sub.TextColor3 = C.TextMuted
				sub.Font = Enum.Font.Gotham
				sub.TextSize = 12
				sub.TextTruncate = Enum.TextTruncate.AtEnd
				sub.Parent = r

				local gpBtn = makeChipButton(r, "🎁 Pet", C.AccentPurple, function()
					sendAdmin("GivePet", {
						targetUserId = selId,
						speciesId = s.id,
						mutation = mut,
						sizeRatio = uiState.selectedSizeRatio,
					})
				end)
				gpBtn.Size = UDim2.fromOffset(88, 30)
				gpBtn.Position = UDim2.new(1, -190, 0.5, -15)

				local gcBtn = makeChipButton(r, "🎒 Crate", C.AccentTeal, function()
					sendAdmin("GiveCrate", {
						targetUserId = selId,
						biomeId = s.biomeId,
						rarity = s.rarity,
						speciesId = s.id,
						useSelectedSpecies = true,
					})
				end)
				gcBtn.Size = UDim2.fromOffset(88, 30)
				gcBtn.Position = UDim2.new(1, -96, 0.5, -15)

				if shown >= 10 then
					break
				end
			end
		end

		if scopeState.matchCount == 0 then
			addActionRow(
				"Tidak ada tool/event/pet yang cocok",
				"Coba kata kunci lain seperti: cash, speed, unbox, ban, fae, crate",
				"Reset Search",
				C.AccentBlue,
				function()
					searchInput.Text = ""
				end,
				nil
			)
		end
	end

	task.defer(function()
		content.CanvasPosition = savedPos
	end)
end

searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	uiState.searchQuery = trimLower(searchInput.Text)
	renderAdminPanel(true)
end)

clearSearchBtn.MouseButton1Click:Connect(function()
	searchInput.Text = ""
end)

local tabs = {
	{ id = "Mod", label = "Players" },
	{ id = "Economy", label = "Economy" },
	{ id = "Spawn", label = "Spawn" },
	{ id = "Rates", label = "Rates" },
	{ id = "Abuse", label = "Events" },
	{ id = "Tools", label = "Tools" },
}
for i, t in ipairs(tabs) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.new(0.158, 0, 1, 0)
	b.BackgroundColor3 = C.TabIdle
	b.Text = t.label
	b.TextColor3 = C.TextMuted
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = tabBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	addPad(b, 4, 0)
	local st = addStroke(b, 1.0, C.CardStroke)
	b.MouseButton1Click:Connect(function()
		uiState.activeTab = t.id
		if searchInput.Text ~= "" then
			uiState.searchQuery = ""
			searchInput.Text = ""
		else
			renderAdminPanel(true)
		end
	end)
	table.insert(tabButtons, { id = t.id, label = t.label, btn = b, stroke = st })
end

toggleBtn.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
	if frame.Visible then
		renderAdminPanel()
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.F2 and (adminState.rank or 0) >= 2 then
		frame.Visible = not frame.Visible
		if frame.Visible then
			renderAdminPanel()
		end
	end
end)

Remotes.Get("AdminStateSync").OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	adminState = state
	local rank = tonumber(state.rank) or 0
	local isOwner = (state.title == "Owner") or rank >= 3
	toggleBtn.Visible = rank >= 2
	toggleBtn.Text = if isOwner then "👑 OWNER (F2)" else "🛡️ ADMIN (F2)"
	toggleBtn.BackgroundColor3 = if isOwner then Color3.fromRGB(202, 138, 4) else C.AccentPink
	title.Text = if isOwner then "👑 OWNER (SUPERADMIN) PANEL" else "🛡️ SERVER ADMIN PANEL"
	title.TextColor3 = if isOwner then Color3.fromRGB(255, 214, 72) else Color3.fromRGB(244, 114, 182)
	fStroke.Color = if isOwner then Color3.fromRGB(161, 110, 24) else Color3.fromRGB(190, 48, 96)

	if rank < 2 then
		frame.Visible = false
		return
	end
	if frame.Visible then
		local focused = UserInputService:GetFocusedTextBox()
		if focused and focused:IsDescendantOf(content) then
			return
		end
		renderAdminPanel()
	end
end)

-- Live 1-second local countdown refresh for open Event cards (non-destructive, zero focus loss!)
task.spawn(function()
	while true do
		task.wait(1)
		if frame.Visible and adminState.activeEvents then
			for id, rem in pairs(adminState.activeEvents) do
				if type(rem) == "number" and rem > 0 then
					local nxt = rem - 1
					adminState.activeEvents[id] = if nxt > 0 then nxt else nil
					local rec = liveEventSubLabels[id]
					if rec and rec.label.Parent then
						rec.label.Text = formatEventSubText(rec.def, if nxt > 0 then nxt else nil)
						if nxt <= 0 then
							rec.label.TextColor3 = C.TextMuted
						end
					end
				end
			end
		end
	end
end)
