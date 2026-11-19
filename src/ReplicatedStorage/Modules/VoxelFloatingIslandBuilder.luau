--!strict
-- VoxelFloatingIslandBuilder.luau
-- Builds the lush Stylized Voxel Floating Island with Ruins, Vegetation,
-- Hanging Roots, Tapered Rocky Underbelly, Warm Lanterns, & Dynamic Animated Waterfall.
-- Reference: 6-view voxel floating island design (Front/Side/Back/Top/Bottom/Close-up).
-- Pure Roblox Parts (Anchored, CanCollide = false, CanQuery = false, CanTouch = false).

local VoxelFloatingIslandBuilder = {}

export type FloatingIslandOptions = {
	biomeId: string?,
	detailLevel: ("Hero" | "Standard")?,
	hasWaterfall: boolean?,
	modelName: string?,
	parent: Instance?,
}

type IslandPalette = {
	grassColors: { Color3 },
	dirtColors: { Color3 },
	stoneColors: { Color3 },
	mossColor: Color3,
	barkColor: Color3,
	barkDark: Color3,
	leafColors: { Color3 },
	flowerColors: { Color3 },
	waterDeep: Color3,
	waterBright: Color3,
	waterFoam: Color3,
	lanternGlow: Color3,
	isVolcano: boolean,
}

local PALETTES: { [string]: IslandPalette } = {
	PineWoods = {
		grassColors = {
			Color3.fromRGB(106, 192, 66),
			Color3.fromRGB(84, 164, 54),
			Color3.fromRGB(128, 208, 74),
		},
		dirtColors = {
			Color3.fromRGB(116, 84, 56),
			Color3.fromRGB(92, 66, 44),
		},
		stoneColors = {
			Color3.fromRGB(128, 126, 138),
			Color3.fromRGB(102, 100, 114),
			Color3.fromRGB(148, 144, 156),
			Color3.fromRGB(78, 78, 92),
		},
		mossColor = Color3.fromRGB(92, 174, 62),
		barkColor = Color3.fromRGB(114, 78, 52),
		barkDark = Color3.fromRGB(84, 56, 38),
		leafColors = {
			Color3.fromRGB(64, 148, 48),
			Color3.fromRGB(92, 182, 58),
			Color3.fromRGB(134, 208, 68),
		},
		flowerColors = {
			Color3.fromRGB(194, 114, 244),
			Color3.fromRGB(255, 218, 78),
			Color3.fromRGB(248, 146, 194),
			Color3.fromRGB(246, 248, 255),
		},
		waterDeep = Color3.fromRGB(52, 168, 246),
		waterBright = Color3.fromRGB(106, 218, 255),
		waterFoam = Color3.fromRGB(224, 248, 255),
		lanternGlow = Color3.fromRGB(255, 192, 84),
		isVolcano = false,
	},
	MangroveSwamp = {
		grassColors = {
			Color3.fromRGB(78, 138, 68),
			Color3.fromRGB(62, 116, 58),
			Color3.fromRGB(96, 156, 76),
		},
		dirtColors = {
			Color3.fromRGB(84, 64, 46),
			Color3.fromRGB(64, 50, 38),
		},
		stoneColors = {
			Color3.fromRGB(94, 102, 98),
			Color3.fromRGB(74, 82, 78),
			Color3.fromRGB(112, 120, 114),
			Color3.fromRGB(58, 66, 64),
		},
		mossColor = Color3.fromRGB(74, 164, 92),
		barkColor = Color3.fromRGB(88, 64, 46),
		barkDark = Color3.fromRGB(62, 46, 34),
		leafColors = {
			Color3.fromRGB(48, 118, 66),
			Color3.fromRGB(68, 146, 78),
			Color3.fromRGB(98, 174, 92),
		},
		flowerColors = {
			Color3.fromRGB(142, 248, 168),
			Color3.fromRGB(228, 246, 108),
			Color3.fromRGB(118, 224, 210),
			Color3.fromRGB(238, 248, 228),
		},
		waterDeep = Color3.fromRGB(42, 164, 178),
		waterBright = Color3.fromRGB(88, 214, 210),
		waterFoam = Color3.fromRGB(214, 252, 244),
		lanternGlow = Color3.fromRGB(255, 202, 92),
		isVolcano = false,
	},
	SavannaCamp = {
		grassColors = {
			Color3.fromRGB(216, 178, 86),
			Color3.fromRGB(192, 154, 72),
			Color3.fromRGB(118, 178, 66),
		},
		dirtColors = {
			Color3.fromRGB(178, 112, 62),
			Color3.fromRGB(148, 88, 48),
		},
		stoneColors = {
			Color3.fromRGB(186, 146, 104),
			Color3.fromRGB(154, 118, 84),
			Color3.fromRGB(204, 168, 122),
			Color3.fromRGB(122, 88, 64),
		},
		mossColor = Color3.fromRGB(112, 172, 64),
		barkColor = Color3.fromRGB(122, 82, 48),
		barkDark = Color3.fromRGB(88, 58, 36),
		leafColors = {
			Color3.fromRGB(108, 154, 48),
			Color3.fromRGB(134, 178, 56),
			Color3.fromRGB(168, 198, 68),
		},
		flowerColors = {
			Color3.fromRGB(255, 162, 54),
			Color3.fromRGB(255, 226, 86),
			Color3.fromRGB(255, 118, 134),
			Color3.fromRGB(255, 246, 222),
		},
		waterDeep = Color3.fromRGB(46, 176, 228),
		waterBright = Color3.fromRGB(98, 228, 248),
		waterFoam = Color3.fromRGB(224, 252, 255),
		lanternGlow = Color3.fromRGB(255, 178, 68),
		isVolcano = false,
	},
	AlpinePeaks = {
		grassColors = {
			Color3.fromRGB(232, 244, 255),
			Color3.fromRGB(206, 230, 248),
			Color3.fromRGB(168, 212, 242),
		},
		dirtColors = {
			Color3.fromRGB(124, 148, 176),
			Color3.fromRGB(96, 120, 148),
		},
		stoneColors = {
			Color3.fromRGB(132, 156, 188),
			Color3.fromRGB(104, 126, 158),
			Color3.fromRGB(156, 186, 218),
			Color3.fromRGB(78, 96, 124),
		},
		mossColor = Color3.fromRGB(126, 208, 248),
		barkColor = Color3.fromRGB(92, 74, 68),
		barkDark = Color3.fromRGB(64, 52, 50),
		leafColors = {
			Color3.fromRGB(68, 132, 126),
			Color3.fromRGB(124, 196, 214),
			Color3.fromRGB(224, 244, 255),
		},
		flowerColors = {
			Color3.fromRGB(142, 226, 255),
			Color3.fromRGB(218, 244, 255),
			Color3.fromRGB(162, 188, 255),
			Color3.fromRGB(255, 255, 255),
		},
		waterDeep = Color3.fromRGB(64, 188, 255),
		waterBright = Color3.fromRGB(138, 234, 255),
		waterFoam = Color3.fromRGB(240, 252, 255),
		lanternGlow = Color3.fromRGB(138, 232, 255),
		isVolcano = false,
	},
	VolcanicJungle = {
		grassColors = {
			Color3.fromRGB(58, 48, 66),
			Color3.fromRGB(46, 38, 54),
			Color3.fromRGB(74, 58, 82),
		},
		dirtColors = {
			Color3.fromRGB(44, 34, 46),
			Color3.fromRGB(32, 24, 36),
		},
		stoneColors = {
			Color3.fromRGB(54, 48, 62),
			Color3.fromRGB(40, 34, 48),
			Color3.fromRGB(72, 62, 78),
			Color3.fromRGB(28, 22, 34),
		},
		mossColor = Color3.fromRGB(255, 104, 34),
		barkColor = Color3.fromRGB(56, 38, 36),
		barkDark = Color3.fromRGB(38, 24, 26),
		leafColors = {
			Color3.fromRGB(136, 28, 42),
			Color3.fromRGB(186, 46, 48),
			Color3.fromRGB(242, 92, 52),
		},
		flowerColors = {
			Color3.fromRGB(255, 96, 38),
			Color3.fromRGB(255, 168, 48),
			Color3.fromRGB(214, 72, 255),
			Color3.fromRGB(255, 214, 128),
		},
		waterDeep = Color3.fromRGB(242, 72, 18),
		waterBright = Color3.fromRGB(255, 148, 32),
		waterFoam = Color3.fromRGB(255, 224, 112),
		lanternGlow = Color3.fromRGB(255, 118, 42),
		isVolcano = true,
	},
}

local function makeSubFolder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function makeVPart(
	parent: Instance,
	originCF: CFrame,
	s: number,
	name: string,
	size: Vector3,
	localCF: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	castShadow: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * s
	local pos = localCF.Position * s
	local rot = localCF - localCF.Position
	p.CFrame = originCF * CFrame.new(pos) * rot
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = transparency or 0
	p.CastShadow = if castShadow ~= nil then castShadow else ((transparency or 0) < 0.25 and size.Magnitude >= 3.5)
	p.Parent = parent
	return p
end

local function makeAnimAttachmentPart(parent: Instance, originCF: CFrame, s: number, name: string, localPos: Vector3): (Part, Attachment)
	local p = makeVPart(parent, originCF, s, name, Vector3.new(0.4, 0.4, 0.4), CFrame.new(localPos), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1, false)
	local att = Instance.new("Attachment")
	att.Name = name .. "_Att"
	att.Parent = p
	return p, att
end

local function buildVoxelTree(
	parent: Instance,
	originCF: CFrame,
	s: number,
	pal: IslandPalette,
	basePos: Vector3,
	treeScale: number,
	isHero: boolean,
	namePrefix: string,
	phaseSeed: number
)
	local t = treeScale
	local trunkH = 6.2 * t
	local treeCF = CFrame.new(basePos)

	-- Stepped bark trunk & flared root buttresses
	makeVPart(parent, originCF, s, namePrefix .. "_TrunkCore", Vector3.new(1.8 * t, trunkH, 1.8 * t), treeCF * CFrame.new(0, trunkH * 0.5, 0), pal.barkColor)
	makeVPart(parent, originCF, s, namePrefix .. "_TrunkUpper", Vector3.new(1.35 * t, trunkH * 0.45, 1.35 * t), treeCF * CFrame.new(0.25 * t, trunkH * 0.78, -0.1 * t), pal.barkDark)

	local roots = {
		Vector3.new(-1.05 * t, 0.7 * t, 0),
		Vector3.new(1.05 * t, 0.7 * t, 0.1 * t),
		Vector3.new(0, 0.7 * t, -1.0 * t),
		Vector3.new(0.1 * t, 0.65 * t, 1.0 * t),
	}
	for ri, rOff in ipairs(roots) do
		makeVPart(parent, originCF, s, namePrefix .. "_Root_" .. ri, Vector3.new(1.0 * t, 1.5 * t, 1.0 * t), treeCF * CFrame.new(rOff), pal.barkDark, nil, 0, false)
	end

	-- Multi-tiered clustered blocky foliage crown matching 6-view voxel tree silhouette
	local baseY = trunkH + 0.9 * t
	local tiers = {
		{ off = Vector3.new(0, baseY - 0.5 * t, 0), sz = Vector3.new(5.8 * t, 2.2 * t, 5.6 * t), col = pal.leafColors[1], sway = false },
		{ off = Vector3.new(-2.4 * t, baseY + 0.2 * t, 0.8 * t), sz = Vector3.new(3.6 * t, 2.4 * t, 3.8 * t), col = pal.leafColors[2], sway = true },
		{ off = Vector3.new(2.3 * t, baseY + 0.1 * t, -1.1 * t), sz = Vector3.new(3.4 * t, 2.2 * t, 3.6 * t), col = pal.leafColors[1], sway = true },
		{ off = Vector3.new(0.2 * t, baseY + 1.2 * t, 1.9 * t), sz = Vector3.new(3.8 * t, 2.2 * t, 3.2 * t), col = pal.leafColors[2], sway = true },
		{ off = Vector3.new(-0.4 * t, baseY + 1.4 * t, -1.8 * t), sz = Vector3.new(3.6 * t, 2.2 * t, 3.2 * t), col = pal.leafColors[2], sway = true },
		{ off = Vector3.new(-1.1 * t, baseY + 2.4 * t, 0.3 * t), sz = Vector3.new(3.6 * t, 1.8 * t, 3.4 * t), col = pal.leafColors[3], sway = true },
		{ off = Vector3.new(1.3 * t, baseY + 2.2 * t, -0.3 * t), sz = Vector3.new(2.8 * t, 1.7 * t, 2.9 * t), col = pal.leafColors[3], sway = true },
		{ off = Vector3.new(0.0, baseY + 3.4 * t, 0.0), sz = Vector3.new(2.4 * t, 1.3 * t, 2.4 * t), col = pal.leafColors[3], sway = true },
	}
	if isHero then
		table.insert(tiers, { off = Vector3.new(-3.4 * t, baseY - 1.1 * t, -1.4 * t), sz = Vector3.new(2.2 * t, 1.9 * t, 2.3 * t), col = pal.leafColors[1], sway = false })
		table.insert(tiers, { off = Vector3.new(3.1 * t, baseY - 0.8 * t, 1.4 * t), sz = Vector3.new(2.2 * t, 1.7 * t, 2.2 * t), col = pal.leafColors[2], sway = true })
		table.insert(tiers, { off = Vector3.new(-2.0 * t, baseY + 2.7 * t, -1.0 * t), sz = Vector3.new(1.8 * t, 1.4 * t, 1.8 * t), col = pal.leafColors[3], sway = true })
	end

	for i, tier in ipairs(tiers) do
		local localLeafCF = treeCF * CFrame.new(tier.off)
		local lp = makeVPart(
			parent,
			originCF,
			s,
			namePrefix .. "_Canopy_" .. i,
			tier.sz,
			localLeafCF,
			tier.col,
			Enum.Material.SmoothPlastic,
			0,
			i == 1
		)
		if tier.sway then
			lp:SetAttribute("AnimKind", "LeafSway")
			lp:SetAttribute("BaseLocalCF", localLeafCF)
			lp:SetAttribute("Phase", phaseSeed + i * 1.15)
		end
	end

	-- Hanging foliage vine clusters from tree canopy rim
	local vineOffsets = {
		Vector3.new(-2.8 * t, baseY - 2.6 * t, -2.4 * t),
		Vector3.new(2.6 * t, baseY - 2.3 * t, 2.0 * t),
	}
	for vi, vOff in ipairs(vineOffsets) do
		local hLen = (1.5 + vi * 0.4) * t
		local pivot = treeCF.Position + vOff + Vector3.new(0, hLen, 0)
		local vp = makeVPart(
			parent,
			originCF,
			s,
			namePrefix .. "_CanopyVine_" .. vi,
			Vector3.new(0.55 * t, hLen * 2, 0.55 * t),
			CFrame.new(pivot - Vector3.new(0, hLen, 0)),
			pal.leafColors[2],
			Enum.Material.SmoothPlastic,
			0,
			false
		)
		vp:SetAttribute("AnimKind", "VineSway")
		vp:SetAttribute("PivotX", pivot.X)
		vp:SetAttribute("PivotY", pivot.Y)
		vp:SetAttribute("PivotZ", pivot.Z)
		vp:SetAttribute("HalfLen", hLen)
		vp:SetAttribute("Phase", phaseSeed + vi * 1.7)
		vp:SetAttribute("Amp", 0.08)
	end
end

local function buildWoodenLanternPost(
	parent: Instance,
	originCF: CFrame,
	s: number,
	pal: IslandPalette,
	localCF: CFrame,
	postHeight: number,
	namePrefix: string,
	withLight: boolean,
	phaseSeed: number
)
	-- Base stone plinth + timber upright + arm + hanging warm lantern
	makeVPart(parent, originCF, s, namePrefix .. "_Plinth", Vector3.new(1.3, 0.65, 1.3), localCF * CFrame.new(0, 0.32, 0), pal.stoneColors[2], nil, 0, false)
	makeVPart(parent, originCF, s, namePrefix .. "_Post", Vector3.new(0.65, postHeight, 0.65), localCF * CFrame.new(0, postHeight * 0.5 + 0.5, 0), pal.barkColor, nil, 0, false)
	makeVPart(parent, originCF, s, namePrefix .. "_Arm", Vector3.new(0.55, 0.55, 1.8), localCF * CFrame.new(0, postHeight + 0.35, -0.75), pal.barkDark, nil, 0, false)

	local lanternCF = localCF * CFrame.new(0, postHeight - 0.55, -1.35)
	makeVPart(parent, originCF, s, namePrefix .. "_Cap", Vector3.new(1.05, 0.32, 1.05), lanternCF * CFrame.new(0, 0.55, 0), pal.stoneColors[4], nil, 0, false)
	local core = makeVPart(parent, originCF, s, namePrefix .. "_Core", Vector3.new(0.76, 0.85, 0.76), lanternCF, pal.lanternGlow, Enum.Material.Neon, 0, false)
	makeVPart(parent, originCF, s, namePrefix .. "_Base", Vector3.new(0.95, 0.28, 0.95), lanternCF * CFrame.new(0, -0.52, 0), pal.stoneColors[4], nil, 0, false)

	if withLight then
		local pl = Instance.new("PointLight")
		pl.Name = "LanternWarmLight"
		pl.Color = pal.lanternGlow
		pl.Range = 22 * s
		pl.Brightness = 1.65
		pl.Shadows = false
		pl:SetAttribute("AnimKind", "LanternPulse")
		pl:SetAttribute("BaseBrightness", 1.65)
		pl:SetAttribute("Phase", phaseSeed)
		pl.Parent = core
	end
end

local function buildAncientRuins(parent: Instance, originCF: CFrame, s: number, pal: IslandPalette, isHero: boolean)
	-- Signature Mossy Stone Archway Ruin on the right bank (+X = 8.5, Z = -2.5) facing -Z/+X pathway
	local archCF = CFrame.new(8.6, 1.2, -3.2) * CFrame.Angles(0, math.rad(-22), 0)
	local st1, st2, st3, st4 = pal.stoneColors[1], pal.stoneColors[2], pal.stoneColors[3], pal.stoneColors[4]

	-- Twin weathered stone pillars
	for _, xSide in ipairs({ -3.2, 3.2 }) do
		local tag = if xSide < 0 then "L" else "R"
		makeVPart(parent, originCF, s, "RuinPlinth_" .. tag, Vector3.new(2.8, 1.4, 2.8), archCF * CFrame.new(xSide, 0.7, 0), st2)
		makeVPart(parent, originCF, s, "RuinColLow_" .. tag, Vector3.new(2.1, 4.4, 2.1), archCF * CFrame.new(xSide, 3.6, 0), st1)
		makeVPart(parent, originCF, s, "RuinColMid_" .. tag, Vector3.new(2.2, 3.6, 2.0), archCF * CFrame.new(xSide, 7.6, 0.1), st3)
		makeVPart(parent, originCF, s, "RuinCap_" .. tag, Vector3.new(2.6, 1.4, 2.6), archCF * CFrame.new(xSide, 9.9, 0), st2)
		-- Moss patches creeping onto masonry
		makeVPart(parent, originCF, s, "RuinMoss_" .. tag .. "1", Vector3.new(1.3, 1.1, 0.9), archCF * CFrame.new(xSide - 0.6, 2.4, -0.9), pal.mossColor, nil, 0, false)
		makeVPart(parent, originCF, s, "RuinMoss_" .. tag .. "2", Vector3.new(1.2, 0.9, 1.2), archCF * CFrame.new(xSide + 0.4, 10.7, -0.3), pal.mossColor, nil, 0, false)
	end

	-- Stepped ruined bridge arch across top
	makeVPart(parent, originCF, s, "RuinLintelCenter", Vector3.new(5.6, 1.8, 2.3), archCF * CFrame.new(0, 9.8, 0), st1)
	makeVPart(parent, originCF, s, "RuinCrownBlockA", Vector3.new(3.6, 1.4, 2.0), archCF * CFrame.new(-1.1, 11.4, 0), st3)
	makeVPart(parent, originCF, s, "RuinCrownBlockB", Vector3.new(2.2, 1.1, 1.9), archCF * CFrame.new(2.2, 11.1, 0.1), st4)
	makeVPart(parent, originCF, s, "RuinCrownMoss", Vector3.new(2.6, 0.6, 2.1), archCF * CFrame.new(-0.9, 12.25, 0), pal.mossColor, nil, 0, false)

	-- Broken low ruin wall beside archway (Top/Back View fidelity)
	makeVPart(parent, originCF, s, "RuinSideWallA", Vector3.new(2.0, 3.4, 4.2), archCF * CFrame.new(4.2, 1.7, 3.0), st2)
	makeVPart(parent, originCF, s, "RuinSideWallB", Vector3.new(1.8, 2.0, 2.4), archCF * CFrame.new(4.1, 4.0, 2.2), st1)

	-- Curved stepped cobblestone path leading from upper spring toward cliff overlook
	local pathStones = {
		{ x = 3.6, y = 2.05, z = 4.6, w = 2.6, d = 2.4, col = st1 },
		{ x = 5.4, y = 1.95, z = 1.8, w = 2.8, d = 2.6, col = st3 },
		{ x = 7.4, y = 1.65, z = -1.2, w = 3.0, d = 2.8, col = st2 },
		{ x = 8.4, y = 1.45, z = -4.8, w = 3.0, d = 2.6, col = st1 },
		{ x = 6.2, y = 1.25, z = -8.4, w = 2.8, d = 2.6, col = st3 },
		{ x = 4.0, y = 1.05, z = -11.6, w = 2.6, d = 2.4, col = st2 },
	}
	for i, ps in ipairs(pathStones) do
		makeVPart(parent, originCF, s, "PathCobble_" .. i, Vector3.new(ps.w, 0.42, ps.d), CFrame.new(ps.x, ps.y, ps.z), ps.col, nil, 0, false)
	end

	if isHero then
		-- Fallen moss-draped pillar stone near rear terrace
		makeVPart(parent, originCF, s, "FallenPillar_1", Vector3.new(4.2, 1.6, 1.7), CFrame.new(-3.2, 2.2, 11.2) * CFrame.Angles(0, math.rad(18), 0), st2)
		makeVPart(parent, originCF, s, "FallenPillarMoss", Vector3.new(2.4, 0.5, 1.5), CFrame.new(-3.4, 3.1, 11.2) * CFrame.Angles(0, math.rad(18), 0), pal.mossColor, nil, 0, false)
	end
end

local function buildWaterfallSystem(
	waterfallFolder: Folder,
	originCF: CFrame,
	s: number,
	pal: IslandPalette,
	isHero: boolean,
	hasWaterfall: boolean,
	phaseOffset: number
)
	local mainFolder = makeSubFolder("MainWaterStream", waterfallFolder)
	local secFolder = makeSubFolder("SecondaryWaterStreams", waterfallFolder)
	local segFolder = makeSubFolder("WaterSegments", waterfallFolder)
	local dropFolder = makeSubFolder("Droplets", waterfallFolder)
	local splashFolder = makeSubFolder("SplashParticles", waterfallFolder)
	local mistFolder = makeSubFolder("WaterMist", waterfallFolder)

	if not hasWaterfall then
		return
	end

	local waterMat = if pal.isVolcano then Enum.Material.Neon else Enum.Material.Glass
	local waterCoreTrans = if pal.isVolcano then 0.05 else 0.34
	local waterGlowTrans = if pal.isVolcano then 0.15 else 0.44
	local dropPlungeY = if isHero then -48.0 else -42.0
	local fallH = 1.2 - dropPlungeY
	local lipZ = -18.5

	-- 1. Upper Crystalline Spring Pool + Stepped Cascade Channel toward Front Cliff Lip
	makeVPart(mainFolder, originCF, s, "SpringPoolMain", Vector3.new(9.2, 0.9, 8.2), CFrame.new(-0.2, 2.35, 6.2), pal.waterDeep, waterMat, 0.22, false)
	makeVPart(mainFolder, originCF, s, "SpringPoolInner", Vector3.new(6.8, 0.45, 6.0), CFrame.new(-0.2, 2.65, 6.0), pal.waterBright, waterMat, 0.18, false)
	makeVPart(mainFolder, originCF, s, "UpperStepA", Vector3.new(6.6, 0.8, 6.2), CFrame.new(0, 1.95, 0.4), pal.waterDeep, waterMat, 0.25, false)
	makeVPart(mainFolder, originCF, s, "UpperStepB", Vector3.new(6.4, 0.8, 6.8), CFrame.new(0, 1.45, -5.8), pal.waterDeep, waterMat, 0.25, false)
	makeVPart(mainFolder, originCF, s, "UpperStepC", Vector3.new(6.8, 0.9, 7.6), CFrame.new(0, 1.00, -12.6), pal.waterBright, waterMat, 0.24, false)
	makeVPart(mainFolder, originCF, s, "CrestFoamLip", Vector3.new(7.2, 0.9, 1.6), CFrame.new(0, 1.12, -17.3), pal.waterFoam, Enum.Material.SmoothPlastic, 0.15, false)

	-- Volumetric Vertical Curtain Backing with softer bottom mist transition
	local bodyH = 1.2 - (dropPlungeY + 9.0)
	local bodyMidY = (1.2 + (dropPlungeY + 9.0)) * 0.5
	local tailH = 9.0
	local tailMidY = dropPlungeY + 4.5
	makeVPart(mainFolder, originCF, s, "MainCascadeVolume", Vector3.new(6.2, bodyH, 1.1), CFrame.new(0, bodyMidY, lipZ + 0.1), pal.waterDeep, waterMat, waterCoreTrans, false)
	makeVPart(mainFolder, originCF, s, "MainCascadeTail", Vector3.new(5.2, tailH, 0.9), CFrame.new(0, tailMidY, lipZ + 0.1), pal.waterBright, waterMat, if pal.isVolcano then 0.28 else 0.62, false)
	makeVPart(mainFolder, originCF, s, "MainCascadeGlow", Vector3.new(4.2, bodyH - 2.0, 1.3), CFrame.new(0, bodyMidY - 0.5, lipZ - 0.1), pal.waterBright, Enum.Material.SmoothPlastic, waterGlowTrans, false)

	-- 2. Secondary Flanking Streams following cliff rock steps
	local secRibbonH = math.abs(dropPlungeY) - 6.0
	local secMidY = (1.0 + dropPlungeY + 7.0) * 0.5
	makeVPart(secFolder, originCF, s, "LeftFlankStream", Vector3.new(1.5, secRibbonH, 0.95), CFrame.new(-3.8, secMidY, lipZ + 0.3), pal.waterBright, waterMat, 0.36, false)
	makeVPart(secFolder, originCF, s, "RightFlankStream", Vector3.new(1.7, secRibbonH * 0.92, 0.95), CFrame.new(3.7, secMidY + 1.8, lipZ + 0.4), pal.waterDeep, waterMat, 0.36, false)
	if isHero then
		-- Side cliff miniature trickle matching Front/Side Reference
		makeVPart(secFolder, originCF, s, "OuterSideTrickle", Vector3.new(1.1, 28.0, 0.8), CFrame.new(9.2, -14.5, -13.5), pal.waterBright, waterMat, 0.40, false)
	end

	-- 3. Animated Reusable WaterSegments (8..15+ continuously plunging downward + horizontal surface shimmer)
	local mainSegCount = if isHero then 12 else 8
	for i = 1, mainSegCount do
		local col = if i % 3 == 0 then pal.waterFoam elseif i % 2 == 0 then pal.waterBright else pal.waterDeep
		local laneX = (-2.3 + ((i * 1.47) % 4.6))
		local zOff = -0.35 - (i % 3) * 0.25
		local w = 1.2 + (i % 3) * 0.65
		local h = 4.6 + (i % 4) * 1.05
		local baseTrans = if pal.isVolcano then 0.05 elseif i % 3 == 0 then 0.22 else 0.32
		local phase = (phaseOffset + (i - 1) / mainSegCount) % 1
		local seg = makeVPart(
			segFolder,
			originCF,
			s,
			"WaterFlowSeg_" .. i,
			Vector3.new(w, h, 0.65),
			CFrame.new(laneX, 1.0 - phase * (fallH - 4.0), lipZ + zOff),
			col,
			if i % 3 == 0 then Enum.Material.SmoothPlastic else waterMat,
			baseTrans,
			false
		)
		seg:SetAttribute("FlowAxis", "Down")
		seg:SetAttribute("LocalX", laneX)
		seg:SetAttribute("LocalZ", lipZ + zOff)
		seg:SetAttribute("StartVal", 1.2)
		seg:SetAttribute("EndVal", dropPlungeY + 1.5)
		seg:SetAttribute("Speed", 0.42 + (i % 3) * 0.06)
		seg:SetAttribute("Phase", phase)
		seg:SetAttribute("BaseTransparency", baseTrans)
	end

	local secSegCount = if isHero then 6 else 4
	for j = 1, secSegCount do
		local sideSign = if j % 2 == 1 then -1 else 1
		local lx = sideSign * (3.7 + (j % 2) * 0.2)
		local lz = lipZ + 0.15
		local phase = (phaseOffset + j * 0.27) % 1
		local sTrans = if pal.isVolcano then 0.08 else 0.28
		local secSeg = makeVPart(
			segFolder,
			originCF,
			s,
			"SecWaterSeg_" .. j,
			Vector3.new(1.05, 4.2, 0.55),
			CFrame.new(lx, 0.5 - phase * 36, lz),
			if j % 2 == 0 then pal.waterFoam else pal.waterBright,
			Enum.Material.SmoothPlastic,
			sTrans,
			false
		)
		secSeg:SetAttribute("FlowAxis", "Down")
		secSeg:SetAttribute("LocalX", lx)
		secSeg:SetAttribute("LocalZ", lz)
		secSeg:SetAttribute("StartVal", 0.8)
		secSeg:SetAttribute("EndVal", dropPlungeY + 6.5)
		secSeg:SetAttribute("Speed", 0.34 + (j % 2) * 0.07)
		secSeg:SetAttribute("Phase", phase)
		secSeg:SetAttribute("BaseTransparency", sTrans)
	end

	-- Horizontal Surface Shimmer Strips moving from Spring Pool to Cliff Edge
	for k = 1, 4 do
		local lx = -1.6 + (k % 3) * 1.6
		local phase = (phaseOffset + (k - 1) / 4) % 1
		local hTrans = if pal.isVolcano then 0.05 else 0.25
		local hSeg = makeVPart(
			segFolder,
			originCF,
			s,
			"SurfaceFlow_" .. k,
			Vector3.new(1.4, 0.28, 3.2),
			CFrame.new(lx, 1.55, 4.0 - phase * 21.0),
			pal.waterFoam,
			Enum.Material.SmoothPlastic,
			hTrans,
			false
		)
		hSeg:SetAttribute("FlowAxis", "Forward")
		hSeg:SetAttribute("LocalX", lx)
		hSeg:SetAttribute("LocalY", 1.58)
		hSeg:SetAttribute("StartVal", 4.5)
		hSeg:SetAttribute("EndVal", -17.2)
		hSeg:SetAttribute("Speed", 0.45)
		hSeg:SetAttribute("Phase", phase)
		hSeg:SetAttribute("BaseTransparency", hTrans)
	end

	-- 4. Independent Blocky Falling Water Fragments / Droplets
	local dropCount = if isHero then 8 else 5
	for di = 1, dropCount do
		local lx = -3.4 + (di * 1.35) % 6.8
		local lz = lipZ - 0.65 - (di % 3) * 0.35
		local phase = (phaseOffset + di * 0.13) % 1
		local sz = 0.58 + (di % 3) * 0.18
		local dTrans = if pal.isVolcano then 0.0 else 0.20
		local drop = makeVPart(
			dropFolder,
			originCF,
			s,
			"WaterDroplet_" .. di,
			Vector3.new(sz, sz * 1.35, sz),
			CFrame.new(lx, -phase * 42, lz),
			if di % 2 == 0 then pal.waterFoam else pal.waterBright,
			if pal.isVolcano then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			dTrans,
			false
		)
		drop:SetAttribute("AnimKind", "Droplet")
		drop:SetAttribute("LocalX", lx)
		drop:SetAttribute("LocalZ", lz)
		drop:SetAttribute("StartY", 0.8)
		drop:SetAttribute("EndY", dropPlungeY + 1.0)
		drop:SetAttribute("OutArcZ", -1.4 - (di % 2) * 0.7)
		drop:SetAttribute("Speed", 0.48 + (di % 4) * 0.05)
		drop:SetAttribute("Phase", phase)
		drop:SetAttribute("BaseTransparency", dTrans)
	end

	-- 5. Bottom Splash Ripple Rings + ParticleEmitters (Crest, Mid-Ledge Splash, Bottom Splash & Rising Mist)
	for ri = 1, 3 do
		local ringPhase = (phaseOffset + (ri - 1) / 3) % 1
		local rw = 7.4 + ri * 1.4
		local rd = 4.6 + ri * 1.0
		local ring = makeVPart(
			splashFolder,
			originCF,
			s,
			"SplashRipple_" .. ri,
			Vector3.new(rw, 0.22, rd),
			CFrame.new(0, dropPlungeY + 0.6, lipZ),
			if ri == 2 then pal.waterBright else pal.waterFoam,
			if pal.isVolcano then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			0.40,
			false
		)
		ring:SetAttribute("AnimKind", "RippleRing")
		ring:SetAttribute("BaseLocalCF", CFrame.new(0, dropPlungeY + 0.6, lipZ))
		ring:SetAttribute("BaseSizeX", rw * s)
		ring:SetAttribute("BaseSizeY", 0.22 * s)
		ring:SetAttribute("BaseSizeZ", rd * s)
		ring:SetAttribute("Phase", ringPhase)
		ring:SetAttribute("Speed", 0.55)
	end

	-- Cliff-crest spray
	local _, crestAtt = makeAnimAttachmentPart(splashFolder, originCF, s, "CrestSprayAnchor", Vector3.new(0, 1.3, lipZ))
	local crestEm = Instance.new("ParticleEmitter")
	crestEm.Name = "CrestFoamSpray"
	crestEm.Color = ColorSequence.new(pal.waterFoam, pal.waterBright)
	crestEm.Rate = if isHero then 7 else 4
	crestEm.Lifetime = NumberRange.new(0.7, 1.3)
	crestEm.Speed = NumberRange.new(2.0, 5.0)
	crestEm.SpreadAngle = Vector2.new(45, 45)
	crestEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * s), NumberSequenceKeypoint.new(1, 1.4 * s) })
	crestEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	crestEm.EmissionDirection = Enum.NormalId.Front
	crestEm.Parent = crestAtt

	-- Mid-cliff splash shelf droplets
	local _, shelfAtt = makeAnimAttachmentPart(splashFolder, originCF, s, "MidSplashAnchor", Vector3.new(0, -16.8, lipZ - 1.0))
	local shelfEm = Instance.new("ParticleEmitter")
	shelfEm.Name = "MidLedgeDroplets"
	shelfEm.Color = ColorSequence.new(pal.waterBright, pal.waterFoam)
	shelfEm.Rate = if isHero then 8 else 5
	shelfEm.Lifetime = NumberRange.new(0.8, 1.5)
	shelfEm.Speed = NumberRange.new(3.5, 8.5)
	shelfEm.SpreadAngle = Vector2.new(75, 75)
	shelfEm.Acceleration = Vector3.new(0, -18, 0)
	shelfEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 0.1 * s) })
	shelfEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	shelfEm.EmissionDirection = Enum.NormalId.Front
	shelfEm.Parent = shelfAtt

	-- Bottom waterfall droplet & white foam dispersion
	local _, botAtt = makeAnimAttachmentPart(splashFolder, originCF, s, "BottomSplashAnchor", Vector3.new(0, dropPlungeY + 1.0, lipZ - 0.5))
	local botDrops = Instance.new("ParticleEmitter")
	botDrops.Name = "BottomWaterDroplets"
	botDrops.Color = ColorSequence.new(pal.waterDeep, pal.waterBright)
	botDrops.Rate = if isHero then 10 else 6
	botDrops.Lifetime = NumberRange.new(0.8, 1.4)
	botDrops.Speed = NumberRange.new(5.0, 11.0)
	botDrops.SpreadAngle = Vector2.new(85, 85)
	botDrops.Acceleration = Vector3.new(0, -24, 0)
	botDrops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55 * s), NumberSequenceKeypoint.new(1, 0.15 * s) })
	botDrops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	botDrops.EmissionDirection = Enum.NormalId.Top
	botDrops.Parent = botAtt

	local botFoam = Instance.new("ParticleEmitter")
	botFoam.Name = "BottomWhiteFoam"
	botFoam.Color = ColorSequence.new(pal.waterFoam, pal.waterBright)
	botFoam.Rate = if isHero then 8 else 5
	botFoam.Lifetime = NumberRange.new(1.0, 1.8)
	botFoam.Speed = NumberRange.new(2.5, 6.0)
	botFoam.SpreadAngle = Vector2.new(80, 80)
	botFoam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * s), NumberSequenceKeypoint.new(1, 2.2 * s) })
	botFoam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.30), NumberSequenceKeypoint.new(1, 1) })
	botFoam.EmissionDirection = Enum.NormalId.Top
	botFoam.Parent = botAtt

	-- Subtle Rising Waterfall Mist
	local _, midMistAtt = makeAnimAttachmentPart(mistFolder, originCF, s, "MidMistAnchor", Vector3.new(0, -24.0, lipZ - 1.2))
	local midMist = Instance.new("ParticleEmitter")
	midMist.Name = "MidWaterMist"
	midMist.Color = ColorSequence.new(pal.waterFoam, pal.waterBright)
	midMist.Rate = if isHero then 4 else 2
	midMist.Lifetime = NumberRange.new(1.6, 2.8)
	midMist.Speed = NumberRange.new(1.2, 3.0)
	midMist.SpreadAngle = Vector2.new(60, 60)
	midMist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8 * s), NumberSequenceKeypoint.new(1, 4.5 * s) })
	midMist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
	midMist.EmissionDirection = Enum.NormalId.Top
	midMist.Parent = midMistAtt

	local _, botMistAtt = makeAnimAttachmentPart(mistFolder, originCF, s, "BottomMistAnchor", Vector3.new(0, dropPlungeY + 2.5, lipZ - 0.8))
	local botMist = Instance.new("ParticleEmitter")
	botMist.Name = "BottomRisingMist"
	botMist.Color = ColorSequence.new(pal.waterFoam, Color3.new(1, 1, 1))
	botMist.Rate = if isHero then 6 else 4
	botMist.Lifetime = NumberRange.new(1.8, 3.2)
	botMist.Speed = NumberRange.new(2.0, 5.5)
	botMist.SpreadAngle = Vector2.new(75, 75)
	botMist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4 * s), NumberSequenceKeypoint.new(1, 5.8 * s) })
	botMist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
	botMist.EmissionDirection = Enum.NormalId.Top
	botMist.Parent = botMistAtt
end

--- Builds a Stylized Voxel Floating Island matching the 6-View Reference Design.
function VoxelFloatingIslandBuilder.Build(cframe: CFrame, scale: number?, opts: FloatingIslandOptions?): Model
	local s = scale or 1.0
	local options = opts or {}
	local biomeId = options.biomeId or "PineWoods"
	local pal = PALETTES[biomeId] or PALETTES.PineWoods
	local detailLevel = options.detailLevel or "Hero"
	local isHero = (detailLevel == "Hero")
	local hasWaterfall = if options.hasWaterfall ~= nil then options.hasWaterfall else true
	local modelName = options.modelName or "FloatingIsland_Waterfall"
	local phaseOffset = (math.abs(cframe.Position.X * 0.017 + cframe.Position.Z * 0.013) % 1)

	local model = Instance.new("Model")
	model.Name = modelName
	if isHero then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end

	-- Required Organised Model Structure (Section 6)
	local terrainFolder = makeSubFolder("IslandTerrain", model)
	local grassFolder = makeSubFolder("GrassSurface", model)
	local treesFolder = makeSubFolder("Trees", model)
	local vegFolder = makeSubFolder("Vegetation", model)
	local ruinsFolder = makeSubFolder("AncientRuins", model)
	local cliffsFolder = makeSubFolder("RockyCliffs", model)
	local rootsFolder = makeSubFolder("HangingRoots", model)
	local rocksFolder = makeSubFolder("FloatingRocks", model)
	local waterfallFolder = makeSubFolder("Waterfall", model)
	local envFolder = makeSubFolder("EnvironmentalEffects", model)

	local anchor = makeVPart(terrainFolder, cframe, s, "IslandCoreAnchor", Vector3.new(2.0, 2.0, 2.0), CFrame.new(0, 0, 0), pal.dirtColors[1], Enum.Material.SmoothPlastic, 1, false)
	model.PrimaryPart = anchor
	model.WorldPivot = cframe

	-- 1. GrassSurface & IslandTerrain (Notched circular/stepped upper plateau leaving waterfall chute clear!)
	local grassDeckSpecs = {
		{ x = -9.6, y = 0.2, z = 0.0, w = 15.6, h = 2.0, d = 28.0, col = pal.grassColors[1] },
		{ x = 9.6, y = 0.2, z = 0.0, w = 15.6, h = 2.0, d = 28.0, col = pal.grassColors[2] },
		{ x = 0.0, y = 0.6, z = 11.2, w = 18.0, h = 2.4, d = 11.6, col = pal.grassColors[1] },
		{ x = -1.2, y = 0.2, z = -3.8, w = 7.2, h = 1.6, d = 22.0, col = pal.grassColors[3] },
		-- Raised rear & tree hill steps
		{ x = -9.8, y = 2.0, z = 4.5, w = 13.5, h = 2.2, d = 14.5, col = pal.grassColors[3] },
		{ x = 9.8, y = 1.6, z = 3.8, w = 12.0, h = 1.8, d = 13.5, col = pal.grassColors[1] },
		{ x = -14.2, y = 0.0, z = -7.5, w = 8.4, h = 1.8, d = 12.0, col = pal.grassColors[2] },
		{ x = 14.4, y = 0.0, z = -7.0, w = 8.0, h = 1.8, d = 12.5, col = pal.grassColors[3] },
	}
	for i, gs in ipairs(grassDeckSpecs) do
		makeVPart(grassFolder, cframe, s, "GrassDeck_" .. i, Vector3.new(gs.w, gs.h, gs.d), CFrame.new(gs.x, gs.y, gs.z), gs.col)
	end

	-- Irregular overhanging grass rim lip steps along cliff perimeter
	local rimOverhangs = {
		{ x = -17.4, y = -0.3, z = -3.0, sz = Vector3.new(2.2, 1.3, 4.4), c = 1 },
		{ x = -17.0, y = -0.5, z = -10.8, sz = Vector3.new(2.0, 1.4, 3.6), c = 3 },
		{ x = 17.6, y = -0.3, z = -2.4, sz = Vector3.new(2.2, 1.3, 4.2), c = 2 },
		{ x = 16.8, y = -0.5, z = -10.4, sz = Vector3.new(2.0, 1.3, 3.4), c = 1 },
		{ x = -9.4, y = -0.4, z = -14.4, sz = Vector3.new(4.2, 1.2, 2.2), c = 3 },
		{ x = 9.4, y = -0.4, z = -14.2, sz = Vector3.new(4.0, 1.2, 2.2), c = 2 },
		{ x = -8.2, y = -0.2, z = 16.6, sz = Vector3.new(4.4, 1.3, 2.2), c = 1 },
		{ x = 7.8, y = -0.2, z = 16.4, sz = Vector3.new(4.2, 1.3, 2.2), c = 3 },
	}
	for i, ro in ipairs(rimOverhangs) do
		makeVPart(grassFolder, cframe, s, "GrassRim_" .. i, ro.sz, CFrame.new(ro.x, ro.y, ro.z), pal.grassColors[ro.c], nil, 0, false)
	end

	-- Stepped dirt rim band directly underneath grass plateau
	local dirtStrataSpecs = {
		{ x = -9.2, y = -2.0, z = 0.2, w = 15.0, h = 3.2, d = 27.0, col = pal.dirtColors[1] },
		{ x = 9.2, y = -2.0, z = 0.2, w = 15.0, h = 3.2, d = 27.0, col = pal.dirtColors[2] },
		{ x = 0.0, y = -1.8, z = 10.6, w = 17.0, h = 3.0, d = 11.0, col = pal.dirtColors[1] },
		{ x = 0.0, y = -2.2, z = -5.0, w = 7.4, h = 3.2, d = 21.0, col = pal.dirtColors[2] },
	}
	for i, ds in ipairs(dirtStrataSpecs) do
		makeVPart(terrainFolder, cframe, s, "DirtStrata_" .. i, Vector3.new(ds.w, ds.h, ds.d), CFrame.new(ds.x, ds.y, ds.z), ds.col)
	end

	-- 2. RockyCliffs: Tapered Irregular Poly-Voxel Floating Island Underbelly (Y = -3.4 .. -28.0)
	local cliffBlocks = {
		-- Flanking stone cliff buttresses around the front waterfall chute
		{ x = -5.6, y = -1.0, z = -15.6, w = 4.6, h = 5.4, d = 4.8, c = 1 },
		{ x = 5.6, y = -1.0, z = -15.6, w = 4.6, h = 5.4, d = 4.8, c = 2 },
		{ x = -11.5, y = -2.6, z = -14.0, w = 7.8, h = 5.2, d = 6.5, c = 3 },
		{ x = 11.5, y = -2.6, z = -13.8, w = 7.6, h = 5.2, d = 6.5, c = 1 },
		-- Upper rock ring (-4.5 .. -10.5)
		{ x = -8.5, y = -6.8, z = -6.2, w = 12.4, h = 7.2, d = 14.0, c = 2 },
		{ x = 8.4, y = -7.0, z = -5.8, w = 12.2, h = 7.4, d = 14.2, c = 1 },
		{ x = -6.8, y = -6.6, z = 7.8, w = 12.6, h = 7.0, d = 13.0, c = 3 },
		{ x = 7.0, y = -6.8, z = 7.6, w = 12.4, h = 7.2, d = 13.2, c = 2 },
		{ x = 0.0, y = -7.2, z = 0.5, w = 14.0, h = 7.6, d = 15.0, c = 4 },
		{ x = -14.8, y = -5.2, z = 0.8, w = 5.8, h = 6.2, d = 11.2, c = 1 },
		{ x = 14.8, y = -5.4, z = 1.2, w = 5.6, h = 6.0, d = 10.6, c = 3 },
		-- Mid cliff ring (-11.0 .. -18.5)
		{ x = -4.6, y = -13.8, z = -4.0, w = 9.2, h = 7.8, d = 10.2, c = 1 },
		{ x = 4.8, y = -14.2, z = -3.8, w = 9.0, h = 7.6, d = 10.0, c = 4 },
		{ x = -3.8, y = -13.5, z = 5.6, w = 8.8, h = 7.4, d = 9.6, c = 3 },
		{ x = 4.0, y = -14.0, z = 5.8, w = 8.8, h = 7.4, d = 9.6, c = 2 },
		{ x = -9.6, y = -12.0, z = 0.2, w = 4.8, h = 6.4, d = 8.4, c = 2 },
		{ x = 9.6, y = -12.4, z = -0.2, w = 4.8, h = 6.2, d = 8.2, c = 1 },
		-- Jutting waterfall splash shelf ledge
		{ x = -2.2, y = -16.8, z = -15.8, w = 4.6, h = 3.8, d = 4.4, c = 3 },
		{ x = 2.6, y = -17.4, z = -15.4, w = 4.4, h = 4.2, d = 4.4, c = 2 },
		-- Tapered deep spire keel (-18.5 .. -28.0)
		{ x = -1.6, y = -20.5, z = -1.2, w = 7.2, h = 6.8, d = 7.6, c = 4 },
		{ x = 1.8, y = -21.2, z = 1.4, w = 6.6, h = 6.6, d = 7.2, c = 2 },
		{ x = 0.2, y = -25.4, z = -0.2, w = 5.2, h = 6.4, d = 5.4, c = 1 },
		{ x = -0.4, y = -29.2, z = 0.3, w = 2.8, h = 4.6, d = 2.8, c = 4 },
		-- Outer stepped craggy rock outcrops breaking up side & front cliff silhouettes
		{ x = -16.8, y = -4.2, z = -1.6, w = 2.8, h = 4.2, d = 4.2, c = 3 },
		{ x = -16.2, y = -7.4, z = 5.0, w = 2.6, h = 4.6, d = 3.8, c = 4 },
		{ x = 16.8, y = -4.0, z = -2.2, w = 2.8, h = 4.4, d = 4.4, c = 2 },
		{ x = 16.2, y = -7.6, z = 4.8, w = 2.6, h = 4.6, d = 3.8, c = 1 },
		{ x = -7.8, y = -11.4, z = -11.4, w = 4.2, h = 5.4, d = 4.0, c = 4 },
		{ x = 7.6, y = -11.8, z = -11.0, w = 4.2, h = 5.2, d = 4.0, c = 3 },
	}
	if isHero then
		table.insert(cliffBlocks, { x = -16.2, y = -4.2, z = -8.4, w = 3.4, h = 4.4, d = 4.2, c = 2 })
		table.insert(cliffBlocks, { x = 16.0, y = -4.6, z = -8.2, w = 3.2, h = 4.2, d = 4.0, c = 4 })
		table.insert(cliffBlocks, { x = 0.0, y = -10.8, z = 13.8, w = 7.2, h = 6.2, d = 4.6, c = 1 })
		table.insert(cliffBlocks, { x = -4.6, y = -19.2, z = -8.2, w = 3.4, h = 4.8, d = 3.4, c = 1 })
		table.insert(cliffBlocks, { x = 4.4, y = -22.8, z = -3.8, w = 3.4, h = 5.6, d = 3.4, c = 3 })
	end
	for i, cb in ipairs(cliffBlocks) do
		makeVPart(cliffsFolder, cframe, s, "CliffBlock_" .. i, Vector3.new(cb.w, cb.h, cb.d), CFrame.new(cb.x, cb.y, cb.z), pal.stoneColors[cb.c])
	end

	-- Moss & cliff crevices tucked onto rocky upper edges
	local cliffMossSpots = {
		Vector3.new(-15.6, -2.4, -4.0),
		Vector3.new(15.6, -2.6, -3.5),
		Vector3.new(-10.8, -4.6, -15.4),
		Vector3.new(10.8, -4.8, 12.2),
		Vector3.new(-4.8, -7.8, -14.8),
	}
	for i, mp in ipairs(cliffMossSpots) do
		makeVPart(cliffsFolder, cframe, s, "CliffMoss_" .. i, Vector3.new(2.2, 1.4, 2.0), CFrame.new(mp), pal.mossColor, nil, 0, false)
	end

	-- 3. Trees (Multi-tier Hero Oak + Secondary & Back Canopy Trees matching Top/Front/Side Views)
	buildVoxelTree(treesFolder, cframe, s, pal, Vector3.new(-9.6, 3.0, 2.6), 1.18, isHero, "HeroOak", phaseOffset)
	buildVoxelTree(treesFolder, cframe, s, pal, Vector3.new(12.2, 2.4, 7.2), 0.88, false, "EastTree", phaseOffset + 1.4)
	if isHero then
		buildVoxelTree(treesFolder, cframe, s, pal, Vector3.new(-1.8, 2.0, 12.6), 0.78, false, "RearTree", phaseOffset + 2.7)
	end

	-- 4. AncientRuins (Stone Archway + Curved Cobble Path)
	buildAncientRuins(ruinsFolder, cframe, s, pal, isHero)

	-- 5. Vegetation (Mossy Boulders, Bushes, Ferns, Wildflowers, & Stream-Side Wooden Railing)
	local boulders = {
		{ x = -4.2, y = 2.0, z = 6.4, sz = Vector3.new(2.4, 1.6, 2.2) },
		{ x = 3.8, y = 2.0, z = 7.4, sz = Vector3.new(2.2, 1.5, 2.2) },
		{ x = -13.8, y = 1.6, z = -4.2, sz = Vector3.new(2.6, 1.6, 2.4) },
		{ x = 13.6, y = 1.4, z = -10.8, sz = Vector3.new(2.2, 1.4, 2.0) },
	}
	for i, bd in ipairs(boulders) do
		makeVPart(vegFolder, cframe, s, "MossBoulder_" .. i, bd.sz, CFrame.new(bd.x, bd.y, bd.z), pal.stoneColors[2], nil, 0, false)
		makeVPart(vegFolder, cframe, s, "MossBoulderCap_" .. i, Vector3.new(bd.sz.X * 0.8, 0.35, bd.sz.Z * 0.8), CFrame.new(bd.x, bd.y + bd.sz.Y * 0.5 + 0.12, bd.z), pal.mossColor, nil, 0, false)
	end

	local bushes = {
		Vector3.new(-6.6, 2.2, -2.5),
		Vector3.new(-12.4, 1.8, -11.2),
		Vector3.new(5.2, 2.0, 10.6),
		Vector3.new(13.8, 1.8, 1.4),
		Vector3.new(-4.8, 1.8, -14.2),
	}
	for i, bp in ipairs(bushes) do
		makeVPart(vegFolder, cframe, s, "BushLow_" .. i, Vector3.new(2.4, 1.3, 2.2), CFrame.new(bp), pal.leafColors[1], nil, 0, false)
		makeVPart(vegFolder, cframe, s, "BushTop_" .. i, Vector3.new(1.5, 0.9, 1.4), CFrame.new(bp + Vector3.new(0, 0.9, 0)), pal.leafColors[3], nil, 0, false)
	end

	-- Stream-side Wooden Railing matching Close-Up Detail
	makeVPart(vegFolder, cframe, s, "FencePost_1", Vector3.new(0.45, 1.9, 0.45), CFrame.new(-4.4, 2.0, -7.2), pal.barkColor, nil, 0, false)
	makeVPart(vegFolder, cframe, s, "FencePost_2", Vector3.new(0.45, 1.9, 0.45), CFrame.new(-4.4, 1.8, -11.4), pal.barkColor, nil, 0, false)
	makeVPart(vegFolder, cframe, s, "FenceRailTop", Vector3.new(0.32, 0.32, 4.6), CFrame.new(-4.4, 2.45, -9.3), pal.barkColor, nil, 0, false)
	makeVPart(vegFolder, cframe, s, "FenceRailBot", Vector3.new(0.28, 0.28, 4.6), CFrame.new(-4.4, 1.75, -9.3), pal.barkDark, nil, 0, false)

	-- Wildflowers & Grass Tufts
	local flowerSpots = {
		Vector3.new(-7.4, 1.5, -10.8),
		Vector3.new(-10.2, 1.5, -7.8),
		Vector3.new(5.6, 1.5, -12.6),
		Vector3.new(11.6, 1.5, -8.2),
		Vector3.new(3.2, 2.2, 2.2),
		Vector3.new(-6.0, 2.5, 8.6),
		Vector3.new(10.8, 2.0, 11.4),
	}
	local flowerCount = if isHero then #flowerSpots else 4
	for fi = 1, flowerCount do
		local fp = flowerSpots[fi]
		local fCol = pal.flowerColors[((fi - 1) % #pal.flowerColors) + 1]
		makeVPart(vegFolder, cframe, s, "FernBase_" .. fi, Vector3.new(1.1, 0.55, 1.1), CFrame.new(fp), pal.leafColors[2], nil, 0, false)
		makeVPart(vegFolder, cframe, s, "FlowerBloom_" .. fi, Vector3.new(0.65, 0.45, 0.65), CFrame.new(fp + Vector3.new(0, 0.45, 0)), fCol, nil, 0, false)
	end

	-- 6. HangingRoots & Swaying Vines around Cliff Overhangs & Underbelly
	local vineDefs = {
		{ x = -15.8, y = -0.8, z = -9.6, len = 6.2, isRoot = false },
		{ x = -16.8, y = -0.6, z = 2.4, len = 7.4, isRoot = false },
		{ x = 16.4, y = -0.6, z = -4.4, len = 6.8, isRoot = false },
		{ x = 14.8, y = -0.8, z = -12.2, len = 8.2, isRoot = false },
		{ x = -8.6, y = -3.4, z = -16.2, len = 5.4, isRoot = false },
		{ x = 8.4, y = -3.4, z = -16.0, len = 6.0, isRoot = false },
		{ x = -2.2, y = -2.6, z = 15.8, len = 7.2, isRoot = false },
		{ x = -6.8, y = -12.5, z = 1.4, len = 6.5, isRoot = true },
		{ x = 6.4, y = -13.0, z = -2.2, len = 6.0, isRoot = true },
		{ x = 1.6, y = -24.5, z = 2.0, len = 5.8, isRoot = true },
	}
	if isHero then
		table.insert(vineDefs, { x = 16.8, y = -0.8, z = 7.6, len = 7.8, isRoot = false })
		table.insert(vineDefs, { x = -11.4, y = -14.2, z = -6.8, len = 5.2, isRoot = false })
	end
	for i, vd in ipairs(vineDefs) do
		local halfL = vd.len * 0.5
		local col = if vd.isRoot then pal.barkDark else pal.leafColors[((i - 1) % 2) + 1]
		local mat = if pal.isVolcano and vd.isRoot then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if pal.isVolcano and vd.isRoot then
			col = pal.mossColor
		end
		local vp = makeVPart(
			rootsFolder,
			cframe,
			s,
			(if vd.isRoot then "HangingRoot_" else "HangingVine_") .. i,
			Vector3.new(0.68, vd.len, 0.68),
			CFrame.new(vd.x, vd.y - halfL, vd.z),
			col,
			mat,
			0,
			false
		)
		vp:SetAttribute("AnimKind", "VineSway")
		vp:SetAttribute("PivotX", vd.x)
		vp:SetAttribute("PivotY", vd.y)
		vp:SetAttribute("PivotZ", vd.z)
		vp:SetAttribute("HalfLen", halfL)
		vp:SetAttribute("Phase", phaseOffset + i * 0.72)
		vp:SetAttribute("Amp", if vd.isRoot then 0.04 else 0.09)
	end

	-- 7. Detached FloatingRocks hovering around the tapered keel (animated gently via FloatBob)
	local rockSpecs = {
		{ x = -13.5, y = -19.5, z = -10.5, sz = Vector3.new(2.6, 3.2, 2.4) },
		{ x = 12.8, y = -22.0, z = -9.5, sz = Vector3.new(2.4, 3.6, 2.4) },
		{ x = -6.5, y = -28.5, z = 6.5, sz = Vector3.new(2.2, 2.8, 2.2) },
		{ x = 7.8, y = -16.5, z = 12.0, sz = Vector3.new(2.8, 2.6, 2.6) },
		{ x = -17.5, y = -10.5, z = 4.5, sz = Vector3.new(2.2, 2.8, 2.2) },
	}
	if isHero then
		table.insert(rockSpecs, { x = 0.8, y = -34.0, z = -1.5, sz = Vector3.new(1.8, 2.6, 1.8) })
		table.insert(rockSpecs, { x = 16.5, y = -11.5, z = -5.5, sz = Vector3.new(2.0, 2.4, 2.0) })
	end
	for i, rs in ipairs(rockSpecs) do
		local rCF = CFrame.new(rs.x, rs.y, rs.z) * CFrame.Angles(0, math.rad(i * 25), 0)
		local rk = makeVPart(rocksFolder, cframe, s, "FloatingRock_" .. i, rs.sz, rCF, pal.stoneColors[((i - 1) % #pal.stoneColors) + 1], nil, 0, false)
		rk:SetAttribute("AnimKind", "FloatBob")
		rk:SetAttribute("BaseLocalCF", rCF)
		rk:SetAttribute("Phase", phaseOffset + i * 0.95)
		rk:SetAttribute("BobAmp", 0.65)
	end

	-- 8. Waterfall (MainWaterStream, SecondaryWaterStreams, WaterSegments, Droplets, SplashParticles, WaterMist)
	buildWaterfallSystem(waterfallFolder, cframe, s, pal, isHero, hasWaterfall, phaseOffset)

	-- 9. EnvironmentalEffects (Warm Lantern Posts + Selective Fireflies & Leaf Motes)
	buildWoodenLanternPost(envFolder, cframe, s, pal, CFrame.new(-7.4, 1.3, -12.8) * CFrame.Angles(0, math.rad(25), 0), 3.4, "LanternWest", true, phaseOffset)
	buildWoodenLanternPost(envFolder, cframe, s, pal, CFrame.new(11.4, 1.3, -9.2) * CFrame.Angles(0, math.rad(-25), 0), 3.2, "LanternEast", isHero, phaseOffset + 1.2)
	if isHero then
		buildWoodenLanternPost(envFolder, cframe, s, pal, CFrame.new(-1.8, 2.1, 8.8) * CFrame.Angles(0, math.rad(150), 0), 3.0, "LanternRear", false, phaseOffset + 2.4)
	end

	-- Fireflies near lush foliage
	local _, fireflyAtt = makeAnimAttachmentPart(envFolder, cframe, s, "FireflyAnchor", Vector3.new(-4.0, 5.2, 1.0))
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "FloatingFireflies"
	fireflies.Color = ColorSequence.new(
		if pal.isVolcano then Color3.fromRGB(255, 132, 42) else Color3.fromRGB(204, 255, 128),
		Color3.fromRGB(255, 234, 118)
	)
	fireflies.Rate = if isHero then 5 else 2
	fireflies.Lifetime = NumberRange.new(2.5, 4.2)
	fireflies.Speed = NumberRange.new(0.6, 1.8)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.LightEmission = 1
	fireflies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.34 * s), NumberSequenceKeypoint.new(1, 0) })
	fireflies.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.15), NumberSequenceKeypoint.new(1, 1) })
	fireflies.Parent = fireflyAtt

	if isHero then
		local _, moteAtt = makeAnimAttachmentPart(envFolder, cframe, s, "AmbientMoteAnchor", Vector3.new(2.0, 7.0, 0))
		local motes = Instance.new("ParticleEmitter")
		motes.Name = "DriftingLeafMotes"
		motes.Color = ColorSequence.new(pal.leafColors[2], pal.leafColors[3])
		motes.Rate = 3
		motes.Lifetime = NumberRange.new(3.0, 5.0)
		motes.Speed = NumberRange.new(0.8, 2.0)
		motes.SpreadAngle = Vector2.new(180, 90)
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * s), NumberSequenceKeypoint.new(1, 0.1 * s) })
		motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		motes.Parent = moteAtt
	end

	model:SetAttribute("HasAnimatedWaterfall", hasWaterfall)
	model:SetAttribute("HasEnvironmentalAnim", true)
	model:SetAttribute("IslandBiomeId", biomeId)
	model:SetAttribute("IslandScale", s)
	model:SetAttribute("DetailLevel", detailLevel)

	if options.parent then
		model.Parent = options.parent
	end
	return model
end

return VoxelFloatingIslandBuilder
