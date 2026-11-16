--!strict
-- RescueClient.client.luau
-- Renders the glowing Lasso Beam during crate extraction, Pull Progress + Tap Boost UI, Slow Mode brake, & 60s Onboarding Arrow

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LassoConfig = require(ReplicatedStorage.Config.LassoConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

local equippedLassoId = "RopeLasso"
local isSlowMode = false
local beamPart: Part? = nil
local activePullGui: ScreenGui? = nil
local pullFillBar: Frame? = nil
local pullLabel: TextLabel? = nil

local function getLassoColor(): Color3
	for _, l in ipairs(LassoConfig) do
		if l.id == equippedLassoId then
			return l.beamColor
		end
	end
	return Color3.fromRGB(255, 206, 72)
end

local function ensurePullUI()
	if activePullGui then return end
	local pg = localPlayer:WaitForChild("PlayerGui")
	local sg = Instance.new("ScreenGui")
	sg.Name = "LassoPullOverlay"
	sg.ResetOnSpawn = false
	sg.Enabled = false
	sg.Parent = pg

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(360, 96)
	panel.Position = UDim2.new(0.5, -180, 0.72, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	panel.BackgroundTransparency = 0.12
	panel.Parent = sg
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 206, 72)
	stroke.Thickness = 2
	stroke.Parent = panel

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 0, 28)
	lbl.Position = UDim2.fromOffset(10, 6)
	lbl.BackgroundTransparency = 1
	lbl.Text = "PULLING CRATE... TAP SPACE / BUTTON!"
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = panel
	pullLabel = lbl

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 18)
	track.Position = UDim2.fromOffset(12, 38)
	track.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
	track.Parent = panel
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 8)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(84, 245, 148)
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
	pullFillBar = fill

	local tapBtn = Instance.new("TextButton")
	tapBtn.Size = UDim2.new(0.7, 0, 0, 28)
	tapBtn.Position = UDim2.new(0.15, 0, 0, 62)
	tapBtn.BackgroundColor3 = Color3.fromRGB(255, 178, 44)
	tapBtn.Text = "YANK HARDER! (TAP / SPACE)"
	tapBtn.TextColor3 = Color3.fromRGB(22, 22, 26)
	tapBtn.Font = Enum.Font.FredokaOne
	tapBtn.TextScaled = true
	tapBtn.Parent = panel
	Instance.new("UICorner", tapBtn).CornerRadius = UDim.new(0, 8)
	tapBtn.MouseButton1Click:Connect(function()
		Remotes.Get("LassoTapBoost"):FireServer()
	end)

	activePullGui = sg
end

local function updateBeam(cratePos: Vector3?)
	if not cratePos then
		if beamPart then
			beamPart:Destroy()
			beamPart = nil
		end
		return
	end
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	if not beamPart then
		local p = Instance.new("Part")
		p.Name = "ClientLassoBeam"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.Neon
		p.Parent = Workspace
		beamPart = p
	end

	local startPos = root.Position + Vector3.new(0, 0.5, 0)
	local dist = (cratePos - startPos).Magnitude
	local bp = beamPart :: Part
	bp.Size = Vector3.new(0.28, 0.28, dist)
	bp.Color = getLassoColor()
	bp.CFrame = CFrame.lookAt(startPos, cratePos) * CFrame.new(0, 0, -dist / 2)
end

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and profile.equippedLasso then
		equippedLassoId = profile.equippedLasso
	end
end)

Remotes.Get("PullProgressSync").OnClientEvent:Connect(function(data)
	ensurePullUI()
	if not activePullGui then return end
	if data.active then
		activePullGui.Enabled = true
		if pullFillBar then
			pullFillBar.Size = UDim2.fromScale(math.clamp(data.progress or 0, 0, 1), 1)
		end
		if pullLabel then
			pullLabel.Text = string.format("PULLING [%s] CRATE — %d%%", string.upper(tostring(data.rarity or "")), math.floor((data.progress or 0) * 100))
		end
		updateBeam(data.cratePos)
	else
		activePullGui.Enabled = false
		updateBeam(nil)
	end
end)

local function toggleSlowMode()
	isSlowMode = not isSlowMode
	localPlayer:SetAttribute("SlowMode", isSlowMode)
	Remotes.Get("SetMovementState"):FireServer("SlowMode", isSlowMode)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		toggleSlowMode()
	elseif input.KeyCode == Enum.KeyCode.Space and activePullGui and activePullGui.Enabled then
		Remotes.Get("LassoTapBoost"):FireServer()
	end
end)

localPlayer.AttributeChanged:Connect(function(attr)
	if attr == "ToggleSlowModeRequest" then
		toggleSlowMode()
	end
end)

-- Ragdoll / Knockback handler when tackled by Poacher or Boss (no teleport to base!)
Remotes.Get("PlayerKnockback").OnClientEvent:Connect(function(knockVel: Vector3, stunDuration: number)
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not hum or not root or not root:IsA("BasePart") then
		return
	end

	hum.PlatformStand = true
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end)
	root.AssemblyLinearVelocity = knockVel
	root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))

	task.delay(tonumber(stunDuration) or 1.4, function()
		if hum.Parent then
			hum.PlatformStand = false
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
	end)
end)
