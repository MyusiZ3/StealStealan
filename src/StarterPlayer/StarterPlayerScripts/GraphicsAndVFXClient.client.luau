--!strict
-- GraphicsAndVFXClient.client.luau
-- Lightweight Graphics Enhancer (ColorCorrection, Bloom, SunRays, & Ambient Biome Particles)
-- Controlled by Profile.settings.graphicsQuality ("Low" | "Medium" | "High")

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local currentQuality: Types.GraphicsQuality = "Medium"

local function ensureEffect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local inst = Instance.new(className) :: any
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

local colorCorr: ColorCorrectionEffect = ensureEffect("ColorCorrectionEffect", "GameColorCorrection")
colorCorr.Saturation = 0.22
colorCorr.Contrast = 0.08
colorCorr.Brightness = 0.03

local bloom: BloomEffect = ensureEffect("BloomEffect", "GameBloom")
bloom.Intensity = 0.35
bloom.Size = 18
bloom.Threshold = 1.05

local sunRays: SunRaysEffect = ensureEffect("SunRaysEffect", "GameSunRays")
sunRays.Intensity = 0.08
sunRays.Spread = 0.45

-- Ambient particle anchor following player on High graphics
local ambientAnchor = Instance.new("Part")
ambientAnchor.Name = "ClientAmbientBiomeVFX"
ambientAnchor.Size = Vector3.new(40, 1, 40)
ambientAnchor.Transparency = 1
ambientAnchor.Anchored = true
ambientAnchor.CanCollide = false
ambientAnchor.CanQuery = false
ambientAnchor.CanTouch = false
ambientAnchor.Parent = Workspace

local ambientEmitter = Instance.new("ParticleEmitter")
ambientEmitter.Name = "BiomeAmbientEmitter"
ambientEmitter.Rate = 10
ambientEmitter.Lifetime = NumberRange.new(2.5, 4.5)
ambientEmitter.Speed = NumberRange.new(1.5, 4.0)
ambientEmitter.Size = NumberSequence.new(0.45, 0.1)
ambientEmitter.EmissionDirection = Enum.NormalId.Bottom
ambientEmitter.Enabled = false
ambientEmitter.Parent = ambientAnchor

local BIOME_VFX_COLORS: { [string]: Color3 } = {
	PineWoods = Color3.fromRGB(142, 238, 128),
	MangroveSwamp = Color3.fromRGB(178, 255, 112),
	SavannaCamp = Color3.fromRGB(255, 218, 128),
	AlpinePeaks = Color3.fromRGB(240, 248, 255),
	VolcanicJungle = Color3.fromRGB(255, 118, 42),
}

local function applyGraphicsQuality(quality: Types.GraphicsQuality)
	currentQuality = quality
	if quality == "Low" then
		pcall(function() Lighting.GlobalShadows = false end)
		colorCorr.Enabled = true
		colorCorr.Saturation = 0.10
		bloom.Enabled = false
		sunRays.Enabled = false
		ambientEmitter.Enabled = false
	elseif quality == "Medium" then
		pcall(function() Lighting.GlobalShadows = true end)
		colorCorr.Enabled = true
		colorCorr.Saturation = 0.20
		bloom.Enabled = true
		bloom.Intensity = 0.30
		sunRays.Enabled = false
		ambientEmitter.Enabled = false
	else -- High
		pcall(function() Lighting.GlobalShadows = true end)
		colorCorr.Enabled = true
		colorCorr.Saturation = 0.26
		bloom.Enabled = true
		bloom.Intensity = 0.45
		sunRays.Enabled = true
		ambientEmitter.Enabled = true
	end
end

applyGraphicsQuality("Medium")

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and type(profile.settings) == "table" then
		local q = profile.settings.graphicsQuality
		if q == "Low" or q == "Medium" or q == "High" then
			if q ~= currentQuality then
				applyGraphicsQuality(q)
			end
		end
	end
end)

local accum = 0
RunService.Heartbeat:Connect(function(dt: number)
	accum += dt
	if accum < 0.45 then return end
	accum = 0

	if currentQuality ~= "High" then
		ambientEmitter.Enabled = false
		return
	end

	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		ambientAnchor.CFrame = CFrame.new(root.Position + Vector3.new(0, 16, 0))
		local z = root.Position.Z
		local biomeId = "PineWoods"
		for _, b in ipairs(BiomeConfig) do
			if z >= b.zStart and z <= b.zEnd then
				biomeId = b.id
				break
			end
		end
		ambientEmitter.Color = ColorSequence.new(BIOME_VFX_COLORS[biomeId] or Color3.new(1, 1, 1))
		ambientEmitter.Enabled = (z > GameConfig.WORLD.SAFE_ZONE_Z_MAX - 20)
	end
end)
