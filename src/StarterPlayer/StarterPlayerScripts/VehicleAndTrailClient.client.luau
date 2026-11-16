--!strict
-- VehicleAndTrailClient.client.luau
-- Manages Speed Multiplier Trail VFX on character, Drivable Land Vehicle Visuals, and Towed Crate Spring Physics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TrailConfig = require(ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(ReplicatedStorage.Config.VehicleConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

local equippedTrailId = "BreezeTrail"
local equippedVehicleId = "StarterATV"
local isRidingVehicle = false

local activeTrail: Trail? = nil
local activeVehicleModel: Model? = nil
local towedCrateVisuals: { Model } = {}
local towedPositions: { Vector3 } = {}

local function findTrailDef(id: string)
	for _, t in ipairs(TrailConfig) do
		if t.id == id then return t end
	end
	return TrailConfig[1]
end

local function findVehicleDef(id: string)
	for _, v in ipairs(VehicleConfig) do
		if v.id == id then return v end
	end
	return VehicleConfig[1]
end

local function applyTrailToCharacter(char: Model)
	if activeTrail then
		activeTrail:Destroy()
		activeTrail = nil
	end
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then return end

	local a0 = root:FindFirstChild("TrailAttach0") :: Attachment?
	if not a0 then
		a0 = Instance.new("Attachment")
		a0.Name = "TrailAttach0"
		a0.Position = Vector3.new(0, 1.2, 0.6)
		a0.Parent = root
	end
	local a1 = root:FindFirstChild("TrailAttach1") :: Attachment?
	if not a1 then
		a1 = Instance.new("Attachment")
		a1.Name = "TrailAttach1"
		a1.Position = Vector3.new(0, -1.2, 0.6)
		a1.Parent = root
	end

	local def = findTrailDef(equippedTrailId)
	local trail = Instance.new("Trail")
	trail.Name = "RangerSpeedTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.55
	trail.MinLength = 0.1
	trail.LightEmission = 0.65
	trail.Color = ColorSequence.new(def.colorPrimary, def.colorSecondary)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = root
	activeTrail = trail
end

local function buildVehicleVisual(): Model
	local def = findVehicleDef(equippedVehicleId)
	local m = Instance.new("Model")
	m.Name = "ActiveRangerVehicle"

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4.8, 1.4, 7.6)
	chassis.Color = def.primaryColor
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Studs
	chassis.Anchored = true
	chassis.CanCollide = false
	chassis.CanQuery = false
	chassis.Parent = m
	m.PrimaryPart = chassis

	local bumper = Instance.new("Part")
	bumper.Name = "Bumper"
	bumper.Size = Vector3.new(5.2, 0.9, 1.0)
	bumper.Color = def.accentColor
	bumper.Anchored = true
	bumper.CanCollide = false
	bumper.CFrame = CFrame.new(0, -0.1, -3.9)
	bumper.Parent = m

	local wheelOffsets = {
		Vector3.new(-2.7, -0.8, -2.4),
		Vector3.new(2.7, -0.8, -2.4),
		Vector3.new(-2.7, -0.8, 2.4),
		Vector3.new(2.7, -0.8, 2.4),
	}
	for i, off in ipairs(wheelOffsets) do
		local w = Instance.new("Part")
		w.Name = "Wheel_" .. i
		w.Size = Vector3.new(1.1, 2.2, 2.2)
		w.Color = Color3.fromRGB(32, 34, 38)
		w.Material = Enum.Material.Rubber
		w.Shape = Enum.PartType.Cylinder
		w.Anchored = true
		w.CanCollide = false
		w.CFrame = CFrame.new(off) * CFrame.Angles(0, 0, math.pi / 2)
		w.Parent = m
	end

	m.Parent = Workspace
	return m
end

local function setRidingVehicle(state: boolean)
	isRidingVehicle = state
	Remotes.Get("SetMovementState"):FireServer("IsRidingVehicle", state)

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		hum.HipHeight = if state then 1.4 else 0
	end

	if activeVehicleModel then
		activeVehicleModel:Destroy()
		activeVehicleModel = nil
	end
	if state then
		activeVehicleModel = buildVehicleVisual()
	end
end

local function syncTowedCrateCount(count: number)
	while #towedCrateVisuals > count do
		local m = table.remove(towedCrateVisuals)
		if m then m:Destroy() end
		table.remove(towedPositions)
	end
	while #towedCrateVisuals < count do
		local m = Instance.new("Model")
		m.Name = "TowedCrateVisual"
		local box = Instance.new("Part")
		box.Name = "Box"
		box.Size = Vector3.new(3.8, 3.8, 3.8)
		box.Color = Color3.fromRGB(255, 196, 62)
		box.Material = Enum.Material.Wood
		box.TopSurface = Enum.SurfaceType.Studs
		box.Anchored = true
		box.CanCollide = false
		box.Parent = m
		m.PrimaryPart = box
		m.Parent = Workspace
		table.insert(towedCrateVisuals, m)

		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		table.insert(towedPositions, if root and root:IsA("BasePart") then root.Position else Vector3.new(0, 3, 0))
	end
end

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) ~= "table" then return end
	if profile.equippedTrail ~= equippedTrailId then
		equippedTrailId = profile.equippedTrail
		if localPlayer.Character then
			applyTrailToCharacter(localPlayer.Character)
		end
	end
	if profile.equippedVehicle ~= equippedVehicleId then
		equippedVehicleId = profile.equippedVehicle
		if isRidingVehicle then
			setRidingVehicle(true)
		end
	end
end)

Remotes.Get("SpawnVehicle").OnClientEvent:Connect(function(forceState)
	setRidingVehicle(if type(forceState) == "boolean" then forceState else not isRidingVehicle)
end)

localPlayer.AttributeChanged:Connect(function(attrName)
	if attrName == "TowedCrateCount" then
		syncTowedCrateCount(tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0)
	elseif attrName == "ToggleVehicleRequest" then
		setRidingVehicle(not isRidingVehicle)
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.V then
		setRidingVehicle(not isRidingVehicle)
	end
end)

localPlayer.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	applyTrailToCharacter(char)
	if isRidingVehicle then
		setRidingVehicle(true)
	end
end)
if localPlayer.Character then
	applyTrailToCharacter(localPlayer.Character)
end

RunService.RenderStepped:Connect(function(dt: number)
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then return end

	if isRidingVehicle and activeVehicleModel and activeVehicleModel.PrimaryPart then
		local targetCF = root.CFrame * CFrame.new(0, -1.8, 0)
		local chassis = activeVehicleModel.PrimaryPart
		for _, part in ipairs(activeVehicleModel:GetChildren()) do
			if part:IsA("BasePart") then
				if part == chassis then
					part.CFrame = targetCF
				elseif part.Name == "Bumper" then
					part.CFrame = targetCF * CFrame.new(0, -0.1, -3.9)
				elseif part.Name == "Wheel_1" then
					part.CFrame = targetCF * CFrame.new(-2.7, -0.8, -2.4) * CFrame.Angles(0, 0, math.pi / 2)
				elseif part.Name == "Wheel_2" then
					part.CFrame = targetCF * CFrame.new(2.7, -0.8, -2.4) * CFrame.Angles(0, 0, math.pi / 2)
				elseif part.Name == "Wheel_3" then
					part.CFrame = targetCF * CFrame.new(-2.7, -0.8, 2.4) * CFrame.Angles(0, 0, math.pi / 2)
				elseif part.Name == "Wheel_4" then
					part.CFrame = targetCF * CFrame.new(2.7, -0.8, 2.4) * CFrame.Angles(0, 0, math.pi / 2)
				end
			end
		end
	end

	-- Smooth Spring Lerp Towing for crates behind player/vehicle
	for i, crateM in ipairs(towedCrateVisuals) do
		local anchorPos = (root.CFrame * CFrame.new(0, 0.5, 6.5 * i)).Position
		local cur = towedPositions[i] or anchorPos
		cur = cur:Lerp(anchorPos, math.clamp(dt * 8, 0, 1))
		towedPositions[i] = cur
		crateM:PivotTo(CFrame.lookAt(cur, root.Position))
	end
end)
