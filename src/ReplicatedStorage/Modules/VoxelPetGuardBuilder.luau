--!strict
-- VoxelPetGuardBuilder.luau
-- Builds the 5-Biome Voxel Pet Guard / Enemy Collection based on the 5-View Reference Design
-- (Wide-rimmed horned hat with front Paw Crest, fierce glowing eyes, high scarf cowl,
--  heavy gold-trimmed pauldrons, Left-Chest Paw Medallion, Left-Hip Capture Lantern,
--  Net Staff capture hoop weapon, and tattered cape with Giant Back Glowing Paw Emblem).
-- Higher biome tiers scale dramatically taller, broader, more ornate, and more menacing.
-- Pure Roblox Parts (Anchored, CanCollide = false by default, zero external asset IDs).

local VoxelPetGuardBuilder = {}

export type GuardPalette = {
	armorDark: Color3,
	armorMid: Color3,
	armorLight: Color3,
	headShadow: Color3,
	cloakPrimary: Color3,
	cloakSecondary: Color3,
	cloakTip: Color3,
	trimGold: Color3,
	trimGoldDark: Color3,
	neonPrimary: Color3,
	neonSecondary: Color3,
	eyeCore: Color3,
	hornDark: Color3,
	hornTip: Color3,
	netMeshColor: Color3,
}

export type GuardTierConfig = {
	tier: number,
	biomeId: string,
	biomeName: string,
	title: string,
	subtitle: string,
	difficulty: string,
	scale: number,
	widthMult: number,
	shoulderMult: number,
	hornScale: number,
	palette: GuardPalette,
}

export type GuardAnimMode = "Idle" | "Walk" | "Chase" | "Attack"

export type BuildOptions = {
	scale: number?,
	parent: Instance?,
	canCollide: boolean?,
	withEffects: boolean?,
	rigged: boolean?,
	isBoss: boolean?,
}

VoxelPetGuardBuilder.BIOME_ORDER = {
	"PineWoods",
	"MangroveSwamp",
	"SavannaCamp",
	"AlpinePeaks",
	"VolcanicJungle",
}

local TIER_CONFIGS: { [string]: GuardTierConfig } = {
	PineWoods = {
		tier = 1,
		biomeId = "PineWoods",
		biomeName = "Whispering Pine Woods",
		title = "Pine Woods Scout Guard",
		subtitle = "Biome 1 Patrol • Agile Forest Warden",
		difficulty = "Easy",
		scale = 1.00,
		widthMult = 1.00,
		shoulderMult = 1.00,
		hornScale = 1.00,
		palette = {
			armorDark = Color3.fromRGB(34, 42, 38),
			armorMid = Color3.fromRGB(48, 58, 52),
			armorLight = Color3.fromRGB(64, 76, 68),
			headShadow = Color3.fromRGB(16, 18, 22),
			cloakPrimary = Color3.fromRGB(44, 108, 56),
			cloakSecondary = Color3.fromRGB(62, 146, 74),
			cloakTip = Color3.fromRGB(92, 232, 118),
			trimGold = Color3.fromRGB(238, 174, 48),
			trimGoldDark = Color3.fromRGB(178, 122, 28),
			neonPrimary = Color3.fromRGB(88, 255, 132),
			neonSecondary = Color3.fromRGB(148, 255, 182),
			eyeCore = Color3.fromRGB(220, 255, 228),
			hornDark = Color3.fromRGB(48, 42, 36),
			hornTip = Color3.fromRGB(238, 174, 48),
			netMeshColor = Color3.fromRGB(210, 232, 220),
		},
	},
	MangroveSwamp = {
		tier = 2,
		biomeId = "MangroveSwamp",
		biomeName = "Muddy Mangrove Swamp",
		title = "Swamp Bog Stalker",
		subtitle = "Biome 2 Enforcer • Venomous Marsh Hunter",
		difficulty = "Medium",
		scale = 1.18,
		widthMult = 1.04,
		shoulderMult = 1.08,
		hornScale = 1.16,
		palette = {
			armorDark = Color3.fromRGB(30, 40, 44),
			armorMid = Color3.fromRGB(42, 56, 60),
			armorLight = Color3.fromRGB(58, 76, 80),
			headShadow = Color3.fromRGB(14, 18, 22),
			cloakPrimary = Color3.fromRGB(34, 92, 88),
			cloakSecondary = Color3.fromRGB(46, 136, 124),
			cloakTip = Color3.fromRGB(62, 224, 198),
			trimGold = Color3.fromRGB(222, 168, 56),
			trimGoldDark = Color3.fromRGB(158, 114, 34),
			neonPrimary = Color3.fromRGB(48, 248, 210),
			neonSecondary = Color3.fromRGB(132, 255, 168),
			eyeCore = Color3.fromRGB(214, 255, 246),
			hornDark = Color3.fromRGB(36, 46, 44),
			hornTip = Color3.fromRGB(48, 248, 210),
			netMeshColor = Color3.fromRGB(194, 235, 228),
		},
	},
	SavannaCamp = {
		tier = 3,
		biomeId = "SavannaCamp",
		biomeName = "Savanna Poacher Camp",
		title = "Savanna Sun Warden",
		subtitle = "Biome 3 Champion • Pharaoh Obsidian Sentinel",
		difficulty = "Hard",
		scale = 1.40,
		widthMult = 1.09,
		shoulderMult = 1.16,
		hornScale = 1.32,
		palette = {
			armorDark = Color3.fromRGB(44, 34, 30),
			armorMid = Color3.fromRGB(64, 48, 42),
			armorLight = Color3.fromRGB(84, 64, 52),
			headShadow = Color3.fromRGB(18, 14, 16),
			cloakPrimary = Color3.fromRGB(142, 52, 26),
			cloakSecondary = Color3.fromRGB(186, 78, 32),
			cloakTip = Color3.fromRGB(255, 144, 42),
			trimGold = Color3.fromRGB(255, 196, 48),
			trimGoldDark = Color3.fromRGB(196, 134, 24),
			neonPrimary = Color3.fromRGB(255, 148, 34),
			neonSecondary = Color3.fromRGB(255, 214, 72),
			eyeCore = Color3.fromRGB(255, 244, 200),
			hornDark = Color3.fromRGB(48, 36, 30),
			hornTip = Color3.fromRGB(255, 196, 48),
			netMeshColor = Color3.fromRGB(242, 228, 204),
		},
	},
	AlpinePeaks = {
		tier = 4,
		biomeId = "AlpinePeaks",
		biomeName = "Frostbite Alpine Peaks",
		title = "Glacier Dread Knight",
		subtitle = "Biome 4 Warlord • Cryo-Armored Permafrost Executioner",
		difficulty = "Extreme",
		scale = 1.65,
		widthMult = 1.15,
		shoulderMult = 1.25,
		hornScale = 1.48,
		palette = {
			armorDark = Color3.fromRGB(24, 32, 52),
			armorMid = Color3.fromRGB(36, 48, 76),
			armorLight = Color3.fromRGB(54, 72, 108),
			headShadow = Color3.fromRGB(12, 16, 26),
			cloakPrimary = Color3.fromRGB(40, 74, 148),
			cloakSecondary = Color3.fromRGB(64, 124, 208),
			cloakTip = Color3.fromRGB(108, 228, 255),
			trimGold = Color3.fromRGB(238, 204, 112),
			trimGoldDark = Color3.fromRGB(154, 178, 212),
			neonPrimary = Color3.fromRGB(72, 226, 255),
			neonSecondary = Color3.fromRGB(182, 246, 255),
			eyeCore = Color3.fromRGB(236, 252, 255),
			hornDark = Color3.fromRGB(34, 46, 72),
			hornTip = Color3.fromRGB(118, 236, 255),
			netMeshColor = Color3.fromRGB(218, 244, 255),
		},
	},
	VolcanicJungle = {
		tier = 5,
		biomeId = "VolcanicJungle",
		biomeName = "Volcanic Obsidian Jungle",
		title = "Abyssal Dread Overlord",
		subtitle = "Biome 5 Apex • Quad-Horned Infernal Sovereign",
		difficulty = "Nightmare",
		scale = 1.96,
		widthMult = 1.22,
		shoulderMult = 1.34,
		hornScale = 1.70,
		palette = {
			armorDark = Color3.fromRGB(26, 20, 34),
			armorMid = Color3.fromRGB(40, 30, 52),
			armorLight = Color3.fromRGB(58, 42, 74),
			headShadow = Color3.fromRGB(10, 8, 16),
			cloakPrimary = Color3.fromRGB(102, 28, 176),
			cloakSecondary = Color3.fromRGB(154, 44, 228),
			cloakTip = Color3.fromRGB(255, 86, 48),
			trimGold = Color3.fromRGB(255, 184, 38),
			trimGoldDark = Color3.fromRGB(196, 122, 20),
			neonPrimary = Color3.fromRGB(204, 68, 255),
			neonSecondary = Color3.fromRGB(255, 92, 34),
			eyeCore = Color3.fromRGB(255, 218, 255),
			hornDark = Color3.fromRGB(28, 20, 38),
			hornTip = Color3.fromRGB(255, 98, 42),
			netMeshColor = Color3.fromRGB(236, 216, 248),
		},
	},
}

function VoxelPetGuardBuilder.GetConfig(biomeId: string): GuardTierConfig
	return TIER_CONFIGS[biomeId] or TIER_CONFIGS.PineWoods
end

type RigState = {
	hubs: { [string]: Part },
	activeBone: Part?,
	partToBone: { [BasePart]: Part },
	boneSet: { [string]: boolean },
}

local activeRigState: RigState? = nil

local function setActiveBone(rigState: RigState?, hubName: string?)
	if not rigState then
		return
	end
	rigState.activeBone = if hubName then rigState.hubs[hubName] else nil
end

local function createBoneHub(model: Model, rigState: RigState?, name: string, unscaledPos: Vector3, s: number): Part?
	if not rigState then
		return nil
	end
	local hub = Instance.new("Part")
	hub.Name = name
	hub.Size = Vector3.new(0.24 * s, 0.24 * s, 0.24 * s)
	hub.CFrame = CFrame.new(unscaledPos * s)
	hub.Color = Color3.new(1, 1, 1)
	hub.Material = Enum.Material.SmoothPlastic
	hub.Transparency = 1
	hub.TopSurface = Enum.SurfaceType.Smooth
	hub.BottomSurface = Enum.SurfaceType.Smooth
	hub.Anchored = true
	hub.Massless = false
	hub.CanCollide = false
	hub.CanQuery = false
	hub.CanTouch = false
	hub.CastShadow = false
	hub.Parent = model
	rigState.hubs[name] = hub
	rigState.boneSet[name] = true
	return hub
end

local function attachMotor(jointName: string, part0: BasePart, part1: BasePart, worldPivot: Vector3): Motor6D
	local pivotCF = CFrame.new(worldPivot)
	local m = Instance.new("Motor6D")
	m.Name = jointName
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(pivotCF)
	m.C1 = part1.CFrame:ToObjectSpace(pivotCF)
	m.CurrentAngle = 0
	m.MaxVelocity = 0.25
	m:SetAttribute("BaseC0", m.C0)
	m.Parent = part0
	return m
end

-- Uses uniform scale `s` so rotated hoops, horns, gauntlets & paws never skew or warp.
local function makeBox(
	model: Model,
	rootCF: CFrame,
	s: number,
	name: string,
	size: Vector3,
	localCF: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size * s
	local pos = localCF.Position
	local rot = localCF - localCF.Position
	p.CFrame = rootCF * CFrame.new(pos * s) * rot
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if canCollide ~= nil then canCollide else false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = transparency or 0
	p.CastShadow = (transparency or 0) < 0.8
	p.Parent = model
	if activeRigState and activeRigState.activeBone and name ~= "HumanoidRootPart" then
		activeRigState.partToBone[p] = activeRigState.activeBone
		p:SetAttribute("BoneCluster", activeRigState.activeBone.Name)
	end
	return p
end

-- Renders a 3D sculpted Voxel Paw Print centered at localCF facing outward along localCF.LookVector (-Z in local space)
local function build3DVoxelPaw(
	model: Model,
	rootCF: CFrame,
	s: number,
	prefix: string,
	localCF: CFrame,
	pawScale: number,
	neonColor: Color3,
	canCollide: boolean
)
	local d = 0.14 * pawScale
	local ps = pawScale
	-- Main stepped palm pad (wider base + tapered upper notch)
	makeBox(model, rootCF, s, prefix .. "_Palm", Vector3.new(0.42 * ps, 0.30 * ps, d), localCF * CFrame.new(0, -0.10 * ps, 0), neonColor, Enum.Material.Neon, canCollide)
	makeBox(model, rootCF, s, prefix .. "_PalmTop", Vector3.new(0.28 * ps, 0.12 * ps, d), localCF * CFrame.new(0, 0.08 * ps, 0), neonColor, Enum.Material.Neon, canCollide)

	-- Four splayed toe beans cleanly separated from palm pad
	local toes = {
		{ x = -0.27 * ps, y = 0.14 * ps, w = 0.11 * ps, h = 0.16 * ps, rot = 18 },
		{ x = -0.10 * ps, y = 0.30 * ps, w = 0.12 * ps, h = 0.18 * ps, rot = 6 },
		{ x = 0.10 * ps, y = 0.30 * ps, w = 0.12 * ps, h = 0.18 * ps, rot = -6 },
		{ x = 0.27 * ps, y = 0.14 * ps, w = 0.11 * ps, h = 0.16 * ps, rot = -18 },
	}
	for i, t in ipairs(toes) do
		makeBox(
			model,
			rootCF,
			s,
			prefix .. "_Toe" .. i,
			Vector3.new(t.w, t.h, d),
			localCF * CFrame.new(t.x, t.y, 0) * CFrame.Angles(0, 0, math.rad(t.rot)),
			neonColor,
			Enum.Material.Neon,
			canCollide
		)
	end
end

-- 1. Boots, Greaves & Heroic Leg Stance (Y = 0.00 .. 2.30)
local function buildLegsAndBoots(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, cc: boolean, rigState: RigState?)
	local pal = cfg.palette
	local wM = cfg.widthMult
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "L" else "R"
		local legX = side * 0.72 * (0.94 + wM * 0.06)
		local yaw = side * math.rad(-7)
		local legCF = CFrame.new(legX, 0, 0) * CFrame.Angles(0, yaw, 0)

		createBoneHub(model, rigState, "Foot" .. tag, Vector3.new(legX, 0.55, 0), s)
		setActiveBone(rigState, "Foot" .. tag)

		-- Thick dark armored sole tread (Bottom View accurate)
		makeBox(model, rootCF, s, "BootSole_" .. tag, Vector3.new(1.06, 0.26, 1.48), legCF * CFrame.new(0, 0.13, -0.12), pal.armorDark, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "BootHeelTrim_" .. tag, Vector3.new(1.08, 0.20, 0.36), legCF * CFrame.new(0, 0.30, 0.44), pal.trimGold, Enum.Material.Metal, cc)

		-- Main stepped boot upper & chunky gold toe cap
		makeBox(model, rootCF, s, "BootToeCap_" .. tag, Vector3.new(1.02, 0.36, 0.42), legCF * CFrame.new(0, 0.38, -0.64), pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "BootUpper_" .. tag, Vector3.new(0.98, 0.68, 1.12), legCF * CFrame.new(0, 0.60, -0.02), pal.armorMid, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "BootCuffTrim_" .. tag, Vector3.new(1.06, 0.16, 1.18), legCF * CFrame.new(0, 0.96, -0.02), pal.trimGold, Enum.Material.Metal, cc)

		createBoneHub(model, rigState, "Leg" .. tag, Vector3.new(legX, 1.56, 0), s)
		setActiveBone(rigState, "Leg" .. tag)

		-- Greaves, Kneecap & Outer Neon Seam
		makeBox(model, rootCF, s, "Greave_" .. tag, Vector3.new(0.92, 1.15, 0.96), legCF * CFrame.new(0, 1.54, 0.02), pal.armorDark, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "KneePlate_" .. tag, Vector3.new(0.98, 0.50, 0.28), legCF * CFrame.new(0, 1.72, -0.44), pal.armorMid, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "KneeGoldRim_" .. tag, Vector3.new(1.02, 0.14, 0.32), legCF * CFrame.new(0, 1.98, -0.44), pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "GreaveNeon_" .. tag, Vector3.new(0.12, 0.68, 0.18), legCF * CFrame.new(side * 0.48, 1.38, 0.02), pal.neonPrimary, Enum.Material.Neon, cc)
	end
end

-- 2. Waist Belt, Split Coat Tails & Left-Hip Capture Lantern (Y = 1.05 .. 2.85)
local function buildBeltAndLantern(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, cc: boolean, withEffects: boolean, rigState: RigState?): Vector3
	local pal = cfg.palette
	local wM = cfg.widthMult

	createBoneHub(model, rigState, "Pelvis", Vector3.new(0, 2.28, 0), s)
	setActiveBone(rigState, "Pelvis")

	-- Pelvic armor & recessed front tabard
	makeBox(model, rootCF, s, "PelvisCore", Vector3.new(2.26 * wM, 0.80, 1.24), CFrame.new(0, 2.28, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "FrontTabard", Vector3.new(0.76, 1.08, 0.18), CFrame.new(0, 1.74, -0.62), pal.cloakPrimary, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "FrontTabardNeon", Vector3.new(0.28, 0.18, 0.20), CFrame.new(0, 1.24, -0.63), pal.neonPrimary, Enum.Material.Neon, cc)

	-- Split Left & Right Armored Coat Tails with Gold Trim Borders
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "L" else "R"
		local flapCF = CFrame.new(side * 0.78 * (0.94 + wM * 0.06), 1.72, -0.64) * CFrame.Angles(math.rad(-8), side * math.rad(-10), side * math.rad(5))
		makeBox(model, rootCF, s, "CoatTail_" .. tag, Vector3.new(0.84, 1.18, 0.24), flapCF, pal.armorMid, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "CoatInnerGold_" .. tag, Vector3.new(0.14, 1.18, 0.28), flapCF * CFrame.new(-side * 0.36, 0, -0.02), pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "CoatHemGold_" .. tag, Vector3.new(0.86, 0.16, 0.28), flapCF * CFrame.new(0, -0.52, -0.02), pal.trimGold, Enum.Material.Metal, cc)
	end

	-- Heavy Waist Belt & Gold Square Buckle
	makeBox(model, rootCF, s, "WaistBelt", Vector3.new(2.44 * wM, 0.44, 1.40), CFrame.new(0, 2.50, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "BeltTrimTop", Vector3.new(2.48 * wM, 0.10, 1.44), CFrame.new(0, 2.72, 0), pal.trimGoldDark, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "BeltBuckleOuter", Vector3.new(0.68, 0.56, 0.24), CFrame.new(0, 2.50, -0.72), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "BeltBuckleCenter", Vector3.new(0.32, 0.26, 0.28), CFrame.new(0, 2.50, -0.74), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	for _, side in ipairs({ -1, 1 }) do
		makeBox(model, rootCF, s, "BeltSideClasp_" .. (if side < 0 then "L" else "R"), Vector3.new(0.32, 0.46, 0.24), CFrame.new(side * 0.92 * wM, 2.50, -0.66), pal.trimGold, Enum.Material.Metal, cc)
	end

	-- Left-Hip Capture Lantern (-X side, Viewer's Right in Front View, clearly forward of left gauntlet)
	local lCF = CFrame.new(-1.26 * wM, 1.86, -0.64) * CFrame.Angles(0, math.rad(14), math.rad(-5))
	local lanternPivot = (lCF * CFrame.new(0.14, 0.76, 0.08)).Position
	createBoneHub(model, rigState, "Lantern", lCF.Position, s)
	setActiveBone(rigState, "Lantern")

	makeBox(model, rootCF, s, "LanternHook", Vector3.new(0.24, 0.46, 0.24), lCF * CFrame.new(0.14, 0.62, 0.08), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "LanternCapTop", Vector3.new(0.76, 0.20, 0.76), lCF * CFrame.new(0, 0.42, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "LanternCapFinial", Vector3.new(0.46, 0.16, 0.46), lCF * CFrame.new(0, 0.56, 0), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "LanternBase", Vector3.new(0.76, 0.22, 0.76), lCF * CFrame.new(0, -0.44, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "LanternBaseTrim", Vector3.new(0.48, 0.14, 0.48), lCF * CFrame.new(0, -0.58, 0), pal.trimGold, Enum.Material.Metal, cc)

	-- Glowing Hourglass Vial Core
	local vialH = if cfg.tier >= 2 then 0.76 else 0.68
	local vial = makeBox(model, rootCF, s, "LanternCore", Vector3.new(0.42, vialH, 0.42), lCF, pal.neonPrimary, Enum.Material.Neon, cc)
	for _, cx in ipairs({ -0.28, 0.28 }) do
		for _, cz in ipairs({ -0.28, 0.28 }) do
			makeBox(model, rootCF, s, "LanternCagePost", Vector3.new(0.11, vialH + 0.08, 0.11), lCF * CFrame.new(cx, 0, cz), pal.armorDark, Enum.Material.SmoothPlastic, cc)
		end
	end
	if withEffects then
		local light = Instance.new("PointLight")
		light.Name = "LanternGlowLight"
		light.Color = pal.neonPrimary
		light.Range = 8 * s
		light.Brightness = 1.4
		light.Parent = vial
	end

	return lanternPivot
end

-- 3. Cuirass, Left-Chest Glowing Paw Medallion & High Face Cowl (Y = 2.70 .. 5.20)
local function buildTorsoAndCowl(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, cc: boolean, rigState: RigState?)
	local pal = cfg.palette
	local wM = cfg.widthMult

	createBoneHub(model, rigState, "Torso", Vector3.new(0, 3.60, 0), s)
	setActiveBone(rigState, "Torso")

	-- Broad layered obsidian cuirass (X scales explicitly with wM so higher tiers look wider & bulkier!)
	makeBox(model, rootCF, s, "TorsoCore", Vector3.new(2.40 * wM, 1.72, 1.38), CFrame.new(0, 3.56, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "TorsoBreastplate", Vector3.new(2.12 * wM, 1.32, 0.26), CFrame.new(0, 3.64, -0.68), pal.armorMid, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "TorsoCenterCloak", Vector3.new(0.86, 1.36, 0.24), CFrame.new(0, 3.60, -0.72), pal.cloakPrimary, Enum.Material.SmoothPlastic, cc)

	-- Bold Gold Coat Lapel Trim Rails
	for _, side in ipairs({ -1, 1 }) do
		makeBox(model, rootCF, s, "TorsoLapelGold_" .. (if side < 0 then "L" else "R"), Vector3.new(0.22, 1.38, 0.28), CFrame.new(side * 0.56 * (0.94 + wM * 0.06), 3.60, -0.74) * CFrame.Angles(0, 0, side * math.rad(-8)), pal.trimGold, Enum.Material.Metal, cc)
	end

	-- Left-Chest Glowing 3D Voxel Paw Medallion (-X upper chest, Viewer's Right in Front View)
	local crestCF = CFrame.new(-0.74 * wM, 3.74, -0.84) * CFrame.Angles(math.rad(6), math.rad(12), 0)
	makeBox(model, rootCF, s, "ChestCrestHousing", Vector3.new(0.88, 0.92, 0.22), crestCF, pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "ChestCrestBorder", Vector3.new(0.96, 0.22, 0.18), crestCF * CFrame.new(0, 0.40, 0), pal.trimGold, Enum.Material.Metal, cc)
	build3DVoxelPaw(model, rootCF, s, "ChestPaw", crestCF * CFrame.new(0, -0.02, -0.10), 0.98, pal.neonPrimary, cc)

	-- Multi-layered wrapped high scarf/bandana cowl (leaves upper eyes exposed)
	makeBox(model, rootCF, s, "ScarfCowlBase", Vector3.new(2.38 * wM, 0.52, 1.80), CFrame.new(0, 4.48, -0.04), pal.cloakPrimary, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "ScarfCowlMid", Vector3.new(2.04 * wM, 0.50, 1.62), CFrame.new(0, 4.82, -0.06), pal.cloakPrimary:Lerp(pal.armorDark, 0.28), Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "ScarfMaskFold", Vector3.new(1.78, 0.36, 0.30), CFrame.new(0, 5.04, -0.76) * CFrame.Angles(math.rad(-8), 0, 0), pal.cloakSecondary:Lerp(pal.armorDark, 0.45), Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "ScarfGoldPin", Vector3.new(0.46, 0.24, 0.16), CFrame.new(0.48, 4.72, -0.88), pal.trimGold, Enum.Material.Metal, cc)
end

-- 4. Massive Layered Pauldrons & Arms (Y = 2.60 .. 4.75); returns exact Right Fist grip CFrame & armOutX
local function buildArmsAndPauldrons(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, cc: boolean, rigState: RigState?): (CFrame, number)
	local pal = cfg.palette
	local sh = cfg.shoulderMult
	local wM = cfg.widthMult
	local torsoShPad = (wM - 1.0) * 1.15

	-- Pauldrons ride on Torso so arm swings & overhead staff lifts never collide pauldron spires into the hat brim
	setActiveBone(rigState, "Torso")

	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "L" else "R"
		local shX = side * (1.42 + torsoShPad + (sh - 1.0) * 0.72)

		-- Stepped Voxel Pauldron + Bold Gold Rim + Under-Glow Slit
		local pCF = CFrame.new(shX, 4.30, 0) * CFrame.Angles(0, 0, side * math.rad(-14))
		makeBox(model, rootCF, s, "PauldronMain_" .. tag, Vector3.new(1.26 * sh, 0.72, 1.56), pCF, pal.armorMid, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "PauldronTop_" .. tag, Vector3.new(0.96 * sh, 0.34, 1.24), pCF * CFrame.new(-side * 0.12, 0.40, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "PauldronGoldRim_" .. tag, Vector3.new(1.32 * sh, 0.18, 1.62), pCF * CFrame.new(side * 0.04, -0.26, 0), pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "PauldronGoldRidge_" .. tag, Vector3.new(0.24 * sh, 0.38, 1.60), pCF * CFrame.new(side * 0.38 * sh, 0.34, 0), pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "PauldronNeonSlit_" .. tag, Vector3.new(0.84 * sh, 0.14, 1.06), pCF * CFrame.new(side * 0.16, -0.38, 0), pal.neonPrimary, Enum.Material.Neon, cc)

		-- Biome Escalation Pauldron Enhancements
		if cfg.tier >= 2 then
			makeBox(model, rootCF, s, "PauldronSpike_" .. tag, Vector3.new(0.46, 0.30, 0.30), pCF * CFrame.new(side * (0.76 * sh), 0.14, 0) * CFrame.Angles(0, 0, side * math.rad(-18)), pal.hornTip, Enum.Material.SmoothPlastic, cc)
		end
		if cfg.tier >= 3 then
			makeBox(model, rootCF, s, "PauldronFin_" .. tag, Vector3.new(0.28, 0.92, 0.56), pCF * CFrame.new(side * (0.56 * sh), 0.72, 0) * CFrame.Angles(0, 0, side * math.rad(-16)), pal.trimGold, Enum.Material.Metal, cc)
		end
		if cfg.tier >= 4 then
			makeBox(model, rootCF, s, "PauldronSpire_" .. tag, Vector3.new(0.34, 1.15, 0.38), pCF * CFrame.new(side * (0.28 * sh), 1.08, 0.12) * CFrame.Angles(math.rad(10), 0, side * math.rad(-12)), pal.neonPrimary, Enum.Material.Neon, cc)
		end
		if cfg.tier >= 5 then
			makeBox(model, rootCF, s, "PauldronDreadHorn_" .. tag, Vector3.new(0.36, 1.38, 0.42), pCF * CFrame.new(side * (0.72 * sh), 1.12, -0.10) * CFrame.Angles(math.rad(-14), 0, side * math.rad(-26)), pal.armorDark, Enum.Material.SmoothPlastic, cc)
			makeBox(model, rootCF, s, "PauldronDreadHornTip_" .. tag, Vector3.new(0.24, 0.54, 0.28), pCF * CFrame.new(side * (0.86 * sh), 1.82, -0.22) * CFrame.Angles(math.rad(-18), 0, side * math.rad(-16)), pal.neonSecondary, Enum.Material.Neon, cc)
		end
	end

	-- Right Arm (+X, Viewer's Left): Raised forward & angled cleanly outward gripping the Net Staff
	local armOutX = torsoShPad + (sh - 1.0) * 0.55
	createBoneHub(model, rigState, "ArmR", Vector3.new(1.85 + armOutX, 3.35, -0.45), s)
	setActiveBone(rigState, "ArmR")
	local rUpperCF = CFrame.new(1.66 + armOutX, 3.55, -0.26) * CFrame.Angles(math.rad(32), math.rad(-12), math.rad(-18))
	makeBox(model, rootCF, s, "UpperArm_R", Vector3.new(0.76, 1.04, 0.76), rUpperCF, pal.armorDark, Enum.Material.SmoothPlastic, cc)
	local rHandCF = CFrame.new(2.14 + armOutX, 3.12, -0.90) * CFrame.Angles(math.rad(54), math.rad(-14), math.rad(-14))
	makeBox(model, rootCF, s, "Forearm_R", Vector3.new(0.82, 0.94, 0.82), rHandCF, pal.armorMid, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "GauntletCuff_R", Vector3.new(0.88, 0.18, 0.88), rHandCF * CFrame.new(0, 0.24, 0), pal.trimGold, Enum.Material.Metal, cc)
	local rFistCF = rHandCF * CFrame.new(0, -0.58, -0.06)
	makeBox(model, rootCF, s, "GauntletFist_R", Vector3.new(0.76, 0.58, 0.78), rFistCF, pal.armorDark, Enum.Material.SmoothPlastic, cc)

	-- Left Arm (-X, Viewer's Right): Braced heroically beside hip lantern without blocking lantern core
	createBoneHub(model, rigState, "ArmL", Vector3.new(-1.72 - armOutX, 3.10, -0.12), s)
	setActiveBone(rigState, "ArmL")
	local lUpperCF = CFrame.new(-1.58 - armOutX, 3.44, -0.04) * CFrame.Angles(math.rad(8), 0, math.rad(16))
	makeBox(model, rootCF, s, "UpperArm_L", Vector3.new(0.76, 1.04, 0.76), lUpperCF, pal.armorDark, Enum.Material.SmoothPlastic, cc)
	local lHandCF = CFrame.new(-1.86 - armOutX, 2.74, -0.20) * CFrame.Angles(math.rad(12), math.rad(8), math.rad(12))
	makeBox(model, rootCF, s, "Forearm_L", Vector3.new(0.82, 0.94, 0.82), lHandCF, pal.armorMid, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "GauntletCuff_L", Vector3.new(0.88, 0.18, 0.88), lHandCF * CFrame.new(0, 0.24, 0), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "GauntletFist_L", Vector3.new(0.74, 0.52, 0.74), lHandCF * CFrame.new(0, -0.54, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)

	return rFistCF, armOutX
end

-- 5. Shadowed Head, Fierce Glowing Eyes & Wide-Brimmed Horned Hat (Y = 4.90 .. 8.50+)
local function buildHeadAndHat(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, cc: boolean, rigState: RigState?)
	local pal = cfg.palette
	local hs = cfg.hornScale

	createBoneHub(model, rigState, "Head", Vector3.new(0, 5.55, 0), s)
	setActiveBone(rigState, "Head")

	-- Shadowed head box recessed below brim (hat brim clears eye level!)
	makeBox(model, rootCF, s, "HeadShadowBox", Vector3.new(1.76, 1.28, 1.56), CFrame.new(0, 5.42, 0), pal.headShadow, Enum.Material.SmoothPlastic, cc)

	-- Fierce angled slanted glowing eyes (> <) strictly below Y = 5.75 hat brim
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "L" else "R"
		local tilt = side * math.rad(-18)
		local eyeBase = CFrame.new(side * 0.44, 5.42, -0.78) * CFrame.Angles(0, 0, tilt)
		makeBox(model, rootCF, s, "EyeOuter_" .. tag, Vector3.new(0.46, 0.18, 0.14), eyeBase, pal.neonPrimary, Enum.Material.Neon, cc)
		makeBox(model, rootCF, s, "EyeCore_" .. tag, Vector3.new(0.24, 0.11, 0.16), eyeBase * CFrame.new(side * 0.04, 0, -0.02), pal.eyeCore, Enum.Material.Neon, cc)
		makeBox(model, rootCF, s, "TempleVentGlow_" .. tag, Vector3.new(0.14, 0.34, 0.24), CFrame.new(side * 0.90, 5.42, -0.26), pal.neonPrimary, Enum.Material.Neon, cc)

		-- Tier 5 extra fierce double-eye brow & obsidian fang jaw grille over cowl
		if cfg.tier >= 5 then
			makeBox(model, rootCF, s, "EyeBrowFlare_" .. tag, Vector3.new(0.32, 0.10, 0.14), eyeBase * CFrame.new(side * 0.16, 0.13, 0), pal.neonSecondary, Enum.Material.Neon, cc)
		end
	end
	if cfg.tier >= 5 then
		makeBox(model, rootCF, s, "DreadJawGrille", Vector3.new(1.16, 0.44, 0.30), CFrame.new(0, 5.06, -0.84), pal.armorDark, Enum.Material.SmoothPlastic, cc)
		for _, fx in ipairs({ -0.36, -0.12, 0.12, 0.36 }) do
			makeBox(model, rootCF, s, "DreadFang", Vector3.new(0.12, 0.32, 0.14), CFrame.new(fx, 5.06, -0.96), pal.neonSecondary, Enum.Material.Neon, cc)
		end
	end

	-- Wide-Brimmed Octagonal Hat (Top View faithful — clear above Y = 5.75!)
	local brimY = 5.90
	makeBox(model, rootCF, s, "HatBrimCenter", Vector3.new(4.10, 0.26, 3.60), CFrame.new(0, brimY, 0.04), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "HatBrimFrontBack", Vector3.new(3.26, 0.26, 4.46), CFrame.new(0, brimY, 0.04), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "HatBrimLeftRight", Vector3.new(4.62, 0.24, 2.52), CFrame.new(0, brimY, 0.04), pal.armorMid, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "HatBrimUnderGlow", Vector3.new(3.64, 0.10, 3.24), CFrame.new(0, brimY - 0.14, 0.04), pal.neonPrimary, Enum.Material.Neon, cc)

	-- Gold Outer Brim Trim Brackets & Corner Glow Pips (Top View accurate)
	makeBox(model, rootCF, s, "HatBrimGoldF", Vector3.new(3.04, 0.28, 0.22), CFrame.new(0, brimY + 0.04, -2.20), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "HatBrimGoldB", Vector3.new(3.04, 0.28, 0.22), CFrame.new(0, brimY + 0.04, 2.28), pal.trimGold, Enum.Material.Metal, cc)
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "L" else "R"
		makeBox(model, rootCF, s, "HatBrimGoldSide_" .. tag, Vector3.new(0.24, 0.28, 2.38), CFrame.new(side * 2.28, brimY + 0.04, 0.04), pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "HatBrimNeonPip_" .. tag, Vector3.new(0.26, 0.18, 0.30), CFrame.new(side * 1.98, brimY + 0.08, -1.68), pal.neonPrimary, Enum.Material.Neon, cc)

		-- Tier 2 Hanging Moss / Tier 4 Hanging Icicles under brim
		if cfg.tier == 2 then
			makeBox(model, rootCF, s, "BrimMoss_" .. tag, Vector3.new(0.22, 0.56, 0.22), CFrame.new(side * 2.12, brimY - 0.34, -0.68), pal.neonSecondary, Enum.Material.SmoothPlastic, cc)
		elseif cfg.tier == 4 then
			makeBox(model, rootCF, s, "BrimIcicle_" .. tag, Vector3.new(0.18, 0.62, 0.18), CFrame.new(side * 2.12, brimY - 0.36, -0.72), pal.neonSecondary, Enum.Material.Neon, cc)
		end
	end

	-- Stepped Hat Crown, Gold Hatband & Front Hat Glowing Paw Crest
	makeBox(model, rootCF, s, "HatCrownLower", Vector3.new(2.44, 0.94, 2.32), CFrame.new(0, 6.48, 0.04), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "HatBandGold", Vector3.new(2.54, 0.22, 2.42), CFrame.new(0, 6.18, 0.04), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "HatCrownUpper", Vector3.new(1.88, 0.52, 1.80), CFrame.new(0, 7.18, 0.04), pal.armorMid, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "HatApexGem", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 7.60, 0.04), pal.neonPrimary, Enum.Material.Neon, cc)

	-- Front Crown Crest Shield + 3D Glowing Voxel Paw Emblem
	local hatCrestCF = CFrame.new(0, 6.66, -1.24) * CFrame.Angles(math.rad(-6), 0, 0)
	makeBox(model, rootCF, s, "HatCrestShield", Vector3.new(1.18, 1.06, 0.26), hatCrestCF, pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "HatCrestGoldArch", Vector3.new(1.26, 0.20, 0.28), hatCrestCF * CFrame.new(0, 0.52, 0), pal.trimGold, Enum.Material.Metal, cc)
	build3DVoxelPaw(model, rootCF, s, "HatPaw", hatCrestCF * CFrame.new(0, -0.02, -0.10), 1.18, pal.neonPrimary, cc)

	-- Tier-Scaled Sweeping Curved Voxel Horns on Sides of Crown
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "L" else "R"
		local hBase = CFrame.new(side * 1.18, 6.38, -0.18) * CFrame.Angles(0, 0, side * math.rad(-14))
		makeBox(model, rootCF, s, "HornSocket_" .. tag, Vector3.new(0.42 * hs, 0.44 * hs, 0.48 * hs), hBase, pal.trimGold, Enum.Material.Metal, cc)
		makeBox(model, rootCF, s, "HornSeg1_" .. tag, Vector3.new(0.38 * hs, 0.58 * hs, 0.38 * hs), hBase * CFrame.new(side * 0.26 * hs, 0.36 * hs, -0.06), pal.hornDark, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "HornSeg2_" .. tag, Vector3.new(0.30 * hs, 0.68 * hs, 0.30 * hs), hBase * CFrame.new(side * 0.40 * hs, 0.90 * hs, -0.12) * CFrame.Angles(math.rad(-10), 0, side * math.rad(16)), pal.hornDark, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "HornTip_" .. tag, Vector3.new(0.22 * hs, 0.54 * hs, 0.22 * hs), hBase * CFrame.new(side * 0.28 * hs, 1.44 * hs, -0.18) * CFrame.Angles(math.rad(-14), 0, side * math.rad(28)), pal.hornTip, Enum.Material.Neon, cc)

		-- Tier 3 Royal Crown Fins / Tier 4 Glacier Spikes / Tier 5 Inner Demonic Horns & Floating Back Spires
		if cfg.tier == 3 then
			makeBox(model, rootCF, s, "CrownSunFin_" .. tag, Vector3.new(0.20, 0.72, 0.56), CFrame.new(side * 0.92, 7.46, 0.04), pal.trimGold, Enum.Material.Metal, cc)
		elseif cfg.tier == 4 then
			makeBox(model, rootCF, s, "CrownFrostSpire_" .. tag, Vector3.new(0.24, 0.96, 0.24), CFrame.new(side * 0.76, 7.64, -0.16) * CFrame.Angles(math.rad(-10), 0, side * math.rad(-12)), pal.neonSecondary, Enum.Material.Neon, cc)
		elseif cfg.tier >= 5 then
			makeBox(model, rootCF, s, "InnerDemonHorn_" .. tag, Vector3.new(0.26, 1.18, 0.26), CFrame.new(side * 0.78, 7.82, -0.22) * CFrame.Angles(math.rad(-16), 0, side * math.rad(-18)), pal.neonSecondary, Enum.Material.Neon, cc)
			setActiveBone(rigState, "Torso")
			makeBox(model, rootCF, s, "BackHaloSpire_" .. tag, Vector3.new(0.32, 1.65, 0.24), CFrame.new(side * 1.42 * cfg.widthMult, 5.45, 1.38) * CFrame.Angles(math.rad(8), 0, side * math.rad(-20)), pal.armorDark, Enum.Material.SmoothPlastic, cc)
			makeBox(model, rootCF, s, "BackHaloGlow_" .. tag, Vector3.new(0.18, 1.10, 0.26), CFrame.new(side * 1.54 * cfg.widthMult, 5.56, 1.38) * CFrame.Angles(math.rad(8), 0, side * math.rad(-20)), pal.neonSecondary, Enum.Material.Neon, cc)
			setActiveBone(rigState, "Head")
		end
	end
end

-- 6. Flowing Tattered Cape & Giant Back Glowing Paw Emblem (Z = +0.85 .. +1.65); returns CapeHem pivot
local function buildTatteredCape(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, cc: boolean, rigState: RigState?): Vector3
	local pal = cfg.palette
	local wM = cfg.widthMult
	local capeCF = CFrame.new(0, 2.78, 1.12) * CFrame.Angles(math.rad(11), 0, 0)

	createBoneHub(model, rigState, "Cape", (capeCF * CFrame.new(0, 0.20, 0)).Position, s)
	setActiveBone(rigState, "Cape")

	-- Upper solid cloak drape flaring behind shoulders & hips
	makeBox(model, rootCF, s, "CapeUpper", Vector3.new(2.74 * wM, 1.92, 0.26), capeCF * CFrame.new(0, 0.64, 0), pal.cloakPrimary, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "CapeMid", Vector3.new(3.16 * wM, 1.46, 0.24), capeCF * CFrame.new(0, -0.78, 0.02), pal.cloakPrimary:Lerp(pal.cloakSecondary, 0.35), Enum.Material.SmoothPlastic, cc)

	-- Gold cape shoulder clasps
	for _, side in ipairs({ -1, 1 }) do
		makeBox(model, rootCF, s, "CapeClaspGold_" .. (if side < 0 then "L" else "R"), Vector3.new(0.34, 0.36, 0.30), capeCF * CFrame.new(side * 1.10 * wM, 1.44, -0.02), pal.trimGold, Enum.Material.Metal, cc)
	end

	-- Giant Back Glowing 3D Voxel Paw Emblem facing +Z
	local backPawCF = capeCF * CFrame.new(0, 0.08, 0.14) * CFrame.Angles(0, math.pi, 0)
	build3DVoxelPaw(model, rootCF, s, "BackCapePaw", backPawCF, 2.15, pal.neonPrimary, cc)

	-- Articulated lower hem for multi-wave tattered trail motion
	local capeHemPivot = (capeCF * CFrame.new(0, -1.48, 0.03)).Position
	createBoneHub(model, rigState, "CapeHem", capeHemPivot, s)
	setActiveBone(rigState, "CapeHem")

	-- Staggered jagged tattered cloak strips transitioning to bright neon tips
	local stripDefs = {
		{ x = -1.36, h = 0.72, glowH = 0.44 },
		{ x = -0.96, h = 0.94, glowH = 0.56 },
		{ x = -0.56, h = 0.64, glowH = 0.38 },
		{ x = -0.18, h = 1.02, glowH = 0.62 },
		{ x = 0.18, h = 0.80, glowH = 0.48 },
		{ x = 0.56, h = 1.06, glowH = 0.60 },
		{ x = 0.96, h = 0.70, glowH = 0.40 },
		{ x = 1.36, h = 0.92, glowH = 0.54 },
	}
	for idx, st in ipairs(stripDefs) do
		makeBox(model, rootCF, s, "CapeStripMid_" .. idx, Vector3.new(0.32 * wM, st.h, 0.20), capeCF * CFrame.new(st.x * wM, -1.46 - st.h * 0.45, 0.04), pal.cloakSecondary, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "CapeStripTip_" .. idx, Vector3.new(0.30 * wM, st.glowH, 0.18), capeCF * CFrame.new(st.x * wM, -1.46 - st.h - st.glowH * 0.35, 0.04), pal.cloakTip, Enum.Material.Neon, cc)
	end

	return capeHemPivot
end

-- 7. Signature "Net Staff (Capture Tool)" gripped squarely inside Right Gauntlet Fist (+X, Viewer's Left); returns hoopCenter Position
local function buildNetStaff(model: Model, rootCF: CFrame, s: number, cfg: GuardTierConfig, rFistCF: CFrame, cc: boolean, withEffects: boolean, rigState: RigState?): Vector3
	local pal = cfg.palette

	createBoneHub(model, rigState, "NetStaff", rFistCF.Position, s)
	setActiveBone(rigState, "NetStaff")

	-- Anchor shaft directly through center of Right Gauntlet Fist, tilted cleanly outside hat brim & horns
	local handPivot = CFrame.new(rFistCF.Position) * CFrame.Angles(math.rad(-10), math.rad(10), math.rad(-17))

	-- Long segmented dark iron shaft resting just above boot sole level and rising through golden yoke
	makeBox(model, rootCF, s, "NetStaffShaft", Vector3.new(0.28, 5.15, 0.28), handPivot * CFrame.new(0, 0.42, 0), pal.armorDark, Enum.Material.SmoothPlastic, cc)
	makeBox(model, rootCF, s, "NetStaffRingLow", Vector3.new(0.36, 0.22, 0.36), handPivot * CFrame.new(0, -1.00, 0), pal.armorMid, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "NetStaffRingMid", Vector3.new(0.38, 0.24, 0.38), handPivot * CFrame.new(0, 1.50, 0), pal.armorMid, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "NetStaffPommelGold", Vector3.new(0.46, 0.34, 0.46), handPivot * CFrame.new(0, -2.14, 0), pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "NetStaffPommelNeon", Vector3.new(0.36, 0.36, 0.36), handPivot * CFrame.new(0, -2.40, 0), pal.neonPrimary, Enum.Material.Neon, cc)

	-- Chunky Golden Yoke Mount above upper shaft
	local yokeCF = handPivot * CFrame.new(0, 3.12, 0)
	makeBox(model, rootCF, s, "NetStaffYokeBase", Vector3.new(1.06, 0.48, 0.54), yokeCF, pal.trimGold, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "NetStaffYokeBoltL", Vector3.new(0.26, 0.34, 0.58), yokeCF * CFrame.new(-0.46, 0.14, 0), pal.trimGoldDark, Enum.Material.Metal, cc)
	makeBox(model, rootCF, s, "NetStaffYokeBoltR", Vector3.new(0.26, 0.34, 0.58), yokeCF * CFrame.new(0.46, 0.14, 0), pal.trimGoldDark, Enum.Material.Metal, cc)

	-- Octagonal Armored Capture Hoop with all outward normals (+Y) pointing strictly away from hoopCenter
	local hoopScale = 1.0 + (cfg.tier - 1) * 0.055
	local hoopCenter = yokeCF * CFrame.new(0, 1.48 * hoopScale, 0)
	local hoopArmDefs = {
		{ x = 0, y = 1.32, rot = 0, len = 1.34 },       -- 1: Top (+Y)
		{ x = 0, y = -1.32, rot = 180, len = 1.24 },    -- 2: Bottom (-Y)
		{ x = -1.32, y = 0, rot = 90, len = 1.34 },     -- 3: Left (-X)
		{ x = 1.32, y = 0, rot = -90, len = 1.34 },     -- 4: Right (+X)
		{ x = -0.94, y = 0.94, rot = 45, len = 1.22 },  -- 5: Top-Left (-X, +Y)
		{ x = 0.94, y = 0.94, rot = -45, len = 1.22 },  -- 6: Top-Right (+X, +Y)
		{ x = -0.94, y = -0.94, rot = 135, len = 1.22 },-- 7: Bottom-Left (-X, -Y)
		{ x = 0.94, y = -0.94, rot = -135, len = 1.22 },-- 8: Bottom-Right (+X, -Y)
	}
	for i, seg in ipairs(hoopArmDefs) do
		local segCF = hoopCenter * CFrame.new(seg.x * hoopScale, seg.y * hoopScale, 0) * CFrame.Angles(0, 0, math.rad(seg.rot))
		makeBox(model, rootCF, s, "HoopFrame_" .. i, Vector3.new(seg.len * hoopScale, 0.28, 0.36), segCF, pal.armorDark, Enum.Material.SmoothPlastic, cc)
		local outerCol = if i % 2 == 1 then pal.neonPrimary else pal.trimGold
		local outerMat = if i % 2 == 1 then Enum.Material.Neon else Enum.Material.Metal
		makeBox(model, rootCF, s, "HoopOuter_" .. i, Vector3.new(seg.len * 0.72 * hoopScale, 0.16, 0.42), segCF * CFrame.new(0, 0.16, 0), outerCol, outerMat, cc)

		-- Biome Tier 3-5 serrated outward capture barbs on Top/Side/Upper-Diagonal edges
		if cfg.tier >= 3 and (i == 1 or i == 3 or i == 4 or i == 5 or i == 6) then
			local barbCol = if cfg.tier >= 5 then pal.neonSecondary elseif cfg.tier == 4 then pal.neonPrimary else pal.trimGold
			local barbMat = if cfg.tier >= 4 then Enum.Material.Neon else Enum.Material.Metal
			makeBox(model, rootCF, s, "HoopBarb_" .. i, Vector3.new(0.24, 0.46, 0.22), segCF * CFrame.new(0, 0.44, 0), barbCol, barbMat, cc)
		end
	end

	-- Recessed 3D Crisscross Capture Net Mesh (3 Horizontal + 3 Vertical pale silver-glowing bars)
	for _, offset in ipairs({ -0.58 * hoopScale, 0, 0.58 * hoopScale }) do
		local barLen = if math.abs(offset) > 0.1 then 2.15 * hoopScale else 2.52 * hoopScale
		makeBox(model, rootCF, s, "NetGridV", Vector3.new(0.11, barLen, 0.11), hoopCenter * CFrame.new(offset, 0, 0), pal.netMeshColor, Enum.Material.SmoothPlastic, cc)
		makeBox(model, rootCF, s, "NetGridH", Vector3.new(barLen, 0.11, 0.11), hoopCenter * CFrame.new(0, offset, 0), pal.netMeshColor, Enum.Material.SmoothPlastic, cc)
	end

	-- Tier 5 Floating Arcane Orb & Selective ParticleEmitter inside Capture Net Hoop
	if cfg.tier >= 5 then
		createBoneHub(model, rigState, "NetCore", hoopCenter.Position, s)
		setActiveBone(rigState, "NetCore")
		local corePart = makeBox(model, rootCF, s, "OverlordNetCore", Vector3.new(0.62, 0.62, 0.62), hoopCenter * CFrame.Angles(math.rad(45), math.rad(45), 0), pal.neonSecondary, Enum.Material.Neon, cc)
		if withEffects then
			local em = Instance.new("ParticleEmitter")
			em.Name = "OverlordNetEmbers"
			em.Rate = 10
			em.Lifetime = NumberRange.new(0.8, 1.4)
			em.Speed = NumberRange.new(1.5, 4.0)
			em.SpreadAngle = Vector2.new(180, 180)
			em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			em.Color = ColorSequence.new(pal.neonPrimary, pal.neonSecondary)
			em.LightEmission = 1
			em.Parent = corePart
		end
		setActiveBone(rigState, "NetStaff")
	elseif withEffects and cfg.tier == 4 then
		local frostEm = Instance.new("ParticleEmitter")
		frostEm.Name = "GlacierHoopSparkles"
		frostEm.Rate = 6
		frostEm.Lifetime = NumberRange.new(0.8, 1.3)
		frostEm.Speed = NumberRange.new(1.0, 2.5)
		frostEm.SpreadAngle = Vector2.new(180, 180)
		frostEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		frostEm.Color = ColorSequence.new(pal.neonPrimary, Color3.new(1, 1, 1))
		frostEm.LightEmission = 1
		frostEm.Parent = makeBox(model, rootCF, s, "NetSparkleAnchor", Vector3.new(0.2, 0.2, 0.2), hoopCenter, pal.neonPrimary, Enum.Material.Neon, cc, 1)
	end

	return hoopCenter.Position
end

-- Flushes model bottom strictly to targetY so boots sit flush on the floor with zero gap/sinking
local function flushModelBottomToY(model: Model, targetY: number): number
	local minY = math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local bottomY = d.Position.Y - d.Size.Y * 0.5
			if bottomY < minY then
				minY = bottomY
			end
		end
	end
	if minY < math.huge then
		local dy = targetY - minY
		if math.abs(dy) > 0.002 then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CFrame = d.CFrame + Vector3.new(0, dy, 0)
				end
			end
		end
		return dy
	end
	return 0
end

local BONE_PARENTS: { [string]: string } = {
	Pelvis = "HumanoidRootPart",
	Lantern = "Pelvis",
	LegL = "Pelvis",
	FootL = "LegL",
	LegR = "Pelvis",
	FootR = "LegR",
	Torso = "Pelvis",
	Head = "Torso",
	ArmR = "Torso",
	NetStaff = "ArmR",
	NetCore = "NetStaff",
	ArmL = "Torso",
	Cape = "Torso",
	CapeHem = "Cape",
}

local JOINT_TO_BONE: { [string]: string } = {
	RootJoint = "Pelvis",
	LanternJoint = "Lantern",
	HipLJoint = "LegL",
	KneeLJoint = "FootL",
	HipRJoint = "LegR",
	KneeRJoint = "FootR",
	WaistJoint = "Torso",
	NeckJoint = "Head",
	ShoulderRJoint = "ArmR",
	StaffJoint = "NetStaff",
	NetCoreJoint = "NetCore",
	ShoulderLJoint = "ArmL",
	CapeJoint = "Cape",
	CapeHemJoint = "CapeHem",
}

local function buildPoseHierarchy(boneSet: { [string]: boolean }, posesByBone: { [string]: CFrame }): Pose
	local rootPose = Instance.new("Pose")
	rootPose.Name = "HumanoidRootPart"
	rootPose.Weight = 0
	rootPose.CFrame = CFrame.new()

	local poseObjs: { [string]: Pose } = { HumanoidRootPart = rootPose }
	for boneName in pairs(boneSet) do
		if boneName ~= "HumanoidRootPart" then
			local p = Instance.new("Pose")
			p.Name = boneName
			p.Weight = 1
			p.CFrame = posesByBone[boneName] or CFrame.new()
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			poseObjs[boneName] = p
		end
	end
	for boneName, poseInst in pairs(poseObjs) do
		if boneName ~= "HumanoidRootPart" then
			local parentName = BONE_PARENTS[boneName] or "HumanoidRootPart"
			local parentPose = poseObjs[parentName] or rootPose
			poseInst.Parent = parentPose
		end
	end
	return rootPose
end

--- Evaluates procedural joint deltas for Idle, Walk, Chase, or Attack modes.
--- Model faces -Z (+Y Up, +X Right). Positive X rotation swings hanging limbs Forward (-Z) and leans Torso Back (+Z).
function VoxelPetGuardBuilder.SamplePoseDeltas(
	mode: GuardAnimMode,
	u: number,
	s: number,
	tier: number,
	attackProgress: number?
): { [string]: CFrame }
	local out: { [string]: CFrame } = {}
	local isBossScale = tier >= 4

	if mode == "Attack" then
		local t = math.clamp(attackProgress or 0, 0, 1)
		local waistPitch, waistYaw, rootBob, staffRaise, staffPitch, staffYaw, lArmSwing, capeFlare = 0, 0, 0, 0, 0, 0, 0, -0.28
		if t < 0.30 then
			-- Coil back & lift Net Staff high overhead without overshooting behind cape
			local k = math.sin((t / 0.30) * math.pi * 0.5)
			waistPitch = 0.14 * k
			waistYaw = -0.32 * k
			rootBob = 0.08 * k * s
			staffRaise = 0.44 * k
			staffPitch = 0.14 * k
			staffYaw = -0.16 * k
			lArmSwing = -0.32 * k
			capeFlare = -0.20 - 0.16 * k
		elseif t < 0.68 then
			-- Explosive capture scoop forward at player waist/chest height (stays cleanly above floor!)
			local k = math.sin(((t - 0.30) / 0.38) * math.pi * 0.5)
			waistPitch = 0.14 - 0.40 * k
			waistYaw = -0.32 + 0.72 * k
			rootBob = (0.08 - 0.14 * k) * s
			staffRaise = 0.44 - 0.70 * k
			staffPitch = 0.14 - 0.38 * k
			staffYaw = -0.16 + 0.38 * k
			lArmSwing = -0.32 + 0.66 * k
			capeFlare = -0.36 - 0.30 * k
		else
			-- Smooth follow-through recovery back to combat stance
			local k = 1 - ((t - 0.68) / 0.32)
			waistPitch = -0.26 * k
			waistYaw = 0.40 * k
			rootBob = -0.06 * k * s
			staffRaise = -0.26 * k
			staffPitch = -0.24 * k
			staffYaw = 0.22 * k
			lArmSwing = 0.34 * k
			capeFlare = -0.22 - 0.44 * k
		end

		out.RootJoint = CFrame.new(0, rootBob, 0) * CFrame.Angles(-0.06 * math.abs(waistPitch), waistYaw * 0.25, 0)
		out.WaistJoint = CFrame.Angles(waistPitch, waistYaw, 0)
		out.NeckJoint = CFrame.Angles(-waistPitch * 0.55, -waistYaw * 0.35, 0)
		out.ShoulderRJoint = CFrame.Angles(staffRaise, staffYaw, 0.08)
		out.StaffJoint = CFrame.Angles(staffPitch, 0, -0.06)
		out.ShoulderLJoint = CFrame.Angles(lArmSwing, 0, -0.10)
		out.HipLJoint = CFrame.Angles(0.24 * (if t < 0.68 then 1 else 1 - (t - 0.68) / 0.32), 0, 0)
		out.HipRJoint = CFrame.Angles(-0.22 * (if t < 0.68 then 1 else 1 - (t - 0.68) / 0.32), 0, 0)
		out.KneeLJoint = CFrame.Angles(-0.20, 0, 0)
		out.KneeRJoint = CFrame.Angles(-0.28, 0, 0)
		out.CapeJoint = CFrame.Angles(capeFlare, waistYaw * 0.25, 0)
		out.CapeHemJoint = CFrame.Angles(capeFlare * 0.35 - 0.12, math.sin(u * 2) * 0.10, 0)
		out.LanternJoint = CFrame.Angles(-waistPitch * 0.4, 0, 0.16 * math.sin(t * math.pi))
		out.NetCoreJoint = CFrame.Angles(u * 2.5, u * 3.2, 0)
		return out
	elseif mode == "Chase" then
		local strideL = math.sin(u) * 0.66
		local strideR = math.sin(u + math.pi) * 0.66
		local kneeL = -math.max(0, -math.cos(u)) * 0.55 - 0.06
		local kneeR = -math.max(0, math.cos(u)) * 0.55 - 0.06
		local stomp = (-0.06 + math.abs(math.sin(u)) * (if isBossScale then 0.11 else 0.13)) * s
		local roll = math.sin(u) * 0.06
		local yaw = math.cos(u) * 0.09
		local wave = math.sin(u * 2 - 0.5) * 0.12

		out.RootJoint = CFrame.new(0, stomp, 0) * CFrame.Angles(-0.08, yaw * 0.5, roll)
		out.HipLJoint = CFrame.Angles(strideL, 0, 0)
		out.HipRJoint = CFrame.Angles(strideR, 0, 0)
		out.KneeLJoint = CFrame.Angles(kneeL, 0, 0)
		out.KneeRJoint = CFrame.Angles(kneeR, 0, 0)
		out.WaistJoint = CFrame.Angles(-0.22 + math.sin(u * 2) * 0.05, -yaw * 1.15, -roll * 0.6)
		out.NeckJoint = CFrame.Angles(0.16 + math.cos(u * 2) * 0.04, yaw * 0.45, math.sin(u * 0.5) * 0.06)
		out.ShoulderLJoint = CFrame.Angles(-math.sin(u) * 0.64, 0, -0.08)
		out.ShoulderRJoint = CFrame.Angles(0.32 + math.sin(u) * 0.20, -yaw * 0.4, 0.06)
		out.StaffJoint = CFrame.Angles(0.20 + math.sin(u - 0.4) * 0.10, 0, -0.08)
		out.CapeJoint = CFrame.Angles(-0.44 + wave, -yaw * 0.4, roll * 0.8)
		out.CapeHemJoint = CFrame.Angles(-0.24 + math.sin(u * 2 - 1.2) * 0.20, math.sin(u - 0.6) * 0.08, 0)
		out.LanternJoint = CFrame.Angles(-0.14 + math.sin(u - 0.4) * 0.32, 0, 0.12 + math.cos(u) * 0.10)
		out.NetCoreJoint = CFrame.Angles(u * 1.8, u * 2.4, 0)
		return out
	elseif mode == "Walk" then
		local strideL = math.sin(u) * 0.44
		local strideR = math.sin(u + math.pi) * 0.44
		local kneeL = -math.max(0, -math.cos(u)) * 0.42
		local kneeR = -math.max(0, math.cos(u)) * 0.42
		local stomp = (-0.04 + math.abs(math.sin(u)) * 0.09) * s
		local roll = math.sin(u) * 0.04
		local yaw = math.cos(u) * 0.06

		out.RootJoint = CFrame.new(0, stomp, 0) * CFrame.Angles(-0.03, yaw * 0.4, roll)
		out.HipLJoint = CFrame.Angles(strideL, 0, 0)
		out.HipRJoint = CFrame.Angles(strideR, 0, 0)
		out.KneeLJoint = CFrame.Angles(kneeL, 0, 0)
		out.KneeRJoint = CFrame.Angles(kneeR, 0, 0)
		out.WaistJoint = CFrame.Angles(-0.07 + math.sin(u * 2) * 0.03, -yaw, -roll * 0.5)
		out.NeckJoint = CFrame.Angles(0.05 + math.cos(u * 2) * 0.02, math.sin(u * 0.35) * 0.14, 0)
		out.ShoulderLJoint = CFrame.Angles(-math.sin(u) * 0.40, 0, -0.04)
		out.ShoulderRJoint = CFrame.Angles(0.10 + math.sin(u) * 0.12, 0, 0.03)
		out.StaffJoint = CFrame.Angles(0.06 + math.cos(u - 0.3) * 0.06, 0, 0)
		out.CapeJoint = CFrame.Angles(-0.24 + math.sin(u * 2 - 0.4) * 0.08, -yaw * 0.3, roll * 0.5)
		out.CapeHemJoint = CFrame.Angles(-0.14 + math.sin(u * 2 - 1.1) * 0.15, math.sin(u - 0.5) * 0.05, 0)
		out.LanternJoint = CFrame.Angles(-0.06 + math.sin(u - 0.35) * 0.22, 0, 0.07 + math.cos(u) * 0.06)
		out.NetCoreJoint = CFrame.Angles(u * 1.2, u * 1.6, 0)
		return out
	else
		local breath = math.sin(u)
		local scan = math.sin(u * 0.5)
		out.RootJoint = CFrame.new(0, breath * 0.055 * s, 0) * CFrame.Angles(breath * 0.015, 0, 0)
		out.WaistJoint = CFrame.Angles(breath * 0.035, scan * 0.05, 0)
		out.NeckJoint = CFrame.Angles(-breath * 0.025, scan * 0.28, scan * 0.03)
		out.ShoulderLJoint = CFrame.Angles(math.sin(u + 0.5) * 0.06, 0, -0.03)
		out.ShoulderRJoint = CFrame.Angles(0.06 + breath * 0.05, 0, 0.03)
		out.StaffJoint = CFrame.Angles(0.04 + math.sin(u - 0.5) * 0.04, 0, 0)
		out.HipLJoint = CFrame.Angles(-breath * 0.02, 0, 0)
		out.HipRJoint = CFrame.Angles(-breath * 0.02, 0, 0)
		out.KneeLJoint = CFrame.Angles(breath * 0.02, 0, 0)
		out.KneeRJoint = CFrame.Angles(breath * 0.02, 0, 0)
		out.CapeJoint = CFrame.Angles(-0.10 - math.sin(u * 0.8) * 0.06, scan * 0.04, 0)
		out.CapeHemJoint = CFrame.Angles(-0.08 - math.sin(u * 0.8 - 0.9) * 0.10, math.cos(u * 0.5) * 0.04, 0)
		out.LanternJoint = CFrame.Angles(math.sin(u * 0.9 - 0.4) * 0.08, 0, math.cos(u * 0.7) * 0.06)
		out.NetCoreJoint = CFrame.Angles(u * 1.0, u * 1.4, 0)
		return out
	end
end

local function populateAnimSaves(model: Model, boneSet: { [string]: boolean }, s: number, tier: number)
	local animSaves = Instance.new("Model")
	animSaves.Name = "AnimSaves"
	animSaves.Parent = model

	local specs: { { name: string, mode: GuardAnimMode, dur: number, loop: boolean, prio: Enum.AnimationPriority } } = {
		{ name = "Idle", mode = "Idle", dur = 2.4, loop = true, prio = Enum.AnimationPriority.Idle },
		{ name = "Walk", mode = "Walk", dur = 1.0, loop = true, prio = Enum.AnimationPriority.Movement },
		{ name = "Chase", mode = "Chase", dur = 0.72, loop = true, prio = Enum.AnimationPriority.Movement },
		{ name = "Attack", mode = "Attack", dur = 0.65, loop = false, prio = Enum.AnimationPriority.Action },
	}
	for _, sp in ipairs(specs) do
		local kfs = Instance.new("KeyframeSequence")
		kfs.Name = sp.name
		kfs.Loop = sp.loop
		kfs.Priority = sp.prio
		kfs.Parent = animSaves

		local stepCount = 6
		for step = 0, stepCount do
			local frac = step / stepCount
			local deltas = VoxelPetGuardBuilder.SamplePoseDeltas(sp.mode, frac * math.pi * 2, s, tier, frac)
			local poses: { [string]: CFrame } = {}
			for jName, dCF in pairs(deltas) do
				local bName = JOINT_TO_BONE[jName]
				if bName then
					poses[bName] = dCF
				end
			end
			local kf = Instance.new("Keyframe")
			kf.Name = "KF_" .. tostring(step)
			kf.Time = frac * sp.dur
			buildPoseHierarchy(boneSet, poses).Parent = kf
			kf.Parent = kfs
		end
	end
end

type MotorCacheEntry = {
	motor: Motor6D,
	baseC0: CFrame,
}

local cachedJointMaps: { [Model]: { [string]: MotorCacheEntry } } = setmetatable({}, { __mode = "k" }) :: any
local watchedStreamingModels: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function getJointMap(model: Model): { [string]: MotorCacheEntry }
	if not watchedStreamingModels[model] then
		watchedStreamingModels[model] = true
		model.DescendantAdded:Connect(function(d)
			if d:IsA("Motor6D") then
				cachedJointMaps[model] = nil
			end
		end)
	end

	local cached = cachedJointMaps[model]
	if cached then
		local firstKey, firstEntry = next(cached)
		if firstKey ~= nil and firstEntry ~= nil and firstEntry.motor.Parent ~= nil then
			return cached
		end
		cached = nil
	end

	local map: { [string]: MotorCacheEntry } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			local baseAttr = d:GetAttribute("BaseC0")
			local baseCF = if typeof(baseAttr) == "CFrame" then baseAttr else d.C0
			map[d.Name] = { motor = d, baseC0 = baseCF }
		end
	end
	if next(map) ~= nil then
		cachedJointMaps[model] = map
	end
	return map
end

--- Steps all Motor6D joints smoothly for a rigged Guard Model using a 60 FPS procedural cycle.
function VoxelPetGuardBuilder.StepRig(
	model: Model,
	mode: GuardAnimMode,
	u: number,
	blendAlpha: number?,
	attackProgress: number?
)
	if not model or not model.Parent then
		return
	end
	local s = tonumber(model:GetAttribute("GuardScale")) or 1.0
	local tier = tonumber(model:GetAttribute("GuardTier")) or 1
	local deltas = VoxelPetGuardBuilder.SamplePoseDeltas(mode, u, s, tier, attackProgress)
	local joints = getJointMap(model)
	local alpha = math.clamp(blendAlpha or 1.0, 0.05, 1.0)
	for jName, entry in pairs(joints) do
		local m = entry.motor
		if m.Parent then
			local d = deltas[jName]
			local targetC0 = if d then (entry.baseC0 * d) else entry.baseC0
			if alpha >= 0.99 then
				m.C0 = targetC0
			else
				m.C0 = m.C0:Lerp(targetC0, alpha)
			end
		end
	end
end

--- Resets all Motor6D joints on a rigged Guard Model back to their rest pose (`BaseC0`).
function VoxelPetGuardBuilder.ResetRig(model: Model)
	if not model or not model.Parent then
		return
	end
	local joints = getJointMap(model)
	for _, entry in pairs(joints) do
		if entry.motor.Parent then
			entry.motor.C0 = entry.baseC0
		end
	end
end

--- Builds a single Biome Pet Guard / Enemy Model grounded at `rootCF.Position.Y`.
--- When `opts.rigged == true`, constructs Motor6D skeleton, Welds, AnimationController/Animator, and AnimSaves.
function VoxelPetGuardBuilder.Build(biomeId: string, rootCF: CFrame?, opts: BuildOptions?): Model
	local cfg = VoxelPetGuardBuilder.GetConfig(biomeId)
	local options = opts or {}
	local cf = rootCF or CFrame.new()
	local s = options.scale or cfg.scale
	local cc = if options.canCollide ~= nil then options.canCollide else false
	local withEffects = if options.withEffects ~= nil then options.withEffects else true
	local rigged = options.rigged == true
	local isBoss = options.isBoss == true

	local model = Instance.new("Model")
	model.Name = "PetGuard_" .. cfg.biomeId

	local rigState: RigState? = nil
	if rigged then
		rigState = {
			hubs = {},
			activeBone = nil,
			partToBone = {},
			boneSet = { HumanoidRootPart = true },
		}
		activeRigState = rigState
	end

	local originCF = CFrame.new()
	local rootPart = makeBox(model, originCF, s, "HumanoidRootPart", Vector3.new(2.2, 3.0, 1.4), CFrame.new(0, 3.2, 0), cfg.palette.armorDark, Enum.Material.SmoothPlastic, cc, 1)
	rootPart.CastShadow = false
	rootPart.Massless = false
	model.PrimaryPart = rootPart

	buildLegsAndBoots(model, originCF, s, cfg, cc, rigState)
	local lanternPivot = buildBeltAndLantern(model, originCF, s, cfg, cc, withEffects, rigState)
	buildTorsoAndCowl(model, originCF, s, cfg, cc, rigState)
	local rFistCF, armOutX = buildArmsAndPauldrons(model, originCF, s, cfg, cc, rigState)
	buildHeadAndHat(model, originCF, s, cfg, cc, rigState)
	local capeHemPivot = buildTatteredCape(model, originCF, s, cfg, cc, rigState)
	local hoopCenterPos = buildNetStaff(model, originCF, s, cfg, rFistCF, cc, withEffects, rigState)

	activeRigState = nil

	local flushDy = flushModelBottomToY(model, 0)

	if isBoss then
		local ring = Instance.new("Part")
		ring.Name = "BossAuraRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.10, 4.6 * cfg.widthMult * s, 4.6 * cfg.widthMult * s)
		ring.CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = cfg.palette.neonSecondary
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.25
		ring.TopSurface = Enum.SurfaceType.Smooth
		ring.BottomSurface = Enum.SurfaceType.Smooth
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Parent = model

		if withEffects then
			local lCore = model:FindFirstChild("LanternCore")
			local lLight = if lCore then lCore:FindFirstChild("LanternGlowLight") else nil
			if lLight and lLight:IsA("PointLight") then
				lLight.Brightness = 1.9
			end
		end
	end

	local rootYOffset = rootPart.Position.Y
	rootPart.PivotOffset = CFrame.new(0, -rootYOffset, 0)
	model:SetAttribute("RootYOffset", rootYOffset)

	if rigged and rigState then
		local hubs = rigState.hubs
		local dyVec = Vector3.new(0, flushDy, 0)
		local wM = cfg.widthMult
		local legBaseX = 0.72 * (0.94 + wM * 0.06)

		for part, boneHub in pairs(rigState.partToBone) do
			local w = Instance.new("WeldConstraint")
			w.Part0 = boneHub
			w.Part1 = part
			w.Parent = boneHub
		end
		local bossRing = model:FindFirstChild("BossAuraRing")
		if bossRing and bossRing:IsA("BasePart") then
			local rw = Instance.new("WeldConstraint")
			rw.Part0 = rootPart
			rw.Part1 = bossRing
			rw.Parent = rootPart
		end

		local function link(jName: string, p0: BasePart?, p1: BasePart?, unscaledPivot: Vector3)
			if p0 and p1 then
				attachMotor(jName, p0, p1, unscaledPivot * s + dyVec)
			end
		end

		link("RootJoint", rootPart, hubs.Pelvis, Vector3.new(0, 2.35, 0))
		link("LanternJoint", hubs.Pelvis, hubs.Lantern, lanternPivot)
		link("HipLJoint", hubs.Pelvis, hubs.LegL, Vector3.new(-legBaseX, 2.12, 0))
		link("HipRJoint", hubs.Pelvis, hubs.LegR, Vector3.new(legBaseX, 2.12, 0))
		link("KneeLJoint", hubs.LegL, hubs.FootL, Vector3.new(-legBaseX, 0.98, 0))
		link("KneeRJoint", hubs.LegR, hubs.FootR, Vector3.new(legBaseX, 0.98, 0))
		link("WaistJoint", hubs.Pelvis, hubs.Torso, Vector3.new(0, 2.75, 0))
		link("NeckJoint", hubs.Torso, hubs.Head, Vector3.new(0, 5.05, 0))
		link("ShoulderRJoint", hubs.Torso, hubs.ArmR, Vector3.new(1.54 + armOutX, 4.00, -0.10))
		link("ShoulderLJoint", hubs.Torso, hubs.ArmL, Vector3.new(-1.50 - armOutX, 3.96, -0.02))
		link("StaffJoint", hubs.ArmR, hubs.NetStaff, rFistCF.Position)
		if hubs.NetCore then
			link("NetCoreJoint", hubs.NetStaff, hubs.NetCore, hoopCenterPos)
		end
		link("CapeJoint", hubs.Torso, hubs.Cape, Vector3.new(0, 4.18, 0.90))
		link("CapeHemJoint", hubs.Cape, hubs.CapeHem, capeHemPivot)

		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= rootPart then
				d.Anchored = false
				d.Massless = true
			end
		end

		local animCtrl = Instance.new("AnimationController")
		animCtrl.Name = "AnimationController"
		animCtrl.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = animCtrl
		populateAnimSaves(model, rigState.boneSet, s, cfg.tier)

		model:SetAttribute("VoxelGuardRig", true)
	end

	model:PivotTo(cf)

	local partCount = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			partCount += 1
		end
	end

	model:SetAttribute("BiomeId", cfg.biomeId)
	model:SetAttribute("GuardTier", cfg.tier)
	model:SetAttribute("GuardTitle", cfg.title)
	model:SetAttribute("GuardDifficulty", cfg.difficulty)
	model:SetAttribute("GuardScale", s)
	model:SetAttribute("IsBoss", isBoss)
	model:SetAttribute("PartCount", partCount)

	if options.parent then
		model.Parent = options.parent
	end
	return model
end

local function makeShowroomPart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	canCollide: boolean?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.shape then
		p.Shape = props.shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = props.parent
	return p
end

--- Helper to build a sleek angled museum-grade pedestal plaque (never obscures boots/shins)
function VoxelPetGuardBuilder.AttachPedestalPlaque(
	parent: Instance,
	cfg: GuardTierConfig,
	plaqueCF: CFrame,
	width: number?,
	height: number?
): Part
	local w = width or 6.2
	local h = height or 1.65

	local board = makeShowroomPart({
		name = "GuardPlaque_" .. cfg.biomeId,
		size = Vector3.new(w, h, 0.22),
		cframe = plaqueCF,
		color = Color3.fromRGB(16, 18, 28),
		parent = parent,
	})
	makeShowroomPart({
		name = "GuardPlaqueRimTop_" .. cfg.biomeId,
		size = Vector3.new(w + 0.16, 0.10, 0.26),
		cframe = plaqueCF * CFrame.new(0, h * 0.5 + 0.04, 0),
		color = cfg.palette.neonPrimary,
		material = Enum.Material.Neon,
		parent = parent,
	})
	makeShowroomPart({
		name = "GuardPlaqueRimBot_" .. cfg.biomeId,
		size = Vector3.new(w + 0.16, 0.10, 0.26),
		cframe = plaqueCF * CFrame.new(0, -h * 0.5 - 0.04, 0),
		color = cfg.palette.trimGold,
		material = Enum.Material.Metal,
		parent = parent,
	})

	local sg = Instance.new("SurfaceGui")
	sg.Name = "PlaqueGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(440, 100)
	sg.LightInfluence = 0.1
	sg.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
	frame.BorderSizePixel = 0
	frame.Parent = sg

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(0.94, 0, 0.48, 0)
	tLbl.Position = UDim2.new(0.03, 0, 0.06, 0)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.FredokaOne
	tLbl.TextScaled = true
	tLbl.TextColor3 = cfg.palette.trimGold
	tLbl.TextStrokeTransparency = 0.2
	tLbl.Text = string.format("TIER %d • %s", cfg.tier, string.upper(cfg.title))
	tLbl.Parent = frame

	local sLbl = Instance.new("TextLabel")
	sLbl.Size = UDim2.new(0.94, 0, 0.36, 0)
	sLbl.Position = UDim2.new(0.03, 0, 0.56, 0)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBold
	sLbl.TextScaled = true
	sLbl.TextColor3 = cfg.palette.neonPrimary
	sLbl.Text = string.format("%s | %.2fx Scale • %s", cfg.biomeId, cfg.scale, string.upper(cfg.difficulty))
	sLbl.Parent = frame

	return board
end

--- Builds the 5-Biome Pet Guard / Enemy Lineup Showcase in PetLab_Showroom (T1 -> T5).
function VoxelPetGuardBuilder.BuildShowroomLineup(stageParent: Instance, originOffset: Vector3?): Model
	local existing = stageParent:FindFirstChild("Showcase_PetGuards")
	if existing then
		existing:Destroy()
	end

	local off = originOffset or Vector3.new(0, 0, 0)
	local lineup = Instance.new("Model")
	lineup.Name = "Showcase_PetGuards"
	lineup.Parent = stageParent

	local podiumTopY = 0.54 + off.Y
	local podiumZ = 42.0 + off.Z

	-- Dark unified podium bay at X = -102 .. -17.5 (clear of Showcase_PrimordialCrate at X = -10)
	makeShowroomPart({
		name = "GuardLineupPodiumBase",
		size = Vector3.new(84.5, 0.50, 18.0),
		cframe = CFrame.new(-59.75 + off.X, 0.29 + off.Y, podiumZ),
		color = Color3.fromRGB(24, 28, 38),
		canCollide = true,
		parent = lineup,
	})
	makeShowroomPart({
		name = "GuardLineupFrontNeonTrim",
		size = Vector3.new(84.5, 0.10, 0.24),
		cframe = CFrame.new(-59.75 + off.X, podiumTopY - 0.03, podiumZ - 9.0),
		color = Color3.fromRGB(204, 68, 255),
		material = Enum.Material.Neon,
		parent = lineup,
	})

	-- 5-stud Player Height Comparison Post on East edge of podium
	local refX = -19.5 + off.X
	makeShowroomPart({
		name = "PlayerScaleRefPad",
		size = Vector3.new(2.2, 0.12, 2.2),
		cframe = CFrame.new(refX, podiumTopY + 0.06, podiumZ),
		color = Color3.fromRGB(64, 74, 96),
		parent = lineup,
	})
	local refBody = makeShowroomPart({
		name = "PlayerScaleRef5Studs",
		size = Vector3.new(1.8, 5.0, 1.0),
		cframe = CFrame.new(refX, podiumTopY + 2.5, podiumZ),
		color = Color3.fromRGB(148, 178, 224),
		parent = lineup,
	})
	local refBb = Instance.new("BillboardGui")
	refBb.Size = UDim2.fromOffset(110, 38)
	refBb.StudsOffset = Vector3.new(0, 3.4, 0)
	refBb.AlwaysOnTop = false
	refBb.MaxDistance = 75
	refBb.Parent = refBody
	local refLbl = Instance.new("TextLabel")
	refLbl.Size = UDim2.fromScale(1, 1)
	refLbl.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
	refLbl.BackgroundTransparency = 0.15
	refLbl.Font = Enum.Font.FredokaOne
	refLbl.TextScaled = true
	refLbl.TextColor3 = Color3.fromRGB(178, 224, 255)
	refLbl.Text = "PLAYER\n5 STUDS"
	refLbl.Parent = refBb
	Instance.new("UICorner", refLbl).CornerRadius = UDim.new(0, 6)

	-- Overhead Gallery Header Sign facing -Z directly toward Player Spawn (Face = Front == -Z natively!)
	local headerSign = makeShowroomPart({
		name = "GuardLineupHeaderBoard",
		size = Vector3.new(66.0, 3.8, 0.35),
		cframe = CFrame.new(-59.5 + off.X, 23.0 + off.Y, podiumZ + 8.4),
		color = Color3.fromRGB(16, 18, 28),
		parent = lineup,
	})
	makeShowroomPart({
		name = "GuardLineupHeaderNeonTop",
		size = Vector3.new(66.0, 0.16, 0.42),
		cframe = CFrame.new(-59.5 + off.X, 24.98 + off.Y, podiumZ + 8.4),
		color = Color3.fromRGB(204, 68, 255),
		material = Enum.Material.Neon,
		parent = lineup,
	})
	makeShowroomPart({
		name = "GuardLineupHeaderNeonBot",
		size = Vector3.new(66.0, 0.16, 0.42),
		cframe = CFrame.new(-59.5 + off.X, 21.02 + off.Y, podiumZ + 8.4),
		color = Color3.fromRGB(255, 184, 38),
		material = Enum.Material.Neon,
		parent = lineup,
	})
	local hGui = Instance.new("SurfaceGui")
	hGui.Name = "HeaderGui"
	hGui.Face = Enum.NormalId.Front
	hGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	hGui.CanvasSize = Vector2.new(1120, 96)
	hGui.LightInfluence = 0.1
	hGui.Parent = headerSign
	local hFrame = Instance.new("Frame")
	hFrame.Size = UDim2.fromScale(1, 1)
	hFrame.BackgroundColor3 = Color3.fromRGB(18, 16, 30)
	hFrame.BorderSizePixel = 0
	hFrame.Parent = hGui
	local hTitle = Instance.new("TextLabel")
	hTitle.Size = UDim2.new(0.96, 0, 0.56, 0)
	hTitle.Position = UDim2.new(0.02, 0, 0.06, 0)
	hTitle.BackgroundTransparency = 1
	hTitle.Font = Enum.Font.FredokaOne
	hTitle.TextScaled = true
	hTitle.TextColor3 = Color3.fromRGB(255, 224, 112)
	hTitle.TextStrokeTransparency = 0.2
	hTitle.Text = "PET GUARD / ENEMY SHOWROOM — 5 BIOME TIERS (T1 -> T5)"
	hTitle.Parent = hFrame
	local hSub = Instance.new("TextLabel")
	hSub.Size = UDim2.new(0.96, 0, 0.30, 0)
	hSub.Position = UDim2.new(0.02, 0, 0.64, 0)
	hSub.BackgroundTransparency = 1
	hSub.Font = Enum.Font.GothamBold
	hSub.TextScaled = true
	hSub.TextColor3 = Color3.fromRGB(204, 148, 255)
	hSub.Text = "5-View Reference Voxel Design • Increasing Scale, Horns, Pauldrons & Menace per Biome"
	hSub.Parent = hFrame

	-- Spawn each Biome Tier Guard cleanly spaced (Tier 1 -> Tier 5) facing -Z
	local baySlots = {
		{ biomeId = "PineWoods", x = -26.5, padDia = 7.4 },
		{ biomeId = "MangroveSwamp", x = -38.0, padDia = 8.8 },
		{ biomeId = "SavannaCamp", x = -52.0, padDia = 10.6 },
		{ biomeId = "AlpinePeaks", x = -68.5, padDia = 12.6 },
		{ biomeId = "VolcanicJungle", x = -89.5, padDia = 15.6 },
	}

	for _, slot in ipairs(baySlots) do
		local cfg = VoxelPetGuardBuilder.GetConfig(slot.biomeId)
		local gx = slot.x + off.X

		local glowRing = makeShowroomPart({
			name = "GuardRing_" .. cfg.biomeId,
			size = Vector3.new(0.14, slot.padDia, slot.padDia),
			cframe = CFrame.new(gx, podiumTopY + 0.07, podiumZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = cfg.palette.neonPrimary,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Cylinder,
			parent = lineup,
		})
		glowRing.CastShadow = false

		local topDisk = makeShowroomPart({
			name = "GuardDisk_" .. cfg.biomeId,
			size = Vector3.new(0.16, slot.padDia - 0.55, slot.padDia - 0.55),
			cframe = CFrame.new(gx, podiumTopY + 0.08, podiumZ) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(36, 40, 54),
			shape = Enum.PartType.Cylinder,
			canCollide = true,
			parent = lineup,
		})
		topDisk.CastShadow = false

		local standY = podiumTopY + 0.16
		local guardCF = CFrame.new(gx, standY, podiumZ) -- faces -Z natively
		VoxelPetGuardBuilder.Build(cfg.biomeId, guardCF, {
			canCollide = false,
			withEffects = true,
			parent = lineup,
		})

		-- Angled Museum Plaque resting cleanly ON TOP of front rim of podium (never clipped by floor!)
		local plaqueCF = CFrame.new(gx, podiumTopY + 0.80, podiumZ - 8.35) * CFrame.Angles(math.rad(-30), 0, 0)
		VoxelPetGuardBuilder.AttachPedestalPlaque(lineup, cfg, plaqueCF, 7.2, 1.55)
	end

	return lineup
end

return VoxelPetGuardBuilder
