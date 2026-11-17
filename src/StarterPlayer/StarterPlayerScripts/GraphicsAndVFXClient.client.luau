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
local lowVFXEnabled = false

-- Cached decor folders for Predictive Area Render Optimization (Zero pop-in lag!)
local decorCacheRoot = Instance.new("Folder")
decorCacheRoot.Name = "ClientCulledBiomeDecor"
decorCacheRoot.Parent = ReplicatedStorage

local biomeCache: { [string]: { model: Folder, decor: Folder?, zStart: number, zEnd: number, centerZ: number, visible: boolean } } = {}
local worldShadowOptimized = false

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
		lowVFXEnabled = (profile.settings.lowVFX == true)
		local q = profile.settings.graphicsQuality
		if q == "Low" or q == "Medium" or q == "High" then
			if q ~= currentQuality then
				applyGraphicsQuality(q)
			end
		end
	end
end)

-- One-time shadow pass optimization + register biome decor buckets cleanly in staggered yields
task.spawn(function()
	local gw = Workspace:WaitForChild("GameWorld", 15)
	if not gw then return end
	local biomesFolder = gw:FindFirstChild("Biomes")
	if not biomesFolder then return end

	for _, b in ipairs(BiomeConfig) do
		local bModel = biomesFolder:FindFirstChild(b.id)
		if bModel and bModel:IsA("Folder") then
			local decor = bModel:FindFirstChild("CuratedDecor")
			biomeCache[b.id] = {
				model = bModel,
				decor = if decor and decor:IsA("Folder") then decor else nil,
				zStart = b.zStart,
				zEnd = b.zEnd,
				centerZ = (b.zStart + b.zEnd) * 0.5,
				visible = true,
			}
			-- Disable redundant shadows/query cost on small decorative leaves/rocks for smooth High Graphics FPS
			if decor then
				for _, d in ipairs(decor:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CastShadow = false
						d.CanQuery = false
						d.CanTouch = false
					end
				end
			end
			task.wait()
		end
	end
	worldShadowOptimized = true
end)

local accum = 0
local cullAccum = 0
RunService.Heartbeat:Connect(function(dt: number)
	accum += dt
	cullAccum += dt

	-- Predictive Sliding-Window Area Render (Every 0.25s, max 1 swap per frame to prevent hitching!)
	if cullAccum >= 0.25 and worldShadowOptimized then
		cullAccum = 0
		local char = localPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		local posZ = if root and root:IsA("BasePart") then root.Position.Z else 0
		local velZ = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Z else 0
		-- Pre-render ahead of movement direction (~1.6s velocity lookahead so fast travel never shows pop-in!)
		local predZ = posZ + math.clamp(velZ * 1.6, -260, 260)

		local loadHalfSpan = if currentQuality == "High" then 520 elseif currentQuality == "Medium" then 450 else 360
		local unloadHalfSpan = loadHalfSpan + 95 -- Hysteresis buffer prevents flickering on borders

		-- Toggle 1 biome decor folder at most per tick for zero frame drops
		for biomeId, entry in pairs(biomeCache) do
			if entry.decor then
				local distToSpan = 0
				if predZ < entry.zStart then
					distToSpan = entry.zStart - predZ
				elseif predZ > entry.zEnd then
					distToSpan = predZ - entry.zEnd
				end
				if not entry.visible and distToSpan <= loadHalfSpan then
					entry.decor.Parent = entry.model
					entry.visible = true
					break
				elseif entry.visible and distToSpan > unloadHalfSpan then
					entry.decor.Parent = decorCacheRoot
					entry.visible = false
					break
				end
			end
		end
	end

	if accum < 0.45 then return end
	accum = 0

	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		-- Also cull distant lights & emitters inside SanctuaryHub / ActiveCrates beyond render radius
		local camPos = root.Position
		local gw = Workspace:FindFirstChild("GameWorld")
		if gw then
			local hub = gw:FindFirstChild("SanctuaryHub")
			if hub then
				for _, d in ipairs(hub:GetDescendants()) do
					if d:IsA("PointLight") and d.Parent and d.Parent:IsA("BasePart") then
						d.Enabled = (currentQuality ~= "Low") and ((d.Parent.Position - camPos).Magnitude <= 220)
					end
				end
			end
		end

		if currentQuality ~= "High" or lowVFXEnabled then
			ambientEmitter.Enabled = false
			return
		end

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
