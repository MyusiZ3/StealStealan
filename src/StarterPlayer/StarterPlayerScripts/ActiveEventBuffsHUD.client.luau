--!strict
-- ActiveEventBuffsHUD.client.luau
-- Renders compact Icon + Countdown Badges directly above BottomCenterHUD inventory/hotbar
-- for all active Admin Abuse events, Server Luck boosts, and live Admin multipliers.
-- Displays a floating detail tooltip on Mouse Hover or Touch/Mouse Hold.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

type BuffEntry = {
	id: string,
	icon: string,
	shortLabel: string,
	detail: string,
	color: Color3,
	endsAt: number?,
	duration: number,
}

type IconWidget = {
	buff: BuffEntry,
	button: TextButton,
	timerLabel: TextLabel,
	accentColor: Color3,
}

local activeBuffs: { BuffEntry } = {}
local iconWidgets: { [string]: IconWidget } = {}
local hoveredBuffId: string? = nil
local heldBuffId: string? = nil
local holdStartedAt = 0
local stickyTapBuffId: string? = nil
local stickyTapUntil = 0

local function formatCompactCountdown(sec: number): string
	local s = math.max(0, math.floor(sec))
	if s >= 3600 then
		local h = math.floor(s / 3600)
		local m = math.floor((s % 3600) / 60)
		return string.format("%dh%02dm", h, m)
	elseif s >= 60 then
		local m = math.floor(s / 60)
		local remS = s % 60
		return string.format("%d:%02d", m, remS)
	else
		return string.format("%ds", s)
	end
end

local function formatLongCountdown(sec: number): string
	local s = math.max(0, math.floor(sec))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local remS = s % 60
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, remS)
	end
	return string.format("%02d:%02d", m, remS)
end

-- Locate MainGameHUD.BottomCenterHUD so we share its exact bottom anchoring & ResponsiveScale
local mainHud = playerGui:WaitForChild("MainGameHUD", 25)
local bottomCenterHud = if mainHud then mainHud:WaitForChild("BottomCenterHUD", 25) else nil

local parentContainer: Instance
local fallbackGui: ScreenGui? = nil
if bottomCenterHud and bottomCenterHud:IsA("GuiObject") then
	parentContainer = bottomCenterHud
else
	local g = Instance.new("ScreenGui")
	g.Name = "ActiveEventBuffsFallbackGui"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 8
	g.Parent = playerGui
	fallbackGui = g
	parentContainer = g
end

local trayFrame = Instance.new("Frame")
trayFrame.Name = "ActiveEventBuffsBar"
trayFrame.AnchorPoint = Vector2.new(0.5, 1)
trayFrame.Size = UDim2.fromOffset(680, 50)
trayFrame.Position = UDim2.new(0.5, 0, 1, -128)
trayFrame.BackgroundTransparency = 1
trayFrame.ZIndex = 25
trayFrame.Visible = false
trayFrame.Parent = parentContainer

local iconRow = Instance.new("Frame")
iconRow.Name = "IconRow"
iconRow.Size = UDim2.fromScale(1, 1)
iconRow.BackgroundTransparency = 1
iconRow.ZIndex = 25
iconRow.Parent = trayFrame

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Padding = UDim.new(0, 10)
rowLayout.Parent = iconRow

-- Floating Tooltip Pill (only appears on hover or touch/click hold)
local tooltip = Instance.new("Frame")
tooltip.Name = "BuffHoverTooltip"
tooltip.AnchorPoint = Vector2.new(0.5, 1)
tooltip.AutomaticSize = Enum.AutomaticSize.X
tooltip.Size = UDim2.fromOffset(0, 44)
tooltip.Position = UDim2.new(0.5, 0, 0, -8)
tooltip.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
tooltip.BackgroundTransparency = 0.04
tooltip.ZIndex = 60
tooltip.Visible = false
tooltip.Active = false
tooltip.Interactable = false
tooltip.Parent = trayFrame

local ttCorner = Instance.new("UICorner")
ttCorner.CornerRadius = UDim.new(0, 9)
ttCorner.Parent = tooltip

local ttStroke = Instance.new("UIStroke")
ttStroke.Thickness = 2
ttStroke.Color = Color3.fromRGB(255, 214, 72)
ttStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ttStroke.Parent = tooltip

local ttPad = Instance.new("UIPadding")
ttPad.PaddingLeft = UDim.new(0, 12)
ttPad.PaddingRight = UDim.new(0, 12)
ttPad.PaddingTop = UDim.new(0, 5)
ttPad.PaddingBottom = UDim.new(0, 5)
ttPad.Parent = tooltip

local ttLayout = Instance.new("UIListLayout")
ttLayout.FillDirection = Enum.FillDirection.Vertical
ttLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ttLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ttLayout.SortOrder = Enum.SortOrder.LayoutOrder
ttLayout.Padding = UDim.new(0, 1)
ttLayout.Parent = tooltip

local ttTitle = Instance.new("TextLabel")
ttTitle.Name = "TitleLabel"
ttTitle.LayoutOrder = 1
ttTitle.AutomaticSize = Enum.AutomaticSize.X
ttTitle.Size = UDim2.fromOffset(0, 18)
ttTitle.BackgroundTransparency = 1
ttTitle.Font = Enum.Font.FredokaOne
ttTitle.TextSize = 15
ttTitle.TextColor3 = Color3.fromRGB(255, 224, 96)
ttTitle.Text = ""
ttTitle.ZIndex = 61
ttTitle.Parent = tooltip

local ttTitleStroke = Instance.new("UIStroke")
ttTitleStroke.Thickness = 1.6
ttTitleStroke.Color = Color3.fromRGB(10, 12, 16)
ttTitleStroke.Parent = ttTitle

local ttDetail = Instance.new("TextLabel")
ttDetail.Name = "DetailLabel"
ttDetail.LayoutOrder = 2
ttDetail.AutomaticSize = Enum.AutomaticSize.X
ttDetail.Size = UDim2.fromOffset(0, 15)
ttDetail.BackgroundTransparency = 1
ttDetail.Font = Enum.Font.GothamBold
ttDetail.TextSize = 12
ttDetail.TextColor3 = Color3.fromRGB(210, 220, 238)
ttDetail.Text = ""
ttDetail.ZIndex = 61
ttDetail.Parent = tooltip

local luckyWidget = if bottomCenterHud then bottomCenterHud:FindFirstChild("LuckyCagesWidget") else nil
local mountActionBtn = if bottomCenterHud then bottomCenterHud:FindFirstChild("MountActionButton") else nil
local dropCrateBtn = if bottomCenterHud then bottomCenterHud:FindFirstChild("DropCrateButton") else nil

local function updateTrayPosition()
	if fallbackGui then
		trayFrame.Position = UDim2.new(0.5, 0, 1, -86)
		return
	end
	local luckyVis = luckyWidget ~= nil and luckyWidget:IsA("GuiObject") and luckyWidget.Visible
	local mountVis = mountActionBtn ~= nil and mountActionBtn:IsA("GuiObject") and mountActionBtn.Visible
	local dropVis = dropCrateBtn ~= nil and dropCrateBtn:IsA("GuiObject") and dropCrateBtn.Visible
	local topActionVis = mountVis or dropVis

	if luckyVis and topActionVis then
		trayFrame.Position = UDim2.new(0.5, 0, 1, -184)
	elseif luckyVis then
		trayFrame.Position = UDim2.new(0.5, 0, 1, -130)
	else
		trayFrame.Position = UDim2.new(0.5, 0, 1, -74)
	end
end

for _, watchObj in ipairs({ luckyWidget, mountActionBtn, dropCrateBtn }) do
	if watchObj and watchObj:IsA("GuiObject") then
		watchObj:GetPropertyChangedSignal("Visible"):Connect(updateTrayPosition)
	end
end
updateTrayPosition()

local function getActiveTooltipBuffId(): string?
	if heldBuffId and iconWidgets[heldBuffId] then
		return heldBuffId
	end
	if hoveredBuffId and iconWidgets[hoveredBuffId] then
		return hoveredBuffId
	end
	if stickyTapBuffId and os.clock() < stickyTapUntil and iconWidgets[stickyTapBuffId] then
		return stickyTapBuffId
	end
	return nil
end

local function refreshTooltip()
	local targetId = getActiveTooltipBuffId()
	local widget = if targetId then iconWidgets[targetId] else nil
	if not widget or not trayFrame.Visible then
		tooltip.Visible = false
		return
	end

	local buff = widget.buff
	local srvNow = Workspace:GetServerTimeNow()
	local remText = if buff.endsAt
		then (" • " .. formatLongCountdown(math.max(0, buff.endsAt - srvNow)))
		else " • LIVE"

	ttStroke.Color = buff.color
	ttTitle.TextColor3 = buff.color:Lerp(Color3.new(1, 1, 1), 0.35)
	ttTitle.Text = string.format("%s %s%s", buff.icon, buff.shortLabel, remText)
	ttDetail.Text = buff.detail

	-- Center tooltip horizontally above the target icon button using normalized scaleX (safe across any UIScale!)
	local barWidth = math.max(1, trayFrame.AbsoluteSize.X)
	local iconAbsPos = widget.button.AbsolutePosition
	local iconAbsSize = widget.button.AbsoluteSize
	local barAbsPos = trayFrame.AbsolutePosition
	local centerScaleX = if iconAbsSize.X > 0
		then math.clamp((iconAbsPos.X + iconAbsSize.X * 0.5 - barAbsPos.X) / barWidth, 0.14, 0.86)
		else 0.5
	tooltip.Position = UDim2.new(centerScaleX, 0, 0, -8)
	tooltip.Visible = true
end

local function applyBadgeStyling(btn: TextButton, buff: BuffEntry)
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = buff.color
	end
	local grad = btn:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(
			buff.color:Lerp(Color3.fromRGB(28, 34, 52), 0.58),
			buff.color:Lerp(Color3.fromRGB(12, 15, 24), 0.82)
		)
	end
	local glyph = btn:FindFirstChild("IconGlyph")
	if glyph and glyph:IsA("TextLabel") then
		glyph.Text = buff.icon
	end
	local pill = btn:FindFirstChild("TimerPill")
	local pStroke = if pill then pill:FindFirstChildOfClass("UIStroke") else nil
	if pStroke then
		pStroke.Color = buff.color
	end
end

local function createIconBadge(buff: BuffEntry, orderIdx: number): IconWidget
	local btn = Instance.new("TextButton")
	btn.Name = "BuffIcon_" .. buff.id
	btn.LayoutOrder = orderIdx
	btn.Size = UDim2.fromOffset(44, 44)
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.ZIndex = 26
	btn.Parent = iconRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.2
	stroke.Color = buff.color
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(
		buff.color:Lerp(Color3.fromRGB(28, 34, 52), 0.58),
		buff.color:Lerp(Color3.fromRGB(12, 15, 24), 0.82)
	)
	grad.Parent = btn

	local glyph = Instance.new("TextLabel")
	glyph.Name = "IconGlyph"
	glyph.Size = UDim2.fromScale(1, 0.72)
	glyph.Position = UDim2.fromScale(0, 0.03)
	glyph.BackgroundTransparency = 1
	glyph.Text = buff.icon
	glyph.TextScaled = true
	glyph.Font = Enum.Font.FredokaOne
	glyph.TextColor3 = Color3.new(1, 1, 1)
	glyph.Active = false
	glyph.Interactable = false
	glyph.ZIndex = 27
	glyph.Parent = btn

	local timerPill = Instance.new("Frame")
	timerPill.Name = "TimerPill"
	timerPill.AnchorPoint = Vector2.new(0.5, 1)
	timerPill.Size = UDim2.fromOffset(48, 16)
	timerPill.Position = UDim2.new(0.5, 0, 1, 5)
	timerPill.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
	timerPill.Active = false
	timerPill.Interactable = false
	timerPill.ZIndex = 28
	timerPill.Parent = btn

	local tpCorner = Instance.new("UICorner")
	tpCorner.CornerRadius = UDim.new(0, 6)
	tpCorner.Parent = timerPill

	local tpStroke = Instance.new("UIStroke")
	tpStroke.Thickness = 1.4
	tpStroke.Color = buff.color
	tpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tpStroke.Parent = timerPill

	local timerLbl = Instance.new("TextLabel")
	timerLbl.Name = "TimerLabel"
	timerLbl.Size = UDim2.fromScale(1, 1)
	timerLbl.BackgroundTransparency = 1
	timerLbl.Font = Enum.Font.FredokaOne
	timerLbl.TextScaled = true
	timerLbl.TextColor3 = Color3.new(1, 1, 1)
	timerLbl.Text = "--"
	timerLbl.Active = false
	timerLbl.Interactable = false
	timerLbl.ZIndex = 29
	timerLbl.Parent = timerPill

	local tlStroke = Instance.new("UIStroke")
	tlStroke.Thickness = 1.5
	tlStroke.Color = Color3.fromRGB(8, 10, 14)
	tlStroke.Parent = timerLbl

	local id = buff.id
	btn.MouseEnter:Connect(function()
		hoveredBuffId = id
		refreshTooltip()
	end)

	btn.MouseLeave:Connect(function()
		if hoveredBuffId == id then
			hoveredBuffId = nil
		end
		refreshTooltip()
	end)

	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
			heldBuffId = id
			holdStartedAt = os.clock()
			refreshTooltip()
		end
	end)

	btn.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
			if heldBuffId == id then
				local holdDur = os.clock() - holdStartedAt
				heldBuffId = nil
				if holdDur < 0.28 and hoveredBuffId ~= id then
					stickyTapBuffId = id
					stickyTapUntil = os.clock() + 2.4
				end
				refreshTooltip()
			end
		end
	end)

	return {
		buff = buff,
		button = btn,
		timerLabel = timerLbl,
		accentColor = buff.color,
	}
end

local function updateCountdowns()
	local srvNow = Workspace:GetServerTimeNow()
	local visibleCount = 0

	for _, w in pairs(iconWidgets) do
		local endsAt = w.buff.endsAt
		if endsAt == nil then
			w.button.Visible = true
			w.timerLabel.Text = "LIVE"
			w.timerLabel.TextColor3 = Color3.fromRGB(110, 245, 196)
			visibleCount += 1
		else
			local rem = endsAt - srvNow
			if rem > 0.2 then
				w.button.Visible = true
				w.timerLabel.Text = formatCompactCountdown(rem)
				w.timerLabel.TextColor3 = if rem <= 10 then Color3.fromRGB(255, 118, 118) else Color3.new(1, 1, 1)
				visibleCount += 1
			else
				w.button.Visible = false
			end
		end
	end

	trayFrame.Visible = visibleCount > 0
	updateTrayPosition()
	if tooltip.Visible or getActiveTooltipBuffId() ~= nil then
		refreshTooltip()
	end
end

local function rebuildBuffIcons(rawBuffs: { any })
	table.clear(activeBuffs)
	local wantedIds: { [string]: boolean } = {}

	for idx, raw in ipairs(rawBuffs) do
		if type(raw) == "table" and type(raw.id) == "string" then
			local colArr = raw.color
			local col = if type(colArr) == "table" and #colArr >= 3
				then Color3.fromRGB(tonumber(colArr[1]) or 255, tonumber(colArr[2]) or 214, tonumber(colArr[3]) or 72)
				else Color3.fromRGB(255, 214, 72)
			local entry: BuffEntry = {
				id = raw.id,
				icon = tostring(raw.icon or "🔥"),
				shortLabel = tostring(raw.shortLabel or raw.id),
				detail = tostring(raw.detail or ""),
				color = col,
				endsAt = if type(raw.endsAt) == "number" then raw.endsAt else nil,
				duration = tonumber(raw.duration) or 0,
			}
			table.insert(activeBuffs, entry)
			wantedIds[entry.id] = true

			local existing = iconWidgets[entry.id]
			if existing and existing.button.Parent then
				existing.buff = entry
				existing.accentColor = entry.color
				existing.button.LayoutOrder = idx
				applyBadgeStyling(existing.button, entry)
			else
				if existing and existing.button then
					existing.button:Destroy()
				end
				iconWidgets[entry.id] = createIconBadge(entry, idx)
			end
		end
	end

	for id, widget in pairs(iconWidgets) do
		if not wantedIds[id] then
			if widget.button then
				widget.button:Destroy()
			end
			iconWidgets[id] = nil
		end
	end

	if hoveredBuffId and not iconWidgets[hoveredBuffId] then
		hoveredBuffId = nil
	end
	if heldBuffId and not iconWidgets[heldBuffId] then
		heldBuffId = nil
	end
	if stickyTapBuffId and not iconWidgets[stickyTapBuffId] then
		stickyTapBuffId = nil
	end

	updateCountdowns()
end

local function findBuffAtScreenPos(guiPos: Vector2): string?
	if not trayFrame.Visible then
		return nil
	end
	for id, w in pairs(iconWidgets) do
		if w.button.Visible and w.button.Parent then
			local pos = w.button.AbsolutePosition
			local sz = w.button.AbsoluteSize
			if sz.X > 0 and sz.Y > 0 then
				if guiPos.X >= pos.X and guiPos.X <= pos.X + sz.X and guiPos.Y >= pos.Y and guiPos.Y <= pos.Y + sz.Y + 6 then
					return id
				end
			end
		end
	end
	return nil
end

-- Release hold tooltip safely if pointer lifts outside button bounds
UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
		if heldBuffId ~= nil then
			local holdDur = os.clock() - holdStartedAt
			local prev = heldBuffId
			heldBuffId = nil
			if holdDur < 0.28 and hoveredBuffId ~= prev then
				stickyTapBuffId = prev
				stickyTapUntil = os.clock() + 2.4
			end
			refreshTooltip()
		end
	end
end)

-- Pointer / touch-drag hit-test fallback (covers bottom TimerPill & non-focused viewport hover)
UserInputService.InputChanged:Connect(function(inp)
	if not trayFrame.Visible then
		return
	end
	if inp.UserInputType == Enum.UserInputType.MouseMovement then
		local topLeftInset = GuiService:GetGuiInset()
		local guiPos = UserInputService:GetMouseLocation() - topLeftInset
		local hitId = findBuffAtScreenPos(guiPos)
		if hitId ~= hoveredBuffId then
			hoveredBuffId = hitId
			refreshTooltip()
		end
	elseif inp.UserInputType == Enum.UserInputType.Touch and heldBuffId ~= nil then
		local guiPos = Vector2.new(inp.Position.X, inp.Position.Y)
		local hitId = findBuffAtScreenPos(guiPos)
		if hitId and hitId ~= heldBuffId then
			heldBuffId = hitId
			refreshTooltip()
		end
	end
end)

Remotes.Get("ActiveEventsSync").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.buffs) ~= "table" then
		return
	end
	rebuildBuffIcons(payload.buffs)
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		if #activeBuffs > 0 then
			updateCountdowns()
		end
	end
end)
