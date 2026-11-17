--!strict
-- AdminPanel.client.luau
-- 5-Tab Server-Verified Admin Control Panel (Moderation, Economy/Live Tuners, Spawner, Admin Abuse Events, Self-Tools)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AdminConfig = require(ReplicatedStorage.Config.AdminConfig)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local adminState: any = { rank = 0, activeEvents = {}, liveTuners = {}, selfTools = {}, players = {} }
local activeTab = "Abuse"
local selectedTargetUserId = localPlayer.UserId
local selectedSpeciesIdx = #AnimalConfig.ALL -- Default Mythic White Tiger
local selectedMutationIdx = 6 -- Default Rainbow
local selectedSizeRatio = 2.8

local gui = Instance.new("ScreenGui")
gui.Name = "AdminControlPanel"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local WorkspaceService = game:GetService("Workspace")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "AdminToggleButton"
toggleBtn.AnchorPoint = Vector2.new(1, 0)
toggleBtn.Size = UDim2.fromOffset(108, 32)
toggleBtn.Position = UDim2.new(1, -12, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(196, 48, 86)
toggleBtn.Text = "ADMIN (F2)"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.FredokaOne
toggleBtn.TextScaled = true
toggleBtn.Visible = false
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
local toggleScale = Instance.new("UIScale")
toggleScale.Name = "ResponsiveScale"
toggleScale.Parent = toggleBtn

local frame = Instance.new("Frame")
frame.Name = "AdminModalFrame"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromOffset(640, 440)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
frame.Visible = false
frame.Parent = gui
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
		toggleScale.Scale = math.clamp(math.min(vp.X / 1366, vp.Y / 768), 0.42, 1.15)
		frameScale.Scale = math.clamp(math.min((vp.X - 36) / 720, (vp.Y - 36) / 480), 0.42, 1.15)
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
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
local fStroke = Instance.new("UIStroke")
fStroke.Color = Color3.fromRGB(224, 62, 108)
fStroke.Thickness = 2
fStroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 34)
title.Position = UDim2.fromOffset(12, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "RANGER ADMIN PANEL & LIVE EVENTS"
title.TextColor3 = Color3.fromRGB(255, 118, 152)
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.Parent = frame

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 34)
tabBar.Position = UDim2.fromOffset(12, 44)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame
local tbLayout = Instance.new("UIListLayout")
tbLayout.FillDirection = Enum.FillDirection.Horizontal
tbLayout.Padding = UDim.new(0, 6)
tbLayout.Parent = tabBar

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -24, 1, -96)
content.Position = UDim2.fromOffset(12, 84)
content.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
content.ScrollBarThickness = 8
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.fromScale(0, 0)
content.Parent = frame
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 10)
local cLayout = Instance.new("UIListLayout")
cLayout.Padding = UDim.new(0, 8)
cLayout.Parent = content
local cPad = Instance.new("UIPadding")
cPad.PaddingTop = UDim.new(0, 8)
cPad.PaddingLeft = UDim.new(0, 8)
cPad.PaddingRight = UDim.new(0, 8)
cPad.PaddingBottom = UDim.new(0, 8)
cPad.Parent = content

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

local function addActionRow(labelText: string, btnText: string, col: Color3, cb: () -> ())
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -8, 0, 46)
	r.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
	r.Parent = content
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(0.68, -10, 1, -8)
	l.Position = UDim2.fromOffset(10, 4)
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = labelText
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Parent = r

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.28, -8, 0, 34)
	b.Position = UDim2.new(0.71, 0, 0, 6)
	b.BackgroundColor3 = col
	b.Text = btnText
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Parent = r
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.MouseButton1Click:Connect(cb)
end

local function addInputRow(placeholder: string, btnText: string, col: Color3, cb: (string) -> ())
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -8, 0, 46)
	r.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
	r.Parent = content
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.66, -10, 0, 34)
	box.Position = UDim2.fromOffset(10, 6)
	box.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
	box.PlaceholderText = placeholder
	box.Text = ""
	box.TextColor3 = Color3.new(1, 1, 1)
	box.Font = Enum.Font.GothamBold
	box.TextScaled = true
	box.Parent = r
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.29, -8, 0, 34)
	b.Position = UDim2.new(0.70, 0, 0, 6)
	b.BackgroundColor3 = col
	b.Text = btnText
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Parent = r
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.MouseButton1Click:Connect(function()
		cb(box.Text)
	end)
end

local function renderAdminPanel()
	clearContent()
	if activeTab == "Abuse" then
		addInputRow("Broadcast Global Banner Message...", "BROADCAST", Color3.fromRGB(244, 178, 42), function(txt)
			if txt ~= "" then sendAdmin("Broadcast", { message = txt }) end
		end)
		for id, def in pairs(AdminConfig.ADMIN_ABUSE_EVENTS) do
			local rem = adminState.activeEvents[id]
			addActionRow(
				def.title .. (if rem then (" [" .. rem .. "s LEFT]") else ""),
				if rem then "EXTEND" else "ACTIVATE",
				def.color,
				function() sendAdmin("TriggerEvent", { eventId = id }) end
			)
		end
		addActionRow("Stop All Active Events & Reset Multipliers", "STOP ALL", Color3.fromRGB(196, 54, 68), function()
			sendAdmin("StopAllEvents")
		end)

	elseif activeTab == "Mod" then
		for _, p in ipairs(adminState.players or {}) do
			local isSel = (p.userId == selectedTargetUserId)
			addActionRow(
				string.format("%s (@%s | %d)", p.displayName, p.name, p.userId),
				if isSel then "TARGETED" else "SELECT",
				if isSel then Color3.fromRGB(84, 212, 128) else Color3.fromRGB(58, 92, 148),
				function()
					selectedTargetUserId = p.userId
					renderAdminPanel()
				end
			)
		end
		addActionRow("Teleport To Selected Player", "TP TO", Color3.fromRGB(58, 168, 232), function()
			sendAdmin("TeleportTo", { targetUserId = selectedTargetUserId })
		end)
		addActionRow("Bring Selected Player", "BRING", Color3.fromRGB(58, 168, 232), function()
			sendAdmin("Bring", { targetUserId = selectedTargetUserId })
		end)
		addActionRow("Freeze / Unfreeze Target", "FREEZE", Color3.fromRGB(118, 168, 238), function()
			sendAdmin("Freeze", { targetUserId = selectedTargetUserId })
		end)
		addActionRow("Unfreeze Target", "UNFREEZE", Color3.fromRGB(84, 212, 128), function()
			sendAdmin("Unfreeze", { targetUserId = selectedTargetUserId })
		end)
		addInputRow("Kick Reason (Optional)...", "KICK", Color3.fromRGB(238, 132, 42), function(txt)
			sendAdmin("Kick", { targetUserId = selectedTargetUserId, reason = if txt ~= "" then txt else "Kicked by Admin" })
		end)
		addInputRow("Ban Reason -> Permanent Ban...", "PERM BAN", Color3.fromRGB(212, 48, 64), function(txt)
			sendAdmin("Ban", { targetUserId = selectedTargetUserId, durationSeconds = 0, reason = if txt ~= "" then txt else "Banned by Admin" })
		end)
		addInputRow("UserId to Unban...", "UNBAN ID", Color3.fromRGB(84, 212, 128), function(txt)
			local uid = tonumber(txt)
			if uid then sendAdmin("Unban", { targetUserId = uid }) end
		end)

	elseif activeTab == "Economy" then
		addInputRow("Give Coins (e.g. 500K, 25M, 10Qa)...", "GIVE COINS", Color3.fromRGB(64, 198, 112), function(txt)
			sendAdmin("GiveCoins", { targetUserId = selectedTargetUserId, amount = if txt ~= "" then txt else "1M" })
		end)
		addInputRow("Give Speed (e.g. 250, 50K)...", "GIVE SPEED", Color3.fromRGB(58, 168, 238), function(txt)
			sendAdmin("GiveSpeed", { targetUserId = selectedTargetUserId, amount = if txt ~= "" then txt else "500" })
		end)
		addActionRow("Set Pen Capacity = 20 (Full Free Upgrade)", "SET 20", Color3.fromRGB(152, 86, 238), function()
			sendAdmin("SetPenCapacity", { targetUserId = selectedTargetUserId, capacity = 20 })
		end)
		addActionRow("Unlock ALL 10 Lassos, 10 Trails, 6 Vehicles & 63 Index", "UNLOCK ALL", Color3.fromRGB(244, 178, 42), function()
			sendAdmin("UnlockAll", { targetUserId = selectedTargetUserId })
		end)
		addInputRow("Live Cash Multiplier (Current: " .. tostring(adminState.liveTuners.cashMult or 1) .. "x)", "SET CASH MULT", Color3.fromRGB(0, 198, 168), function(txt)
			sendAdmin("SetLiveMultiplier", { key = "cashMult", value = tonumber(txt) or 1 })
		end)
		addInputRow("Live Crate Resistance Mult (e.g. 0.1 = 10x easier)", "SET RES MULT", Color3.fromRGB(0, 198, 168), function(txt)
			sendAdmin("SetLiveMultiplier", { key = "resistanceMult", value = tonumber(txt) or 1 })
		end)

	elseif activeTab == "Spawn" then
		local spec = AnimalConfig.ALL[selectedSpeciesIdx] or AnimalConfig.ALL[1]
		local mut = GameConfig.MUTATION_ORDER[selectedMutationIdx] or "None"
		addActionRow(string.format("Species (#%02d/%d): %s [%s]", spec.indexNumber, #AnimalConfig.ALL, spec.name, spec.rarity), "NEXT SPECIES", Color3.fromRGB(68, 152, 238), function()
			selectedSpeciesIdx = (selectedSpeciesIdx % #AnimalConfig.ALL) + 1
			renderAdminPanel()
		end)
		addActionRow("Mutation: " .. mut, "NEXT MUT", Color3.fromRGB(178, 86, 255), function()
			selectedMutationIdx = (selectedMutationIdx % #GameConfig.MUTATION_ORDER) + 1
			renderAdminPanel()
		end)
		addInputRow("Custom Size Ratio (Current: " .. tostring(selectedSizeRatio) .. "x, e.g. 5.0)", "SET SIZE", Color3.fromRGB(238, 158, 48), function(txt)
			selectedSizeRatio = math.clamp(tonumber(txt) or 2.8, 0.5, 10.0)
			renderAdminPanel()
		end)
		addActionRow(string.format("SPAWN [%s] %s (%.1fx) into Target Pen!", mut, spec.name, selectedSizeRatio), "SPAWN NOW", Color3.fromRGB(84, 212, 128), function()
			sendAdmin("SpawnAnimal", {
				targetUserId = selectedTargetUserId,
				speciesId = spec.id,
				mutation = mut,
				sizeRatio = selectedSizeRatio,
			})
		end)

	elseif activeTab == "Tools" then
		local st = adminState.selfTools or {}
		local function addToggle(key: string, label: string)
			local on = st[key] == true
			addActionRow(label, if on then "ON" else "OFF", if on then Color3.fromRGB(84, 212, 128) else Color3.fromRGB(148, 62, 74), function()
				sendAdmin("ToggleSelfTool", { tool = key })
			end)
		end
		addToggle("godMode", "God Mode (Poachers Ignore Admin)")
		addToggle("instantPull", "Instant Lasso Pull (1-Tap Crate Extract)")
		addToggle("instantUnbox", "Instant Crate Unbox (0s Timer)")
		addToggle("superSpeed", "Admin Super Speed (140+ WalkSpeed)")
	end
end

local tabs = {
	{ id = "Abuse", label = "Admin Abuse" },
	{ id = "Mod", label = "Moderation" },
	{ id = "Economy", label = "Economy/Values" },
	{ id = "Spawn", label = "Spawner" },
	{ id = "Tools", label = "Self Tools" },
}
for _, t in ipairs(tabs) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.19, 0, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(48, 52, 74)
	b.Text = t.label
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Parent = tabBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(function()
		activeTab = t.id
		renderAdminPanel()
	end)
end

toggleBtn.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
	if frame.Visible then
		renderAdminPanel()
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.F2 and (adminState.rank or 0) >= 1 then
		frame.Visible = not frame.Visible
		if frame.Visible then
			renderAdminPanel()
		end
	end
end)

Remotes.Get("AdminStateSync").OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	adminState = state
	toggleBtn.Visible = (state.rank or 0) >= 1
	if frame.Visible then
		renderAdminPanel()
	end
end)
