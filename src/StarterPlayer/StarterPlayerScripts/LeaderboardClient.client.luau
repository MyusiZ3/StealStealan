--!strict
-- LeaderboardClient.client.luau
-- Renders up to 100 entries on each of the 3 3D Hub Leaderboards (Top Rebirths, Top Speed, Top Playtime)
-- with avatar thumbnails, rank badges, formatted values, and 5-minute refresh countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local currentPayload: any = nil
local nextRefreshAt = os.time() + 300

local function formatPlaytime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days = math.floor(s / 86400)
	local hours = math.floor((s % 86400) / 3600)
	local mins = math.floor((s % 3600) / 60)
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, mins)
	else
		return string.format("%dm %ds", mins, s % 60)
	end
end

local function makeStroke(inst: Instance, thickness: number, color: Color3?)
	local st = Instance.new("UIStroke")
	st.Thickness = thickness
	st.Color = color or Color3.fromRGB(12, 14, 18)
	st.Parent = inst
end

local function populateBoard(boardName: string, entries: { any }, iconStr: string, accentColor: Color3, formatFn: (number) -> string)
	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local wall = if hub then hub:FindFirstChild("LeaderboardWall") else nil
	local boardModel = if wall then wall:FindFirstChild(boardName) else nil
	local screenPart = if boardModel then boardModel:FindFirstChild("DisplaySurface") else nil
	local gui = if screenPart then screenPart:FindFirstChild("BoardGui") else nil
	local scroll = if gui then gui:FindFirstChild("ScrollList", true) else nil
	if not scroll or not scroll:IsA("ScrollingFrame") then
		return
	end

	for _, ch in ipairs(scroll:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end

	local count = math.min(100, #entries)
	for i = 1, count do
		local entry = entries[i]
		local row = Instance.new("Frame")
		row.Name = "Row_" .. tostring(i)
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -6, 0, 56)
		row.BackgroundColor3 = if i % 2 == 1 then Color3.fromRGB(36, 42, 54) else Color3.fromRGB(46, 54, 68)
		row.BackgroundTransparency = 0.12
		row.Parent = scroll

		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row
		makeStroke(row, if i <= 3 then 2.2 else 1.2, if i == 1 then Color3.fromRGB(255, 214, 54) elseif i == 2 then Color3.fromRGB(210, 224, 240) elseif i == 3 then Color3.fromRGB(224, 138, 72) else accentColor)

		-- Player Avatar Headshot
		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.fromOffset(46, 46)
		avatar.Position = UDim2.fromOffset(6, 5)
		avatar.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
		avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", tonumber(entry.userId) or 1)
		avatar.Parent = row
		local ac = Instance.new("UICorner")
		ac.CornerRadius = UDim.new(0, 6)
		ac.Parent = avatar
		makeStroke(avatar, 1.5)

		-- Rank Badge (#1, #2, #3...)
		local rankLbl = Instance.new("TextLabel")
		rankLbl.Size = UDim2.fromOffset(44, 24)
		rankLbl.Position = UDim2.fromOffset(48, 28)
		rankLbl.BackgroundTransparency = 1
		rankLbl.Text = "#" .. tostring(i)
		rankLbl.TextColor3 = if i == 1 then Color3.fromRGB(255, 224, 62) elseif i == 2 then Color3.fromRGB(222, 232, 248) elseif i == 3 then Color3.fromRGB(238, 152, 82) else Color3.new(1, 1, 1)
		rankLbl.Font = Enum.Font.FredokaOne
		rankLbl.TextScaled = true
		rankLbl.Parent = row
		makeStroke(rankLbl, 2)

		-- Value (Top Right)
		local valLbl = Instance.new("TextLabel")
		valLbl.Size = UDim2.new(1, -102, 0, 26)
		valLbl.Position = UDim2.fromOffset(96, 3)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = iconStr .. " " .. formatFn(tonumber(entry.value) or 0)
		valLbl.TextColor3 = accentColor
		valLbl.Font = Enum.Font.FredokaOne
		valLbl.TextScaled = true
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Parent = row
		makeStroke(valLbl, 2)

		-- Username (Bottom Right)
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -102, 0, 22)
		nameLbl.Position = UDim2.fromOffset(96, 30)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = "@" .. tostring(entry.username or "Ranger")
		nameLbl.TextColor3 = if i <= 3 then Color3.fromRGB(255, 226, 98) else Color3.new(1, 1, 1)
		nameLbl.Font = Enum.Font.FredokaOne
		nameLbl.TextScaled = true
		nameLbl.TextXAlignment = Enum.TextXAlignment.Right
		nameLbl.Parent = row
		makeStroke(nameLbl, 2)
	end
end

local function renderAllBoards()
	if type(currentPayload) ~= "table" then
		return
	end
	populateBoard("TopRebirthBoard", currentPayload.rebirths or {}, "♻️", Color3.fromRGB(118, 255, 118), function(v)
		local n = math.floor(v)
		return FormatUtil.Number(n) .. (if n == 1 then " Rebirth" else " Rebirths")
	end)
	populateBoard("TopSpeedBoard", currentPayload.speed or {}, "👟", Color3.fromRGB(96, 214, 255), function(v)
		return FormatUtil.Number(v)
	end)
	populateBoard("TopPlaytimeBoard", currentPayload.playtime or {}, "🕒", Color3.fromRGB(255, 132, 168), function(v)
		return formatPlaytime(v)
	end)
end

Remotes.Get("LeaderboardSync").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	currentPayload = payload
	if type(payload.nextRefreshAt) == "number" then
		nextRefreshAt = payload.nextRefreshAt
	end
	renderAllBoards()
end)

-- Update "Updates in: MM:SS" footer every second
local accum = 0
RunService.Heartbeat:Connect(function(dt: number)
	accum += dt
	if accum < 1.0 then return end
	accum = 0

	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local wall = if hub then hub:FindFirstChild("LeaderboardWall") else nil
	if not wall then return end

	local rem = math.max(0, nextRefreshAt - os.time())
	local txt = string.format("Top 100 • Updates in %d:%02d", math.floor(rem / 60), rem % 60)
	for _, bName in ipairs({ "TopRebirthBoard", "TopSpeedBoard", "TopPlaytimeBoard" }) do
		local bm = wall:FindFirstChild(bName)
		local sp = if bm then bm:FindFirstChild("DisplaySurface") else nil
		local bg = if sp then sp:FindFirstChild("BoardGui") else nil
		local foot = if bg then bg:FindFirstChild("FooterLabel", true) else nil
		if foot and foot:IsA("TextLabel") then
			foot.Text = txt
		end
	end
end)
