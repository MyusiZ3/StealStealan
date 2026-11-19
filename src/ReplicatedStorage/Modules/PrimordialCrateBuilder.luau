--!strict
-- PrimordialCrateBuilder.luau
-- Builds the modular 3D Voxel Primordial Containment Reliquary matching the 7-view turnaround concept.
-- Exposes standard BuildCrateModel contract: CrateRoot PrimaryPart, ground-anchored PivotOffset at Y = 0,
-- TowRing, and optional RarityBeacon / CosmicBeaconCore when showBeacon == true. Zero PointLights (anti-glare).

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local PrimordialCrateBuilder = {}

PrimordialCrateBuilder.CRATE_TITLE = "Primordial Cataclysm Reliquary"

export type BuildOpts = {
	isBuried: boolean?,
	canCollide: boolean?,
	showBeacon: boolean?,
	variant: number?,
	lowDetail: boolean?,
}

local OBSIDIAN_DARK = Color3.fromRGB(22, 20, 26)
local OBSIDIAN_MID = Color3.fromRGB(44, 39, 52)
local OBSIDIAN_RIM = Color3.fromRGB(64, 56, 74)
local GOLD_BRIGHT = Color3.fromRGB(228, 168, 74)
local GOLD_BRONZE = Color3.fromRGB(168, 106, 42)
local RUBY_CHAMBER = Color3.fromRGB(158, 14, 42)
local CRIMSON_NEON = Color3.fromRGB(255, 34, 78)
local ROSE_CORE = Color3.fromRGB(255, 134, 168)

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local MAT_NEON = Enum.Material.Neon

-- Build orthogonal 2D pixel/voxel grid helper around face normal:
-- face = "Front" (-Z), "Back" (+Z), "Left" (-X), "Right" (+X)
local function buildFaceDiamond(
	vox: (string, number, number, number, number, number, number, Color3, Enum.Material, CFrame?) -> Part,
	face: string,
	centerU: number,
	centerY: number,
	faceDepth: number,
	normalSign: number,
	voxelStep: number,
	ringSteps: number,
	starRadius: number,
	lowDetail: boolean
)
	local function placeOnFace(name: string, u: number, y: number, wU: number, hY: number, thick: number, outOff: number, col: Color3, mat: Enum.Material)
		local d = faceDepth + normalSign * (outOff + thick * 0.5)
		if face == "Front" or face == "Back" then
			local lx = if face == "Front" then u else -u
			vox(name, wU, hY, thick, lx, y - hY * 0.5, d, col, mat)
		else
			local lz = if face == "Right" then u else -u
			vox(name, thick, hY, wU, d, y - hY * 0.5, lz, col, mat)
		end
	end

	-- Stepped obsidian outer backing diamond (odd/even micro relief eliminates coplanar edge shimmer)
	for row = -ringSteps, ringSteps do
		local span = (ringSteps - math.abs(row)) * 2 + 1
		local uWidth = span * voxelStep
		local relief = (math.abs(row) % 2) * 0.005
		placeOnFace("LockBackRow", centerU, centerY + row * voxelStep, uWidth, voxelStep, 0.08, 0.00 + relief, OBSIDIAN_DARK, MAT_PLASTIC)
	end

	-- Stepped bronze/gold diamond bezel
	local goldHalf = ringSteps - 1
	for row = -goldHalf, goldHalf do
		local span = (goldHalf - math.abs(row)) * 2 + 1
		local uWidth = span * voxelStep
		local col = if math.abs(row) >= goldHalf - 1 then GOLD_BRONZE else GOLD_BRIGHT
		local relief = (math.abs(row) % 2) * 0.005
		placeOnFace("LockGoldRow", centerU, centerY + row * voxelStep, uWidth, voxelStep, 0.09, 0.06 + relief, col, MAT_PLASTIC)
	end

	-- Inner obsidian diamond socket (single compact block reduces part count while preserving crisp pixel bevel)
	local innerHalf = math.max(1, goldHalf - 2)
	local sockSize = (innerHalf * 2 + 1) * voxelStep * 0.85
	placeOnFace("LockSocket", centerU, centerY, sockSize, sockSize, 0.07, 0.13, OBSIDIAN_DARK, MAT_PLASTIC)

	-- 4-Point Crimson Neon Star Gem + Hot-Pink Center Pin
	local armLen = starRadius * 2.0
	local armThick = if lowDetail then voxelStep * 1.15 else voxelStep * 0.95
	placeOnFace("LockGemH", centerU, centerY, armLen, armThick, 0.08, 0.18, CRIMSON_NEON, MAT_NEON)
	placeOnFace("LockGemV", centerU, centerY, armThick, armLen, 0.08, 0.186, CRIMSON_NEON, MAT_NEON)
	placeOnFace("LockGemCore", centerU, centerY, armThick * 1.15, armThick * 1.15, 0.08, 0.22, ROSE_CORE, MAT_NEON)
end

local function buildSteppedXBrace(
	vox: (string, number, number, number, number, number, number, Color3, Enum.Material, CFrame?) -> Part,
	face: string,
	faceDepth: number,
	normalSign: number,
	spanU: number,
	centerY: number,
	spanY: number,
	steps: number
)
	local function placeArmPart(name: string, u: number, y: number, wU: number, hY: number, thick: number, outOff: number, col: Color3)
		local d = faceDepth + normalSign * (outOff + thick * 0.5)
		if face == "Back" then
			vox(name, wU, hY, thick, -u, y - hY * 0.5, d, col, MAT_PLASTIC)
		elseif face == "Right" then
			vox(name, thick, hY, wU, d, y - hY * 0.5, u, col, MAT_PLASTIC)
		else
			vox(name, thick, hY, wU, d, y - hY * 0.5, -u, col, MAT_PLASTIC)
		end
	end

	local stepW = (spanU / steps) * 1.24
	local stepH = (spanY / steps) * 1.24
	for _, su in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for i = 1, steps do
				local t = (i - 0.5) / steps
				local u = su * spanU * (0.20 + t * 0.78)
				local y = centerY + sy * spanY * (0.20 + t * 0.78)
				local relief = (i % 2) * 0.008
				placeArmPart("XBraceBack", u, y, stepW * 1.14, stepH * 1.14, 0.08, 0.00 + relief, OBSIDIAN_DARK)
				local goldCol = if i % 2 == 1 then GOLD_BRIGHT else GOLD_BRONZE
				placeArmPart("XBraceGold", u, y, stepW * 0.84, stepH * 0.84, 0.09, 0.06 + relief, goldCol)
			end
		end
	end
end

function PrimordialCrateBuilder.Build(biomeId: string, sizeScale: number?, opts: BuildOpts?): Model
	local s = sizeScale or GameConfig.ComputeCrateScale("Primordial")
	local isBuried = if opts and opts.isBuried ~= nil then opts.isBuried else true
	local canCollide = if opts and opts.canCollide ~= nil then opts.canCollide else false
	local showBeacon = if opts and opts.showBeacon ~= nil then opts.showBeacon else isBuried
	local styleIdx = math.max(1, math.floor((opts and opts.variant) or 1))
	local lowDetail = (opts and opts.lowDetail == true) or (s < 0.52)

	local crateModel = Instance.new("Model")
	crateModel.Name = string.format("Crate_%s_Primordial", biomeId)
	crateModel:SetAttribute("BiomeId", biomeId)
	crateModel:SetAttribute("Rarity", "Primordial")
	crateModel:SetAttribute("SizeScale", s)
	crateModel:SetAttribute("CrateVariant", styleIdx)
	crateModel:SetAttribute("CrateTitle", PrimordialCrateBuilder.CRATE_TITLE)
	crateModel:SetAttribute("IsVoxelCrate", true)

	local baseYUnit = 2.05
	local baseY = baseYUnit * s
	local tilt = if isBuried then CFrame.Angles(math.rad(10), math.rad(12), math.rad(-7)) else CFrame.new()

	local root = Instance.new("Part")
	root.Name = "CrateRoot"
	root.Size = Vector3.new(4.32 * s, 4.10 * s, 4.16 * s)
	root.CFrame = CFrame.new(0, baseY, 0) * tilt
	root.Color = OBSIDIAN_DARK
	root.Material = MAT_PLASTIC
	root.Transparency = 1
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Anchored = true
	root.CanCollide = canCollide
	root.CanQuery = true
	root.CanTouch = false
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -baseY, 0)
	root.Parent = crateModel

	crateModel.PrimaryPart = root
	crateModel.WorldPivot = CFrame.new(0, 0, 0)

	local rootCF = root.CFrame

	local function vox(name: string, sx: number, sy: number, sz: number, lx: number, lyBottom: number, lz: number, color: Color3, mat: Enum.Material, rotCF: CFrame?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(sx * s, sy * s, sz * s)
		local offsetCF = CFrame.new(lx * s, (lyBottom + sy * 0.5 - baseYUnit) * s, lz * s)
		p.CFrame = rootCF * offsetCF * (rotCF or CFrame.new())
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = (sx * sy * sz >= 0.35) and (mat ~= MAT_NEON)
		p.Parent = crateModel
		return p
	end

	-- 1. Stepped Plinth Base & Golden Corner Claws (Y = 0.00 .. 0.68)
	vox("PlinthBottom", 4.32, 0.26, 4.16, 0, 0.00, 0, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("PlinthStep", 4.08, 0.30, 3.92, 0, 0.26, 0, OBSIDIAN_MID, MAT_PLASTIC)

	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			vox("CornerFoot", 0.98, 0.44, 0.94, cx * 1.82, 0.00, cz * 1.74, OBSIDIAN_DARK, MAT_PLASTIC)
			vox("CornerFootRim", 0.88, 0.20, 0.84, cx * 1.82, 0.44, cz * 1.74, OBSIDIAN_RIM, MAT_PLASTIC)
			-- Stepped antique gold corner claw brackets at foot
			vox("FootClawZ", 0.34, 0.24, 0.22, cx * 1.74, 0.00, cz * 2.18, GOLD_BRIGHT, MAT_PLASTIC)
			vox("FootClawX", 0.22, 0.24, 0.34, cx * 2.26, 0.00, cz * 1.66, GOLD_BRIGHT, MAT_PLASTIC)
			vox("FootClawToe", 0.24, 0.16, 0.24, cx * 2.22, 0.24, cz * 2.12, GOLD_BRONZE, MAT_PLASTIC)
		end
	end

	-- Front bottom sill: bronze trim & twin sharp upward golden fangs framing a crimson notch
	vox("FrontSillBar", 2.48, 0.22, 0.18, 0, 0.24, -2.04, GOLD_BRONZE, MAT_PLASTIC)
	vox("FrontSillNotch", 0.36, 0.14, 0.12, 0, 0.34, -2.09, CRIMSON_NEON, MAT_NEON)
	for _, sx in ipairs({ -1, 1 }) do
		vox("FrontFangBase", 0.26, 0.42, 0.20, sx * 0.32, 0.24, -2.07, GOLD_BRIGHT, MAT_PLASTIC)
		vox("FrontFangTip", 0.16, 0.26, 0.16, sx * 0.32, 0.66, -2.07, GOLD_BRIGHT, MAT_PLASTIC)
		vox("FrontSillStud", 0.22, 0.18, 0.16, sx * 0.92, 0.30, -2.06, OBSIDIAN_RIM, MAT_PLASTIC)
	end

	-- Left, Right, & Back lower sill crimson horizontal energy slits
	vox("BackSillSlit", 2.16, 0.10, 0.10, 0, 0.42, 2.04, CRIMSON_NEON, MAT_NEON)
	vox("BackSillStep", 2.38, 0.16, 0.16, 0, 0.24, 2.02, OBSIDIAN_DARK, MAT_PLASTIC)
	for _, sx in ipairs({ -1, 1 }) do
		vox("SideSillSlit", 0.10, 0.10, 2.00, sx * 2.12, 0.42, 0, CRIMSON_NEON, MAT_NEON)
		vox("SideSillStep", 0.16, 0.16, 2.24, sx * 2.10, 0.24, 0, OBSIDIAN_DARK, MAT_PLASTIC)
	end

	-- 2. Solid Deep Ruby Inner Chamber & 4-Face Glowing Crimson-Rose Panes
	vox("InnerRubyCore", 3.68, 2.94, 3.52, 0, 0.60, 0, RUBY_CHAMBER, MAT_PLASTIC)

	-- Glowing panes & rose inner core highlights on Front/Back (-Z / +Z) and Left/Right (-X / +X)
	for _, sz in ipairs({ -1, 1 }) do
		local zPane = sz * 1.80
		local zRose = sz * 1.835
		for _, sx in ipairs({ -1, 1 }) do
			vox("GlowPaneFB", 1.08, 2.68, 0.09, sx * 0.66, 0.72, zPane, CRIMSON_NEON, MAT_NEON)
			vox("RoseCoreFB", 0.34, 2.48, 0.06, sx * 0.66, 0.82, zRose, ROSE_CORE, MAT_NEON)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local xPane = sx * 1.88
		local xRose = sx * 1.915
		for _, sz in ipairs({ -1, 1 }) do
			vox("GlowPaneSide", 0.09, 2.68, 0.98, xPane, 0.72, sz * 0.60, CRIMSON_NEON, MAT_NEON)
			vox("RoseCoreSide", 0.06, 2.48, 0.32, xRose, 0.82, sz * 0.60, ROSE_CORE, MAT_NEON)
		end
	end

	-- 3. Four Stepped Obsidian Corner Pillars + Recessed Vertical Crimson '+' Channels & Gold Collars
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local px, pz = cx * 1.72, cz * 1.64
			vox("CornerPillar", 0.72, 3.24, 0.70, px, 0.56, pz, OBSIDIAN_DARK, MAT_PLASTIC)

			-- Front/Back pillar face: obsidian left/right cheek armor + recessed vertical crimson slit (0.05 proud of pillar, 0.03 behind cheeks)
			local fzCheek = cz * 2.02
			local fzRune = cz * 2.01
			vox("PillarCheekZ_Out", 0.24, 2.74, 0.10, px + cx * 0.24, 0.66, fzCheek, OBSIDIAN_MID, MAT_PLASTIC)
			vox("PillarCheekZ_In", 0.24, 2.74, 0.10, px - cx * 0.24, 0.66, fzCheek, OBSIDIAN_MID, MAT_PLASTIC)
			vox("PillarRuneZV", 0.15, 2.78, 0.06, px, 0.64, fzRune, CRIMSON_NEON, MAT_NEON)
			vox("PillarRuneZTopPlus", 0.52, 0.15, 0.10, px, 3.16, cz * 2.04, CRIMSON_NEON, MAT_NEON)
			vox("PillarRuneZBotPlus", 0.52, 0.15, 0.10, px, 0.72, cz * 2.04, CRIMSON_NEON, MAT_NEON)

			-- Left/Right pillar face: obsidian cheek armor + recessed vertical crimson slit + '+' cross flares
			local fxCheek = cx * 2.11
			local fxRune = cx * 2.10
			vox("PillarCheekX_Out", 0.10, 2.74, 0.24, fxCheek, 0.66, pz + cz * 0.24, OBSIDIAN_MID, MAT_PLASTIC)
			vox("PillarCheekX_In", 0.10, 2.74, 0.24, fxCheek, 0.66, pz - cz * 0.24, OBSIDIAN_MID, MAT_PLASTIC)
			vox("PillarRuneXV", 0.06, 2.78, 0.15, fxRune, 0.64, pz, CRIMSON_NEON, MAT_NEON)
			vox("PillarRuneXTopPlus", 0.10, 0.15, 0.50, cx * 2.13, 3.16, pz, CRIMSON_NEON, MAT_NEON)
			vox("PillarRuneXBotPlus", 0.10, 0.15, 0.50, cx * 2.13, 0.72, pz, CRIMSON_NEON, MAT_NEON)

			-- Golden upper shoulder collar wrapping corner below cornice
			vox("PillarGoldCollar", 0.88, 0.26, 0.86, cx * 1.76, 3.44, cz * 1.68, GOLD_BRIGHT, MAT_PLASTIC)
			vox("PillarBronzeStep", 0.76, 0.14, 0.74, cx * 1.80, 3.30, cz * 1.72, GOLD_BRONZE, MAT_PLASTIC)
		end
	end

	-- 4. Four Outer Bowed Voxel Iron Chains (from ly = 0.80 .. 3.26)
	local linkCount = if lowDetail then 3 else 5
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			-- Top & bottom chain shackle anchors
			vox("ChainShackleTop", 0.22, 0.20, 0.22, cx * 2.10, 3.16, cz * 1.96, OBSIDIAN_RIM, MAT_PLASTIC)
			vox("ChainShackleBot", 0.22, 0.20, 0.22, cx * 2.10, 0.68, cz * 1.96, OBSIDIAN_RIM, MAT_PLASTIC)
			for i = 1, linkCount do
				local t = i / (linkCount + 1)
				local ly = 0.82 + t * 2.34
				local bow = math.sin(t * math.pi) * 0.18
				local isOdd = (i % 2 == 1)
				local col = if isOdd then OBSIDIAN_DARK else OBSIDIAN_MID
				local sx = if isOdd then 0.16 else 0.24
				local sz = if isOdd then 0.24 else 0.16
				local linkH = (2.34 / (linkCount + 1)) * 1.15
				vox("ChainLink", sx, linkH, sz, cx * (2.14 + bow), ly - linkH * 0.5, cz * (2.00 + bow * 0.9), col, MAT_PLASTIC)
			end
		end
	end

	-- 5. Front View (-Z Face): Cage Bars, Central Stepped Diamond Medallion Lock & Royal V-Wing Clasp
	vox("FrontHBar", 2.60, 0.26, 0.16, 0, 1.74, -1.91, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("FrontVCenterBar", 0.26, 2.86, 0.16, 0, 0.66, -1.91, OBSIDIAN_DARK, MAT_PLASTIC)
	for _, sx in ipairs({ -1, 1 }) do
		vox("FrontInnerMul", 0.18, 2.74, 0.12, sx * 0.88, 0.68, -1.90, OBSIDIAN_MID, MAT_PLASTIC)
	end
	vox("FrontTopLintel", 2.60, 0.36, 0.22, 0, 3.50, -1.94, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("FrontBotLintel", 2.60, 0.24, 0.20, 0, 0.48, -1.94, OBSIDIAN_DARK, MAT_PLASTIC)

	buildFaceDiamond(
		vox,
		"Front",
		0,
		1.86,
		-1.94,
		-1,
		if lowDetail then 0.20 else 0.155,
		if lowDetail then 3 else 4,
		if lowDetail then 0.35 else 0.40,
		lowDetail
	)

	-- Royal V-Winged Golden Clasp / Lid Crest above the front diamond lock
	vox("ClaspCenterObs", 0.46, 0.78, 0.20, 0, 3.12, -2.04, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("ClaspCenterGem", 0.16, 0.38, 0.10, 0, 3.30, -2.11, CRIMSON_NEON, MAT_NEON)
	vox("ClaspCenterFang", 0.24, 0.44, 0.18, 0, 2.76, -2.07, GOLD_BRIGHT, MAT_PLASTIC)
	vox("ClaspFangTip", 0.12, 0.16, 0.16, 0, 2.62, -2.08, GOLD_BRIGHT, MAT_PLASTIC)
	vox("ClaspCrownPeak", 0.22, 0.46, 0.16, 0, 3.90, -2.04, GOLD_BRIGHT, MAT_PLASTIC)
	vox("ClaspCrownTip", 0.12, 0.22, 0.14, 0, 4.36, -2.04, GOLD_BRIGHT, MAT_PLASTIC)
	for _, sx in ipairs({ -1, 1 }) do
		vox("ClaspWingOuter", 0.56, 0.24, 0.18, sx * 0.88, 3.66, -2.04, GOLD_BRIGHT, MAT_PLASTIC)
		vox("ClaspWingMid", 0.48, 0.24, 0.18, sx * 0.50, 3.44, -2.05, GOLD_BRIGHT, MAT_PLASTIC)
		vox("ClaspWingLow", 0.34, 0.24, 0.18, sx * 0.24, 3.20, -2.06, GOLD_BRONZE, MAT_PLASTIC)
		vox("ClaspWingTooth", 0.16, 0.20, 0.14, sx * 0.72, 3.46, -2.06, OBSIDIAN_RIM, MAT_PLASTIC)
	end

	-- 6. Left (-X), Right (+X), & Back (+Z) Faces: Crossbars, Stepped Golden X-Braces & Diamond Locks
	local xSteps = if lowDetail then 2 else 3
	local sideDiamondStep = if lowDetail then 0.18 else 0.14
	local sideDiamondRings = 3

	-- Back Face (+Z)
	vox("BackHBar", 2.60, 0.24, 0.14, 0, 1.92, 1.91, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("BackVBar", 0.24, 2.74, 0.14, 0, 0.68, 1.91, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("BackTopFriezeSlit", 2.28, 0.11, 0.10, 0, 3.36, 1.96, CRIMSON_NEON, MAT_NEON)
	vox("BackTopLintel", 2.60, 0.36, 0.22, 0, 3.50, 1.94, OBSIDIAN_DARK, MAT_PLASTIC)
	buildSteppedXBrace(vox, "Back", 1.92, 1, 1.10, 2.04, 1.10, xSteps)
	buildFaceDiamond(vox, "Back", 0, 2.04, 1.95, 1, sideDiamondStep, sideDiamondRings, 0.28, lowDetail)

	-- Left (-X) & Right (+X) Faces
	for _, sx in ipairs({ -1, 1 }) do
		local fName = if sx > 0 then "Right" else "Left"
		vox(fName .. "HBar", 0.14, 0.24, 2.48, sx * 1.99, 1.92, 0, OBSIDIAN_DARK, MAT_PLASTIC)
		vox(fName .. "VBar", 0.14, 2.74, 0.24, sx * 1.99, 0.68, 0, OBSIDIAN_DARK, MAT_PLASTIC)
		vox(fName .. "TopFriezeSlit", 0.10, 0.11, 2.12, sx * 2.04, 3.36, 0, CRIMSON_NEON, MAT_NEON)
		vox(fName .. "TopLintel", 0.22, 0.36, 2.48, sx * 2.02, 3.50, 0, OBSIDIAN_DARK, MAT_PLASTIC)
		buildSteppedXBrace(vox, fName, 2.00, sx, 1.04, 2.04, 1.10, xSteps)
		buildFaceDiamond(vox, fName, 0, 2.04, 2.03, sx, sideDiamondStep, sideDiamondRings, 0.28, lowDetail)
	end

	-- 7. Crown Battlements, 4 Pointed Corner Turrets, Recessed Crimson Roof Grid & Jagged Dorsal Spire
	vox("RoofChamberBase", 3.60, 0.22, 3.44, 0, 3.74, 0, RUBY_CHAMBER, MAT_PLASTIC)
	vox("RoofCrimsonGlow", 3.24, 0.12, 3.08, 0, 3.90, 0, CRIMSON_NEON, MAT_NEON)
	-- Obsidian lattice crossbeams over the glowing roof (staggered Y eliminates Z-fighting)
	for _, gx in ipairs({ -1.04, 0, 1.04 }) do
		vox("RoofLatticeZ", 0.22, 0.18, 3.04, gx, 3.92, 0, OBSIDIAN_DARK, MAT_PLASTIC)
	end
	for _, gz in ipairs({ -0.98, 0, 0.98 }) do
		vox("RoofLatticeX", 3.22, 0.16, 0.22, 0, 3.91, gz, OBSIDIAN_DARK, MAT_PLASTIC)
	end

	-- Perimeter top cornice battlements (trimmed strictly between corner turrets)
	for _, sz in ipairs({ -1, 1 }) do
		vox("CrownRimZ", 2.82, 0.30, 0.42, 0, 3.80, sz * 1.76, OBSIDIAN_DARK, MAT_PLASTIC)
		vox("CrownCrenelMidZ", 0.62, 0.22, 0.38, 0, 4.10, sz * 1.78, OBSIDIAN_MID, MAT_PLASTIC)
	end
	for _, sx in ipairs({ -1, 1 }) do
		vox("CrownRimX", 0.42, 0.30, 2.66, sx * 1.84, 3.80, 0, OBSIDIAN_DARK, MAT_PLASTIC)
		vox("CrownCrenelMidX", 0.38, 0.22, 0.62, sx * 1.86, 4.10, 0, OBSIDIAN_MID, MAT_PLASTIC)
		-- Gold mid-lid crest accent on left/right
		vox("CrownSideGold", 0.24, 0.20, 0.34, sx * 1.90, 4.16, 0, GOLD_BRIGHT, MAT_PLASTIC)
	end

	-- Four Pointed Obsidian & Gold Corner Crown Turrets
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local tx, tz = cx * 1.76, cz * 1.68
			vox("CornerTurretBase", 0.68, 0.34, 0.68, tx, 3.80, tz, OBSIDIAN_DARK, MAT_PLASTIC)
			vox("CornerTurretStep", 0.46, 0.28, 0.46, cx * 1.78, 4.14, cz * 1.70, OBSIDIAN_MID, MAT_PLASTIC)
			vox("CornerTurretGold", 0.28, 0.28, 0.28, cx * 1.80, 4.42, cz * 1.72, GOLD_BRIGHT, MAT_PLASTIC)
		end
	end

	-- Central Jagged Crimson-Obsidian Dorsal Horn Spire (Peak at ly = 5.14)
	vox("SpireBase", 0.96, 0.28, 1.76, 0, 4.02, 0, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("SpireRibStep", 0.64, 0.26, 1.24, 0, 4.30, 0, OBSIDIAN_MID, MAT_PLASTIC)
	vox("SpireObsPeak", 0.36, 0.24, 0.56, 0, 4.56, 0, OBSIDIAN_DARK, MAT_PLASTIC)
	vox("SpireCrimsonCore", 0.22, 0.42, 0.38, 0, 4.42, 0, CRIMSON_NEON, MAT_NEON)
	vox("SpireTipCrimson", 0.16, 0.20, 0.22, 0, 4.76, 0, CRIMSON_NEON, MAT_NEON)
	vox("SpireApex", 0.10, 0.18, 0.14, 0, 4.96, 0, ROSE_CORE, MAT_NEON)
	vox("SpireFrontFlank", 0.26, 0.30, 0.26, 0, 4.18, -0.66, GOLD_BRIGHT, MAT_PLASTIC)
	vox("SpireBackFlank", 0.24, 0.28, 0.26, 0, 4.18, 0.66, CRIMSON_NEON, MAT_NEON)

	-- TowRing preserved invisibly at dorsal spire base for gameplay tow attachment compatibility
	local ring = vox("TowRing", 0.72, 0.72, 0.72, 0, 4.00, 0, CRIMSON_NEON, MAT_PLASTIC)
	ring.Shape = Enum.PartType.Ball
	ring.Transparency = 1
	ring.CastShadow = false

	-- World Rarity Beacon for wild buried crates
	if showBeacon then
		local beamHeight = 102
		local beacon = Instance.new("Part")
		beacon.Name = "RarityBeacon"
		beacon.Size = Vector3.new(1.55 * s, beamHeight, 1.55 * s)
		beacon.CFrame = rootCF * CFrame.new(0, beamHeight * 0.5 + 2.25 * s, 0)
		beacon.Color = Color3.fromRGB(255, 38, 78)
		beacon.Material = MAT_PLASTIC
		beacon.Transparency = 0.80
		beacon.TopSurface = Enum.SurfaceType.Smooth
		beacon.BottomSurface = Enum.SurfaceType.Smooth
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.CanTouch = false
		beacon.CastShadow = false
		beacon.Parent = crateModel

		local innerCore = Instance.new("Part")
		innerCore.Name = "CosmicBeaconCore"
		innerCore.Size = Vector3.new(0.48 * s, beamHeight + 8, 0.48 * s)
		innerCore.CFrame = rootCF * CFrame.new(0, beamHeight * 0.5 + 2.25 * s, 0)
		innerCore.Color = Color3.fromRGB(255, 168, 74)
		innerCore.Material = MAT_NEON
		innerCore.Transparency = 0.65
		innerCore.TopSurface = Enum.SurfaceType.Smooth
		innerCore.BottomSurface = Enum.SurfaceType.Smooth
		innerCore.Anchored = true
		innerCore.CanCollide = false
		innerCore.CanQuery = false
		innerCore.CanTouch = false
		innerCore.CastShadow = false
		innerCore.Parent = crateModel
	end

	return crateModel
end

return PrimordialCrateBuilder
