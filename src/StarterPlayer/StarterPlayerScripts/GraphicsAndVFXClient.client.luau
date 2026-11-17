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
	local kept: Instance? = nil
	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch.ClassName == className then
			if ch.Name == name and not kept then
				kept = ch
			else
				ch:Destroy()
			end
		end
	end
	if kept then
		return kept :: any
	end
	local inst = Instance.new(className) :: any
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

-- Comfortable anti-glare sunlit palette (stops flat sunlit floors/slabs from blowing out white!)
pcall(function()
	Lighting.Brightness = 1.65
	Lighting.ExposureCompensation = -0.12
	Lighting.Ambient = Color3.fromRGB(96, 106, 124)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 124, 142)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.22
	Lighting.ClockTime = 15.2
end)

local atmosphere: Atmosphere = ensureEffect("Atmosphere", "GameAtmosphere")
atmosphere.Density = 0.20
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(246, 226, 238)
atmosphere.Decay = Color3.fromRGB(236, 204, 224)
atmosphere.Glare = 0
atmosphere.Haze = 0.65

local terrainClouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
terrainClouds.Cover = 0.58
terrainClouds.Density = 0.42
terrainClouds.Color = Color3.fromRGB(250, 228, 238)
terrainClouds.Parent = Workspace.Terrain

local colorCorr: ColorCorrectionEffect = ensureEffect("ColorCorrectionEffect", "GameColorCorrection")
colorCorr.Saturation = 0.14
colorCorr.Contrast = 0.06
colorCorr.Brightness = -0.02

local bloom: BloomEffect = ensureEffect("BloomEffect", "GameBloom")
bloom.Intensity = 0.10
bloom.Size = 14
bloom.Threshold = 2.40

local sunRays: SunRaysEffect = ensureEffect("SunRaysEffect", "GameSunRays")
sunRays.Intensity = 0.02
sunRays.Spread = 0.20

local depthOfField: DepthOfFieldEffect = ensureEffect("DepthOfFieldEffect", "GameDepthOfField")
depthOfField.FocusDistance = 58
depthOfField.InFocusRadius = 96
depthOfField.NearIntensity = 0
depthOfField.FarIntensity = 0.16

local skyIslandCache: { { inst: Model, z: number, visible: boolean } } = {}
local brushedDecorCache: { { inst: Instance, z: number, visible: boolean } } = {}

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
		colorCorr.Brightness = -0.02
		colorCorr.Contrast = 0.06
		colorCorr.Saturation = 0.08
		bloom.Enabled = false
		sunRays.Enabled = false
		depthOfField.Enabled = false
		ambientEmitter.Enabled = false
	elseif quality == "Medium" then
		pcall(function() Lighting.GlobalShadows = true end)
		colorCorr.Enabled = true
		colorCorr.Brightness = -0.02
		colorCorr.Contrast = 0.06
		colorCorr.Saturation = 0.14
		bloom.Enabled = true
		bloom.Intensity = 0.10
		bloom.Size = 14
		bloom.Threshold = 2.40
		sunRays.Enabled = false
		depthOfField.Enabled = true
		depthOfField.FocusDistance = 58
		depthOfField.InFocusRadius = 96
		depthOfField.NearIntensity = 0
		depthOfField.FarIntensity = 0.16
		ambientEmitter.Enabled = false
	else -- High
		pcall(function() Lighting.GlobalShadows = true end)
		colorCorr.Enabled = true
		colorCorr.Brightness = -0.02
		colorCorr.Contrast = 0.06
		colorCorr.Saturation = 0.18
		bloom.Enabled = true
		bloom.Intensity = 0.16
		bloom.Size = 14
		bloom.Threshold = 2.40
		sunRays.Enabled = true
		sunRays.Intensity = 0.02
		sunRays.Spread = 0.20
		depthOfField.Enabled = true
		depthOfField.FocusDistance = 68
		depthOfField.InFocusRadius = 115
		depthOfField.NearIntensity = 0
		depthOfField.FarIntensity = 0.24
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
	local skyFolder = gw:FindFirstChild("SkyIslands")
	if skyFolder then
		for _, ch in ipairs(skyFolder:GetChildren()) do
			if ch:IsA("Model") and ch.PrimaryPart then
				table.insert(skyIslandCache, {
					inst = ch,
					z = ch.PrimaryPart.Position.Z,
					visible = true,
				})
			end
		end
	end

	-- Optimize & register any Brushtool 2.1 painted props in Workspace.GameWorld.BrushedDecor
	local brushedFolder = gw:FindFirstChild("BrushedDecor")
	if brushedFolder then
		for _, prop in ipairs(brushedFolder:GetChildren()) do
			local zPos: number? = nil
			if prop:IsA("BasePart") then
				zPos = prop.Position.Z
				if prop.Size.Magnitude < 28 then
					prop.CastShadow = false
					prop.CanQuery = false
					prop.CanTouch = false
				end
			elseif prop:IsA("Model") then
				local okBox, cf = pcall(function() return prop:GetBoundingBox() end)
				if okBox and cf then
					zPos = cf.Position.Z
				end
				for _, d in ipairs(prop:GetDescendants()) do
					if d:IsA("BasePart") and d.Size.Magnitude < 28 then
						d.CastShadow = false
						d.CanQuery = false
						d.CanTouch = false
					end
				end
			end
			if zPos then
				table.insert(brushedDecorCache, {
					inst = prop,
					z = zPos,
					visible = true,
				})
			end
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

		local loadHalfSpan = if currentQuality == "High" then 560 elseif currentQuality == "Medium" then 440 else 300
		local unloadHalfSpan = loadHalfSpan + 95 -- Hysteresis buffer prevents flickering on borders
		local skySpan = if currentQuality == "High" then 1150 elseif currentQuality == "Medium" then 900 else 650

		local gwSky = Workspace:FindFirstChild("GameWorld") and Workspace.GameWorld:FindFirstChild("SkyIslands")
		if gwSky then
			for _, sky in ipairs(skyIslandCache) do
				local dZ = math.abs(sky.z - predZ)
				if not sky.visible and dZ <= skySpan then
					sky.inst.Parent = gwSky
					sky.visible = true
				elseif sky.visible and dZ > (skySpan + 120) then
					sky.inst.Parent = decorCacheRoot
					sky.visible = false
				end
			end
		end

		local gwBrushed = Workspace:FindFirstChild("GameWorld") and Workspace.GameWorld:FindFirstChild("BrushedDecor")
		if gwBrushed then
			for _, bp in ipairs(brushedDecorCache) do
				local dZ = math.abs(bp.z - predZ)
				if not bp.visible and dZ <= loadHalfSpan then
					bp.inst.Parent = gwBrushed
					bp.visible = true
				elseif bp.visible and dZ > (loadHalfSpan + 160) then
					bp.inst.Parent = decorCacheRoot
					bp.visible = false
				end
			end
		end

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
