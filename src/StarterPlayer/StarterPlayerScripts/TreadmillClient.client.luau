--!strict
-- TreadmillClient.client.luau
-- Snaps character onto TreadmillStandAnchor when entering Treadmill zone,
-- plays looped Running animation + speed sparks, and lets player hop off by pressing Space / Jump.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local onTreadmill = false
local snapCFrame: CFrame? = nil
local activeRunTrack: AnimationTrack? = nil
local hopOffGui: ScreenGui? = nil
local footSparkEmitter: ParticleEmitter? = nil

local R15_RUN_ANIM = "rbxassetid://507767714"
local R6_RUN_ANIM = "rbxassetid://180426354"

local function ensureHopOffUI()
	if hopOffGui then return end
	local sg = Instance.new("ScreenGui")
	sg.Name = "TreadmillOverlay"
	sg.ResetOnSpawn = false
	sg.Enabled = false
	sg.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(240, 40)
	btn.Position = UDim2.new(0.5, -120, 0.78, 0)
	btn.BackgroundColor3 = Color3.fromRGB(224, 58, 52)
	btn.Text = "JUMP / CLICK TO HOP OFF"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.FredokaOne
	btn.TextScaled = true
	btn.Parent = sg
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(14, 15, 18)
	st.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if onTreadmill then
			Remotes.Get("TreadmillState"):FireServer(false)
		end
	end)
	hopOffGui = sg
end

local function stopTreadmillAnim()
	if activeRunTrack then
		pcall(function()
			activeRunTrack:Stop(0.15)
			activeRunTrack:Destroy()
		end)
		activeRunTrack = nil
	end
	if footSparkEmitter then
		footSparkEmitter.Enabled = false
		footSparkEmitter:Destroy()
		footSparkEmitter = nil
	end
	if hopOffGui then
		hopOffGui.Enabled = false
	end
end

local function startTreadmillAnim()
	stopTreadmillAnim()
	ensureHopOffUI()
	if hopOffGui then
		hopOffGui.Enabled = true
	end

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not hum or not root or not root:IsA("BasePart") then return end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = if hum.RigType == Enum.HumanoidRigType.R15 then R15_RUN_ANIM else R6_RUN_ANIM
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	anim:Destroy()
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.1, 1, 2.2)
		activeRunTrack = track
	end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "TreadmillSparks"
	sparks.Rate = 18
	sparks.Lifetime = NumberRange.new(0.25, 0.45)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.Color = ColorSequence.new(Color3.fromRGB(64, 224, 255), Color3.fromRGB(255, 255, 255))
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.EmissionDirection = Enum.NormalId.Back
	sparks.Parent = root
	footSparkEmitter = sparks
end

Remotes.Get("TreadmillState").OnClientEvent:Connect(function(active: boolean, targetCF: CFrame?)
	onTreadmill = active
	if active and targetCF then
		snapCFrame = targetCF
		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = targetCF
		end
		startTreadmillAnim()
	else
		local exitCF = snapCFrame
		snapCFrame = nil
		stopTreadmillAnim()
		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and exitCF then
			-- Step safely behind/off the treadmill belt
			root.CFrame = exitCF * CFrame.new(0, 1.5, 6.5)
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if onTreadmill then
		onTreadmill = false
		Remotes.Get("TreadmillState"):FireServer(false)
	end
end)

RunService.Heartbeat:Connect(function()
	if not onTreadmill or not snapCFrame then return end
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		-- Keep character positioned cleanly on belt while running animation plays
		root.CFrame = snapCFrame
		root.AssemblyLinearVelocity = Vector3.zero
	end
end)

localPlayer.CharacterAdded:Connect(function()
	onTreadmill = false
	snapCFrame = nil
	stopTreadmillAnim()
end)
