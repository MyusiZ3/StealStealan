--!strict
-- RescueClient.client.luau
-- Renders the glowing Lasso Beam during crate extraction, Pull Progress + Tap Boost UI, Slow Mode brake, & 60s Onboarding Arrow

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RunService = game:GetService("RunService")
local LassoConfig = require(ReplicatedStorage.Config.LassoConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

local equippedLassoId = "RopeLasso"
local isSlowMode = false
local beamPart: Part? = nil
local ropeBeam: Beam? = nil
local ropeAttach0Part: Part? = nil
local ropeAttach1Part: Part? = nil
local loopRingParts: { Part } = {}
local digVfxPart: Part? = nil
local digDirtEmitter: ParticleEmitter? = nil
local digSparkEmitter: ParticleEmitter? = nil
local isPullActive = false
local activeCratePos: Vector3? = nil
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
	lbl.Text = "CLICK / TAP FAST TO PULL!"
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
	tapBtn.Size = UDim2.new(0.76, 0, 0, 28)
	tapBtn.Position = UDim2.new(0.12, 0, 0, 62)
	tapBtn.BackgroundColor3 = Color3.fromRGB(255, 178, 44)
	tapBtn.Text = "CLICK / TAP / SPACE TO PULL!"
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

local function destroyLassoRopeVisuals()
	if beamPart then
		beamPart:Destroy()
		beamPart = nil
	end
	if ropeBeam then
		ropeBeam:Destroy()
		ropeBeam = nil
	end
	if ropeAttach0Part then
		ropeAttach0Part:Destroy()
		ropeAttach0Part = nil
	end
	if ropeAttach1Part then
		ropeAttach1Part:Destroy()
		ropeAttach1Part = nil
	end
	for _, seg in ipairs(loopRingParts) do
		if seg then seg:Destroy() end
	end
	table.clear(loopRingParts)
	if digVfxPart then
		digVfxPart:Destroy()
		digVfxPart = nil
		digDirtEmitter = nil
		digSparkEmitter = nil
	end
	localPlayer:SetAttribute("ClientPullingCrate", false)
end

local function updateBeam(cratePos: Vector3?)
	if not cratePos then
		destroyLassoRopeVisuals()
		return
	end
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	-- Anchor rope visually at player's Right Hand / held lasso coil!
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local startPos = if hand and hand:IsA("BasePart")
		then (hand.CFrame * CFrame.new(0, -0.15, -0.35)).Position
		else (root.CFrame * CFrame.new(1.1, 0.3, -0.6)).Position
	local targetLoopPos = cratePos + Vector3.new(0, 0.45, 0)
	local lassoCol = getLassoColor()

	if not beamPart then
		local p = Instance.new("Part")
		p.Name = "ClientLassoRope3D"
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Parent = Workspace
		beamPart = p
	end

	if not ropeAttach0Part then
		local a0p = Instance.new("Part")
		a0p.Name = "LassoAttachA0"
		a0p.Size = Vector3.new(0.2, 0.2, 0.2)
		a0p.Transparency = 1
		a0p.Anchored = true
		a0p.CanCollide = false
		a0p.CanQuery = false
		a0p.Parent = Workspace
		local att0 = Instance.new("Attachment", a0p)
		att0.Name = "Att0"
		ropeAttach0Part = a0p

		local a1p = Instance.new("Part")
		a1p.Name = "LassoAttachA1"
		a1p.Size = Vector3.new(0.2, 0.2, 0.2)
		a1p.Transparency = 1
		a1p.Anchored = true
		a1p.CanCollide = false
		a1p.CanQuery = false
		a1p.Parent = Workspace
		local att1 = Instance.new("Attachment", a1p)
		att1.Name = "Att1"
		ropeAttach1Part = a1p

		local b = Instance.new("Beam")
		b.Name = "LassoEnergyBeam"
		b.Attachment0 = att0
		b.Attachment1 = att1
		b.Width0 = 0.42
		b.Width1 = 0.56
		b.LightEmission = 0.9
		b.FaceCamera = true
		b.Parent = a0p
		ropeBeam = b
	end

	if #loopRingParts == 0 then
		for i = 1, 6 do
			local seg = Instance.new("Part")
			seg.Name = "LassoLoopSeg_" .. i
			seg.Size = Vector3.new(0.26, 0.26, 2.2)
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CastShadow = false
			seg.Material = Enum.Material.Neon
			seg.Parent = Workspace
			table.insert(loopRingParts, seg)
		end
	end

	local delta = targetLoopPos - startPos
	local dist = math.max(0.2, delta.Magnitude)
	local mid = (startPos + targetLoopPos) * 0.5

	local bp = beamPart :: Part
	bp.Size = Vector3.new(dist, 0.26, 0.26)
	bp.Color = lassoCol
	bp.CFrame = CFrame.lookAt(mid, targetLoopPos) * CFrame.Angles(0, math.pi * 0.5, 0)

	if ropeAttach0Part and ropeAttach1Part and ropeBeam then
		ropeAttach0Part.Position = startPos
		ropeAttach1Part.Position = targetLoopPos
		ropeBeam.Color = ColorSequence.new(lassoCol, Color3.new(1, 1, 1))
		local t = os.clock() * 14
		ropeBeam.CurveSize0 = math.sin(t) * 1.4
		ropeBeam.CurveSize1 = math.cos(t) * 1.2
	end

	local spin = os.clock() * 5.2
	local radius = 2.65
	local segCount = #loopRingParts
	for i, seg in ipairs(loopRingParts) do
		local a = spin + ((i - 1) / segCount) * math.pi * 2
		local ringPos = targetLoopPos + Vector3.new(math.cos(a) * radius, math.sin(spin * 1.3 + i) * 0.2, math.sin(a) * radius)
		seg.Color = lassoCol
		seg.CFrame = CFrame.lookAt(ringPos, targetLoopPos) * CFrame.Angles(0, math.pi * 0.5, 0)
	end

	-- Active Digging Earth Dust + Lasso Spark VFX around the crate being pulled
	if not digVfxPart then
		local dp = Instance.new("Part")
		dp.Name = "LassoDigVFXPart"
		dp.Size = Vector3.new(3.2, 0.4, 3.2)
		dp.Transparency = 1
		dp.Anchored = true
		dp.CanCollide = false
		dp.CanQuery = false
		dp.CanTouch = false
		dp.Parent = Workspace
		digVfxPart = dp

		local dirt = Instance.new("ParticleEmitter")
		dirt.Name = "DigDirtEmitter"
		dirt.Rate = 30
		dirt.Lifetime = NumberRange.new(0.45, 0.9)
		dirt.Speed = NumberRange.new(8, 17)
		dirt.SpreadAngle = Vector2.new(58, 58)
		dirt.Acceleration = Vector3.new(0, -32, 0)
		dirt.EmissionDirection = Enum.NormalId.Top
		dirt.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
		dirt.Color = ColorSequence.new(Color3.fromRGB(148, 106, 68), Color3.fromRGB(92, 66, 42))
		dirt.RotSpeed = NumberRange.new(-180, 180)
		dirt.Parent = dp
		digDirtEmitter = dirt

		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "DigSparkEmitter"
		sparks.Rate = 24
		sparks.Lifetime = NumberRange.new(0.3, 0.65)
		sparks.Speed = NumberRange.new(10, 22)
		sparks.SpreadAngle = Vector2.new(70, 70)
		sparks.Acceleration = Vector3.new(0, -14, 0)
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(1, 0) })
		sparks.Color = ColorSequence.new(lassoCol, Color3.new(1, 1, 1))
		sparks.Parent = dp
		digSparkEmitter = sparks
	end
	if digVfxPart then
		digVfxPart.Position = Vector3.new(cratePos.X, math.max(0.4, cratePos.Y - 0.6), cratePos.Z)
		if digSparkEmitter then
			digSparkEmitter.Color = ColorSequence.new(lassoCol, Color3.new(1, 1, 1))
		end
	end
end

RunService.RenderStepped:Connect(function()
	if isPullActive and activeCratePos then
		updateBeam(activeCratePos)
	elseif beamPart then
		destroyLassoRopeVisuals()
	end
end)

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and profile.equippedLasso then
		equippedLassoId = profile.equippedLasso
	end
end)

Remotes.Get("PullProgressSync").OnClientEvent:Connect(function(data)
	ensurePullUI()
	if not activePullGui then return end
	if data.active then
		isPullActive = true
		activeCratePos = data.cratePos
		localPlayer:SetAttribute("ClientPullingCrate", true)
		activePullGui.Enabled = true
		local weak = data.tooWeak == true
		if pullFillBar then
			pullFillBar.Size = UDim2.fromScale(math.clamp(data.progress or 0, 0, 1), 1)
			pullFillBar.BackgroundColor3 = if weak then Color3.fromRGB(255, 76, 68) else Color3.fromRGB(84, 245, 148)
		end
		if pullLabel then
			local pct = math.floor((data.progress or 0) * 100)
			if weak then
				pullLabel.Text = string.format("⚠️ LASSO TOO WEAK! [%s] %d%%", string.upper(tostring(data.rarity or "")), pct)
				pullLabel.TextColor3 = Color3.fromRGB(255, 118, 108)
			else
				pullLabel.Text = string.format("TAP FAST! [%s] %d%%", string.upper(tostring(data.rarity or "")), pct)
				pullLabel.TextColor3 = Color3.new(1, 1, 1)
			end
		end
		updateBeam(data.cratePos)
	else
		isPullActive = false
		activeCratePos = nil
		localPlayer:SetAttribute("ClientPullingCrate", false)
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
	if isPullActive and (input.KeyCode == Enum.KeyCode.Space or (not gp and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch))) then
		Remotes.Get("LassoTapBoost"):FireServer()
		return
	end
	if gp then return end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		toggleSlowMode()
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
