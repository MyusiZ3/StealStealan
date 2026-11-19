--!strict
-- AdminPanel.client.luau (PROVISIONED SERVER-SIDE ONLY via ServerScriptService.Services.AdminUI)
-- Server-cloned into PlayerGui exclusively for verified Rank >= 2 Admin / Owner players.
-- Compact 6-Tab Architecture:
--   1. Spawner (Multi-Select Rarity + % Weight, Mutation + % Chance, Min/Max Weight Ratio, Area, Qty)
--   2. Give Player (Crate Inv / Ready Pen Crate / Direct Pet, Rarity & Species, Mutation, Weight, Qty)
--   3. Semi-RNG & Rates (Rarity %, Mutation %, Size Bracket %, & Pity Counters)
--   4. Events (Categorized Admin Abuse Events + Duration + Broadcast)
--   5. Players & Mod (Teleport, Heal/Freeze/Kill, Economy, Ban/Kick, Owner Role Management)
--   6. Self Tools (God/Pull/Unbox/Speed/Invis + Live Multipliers)
-- Global Header Scope Switch: [📍 This Server] vs [🌐 All Servers] (MessagingService cross-server relay)

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
	rarityWeightOverrides = {},
	mutationWeightOverrides = {},
	sizeBracketOverrides = {},
	semiRngPity = { luckyEvery = 10, ultraEvery = 25 },
	forcedWildMutation = "Random",
	selfTools = {},
	players = {},
}

local uiState = {
	activeTab = "Spawner",
	scope = "ThisServer", -- "ThisServer" | "AllServers"
	searchQuery = "",
	selectedTargetUserId = localPlayer.UserId,
	-- Tab 1: Spawner
	spawnerRarities = {
		Legendary = 50,
		Mythic = 35,
		Primordial = 15,
	} :: { [string]: number },
	spawnerMutation = "Random",
	spawnerMutationPct = 35,
	spawnerMinRatio = 0.85,
	spawnerMaxRatio = 2.20,
	spawnerQty = 5,
	spawnerArea = "Default",
	-- Tab 2: Give Player
	giveMode = "CrateInv", -- "CrateInv" | "PenCrate" | "DirectPet"
	giveRarity = "Primordial",
	giveUseSpecies = true,
	giveSpeciesId = AnimalConfig.ALL[#AnimalConfig.ALL].id,
	giveMutation = "Rainbow",
	giveMinRatio = 2.0,
	giveMaxRatio = 2.5,
	giveQty = 1,
	-- Tab 4: Events
	customEventSeconds = 120,
	useDefaultEventDuration = false,
	eventCategory = "All", -- "All" | "Economy" | "Luck" | "Chaos"
}

local EVENT_CATEGORIES: { [string]: string } = {
	DoubleCash = "Economy",
	DoubleSpeed = "Economy",
	GoldenFever = "Economy",
	SuperLuck5x = "Luck",
	MutationParty100x = "Luck",
	InstantUnboxParty = "Luck",
	CrateRain = "Chaos",
	TitanicZoo = "Chaos",
	ZeroResistance = "Chaos",
	PoacherStampede = "Chaos",
}

local C = {
	ModalBg = Color3.fromRGB(16, 20, 30),
	PanelBg = Color3.fromRGB(11, 14, 22),
	CardBg = Color3.fromRGB(24, 30, 46),
	CardStroke = Color3.fromRGB(46, 58, 84),
	InputBg = Color3.fromRGB(13, 17, 27),
	TabIdle = Color3.fromRGB(28, 35, 52),
	TextMain = Color3.fromRGB(244, 247, 252),
	TextMuted = Color3.fromRGB(148, 163, 184),
	AccentBlue = Color3.fromRGB(37, 99, 235),
	AccentGreen = Color3.fromRGB(22, 163, 74),
	AccentRed = Color3.fromRGB(204, 42, 54),
	AccentAmber = Color3.fromRGB(202, 138, 4),
	AccentPurple = Color3.fromRGB(126, 34, 206),
	AccentTeal = Color3.fromRGB(13, 148, 136),
	AccentPink = Color3.fromRGB(219, 39, 119),
	AccentCyan = Color3.fromRGB(8, 145, 178),
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
frame.Size = UDim2.fromOffset(740, 548)
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
		frameScale.Scale = math.clamp(math.min((vp.X - 36) / 770, (vp.Y - 36) / 576), 0.45, 1.12)
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

-- Header Bar + Global Scope Toggle
local title = Instance.new("TextLabel")
title.Name = "HeaderTitle"
title.Size = UDim2.new(1, -246, 0, 30)
title.Position = UDim2.fromOffset(14, 8)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SERVER ADMIN PANEL"
title.TextColor3 = Color3.fromRGB(255, 208, 72)
title.Font = Enum.Font.FredokaOne
title.TextSize = 19
title.TextTruncate = Enum.TextTruncate.AtEnd
title.Parent = frame

local scopeBtn = Instance.new("TextButton")
scopeBtn.Name = "ScopeSwitchButton"
scopeBtn.Size = UDim2.fromOffset(180, 28)
scopeBtn.Position = UDim2.new(1, -226, 0, 9)
scopeBtn.BackgroundColor3 = C.AccentTeal
scopeBtn.Text = "📍 Scope: This Server"
scopeBtn.TextColor3 = Color3.new(1, 1, 1)
scopeBtn.Font = Enum.Font.GothamBold
scopeBtn.TextSize = 12
scopeBtn.Parent = frame
Instance.new("UICorner", scopeBtn).CornerRadius = UDim.new(0, 7)
addStroke(scopeBtn, 1.3, Color3.fromRGB(255, 255, 255))

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

-- Global Search Bar
local searchBarFrame = Instance.new("Frame")
searchBarFrame.Name = "AdminSearchBar"
searchBarFrame.Size = UDim2.new(1, -28, 0, 30)
searchBarFrame.Position = UDim2.fromOffset(14, 42)
searchBarFrame.BackgroundColor3 = C.InputBg
searchBarFrame.Parent = frame
Instance.new("UICorner", searchBarFrame).CornerRadius = UDim.new(0, 8)
addStroke(searchBarFrame, 1.3, C.CardStroke)

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.fromOffset(26, 30)
searchIcon.Position = UDim2.fromOffset(4, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextSize = 13
searchIcon.TextColor3 = C.TextMuted
searchIcon.Parent = searchBarFrame

local searchInput = Instance.new("TextBox")
searchInput.Name = "SearchInput"
searchInput.Size = UDim2.new(1, -64, 1, 0)
searchInput.Position = UDim2.fromOffset(30, 0)
searchInput.BackgroundTransparency = 1
searchInput.PlaceholderText = "Filter tools, rarities, species, events, mutations..."
searchInput.PlaceholderColor3 = C.TextMuted
searchInput.Text = ""
searchInput.ClearTextOnFocus = false
searchInput.TextXAlignment = Enum.TextXAlignment.Left
searchInput.TextColor3 = C.TextMain
searchInput.Font = Enum.Font.GothamBold
searchInput.TextSize = 12
searchInput.Parent = searchBarFrame

local clearSearchBtn = Instance.new("TextButton")
clearSearchBtn.Name = "ClearSearchBtn"
clearSearchBtn.Size = UDim2.fromOffset(24, 22)
clearSearchBtn.Position = UDim2.new(1, -28, 0, 4)
clearSearchBtn.BackgroundColor3 = C.TabIdle
clearSearchBtn.Text = "✕"
clearSearchBtn.TextColor3 = C.TextMain
clearSearchBtn.Font = Enum.Font.GothamBold
clearSearchBtn.TextSize = 12
clearSearchBtn.Visible = false
clearSearchBtn.Parent = searchBarFrame
Instance.new("UICorner", clearSearchBtn).CornerRadius = UDim.new(0, 6)

-- 6 Clean Tab Strip
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -28, 0, 32)
tabBar.Position = UDim2.fromOffset(14, 78)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

local tabButtons: { { id: string, label: string, btn: TextButton, stroke: UIStroke } } = {}

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -28, 1, -124)
content.Position = UDim2.fromOffset(14, 114)
content.BackgroundColor3 = C.PanelBg
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = Color3.fromRGB(96, 114, 152)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.Parent = frame
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 10)
addPad(content, 10, 10)

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local function fireAdmin(action: string, payload: { [string]: any }?)
	local finalPayload = if payload then table.clone(payload) else {}
	if finalPayload.scope == nil then
		finalPayload.scope = uiState.scope
	end
	Remotes.Get("AdminCommand"):FireServer(action, finalPayload)
end

local function refreshScopeVisual()
	if uiState.scope == "AllServers" then
		scopeBtn.Text = "🌐 Scope: All Servers"
		scopeBtn.BackgroundColor3 = C.AccentAmber
	else
		scopeBtn.Text = "📍 Scope: This Server"
		scopeBtn.BackgroundColor3 = C.AccentTeal
	end
end

-- Compact Reusable UI Helpers
local orderSeq = 0
local function nextOrder(): number
	orderSeq += 1
	return orderSeq
end

local function matchesQuery(haystack: string): boolean
	local q = string.lower(string.gsub(uiState.searchQuery, "^%s*(.-)%s*$", "%1"))
	if q == "" then return true end
	return string.find(string.lower(haystack), q, 1, true) ~= nil
end

local function mkSection(text: string, parent: Instance?): Frame
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 22)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = nextOrder()
	wrap.Parent = parent or content
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.upper(text)
	lbl.TextColor3 = Color3.fromRGB(162, 184, 228)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = wrap
	return wrap
end

local function mkCard(height: number?, parent: Instance?): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height or 0)
	if not height or height == 0 then
		card.AutomaticSize = Enum.AutomaticSize.Y
	end
	card.BackgroundColor3 = C.CardBg
	card.LayoutOrder = nextOrder()
	card.Parent = parent or content
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
	addStroke(card, 1.2, C.CardStroke)
	addPad(card, 10, 8)
	return card
end

local function mkBtn(parent: Instance, text: string, color: Color3, size: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	addStroke(b, 1, Color3.new(0, 0, 0))
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function mkInput(parent: Instance, defaultText: string, placeholder: string, size: UDim2): TextBox
	local tb = Instance.new("TextBox")
	tb.Size = size
	tb.BackgroundColor3 = C.InputBg
	tb.Text = defaultText
	tb.PlaceholderText = placeholder
	tb.PlaceholderColor3 = C.TextMuted
	tb.ClearTextOnFocus = false
	tb.TextColor3 = Color3.new(1, 1, 1)
	tb.Font = Enum.Font.GothamBold
	tb.TextSize = 12
	tb.Parent = parent
	Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 7)
	addStroke(tb, 1.1, C.CardStroke)
	return tb
end

local function mkChipRow(parent: Instance, items: { { id: string, label: string, color: Color3? } }, selectedId: string, onSelect: (string) -> ())
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = nextOrder()
	wrap.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 106, 0, 26)
	grid.CellPadding = UDim2.fromOffset(5, 5)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = wrap

	for i, it in ipairs(items) do
		local isSel = (it.id == selectedId)
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = i
		btn.BackgroundColor3 = if isSel then (it.color or C.AccentBlue) else C.TabIdle
		btn.Text = it.label
		btn.TextColor3 = if isSel then Color3.new(1, 1, 1) else C.TextMuted
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.Parent = wrap
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		addStroke(btn, if isSel then 1.8 else 1.0, if isSel then Color3.new(1, 1, 1) else C.CardStroke)
		btn.MouseButton1Click:Connect(function()
			onSelect(it.id)
		end)
	end
end

local renderAdminPanel: (boolean?) -> ()

local function addTargetPlayerBar(parent: Instance)
	local card = mkCard(nil, parent)
	local v = Instance.new("UIListLayout")
	v.Padding = UDim.new(0, 6)
	v.SortOrder = Enum.SortOrder.LayoutOrder
	v.Parent = card

	local hdr = Instance.new("TextLabel")
	hdr.Size = UDim2.new(1, 0, 0, 16)
	hdr.BackgroundTransparency = 1
	hdr.Text = "Target Player (@Me, online players, or UserId):"
	hdr.TextColor3 = C.TextMuted
	hdr.Font = Enum.Font.GothamBold
	hdr.TextSize = 11
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.LayoutOrder = 1
	hdr.Parent = card

	local row = Instance.new("ScrollingFrame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollBarThickness = 3
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new(0, 0, 0, 0)
	row.LayoutOrder = 2
	row.Parent = card
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 5)
	rl.Parent = row

	local meSel = uiState.selectedTargetUserId == localPlayer.UserId
	mkBtn(row, "@Me (" .. localPlayer.Name .. ")", if meSel then C.AccentBlue else C.TabIdle, UDim2.fromOffset(124, 26), function()
		uiState.selectedTargetUserId = localPlayer.UserId
		renderAdminPanel(true)
	end)
	for _, p in ipairs(adminState.players or {}) do
		if p.userId ~= localPlayer.UserId then
			local sel = (uiState.selectedTargetUserId == p.userId)
			mkBtn(row, p.name, if sel then C.AccentBlue else C.TabIdle, UDim2.fromOffset(110, 26), function()
				uiState.selectedTargetUserId = p.userId
				renderAdminPanel(true)
			end)
		end
	end

	local uidRow = Instance.new("Frame")
	uidRow.Size = UDim2.new(1, 0, 0, 26)
	uidRow.BackgroundTransparency = 1
	uidRow.LayoutOrder = 3
	uidRow.Parent = card
	local uidIn = mkInput(uidRow, tostring(uiState.selectedTargetUserId), "Target UserId", UDim2.new(0.68, -6, 1, 0))
	mkBtn(uidRow, "Set UserId", C.AccentTeal, UDim2.new(0.32, 0, 1, 0), function()
		local n = tonumber(uidIn.Text)
		if n and n == n then
			uiState.selectedTargetUserId = math.floor(n)
			renderAdminPanel(true)
		end
	end).Position = UDim2.fromScale(0.68, 0)
end

-- ============================================================================
-- TAB 1: WORLD CRATE SPAWNER (Multi-Select Rarity + % Weight + Mut % + Range)
-- ============================================================================
local function buildSpawnerTab()
	mkSection("1. Multi-Select Rarity Pool & Weight (%) — Pick 1 or More", content)
	local rarCard = mkCard(nil, content)
	local rv = Instance.new("UIListLayout")
	rv.Padding = UDim.new(0, 6)
	rv.SortOrder = Enum.SortOrder.LayoutOrder
	rv.Parent = rarCard

	-- Quick Presets Row
	local presetRow = Instance.new("Frame")
	presetRow.Size = UDim2.new(1, 0, 0, 26)
	presetRow.BackgroundTransparency = 1
	presetRow.LayoutOrder = 1
	presetRow.Parent = rarCard
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.Padding = UDim.new(0, 6)
	pl.Parent = presetRow
	mkBtn(presetRow, "Apex Only", C.AccentPurple, UDim2.fromOffset(96, 26), function()
		uiState.spawnerRarities = { Astral = 25, Omega = 25, Singularity = 25, Primordial = 25 }
		renderAdminPanel(true)
	end)
	mkBtn(presetRow, "Legendary+", C.AccentAmber, UDim2.fromOffset(102, 26), function()
		uiState.spawnerRarities = {}
		for _, r in ipairs(GameConfig.RARITY_ORDER) do
			if GameConfig.GetRarityTier(r) >= 5 then
				uiState.spawnerRarities[r] = 10
			end
		end
		renderAdminPanel(true)
	end)
	mkBtn(presetRow, "Select All", C.AccentBlue, UDim2.fromOffset(88, 26), function()
		uiState.spawnerRarities = {}
		for _, r in ipairs(GameConfig.RARITY_ORDER) do
			uiState.spawnerRarities[r] = 10
		end
		renderAdminPanel(true)
	end)
	mkBtn(presetRow, "Clear (Primordial)", C.TabIdle, UDim2.fromOffset(124, 26), function()
		uiState.spawnerRarities = { Primordial = 100 }
		renderAdminPanel(true)
	end)

	-- Total Weight for % Share display
	local sumW = 0
	for r, w in pairs(uiState.spawnerRarities) do
		if GameConfig.RARITY_TIER_INDEX[r] and w > 0 then
			sumW += w
		end
	end

	local rarGridWrap = Instance.new("Frame")
	rarGridWrap.Size = UDim2.new(1, 0, 0, 0)
	rarGridWrap.AutomaticSize = Enum.AutomaticSize.Y
	rarGridWrap.BackgroundTransparency = 1
	rarGridWrap.LayoutOrder = 2
	rarGridWrap.Parent = rarCard
	local rg = Instance.new("UIGridLayout")
	rg.CellSize = UDim2.new(0, 128, 0, 48)
	rg.CellPadding = UDim2.fromOffset(5, 5)
	rg.SortOrder = Enum.SortOrder.LayoutOrder
	rg.Parent = rarGridWrap

	for i, r in ipairs(GameConfig.RARITY_ORDER) do
		if matchesQuery(r) then
			local wVal = uiState.spawnerRarities[r]
			local isSel = (wVal ~= nil)
			local rCol = (GameConfig.RARITY_COLORS :: any)[r] or C.AccentBlue
			local cell = Instance.new("Frame")
			cell.LayoutOrder = i
			cell.BackgroundColor3 = if isSel then Color3.fromRGB(28, 38, 62) else C.TabIdle
			cell.Parent = rarGridWrap
			Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 7)
			addStroke(cell, if isSel then 1.8 else 1.0, if isSel then rCol else C.CardStroke)

			local pctText = if isSel and sumW > 0 then string.format("%.0f%%", (wVal / sumW) * 100) else "OFF"
			local togBtn = Instance.new("TextButton")
			togBtn.Size = UDim2.new(1, 0, 0, 24)
			togBtn.BackgroundTransparency = 1
			togBtn.Text = (if isSel then "☑ " else "☐ ") .. r
			togBtn.TextColor3 = if isSel then rCol else C.TextMuted
			togBtn.Font = Enum.Font.GothamBold
			togBtn.TextSize = 11
			togBtn.Parent = cell
			togBtn.MouseButton1Click:Connect(function()
				if uiState.spawnerRarities[r] ~= nil then
					uiState.spawnerRarities[r] = nil
				else
					uiState.spawnerRarities[r] = 25
				end
				renderAdminPanel(true)
			end)

			local wBox = mkInput(cell, if isSel then tostring(wVal) else "", "% Wt (" .. pctText .. ")", UDim2.new(0.62, 0, 0, 20))
			wBox.Position = UDim2.fromOffset(4, 25)
			wBox.TextSize = 10
			wBox.FocusLost:Connect(function()
				local n = tonumber(wBox.Text)
				if n and n >= 0 then
					uiState.spawnerRarities[r] = n
					renderAdminPanel(true)
				end
			end)
			local shareLbl = Instance.new("TextLabel")
			shareLbl.Size = UDim2.new(0.34, -4, 0, 20)
			shareLbl.Position = UDim2.new(0.64, 0, 0, 25)
			shareLbl.BackgroundTransparency = 1
			shareLbl.Text = pctText
			shareLbl.TextColor3 = if isSel then Color3.fromRGB(118, 245, 162) else C.TextMuted
			shareLbl.Font = Enum.Font.GothamBold
			shareLbl.TextSize = 10
			shareLbl.Parent = cell
		end
	end

	-- Mutation & % Chance + Weight Range + Area + Qty
	mkSection("2. Mutation Chance (%), Weight/Size Range, Area & Spawn", content)
	local optCard = mkCard(nil, content)
	local ov = Instance.new("UIListLayout")
	ov.Padding = UDim.new(0, 7)
	ov.SortOrder = Enum.SortOrder.LayoutOrder
	ov.Parent = optCard

	local mutItems = { { id = "None", label = "None", color = C.TabIdle }, { id = "Random", label = "🎲 Random Pool", color = C.AccentPurple } }
	for _, mKey in ipairs(GameConfig.MUTATION_ORDER) do
		if mKey ~= "None" then
			local info = (GameConfig.MUTATIONS :: any)[mKey]
			table.insert(mutItems, { id = mKey, label = mKey, color = if info then info.color else C.AccentPink })
		end
	end
	mkChipRow(optCard, mutItems, uiState.spawnerMutation, function(id)
		uiState.spawnerMutation = id
		renderAdminPanel(true)
	end)

	local numRow = Instance.new("Frame")
	numRow.Size = UDim2.new(1, 0, 0, 44)
	numRow.BackgroundTransparency = 1
	numRow.LayoutOrder = nextOrder()
	numRow.Parent = optCard
	local ng = Instance.new("UIGridLayout")
	ng.CellSize = UDim2.new(0.242, 0, 1, 0)
	ng.CellPadding = UDim2.new(0.01, 0, 0, 0)
	ng.Parent = numRow

	local function addLabeledInput(label: string, defaultVal: string, onChange: (string) -> ())
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.Parent = numRow
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 16)
		l.BackgroundTransparency = 1
		l.Text = label
		l.TextColor3 = C.TextMuted
		l.Font = Enum.Font.GothamBold
		l.TextSize = 10
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = col
		local tb = mkInput(col, defaultVal, label, UDim2.new(1, 0, 0, 26))
		tb.Position = UDim2.fromOffset(0, 18)
		tb.FocusLost:Connect(function()
			onChange(tb.Text)
		end)
		return tb
	end

	local mutPctBox = addLabeledInput("Mutation % (0-100)", tostring(uiState.spawnerMutationPct), function(t)
		uiState.spawnerMutationPct = math.clamp(tonumber(t) or 0, 0, 100)
	end)
	local minRatioBox = addLabeledInput("Min Weight Ratio (x)", tostring(uiState.spawnerMinRatio), function(t)
		uiState.spawnerMinRatio = math.clamp(tonumber(t) or 0.85, 0.4, 10.0)
	end)
	local maxRatioBox = addLabeledInput("Max Weight Ratio (x)", tostring(uiState.spawnerMaxRatio), function(t)
		uiState.spawnerMaxRatio = math.clamp(tonumber(t) or 2.20, 0.4, 12.0)
	end)
	local qtyBox = addLabeledInput("Quantity (1-50)", tostring(uiState.spawnerQty), function(t)
		uiState.spawnerQty = math.clamp(math.floor(tonumber(t) or 5), 1, 50)
	end)

	local areaItems = {
		{ id = "Default", label = "Default (By Rarity)", color = C.AccentTeal },
		{ id = "NearAdmin", label = "Near Admin", color = C.AccentAmber },
	}
	for _, b in ipairs(BiomeConfig) do
		table.insert(areaItems, { id = b.id, label = b.id, color = b.accentColor })
	end
	mkChipRow(optCard, areaItems, uiState.spawnerArea, function(id)
		uiState.spawnerArea = id
		renderAdminPanel(true)
	end)

	local scopeStr = if uiState.scope == "AllServers" then "🌐 ALL SERVERS" else "📍 THIS SERVER"
	mkBtn(optCard, "🚀 SPAWN WORLD CRATES [" .. scopeStr .. "]", C.AccentGreen, UDim2.new(1, 0, 0, 34), function()
		uiState.spawnerMutationPct = math.clamp(tonumber(mutPctBox.Text) or uiState.spawnerMutationPct, 0, 100)
		uiState.spawnerMinRatio = math.clamp(tonumber(minRatioBox.Text) or uiState.spawnerMinRatio, 0.4, 10.0)
		uiState.spawnerMaxRatio = math.clamp(tonumber(maxRatioBox.Text) or uiState.spawnerMaxRatio, uiState.spawnerMinRatio, 12.0)
		uiState.spawnerQty = math.clamp(math.floor(tonumber(qtyBox.Text) or uiState.spawnerQty), 1, 50)

		local packRarities = {}
		for r, w in pairs(uiState.spawnerRarities) do
			if w > 0 then
				table.insert(packRarities, { rarity = r, pct = w })
			end
		end
		if #packRarities == 0 then
			table.insert(packRarities, { rarity = "Legendary", pct = 100 })
		end
		fireAdmin("BatchSpawnWorldCrates", {
			rarities = packRarities,
			mutation = uiState.spawnerMutation,
			mutationChancePct = uiState.spawnerMutationPct,
			minWeightRatio = uiState.spawnerMinRatio,
			maxWeightRatio = uiState.spawnerMaxRatio,
			quantity = uiState.spawnerQty,
			area = uiState.spawnerArea,
		})
	end).LayoutOrder = nextOrder()
end

-- ============================================================================
-- TAB 2: GIVE PLAYER (Crate Inv / Ready Pen Crate / Direct Pet)
-- ============================================================================
local function buildGiveTab()
	addTargetPlayerBar(content)
	mkSection("Give Crate or Direct Pet to Target Player", content)

	local card = mkCard(nil, content)
	local cv = Instance.new("UIListLayout")
	cv.Padding = UDim.new(0, 7)
	cv.SortOrder = Enum.SortOrder.LayoutOrder
	cv.Parent = card

	mkChipRow(card, {
		{ id = "CrateInv", label = "🎒 Crate (Inv)", color = C.AccentBlue },
		{ id = "PenCrate", label = "🏡 Ready Crate (Pen)", color = C.AccentGreen },
		{ id = "DirectPet", label = "🐾 Direct Pet", color = C.AccentPurple },
	}, uiState.giveMode, function(id)
		uiState.giveMode = id
		renderAdminPanel(true)
	end)

	local rarItems = {}
	for _, r in ipairs(GameConfig.RARITY_ORDER) do
		table.insert(rarItems, { id = r, label = r, color = (GameConfig.RARITY_COLORS :: any)[r] })
	end
	mkChipRow(card, rarItems, uiState.giveRarity, function(id)
		uiState.giveRarity = id
		for _, s in ipairs(AnimalConfig.ALL) do
			if s.rarity == id then
				uiState.giveSpeciesId = s.id
				break
			end
		end
		renderAdminPanel(true)
	end)

	-- Species picker filtered by rarity (+ searchQuery)
	local modeTogRow = Instance.new("Frame")
	modeTogRow.Size = UDim2.new(1, 0, 0, 26)
	modeTogRow.BackgroundTransparency = 1
	modeTogRow.LayoutOrder = nextOrder()
	modeTogRow.Parent = card
	mkBtn(modeTogRow, if uiState.giveUseSpecies then "🎯 Mode: Specific Species (Below)" else "🎲 Mode: Random of Rarity", if uiState.giveUseSpecies then C.AccentTeal else C.TabIdle, UDim2.new(0.62, -6, 1, 0), function()
		uiState.giveUseSpecies = not uiState.giveUseSpecies
		renderAdminPanel(true)
	end)
	mkBtn(modeTogRow, "⚡ Instant-Ready Pen Crates", C.AccentAmber, UDim2.new(0.38, 0, 1, 0), function()
		fireAdmin("InstantReadyCrates", { targetUserId = uiState.selectedTargetUserId })
	end).Position = UDim2.fromScale(0.62, 0)

	local specScroll = Instance.new("ScrollingFrame")
	specScroll.Size = UDim2.new(1, 0, 0, 128)
	specScroll.BackgroundColor3 = C.InputBg
	specScroll.BorderSizePixel = 0
	specScroll.ScrollBarThickness = 5
	specScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	specScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	specScroll.LayoutOrder = nextOrder()
	specScroll.Parent = card
	Instance.new("UICorner", specScroll).CornerRadius = UDim.new(0, 8)
	addPad(specScroll, 6, 6)
	local sg = Instance.new("UIGridLayout")
	sg.CellSize = UDim2.new(0.324, 0, 0, 38)
	sg.CellPadding = UDim2.fromOffset(5, 5)
	sg.Parent = specScroll

	local selectedSpec = AnimalConfig.GetById(uiState.giveSpeciesId) or AnimalConfig.ALL[1]
	for idx, s in ipairs(AnimalConfig.ALL) do
		local matchRar = (uiState.searchQuery ~= "") or (s.rarity == uiState.giveRarity)
		if matchRar and matchesQuery(s.name .. " " .. s.rarity .. " " .. s.biomeId) then
			local isSel = (s.id == uiState.giveSpeciesId)
			local btn = mkBtn(specScroll, string.format("%s\n%s • $%s/s", s.name, s.rarity, FormatUtil.Number(s.baseIncomePerSec)), if isSel then C.AccentPink else C.CardBg, UDim2.fromOffset(0, 0), function()
				uiState.giveSpeciesId = s.id
				uiState.giveRarity = s.rarity
				uiState.giveUseSpecies = true
				renderAdminPanel(true)
			end)
			btn.LayoutOrder = idx
			btn.TextSize = 10
		end
	end

	local mutItems = {}
	for _, mKey in ipairs(GameConfig.MUTATION_ORDER) do
		local info = (GameConfig.MUTATIONS :: any)[mKey]
		table.insert(mutItems, { id = mKey, label = mKey, color = if info then info.color else C.TabIdle })
	end
	mkChipRow(card, mutItems, uiState.giveMutation, function(id)
		uiState.giveMutation = id
		renderAdminPanel(true)
	end)

	local bottomRow = Instance.new("Frame")
	bottomRow.Size = UDim2.new(1, 0, 0, 44)
	bottomRow.BackgroundTransparency = 1
	bottomRow.LayoutOrder = nextOrder()
	bottomRow.Parent = card
	local bg = Instance.new("UIGridLayout")
	bg.CellSize = UDim2.new(0.242, 0, 1, 0)
	bg.CellPadding = UDim2.new(0.01, 0, 0, 0)
	bg.Parent = bottomRow

	local function addGiveBox(lbl: string, val: string): TextBox
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.Parent = bottomRow
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 16)
		l.BackgroundTransparency = 1
		l.Text = lbl
		l.TextColor3 = C.TextMuted
		l.Font = Enum.Font.GothamBold
		l.TextSize = 10
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = col
		local tb = mkInput(col, val, lbl, UDim2.new(1, 0, 0, 26))
		tb.Position = UDim2.fromOffset(0, 18)
		return tb
	end

	local minBox = addGiveBox("Min Weight (x)", tostring(uiState.giveMinRatio))
	local maxBox = addGiveBox("Max Weight (x)", tostring(uiState.giveMaxRatio))
	local qBox = addGiveBox("Quantity (1-25)", tostring(uiState.giveQty))

	local estKg = math.floor(selectedSpec.baseWeightKg * math.pow(uiState.giveMaxRatio, 2.2) * 10 + 0.5) / 10
	local previewCol = Instance.new("Frame")
	previewCol.BackgroundTransparency = 1
	previewCol.Parent = bottomRow
	local prevLbl = Instance.new("TextLabel")
	prevLbl.Size = UDim2.fromScale(1, 1)
	prevLbl.BackgroundTransparency = 1
	prevLbl.Text = string.format("Max ≈ %.1f KG\n(%s)", estKg, selectedSpec.name)
	prevLbl.TextColor3 = Color3.fromRGB(118, 245, 162)
	prevLbl.Font = Enum.Font.GothamBold
	prevLbl.TextSize = 11
	prevLbl.TextWrapped = true
	prevLbl.Parent = previewCol

	mkBtn(card, "🎁 GIVE TO TARGET PLAYER", C.AccentPink, UDim2.new(1, 0, 0, 32), function()
		uiState.giveMinRatio = math.clamp(tonumber(minBox.Text) or uiState.giveMinRatio, 0.45, 10.0)
		uiState.giveMaxRatio = math.clamp(tonumber(maxBox.Text) or uiState.giveMaxRatio, uiState.giveMinRatio, 12.0)
		uiState.giveQty = math.clamp(math.floor(tonumber(qBox.Text) or uiState.giveQty), 1, 25)
		fireAdmin("GivePlayerItems", {
			targetUserId = uiState.selectedTargetUserId,
			giveMode = uiState.giveMode,
			biomeId = selectedSpec.biomeId,
			rarity = uiState.giveRarity,
			speciesId = uiState.giveSpeciesId,
			useSelectedSpecies = uiState.giveUseSpecies,
			mutation = uiState.giveMutation,
			minWeightRatio = uiState.giveMinRatio,
			maxWeightRatio = uiState.giveMaxRatio,
			quantity = uiState.giveQty,
			instantReady = true,
		})
	end).LayoutOrder = nextOrder()
end

-- ============================================================================
-- TAB 3: SEMI-RNG & GLOBAL RATES (Rarity %, Mutation %, Size %, Pity)
-- ============================================================================
local function buildRatesTab()
	local isOwner = (tonumber(adminState.rank) or 0) >= 3
	if not isOwner then
		local warnCard = mkCard(40, content)
		local wl = Instance.new("TextLabel")
		wl.Size = UDim2.fromScale(1, 1)
		wl.BackgroundTransparency = 1
		wl.Text = "🔒 Owner (Rank 3) required to edit Semi-RNG & Spawn Rates."
		wl.TextColor3 = Color3.fromRGB(255, 118, 118)
		wl.Font = Enum.Font.GothamBold
		wl.TextSize = 13
		wl.Parent = warnCard
		return
	end

	-- Top Actions + Global Luck Multipliers
	local topCard = mkCard(nil, content)
	local tv = Instance.new("UIListLayout")
	tv.Padding = UDim.new(0, 6)
	tv.SortOrder = Enum.SortOrder.LayoutOrder
	tv.Parent = topCard

	local topBtns = Instance.new("Frame")
	topBtns.Size = UDim2.new(1, 0, 0, 28)
	topBtns.BackgroundTransparency = 1
	topBtns.LayoutOrder = 1
	topBtns.Parent = topCard
	mkBtn(topBtns, "🔄 Respawn All Biome Crates", C.AccentGreen, UDim2.new(0.49, -3, 1, 0), function()
		fireAdmin("TriggerWaveReset")
	end)
	mkBtn(topBtns, "♻️ Reset All Rates to Default", C.AccentRed, UDim2.new(0.49, 0, 1, 0), function()
		fireAdmin("ResetSpawnRates")
	end).Position = UDim2.fromScale(0.51, 0)

	local luckRow = Instance.new("Frame")
	luckRow.Size = UDim2.new(1, 0, 0, 28)
	luckRow.BackgroundTransparency = 1
	luckRow.LayoutOrder = 2
	luckRow.Parent = topCard
	local rarLuckIn = mkInput(luckRow, tostring((adminState.liveTuners and adminState.liveTuners.rarityLuckMult) or 1), "Crate Luck", UDim2.new(0.24, -4, 1, 0))
	mkBtn(luckRow, "Set Crate Luck x", C.AccentAmber, UDim2.new(0.25, -4, 1, 0), function()
		fireAdmin("SetRarityLuck", { value = tonumber(rarLuckIn.Text) or 1 })
	end).Position = UDim2.fromScale(0.24, 0)
	local mutLuckIn = mkInput(luckRow, tostring((adminState.liveTuners and adminState.liveTuners.mutationLuckMult) or 1), "Mut Luck", UDim2.new(0.24, -4, 1, 0))
	mutLuckIn.Position = UDim2.fromScale(0.51, 0)
	mkBtn(luckRow, "Set Mut Luck x", C.AccentPurple, UDim2.new(0.25, 0, 1, 0), function()
		fireAdmin("SetMutationLuck", { value = tonumber(mutLuckIn.Text) or 1 })
	end).Position = UDim2.fromScale(0.75, 0)

	-- Section A: Crate Rarity Weights (%)
	mkSection("A. Crate Rarity Spawn Rates (% Share & Weight)", content)
	local rOverrides = adminState.rarityWeightOverrides or {}
	local totalRarW = 0
	for _, r in ipairs(GameConfig.RARITY_ORDER) do
		local w = if rOverrides[r] ~= nil then tonumber(rOverrides[r]) or 0 else ((GameConfig.RARITY_WEIGHTS :: any)[r] or 1)
		totalRarW += math.max(0, w)
	end

	local rarWrap = mkCard(nil, content)
	local rwGrid = Instance.new("UIGridLayout")
	rwGrid.CellSize = UDim2.new(0.324, 0, 0, 52)
	rwGrid.CellPadding = UDim2.fromOffset(6, 6)
	rwGrid.Parent = rarWrap

	for i, r in ipairs(GameConfig.RARITY_ORDER) do
		if matchesQuery(r) then
			local defW = (GameConfig.RARITY_WEIGHTS :: any)[r] or 1
			local curW = if rOverrides[r] ~= nil then (tonumber(rOverrides[r]) or defW) else defW
			local pct = if totalRarW > 0 then (curW / totalRarW) * 100 else 0
			local cell = Instance.new("Frame")
			cell.LayoutOrder = i
			cell.BackgroundColor3 = C.InputBg
			cell.Parent = rarWrap
			Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 7)
			addStroke(cell, 1, (GameConfig.RARITY_COLORS :: any)[r] or C.CardStroke)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 0, 18)
			lbl.Position = UDim2.fromOffset(4, 2)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("%s (%.3g%%)", r, pct)
			lbl.TextColor3 = (GameConfig.RARITY_COLORS :: any)[r] or C.TextMain
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 10
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = cell

			local inBox = mkInput(cell, tostring(curW), "Wt", UDim2.new(0.50, -4, 0, 22))
			inBox.Position = UDim2.fromOffset(4, 24)
			inBox.TextSize = 10
			local setB = mkBtn(cell, "Set", C.AccentBlue, UDim2.new(0.24, -2, 0, 22), function()
				fireAdmin("SetRarityWeight", { rarity = r, weight = tonumber(inBox.Text) })
			end)
			setB.Position = UDim2.new(0.50, 2, 0, 24)
			setB.TextSize = 10
			local clrB = mkBtn(cell, "Def", C.TabIdle, UDim2.new(0.24, -4, 0, 22), function()
				fireAdmin("SetRarityWeight", { rarity = r, weight = -1 })
			end)
			clrB.Position = UDim2.new(0.75, 2, 0, 24)
			clrB.TextSize = 10
		end
	end

	-- Section B: Pet Mutation Weights (%) + Forced Wild Mutation
	mkSection("B. Pet Mutation Roll Rates (%) & Forced Wild Mutation", content)
	local mOverrides = adminState.mutationWeightOverrides or {}
	local totalMutW = 0
	for _, mKey in ipairs(GameConfig.MUTATION_ORDER) do
		local defW = ((GameConfig.MUTATIONS :: any)[mKey] and (GameConfig.MUTATIONS :: any)[mKey].weight) or 0
		local w = if mOverrides[mKey] ~= nil then (tonumber(mOverrides[mKey]) or defW) else defW
		totalMutW += math.max(0, w)
	end

	local mutCard = mkCard(nil, content)
	local mv = Instance.new("UIListLayout")
	mv.Padding = UDim.new(0, 6)
	mv.Parent = mutCard

	local forceItems = { { id = "Random", label = "Forced: Random", color = C.AccentGreen } }
	for _, mKey in ipairs(GameConfig.MUTATION_ORDER) do
		local info = (GameConfig.MUTATIONS :: any)[mKey]
		table.insert(forceItems, { id = mKey, label = mKey, color = if info then info.color else C.AccentPink })
	end
	mkChipRow(mutCard, forceItems, tostring(adminState.forcedWildMutation or "Random"), function(id)
		fireAdmin("SetForcedMutation", { mutation = id })
	end)

	local mutGrid = Instance.new("Frame")
	mutGrid.Size = UDim2.new(1, 0, 0, 0)
	mutGrid.AutomaticSize = Enum.AutomaticSize.Y
	mutGrid.BackgroundTransparency = 1
	mutGrid.Parent = mutCard
	local mg = Instance.new("UIGridLayout")
	mg.CellSize = UDim2.new(0.324, 0, 0, 52)
	mg.CellPadding = UDim2.fromOffset(6, 6)
	mg.Parent = mutGrid

	for i, mKey in ipairs(GameConfig.MUTATION_ORDER) do
		if matchesQuery(mKey) then
			local mInfo = (GameConfig.MUTATIONS :: any)[mKey]
			local defW = if mInfo then mInfo.weight else 1
			local curW = if mOverrides[mKey] ~= nil then (tonumber(mOverrides[mKey]) or defW) else defW
			local pct = if totalMutW > 0 then (curW / totalMutW) * 100 else 0
			local cell = Instance.new("Frame")
			cell.LayoutOrder = i
			cell.BackgroundColor3 = C.InputBg
			cell.Parent = mutGrid
			Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 7)
			addStroke(cell, 1, if mInfo then mInfo.color else C.CardStroke)

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 0, 18)
			lbl.Position = UDim2.fromOffset(4, 2)
			lbl.BackgroundTransparency = 1
			lbl.Text = string.format("%s (%.3g%%)", mKey, pct)
			lbl.TextColor3 = if mInfo then mInfo.color else C.TextMain
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 10
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = cell

			local inBox = mkInput(cell, tostring(curW), "Wt", UDim2.new(0.50, -4, 0, 22))
			inBox.Position = UDim2.fromOffset(4, 24)
			inBox.TextSize = 10
			local setB = mkBtn(cell, "Set", C.AccentPurple, UDim2.new(0.24, -2, 0, 22), function()
				fireAdmin("SetMutationWeight", { mutation = mKey, weight = tonumber(inBox.Text) })
			end)
			setB.Position = UDim2.new(0.50, 2, 0, 24)
			setB.TextSize = 10
			local clrB = mkBtn(cell, "Def", C.TabIdle, UDim2.new(0.24, -4, 0, 22), function()
				fireAdmin("SetMutationWeight", { mutation = mKey, weight = -1 })
			end)
			clrB.Position = UDim2.new(0.75, 2, 0, 24)
			clrB.TextSize = 10
		end
	end

	-- Section C: Weight / Size Brackets (%) & Semi-RNG Pity
	mkSection("C. Giant Weight Brackets (%) & Semi-RNG Pity Thresholds", content)
	local sOverrides = adminState.sizeBracketOverrides or {}
	local totalSizeW = 0
	for _, sb in ipairs(GameConfig.SIZE_BRACKETS) do
		local w = if sOverrides[sb.name] ~= nil then (tonumber(sOverrides[sb.name]) or sb.weight) else sb.weight
		totalSizeW += math.max(0, w)
	end

	local sizeCard = mkCard(nil, content)
	local sv = Instance.new("UIListLayout")
	sv.Padding = UDim.new(0, 6)
	sv.Parent = sizeCard

	local sbGrid = Instance.new("Frame")
	sbGrid.Size = UDim2.new(1, 0, 0, 0)
	sbGrid.AutomaticSize = Enum.AutomaticSize.Y
	sbGrid.BackgroundTransparency = 1
	sbGrid.Parent = sizeCard
	local sbg = Instance.new("UIGridLayout")
	sbg.CellSize = UDim2.new(0.324, 0, 0, 54)
	sbg.CellPadding = UDim2.fromOffset(6, 6)
	sbg.Parent = sbGrid

	for i, sb in ipairs(GameConfig.SIZE_BRACKETS) do
		local curW = if sOverrides[sb.name] ~= nil then (tonumber(sOverrides[sb.name]) or sb.weight) else sb.weight
		local pct = if totalSizeW > 0 then (curW / totalSizeW) * 100 else 0
		local cell = Instance.new("Frame")
		cell.LayoutOrder = i
		cell.BackgroundColor3 = C.InputBg
		cell.Parent = sbGrid
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 7)
		addStroke(cell, 1, C.AccentCyan)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -8, 0, 18)
		lbl.Position = UDim2.fromOffset(4, 2)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("%s %.2g-%.2gx (%.1f%%)", sb.name, sb.minRatio, sb.maxRatio, pct)
		lbl.TextColor3 = Color3.fromRGB(118, 228, 255)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = cell

		local inBox = mkInput(cell, tostring(curW), "Wt", UDim2.new(0.50, -4, 0, 22))
		inBox.Position = UDim2.fromOffset(4, 26)
		inBox.TextSize = 10
		local setB = mkBtn(cell, "Set", C.AccentCyan, UDim2.new(0.24, -2, 0, 22), function()
			fireAdmin("SetSizeBracketWeight", { bracket = sb.name, weight = tonumber(inBox.Text) })
		end)
		setB.Position = UDim2.new(0.50, 2, 0, 26)
		setB.TextSize = 10
		local clrB = mkBtn(cell, "Def", C.TabIdle, UDim2.new(0.24, -4, 0, 22), function()
			fireAdmin("SetSizeBracketWeight", { bracket = sb.name, weight = -1 })
		end)
		clrB.Position = UDim2.new(0.75, 2, 0, 26)
		clrB.TextSize = 10
	end

	local pity = adminState.semiRngPity or { luckyEvery = 10, ultraEvery = 25 }
	local pityRow = Instance.new("Frame")
	pityRow.Size = UDim2.new(1, 0, 0, 28)
	pityRow.BackgroundTransparency = 1
	pityRow.Parent = sizeCard
	local lBox = mkInput(pityRow, tostring(pity.luckyEvery or 10), "Lucky Every N", UDim2.new(0.28, -4, 1, 0))
	local uBox = mkInput(pityRow, tostring(pity.ultraEvery or 25), "Ultra Every N", UDim2.new(0.28, -4, 1, 0))
	uBox.Position = UDim2.fromScale(0.29, 0)
	mkBtn(pityRow, "Apply Semi-RNG Pity", C.AccentAmber, UDim2.new(0.42, 0, 1, 0), function()
		fireAdmin("SetPityThresholds", {
			luckyEvery = tonumber(lBox.Text) or 10,
			ultraEvery = tonumber(uBox.Text) or 25,
		})
	end).Position = UDim2.fromScale(0.58, 0)
end

-- ============================================================================
-- TAB 4: CATEGORIZED EVENTS & GLOBAL BROADCAST
-- ============================================================================
local liveEventSubLabels: { [string]: { label: TextLabel, def: any } } = {}

local function formatEventSubText(def: any, rem: number?): string
	if rem and rem > 0 then
		return string.format("ACTIVE (%s) • %s", FormatUtil.Time(rem), def.description)
	end
	return string.format("%s (%s)", def.description, FormatUtil.Time(def.durationSeconds or 120))
end

local function buildEventsTab()
	-- Global Announcement Row
	local bcCard = mkCard(46, content)
	local bcIn = mkInput(bcCard, "", "Broadcast message to banner (" .. uiState.scope .. ")...", UDim2.new(0.74, -6, 1, 0))
	mkBtn(bcCard, "📢 Broadcast", C.AccentAmber, UDim2.new(0.26, 0, 1, 0), function()
		if bcIn.Text ~= "" then
			fireAdmin("Broadcast", { message = bcIn.Text })
			bcIn.Text = ""
		end
	end).Position = UDim2.fromScale(0.74, 0)

	-- Duration & Stop All Bar
	local durCard = mkCard(nil, content)
	local dv = Instance.new("UIListLayout")
	dv.Padding = UDim.new(0, 6)
	dv.Parent = durCard

	local durRow = Instance.new("Frame")
	durRow.Size = UDim2.new(1, 0, 0, 26)
	durRow.BackgroundTransparency = 1
	durRow.Parent = durCard
	local dl = Instance.new("UIListLayout")
	dl.FillDirection = Enum.FillDirection.Horizontal
	dl.Padding = UDim.new(0, 4)
	dl.Parent = durRow

	for _, preset in ipairs({
		{ label = "Def", sec = -1 },
		{ label = "30s", sec = 30 },
		{ label = "1m", sec = 60 },
		{ label = "2m", sec = 120 },
		{ label = "5m", sec = 300 },
		{ label = "10m", sec = 600 },
		{ label = "30m", sec = 1800 },
	}) do
		local isDef = (preset.sec < 0 and uiState.useDefaultEventDuration) or (not uiState.useDefaultEventDuration and uiState.customEventSeconds == preset.sec)
		mkBtn(durRow, preset.label, if isDef then C.AccentBlue else C.TabIdle, UDim2.fromOffset(48, 26), function()
			if preset.sec < 0 then
				uiState.useDefaultEventDuration = true
			else
				uiState.useDefaultEventDuration = false
				uiState.customEventSeconds = preset.sec
			end
			renderAdminPanel(true)
		end)
	end
	local customSecBox = mkInput(durRow, tostring(uiState.customEventSeconds), "Sec", UDim2.fromOffset(58, 26))
	customSecBox.FocusLost:Connect(function()
		local n = tonumber(customSecBox.Text)
		if n and n >= 5 then
			uiState.useDefaultEventDuration = false
			uiState.customEventSeconds = math.floor(n)
		end
	end)
	mkBtn(durRow, "🛑 Stop All", C.AccentRed, UDim2.fromOffset(92, 26), function()
		fireAdmin("StopAllEvents")
	end)

	mkChipRow(durCard, {
		{ id = "All", label = "All Events", color = C.AccentBlue },
		{ id = "Economy", label = "💵 Eco & Speed", color = C.AccentGreen },
		{ id = "Luck", label = "🍀 Luck & Hatch", color = C.AccentPurple },
		{ id = "Chaos", label = "🌪️ World & Chaos", color = C.AccentRed },
	}, uiState.eventCategory, function(id)
		uiState.eventCategory = id
		renderAdminPanel(true)
	end)

	-- 2-Column Event Cards
	local gridWrap = Instance.new("Frame")
	gridWrap.Size = UDim2.new(1, 0, 0, 0)
	gridWrap.AutomaticSize = Enum.AutomaticSize.Y
	gridWrap.BackgroundTransparency = 1
	gridWrap.LayoutOrder = nextOrder()
	gridWrap.Parent = content
	local eg = Instance.new("UIGridLayout")
	eg.CellSize = UDim2.new(0.49, 0, 0, 74)
	eg.CellPadding = UDim2.new(0.02, 0, 0, 6)
	eg.Parent = gridWrap

	table.clear(liveEventSubLabels)
	for _, def in ipairs(adminState.eventsCatalog or {}) do
		local cat = EVENT_CATEGORIES[def.id] or "Chaos"
		if (uiState.eventCategory == "All" or cat == uiState.eventCategory) and matchesQuery(def.shortLabel .. " " .. def.title .. " " .. def.description .. " " .. cat) then
			local rem = adminState.activeEvents and tonumber(adminState.activeEvents[def.id])
			local card = Instance.new("Frame")
			card.BackgroundColor3 = C.CardBg
			card.Parent = gridWrap
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
			addStroke(card, 1.3, if rem and rem > 0 then Color3.fromRGB(72, 245, 148) else (def.color or C.CardStroke))
			addPad(card, 8, 6)

			local tLbl = Instance.new("TextLabel")
			tLbl.Size = UDim2.new(1, 0, 0, 18)
			tLbl.BackgroundTransparency = 1
			tLbl.Text = string.format("%s %s [%s]", def.icon or "🔥", def.shortLabel, cat)
			tLbl.TextColor3 = def.color or C.TextMain
			tLbl.Font = Enum.Font.GothamBold
			tLbl.TextSize = 12
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			tLbl.Parent = card

			local sLbl = Instance.new("TextLabel")
			sLbl.Size = UDim2.new(1, 0, 0, 16)
			sLbl.Position = UDim2.fromOffset(0, 19)
			sLbl.BackgroundTransparency = 1
			sLbl.Text = formatEventSubText(def, rem)
			sLbl.TextColor3 = if rem and rem > 0 then Color3.fromRGB(118, 255, 164) else C.TextMuted
			sLbl.Font = Enum.Font.Gotham
			sLbl.TextSize = 10
			sLbl.TextXAlignment = Enum.TextXAlignment.Left
			sLbl.TextTruncate = Enum.TextTruncate.AtEnd
			sLbl.Parent = card
			liveEventSubLabels[def.id] = { label = sLbl, def = def }

			local btnRow = Instance.new("Frame")
			btnRow.Size = UDim2.new(1, 0, 0, 24)
			btnRow.Position = UDim2.fromOffset(0, 38)
			btnRow.BackgroundTransparency = 1
			btnRow.Parent = card
			local durArg = if uiState.useDefaultEventDuration then def.durationSeconds else math.max(5, tonumber(customSecBox.Text) or uiState.customEventSeconds)
			mkBtn(btnRow, if rem and rem > 0 then "+Extend" else "▶ Trigger", C.AccentGreen, UDim2.new(0.58, -4, 1, 0), function()
				local d = if uiState.useDefaultEventDuration then def.durationSeconds else math.max(5, tonumber(customSecBox.Text) or uiState.customEventSeconds)
				fireAdmin("TriggerEvent", { eventId = def.id, durationSeconds = d, mode = if rem and rem > 0 then "extend" else "start" })
			end)
			mkBtn(btnRow, "Stop", if rem and rem > 0 then C.AccentRed else C.TabIdle, UDim2.new(0.42, 0, 1, 0), function()
				fireAdmin("StopEvent", { eventId = def.id })
			end).Position = UDim2.fromScale(0.58, 0)
		end
	end
end

-- ============================================================================
-- TAB 5: PLAYERS & MODERATION
-- ============================================================================
local function buildModTab()
	addTargetPlayerBar(content)

	mkSection("Teleport, Character & Quick Progression", content)
	local actCard = mkCard(nil, content)
	local av = Instance.new("UIListLayout")
	av.Padding = UDim.new(0, 6)
	av.Parent = actCard

	local g1 = Instance.new("Frame")
	g1.Size = UDim2.new(1, 0, 0, 0)
	g1.AutomaticSize = Enum.AutomaticSize.Y
	g1.BackgroundTransparency = 1
	g1.Parent = actCard
	local gg1 = Instance.new("UIGridLayout")
	gg1.CellSize = UDim2.new(0.242, 0, 0, 28)
	gg1.CellPadding = UDim2.new(0.01, 0, 0, 5)
	gg1.Parent = g1

	local quickActs = {
		{ t = "TP to Player", c = C.AccentBlue, a = "TeleportTo" },
		{ t = "Bring Player", c = C.AccentBlue, a = "Bring" },
		{ t = "TP to Plot", c = C.AccentTeal, a = "TeleportToPlot" },
		{ t = "Heal & Unstun", c = C.AccentGreen, a = "HealUnstun" },
		{ t = "Freeze", c = C.AccentCyan, a = "Freeze" },
		{ t = "Unfreeze", c = C.AccentTeal, a = "Unfreeze" },
		{ t = "Kill Player", c = C.AccentRed, a = "Kill" },
		{ t = "Unlock All Gear", c = C.AccentAmber, a = "UnlockAll" },
	}
	for _, qa in ipairs(quickActs) do
		mkBtn(g1, qa.t, qa.c, UDim2.fromOffset(0, 0), function()
			fireAdmin(qa.a, { targetUserId = uiState.selectedTargetUserId })
		end)
	end

	-- Zone Teleport Row
	local zRow = Instance.new("Frame")
	zRow.Size = UDim2.new(1, 0, 0, 26)
	zRow.BackgroundTransparency = 1
	zRow.Parent = actCard
	local zl = Instance.new("UIListLayout")
	zl.FillDirection = Enum.FillDirection.Horizontal
	zl.Padding = UDim.new(0, 5)
	zl.Parent = zRow
	mkBtn(zRow, "TP SafeZone", C.TabIdle, UDim2.fromOffset(92, 26), function()
		fireAdmin("TeleportToZone", { targetUserId = uiState.selectedTargetUserId, zoneId = "SafeZone" })
	end)
	for _, b in ipairs(BiomeConfig) do
		mkBtn(zRow, b.id, b.accentColor, UDim2.fromOffset(102, 26), function()
			fireAdmin("TeleportToZone", { targetUserId = uiState.selectedTargetUserId, zoneId = b.id })
		end)
	end

	-- Economy & Treadmill/Pen Level Inputs
	mkSection("Economy, Rebirth, Treadmill Lv (1-12) & Pen Capacity (8-25)", content)
	local ecoCard = mkCard(nil, content)
	local ev = Instance.new("UIListLayout")
	ev.Padding = UDim.new(0, 6)
	ev.Parent = ecoCard

	local function addPairRow(defaultVal: string, labelA: string, colA: Color3, fnA: (string) -> (), labelB: string?, colB: Color3?, fnB: ((string) -> ())?)
		local r = Instance.new("Frame")
		r.Size = UDim2.new(1, 0, 0, 28)
		r.BackgroundTransparency = 1
		r.Parent = ecoCard
		local tb = mkInput(r, defaultVal, "Amount", UDim2.new(0.42, -4, 1, 0))
		if labelB and fnB and colB then
			mkBtn(r, labelA, colA, UDim2.new(0.28, -4, 1, 0), function() fnA(tb.Text) end).Position = UDim2.fromScale(0.43, 0)
			mkBtn(r, labelB, colB, UDim2.new(0.28, 0, 1, 0), function() fnB(tb.Text) end).Position = UDim2.fromScale(0.72, 0)
		else
			mkBtn(r, labelA, colA, UDim2.new(0.57, 0, 1, 0), function() fnA(tb.Text) end).Position = UDim2.fromScale(0.43, 0)
		end
	end

	addPairRow("100M", "+ Give Cash", C.AccentGreen, function(v)
		fireAdmin("GiveCoins", { targetUserId = uiState.selectedTargetUserId, amount = v })
	end, "Set Cash", C.AccentAmber, function(v)
		fireAdmin("SetCoins", { targetUserId = uiState.selectedTargetUserId, amount = v })
	end)
	addPairRow("10K", "+ Give Speed", C.AccentBlue, function(v)
		fireAdmin("GiveSpeed", { targetUserId = uiState.selectedTargetUserId, amount = v })
	end, "Set Speed", C.AccentTeal, function(v)
		fireAdmin("SetSpeed", { targetUserId = uiState.selectedTargetUserId, amount = v })
	end)
	addPairRow("12", "Set Treadmill Lv (1-12)", C.AccentPurple, function(v)
		fireAdmin("SetTreadmillLevel", { targetUserId = uiState.selectedTargetUserId, level = tonumber(v) or 12 })
	end, "Set Pen Cap (8-25)", C.AccentPink, function(v)
		fireAdmin("SetPenCapacity", { targetUserId = uiState.selectedTargetUserId, capacity = tonumber(v) or 20 })
	end)
	addPairRow("1", "+ Give Rebirth", C.AccentPink, function(v)
		fireAdmin("GiveRebirth", { targetUserId = uiState.selectedTargetUserId, amount = tonumber(v) or 1 })
	end, "Set Rebirth", C.AccentAmber, function(v)
		fireAdmin("SetRebirth", { targetUserId = uiState.selectedTargetUserId, amount = tonumber(v) or 0 })
	end)

	-- Moderation & Owner Tools
	mkSection("Moderation & Owner Controls", content)
	local modCard = mkCard(nil, content)
	local mv = Instance.new("UIListLayout")
	mv.Padding = UDim.new(0, 6)
	mv.Parent = modCard
	local reasonBox = mkInput(modCard, "Admin moderation action", "Ban/Kick Reason", UDim2.new(1, 0, 0, 26))
	local mRow = Instance.new("Frame")
	mRow.Size = UDim2.new(1, 0, 0, 28)
	mRow.BackgroundTransparency = 1
	mRow.Parent = modCard
	local mg = Instance.new("UIGridLayout")
	mg.CellSize = UDim2.new(0.242, 0, 1, 0)
	mg.CellPadding = UDim2.new(0.01, 0, 0, 0)
	mg.Parent = mRow
	mkBtn(mRow, "Kick", C.AccentAmber, UDim2.fromOffset(0, 0), function()
		fireAdmin("Kick", { targetUserId = uiState.selectedTargetUserId, reason = reasonBox.Text })
	end)
	mkBtn(mRow, "TempBan (1h)", C.AccentRed, UDim2.fromOffset(0, 0), function()
		fireAdmin("Ban", { targetUserId = uiState.selectedTargetUserId, durationSeconds = 3600, reason = reasonBox.Text })
	end)
	mkBtn(mRow, "PermBan", Color3.fromRGB(150, 24, 34), UDim2.fromOffset(0, 0), function()
		fireAdmin("Ban", { targetUserId = uiState.selectedTargetUserId, durationSeconds = 0, reason = reasonBox.Text })
	end)
	mkBtn(mRow, "Unban ID", C.AccentGreen, UDim2.fromOffset(0, 0), function()
		fireAdmin("Unban", { targetUserId = uiState.selectedTargetUserId })
	end)

	if (tonumber(adminState.rank) or 0) >= 3 then
		local oRow = Instance.new("Frame")
		oRow.Size = UDim2.new(1, 0, 0, 28)
		oRow.BackgroundTransparency = 1
		oRow.Parent = modCard
		local og = Instance.new("UIGridLayout")
		og.CellSize = UDim2.new(0.242, 0, 1, 0)
		og.CellPadding = UDim2.new(0.01, 0, 0, 0)
		og.Parent = oRow
		mkBtn(oRow, "Grant Admin", C.AccentPink, UDim2.fromOffset(0, 0), function()
			fireAdmin("GrantTitle", { targetUserId = uiState.selectedTargetUserId, title = "Admin" })
		end)
		mkBtn(oRow, "Grant Owner", C.AccentAmber, UDim2.fromOffset(0, 0), function()
			fireAdmin("GrantTitle", { targetUserId = uiState.selectedTargetUserId, title = "Owner" })
		end)
		mkBtn(oRow, "Revoke Title", C.TabIdle, UDim2.fromOffset(0, 0), function()
			fireAdmin("RevokeTitle", { targetUserId = uiState.selectedTargetUserId })
		end)
		mkBtn(oRow, "⚠️ Wipe Data", C.AccentRed, UDim2.fromOffset(0, 0), function()
			fireAdmin("ResetPlayerData", { targetUserId = uiState.selectedTargetUserId })
		end)
	end
end

-- ============================================================================
-- TAB 6: SELF TOOLS & LIVE SERVER MULTIPLIERS
-- ============================================================================
local function buildToolsTab()
	mkSection("Personal Admin Toggles", content)
	local card = mkCard(nil, content)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.324, 0, 0, 34)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.Parent = card

	local st = adminState.selfTools or {}
	for _, tDef in ipairs({
		{ key = "godMode", label = "God Mode" },
		{ key = "instantPull", label = "Instant Pull" },
		{ key = "instantUnbox", label = "Instant Unbox" },
		{ key = "superSpeed", label = "Super Speed" },
		{ key = "invisible", label = "Invisible" },
	}) do
		local active = (st[tDef.key] == true)
		mkBtn(card, (if active then "✅ " else "⬜ ") .. tDef.label, if active then C.AccentGreen else C.TabIdle, UDim2.fromOffset(0, 0), function()
			fireAdmin("ToggleSelfTool", { tool = tDef.key })
		end)
	end

	mkSection("Live Gameplay Multipliers (" .. uiState.scope .. ")", content)
	local mCard = mkCard(nil, content)
	local mv = Instance.new("UIListLayout")
	mv.Padding = UDim.new(0, 6)
	mv.Parent = mCard
	local lt = adminState.liveTuners or {}

	for _, mDef in ipairs({
		{ key = "cashMult", label = "Cash Multiplier (x)", col = C.AccentGreen },
		{ key = "speedMult", label = "Treadmill Speed Mult (x)", col = C.AccentBlue },
		{ key = "resistanceMult", label = "Crate Resistance Mult (x)", col = C.AccentTeal },
		{ key = "poacherSpeedMult", label = "Poacher Speed Mult (x)", col = C.AccentRed },
	}) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.Parent = mCard
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.45, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = mDef.label
		lbl.TextColor3 = C.TextMain
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row
		local inBox = mkInput(row, tostring(lt[mDef.key] or 1), "1.0", UDim2.new(0.28, -4, 1, 0))
		inBox.Position = UDim2.fromScale(0.46, 0)
		mkBtn(row, "Apply", mDef.col, UDim2.new(0.25, 0, 1, 0), function()
			fireAdmin("SetLiveMultiplier", { key = mDef.key, value = tonumber(inBox.Text) or 1 })
		end).Position = UDim2.fromScale(0.75, 0)
	end

	mkBtn(mCard, "Reset Multipliers to 1.0x", C.AccentAmber, UDim2.new(1, 0, 0, 28), function()
		fireAdmin("ResetMultipliers")
	end)
end

-- ============================================================================
-- MASTER RENDERER & EVENTS
-- ============================================================================
renderAdminPanel = function(preserveScroll: boolean?)
	local savedY = content.CanvasPosition.Y
	refreshScopeVisual()
	for _, ch in ipairs(content:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	for _, tb in ipairs(tabButtons) do
		local isSel = (tb.id == uiState.activeTab)
		tb.btn.BackgroundColor3 = if isSel then C.AccentBlue else C.TabIdle
		tb.btn.TextColor3 = if isSel then Color3.new(1, 1, 1) else C.TextMuted
		tb.stroke.Color = if isSel then Color3.fromRGB(147, 197, 253) else C.CardStroke
	end

	if uiState.activeTab == "Spawner" then
		buildSpawnerTab()
	elseif uiState.activeTab == "Give" then
		buildGiveTab()
	elseif uiState.activeTab == "Rates" then
		buildRatesTab()
	elseif uiState.activeTab == "Events" then
		buildEventsTab()
	elseif uiState.activeTab == "Mod" then
		buildModTab()
	elseif uiState.activeTab == "Tools" then
		buildToolsTab()
	end

	if preserveScroll then
		task.defer(function()
			content.CanvasPosition = Vector2.new(0, savedY)
		end)
	end
end

scopeBtn.MouseButton1Click:Connect(function()
	uiState.scope = if uiState.scope == "ThisServer" then "AllServers" else "ThisServer"
	renderAdminPanel(true)
end)

searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	uiState.searchQuery = searchInput.Text
	clearSearchBtn.Visible = (#searchInput.Text > 0)
	renderAdminPanel(true)
end)

clearSearchBtn.MouseButton1Click:Connect(function()
	searchInput.Text = ""
end)

local tabs = {
	{ id = "Spawner", label = "📦 Spawner" },
	{ id = "Give", label = "🎁 Give Player" },
	{ id = "Rates", label = "🎲 Semi-RNG" },
	{ id = "Events", label = "🎉 Events" },
	{ id = "Mod", label = "👤 Players" },
	{ id = "Tools", label = "🛠️ Tools" },
}
for i, t in ipairs(tabs) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.new(0.158, 0, 1, 0)
	b.BackgroundColor3 = C.TabIdle
	b.Text = t.label
	b.TextColor3 = C.TextMuted
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
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
	title.Text = if isOwner then "👑 OWNER PANEL" else "🛡️ ADMIN PANEL"
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
		renderAdminPanel(true)
	end
end)

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
