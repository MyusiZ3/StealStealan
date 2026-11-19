--!strict
-- VoxelTreadmillBuilder.luau
-- Builds 12 unique, progressive 3D voxel treadmill models (LV 1 Basic -> LV 12 Primordial)
-- using pure Roblox Block Parts (SmoothPlastic, Metal, Neon) with animated belt segments
-- and LV 8-12 SpecialEffects (zero external asset IDs).

local VoxelTreadmillBuilder = {}

export type TreadmillDef = {
	level: number,
	tier: string,
	modelName: string,
	frameDark: Color3,
	frameMid: Color3,
	accent: Color3,
	neonCol: Color3,
	neonSec: Color3,
	beltBaseCol: Color3,
	slatCol: Color3,
	chevronCol: Color3,
	hasNeon: boolean,
}

local DEFS: { TreadmillDef } = {
	{
		level = 1,
		tier = "Basic",
		modelName = "Treadmill_LV01_Basic",
		frameDark = Color3.fromRGB(48, 52, 58),
		frameMid = Color3.fromRGB(122, 128, 138),
		accent = Color3.fromRGB(168, 174, 184),
		neonCol = Color3.fromRGB(168, 174, 184),
		neonSec = Color3.fromRGB(210, 214, 222),
		beltBaseCol = Color3.fromRGB(28, 30, 34),
		slatCol = Color3.fromRGB(38, 42, 48),
		chevronCol = Color3.fromRGB(145, 152, 162),
		hasNeon = false,
	},
	{
		level = 2,
		tier = "Standard",
		modelName = "Treadmill_LV02_Standard",
		frameDark = Color3.fromRGB(42, 48, 58),
		frameMid = Color3.fromRGB(108, 120, 138),
		accent = Color3.fromRGB(42, 132, 224),
		neonCol = Color3.fromRGB(54, 212, 255),
		neonSec = Color3.fromRGB(148, 238, 255),
		beltBaseCol = Color3.fromRGB(24, 28, 36),
		slatCol = Color3.fromRGB(34, 40, 50),
		chevronCol = Color3.fromRGB(54, 212, 255),
		hasNeon = true,
	},
	{
		level = 3,
		tier = "Uncommon",
		modelName = "Treadmill_LV03_Uncommon",
		frameDark = Color3.fromRGB(24, 28, 28),
		frameMid = Color3.fromRGB(48, 58, 52),
		accent = Color3.fromRGB(46, 186, 78),
		neonCol = Color3.fromRGB(64, 248, 96),
		neonSec = Color3.fromRGB(162, 255, 148),
		beltBaseCol = Color3.fromRGB(20, 24, 24),
		slatCol = Color3.fromRGB(30, 36, 34),
		chevronCol = Color3.fromRGB(64, 248, 96),
		hasNeon = true,
	},
	{
		level = 4,
		tier = "Rare",
		modelName = "Treadmill_LV04_Rare",
		frameDark = Color3.fromRGB(20, 26, 44),
		frameMid = Color3.fromRGB(38, 56, 94),
		accent = Color3.fromRGB(48, 142, 255),
		neonCol = Color3.fromRGB(68, 198, 255),
		neonSec = Color3.fromRGB(182, 238, 255),
		beltBaseCol = Color3.fromRGB(18, 22, 34),
		slatCol = Color3.fromRGB(28, 36, 54),
		chevronCol = Color3.fromRGB(68, 198, 255),
		hasNeon = true,
	},
	{
		level = 5,
		tier = "Epic",
		modelName = "Treadmill_LV05_Epic",
		frameDark = Color3.fromRGB(24, 18, 34),
		frameMid = Color3.fromRGB(54, 38, 78),
		accent = Color3.fromRGB(152, 64, 232),
		neonCol = Color3.fromRGB(194, 78, 255),
		neonSec = Color3.fromRGB(232, 164, 255),
		beltBaseCol = Color3.fromRGB(20, 16, 28),
		slatCol = Color3.fromRGB(32, 24, 46),
		chevronCol = Color3.fromRGB(194, 78, 255),
		hasNeon = true,
	},
	{
		level = 6,
		tier = "Legendary",
		modelName = "Treadmill_LV06_Legendary",
		frameDark = Color3.fromRGB(28, 24, 20),
		frameMid = Color3.fromRGB(68, 54, 32),
		accent = Color3.fromRGB(238, 182, 46),
		neonCol = Color3.fromRGB(255, 208, 62),
		neonSec = Color3.fromRGB(255, 242, 156),
		beltBaseCol = Color3.fromRGB(24, 20, 18),
		slatCol = Color3.fromRGB(38, 32, 26),
		chevronCol = Color3.fromRGB(255, 208, 62),
		hasNeon = true,
	},
	{
		level = 7,
		tier = "Mythic",
		modelName = "Treadmill_LV07_Mythic",
		frameDark = Color3.fromRGB(26, 16, 18),
		frameMid = Color3.fromRGB(78, 22, 28),
		accent = Color3.fromRGB(218, 36, 48),
		neonCol = Color3.fromRGB(255, 48, 64),
		neonSec = Color3.fromRGB(255, 148, 132),
		beltBaseCol = Color3.fromRGB(22, 14, 16),
		slatCol = Color3.fromRGB(36, 20, 24),
		chevronCol = Color3.fromRGB(255, 58, 74),
		hasNeon = true,
	},
	{
		level = 8,
		tier = "Cosmic",
		modelName = "Treadmill_LV08_Cosmic",
		frameDark = Color3.fromRGB(20, 18, 38),
		frameMid = Color3.fromRGB(54, 42, 108),
		accent = Color3.fromRGB(98, 118, 255),
		neonCol = Color3.fromRGB(188, 78, 255),
		neonSec = Color3.fromRGB(68, 224, 255),
		beltBaseCol = Color3.fromRGB(16, 14, 30),
		slatCol = Color3.fromRGB(28, 24, 52),
		chevronCol = Color3.fromRGB(192, 86, 255),
		hasNeon = true,
	},
	{
		level = 9,
		tier = "Divine",
		modelName = "Treadmill_LV09_Divine",
		frameDark = Color3.fromRGB(234, 238, 244),
		frameMid = Color3.fromRGB(208, 214, 224),
		accent = Color3.fromRGB(246, 196, 52),
		neonCol = Color3.fromRGB(255, 224, 78),
		neonSec = Color3.fromRGB(255, 255, 235),
		beltBaseCol = Color3.fromRGB(38, 36, 42),
		slatCol = Color3.fromRGB(52, 48, 56),
		chevronCol = Color3.fromRGB(255, 224, 78),
		hasNeon = true,
	},
	{
		level = 10,
		tier = "Infinity",
		modelName = "Treadmill_LV10_Infinity",
		frameDark = Color3.fromRGB(18, 32, 68),
		frameMid = Color3.fromRGB(34, 86, 168),
		accent = Color3.fromRGB(244, 192, 48),
		neonCol = Color3.fromRGB(58, 228, 255),
		neonSec = Color3.fromRGB(255, 214, 78),
		beltBaseCol = Color3.fromRGB(14, 24, 48),
		slatCol = Color3.fromRGB(24, 42, 78),
		chevronCol = Color3.fromRGB(58, 228, 255),
		hasNeon = true,
	},
	{
		level = 11,
		tier = "Singularity",
		modelName = "Treadmill_LV11_Singularity",
		frameDark = Color3.fromRGB(16, 12, 24),
		frameMid = Color3.fromRGB(46, 24, 74),
		accent = Color3.fromRGB(146, 48, 238),
		neonCol = Color3.fromRGB(178, 54, 255),
		neonSec = Color3.fromRGB(255, 84, 224),
		beltBaseCol = Color3.fromRGB(12, 10, 18),
		slatCol = Color3.fromRGB(26, 18, 42),
		chevronCol = Color3.fromRGB(178, 54, 255),
		hasNeon = true,
	},
	{
		level = 12,
		tier = "Primordial",
		modelName = "Treadmill_LV12_Primordial",
		frameDark = Color3.fromRGB(18, 14, 16),
		frameMid = Color3.fromRGB(68, 20, 22),
		accent = Color3.fromRGB(236, 168, 48),
		neonCol = Color3.fromRGB(255, 42, 42),
		neonSec = Color3.fromRGB(255, 164, 48),
		beltBaseCol = Color3.fromRGB(16, 12, 14),
		slatCol = Color3.fromRGB(32, 18, 20),
		chevronCol = Color3.fromRGB(255, 58, 42),
		hasNeon = true,
	},
}

VoxelTreadmillBuilder.DEFS = DEFS

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findVFXTemplate(pathParts: { string }): Instance?
	for _, root in ipairs({ Workspace, ReplicatedStorage:FindFirstChild("TreadmillVFXAssets") }) do
		if root then
			local cur: Instance? = root
			for _, part in ipairs(pathParts) do
				cur = if cur then cur:FindFirstChild(part) else nil
				if not cur then
					break
				end
			end
			if cur then
				return cur
			end
		end
	end
	return nil
end

local function scaleNumberSequence(ns: NumberSequence, mult: number): NumberSequence
	local kps = {}
	for _, kp in ipairs(ns.Keypoints) do
		table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * mult, kp.Envelope * mult))
	end
	return NumberSequence.new(kps)
end

local function cloneAssetVFX(
	targetHost: Instance,
	pathParts: { string },
	sizeScale: number?,
	maxRate: number?,
	tintCol: ColorSequence?
): number
	local tpl = findVFXTemplate(pathParts)
	if not tpl then
		return 0
	end
	local sScale = sizeScale or 0.45
	local rCap = maxRate or 14
	local cloned = 0
	for _, desc in ipairs(tpl:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			local pe = desc:Clone()
			pe.Enabled = true
			pe.Rate = math.clamp(pe.Rate * 0.45, 2, rCap)
			pe.Size = scaleNumberSequence(pe.Size, sScale)
			pe.Speed = NumberRange.new(pe.Speed.Min * sScale, pe.Speed.Max * sScale)
			if tintCol then
				pe.Color = tintCol
			end
			pe:SetAttribute("AssetVFX", true)
			pe.Parent = targetHost
			cloned += 1
		end
	end
	return cloned
end

local function mkPart(
	parent: Instance,
	name: string,
	size: Vector3,
	relCF: CFrame,
	color: Color3,
	mat: Enum.Material?,
	canCollide: boolean?,
	trans: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.CFrame = relCF
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if canCollide ~= nil then canCollide else true
	p.CanQuery = if canCollide ~= nil then canCollide else true
	p.CanTouch = false
	p.Transparency = trans or 0
	p.Parent = parent
	return p
end

local function mkChevron(parent: Instance, name: string, centerZ: number, beltY: number, col: Color3, mat: Enum.Material)
	-- Clean voxel chevron arrow pointing toward +Z (toward front console)
	local lWing = mkPart(
		parent,
		name .. "_L",
		Vector3.new(1.5, 0.05, 0.34),
		CFrame.new(-0.55, beltY, centerZ - 0.22) * CFrame.Angles(0, math.rad(28), 0),
		col,
		mat,
		false
	)
	lWing.CastShadow = false
	local rWing = mkPart(
		parent,
		name .. "_R",
		Vector3.new(1.5, 0.05, 0.34),
		CFrame.new(0.55, beltY, centerZ - 0.22) * CFrame.Angles(0, math.rad(-28), 0),
		col,
		mat,
		false
	)
	rWing.CastShadow = false
end

local function addSpikeCluster(parent: Instance, prefix: string, pos: Vector3, dirOut: Vector3, h: number, w: number, col: Color3, neonCol: Color3)
	local base = mkPart(parent, prefix .. "_Base", Vector3.new(w, h * 0.55, w), CFrame.new(pos + Vector3.new(0, h * 0.27, 0)), col, Enum.Material.Metal, false)
	local tip = mkPart(parent, prefix .. "_Tip", Vector3.new(w * 0.56, h * 0.55, w * 0.56), CFrame.new(pos + Vector3.new(dirOut.X * 0.08, h * 0.72, dirOut.Z * 0.08)), neonCol, Enum.Material.Neon, false)
	base.CastShadow = false
	tip.CastShadow = false
end

local function addVoxelWing(parent: Instance, sideSign: number, origin: Vector3, featherCol: Color3, trimCol: Color3, glowCol: Color3)
	-- Multi-stepped voxel angel wing sweeping outward and upward
	for i = 1, 5 do
		local xOff = sideSign * (0.55 + i * 0.62)
		local yOff = 0.2 + i * 0.44
		local zOff = -0.15 - i * 0.14
		local lenY = 1.45 - i * 0.14
		mkPart(
			parent,
			string.format("WingFeather_%d_%d", sideSign, i),
			Vector3.new(0.56, lenY, 0.42),
			CFrame.new(origin + Vector3.new(xOff, yOff, zOff)) * CFrame.Angles(0, 0, sideSign * math.rad(-14)),
			if i == 1 then trimCol else featherCol,
			if i == 1 then Enum.Material.Metal else Enum.Material.SmoothPlastic,
			false
		)
		if i % 2 == 1 then
			mkPart(
				parent,
				string.format("WingGlow_%d_%d", sideSign, i),
				Vector3.new(0.24, lenY * 0.6, 0.46),
				CFrame.new(origin + Vector3.new(xOff, yOff + 0.12, zOff)) * CFrame.Angles(0, 0, sideSign * math.rad(-14)),
				glowCol,
				Enum.Material.Neon,
				false
			)
		end
	end
end

function VoxelTreadmillBuilder.Build(level: number, originCF: CFrame?): Model
	local lv = math.clamp(math.floor(level), 1, 12)
	local def = DEFS[lv]

	local model = Instance.new("Model")
	model.Name = def.modelName
	model:SetAttribute("Level", lv)
	model:SetAttribute("Tier", def.tier)
	model:SetAttribute("VoxelTreadmill", true)

	local baseFrame = Instance.new("Folder")
	baseFrame.Name = "BaseFrame"
	baseFrame.Parent = model

	local runningBelt = Instance.new("Folder")
	runningBelt.Name = "RunningBelt"
	runningBelt.Parent = model

	local beltSegments = Instance.new("Folder")
	beltSegments.Name = "BeltSegments"
	beltSegments.Parent = model

	local sideRails = Instance.new("Folder")
	sideRails.Name = "SideRails"
	sideRails.Parent = model

	local frontDetails = Instance.new("Folder")
	frontDetails.Name = "FrontDetails"
	frontDetails.Parent = model

	local rearConsole = Instance.new("Folder")
	rearConsole.Name = "RearConsole"
	rearConsole.Parent = model

	local consoleSupports = Instance.new("Folder")
	consoleSupports.Name = "ConsoleSupports"
	consoleSupports.Parent = model

	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = model

	local specialEffects: Folder? = nil
	if lv >= 8 then
		local sf = Instance.new("Folder")
		sf.Name = "SpecialEffects"
		sf.Parent = model
		specialEffects = sf
	end

	-- Core standardized dimensions: Length = 14 studs (-7..+7), Width = 8 studs (-4..+4), Platform top = 1.2 studs
	-- Note: Console stands at +Z (+4.8), Rear entry at -Z (-7.0).
	-- Belt animates from front (+Z) toward rear (-Z) so running forward (+Z) feels natural!
	local footH = 0.25
	local deckH = 0.95
	local platformTopY = footH + deckH -- 1.20 studs

	-- 1. BaseFrame: 4 Supporting Feet + Main Collidable Platform Deck
	local rootPart = mkPart(
		baseFrame,
		"PlatformBase",
		Vector3.new(6.8, deckH, 13.4),
		CFrame.new(0, footH + deckH * 0.5, 0),
		def.frameDark,
		Enum.Material.Metal,
		true
	)
	model.PrimaryPart = rootPart

	for idx, fc in ipairs({
		Vector3.new(-3.35, footH * 0.5, -6.2),
		Vector3.new(3.35, footH * 0.5, -6.2),
		Vector3.new(-3.35, footH * 0.5, 6.2),
		Vector3.new(3.35, footH * 0.5, 6.2),
	}) do
		mkPart(baseFrame, "Foot_" .. idx, Vector3.new(1.3, footH, 1.4), CFrame.new(fc), def.frameDark, Enum.Material.Metal, true)
	end

	-- 2. RunningBelt: Collidable Belt Bed + Front/Rear Rollers
	local beltWidth = 4.9
	local beltLen = 11.4
	local beltCenterZ = -0.55
	local beltBed = mkPart(
		runningBelt,
		"BeltBed",
		Vector3.new(beltWidth, 0.14, beltLen),
		CFrame.new(0, platformTopY + 0.04, beltCenterZ),
		def.beltBaseCol,
		Enum.Material.SmoothPlastic,
		true
	)
	beltBed:SetAttribute("BeltStartZ", beltCenterZ + beltLen * 0.5 - 0.45)
	beltBed:SetAttribute("BeltEndZ", beltCenterZ - beltLen * 0.5 + 0.45)
	beltBed:SetAttribute("BeltY", platformTopY + 0.125)

	mkPart(runningBelt, "BeltRollerFront", Vector3.new(beltWidth + 0.2, 0.45, 0.55), CFrame.new(0, platformTopY - 0.05, beltCenterZ + beltLen * 0.5 + 0.1), def.frameMid, Enum.Material.Metal, false)
	mkPart(runningBelt, "BeltRollerRear", Vector3.new(beltWidth + 0.2, 0.45, 0.55), CFrame.new(0, platformTopY - 0.05, beltCenterZ - beltLen * 0.5 - 0.1), def.frameMid, Enum.Material.Metal, false)

	-- 3. BeltSegments: 10 Animated Voxel Belt Slats + 3 Chevron Arrow Slats
	local slatCount = 10
	local startZ = beltCenterZ + beltLen * 0.5 - 0.45
	local endZ = beltCenterZ - beltLen * 0.5 + 0.45
	local spanZ = startZ - endZ
	local beltY = platformTopY + 0.125
	local chevMat = if def.hasNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic

	for i = 1, slatCount do
		local frac = (i - 1) / slatCount
		local zPos = startZ - frac * spanZ
		local seg = Instance.new("Model")
		seg.Name = "BeltSegment_" .. i
		seg:SetAttribute("StartFrac", frac)
		seg.Parent = beltSegments

		local slat = mkPart(
			seg,
			"BeltSlat",
			Vector3.new(beltWidth - 0.24, 0.04, 0.48),
			CFrame.new(0, beltY, zPos),
			def.slatCol,
			Enum.Material.SmoothPlastic,
			false
		)
		slat.CastShadow = false
		seg.PrimaryPart = slat

		if i == 2 or i == 5 or i == 8 then
			mkChevron(seg, "Chevron", zPos, beltY + 0.03, def.chevronCol, chevMat)
		end
	end

	-- 4. SideRails & 5. FrontDetails (Corner Blocks + End Caps)
	local railX = 3.25
	for _, side in ipairs({ -1, 1 }) do
		local sideTag = if side < 0 then "L" else "R"
		mkPart(
			sideRails,
			"SideRailBody_" .. sideTag,
			Vector3.new(1.35, 1.15, 13.6),
			CFrame.new(side * railX, footH + 0.575, 0),
			def.frameDark,
			Enum.Material.Metal,
			true
		)
		mkPart(
			sideRails,
			"SideRailTopTrim_" .. sideTag,
			Vector3.new(1.05, 0.18, 12.0),
			CFrame.new(side * railX, footH + 1.22, 0),
			def.frameMid,
			Enum.Material.SmoothPlastic,
			false
		)
		if def.hasNeon then
			local strip = mkPart(
				sideRails,
				"SideNeonStrip_" .. sideTag,
				Vector3.new(0.18, 0.22, 11.4),
				CFrame.new(side * (railX + 0.64), footH + 0.65, 0),
				def.neonCol,
				Enum.Material.Neon,
				false
			)
			strip.CastShadow = false
			if lv >= 4 then
				local topStrip = mkPart(
					sideRails,
					"SideTopNeon_" .. sideTag,
					Vector3.new(0.24, 0.12, 11.0),
					CFrame.new(side * (railX - 0.15), footH + 1.33, 0),
					def.neonSec,
					Enum.Material.Neon,
					false
				)
				topStrip.CastShadow = false
			end
		end

		-- Upgraded Corner Blocks (Front & Rear corners)
		for _, zEnd in ipairs({ -6.4, 6.4 }) do
			local cTag = if zEnd < 0 then "Rear" else "Front"
			local cornerH = if lv >= 4 then 1.55 else 1.38
			local cornerSize = Vector3.new(1.58, cornerH, 1.58)
			mkPart(
				frontDetails,
				string.format("CornerBlock_%s_%s", cTag, sideTag),
				cornerSize,
				CFrame.new(side * (railX + 0.05), footH + cornerH * 0.5, zEnd),
				if lv == 1 then def.frameMid else def.accent,
				if lv >= 6 then Enum.Material.Metal else Enum.Material.SmoothPlastic,
				true
			)
			if def.hasNeon then
				local cNeon = mkPart(
					frontDetails,
					string.format("CornerGlow_%s_%s", cTag, sideTag),
					Vector3.new(1.64, 0.22, 0.55),
					CFrame.new(side * (railX + 0.05), footH + cornerH * 0.68, zEnd),
					def.neonCol,
					Enum.Material.Neon,
					false
				)
				cNeon.CastShadow = false
			end
		end
	end

	-- Front & Rear Bumper Caps
	mkPart(frontDetails, "RearEndBumper", Vector3.new(5.4, 0.72, 0.8), CFrame.new(0, footH + 0.36, -6.6), def.frameMid, Enum.Material.Metal, true)
	mkPart(frontDetails, "FrontEndBumper", Vector3.new(5.4, 0.85, 0.9), CFrame.new(0, footH + 0.42, 6.6), def.frameMid, Enum.Material.Metal, true)

	-- 6. ConsoleSupports (2 Console Pillars + Handrails + Crossbar)
	local consoleZ = 5.0
	local pillarH = 3.2
	for _, side in ipairs({ -1, 1 }) do
		local sideTag = if side < 0 then "L" else "R"
		mkPart(
			consoleSupports,
			"ConsolePillar_" .. sideTag,
			Vector3.new(0.95, pillarH, 0.95),
			CFrame.new(side * 2.85, platformTopY + pillarH * 0.5, consoleZ),
			def.frameMid,
			Enum.Material.Metal,
			true
		)
		-- Stepped collar at top of pillar
		mkPart(
			consoleSupports,
			"PillarCollar_" .. sideTag,
			Vector3.new(1.22, 0.48, 1.22),
			CFrame.new(side * 2.85, platformTopY + pillarH - 0.15, consoleZ),
			def.frameDark,
			Enum.Material.Metal,
			false
		)
		-- Forward side grip / handrail
		mkPart(
			consoleSupports,
			"ConsoleArm_" .. sideTag,
			Vector3.new(0.58, 0.52, 2.2),
			CFrame.new(side * 2.85, platformTopY + 2.45, consoleZ - 1.2) * CFrame.Angles(math.rad(-14), 0, 0),
			def.frameDark,
			Enum.Material.Metal,
			false
		)
		if def.hasNeon then
			mkPart(
				consoleSupports,
				"PillarGlow_" .. sideTag,
				Vector3.new(0.24, pillarH - 0.6, 1.02),
				CFrame.new(side * 2.85, platformTopY + pillarH * 0.5, consoleZ),
				def.neonCol,
				Enum.Material.Neon,
				false
			)
		end
	end

	-- 7. RearConsole (Crossbar + Control Monitor + Screen)
	local consoleY = platformTopY + pillarH + 0.2
	mkPart(
		rearConsole,
		"ConsoleCrossbar",
		Vector3.new(6.8, 0.78, 1.25),
		CFrame.new(0, consoleY - 0.25, consoleZ),
		def.frameDark,
		Enum.Material.Metal,
		false
	)
	local monitorFrame = mkPart(
		rearConsole,
		"MonitorFrame",
		Vector3.new(3.4, 1.85, 0.72),
		CFrame.new(0, consoleY + 0.55, consoleZ - 0.18) * CFrame.Angles(math.rad(16), 0, 0),
		def.frameDark,
		Enum.Material.Metal,
		false
	)
	local screenMat = if def.hasNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local screenPart = mkPart(
		rearConsole,
		"MonitorScreen",
		Vector3.new(2.75, 1.25, 0.12),
		monitorFrame.CFrame * CFrame.new(0, 0, -0.34),
		if def.hasNeon then def.neonCol else Color3.fromRGB(196, 204, 214),
		screenMat,
		false
	)
	screenPart.CastShadow = false
	-- Center screen emblem
	mkPart(
		rearConsole,
		"MonitorEmblem",
		Vector3.new(0.62, 0.62, 0.14),
		screenPart.CFrame * CFrame.new(0, 0, -0.04) * CFrame.Angles(0, 0, math.rad(45)),
		if def.hasNeon then def.neonSec else Color3.fromRGB(242, 246, 255),
		if def.hasNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		false
	)

	-- 8. Level-Specific Unique Voxel Silhouettes (Decorations) + 9. SpecialEffects (LV 8-12 only)
	local crownBaseY = consoleY + 1.55

	if lv == 4 then
		-- LV 4 Rare: Upgraded chamfered shoulder blocks & blue side fins
		for _, side in ipairs({ -1, 1 }) do
			mkPart(decorations, "RareShoulderFin_" .. side, Vector3.new(0.7, 0.9, 1.4), CFrame.new(side * 3.55, consoleY + 0.25, consoleZ), def.accent, Enum.Material.Metal, false)
			mkPart(decorations, "RareCornerCap_" .. side, Vector3.new(1.1, 0.4, 1.1), CFrame.new(side * railX, footH + 1.75, -6.4), def.neonCol, Enum.Material.Neon, false)
		end
	elseif lv == 5 then
		-- LV 5 Epic: Purple crystal fins on console & glowing side ribs
		for _, side in ipairs({ -1, 1 }) do
			mkPart(decorations, "EpicConsoleWing_" .. side, Vector3.new(0.45, 1.25, 0.9), CFrame.new(side * 2.15, consoleY + 0.85, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-18)), def.neonCol, Enum.Material.Neon, false)
			for idx = -1, 1 do
				mkPart(decorations, string.format("EpicSideRib_%d_%d", side, idx), Vector3.new(0.32, 0.8, 0.55), CFrame.new(side * (railX + 0.72), footH + 0.7, idx * 3.2), def.accent, Enum.Material.SmoothPlastic, false)
			end
		end
	elseif lv == 6 then
		-- LV 6 Legendary: Golden Crown-shaped voxel decoration above console + golden corner trims
		mkPart(decorations, "CrownBase", Vector3.new(2.8, 0.45, 0.55), CFrame.new(0, crownBaseY, consoleZ), def.accent, Enum.Material.Metal, false)
		for _, cx in ipairs({ -1.1, 0, 1.1 }) do
			local h = if cx == 0 then 1.25 else 0.88
			mkPart(decorations, "CrownProng_" .. tostring(cx), Vector3.new(0.52, h, 0.52), CFrame.new(cx, crownBaseY + h * 0.5 + 0.15, consoleZ), def.accent, Enum.Material.Metal, false)
			mkPart(decorations, "CrownTip_" .. tostring(cx), Vector3.new(0.36, 0.36, 0.56), CFrame.new(cx, crownBaseY + h + 0.25, consoleZ), def.neonCol, Enum.Material.Neon, false)
		end
		mkPart(decorations, "CrownGem", Vector3.new(0.48, 0.48, 0.62), CFrame.new(0, crownBaseY + 0.32, consoleZ), def.neonSec, Enum.Material.Neon, false)
	elseif lv == 7 then
		-- LV 7 Mythic: Sharp red spikes at 4 corners & side rails + horned crimson crest with glowing red core
		for _, side in ipairs({ -1, 1 }) do
			addSpikeCluster(decorations, "CornerSpikeF_" .. side, Vector3.new(side * railX, footH + 1.55, 6.4), Vector3.new(side * 0.3, 1, 0.3), 1.35, 0.72, def.frameMid, def.neonCol)
			addSpikeCluster(decorations, "CornerSpikeR_" .. side, Vector3.new(side * railX, footH + 1.55, -6.4), Vector3.new(side * 0.3, 1, -0.3), 1.35, 0.72, def.frameMid, def.neonCol)
			for sIdx = -1, 1 do
				addSpikeCluster(decorations, string.format("RailSpike_%d_%d", side, sIdx), Vector3.new(side * (railX + 0.1), footH + 1.35, sIdx * 3.1), Vector3.new(side * 0.2, 1, 0), 0.95, 0.48, def.frameMid, def.neonCol)
			end
			-- Aggressive horned crest flanking console
			mkPart(decorations, "MythicHornBase_" .. side, Vector3.new(0.65, 1.35, 0.65), CFrame.new(side * 1.45, crownBaseY + 0.4, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-22)), def.frameMid, Enum.Material.Metal, false)
			mkPart(decorations, "MythicHornTip_" .. side, Vector3.new(0.42, 0.95, 0.42), CFrame.new(side * 1.75, crownBaseY + 1.35, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-10)), def.neonCol, Enum.Material.Neon, false)
		end
		-- Static glowing red core above monitor
		mkPart(decorations, "MythicCoreFrame", Vector3.new(1.15, 1.15, 0.62), CFrame.new(0, crownBaseY + 0.35, consoleZ), def.frameDark, Enum.Material.Metal, false)
		mkPart(decorations, "MythicCoreGlow", Vector3.new(0.72, 0.72, 0.72), CFrame.new(0, crownBaseY + 0.35, consoleZ) * CFrame.Angles(0, 0, math.rad(45)), def.neonCol, Enum.Material.Neon, false)
	elseif lv == 8 then
		-- LV 8 Cosmic: Crystal corner spires, orbital rings, floating spheres & subtle cosmic particles
		for _, side in ipairs({ -1, 1 }) do
			addSpikeCluster(decorations, "CosmicSpireF_" .. side, Vector3.new(side * railX, footH + 1.55, 6.4), Vector3.zero, 1.5, 0.78, def.frameMid, def.neonSec)
			addSpikeCluster(decorations, "CosmicSpireR_" .. side, Vector3.new(side * railX, footH + 1.55, -6.4), Vector3.zero, 1.5, 0.78, def.frameMid, def.neonCol)
		end
		if specialEffects then
			-- Orbital Ring 1 & 2 (voxel ring segments around console)
			for rIdx = 1, 2 do
				local ringModel = Instance.new("Model")
				ringModel.Name = "OrbitalRing_" .. rIdx
				ringModel:SetAttribute("RingRadius", if rIdx == 1 then 4.2 else 3.3)
				ringModel:SetAttribute("RingCenterY", consoleY + 0.9)
				ringModel:SetAttribute("RingCenterZ", consoleZ - 0.2)
				ringModel:SetAttribute("TiltDeg", if rIdx == 1 then 16 else -22)
				ringModel:SetAttribute("SpinSpeed", if rIdx == 1 then 1.1 else -1.5)
				ringModel.Parent = specialEffects

				local segCount = 12
				local rad = if rIdx == 1 then 4.2 else 3.3
				local col = if rIdx == 1 then def.neonSec else def.neonCol
				for i = 1, segCount do
					local ang = (i / segCount) * math.pi * 2
					local p = mkPart(ringModel, "RingSeg_" .. i, Vector3.new(0.28, 0.28, 0.95), CFrame.new(math.cos(ang) * rad, consoleY + 0.9, consoleZ - 0.2 + math.sin(ang) * rad), col, Enum.Material.Neon, false)
					p.CastShadow = false
				end
			end
			-- Floating purple/cyan energy spheres (blocky voxel cubes/diamonds)
			for i = 1, 4 do
				local orb = mkPart(specialEffects, "FloatingOrb_" .. i, Vector3.new(0.65, 0.65, 0.65), CFrame.new(if i % 2 == 0 then -4.4 else 4.4, 2.2 + i * 0.6, -2.5 + i * 2.0), if i % 2 == 0 then def.neonCol else def.neonSec, Enum.Material.Neon, false)
				orb:SetAttribute("BasePos", orb.Position)
				orb:SetAttribute("Phase", i * 1.4)
				orb.CastShadow = false
			end
			local emitterHost = mkPart(specialEffects, "CosmicEmitterHost", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, consoleY + 1.0, consoleZ), def.neonCol, Enum.Material.SmoothPlastic, false, 1)
			local cCount = cloneAssetVFX(emitterHost, { "Particle effects", "Portals", "08 - PORTAL [B]" }, 0.38, 12, nil)
			cCount += cloneAssetVFX(emitterHost, { "VFX1", "Anime", "Charge-01" }, 0.35, 10, ColorSequence.new(def.neonCol, def.neonSec))
			if cCount == 0 then
				local pe = Instance.new("ParticleEmitter")
				pe.Name = "CosmicParticles"
				pe.Rate = 10
				pe.Lifetime = NumberRange.new(1.2, 2.2)
				pe.Speed = NumberRange.new(1.2, 2.8)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
				pe.Color = ColorSequence.new(def.neonCol, def.neonSec)
				pe.LightEmission = 0.6
				pe.Parent = emitterHost
			end
		end
	elseif lv == 9 then
		-- LV 9 Divine: White & Gold frame, decorative voxel wings, golden halo & soft sparkles
		addVoxelWing(decorations, -1, Vector3.new(-2.6, consoleY + 0.1, consoleZ + 0.1), def.frameDark, def.accent, def.neonCol)
		addVoxelWing(decorations, 1, Vector3.new(2.6, consoleY + 0.1, consoleZ + 0.1), def.frameDark, def.accent, def.neonCol)
		-- Side mini-wings near rear corners
		for _, side in ipairs({ -1, 1 }) do
			mkPart(decorations, "SideWing1_" .. side, Vector3.new(0.45, 0.9, 1.4), CFrame.new(side * (railX + 0.65), footH + 1.4, -5.2) * CFrame.Angles(math.rad(18), 0, side * math.rad(-14)), def.frameDark, Enum.Material.SmoothPlastic, false)
			mkPart(decorations, "SideWing2_" .. side, Vector3.new(0.35, 0.65, 1.0), CFrame.new(side * (railX + 0.85), footH + 1.9, -5.8) * CFrame.Angles(math.rad(22), 0, side * math.rad(-18)), def.neonCol, Enum.Material.Neon, false)
		end
		if specialEffects then
			local haloModel = Instance.new("Model")
			haloModel.Name = "DivineHalo"
			haloModel:SetAttribute("RingRadius", 1.55)
			haloModel:SetAttribute("RingCenterY", crownBaseY + 1.25)
			haloModel:SetAttribute("RingCenterZ", consoleZ)
			haloModel:SetAttribute("TiltDeg", 4)
			haloModel:SetAttribute("SpinSpeed", 0.9)
			haloModel.Parent = specialEffects
			for i = 1, 12 do
				local ang = (i / 12) * math.pi * 2
				local seg = mkPart(haloModel, "HaloSeg_" .. i, Vector3.new(0.38, 0.24, 0.58), CFrame.new(math.cos(ang) * 1.55, crownBaseY + 1.25, consoleZ + math.sin(ang) * 1.55), def.neonCol, Enum.Material.Neon, false)
				seg.CastShadow = false
			end
			local spHost = mkPart(specialEffects, "DivineSparkleHost", Vector3.new(6.2, 2.0, 2.0), CFrame.new(0, consoleY + 0.8, consoleZ), def.neonCol, Enum.Material.SmoothPlastic, false, 1)
			local dCount = cloneAssetVFX(spHost, { "VFX1", "Anime", "Shiny-01" }, 0.42, 12, ColorSequence.new(def.neonCol, def.neonSec))
			dCount += cloneAssetVFX(spHost, { "Particle effects", "Other", "Heal Part (*)" }, 0.42, 8, ColorSequence.new(def.neonCol, def.neonSec))
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "DivineSparkles"
			pe.Rate = 12
			pe.Lifetime = NumberRange.new(1.0, 1.8)
			pe.Speed = NumberRange.new(0.6, 1.8)
			pe.SpreadAngle = Vector2.new(90, 90)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.26), NumberSequenceKeypoint.new(0.5, 0.34), NumberSequenceKeypoint.new(1, 0) })
			pe.Color = ColorSequence.new(def.neonCol, def.neonSec)
			pe.LightEmission = 0.7
			pe.Parent = spHost
		end
	elseif lv == 10 then
		-- LV 10 Infinity: Blue & Gold frame, voxel Infinity Symbol (∞), rotating energy rings
		for _, side in ipairs({ -1, 1 }) do
			mkPart(decorations, "InfHorn_" .. side, Vector3.new(0.68, 2.1, 0.72), CFrame.new(side * 2.45, consoleY + 1.15, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-12)), def.accent, Enum.Material.Metal, false)
			mkPart(decorations, "InfHornGlow_" .. side, Vector3.new(0.32, 1.65, 0.78), CFrame.new(side * 2.45, consoleY + 1.25, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-12)), def.neonCol, Enum.Material.Neon, false)
			addSpikeCluster(decorations, "InfCornerCrystal_" .. side, Vector3.new(side * railX, footH + 1.55, 6.4), Vector3.zero, 1.6, 0.82, def.accent, def.neonCol)
		end
		-- Voxel Infinity Symbol (∞) above console
		local infY = crownBaseY + 0.95
		for _, loopSide in ipairs({ -1, 1 }) do
			local cx = loopSide * 0.95
			mkPart(decorations, "InfTop_" .. loopSide, Vector3.new(1.25, 0.34, 0.38), CFrame.new(cx, infY + 0.55, consoleZ), def.neonCol, Enum.Material.Neon, false)
			mkPart(decorations, "InfBot_" .. loopSide, Vector3.new(1.25, 0.34, 0.38), CFrame.new(cx, infY - 0.55, consoleZ), def.neonCol, Enum.Material.Neon, false)
			mkPart(decorations, "InfOuter_" .. loopSide, Vector3.new(0.34, 1.1, 0.38), CFrame.new(cx + loopSide * 0.55, infY, consoleZ), def.neonCol, Enum.Material.Neon, false)
		end
		mkPart(decorations, "InfBridge", Vector3.new(0.55, 0.75, 0.44), CFrame.new(0, infY, consoleZ) * CFrame.Angles(0, 0, math.rad(45)), def.neonSec, Enum.Material.Neon, false)

		if specialEffects then
			for rIdx = 1, 2 do
				local ringModel = Instance.new("Model")
				ringModel.Name = "InfinityRing_" .. rIdx
				ringModel:SetAttribute("RingRadius", if rIdx == 1 then 4.5 else 3.6)
				ringModel:SetAttribute("RingCenterY", consoleY + 0.75)
				ringModel:SetAttribute("RingCenterZ", consoleZ - 0.4)
				ringModel:SetAttribute("TiltDeg", if rIdx == 1 then 20 else -20)
				ringModel:SetAttribute("SpinSpeed", if rIdx == 1 then 1.35 else -1.35)
				ringModel.Parent = specialEffects
				local rad = if rIdx == 1 then 4.5 else 3.6
				local col = if rIdx == 1 then def.neonCol else def.neonSec
				for i = 1, 12 do
					local ang = (i / 12) * math.pi * 2
					local p = mkPart(ringModel, "InfRingSeg_" .. i, Vector3.new(0.28, 0.24, 0.95), CFrame.new(math.cos(ang) * rad, consoleY + 0.75, consoleZ - 0.4 + math.sin(ang) * rad), col, Enum.Material.Neon, false)
					p.CastShadow = false
				end
			end
			local infHost = mkPart(specialEffects, "InfinityParticleHost", Vector3.new(4.0, 2.0, 2.0), CFrame.new(0, consoleY + 0.9, consoleZ), def.neonCol, Enum.Material.SmoothPlastic, false, 1)
			cloneAssetVFX(infHost, { "Particle effects", "Portals", "Magic Ting5" }, 0.50, 6, ColorSequence.new(def.neonCol, def.neonSec))
			cloneAssetVFX(infHost, { "Particle effects", "Lightning", "A - ELECTRICITY 01" }, 0.38, 10, ColorSequence.new(def.neonCol, def.neonSec))
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "InfinityParticles"
			pe.Rate = 12
			pe.Lifetime = NumberRange.new(1.0, 1.8)
			pe.Speed = NumberRange.new(1.0, 2.4)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
			pe.Color = ColorSequence.new(def.neonCol, def.neonSec)
			pe.LightEmission = 0.65
			pe.Parent = infHost
		end
	elseif lv == 11 then
		-- LV 11 Singularity: Black & deep purple frame, jagged rail spikes, large black-hole portal, rotating gravitational rings & fragments
		for _, side in ipairs({ -1, 1 }) do
			for sIdx = -2, 2 do
				addSpikeCluster(decorations, string.format("VoidSpike_%d_%d", side, sIdx), Vector3.new(side * (railX + 0.1), footH + 1.35, sIdx * 2.6), Vector3.new(side * 0.25, 1, 0), 1.15, 0.58, def.frameMid, def.neonCol)
			end
			-- Arched void arms framing the black-hole portal
			mkPart(decorations, "PortalArmLow_" .. side, Vector3.new(0.7, 1.6, 0.7), CFrame.new(side * 2.5, consoleY + 1.1, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-26)), def.frameDark, Enum.Material.Metal, false)
			mkPart(decorations, "PortalArmHigh_" .. side, Vector3.new(0.65, 1.4, 0.65), CFrame.new(side * 1.9, consoleY + 2.6, consoleZ) * CFrame.Angles(0, 0, side * math.rad(28)), def.neonCol, Enum.Material.Neon, false)
		end
		if specialEffects then
			local portalY = crownBaseY + 1.25
			local portalModel = Instance.new("Model")
			portalModel.Name = "SingularityPortal"
			portalModel:SetAttribute("PortalCenterY", portalY)
			portalModel:SetAttribute("PortalCenterZ", consoleZ)
			portalModel.Parent = specialEffects

			local voidCore = mkPart(portalModel, "BlackHoleCore", Vector3.new(1.85, 1.85, 0.55), CFrame.new(0, portalY, consoleZ), Color3.fromRGB(8, 6, 12), Enum.Material.SmoothPlastic, false)
			portalModel.PrimaryPart = voidCore
			-- Outer rotating accretion ring
			for i = 1, 12 do
				local ang = (i / 12) * math.pi * 2
				local seg = mkPart(portalModel, "PortalRim_" .. i, Vector3.new(0.42, 0.42, 0.46), CFrame.new(math.cos(ang) * 1.25, portalY + math.sin(ang) * 1.25, consoleZ), if i % 2 == 0 then def.neonCol else def.neonSec, Enum.Material.Neon, false)
				seg.CastShadow = false
			end
			-- Gravitational ground ring
			local gravRing = Instance.new("Model")
			gravRing.Name = "GravitationalRing"
			gravRing:SetAttribute("RingRadius", 5.2)
			gravRing:SetAttribute("RingCenterY", footH + 0.55)
			gravRing:SetAttribute("RingCenterZ", 0)
			gravRing:SetAttribute("TiltDeg", 0)
			gravRing:SetAttribute("SpinSpeed", 0.85)
			gravRing.Parent = specialEffects
			for i = 1, 14 do
				local ang = (i / 14) * math.pi * 2
				local seg = mkPart(gravRing, "GravSeg_" .. i, Vector3.new(0.35, 0.14, 1.15), CFrame.new(math.cos(ang) * 5.2, footH + 0.55, math.sin(ang) * 5.2), def.neonCol, Enum.Material.Neon, false)
				seg.CastShadow = false
			end
			-- Floating dark purple fragments
			for i = 1, 6 do
				local frag = mkPart(specialEffects, "FloatingFrag_" .. i, Vector3.new(0.55, 0.55, 0.55), CFrame.new((if i % 2 == 0 then -4.6 else 4.6), 2.0 + (i % 3) * 1.1, -3.5 + i * 1.4), def.frameMid, Enum.Material.SmoothPlastic, false)
				frag:SetAttribute("BasePos", frag.Position)
				frag:SetAttribute("Phase", i * 1.1)
				frag.CastShadow = false
			end
			-- Inward suction particles around portal
			local pHost = mkPart(specialEffects, "SingularityParticleHost", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, portalY, consoleZ), def.neonCol, Enum.Material.SmoothPlastic, false, 1)
			local sCount = cloneAssetVFX(pHost, { "VFX1", "Anime", "Portal-01" }, 0.45, 10, ColorSequence.new(def.neonSec, def.neonCol))
			sCount += cloneAssetVFX(pHost, { "Particle effects", "Portals", "07 - PORTAL [A]" }, 0.38, 10, nil)
			if sCount == 0 then
				local pe = Instance.new("ParticleEmitter")
				pe.Name = "PortalPullParticles"
				pe.Rate = 16
				pe.Lifetime = NumberRange.new(0.7, 1.3)
				pe.Speed = NumberRange.new(-4.5, -2.0)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.36), NumberSequenceKeypoint.new(1, 0) })
				pe.Color = ColorSequence.new(def.neonSec, Color3.fromRGB(24, 10, 42))
				pe.LightEmission = 0.6
				pe.Parent = pHost
			end
		end
	elseif lv == 12 then
		-- LV 12 Primordial: Black, crimson & gold frame, massive horns, ancient spikes, chains, pulsing red core, embers & smoke
		for _, side in ipairs({ -1, 1 }) do
			-- Ancient spikes on all corners & along rails
			addSpikeCluster(decorations, "PrimSpikeF_" .. side, Vector3.new(side * railX, footH + 1.55, 6.4), Vector3.new(side * 0.25, 1, 0.25), 1.85, 0.88, def.accent, def.neonCol)
			addSpikeCluster(decorations, "PrimSpikeR_" .. side, Vector3.new(side * railX, footH + 1.55, -6.4), Vector3.new(side * 0.25, 1, -0.25), 1.75, 0.85, def.accent, def.neonCol)
			for sIdx = -1, 1 do
				addSpikeCluster(decorations, string.format("PrimRailSpike_%d_%d", side, sIdx), Vector3.new(side * (railX + 0.18), footH + 1.38, sIdx * 3.0), Vector3.new(side * 0.3, 1, 0), 1.25, 0.62, def.frameMid, def.neonCol)
			end
			-- Massive Curved Crimson-Gold Horns atop Console
			mkPart(decorations, "PrimHornSeg1_" .. side, Vector3.new(0.95, 1.45, 0.95), CFrame.new(side * 1.9, crownBaseY + 0.45, consoleZ) * CFrame.Angles(0, 0, side * math.rad(-24)), def.frameMid, Enum.Material.Metal, false)
			mkPart(decorations, "PrimHornSeg2_" .. side, Vector3.new(0.72, 1.35, 0.72), CFrame.new(side * 2.35, crownBaseY + 1.65, consoleZ) * CFrame.Angles(0, 0, side * math.rad(12)), def.neonCol, Enum.Material.Neon, false)
			mkPart(decorations, "PrimHornTip_" .. side, Vector3.new(0.45, 0.95, 0.45), CFrame.new(side * 1.95, crownBaseY + 2.65, consoleZ) * CFrame.Angles(0, 0, side * math.rad(34)), def.accent, Enum.Material.Metal, false)
		end

		if specialEffects then
			-- Voxel Chains draped from Console Pillars down to Front-Rear Side Rails
			for _, side in ipairs({ -1, 1 }) do
				local chainModel = Instance.new("Model")
				chainModel.Name = "PrimordialChain_" .. (if side < 0 then "L" else "R")
				chainModel:SetAttribute("BaseSide", side)
				chainModel.Parent = specialEffects
				local pStart = Vector3.new(side * 3.15, platformTopY + 2.75, consoleZ - 0.2)
				local pEnd = Vector3.new(side * (railX + 0.45), footH + 1.45, -5.6)
				local links = 10
				for k = 0, links do
					local t = k / links
					local sag = math.sin(t * math.pi) * 0.85
					local pos = pStart:Lerp(pEnd, t) - Vector3.new(0, sag, 0)
					local link = mkPart(
						chainModel,
						"ChainLink_" .. k,
						Vector3.new(0.36, 0.48, 0.56),
						CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 25 else -25)),
						if k % 3 == 0 then def.accent else Color3.fromRGB(48, 42, 46),
						Enum.Material.Metal,
						false
					)
					link:SetAttribute("BasePos", pos)
					link:SetAttribute("LinkIdx", k)
					link.CastShadow = false
				end
			end

			-- Pulsing Red Central Energy Core above Console
			local coreOuter = mkPart(specialEffects, "PrimordialCoreOuter", Vector3.new(1.35, 1.35, 0.68), CFrame.new(0, crownBaseY + 0.55, consoleZ) * CFrame.Angles(0, 0, math.rad(45)), def.accent, Enum.Material.Metal, false)
			coreOuter.CastShadow = false
			local coreInner = mkPart(specialEffects, "PrimordialCore", Vector3.new(0.92, 0.92, 0.82), CFrame.new(0, crownBaseY + 0.55, consoleZ) * CFrame.Angles(0, 0, math.rad(45)), def.neonCol, Enum.Material.Neon, false)
			coreInner:SetAttribute("BaseSize", coreInner.Size)
			coreInner.CastShadow = false

			-- Embers + Dark Smoke + Fire Particles (built-in Roblox properties only)
			local baseVfxHost = mkPart(specialEffects, "PrimordialBaseVFX", Vector3.new(7.5, 0.4, 13.0), CFrame.new(0, footH + 0.4, 0), def.neonCol, Enum.Material.SmoothPlastic, false, 1)
			cloneAssetVFX(baseVfxHost, { "VFX1", "Anime", "Crack-01" }, 0.50, 5, ColorSequence.new(def.neonCol, def.neonSec))
			cloneAssetVFX(baseVfxHost, { "VFX1", "Anime", "Fire-01" }, 0.40, 14, ColorSequence.new(def.neonCol, def.neonSec))
			local embers = Instance.new("ParticleEmitter")
			embers.Name = "PrimordialEmbers"
			embers.Rate = 18
			embers.Lifetime = NumberRange.new(1.0, 1.9)
			embers.Speed = NumberRange.new(2.2, 4.8)
			embers.SpreadAngle = Vector2.new(35, 35)
			embers.Acceleration = Vector3.new(0, 2.5, 0)
			embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(1, 0) })
			embers.Color = ColorSequence.new(def.neonCol, def.neonSec)
			embers.LightEmission = 0.75
			embers.Parent = baseVfxHost

			local smokeHost = mkPart(specialEffects, "PrimordialSmokeHost", Vector3.new(4.2, 0.8, 2.0), CFrame.new(0, consoleY + 1.1, consoleZ), Color3.fromRGB(36, 26, 28), Enum.Material.SmoothPlastic, false, 1)
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "PrimordialSmoke"
			smoke.Rate = 8
			smoke.Lifetime = NumberRange.new(1.5, 2.5)
			smoke.Speed = NumberRange.new(1.2, 2.6)
			smoke.SpreadAngle = Vector2.new(45, 45)
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.2) })
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			smoke.Color = ColorSequence.new(Color3.fromRGB(48, 32, 34), Color3.fromRGB(22, 16, 18))
			smoke.Parent = smokeHost

			local fire = Instance.new("ParticleEmitter")
			fire.Name = "PrimordialConsoleFire"
			fire.Rate = 14
			fire.Lifetime = NumberRange.new(0.5, 1.0)
			fire.Speed = NumberRange.new(2.0, 4.2)
			fire.SpreadAngle = Vector2.new(30, 30)
			fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
			fire.Color = ColorSequence.new(def.neonCol, def.neonSec)
			fire.LightEmission = 0.8
			fire.Parent = smokeHost
		end
	end

	-- Anchor bottom pivot at Y = 0 so :PivotTo(groundCF) sits 0.000 studs flush on the floor
	rootPart.PivotOffset = CFrame.new(0, -(footH + deckH * 0.5), 0)
	if originCF then
		model:PivotTo(originCF)
	end
	return model
end

function VoxelTreadmillBuilder.BuildCollection(originCornerCF: CFrame?): Folder
	local baseCF = originCornerCF or CFrame.new(-124, 0, -10)
	local folder = Instance.new("Folder")
	folder.Name = "TreadmillCollection"

	-- 4 Columns x 3 Rows organized layout
	local colSpacing = 14.0
	local rowSpacing = 20.0
	for i = 1, 12 do
		local idx0 = i - 1
		local col = idx0 % 4
		local row = math.floor(idx0 / 4)
		local cf = baseCF * CFrame.new(col * colSpacing, 0, row * rowSpacing)
		local tm = VoxelTreadmillBuilder.Build(i, cf)
		tm.Parent = folder
	end

	return folder
end

return VoxelTreadmillBuilder
