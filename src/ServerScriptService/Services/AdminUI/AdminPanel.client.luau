--!strict
-- AdminPanel.client.luau (PROVISIONED SERVER-SIDE ONLY via ServerScriptService.Services.AdminUI)
-- Server-cloned into PlayerGui exclusively for verified Rank >= 2 Admin / Owner players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local WorkspaceService = game:GetService("Workspace")

local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local adminState: any = { rank = 0, title = "", isRoot = false, activeEvents = {}, eventsCatalog = {}, liveTuners = {}, selfTools = {}, players = {} }
local activeTab = "Mod"
local selectedTargetUserId = localPlayer.UserId
local selectedBiomeIdx = 1
local selectedRarityIdx = 5 -- Default Legendary
local selectedSpeciesIdx = #AnimalConfig.ALL
local selectedMutationIdx = 6 -- Default Rainbow
local selectedSizeRatio = 2.5

local RARITIES: { string } = GameConfig.RARITY_ORDER
local selectedRateRarityIdx = 15 -- Default Primordial for Owner rate tuning
local selectedRateMutIdx = 14 -- Default Celestial for Owner rate tuning

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

local function addStroke(inst: Instance, thickness: number, color: Color3)
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
else
	gui = Instance.new("ScreenGui")
	gui.Name = "AdminControlPanel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
frame.Size = UDim2.fromOffset(680, 480)
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
		frameScale.Scale = math.clamp(math.min((vp.X - 36) / 720, (vp.Y - 36) / 516), 0.45, 1.12)
	end
	local function bindAdminCamera()
		if vpConn then vpConn:Disconnect(); vpConn = nil end
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
title.Size = UDim2.new(1, -68, 0, 32)
title.Position = UDim2.fromOffset(14, 10)
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
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, -42, 0, 10)
closeBtn.BackgroundColor3 = C.AccentRed
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 16
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)
closeBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Tabs Row
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -28, 0, 34)
tabBar.Position = UDim2.fromOffset(14, 48)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame
local tbLayout = Instance.new("UIListLayout")
tbLayout.FillDirection = Enum.FillDirection.Horizontal
tbLayout.SortOrder = Enum.SortOrder.LayoutOrder
tbLayout.Padding = UDim.new(0, 6)
tbLayout.Parent = tabBar

-- Pinned Target Strip (Visible context on every tab)
local targetBar = Instance.new("Frame")
targetBar.Name = "PinnedTargetBar"
targetBar.Size = UDim2.new(1, -28, 0, 32)
targetBar.Position = UDim2.fromOffset(14, 88)
targetBar.BackgroundColor3 = C.PanelBg
targetBar.Parent = frame
Instance.new("UICorner", targetBar).CornerRadius = UDim.new(0, 8)
addStroke(targetBar, 1.2, C.CardStroke)

local targetLbl = Instance.new("TextLabel")
targetLbl.Size = UDim2.new(1, -118, 1, 0)
targetLbl.Position = UDim2.fromOffset(10, 0)
targetLbl.BackgroundTransparency = 1
targetLbl.TextXAlignment = Enum.TextXAlignment.Left
targetLbl.Text = "Target: @self"
targetLbl.TextColor3 = C.TextMain
targetLbl.Font = Enum.Font.GothamBold
targetLbl.TextSize = 13
targetLbl.TextTruncate = Enum.TextTruncate.AtEnd
targetLbl.Parent = targetBar

local cycleTargetBtn = Instance.new("TextButton")
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
content.Size = UDim2.new(1, -28, 1, -140)
content.Position = UDim2.fromOffset(14, 126)
content.BackgroundColor3 = C.PanelBg
content.ScrollBarThickness = 6
content.ScrollBarImageColor3 = Color3.fromRGB(92, 108, 138)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.fromScale(0, 0)
content.Parent = frame
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 10)
addStroke(content, 1.2, C.CardStroke)

local cLayout = Instance.new("UIListLayout")
cLayout.Padding = UDim.new(0, 8)
cLayout.SortOrder = Enum.SortOrder.LayoutOrder
cLayout.Parent = content
addPad(content, 10, 10)

local tabButtons: { { id: string, btn: TextButton, stroke: UIStroke } } = {}

local function sendAdmin(action: string, payload: { [string]: any }?)
	Remotes.Get("AdminCommand"):FireServer(action, payload or {})
end

local function clearContent()
	for _, ch in ipairs(content:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local function getTargetInfo(): (string, string)
	for _, p in ipairs(adminState.players or {}) do
		if p.userId == selectedTargetUserId then
			local role = if p.title ~= "" and p.title ~= nil then p.title else "Player"
			return string.format("%s (@%s)", p.displayName, p.name), role
		end
	end
	return tostring(selectedTargetUserId), "Player"
end

local function updateTargetBar()
	local nameStr, roleStr = getTargetInfo()
	local prefix = if roleStr == "Owner" then "👑 " elseif roleStr == "Admin" then "🛡️ " else "👤 "
	targetLbl.Text = string.format("Active Target:  %s%s  [%s]", prefix, nameStr, string.upper(roleStr))
	targetLbl.TextColor3 = if roleStr == "Owner" then Color3.fromRGB(255, 214, 84) elseif roleStr == "Admin" then Color3.fromRGB(255, 132, 172) else C.TextMain
end

local function addSectionHeader(text: string, color: Color3?)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.TextColor3 = color or C.TextMuted
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.Parent = content
end

local function makeChipButton(parent: Instance, label: string, bg: Color3, cb: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = bg
	b.Text = label
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	addPad(b, 8, 0)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function addActionGrid(buttons: { { text: string, color: Color3, onClick: () -> () } }, cols: number?)
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

local function addActionRow(labelText: string, subText: string?, btnText: string, col: Color3, cb: () -> ())
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

local function addInputRow(placeholder: string, btnText: string, col: Color3, cb: (string) -> ())
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

local renderAdminPanel: (resetScroll: boolean?) -> ()

local function updateTabStyles()
	local myRank = tonumber(adminState.rank) or 0
	local activeCol = if myRank >= 3 or adminState.title == "Owner" then C.AccentAmber else C.AccentPink
	for _, entry in ipairs(tabButtons) do
		local isAct = (activeTab == entry.id)
		entry.btn.BackgroundColor3 = if isAct then activeCol else C.TabIdle
		entry.btn.TextColor3 = if isAct then Color3.new(1, 1, 1) else C.TextMuted
		entry.stroke.Color = if isAct then Color3.new(1, 1, 1) else C.CardStroke
		entry.stroke.Thickness = if isAct then 1.8 else 1.0
	end
end

cycleTargetBtn.MouseButton1Click:Connect(function()
	local list = adminState.players or {}
	if #list == 0 then return end
	local idx = 1
	for i, p in ipairs(list) do
		if p.userId == selectedTargetUserId then
			idx = (i % #list) + 1
			break
		end
	end
	selectedTargetUserId = list[idx].userId
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

	local myRank = tonumber(adminState.rank) or 0

	if activeTab == "Mod" then
		addSectionHeader("SERVER PLAYERS", C.TextMuted)
		for _, p in ipairs(adminState.players or {}) do
			local isSel = (p.userId == selectedTargetUserId)
			local tag = if p.title == "Owner" then "👑 OWNER  •  " elseif p.title == "Admin" then "🛡️ ADMIN  •  " else ""
			addActionRow(
				string.format("%s%s", tag, p.displayName),
				string.format("@%s  |  ID: %d", p.name, p.userId),
				if isSel then "SELECTED" else "Select",
				if isSel then C.AccentGreen else C.AccentBlue,
				function()
					selectedTargetUserId = p.userId
					renderAdminPanel()
				end
			)
		end

		addSectionHeader("PLAYER MODERATION & MOVEMENT", C.TextMuted)
		addActionGrid({
			{ text = "Kill Player", color = C.AccentRed, onClick = function() sendAdmin("Kill", { targetUserId = selectedTargetUserId }) end },
			{ text = "TP To Player", color = C.AccentBlue, onClick = function() sendAdmin("TeleportTo", { targetUserId = selectedTargetUserId }) end },
			{ text = "Bring Player", color = C.AccentTeal, onClick = function() sendAdmin("Bring", { targetUserId = selectedTargetUserId }) end },
		}, 3)
		addActionGrid({
			{ text = "Freeze", color = Color3.fromRGB(71, 85, 105), onClick = function() sendAdmin("Freeze", { targetUserId = selectedTargetUserId }) end },
			{ text = "Unfreeze", color = C.AccentGreen, onClick = function() sendAdmin("Unfreeze", { targetUserId = selectedTargetUserId }) end },
		}, 2)

		addSectionHeader("TELEPORT TARGET TO ZONE", C.TextMuted)
		addActionGrid({
			{ text = "Safe Zone", color = C.AccentGreen, onClick = function() sendAdmin("TeleportToZone", { targetUserId = selectedTargetUserId, zoneId = "SafeZone" }) end },
			{ text = "Pine Wood", color = Color3.fromRGB(46, 125, 50), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selectedTargetUserId, zoneId = "PineWoods" }) end },
			{ text = "Swamp", color = Color3.fromRGB(101, 86, 52), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selectedTargetUserId, zoneId = "MangroveSwamp" }) end },
		}, 3)
		addActionGrid({
			{ text = "Savanna", color = Color3.fromRGB(180, 120, 32), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selectedTargetUserId, zoneId = "SavannaCamp" }) end },
			{ text = "Alpine", color = Color3.fromRGB(2, 132, 199), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selectedTargetUserId, zoneId = "AlpinePeaks" }) end },
			{ text = "Volcanic", color = Color3.fromRGB(185, 56, 36), onClick = function() sendAdmin("TeleportToZone", { targetUserId = selectedTargetUserId, zoneId = "VolcanicJungle" }) end },
		}, 3)

		addSectionHeader("KICK & BAN", C.TextMuted)
		addInputRow("Kick reason (optional)...", "Kick Player", C.AccentAmber, function(txt)
			sendAdmin("Kick", { targetUserId = selectedTargetUserId, reason = if txt ~= "" then txt else "Kicked by Admin" })
		end)
		addInputRow("Permanent ban reason...", "Perm Ban", C.AccentRed, function(txt)
			sendAdmin("Ban", { targetUserId = selectedTargetUserId, durationSeconds = 0, reason = if txt ~= "" then txt else "Banned by Admin" })
		end)
		addInputRow("Enter UserId to unban...", "Unban ID", C.AccentGreen, function(txt)
			local uid = tonumber(txt)
			if uid then sendAdmin("Unban", { targetUserId = uid }) end
		end)

		if myRank >= 3 then
			addSectionHeader("SUPERADMIN (OWNER) — TITLES & DATA", Color3.fromRGB(255, 208, 72))
			addActionGrid({
				{ text = "Give [Admin]", color = C.AccentPink, onClick = function() sendAdmin("GrantTitle", { targetUserId = selectedTargetUserId, title = "Admin" }) end },
				{ text = "Give [Owner]", color = C.AccentAmber, onClick = function() sendAdmin("GrantTitle", { targetUserId = selectedTargetUserId, title = "Owner" }) end },
				{ text = "Revoke Title", color = Color3.fromRGB(100, 116, 139), onClick = function() sendAdmin("RevokeTitle", { targetUserId = selectedTargetUserId }) end },
			}, 3)
			addInputRow("Offline Grant Admin: UserId,Username", "Grant Admin", C.AccentPink, function(txt)
				local uidStr, uname = string.match(txt, "^%s*(%d+)%s*,%s*([%w_]+)%s*$")
				if uidStr and uname then
					sendAdmin("GrantTitle", { targetUserId = tonumber(uidStr), targetUsername = uname, title = "Admin" })
				end
			end)
			addActionRow("Wipe Target Save Data", "Resets target coins, speed & inventory to new profile", "Wipe Data", C.AccentRed, function()
				sendAdmin("ResetPlayerData", { targetUserId = selectedTargetUserId })
			end)
		end

	elseif activeTab == "Economy" then
		addSectionHeader("SPEED & MONEY CONTROLS", C.TextMuted)
		addInputRow("Set exact speed (e.g. 500, 50K, 10B)...", "Set Speed", C.AccentBlue, function(txt)
			sendAdmin("SetSpeed", { targetUserId = selectedTargetUserId, amount = if txt ~= "" then txt else "500" })
		end)
		addInputRow("Add speed (+amount, e.g. 250, 50K)...", "Give Speed", C.AccentTeal, function(txt)
			sendAdmin("GiveSpeed", { targetUserId = selectedTargetUserId, amount = if txt ~= "" then txt else "500" })
		end)
		addInputRow("Give coins (+amount, e.g. 500K, 25M)...", "Give Money", C.AccentGreen, function(txt)
			sendAdmin("GiveCoins", { targetUserId = selectedTargetUserId, amount = if txt ~= "" then txt else "1M" })
		end)
		addInputRow("Set exact coins (e.g. 0, 10M, 5T)...", "Set Money", Color3.fromRGB(21, 128, 61), function(txt)
			sendAdmin("SetCoins", { targetUserId = selectedTargetUserId, amount = if txt ~= "" then txt else "0" })
		end)

		addSectionHeader("PROGRESSION & MULTIPLIERS", C.TextMuted)
		addActionGrid({
			{ text = "Set Pen Cap (20)", color = C.AccentPurple, onClick = function() sendAdmin("SetPenCapacity", { targetUserId = selectedTargetUserId, capacity = 20 }) end },
			{ text = "Unlock All Gear/Index", color = C.AccentAmber, onClick = function() sendAdmin("UnlockAll", { targetUserId = selectedTargetUserId }) end },
		}, 2)
		addInputRow("Live Cash Mult (Current: " .. tostring((adminState.liveTuners or {}).cashMult or 1) .. "x)", "Set Cash Mult", C.AccentTeal, function(txt)
			sendAdmin("SetLiveMultiplier", { key = "cashMult", value = tonumber(txt) or 1 })
		end)
		addInputRow("Live Resistance Mult (0.1 = 10x easier)", "Set Res Mult", C.AccentTeal, function(txt)
			sendAdmin("SetLiveMultiplier", { key = "resistanceMult", value = tonumber(txt) or 1 })
		end)

	elseif activeTab == "Spawn" then
		local biome = BiomeConfig[selectedBiomeIdx] or BiomeConfig[1]
		local rarity = RARITIES[selectedRarityIdx] or "Legendary"
		local spec = AnimalConfig.ALL[selectedSpeciesIdx] or AnimalConfig.ALL[1]
		local mut = GameConfig.MUTATION_ORDER[selectedMutationIdx] or "None"

		addSectionHeader("1. SPAWN ANIMAL CRATE IN WORLD", Color3.fromRGB(250, 204, 21))
		addActionRow("Biome: " .. biome.name, "Crate will spawn strictly inside this biome", "Next Biome", C.AccentTeal, function()
			selectedBiomeIdx = (selectedBiomeIdx % #BiomeConfig) + 1
			renderAdminPanel()
		end)
		addActionRow("Crate Rarity: " .. rarity, "Determines crate visuals, resistance & announce icon", "Next Rarity", C.AccentAmber, function()
			selectedRarityIdx = (selectedRarityIdx % #RARITIES) + 1
			renderAdminPanel()
		end)
		addActionGrid({
			{
				text = "Spawn in " .. biome.id,
				color = C.AccentGreen,
				onClick = function()
					sendAdmin("SpawnWorldCrate", { biomeId = biome.id, rarity = rarity, speciesId = spec.id, nearAdmin = false })
				end,
			},
			{
				text = "Spawn Near Me",
				color = C.AccentBlue,
				onClick = function()
					sendAdmin("SpawnWorldCrate", { biomeId = biome.id, rarity = rarity, speciesId = spec.id, nearAdmin = true })
				end,
			},
		}, 2)

		addSectionHeader("2. GIVE PET DIRECTLY TO TARGET PLAYER", Color3.fromRGB(192, 132, 252))
		addActionRow(string.format("Species (#%02d/%d): %s", spec.indexNumber, #AnimalConfig.ALL, spec.name), string.format("%s | %s", spec.biomeId, spec.rarity), "Next Species", C.AccentBlue, function()
			selectedSpeciesIdx = (selectedSpeciesIdx % #AnimalConfig.ALL) + 1
			renderAdminPanel()
		end)
		addActionRow("Mutation: " .. mut, "Applies mutation multiplier & visual finish", "Next Mutation", C.AccentPurple, function()
			selectedMutationIdx = (selectedMutationIdx % #GameConfig.MUTATION_ORDER) + 1
			renderAdminPanel()
		end)
		addInputRow("Size ratio (Current: " .. tostring(selectedSizeRatio) .. "x, e.g. 5.0)", "Set Size", C.AccentAmber, function(txt)
			selectedSizeRatio = math.clamp(tonumber(txt) or 2.5, 0.5, 10.0)
			renderAdminPanel()
		end)
		addActionRow(string.format("[%s] %s (%.1fx)", mut, spec.name, selectedSizeRatio), "Places directly into target's Inventory & Pen", "Give Pet", C.AccentPurple, function()
			sendAdmin("GivePet", {
				targetUserId = selectedTargetUserId,
				speciesId = spec.id,
				mutation = mut,
				sizeRatio = selectedSizeRatio,
			})
		end)

	elseif activeTab == "Rates" then
		local isOwner = (adminState.rank or 0) >= 3
		if not isOwner then
			addSectionHeader("OWNER (SUPERADMIN) ONLY", C.AccentRed)
			addActionRow("Locked", "Only Owner / Superadmin can modify spawn & mutation rates.", "Rank 3+", Color3.fromRGB(71, 85, 105), function() end)
		else
			local tuners = adminState.liveTuners or {}
			local rOverrides = adminState.rarityWeightOverrides or {}
			local mOverrides = adminState.mutationWeightOverrides or {}
			local rKey = RARITIES[selectedRateRarityIdx] or "Primordial"
			local rDefW = (GameConfig.RARITY_WEIGHTS :: any)[rKey] or 1.0
			local rCurW = if rOverrides[rKey] ~= nil then rOverrides[rKey] else rDefW
			local mKey = GameConfig.MUTATION_ORDER[selectedRateMutIdx] or "Celestial"
			local mDefW = (GameConfig.MUTATIONS[mKey] and GameConfig.MUTATIONS[mKey].weight) or 1.0
			local mCurW = if mOverrides[mKey] ~= nil then mOverrides[mKey] else mDefW
			local forcedMut = tostring(adminState.forcedWildMutation or "Random")

			addSectionHeader("GLOBAL SPAWN & MUTATION LUCK (OWNER)", Color3.fromRGB(250, 204, 21))
			addInputRow(string.format("Rarity Luck Mult (Current: %.2fx)", tonumber(tuners.rarityLuckMult) or 1), "Set Rarity Luck", C.AccentAmber, function(txt)
				sendAdmin("SetRarityLuck", { value = tonumber(txt) or 1 })
			end)
			addInputRow(string.format("Mutation Luck Mult (Current: %.2fx)", tonumber(tuners.mutationLuckMult) or 1), "Set Mut Luck", C.AccentPurple, function(txt)
				sendAdmin("SetMutationLuck", { value = tonumber(txt) or 1 })
			end)
			addActionGrid({
				{ text = "Respawn All Biomes", color = C.AccentGreen, onClick = function() sendAdmin("TriggerWaveReset") end },
				{ text = "Reset All Rates", color = C.AccentRed, onClick = function() sendAdmin("ResetSpawnRates") end },
			}, 2)

			addSectionHeader("PER-RARITY CRATE SPAWN WEIGHT", C.TextMuted)
			addActionRow(string.format("Rarity: %s (Current Weight: %.4g | Default: %.4g)", rKey, rCurW, rDefW), "Only spawns in biomes whose maxRarity allows this tier", "Next Tier", C.AccentBlue, function()
				selectedRateRarityIdx = (selectedRateRarityIdx % #RARITIES) + 1
				renderAdminPanel()
			end)
			addInputRow("New weight for " .. rKey .. " (empty or -1 to reset default)", "Apply Weight", C.AccentTeal, function(txt)
				local num = tonumber(txt)
				sendAdmin("SetRarityWeight", { rarity = rKey, weight = if num ~= nil then num else -1 })
			end)

			addSectionHeader("PER-MUTATION SPAWN WEIGHT & OVERRIDE", Color3.fromRGB(192, 132, 252))
			addActionRow(string.format("Mutation: %s (Weight: %.4g | Default: %.4g)", mKey, mCurW, mDefW), "Adjust drop rate weight for this visual mutation", "Next Mut", C.AccentPurple, function()
				selectedRateMutIdx = (selectedRateMutIdx % #GameConfig.MUTATION_ORDER) + 1
				renderAdminPanel()
			end)
			addInputRow("New weight for " .. mKey .. " (empty or -1 to reset)", "Apply Mut W", C.AccentTeal, function(txt)
				local num = tonumber(txt)
				sendAdmin("SetMutationWeight", { mutation = mKey, weight = if num ~= nil then num else -1 })
			end)
			addActionRow("Forced Hatch/Wild Mutation: " .. forcedMut, "Cycles Random -> next mutation for all new hatches", "Cycle Force", C.AccentPink, function()
				if forcedMut == "Random" then
					sendAdmin("SetForcedMutation", { mutation = GameConfig.MUTATION_ORDER[2] })
				else
					local idx = table.find(GameConfig.MUTATION_ORDER, forcedMut) or 0
					local nxt = GameConfig.MUTATION_ORDER[idx + 1] or "Random"
					sendAdmin("SetForcedMutation", { mutation = nxt })
				end
			end)
		end

	elseif activeTab == "Abuse" then
		addSectionHeader("GLOBAL ANNOUNCEMENT & LIVE EVENTS", C.TextMuted)
		addInputRow("Broadcast message to all players...", "Broadcast", C.AccentAmber, function(txt)
			if txt ~= "" then sendAdmin("Broadcast", { message = txt }) end
		end)
		for _, def in ipairs(adminState.eventsCatalog or {}) do
			local rem = (adminState.activeEvents or {})[def.id]
			addActionRow(
				def.title,
				if rem then ("Active • " .. tostring(rem) .. "s remaining") else "Inactive",
				if rem then "Extend" else "Activate",
				if rem then C.AccentGreen else C.AccentPurple,
				function() sendAdmin("TriggerEvent", { eventId = def.id }) end
			)
		end
		addActionRow("Stop All Active Events", "Clears active timers & resets multipliers to 1x", "Stop All", C.AccentRed, function()
			sendAdmin("StopAllEvents")
		end)

	elseif activeTab == "Tools" then
		addSectionHeader("PERSONAL ADMIN SELF-TOOLS", C.TextMuted)
		local st = adminState.selfTools or {}
		local function addToggle(key: string, label: string, sub: string)
			local on = st[key] == true
			addActionRow(label, sub, if on then "ENABLED" else "DISABLED", if on then C.AccentGreen else Color3.fromRGB(71, 85, 105), function()
				sendAdmin("ToggleSelfTool", { tool = key })
			end)
		end
		addToggle("godMode", "God Mode", "Poachers ignore you while pulling or carrying crates")
		addToggle("instantPull", "Instant Lasso Pull", "1-tap extracts any crate immediately")
		addToggle("instantUnbox", "Instant Crate Unbox", "Zero hatch wait time on your Sanctuary Pen")
		addToggle("superSpeed", "Admin Super Speed", "Grants ultra high movement speed")
	end

	task.defer(function()
		content.CanvasPosition = savedPos
	end)
end

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
		activeTab = t.id
		renderAdminPanel(true)
	end)
	table.insert(tabButtons, { id = t.id, btn = b, stroke = st })
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
		if focused and focused:IsDescendantOf(frame) then
			return
		end
		renderAdminPanel()
	end
end)
