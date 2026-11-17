--!strict
-- CinematicVFX.luau
-- Anti-glare tiered World & UI Cinematic VFX Engine:
--   1) Tiered Crate Hatching + Full-Screen RNG Reveal Cutscene (Cosmic..Primordial)
--   2) Wild Cosmic+ Crate Ground Runes & Orbiting Crystal Shards
--   3) Lasso Extraction Ground Eruptions (Biome-Themed)
--   4) Pet Merge / Fuse Spiraling Convergence Burst
--   5) Rebirth Golden-Magenta Ascension Pillar

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local GameConfig = require(Config:WaitForChild("GameConfig"))
local AnimalConfig = require(Config:WaitForChild("AnimalConfig"))
local AnimalVisualBuilder = require(Modules:WaitForChild("AnimalVisualBuilder"))
local VoxelPets = require(Modules:WaitForChild("VoxelPets"))
local RarityEffects = require(Modules:WaitForChild("RarityEffects"))
local FormatUtil = require(Modules:WaitForChild("FormatUtil"))

local CinematicVFX = {}

export type BiomeTheme = {
	label: string,
	primary: Color3,
	secondary: Color3,
	shardMat: Enum.Material,
}

export type HatchSequenceParams = {
	baseCF: CFrame,
	rarity: string,
	biomeId: string,
	sizeScale: number?,
	speciesId: string,
	mutation: string?,
	sizeRatio: number?,
	weightKg: number?,
	oddsDenom: number?,
	openerPlayer: Player?,
	isLocalOpener: boolean,
	lowVFX: boolean,
	playerGui: PlayerGui?,
	variant: number?,
	onComplete: (() -> ())?,
}

export type RareRevealInfo = {
	rarity: string,
	biomeId: string,
	speciesId: string,
	mutation: string?,
	sizeRatio: number?,
	weightKg: number?,
	oddsDenom: number?,
}

local BIOME_THEMES: { [string]: BiomeTheme } = {
	PineWoods = {
		label = "Whispering Pine Woods",
		primary = Color3.fromRGB(76, 204, 96),
		secondary = Color3.fromRGB(168, 122, 68),
		shardMat = Enum.Material.SmoothPlastic,
	},
	MangroveSwamp = {
		label = "Muddy Mangrove Swamp",
		primary = Color3.fromRGB(64, 224, 162),
		secondary = Color3.fromRGB(132, 198, 76),
		shardMat = Enum.Material.SmoothPlastic,
	},
	SavannaCamp = {
		label = "Savanna Poacher Camp",
		primary = Color3.fromRGB(246, 186, 64),
		secondary = Color3.fromRGB(204, 118, 54),
		shardMat = Enum.Material.Metal,
	},
	AlpinePeaks = {
		label = "Frostbite Alpine Peaks",
		primary = Color3.fromRGB(118, 224, 255),
		secondary = Color3.fromRGB(182, 148, 255),
		shardMat = Enum.Material.Glass,
	},
	VolcanicJungle = {
		label = "Volcanic Obsidian Jungle",
		primary = Color3.fromRGB(255, 98, 42),
		secondary = Color3.fromRGB(52, 38, 62),
		shardMat = Enum.Material.Basalt,
	},
}

local function getBiomeTheme(biomeId: string): BiomeTheme
	return BIOME_THEMES[biomeId] or BIOME_THEMES.PineWoods
end

local function getVFXFolder(): Folder
	local f = Workspace:FindFirstChild("ClientVFXFolder")
	if f and f:IsA("Folder") then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "ClientVFXFolder"
	created.Parent = Workspace
	return created
end

local function isTooFarForBystander(pos: Vector3, maxDist: number, isLocalOpener: boolean): boolean
	if isLocalOpener then
		return false
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	return (cam.CFrame.Position - pos).Magnitude > maxDist
end

local function makeVfxPart(
	name: string,
	size: Vector3,
	cf: CFrame,
	col: Color3,
	mat: Enum.Material,
	trans: number,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Material = mat
	p.Transparency = trans
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function spawnShockRing(
	pos: Vector3,
	startDiam: number,
	endDiam: number,
	thickness: number,
	col: Color3,
	dur: number,
	tiltAngles: CFrame?
)
	local rotCF = tiltAngles or CFrame.new()
	local baseCF = CFrame.new(pos) * rotCF * CFrame.Angles(0, 0, math.rad(90))
	local ring = makeVfxPart(
		"VFXShockRing",
		Vector3.new(thickness, startDiam, startDiam),
		baseCF,
		col,
		Enum.Material.Glass,
		0.22,
		getVFXFolder()
	)
	ring.Shape = Enum.PartType.Cylinder
	TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(math.max(0.08, thickness * 0.5), endDiam, endDiam),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, dur + 0.08)
end

local function spawnParticleBurst(
	pos: Vector3,
	colA: Color3,
	colB: Color3,
	count: number,
	speedMin: number,
	speedMax: number,
	sizePeak: number,
	lifeMax: number,
	gravityY: number
)
	local holder = makeVfxPart("VFXParticleBurst", Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos), colA, Enum.Material.SmoothPlastic, 1, getVFXFolder())
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colA),
		ColorSequenceKeypoint.new(0.6, colB),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sizePeak * 0.35),
		NumberSequenceKeypoint.new(0.25, sizePeak),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(math.max(0.25, lifeMax * 0.55), lifeMax)
	pe.Speed = NumberRange.new(speedMin, speedMax)
	pe.SpreadAngle = Vector2.new(95, 95)
	pe.Acceleration = Vector3.new(0, gravityY, 0)
	pe.LightEmission = 0.32
	pe.Rate = 0
	pe.Parent = holder
	pe:Emit(count)
	Debris:AddItem(holder, lifeMax + 0.25)
end

local function createOrbWithTrail(name: string, diam: number, colA: Color3, colB: Color3, trailLife: number, parent: Instance): Part
	local orb = makeVfxPart(name, Vector3.new(diam, diam, diam), CFrame.new(), colA, Enum.Material.Glass, 0.15, parent)
	orb.Shape = Enum.PartType.Ball
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, diam * 0.45, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -diam * 0.45, 0)
	a1.Parent = orb

	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = trailLife
	tr.MinLength = 0.08
	tr.LightEmission = 0.34
	tr.Color = ColorSequence.new(colA, colB)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Parent = orb
	return orb
end

local function spawnCometOrbs(center: Vector3, count: number, colA: Color3, colB: Color3, scale: number, dur: number)
	local container = Instance.new("Folder")
	container.Name = "VFXComets"
	container.Parent = getVFXFolder()
	Debris:AddItem(container, dur + 0.5)

	local comets: { { orb: Part, dir: Vector3, upSpeed: number, rotSpeed: number } } = {}
	for i = 1, count do
		local ang = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.35
		local horizSpd = (12 + math.random() * 14) * math.max(0.85, scale * 0.65)
		local col = if i % 2 == 0 then colA else colB
		local orb = createOrbWithTrail("CometOrb_" .. i, 0.48 * math.max(0.8, scale * 0.6), col, Color3.new(1, 1, 1), 0.35, container)
		orb.Position = center
		table.insert(comets, {
			orb = orb,
			dir = Vector3.new(math.cos(ang) * horizSpd, 0, math.sin(ang) * horizSpd),
			upSpeed = (20 + math.random() * 16) * math.max(0.85, scale * 0.65),
			rotSpeed = (math.random() - 0.5) * 6,
		})
	end

	task.spawn(function()
		local t0 = os.clock()
		local g = -42 * math.max(0.85, scale * 0.65)
		while os.clock() - t0 < dur and container.Parent do
			local t = os.clock() - t0
			local alpha = math.clamp(t / dur, 0, 1)
			for _, c in ipairs(comets) do
				local pos = center + c.dir * t + Vector3.new(0, c.upSpeed * t + 0.5 * g * t * t, 0)
				if pos.Y < center.Y - 0.2 then
					pos = Vector3.new(pos.X, center.Y - 0.2, pos.Z)
				end
				c.orb.CFrame = CFrame.new(pos) * CFrame.Angles(0, t * c.rotSpeed, 0)
				c.orb.Transparency = math.clamp(0.15 + alpha * 0.85, 0, 1)
			end
			RunService.RenderStepped:Wait()
		end
		if container.Parent then
			container:Destroy()
		end
	end)
end

local function spawnCrystalMonoliths(
	center: Vector3,
	count: number,
	radiusMin: number,
	radiusMax: number,
	heightBase: number,
	theme: BiomeTheme,
	rarPrimary: Color3,
	rarSec: Color3,
	holdDur: number
)
	local container = Instance.new("Folder")
	container.Name = "VFXMonoliths"
	container.Parent = getVFXFolder()
	Debris:AddItem(container, holdDur + 0.85)

	local rings = if count >= 12 then 2 else 1
	for i = 1, count do
		local ringIdx = if rings == 2 and i > math.floor(count * 0.5) then 2 else 1
		local inRingCount = if rings == 2 then math.ceil(count * 0.5) else count
		local idxInRing = if ringIdx == 1 then i else (i - math.floor(count * 0.5))
		local ang = (idxInRing / inRingCount) * math.pi * 2 + (if ringIdx == 2 then 0.28 else 0)
		local radius = if ringIdx == 1 then radiusMin else radiusMax
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local h = heightBase * (if ringIdx == 1 then 1.05 else 0.78) * (0.85 + (i % 3) * 0.14)
		local w = math.max(0.55, h * 0.19)
		local tilt = math.rad(if ringIdx == 1 then 24 else 38)
		local pos = center + dir * radius

		local finalCF = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-tilt, math.rad((i % 2 == 0) and 45 or 0), 0) * CFrame.new(0, h * 0.42, 0)
		local startCF = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-tilt, 0, 0) * CFrame.new(0, -h * 0.45, 0)
		local isAccent = (i % 2 == 0)
		local col = if isAccent then rarPrimary:Lerp(theme.primary, 0.38) else rarSec:Lerp(theme.secondary, 0.32)
		local mat = if isAccent and theme.shardMat == Enum.Material.Glass then Enum.Material.Glass else theme.shardMat
		local trans = if mat == Enum.Material.Glass then 0.24 else 0.08

		local spike = makeVfxPart("Monolith_" .. i, Vector3.new(w, h, w), startCF, col, mat, trans, container)
		TweenService:Create(spike, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = finalCF,
		}):Play()

		-- Tip crystal accent on alternate monoliths
		if i % 2 == 1 then
			local tip = makeVfxPart("MonolithTip_" .. i, Vector3.new(w * 0.65, h * 0.28, w * 0.65), startCF, rarSec, Enum.Material.Glass, 0.22, container)
			local finalTipCF = finalCF * CFrame.new(0, h * 0.46, 0) * CFrame.Angles(0, math.rad(45), 0)
			TweenService:Create(tip, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = finalTipCF,
			}):Play()
			task.delay(holdDur, function()
				if tip.Parent then
					TweenService:Create(tip, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						CFrame = finalTipCF * CFrame.new(0, -h * 0.6, 0),
						Transparency = 1,
					}):Play()
				end
			end)
		end

		task.delay(holdDur, function()
			if spike.Parent then
				TweenService:Create(spike, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = startCF,
					Transparency = 1,
				}):Play()
			end
		end)
	end
end

local function spawnSkyPillar(center: Vector3, height: number, width: number, colA: Color3, colB: Color3, dur: number, addHelixOrbs: boolean)
	local container = Instance.new("Folder")
	container.Name = "VFXSkyPillar"
	container.Parent = getVFXFolder()
	Debris:AddItem(container, dur + 0.4)

	local baseCF = CFrame.new(center + Vector3.new(0, height * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local outer = makeVfxPart("OuterBeam", Vector3.new(height, width * 2.2, width * 2.2), baseCF, colA, Enum.Material.Glass, 0.36, container)
	outer.Shape = Enum.PartType.Cylinder
	local inner = makeVfxPart("InnerCore", Vector3.new(height + 6, width * 0.85, width * 0.85), baseCF, colB, Enum.Material.Glass, 0.20, container)
	inner.Shape = Enum.PartType.Cylinder

	TweenService:Create(outer, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(height * 1.15, width * 0.4, width * 0.4),
		Transparency = 1,
	}):Play()
	TweenService:Create(inner, TweenInfo.new(dur * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(height * 1.15, width * 0.2, width * 0.2),
		Transparency = 1,
	}):Play()

	if addHelixOrbs then
		local hA = createOrbWithTrail("HelixA", 0.55, colA, Color3.new(1, 1, 1), 0.38, container)
		local hB = createOrbWithTrail("HelixB", 0.55, colB, Color3.new(1, 1, 1), 0.38, container)
		task.spawn(function()
			local t0 = os.clock()
			local helixDur = math.min(0.85, dur * 0.85)
			while os.clock() - t0 < helixDur and container.Parent do
				local a = (os.clock() - t0) / helixDur
				local yOff = a * height * 0.82
				local r = width * (1.5 - a * 0.6)
				local theta = a * math.pi * 6
				hA.Position = center + Vector3.new(math.cos(theta) * r, yOff, math.sin(theta) * r)
				hB.Position = center + Vector3.new(math.cos(theta + math.pi) * r, yOff, math.sin(theta + math.pi) * r)
				hA.Transparency = 0.15 + a * 0.8
				hB.Transparency = 0.15 + a * 0.8
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

local function buildGroundSeal(center: Vector3, radius: number, colA: Color3, colB: Color3, doubleRing: boolean, parent: Instance): { inner: Model, outer: Model? }
	local inner = Instance.new("Model")
	inner.Name = "AstralGroundSeal"
	inner.Parent = parent

	local centerAnchor = makeVfxPart("SealAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(center), colA, Enum.Material.SmoothPlastic, 1, inner)
	inner.PrimaryPart = centerAnchor

	local disc = makeVfxPart(
		"SealDisc",
		Vector3.new(0.08, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		colA,
		Enum.Material.Glass,
		0.48,
		inner
	)
	disc.Shape = Enum.PartType.Cylinder

	-- Octagram crossed rune bars
	for k = 0, 3 do
		local bar = makeVfxPart(
			"SealBar_" .. k,
			Vector3.new(radius * 1.95, 0.10, 0.22),
			CFrame.new(center + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, k * math.pi * 0.25, 0),
			if k % 2 == 0 then colA else colB,
			Enum.Material.SmoothPlastic,
			0.18,
			inner
		)
		bar.Parent = inner
	end

	local outer: Model? = nil
	if doubleRing then
		local outMod = Instance.new("Model")
		outMod.Name = "AstralOuterSeal"
		outMod.Parent = parent
		local outAnchor = makeVfxPart("OuterAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(center), colB, Enum.Material.SmoothPlastic, 1, outMod)
		outMod.PrimaryPart = outAnchor
		local outR = radius * 1.48
		for k = 0, 5 do
			local segAng = (k / 6) * math.pi * 2
			makeVfxPart(
				"OuterNode_" .. k,
				Vector3.new(0.55, 0.18, 0.95),
				CFrame.new(center + Vector3.new(math.cos(segAng) * outR, 0.04, math.sin(segAng) * outR)) * CFrame.Angles(0, -segAng, 0),
				colB,
				Enum.Material.Glass,
				0.26,
				outMod
			)
		end
		outer = outMod
	end

	return { inner = inner, outer = outer }
end

local function spawnShatterDebris(originPos: Vector3, biomeId: string, rarityCol: Color3, scale: number)
	local theme = getBiomeTheme(biomeId)
	local styleMat = if biomeId == "AlpinePeaks"
		then Enum.Material.Ice
		elseif biomeId == "VolcanicJungle" then Enum.Material.Basalt
		elseif biomeId == "SavannaCamp" then Enum.Material.DiamondPlate
		else Enum.Material.WoodPlanks

	local container = Instance.new("Folder")
	container.Name = "HatchShatterDebris"
	container.Parent = getVFXFolder()
	Debris:AddItem(container, 1.0)

	local shards: { { p: Part, vel: Vector3, rot: Vector3, baseSz: Vector3 } } = {}
	for i = 1, 14 do
		local ang = (i / 14) * math.pi * 2 + (math.random() - 0.5) * 0.35
		local spd = 10 + math.random() * 14
		local sx = (0.42 + math.random() * 0.48) * scale
		local sy = (0.26 + math.random() * 0.42) * scale
		local sz = (0.42 + math.random() * 0.48) * scale
		local sh = makeVfxPart(
			"Shard_" .. i,
			Vector3.new(sx, sy, sz),
			CFrame.new(originPos + Vector3.new(math.cos(ang) * 0.55, 0.8 * scale, math.sin(ang) * 0.55)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			if i % 3 == 0 then rarityCol else (if i % 2 == 0 then theme.primary else theme.secondary),
			if i % 3 == 0 then Enum.Material.Glass else styleMat,
			if i % 3 == 0 then 0.2 else 0,
			container
		)
		sh.TopSurface = Enum.SurfaceType.Studs
		table.insert(shards, {
			p = sh,
			vel = Vector3.new(math.cos(ang) * spd, 11 + math.random() * 12, math.sin(ang) * spd),
			rot = Vector3.new((math.random() - 0.5) * 14, (math.random() - 0.5) * 14, (math.random() - 0.5) * 14),
			baseSz = sh.Size,
		})
	end

	task.spawn(function()
		local t0 = os.clock()
		local prev = t0
		while os.clock() - t0 < 0.72 and container.Parent do
			local nowC = os.clock()
			local dt = math.min(0.05, nowC - prev)
			prev = nowC
			local alpha = (nowC - t0) / 0.72
			for _, item in ipairs(shards) do
				item.vel += Vector3.new(0, -48 * dt, 0)
				local p = item.p
				local nextPos = p.Position + item.vel * dt
				if nextPos.Y < originPos.Y + 0.2 then
					nextPos = Vector3.new(nextPos.X, originPos.Y + 0.2, nextPos.Z)
					item.vel = Vector3.new(item.vel.X * 0.65, math.abs(item.vel.Y) * 0.38, item.vel.Z * 0.65)
				end
				p.CFrame = CFrame.new(nextPos) * (p.CFrame - p.CFrame.Position) * CFrame.Angles(item.rot.X * dt, item.rot.Y * dt, item.rot.Z * dt)
				p.Size = item.baseSz * math.max(0.05, 1 - alpha * 0.85)
				p.Transparency = math.clamp(alpha * 1.15 - 0.15, 0, 1)
			end
			RunService.RenderStepped:Wait()
		end
		if container.Parent then
			container:Destroy()
		end
	end)
end

-- ============================================================================
-- FULL-SCREEN ANTI-GLARE RARE HATCH CUTSCENE BANNER (COSMIC+)
-- ============================================================================
function CinematicVFX.PlayRareRevealBanner(playerGui: PlayerGui, info: RareRevealInfo)
	if not playerGui then
		return
	end
	local old = playerGui:FindFirstChild("RareHatchCinematicGui")
	if old then
		old:Destroy()
	end

	local rarity = tostring(info.rarity or "Cosmic")
	local pal = RarityEffects.GetRarityPalette(rarity)
	local theme = getBiomeTheme(tostring(info.biomeId or "PineWoods"))
	local tier = GameConfig.GetRarityTier(rarity)
	local spec = AnimalConfig.GetById(info.speciesId)
	local speciesName = if spec then spec.name else info.speciesId
	local mut = tostring(info.mutation or "None")
	local oddsDenom = info.oddsDenom or GameConfig.ComputePullOddsDenominator(rarity, mut)
	local sRatio = tonumber(info.sizeRatio) or 1.0
	local weightKg = tonumber(info.weightKg) or 5.0
	local incPerSec = AnimalConfig.ComputeIncomePerSec({
		uid = "",
		speciesId = info.speciesId,
		sizeRatio = sRatio,
		weightKg = weightKg,
		mutation = mut :: any,
		locked = false,
		acquiredAt = 0,
	})

	local gui = Instance.new("ScreenGui")
	gui.Name = "RareHatchCinematicGui"
	gui.DisplayOrder = 950
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 22)
	backdrop.BackgroundTransparency = 1
	backdrop.AutoButtonColor = false
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Parent = gui

	local targetBgTrans = if tier >= 11 then 0.28 else 0.44
	TweenService:Create(backdrop, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = targetBgTrans,
	}):Play()

	-- Sleek Top & Bottom Rarity / Biome Trim Bars (no full-screen flash)
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 10)
	topBar.Position = UDim2.fromScale(0, 0.08)
	topBar.BackgroundColor3 = pal.primary
	topBar.BorderSizePixel = 0
	topBar.Parent = backdrop

	local botBar = Instance.new("Frame")
	botBar.Size = UDim2.new(1, 0, 0, 10)
	botBar.Position = UDim2.new(0, 0, 0.92, -10)
	botBar.BackgroundColor3 = theme.primary
	botBar.BorderSizePixel = 0
	botBar.Parent = backdrop

	-- Center Card Frame
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(520, 400)
	card.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Parent = backdrop
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 3.2
	cardStroke.Color = pal.primary
	cardStroke.Parent = card

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.72
	uiScale.Parent = card
	TweenService:Create(uiScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	-- Rotating Sunburst Rays Backdrop
	local rayHolder = Instance.new("Frame")
	rayHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	rayHolder.Position = UDim2.fromScale(0.5, 0.44)
	rayHolder.Size = UDim2.fromOffset(270, 270)
	rayHolder.BackgroundTransparency = 1
	rayHolder.ClipsDescendants = true
	rayHolder.Parent = card
	RarityEffects.ApplyThumbnailBackdrop(rayHolder, rarity, true, mut)
	local rc = rayHolder:FindFirstChildOfClass("UICorner")
	if rc then
		rc.CornerRadius = UDim.new(1, 0)
	else
		local newRc = Instance.new("UICorner")
		newRc.CornerRadius = UDim.new(1, 0)
		newRc.Parent = rayHolder
	end

	-- 3D ViewportFrame showcasing live hatched pet!
	local vp = Instance.new("ViewportFrame")
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.44)
	vp.Size = UDim2.fromOffset(250, 250)
	vp.BackgroundTransparency = 1
	vp.ZIndex = 6
	vp.Parent = card

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = vp
	local vpCam = Instance.new("Camera")
	vpCam.FieldOfView = 36
	vpCam.Parent = vp
	vp.CurrentCamera = vpCam

	local previewPet = AnimalVisualBuilder.BuildAnimalModel(info.speciesId, 1.0, mut :: any, false)
	previewPet:PivotTo(CFrame.new(0, 0, 0))
	previewPet.Parent = worldModel
	local bbCF, bbSz = previewPet:GetBoundingBox()
	local maxDim = math.max(bbSz.X, bbSz.Y, bbSz.Z, 2.2)
	local centerPos = bbCF.Position
	local camDist = maxDim * 1.95

	-- Rarity Header
	local headerLbl = Instance.new("TextLabel")
	headerLbl.Size = UDim2.new(1, -24, 0, 44)
	headerLbl.Position = UDim2.fromOffset(12, 12)
	headerLbl.BackgroundTransparency = 1
	headerLbl.Font = Enum.Font.FredokaOne
	headerLbl.TextScaled = true
	headerLbl.Text = string.format("✦ %s UNBOXED ✦", string.upper(rarity))
	headerLbl.ZIndex = 10
	headerLbl.Parent = card
	local hs = Instance.new("UIStroke")
	hs.Thickness = 3
	hs.Color = Color3.fromRGB(10, 12, 22)
	hs.Parent = headerLbl
	RarityEffects.ApplyTextEffect(headerLbl, rarity)

	-- Odds & Biome Badge
	local oddsBadge = Instance.new("TextLabel")
	oddsBadge.AnchorPoint = Vector2.new(0.5, 0)
	oddsBadge.Position = UDim2.new(0.5, 0, 0, 56)
	oddsBadge.Size = UDim2.fromOffset(420, 24)
	oddsBadge.BackgroundColor3 = theme.primary:Lerp(Color3.fromRGB(18, 22, 36), 0.72)
	oddsBadge.Font = Enum.Font.GothamBold
	oddsBadge.TextSize = 13
	oddsBadge.TextColor3 = theme.primary:Lerp(Color3.new(1, 1, 1), 0.55)
	oddsBadge.Text = string.format("1 IN %s  •  %s", FormatUtil.Number(oddsDenom), string.upper(theme.label))
	oddsBadge.ZIndex = 10
	oddsBadge.Parent = card
	local obCorner = Instance.new("UICorner")
	obCorner.CornerRadius = UDim.new(1, 0)
	obCorner.Parent = oddsBadge
	local obStroke = Instance.new("UIStroke")
	obStroke.Color = theme.primary
	obStroke.Thickness = 1.4
	obStroke.Parent = oddsBadge

	-- Pet Name + Mutation + Income/KG
	local mutPrefix = if mut ~= "None" then ("[" .. mut .. "] ") else ""
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -24, 0, 34)
	nameLbl.Position = UDim2.new(0, 12, 1, -86)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextScaled = true
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.Text = mutPrefix .. speciesName
	nameLbl.ZIndex = 10
	nameLbl.Parent = card
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2.6
	ns.Color = Color3.fromRGB(10, 12, 22)
	ns.Parent = nameLbl

	local statsLbl = Instance.new("TextLabel")
	statsLbl.Size = UDim2.new(1, -24, 0, 24)
	statsLbl.Position = UDim2.new(0, 12, 1, -50)
	statsLbl.BackgroundTransparency = 1
	statsLbl.Font = Enum.Font.GothamBold
	statsLbl.TextSize = 15
	statsLbl.TextColor3 = Color3.fromRGB(112, 255, 146)
	statsLbl.Text = string.format("+$%s/s  •  %.2fx Size  •  %.1f KG", FormatUtil.Number(incPerSec), sRatio, weightKg)
	statsLbl.ZIndex = 10
	statsLbl.Parent = card

	local hintLbl = Instance.new("TextLabel")
	hintLbl.Size = UDim2.new(1, -24, 0, 18)
	hintLbl.Position = UDim2.new(0, 12, 1, -24)
	hintLbl.BackgroundTransparency = 1
	hintLbl.Font = Enum.Font.Gotham
	hintLbl.TextSize = 12
	hintLbl.TextColor3 = Color3.fromRGB(178, 188, 212)
	hintLbl.Text = "Tap anywhere to close"
	hintLbl.ZIndex = 10
	hintLbl.Parent = card

	local isClosing = false
	local startT = os.clock()
	local conn: RBXScriptConnection
	local function closeBanner()
		if isClosing then
			return
		end
		isClosing = true
		if conn then
			conn:Disconnect()
		end
		TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.85,
		}):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.26, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end

	conn = RunService.RenderStepped:Connect(function()
		if not gui.Parent then
			conn:Disconnect()
			return
		end
		local el = os.clock() - startT
		local yaw = el * 1.35
		vpCam.CFrame = CFrame.lookAt(
			centerPos + Vector3.new(math.sin(yaw) * camDist, maxDim * 0.25, -math.cos(yaw) * camDist),
			centerPos
		)
		if previewPet:GetAttribute("VoxelRig") == true then
			VoxelPets.StepRig(previewPet, "Fly", el, 0)
		end
	end)

	backdrop.MouseButton1Click:Connect(closeBanner)
	local autoDur = if tier >= 11 then 3.4 else 2.8
	task.delay(autoDur, closeBanner)
end

-- ============================================================================
-- 1. TIERED CRATE HATCHING SEQUENCE
-- ============================================================================
function CinematicVFX.PlayCrateHatchSequence(params: HatchSequenceParams)
	local baseCF = params.baseCF
	local rarity = tostring(params.rarity or "Common")
	local biomeId = tostring(params.biomeId or "PineWoods")
	local sc = params.sizeScale or GameConfig.ComputeCrateScale(rarity)
	local tier = GameConfig.GetRarityTier(rarity)
	local rarityCol = (GameConfig.RARITY_COLORS :: any)[rarity] or Color3.fromRGB(255, 224, 96)
	local raritySec = (GameConfig.RARITY_SECONDARY_COLORS :: any)[rarity] or rarityCol:Lerp(Color3.new(1, 1, 1), 0.4)
	local theme = getBiomeTheme(biomeId)

	local function finishCallback()
		if params.onComplete then
			params.onComplete()
		end
	end

	if isTooFarForBystander(baseCF.Position, 175, params.isLocalOpener) then
		finishCallback()
		return
	end

	local spec = AnimalConfig.GetById(params.speciesId)
	local variantIdx = params.variant or (if spec then ((spec.indexNumber % 3) + 1) else 1)
	local revealCrate = AnimalVisualBuilder.BuildCrateModel(rarity :: any, biomeId, sc, {
		isBuried = false,
		canCollide = false,
		showBeacon = false,
		variant = variantIdx,
	})
	revealCrate.Name = "ClientHatchAnimCrate"
	revealCrate:PivotTo(baseCF)
	revealCrate.Parent = getVFXFolder()
	Debris:AddItem(revealCrate, 4.5)

	local chargeDur = if tier >= 11 then 1.60 elseif tier >= 7 then 1.20 elseif tier >= 4 then 0.90 else 0.65
	local useHighVFX = (not params.lowVFX) and tier >= 7
	local isApexTier = (not params.lowVFX) and tier >= 11

	local chargeFolder: Folder? = nil
	local sealRefs: { inner: Model, outer: Model? }? = nil
	local chargeOrbs: { Part } = {}
	local vortexEmitterPart: Part? = nil

	if useHighVFX then
		local cfFolder = Instance.new("Folder")
		cfFolder.Name = "HatchChargeVFX"
		cfFolder.Parent = getVFXFolder()
		Debris:AddItem(cfFolder, chargeDur + 1.0)
		chargeFolder = cfFolder

		sealRefs = buildGroundSeal(baseCF.Position + Vector3.new(0, 0.08, 0), 3.6 * sc, rarityCol, theme.primary, isApexTier, cfFolder)
		local orbCount = if isApexTier then 6 else 4
		for i = 1, orbCount do
			local col = if i % 2 == 0 then rarityCol else theme.primary
			local orb = createOrbWithTrail("ChargeOrb_" .. i, 0.42 * math.max(0.85, sc * 0.6), col, raritySec, 0.30, cfFolder)
			orb.Position = baseCF.Position + Vector3.new(0, 1.5 * sc, 0)
			table.insert(chargeOrbs, orb)
		end

		local vPart = makeVfxPart("VortexEmitter", Vector3.new(0.4, 0.4, 0.4), baseCF * CFrame.new(0, 1.8 * sc, 0), rarityCol, Enum.Material.SmoothPlastic, 1, cfFolder)
		vortexEmitterPart = vPart
		local vpe = Instance.new("ParticleEmitter")
		vpe.Rate = if isApexTier then 36 else 22
		vpe.Lifetime = NumberRange.new(0.35, 0.6)
		vpe.Speed = NumberRange.new(-6, -2)
		vpe.SpreadAngle = Vector2.new(180, 180)
		vpe.Color = ColorSequence.new(rarityCol, theme.primary)
		vpe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * sc), NumberSequenceKeypoint.new(1, 0) })
		vpe.LightEmission = 0.30
		vpe.Parent = vPart
	end

	local localHum: Humanoid? = nil
	if isApexTier and params.isLocalOpener and params.openerPlayer and params.openerPlayer.Character then
		local h = params.openerPlayer.Character:FindFirstChildOfClass("Humanoid")
		if h then
			localHum = h
		end
	end

	task.spawn(function()
		-- PHASE 1: Charge / Levitation / Implosion Buildup
		local startT = os.clock()
		local implosionSqueeze = if isApexTier then 0.12 else 0
		while os.clock() - startT < chargeDur do
			local el = os.clock() - startT
			local alpha = math.clamp(el / chargeDur, 0, 1)
			local inSqueeze = isApexTier and (chargeDur - el) <= implosionSqueeze
			local freq = 18 + alpha * 46
			local amp = 0.08 + alpha * 0.25
			local levitate = if tier >= 7 then (alpha * 1.45 * sc) else 0
			local hop = math.abs(math.sin(el * 13)) * (0.28 + alpha * 0.72) + levitate
			local tilt = math.sin(el * freq) * amp

			if revealCrate.Parent then
				revealCrate:PivotTo(baseCF * CFrame.new(0, hop, 0) * CFrame.Angles(tilt, alpha * (if tier >= 7 then 4.2 else 2.2), -tilt * 0.8))
				local targetCrateScale = if inSqueeze
					then math.max(0.28, 1.0 - ((implosionSqueeze - (chargeDur - el)) / implosionSqueeze) * 0.72)
					else (1 + math.sin(el * 22) * 0.1)
				pcall(function()
					revealCrate:ScaleTo(targetCrateScale)
				end)
			end

			if sealRefs and sealRefs.inner.PrimaryPart then
				local centerCF = CFrame.new(baseCF.Position + Vector3.new(0, 0.08, 0))
				sealRefs.inner:PivotTo(centerCF * CFrame.Angles(0, el * (1.8 + alpha * 4.5), 0))
				if sealRefs.outer and sealRefs.outer.PrimaryPart then
					sealRefs.outer:PivotTo(centerCF * CFrame.Angles(0, -el * (1.4 + alpha * 3.8), 0))
				end
			end

			if #chargeOrbs > 0 then
				local orbCount = #chargeOrbs
				local orbitR = (4.8 * sc) * (1 - alpha * (if inSqueeze then 0.90 else 0.52))
				local orbitY = baseCF.Position.Y + 1.4 * sc + alpha * 1.8 * sc
				for i, orb in ipairs(chargeOrbs) do
					local ang = (i / orbCount) * math.pi * 2 + el * (4.5 + alpha * 8.0)
					orb.Position = Vector3.new(baseCF.Position.X + math.cos(ang) * orbitR, orbitY + math.sin(el * 5 + i) * 0.65 * sc, baseCF.Position.Z + math.sin(ang) * orbitR)
				end
			end

			if vortexEmitterPart and vortexEmitterPart.Parent then
				vortexEmitterPart.Position = baseCF.Position + Vector3.new(0, 1.6 * sc + levitate, 0)
			end

			if localHum and localHum.Parent then
				local shake = 0.15 * alpha
				localHum.CameraOffset = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
			end

			RunService.RenderStepped:Wait()
		end

		if localHum and localHum.Parent then
			localHum.CameraOffset = Vector3.zero
		end
		if chargeFolder and chargeFolder.Parent then
			chargeFolder:Destroy()
		end
		if revealCrate.Parent then
			revealCrate:Destroy()
		end

		-- PHASE 2: Tiered Detonation!
		local detOrigin = baseCF.Position
		spawnShatterDebris(detOrigin, biomeId, rarityCol, sc)

		if tier >= 11 then
			-- Infinity .. Primordial (e.g. Singularity in Biome D!)
			spawnSkyPillar(detOrigin, 58, 1.6 * sc, rarityCol, theme.primary, 1.15, true)
			spawnCrystalMonoliths(detOrigin, 16, 4.4 * sc, 7.6 * sc, 7.2 * sc, theme, rarityCol, raritySec, 1.35)
			spawnShockRing(detOrigin + Vector3.new(0, 0.9 * sc, 0), 2 * sc, 28 * sc, 0.35, rarityCol, 0.68)
			spawnShockRing(detOrigin + Vector3.new(0, 2.2 * sc, 0), 2 * sc, 20 * sc, 0.28, theme.primary, 0.58, CFrame.Angles(math.rad(35), 0.4, 0))
			spawnShockRing(detOrigin + Vector3.new(0, 2.2 * sc, 0), 2 * sc, 20 * sc, 0.28, raritySec, 0.58, CFrame.Angles(math.rad(-35), -0.4, 0))
			spawnCometOrbs(detOrigin + Vector3.new(0, 1.8 * sc, 0), 16, rarityCol, theme.primary, sc, 0.85)
			spawnParticleBurst(detOrigin + Vector3.new(0, 1.8 * sc, 0), rarityCol, theme.primary, 65, 16, 36, 1.2 * sc, 1.0, -22)

			if params.isLocalOpener and not params.lowVFX and params.playerGui then
				CinematicVFX.PlayRareRevealBanner(params.playerGui, {
					rarity = rarity,
					biomeId = biomeId,
					speciesId = params.speciesId,
					mutation = params.mutation,
					sizeRatio = params.sizeRatio,
					weightKg = params.weightKg,
					oddsDenom = params.oddsDenom,
				})
			end
		elseif tier >= 7 then
			-- Cosmic .. Divine
			spawnSkyPillar(detOrigin, 38, 1.15 * sc, rarityCol, theme.primary, 0.85, false)
			spawnCrystalMonoliths(detOrigin, 12, 3.8 * sc, 5.8 * sc, 5.0 * sc, theme, rarityCol, raritySec, 1.05)
			spawnShockRing(detOrigin + Vector3.new(0, 0.9 * sc, 0), 2 * sc, 21 * sc, 0.30, rarityCol, 0.56)
			spawnShockRing(detOrigin + Vector3.new(0, 1.6 * sc, 0), 2 * sc, 15 * sc, 0.24, theme.primary, 0.48)
			spawnShockRing(detOrigin + Vector3.new(0, 2.4 * sc, 0), 1.5 * sc, 11 * sc, 0.20, raritySec, 0.40)
			spawnCometOrbs(detOrigin + Vector3.new(0, 1.5 * sc, 0), 10, rarityCol, theme.primary, sc, 0.70)
			spawnParticleBurst(detOrigin + Vector3.new(0, 1.5 * sc, 0), rarityCol, theme.primary, 52, 14, 28, 1.05 * sc, 0.9, -20)

			if params.isLocalOpener and not params.lowVFX and params.playerGui then
				CinematicVFX.PlayRareRevealBanner(params.playerGui, {
					rarity = rarity,
					biomeId = biomeId,
					speciesId = params.speciesId,
					mutation = params.mutation,
					sizeRatio = params.sizeRatio,
					weightKg = params.weightKg,
					oddsDenom = params.oddsDenom,
				})
			end
		elseif tier >= 4 then
			-- Epic .. Mythic
			spawnCrystalMonoliths(detOrigin, 8, 3.2 * sc, 3.2 * sc, 3.2 * sc, theme, rarityCol, raritySec, 0.72)
			spawnShockRing(detOrigin + Vector3.new(0, 0.9 * sc, 0), 2 * sc, 16 * sc, 0.25, rarityCol, 0.46)
			spawnShockRing(detOrigin + Vector3.new(0, 1.4 * sc, 0), 1.5 * sc, 11 * sc, 0.20, theme.primary, 0.38)
			spawnParticleBurst(detOrigin + Vector3.new(0, 1.4 * sc, 0), rarityCol, theme.primary, 42, 12, 24, 0.95 * sc, 0.85, -18)
		else
			-- Common .. Rare
			spawnShockRing(detOrigin + Vector3.new(0, 1.0 * sc, 0), 2 * sc, 13 * sc, 0.22, rarityCol, 0.42)
			spawnParticleBurst(detOrigin + Vector3.new(0, 1.2 * sc, 0), rarityCol, Color3.new(1, 1, 1), 24, 10, 20, 0.85 * sc, 0.75, -18)
		end

		-- PHASE 3: Hatched Pet Erupts & Swoops Toward Opener
		local petScale = math.clamp((tonumber(params.sizeRatio) or 1.0) * 0.92, 0.85, 1.8)
		local animPet = AnimalVisualBuilder.BuildAnimalModel(params.speciesId, petScale, (params.mutation or "None") :: any, false)
		animPet.Name = "ClientHatchLeapAnimal"
		local originPos = (baseCF * CFrame.new(0, 1.8 * sc, 0)).Position
		animPet:PivotTo(CFrame.new(originPos))
		animPet.Parent = getVFXFolder()
		Debris:AddItem(animPet, 3.5)

		local pRoot = animPet.PrimaryPart
		if pRoot then
			local inc = AnimalConfig.ComputeIncomePerSec({
				uid = "",
				speciesId = params.speciesId,
				sizeRatio = tonumber(params.sizeRatio) or 1.0,
				weightKg = tonumber(params.weightKg) or 5.0,
				mutation = (params.mutation or "None") :: any,
				locked = false,
				acquiredAt = 0,
			})
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(200, 62)
			bb.StudsOffset = Vector3.new(0, 3.8 * petScale + 1.2, 0)
			bb.AlwaysOnTop = true
			bb.Parent = pRoot

			local topTxt = Instance.new("TextLabel")
			topTxt.Size = UDim2.fromScale(1, 0.54)
			topTxt.BackgroundTransparency = 1
			topTxt.Text = "$" .. FormatUtil.Number(inc) .. "/s"
			topTxt.TextColor3 = Color3.fromRGB(108, 255, 128)
			topTxt.Font = Enum.Font.FredokaOne
			topTxt.TextScaled = true
			topTxt.Parent = bb
			local ts = Instance.new("UIStroke")
			ts.Thickness = 2.8
			ts.Color = Color3.fromRGB(10, 12, 16)
			ts.Parent = topTxt

			local subTxt = Instance.new("TextLabel")
			subTxt.Size = UDim2.fromScale(1, 0.44)
			subTxt.Position = UDim2.fromScale(0, 0.54)
			subTxt.BackgroundTransparency = 1
			subTxt.Text = rarity
			subTxt.Font = Enum.Font.FredokaOne
			subTxt.TextScaled = true
			subTxt.Parent = bb
			local ss = Instance.new("UIStroke")
			ss.Thickness = 2.6
			ss.Color = Color3.fromRGB(10, 12, 16)
			ss.Parent = subTxt
			RarityEffects.ApplyTextEffect(subTxt, rarity)
		end

		local popDur = if tier >= 11 then 1.25 elseif tier >= 7 then 0.85 else 0.45
		local popStart = os.clock()
		local hoverPos = originPos + Vector3.new(0, 4.4, 0)
		local isVoxel = (animPet:GetAttribute("VoxelRig") == true)

		while os.clock() - popStart < popDur and animPet.Parent do
			local el = os.clock() - popStart
			local a = math.clamp(el / popDur, 0, 1)
			local easeOut = 1 - math.pow(1 - a, 3)
			local openerChar = if params.openerPlayer then params.openerPlayer.Character else nil
			local oRoot = if openerChar then openerChar:FindFirstChild("HumanoidRootPart") else nil
			local cam = Workspace.CurrentCamera
			local viewerPos = if oRoot and oRoot:IsA("BasePart")
				then oRoot.Position
				elseif cam then cam.CFrame.Position
				else (originPos + Vector3.new(0, 4, -12))

			local curPos = originPos:Lerp(hoverPos, math.min(1, easeOut * 1.4)) + Vector3.new(0, math.sin(el * 3.5) * 0.25, 0)
			local lookPt = Vector3.new(viewerPos.X, curPos.Y, viewerPos.Z)
			local faceCF = if (lookPt - curPos).Magnitude > 0.1 then CFrame.lookAt(curPos, lookPt) else CFrame.new(curPos)
			animPet:PivotTo(faceCF)
			pcall(function()
				animPet:ScaleTo(0.35 + math.min(1, easeOut * 1.4) * 0.95)
			end)
			if isVoxel then
				VoxelPets.StepRig(animPet, "Fly", el, 0)
			end
			RunService.RenderStepped:Wait()
		end

		local openerCharNow = if params.openerPlayer then params.openerPlayer.Character else nil
		local hasCharTarget = openerCharNow ~= nil and openerCharNow:FindFirstChild("HumanoidRootPart") ~= nil
		local leapDur = 0.50
		local leapStart = os.clock()
		while os.clock() - leapStart < leapDur and animPet.Parent do
			local el = os.clock() - leapStart
			local a = math.clamp(el / leapDur, 0, 1)
			local ch = if params.openerPlayer then params.openerPlayer.Character else nil
			local rPart = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
			local targetPos = if rPart and rPart:IsA("BasePart")
				then (rPart.Position + Vector3.new(0, 0.5, 0))
				else (hoverPos + Vector3.new(0, 3.5, 0))
			local arcY = math.sin(a * math.pi) * (if hasCharTarget then 4.5 else 1.5)
			local curPos = hoverPos:Lerp(targetPos, a * a) + Vector3.new(0, arcY, 0)
			local lookTarget = Vector3.new(targetPos.X, curPos.Y, targetPos.Z)
			local lookCF = if (lookTarget - curPos).Magnitude > 0.1 then CFrame.lookAt(curPos, lookTarget) else CFrame.new(curPos)
			animPet:PivotTo(lookCF)
			pcall(function()
				animPet:ScaleTo(math.max(0.18, 1.3 - a * 1.12))
			end)
			if isVoxel then
				VoxelPets.StepRig(animPet, "Fly", el, 0)
			end
			RunService.RenderStepped:Wait()
		end

		local charEnd = if params.openerPlayer then params.openerPlayer.Character else nil
		local rootEnd = if charEnd then charEnd:FindFirstChild("HumanoidRootPart") else nil
		if rootEnd and rootEnd:IsA("BasePart") then
			spawnShockRing(rootEnd.Position, 1.5, 6.2, 0.25, rarityCol, 0.28)
		end

		if animPet.Parent then
			animPet:Destroy()
		end
		finishCallback()
	end)
end

-- ============================================================================
-- 2. LASSO EXTRACTION BIOME ERUPTION
-- ============================================================================
function CinematicVFX.PlayLassoExtractBurst(worldPos: Vector3, rarity: string, biomeId: string, scale: number, lowVFX: boolean)
	if isTooFarForBystander(worldPos, 175, false) then
		return
	end
	local sc = math.clamp(scale or 1.0, 0.65, 3.0)
	local tier = GameConfig.GetRarityTier(rarity)
	local rarCol = (GameConfig.RARITY_COLORS :: any)[rarity] or Color3.fromRGB(108, 255, 132)
	local rarSec = (GameConfig.RARITY_SECONDARY_COLORS :: any)[rarity] or rarCol
	local theme = getBiomeTheme(biomeId)

	spawnShockRing(worldPos + Vector3.new(0, 0.35, 0), 1.5 * sc, (if tier >= 7 then 16 else 10) * sc, 0.24, theme.primary, 0.42)
	spawnParticleBurst(worldPos + Vector3.new(0, 0.9 * sc, 0), theme.primary, rarCol, if lowVFX then 12 else 28, 10, 22, 0.78 * sc, 0.72, -24)

	if not lowVFX and tier >= 7 then
		spawnCrystalMonoliths(worldPos, 6, 2.8 * sc, 2.8 * sc, 3.4 * sc, theme, rarCol, rarSec, 0.65)
	end
end

-- ============================================================================
-- 3. PET MERGE / FUSE SPIRALING CONVERGENCE BURST
-- ============================================================================
function CinematicVFX.PlayMergeBurst(targetPosOrChar: Vector3 | Model, rarity: string, mutation: string, scale: number, lowVFX: boolean)
	local function resolveCenter(): Vector3
		if typeof(targetPosOrChar) == "Vector3" then
			return targetPosOrChar
		end
		local hrp = targetPosOrChar:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp.Position + hrp.CFrame.LookVector * 2.4 + Vector3.new(0, 1.0, 0)
		end
		return Vector3.new(0, 3, 0)
	end

	local initialCenter = resolveCenter()
	if isTooFarForBystander(initialCenter, 175, targetPosOrChar == Players.LocalPlayer.Character) then
		return
	end

	local sc = math.clamp(scale or 1.1, 0.7, 2.6)
	local rarCol = (GameConfig.RARITY_COLORS :: any)[rarity] or Color3.fromRGB(118, 212, 255)
	local mutInfo = (GameConfig.MUTATIONS :: any)[mutation]
	local mutCol = if mutInfo and mutInfo.color then mutInfo.color else rarCol

	if lowVFX then
		spawnShockRing(initialCenter, 1.5, 9.5 * sc, 0.25, mutCol, 0.42)
		spawnParticleBurst(initialCenter, rarCol, mutCol, 16, 8, 18, 0.65, 0.65, -12)
		return
	end

	local container = Instance.new("Folder")
	container.Name = "MergeSpiralOrbs"
	container.Parent = getVFXFolder()
	Debris:AddItem(container, 1.0)

	local orbs: { Part } = {}
	for i = 1, 3 do
		local c = if i == 1 then rarCol elseif i == 2 then mutCol else Color3.fromRGB(255, 224, 96)
		table.insert(orbs, createOrbWithTrail("MergeSpirit_" .. i, 0.45 * math.max(0.8, sc * 0.65), c, Color3.new(1, 1, 1), 0.28, container))
	end

	task.spawn(function()
		local dur = 0.42
		local t0 = os.clock()
		while os.clock() - t0 < dur and container.Parent do
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local center = resolveCenter()
			local r = 4.6 * (1 - a * a)
			for i, orb in ipairs(orbs) do
				local ang = (i / 3) * math.pi * 2 + a * math.pi * 3.8
				orb.Position = center + Vector3.new(math.cos(ang) * r, math.sin(a * math.pi) * 1.4, math.sin(ang) * r)
			end
			RunService.RenderStepped:Wait()
		end
		if container.Parent then
			container:Destroy()
		end
		local burstPos = resolveCenter()
		spawnShockRing(burstPos, 1.4, 12.5 * sc, 0.26, mutCol, 0.46)
		spawnShockRing(burstPos, 1.0, 9.0 * sc, 0.22, rarCol, 0.36, CFrame.Angles(math.rad(30), 0, math.rad(20)))
		spawnParticleBurst(burstPos, rarCol, mutCol, 36, 10, 24, 0.85 * sc, 0.80, -14)
	end)
end

-- ============================================================================
-- 4. REBIRTH GOLDEN-MAGENTA ASCENSION PILLAR
-- ============================================================================
function CinematicVFX.PlayRebirthAscension(character: Model, _rebirths: number, lowVFX: boolean)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local pos = hrp.Position - Vector3.new(0, 2.2, 0)
	if isTooFarForBystander(pos, 195, character == Players.LocalPlayer.Character) then
		return
	end

	local cMagenta = Color3.fromRGB(255, 92, 188)
	local cGold = Color3.fromRGB(255, 214, 72)

	spawnShockRing(pos + Vector3.new(0, 0.4, 0), 2.5, 22, 0.32, cGold, 0.65)
	spawnShockRing(pos + Vector3.new(0, 1.2, 0), 2.0, 15, 0.25, cMagenta, 0.55)
	spawnParticleBurst(pos + Vector3.new(0, 2.2, 0), cGold, cMagenta, if lowVFX then 18 else 50, 12, 28, 0.95, 1.0, -8)

	if not lowVFX then
		spawnSkyPillar(pos, 48, 1.85, cGold, cMagenta, 1.10, true)
	end
end

-- ============================================================================
-- 5. WILD COSMIC+ CRATE AMBIENT GROUND RUNES & ORBITING SHARDS
-- ============================================================================
type WildAuraEntry = {
	crate: Model,
	anchor: BasePart,
	seal: Model,
	shards: { Part },
	isApex: boolean,
	pos: Vector3,
}

local wildAurasBound = false
local wildAuras: { WildAuraEntry } = {}
local activeAurasByCrate: { [Model]: WildAuraEntry } = {}

function CinematicVFX.BindWildCrateAuras(isLowVFXFn: () -> boolean)
	if wildAurasBound then
		return
	end
	wildAurasBound = true

	local function detachCrate(crate: Model)
		local existing = activeAurasByCrate[crate]
		if existing then
			if existing.seal.Parent then
				existing.seal:Destroy()
			end
			activeAurasByCrate[crate] = nil
		end
	end

	local function tryAttachCrate(inst: Instance)
		if not inst:IsA("Model") then
			return
		end
		if activeAurasByCrate[inst] then
			return
		end
		local rarity = inst:GetAttribute("Rarity")
		if typeof(rarity) ~= "string" or not GameConfig.IsCosmicOrAbove(rarity) then
			return
		end
		local root = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
		if not root then
			return
		end
		local sc = tonumber(inst:GetAttribute("SizeScale")) or 1.6
		local biomeId = tostring(inst:GetAttribute("BiomeId") or "PineWoods")
		local theme = getBiomeTheme(biomeId)
		local rarCol = (GameConfig.RARITY_COLORS :: any)[rarity] or Color3.fromRGB(168, 92, 255)
		local tier = GameConfig.GetRarityTier(rarity)
		local isApex = tier >= 11

		local basePos = Vector3.new(root.Position.X, math.max(0.2, root.Position.Y - 1.4 * sc), root.Position.Z)
		local auraFolder = Instance.new("Model")
		auraFolder.Name = "WildCosmicAura"
		auraFolder.Parent = inst

		local sealRefs = buildGroundSeal(basePos + Vector3.new(0, 0.12, 0), 3.1 * sc, rarCol, theme.primary, isApex, auraFolder)
		local shardCount = if isApex then 4 else 2
		local shards: { Part } = {}
		for i = 1, shardCount do
			local sh = makeVfxPart(
				"WildShard_" .. i,
				Vector3.new(0.38 * math.max(0.8, sc * 0.55), 0.72 * math.max(0.8, sc * 0.55), 0.38 * math.max(0.8, sc * 0.55)),
				CFrame.new(basePos),
				if i % 2 == 0 then rarCol else theme.primary,
				theme.shardMat,
				0.18,
				auraFolder
			)
			table.insert(shards, sh)
		end

		if isApex then
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "WildApexMotes"
			pe.Rate = 8
			pe.Lifetime = NumberRange.new(1.0, 1.8)
			pe.Speed = NumberRange.new(1.2, 2.8)
			pe.SpreadAngle = Vector2.new(35, 35)
			pe.LightEmission = 0.28
			pe.Color = ColorSequence.new(rarCol, theme.primary)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.30 * sc), NumberSequenceKeypoint.new(1, 0) })
			pe.Parent = root
		end

		local entry: WildAuraEntry = {
			crate = inst,
			anchor = root,
			seal = auraFolder,
			shards = shards,
			isApex = isApex,
			pos = basePos,
		}
		activeAurasByCrate[inst] = entry
		table.insert(wildAuras, entry)
	end

	task.spawn(function()
		local gw = Workspace:WaitForChild("GameWorld", 20)
		if not gw then
			return
		end
		local activeCrates = gw:WaitForChild("ActiveCrates", 20)
		if not activeCrates then
			return
		end
		for _, ch in ipairs(activeCrates:GetChildren()) do
			tryAttachCrate(ch)
		end
		activeCrates.ChildAdded:Connect(function(ch)
			task.defer(function()
				tryAttachCrate(ch)
			end)
		end)
		activeCrates.ChildRemoved:Connect(function(ch)
			if ch:IsA("Model") then
				detachCrate(ch)
			end
		end)
	end)

	RunService.Heartbeat:Connect(function()
		local lowVFX = isLowVFXFn()
		local cam = Workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else nil
		local now = os.clock()

		for i = #wildAuras, 1, -1 do
			local entry = wildAuras[i]
			if not entry.crate.Parent or not entry.anchor.Parent then
				if entry.seal.Parent then
					entry.seal:Destroy()
				end
				activeAurasByCrate[entry.crate] = nil
				table.remove(wildAuras, i)
			else
				local visible = not lowVFX and (camPos == nil or (camPos - entry.anchor.Position).Magnitude <= 165)
				if not visible then
					continue
				end
				local sc = tonumber(entry.crate:GetAttribute("SizeScale")) or 1.6
				local basePos = Vector3.new(entry.anchor.Position.X, math.max(0.2, entry.anchor.Position.Y - 1.45 * sc), entry.anchor.Position.Z)
				local innerSeal = entry.seal:FindFirstChild("AstralGroundSeal")
				if innerSeal and innerSeal:IsA("Model") and innerSeal.PrimaryPart then
					innerSeal:PivotTo(CFrame.new(basePos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, now * 0.9, 0))
				end
				local outerSeal = entry.seal:FindFirstChild("AstralOuterSeal")
				if outerSeal and outerSeal:IsA("Model") and outerSeal.PrimaryPart then
					outerSeal:PivotTo(CFrame.new(basePos + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, -now * 0.7, 0))
				end
				local r = 2.6 * sc
				for j, sh in ipairs(entry.shards) do
					local ang = (j / #entry.shards) * math.pi * 2 + now * (if entry.isApex then 1.8 else 1.2)
					local bob = math.sin(now * 2.4 + j) * 0.45
					sh.CFrame = CFrame.new(basePos + Vector3.new(math.cos(ang) * r, 1.5 * sc + bob, math.sin(ang) * r))
						* CFrame.Angles(math.rad(22), -ang, math.rad(14))
				end
			end
		end
	end)
end

return CinematicVFX
