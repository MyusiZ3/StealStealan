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
local treadmillEnteredAt = 0
local snapCFrame: CFrame? = nil
local activeRunTrack: AnimationTrack? = nil
local hopOffGui: ScreenGui? = nil
local footSparkEmitter: ParticleEmitter? = nil
local savedAutoRotate = true
local standingHipHeight = 2.0

local R15_RUN_ANIM = "rbxassetid://507767714"
local R6_RUN_ANIM = "rbxassetid://180426354"

local exitTreadmillClient: (boolean) -> ()

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
	btn.TextSize = 15
	btn.Parent = sg
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(14, 15, 18)
	st.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if onTreadmill then
			exitTreadmillClient(true)
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

exitTreadmillClient = function(notifyServer: boolean)
	if not onTreadmill and not snapCFrame then
		return
	end
	onTreadmill = false
	local exitCF = snapCFrame
	snapCFrame = nil
	stopTreadmillAnim()

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if hum then
		hum.AutoRotate = savedAutoRotate
	end
	if root and root:IsA("BasePart") then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if exitCF then
			-- Step cleanly behind the treadmill deck (+7.8 behind local look direction)
			root.CFrame = exitCF * CFrame.new(0, 0.5, 7.8)
		end
	end
	if notifyServer then
		Remotes.Get("TreadmillState"):FireServer(false)
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

Remotes.Get("TreadmillState").OnClientEvent:Connect(function(active: boolean, targetCF: CFrame?, beltSurfaceY: number?)
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if active and targetCF then
		if onTreadmill then return end
		onTreadmill = true
		treadmillEnteredAt = os.clock()
		local finalCF = targetCF
		if hum and root and root:IsA("BasePart") then
			savedAutoRotate = hum.AutoRotate
			hum.AutoRotate = false
			-- Always use clean standing hipHeight so feet sit 0.00 studs flush on belt without up/down bounce
			local attrHip = tonumber(localPlayer:GetAttribute("StandingHipHeight"))
			local cleanHip = if attrHip and (attrHip > 0.4 or hum.RigType == Enum.HumanoidRigType.R6)
				then attrHip
				elseif localPlayer:GetAttribute("IsRidingVehicle") ~= true and tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") == ""
				then hum.HipHeight
				else standingHipHeight
			standingHipHeight = cleanHip
			hum.HipHeight = cleanHip
			if type(beltSurfaceY) == "number" then
				local footOffset = if hum.RigType == Enum.HumanoidRigType.R6 then 3.0 else (cleanHip + root.Size.Y * 0.5)
				local rotOnly = targetCF - targetCF.Position
				finalCF = CFrame.new(targetCF.Position.X, beltSurfaceY + footOffset, targetCF.Position.Z) * rotOnly
			end
			-- Ensure any attached held/carried parts are completely massless & non-colliding
			for _, desc in ipairs(char:GetDescendants()) do
				if desc:IsA("BasePart") and (desc.Name == "ClientHeldItemModel" or string.find(desc.Name, "Crate") or desc:FindFirstAncestor("ClientHeldItemModel") or desc:FindFirstAncestor("ClientCarriedCrate")) then
					desc.CanCollide = false
					desc.CanTouch = false
					desc.CanQuery = false
					desc.Massless = true
				end
			end
		end
		snapCFrame = finalCF
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.CFrame = finalCF
			root.Anchored = true
		end
		if hum then
			hum:Move(Vector3.zero)
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end
		startTreadmillAnim()
	else
		exitTreadmillClient(false)
	end
end)

UserInputService.JumpRequest:Connect(function()
	if onTreadmill then
		exitTreadmillClient(true)
	end
end)

RunService.RenderStepped:Connect(function()
	if not onTreadmill or not snapCFrame then return end
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if hum then
		hum.AutoRotate = false
		hum:Move(Vector3.zero)
	end
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.CFrame = snapCFrame
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end)

localPlayer.CharacterAdded:Connect(function(char)
	onTreadmill = false
	snapCFrame = nil
	stopTreadmillAnim()
	local hum = char:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		standingHipHeight = hum.HipHeight
	end
end)
if localPlayer.Character then
	local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		standingHipHeight = hum.HipHeight
	end
end
