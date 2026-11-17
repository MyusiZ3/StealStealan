--!strict
-- OnboardingArrow.client.luau
-- 60-Second Onboarding Guide Beam guiding new players:
-- 1. Step on Treadmill -> 2. Exit Gate to Onboarding Crate (Z=174) -> 3. Return Crate to Sanctuary Pen!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local profile: any = nil
local completedOnboarding = false

local targetAttachPart = Instance.new("Part")
targetAttachPart.Name = "OnboardingTargetAnchor"
targetAttachPart.Size = Vector3.new(1, 1, 1)
targetAttachPart.Anchored = true
targetAttachPart.CanCollide = false
targetAttachPart.CanQuery = false
targetAttachPart.Transparency = 1
targetAttachPart.Parent = Workspace

local targetAttach = Instance.new("Attachment")
targetAttach.Parent = targetAttachPart

local hintGui = Instance.new("BillboardGui")
hintGui.Size = UDim2.fromOffset(210, 48)
hintGui.StudsOffset = Vector3.new(0, 4.5, 0)
hintGui.AlwaysOnTop = true
hintGui.Parent = targetAttachPart

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.fromScale(1, 1)
hintLbl.BackgroundColor3 = Color3.fromRGB(20, 26, 36)
hintLbl.BackgroundTransparency = 0.2
hintLbl.TextColor3 = Color3.fromRGB(255, 224, 72)
hintLbl.Font = Enum.Font.FredokaOne
hintLbl.TextScaled = true
hintLbl.Parent = hintGui
Instance.new("UICorner", hintLbl).CornerRadius = UDim.new(0, 8)
local st = Instance.new("UIStroke")
st.Thickness = 2
st.Color = Color3.fromRGB(12, 14, 18)
st.Parent = hintLbl

local guideBeam: Beam? = nil

local function cleanupGuide()
	if guideBeam then
		guideBeam:Destroy()
		guideBeam = nil
	end
	hintGui.Enabled = false
end

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(newProf)
	if type(newProf) ~= "table" then return end
	profile = newProf
	local hasAnimal = next(newProf.inventoryAnimals) ~= nil
	if hasAnimal or (newProf.analyticsMeta and newProf.analyticsMeta.onboardingStep >= 1) then
		completedOnboarding = true
		cleanupGuide()
	end
end)

RunService.Heartbeat:Connect(function()
	if completedOnboarding or not profile then return end
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	local pAttach = root:FindFirstChild("OnboardingPlayerAttach") :: Attachment?
	if not pAttach then
		pAttach = Instance.new("Attachment")
		pAttach.Name = "OnboardingPlayerAttach"
		pAttach.Parent = root
	end

	if not guideBeam then
		local b = Instance.new("Beam")
		b.Name = "OnboardingBeam"
		b.Attachment0 = pAttach
		b.Attachment1 = targetAttach
		b.Width0 = 1.1
		b.Width1 = 1.1
		b.TextureSpeed = 2.5
		b.Color = ColorSequence.new(Color3.fromRGB(84, 255, 162), Color3.fromRGB(255, 224, 72))
		b.FaceCamera = true
		b.Parent = root
		guideBeam = b
	end

	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local plots = if hub then hub:FindFirstChild("Plots") else nil
	local myPlot: Model? = nil
	if plots then
		for _, p in ipairs(plots:GetChildren()) do
			if p:GetAttribute("OwnerUserId") == localPlayer.UserId then
				myPlot = p :: Model
				break
			end
		end
	end

	local towed = tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0
	if towed > 0 and myPlot then
		local pad = myPlot:FindFirstChild("OpenPaddockFloor")
		if pad and pad:IsA("BasePart") then
			targetAttachPart.Position = pad.Position + Vector3.new(0, 2.5, 0)
			hintLbl.Text = "Drop Crate Inside Pen!"
			hintGui.Enabled = true
			return
		end
	end

	if profile.speedStat < 2 and myPlot then
		local tread = myPlot:FindFirstChild("TreadmillStandAnchor") or myPlot:FindFirstChild("TreadmillPad")
		if tread and tread:IsA("BasePart") then
			targetAttachPart.Position = tread.Position + Vector3.new(0, 1.5, 0)
			hintLbl.Text = "Step on Treadmill (+Speed)!"
			hintGui.Enabled = true
			return
		end
	end

	-- Otherwise point to the Onboarding Crate right outside Safe Zone Gate
	targetAttachPart.Position = Vector3.new(10, 2.5, 174)
	hintLbl.Text = "Pull Starter Fox Crate!"
	hintGui.Enabled = true
end)
