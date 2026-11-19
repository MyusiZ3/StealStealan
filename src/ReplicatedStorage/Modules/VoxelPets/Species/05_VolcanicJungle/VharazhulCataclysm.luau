--!strict
-- VharazhulCataclysm.luau
-- Primordial Final Boss: VHARAZHUL, God of the First Cataclysm.
-- Towering bipedal Elder Dragon Boss with 6-cube obsidian/basalt/ivory/crimson/gold/amber palette,
-- glowing fel-green eyes beneath royal golden crown horns, roaring articulated JawJoint,
-- V-shaped pectoral gorget, spiked shoulder gauntlets, colossal crimson/obsidian tattered wings,
-- signature spiked lower wing-tendrils, and golden scythe-tipped serpent tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)

type VoxelSpec = RigCore.VoxelSpec

local C_OBSIDIAN = Color3.fromRGB(22, 22, 27)
local C_BASALT = Color3.fromRGB(74, 76, 86)
local C_BASALT_DARK = Color3.fromRGB(48, 50, 58)
local C_IVORY = Color3.fromRGB(222, 218, 212)
local C_CRIMSON = Color3.fromRGB(188, 24, 34)
local C_CRIMSON_DARK = Color3.fromRGB(132, 16, 24)
local C_GOLD = Color3.fromRGB(238, 192, 68)
local C_AMBER = Color3.fromRGB(196, 136, 42)
local C_FEL_EYE = Color3.fromRGB(92, 255, 72)

local VharazhulCataclysm = {
	Id = "VharazhulCataclysm",
	DisplayName = "VHARAZHUL, God of the First Cataclysm",
	Archetype = "CataclysmColossus" :: RigCore.ArchetypeId,
	DefaultScale = 1.50,
	CameraHeightOffset = 3.35,
	CameraDistMult = 1.65,
	AccentColor = C_CRIMSON,
}

function VharazhulCataclysm.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(2.2, 2.6, 2.4), C_CRIMSON)

	-- 1. UPRIGHT COLOSSAL TORSO (Hub Y = 2.56 -> pelvis 1.50..2.26, barrel ribcage 2.46..3.78)
	local torsoVoxels: { VoxelSpec } = {
		-- Pelvis, waist & deep ribcage core
		{ p = { 0, -0.68, 0.04 }, sz = { 1.24, 0.76, 1.08 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, -0.26, 0.00 }, sz = { 1.32, 0.62, 1.12 }, c = C_BASALT_DARK, tint = "primary" },
		{ p = { 0, 0.44, -0.06 }, sz = { 1.72, 1.08, 1.32 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.96, -0.10 }, sz = { 1.52, 0.52, 1.12 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.38, -0.44 }, sz = { 1.38, 0.86, 0.64 }, c = C_BASALT, tint = "secondary" },

		-- Stepped Central Ivory Belly-to-Sternum Scutes (staggered Z to prevent Z-fighting)
		{ p = { 0, -0.82, -0.48 }, sz = { 0.46, 0.34, 0.24 }, c = C_IVORY, tint = "secondary" },
		{ p = { 0, -0.48, -0.56 }, sz = { 0.54, 0.34, 0.26 }, c = C_IVORY, tint = "secondary" },
		{ p = { 0, -0.14, -0.62 }, sz = { 0.58, 0.34, 0.24 }, c = C_IVORY, tint = "secondary" },
		{ p = { 0, 0.24, -0.70 }, sz = { 0.60, 0.36, 0.26 }, c = C_IVORY, tint = "secondary" },
		{ p = { 0, 0.62, -0.72 }, sz = { 0.54, 0.36, 0.22 }, c = C_IVORY, tint = "secondary" },

		-- Sovereign V-Shaped Gold & Amber Pectoral Gorget
		{ p = { 0, 0.54, -0.80 }, sz = { 0.44, 0.36, 0.22 }, c = C_AMBER, r = { 0, 0, 45 }, tint = "secondary" },
		{ p = { 0, 0.54, -0.88 }, sz = { 0.22, 0.22, 0.14 }, c = C_GOLD, r = { 0, 0, 45 }, tint = "secondary" },
	}

	-- Striated Diagonal Crimson Pectoral/Rib Bands & Gold Gorget Collar Arms
	for _, side in ipairs({ -1, 1 }) do
		-- Lower & mid diagonal crimson rib armor
		table.insert(torsoVoxels, {
			p = { side * 0.50, -0.34, -0.26 },
			sz = { 0.56, 0.24, 0.84 },
			c = C_CRIMSON,
			r = { 12, side * 12, side * -26 },
			tint = "primary",
		})
		table.insert(torsoVoxels, {
			p = { side * 0.62, 0.04, -0.28 },
			sz = { 0.66, 0.26, 0.94 },
			c = C_CRIMSON,
			r = { 10, side * 10, side * -28 },
			tint = "primary",
		})
		table.insert(torsoVoxels, {
			p = { side * 0.58, 0.42, -0.38 },
			sz = { 0.74, 0.34, 0.86 },
			c = C_CRIMSON,
			r = { 8, side * 12, side * -22 },
			tint = "primary",
		})
		-- Outer basalt shoulder-rib guard
		table.insert(torsoVoxels, {
			p = { side * 0.84, 0.24, 0.08 },
			sz = { 0.26, 0.72, 0.76 },
			c = C_BASALT,
			r = { 0, 0, side * -10 },
			tint = "secondary",
		})
		-- Gold pectoral gorget collar wings + collarbone spikes
		table.insert(torsoVoxels, {
			p = { side * 0.46, 0.78, -0.64 },
			sz = { 0.68, 0.22, 0.28 },
			c = C_AMBER,
			r = { 0, side * -14, side * 24 },
			tint = "secondary",
		})
		table.insert(torsoVoxels, {
			p = { side * 0.42, 0.70, -0.74 },
			sz = { 0.64, 0.24, 0.24 },
			c = C_GOLD,
			r = { 0, side * -18, side * 28 },
			tint = "secondary",
		})
		table.insert(torsoVoxels, {
			p = { side * 0.76, 0.96, -0.56 },
			sz = { 0.32, 0.44, 0.26 },
			c = C_GOLD,
			r = { -16, 0, side * -32 },
			tint = "secondary",
		})
		-- Back scapular crimson ridges visible in Back View
		table.insert(torsoVoxels, {
			p = { side * 0.48, 0.52, 0.52 },
			sz = { 0.54, 0.62, 0.34 },
			c = C_CRIMSON_DARK,
			r = { -8, side * -16, side * 18 },
			tint = "primary",
		})
	end

	-- Heavy Interlocking Golden Dorsal Spine Crest down Torso back
	for i = 0, 4 do
		local yOff = 0.92 - i * 0.38
		local zOff = 0.52 + (if i < 2 then 0.04 else 0.08)
		table.insert(torsoVoxels, {
			p = { 0, yOff, zOff },
			sz = { 0.30, 0.32, 0.36 },
			c = C_GOLD,
			r = { 24, 0, 0 },
			tint = "secondary",
		})
		table.insert(torsoVoxels, {
			p = { 0, yOff - 0.08, zOff - 0.14 },
			sz = { 0.40, 0.28, 0.22 },
			c = C_AMBER,
			r = { 16, 0, 0 },
			tint = "secondary",
		})
	end

	-- 2. S-CURVED ARMORED NECK (Hub Y = 3.88, pivot 3.58)
	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, -0.06, 0.10 }, sz = { 1.06, 0.88, 1.04 }, c = C_OBSIDIAN, r = { -14, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.56, -0.14 }, sz = { 0.84, 0.82, 0.90 }, c = C_OBSIDIAN, r = { -22, 0, 0 }, tint = "primary" },
		-- Recessed upper neck socket strictly inside Head cranium
		{ p = { 0, 0.94, -0.28 }, sz = { 0.52, 0.34, 0.54 }, c = C_OBSIDIAN, tint = "primary" },
		-- Segmented Ivory Throat Scutes
		{ p = { 0, -0.16, -0.44 }, sz = { 0.44, 0.32, 0.24 }, c = C_IVORY, r = { -14, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.20, -0.52 }, sz = { 0.40, 0.32, 0.22 }, c = C_IVORY, r = { -18, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.54, -0.60 }, sz = { 0.36, 0.30, 0.22 }, c = C_IVORY, r = { -22, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(neckVoxels, {
			p = { side * 0.44, 0.02, -0.04 },
			sz = { 0.22, 0.58, 0.64 },
			c = C_CRIMSON,
			r = { -18, side * 10, side * -14 },
			tint = "primary",
		})
		table.insert(neckVoxels, {
			p = { side * 0.36, 0.52, -0.18 },
			sz = { 0.20, 0.52, 0.56 },
			c = C_CRIMSON,
			r = { -24, side * 8, side * -12 },
			tint = "primary",
		})
		table.insert(neckVoxels, {
			p = { side * 0.40, 0.24, 0.16 },
			sz = { 0.18, 0.56, 0.34 },
			c = C_BASALT,
			r = { -18, 0, side * -10 },
			tint = "secondary",
		})
	end
	for i = 0, 2 do
		table.insert(neckVoxels, {
			p = { 0, -0.02 + i * 0.38, 0.54 - i * 0.08 },
			sz = { 0.22, 0.34, 0.36 },
			c = C_GOLD,
			r = { 28, 0, 0 },
			tint = "secondary",
		})
	end

	-- 3. ROARING CROWNED HEAD (Hub Y = 4.96, Z = -0.96, pivot 4.78, -0.76)
	local headVoxels: { VoxelSpec } = {
		-- Broad angular cranium + tapered snout
		{ p = { 0, 0.08, 0.04 }, sz = { 0.98, 0.76, 1.08 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.04, -0.68 }, sz = { 0.72, 0.48, 0.62 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, -0.02, -1.16 }, sz = { 0.52, 0.38, 0.52 }, c = C_OBSIDIAN, tint = "primary" },
		-- Basalt snout tip shield & crimson nasal bridge
		{ p = { 0, 0.16, -1.21 }, sz = { 0.44, 0.18, 0.38 }, c = C_BASALT, tint = "secondary" },
		{ p = { 0, 0.28, -0.76 }, sz = { 0.28, 0.14, 0.72 }, c = C_CRIMSON, tint = "primary" },
		-- Upward-swept Sovereign Gold Nasal Horn + central crown blade
		{ p = { 0, 0.26, -1.22 }, sz = { 0.16, 0.46, 0.18 }, c = C_GOLD, r = { 24, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.56, 0.34 }, sz = { 0.18, 0.56, 0.24 }, c = C_GOLD, r = { 34, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.36, 0.12 }, sz = { 0.32, 0.28, 0.64 }, c = C_CRIMSON, r = { 18, 0, 0 }, tint = "primary" },
		-- Deep crimson upper palate inside roaring mouth
		{ p = { 0, -0.18, -0.84 }, sz = { 0.44, 0.12, 0.76 }, c = C_CRIMSON_DARK, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		-- Cheek armor & temporal crimson crests
		table.insert(headVoxels, { p = { side * 0.44, 0.16, -0.06 }, sz = { 0.20, 0.38, 0.84 }, c = C_CRIMSON, r = { 8, side * 8, 0 }, tint = "primary" })
		table.insert(headVoxels, { p = { side * 0.46, -0.14, 0.06 }, sz = { 0.20, 0.34, 0.58 }, c = C_BASALT, tint = "secondary" })
		-- Glowing Fel-Green Predator Eye + dark slit pupil + heavy Gold Supraorbital Brow
		table.insert(headVoxels, { p = { side * 0.38, 0.10, -0.52 }, sz = { 0.14, 0.18, 0.28 }, c = C_FEL_EYE, m = Enum.Material.Neon, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.44, 0.10, -0.52 }, sz = { 0.05, 0.12, 0.10 }, c = C_OBSIDIAN, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.42, 0.26, -0.44 }, sz = { 0.18, 0.16, 0.54 }, c = C_GOLD, r = { 12, side * 10, side * -12 }, tint = "secondary" })
		-- Continuous Swept-Back Sovereign Gold Crown Horns (reach Y ~ 6.35)
		table.insert(headVoxels, { p = { side * 0.41, 0.52, 0.27 }, sz = { 0.22, 0.58, 0.22 }, c = C_AMBER, r = { 28, 0, side * -18 }, tint = "secondary" })
		table.insert(headVoxels, { p = { side * 0.58, 0.92, 0.54 }, sz = { 0.18, 0.62, 0.18 }, c = C_GOLD, r = { 42, 0, side * -24 }, tint = "secondary" })
		table.insert(headVoxels, { p = { side * 0.78, 1.24, 0.88 }, sz = { 0.13, 0.54, 0.13 }, c = C_GOLD, r = { 52, 0, side * -28 }, tint = "secondary" })
		-- Lateral & cheek frill horns
		table.insert(headVoxels, { p = { side * 0.52, 0.14, 0.44 }, sz = { 0.16, 0.18, 0.58 }, c = C_GOLD, r = { -20, side * 24, 0 }, tint = "secondary" })
		table.insert(headVoxels, { p = { side * 0.52, -0.18, 0.32 }, sz = { 0.16, 0.22, 0.38 }, c = C_GOLD, r = { 14, side * 22, 0 }, tint = "secondary" })
		-- Upper interlocking Ivory Fangs along maxilla edge
		for _, zTooth in ipairs({ -0.68, -0.94, -1.16, -1.34 }) do
			local fHeight = if zTooth == -1.34 then 0.20 else 0.15
			table.insert(headVoxels, { p = { side * 0.24, -0.24, zTooth }, sz = { 0.08, fHeight, 0.09 }, c = C_IVORY, tint = "keep" })
		end
	end

	-- 4. ARTICULATED ROARING LOWER JAW (Hub Y = 4.70, Z = -1.08, pivot 4.78, -0.92)
	local jawVoxels: { VoxelSpec } = {
		-- Rear hinge core nested cleanly inside Head cranium
		{ p = { 0, 0.04, 0.08 }, sz = { 0.66, 0.28, 0.44 }, c = C_BASALT, r = { -8, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.02, -0.24 }, sz = { 0.54, 0.22, 0.74 }, c = C_BASALT, r = { -12, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.12, -0.34 }, sz = { 0.44, 0.18, 0.62 }, c = C_CRIMSON, r = { -12, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.18, -0.44 }, sz = { 0.36, 0.16, 0.56 }, c = C_GOLD, r = { -14, 0, 0 }, tint = "secondary" },
		{ p = { 0, -0.24, -0.78 }, sz = { 0.16, 0.22, 0.22 }, c = C_GOLD, r = { 22, 0, 0 }, tint = "secondary" },
		-- Crimson roaring tongue inside open maw
		{ p = { 0, 0.06, -0.30 }, sz = { 0.28, 0.10, 0.54 }, c = C_CRIMSON_DARK, r = { -12, 0, 0 }, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		for _, zFang in ipairs({ -0.36, -0.58, -0.76 }) do
			local fH = if zFang == -0.76 then 0.18 else 0.14
			table.insert(jawVoxels, { p = { side * 0.20, 0.06, zFang }, sz = { 0.08, fH, 0.08 }, c = C_IVORY, r = { -12, 0, 0 }, tint = "keep" })
		end
	end

	-- 5. MUSCULAR CLAWED BOSS ARMS & SPIKED PAULDRONS (LegFL / LegFR)
	local function makeBossArm(side: number): { VoxelSpec }
		return {
			-- Spiked Shoulder Pauldron overlapping Torso upper shoulder
			{ p = { side * -0.06, 0.48, 0.12 }, sz = { 0.64, 0.64, 0.66 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { side * 0.08, 0.54, 0.10 }, sz = { 0.52, 0.48, 0.58 }, c = C_CRIMSON, r = { 0, 0, side * -16 }, tint = "primary" },
			{ p = { side * 0.24, 0.78, 0.14 }, sz = { 0.22, 0.44, 0.24 }, c = C_GOLD, r = { -14, 0, side * -32 }, tint = "secondary" },
			{ p = { side * 0.34, 0.52, 0.22 }, sz = { 0.28, 0.22, 0.22 }, c = C_GOLD, r = { 0, side * -12, side * -18 }, tint = "secondary" },
			-- Muscular upper arm
			{ p = { side * 0.08, 0.08, 0.08 }, sz = { 0.48, 0.62, 0.48 }, c = C_OBSIDIAN, r = { -16, 0, side * -10 }, tint = "primary" },
			{ p = { side * 0.16, 0.08, -0.06 }, sz = { 0.34, 0.48, 0.30 }, c = C_CRIMSON, r = { -16, 0, side * -12 }, tint = "primary" },
			-- Forward-angled forearm & elbow gold spike
			{ p = { side * 0.16, -0.34, -0.20 }, sz = { 0.46, 0.46, 0.72 }, c = C_CRIMSON, r = { -22, side * 10, side * -8 }, tint = "primary" },
			{ p = { side * 0.28, -0.34, -0.22 }, sz = { 0.20, 0.40, 0.58 }, c = C_BASALT, r = { -22, side * 10, side * -8 }, tint = "secondary" },
			{ p = { side * 0.28, -0.20, 0.24 }, sz = { 0.18, 0.22, 0.38 }, c = C_GOLD, r = { -28, side * 16, 0 }, tint = "secondary" },
			-- Massive Clawed Hand + 4 Ivory Razor Claws
			{ p = { side * 0.18, -0.58, -0.58 }, sz = { 0.44, 0.42, 0.44 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { side * 0.18, -0.44, -0.72 }, sz = { 0.42, 0.20, 0.26 }, c = C_CRIMSON, tint = "primary" },
			{ p = { side * -0.02, -0.66, -0.78 }, sz = { 0.14, 0.24, 0.22 }, c = C_IVORY, r = { 24, 0, side * 24 }, tint = "secondary" },
			{ p = { side * 0.08, -0.78, -0.82 }, sz = { 0.11, 0.28, 0.14 }, c = C_IVORY, r = { 18, 0, 0 }, tint = "secondary" },
			{ p = { side * 0.20, -0.80, -0.86 }, sz = { 0.11, 0.30, 0.14 }, c = C_IVORY, r = { 16, 0, 0 }, tint = "secondary" },
			{ p = { side * 0.32, -0.76, -0.78 }, sz = { 0.11, 0.26, 0.14 }, c = C_IVORY, r = { 18, 0, side * -10 }, tint = "secondary" },
		}
	end

	-- 6. HEAVY DIGITIGRADE HIND LEGS (LegBL / LegBR, hub Y = 0.96 -> sole/claws exact at Y = 0.00)
	local function makeBossLeg(side: number): { VoxelSpec }
		local voxels: { VoxelSpec } = {
			-- Foot sole & rear ground contact (Z = -0.41..+0.27, bottom relY = -0.96 -> world 0.00)
			{ p = { 0, -0.82, -0.07 }, sz = { 0.68, 0.28, 0.68 }, c = C_BASALT, tint = "primary" },
			{ p = { 0, -0.64, -0.18 }, sz = { 0.56, 0.22, 0.66 }, c = C_CRIMSON, tint = "primary" },
			{ p = { 0, -0.76, 0.30 }, sz = { 0.22, 0.24, 0.30 }, c = C_GOLD, r = { 18, 0, 0 }, tint = "secondary" },
			-- Ankle & reverse-jointed lower shin
			{ p = { 0, -0.50, 0.12 }, sz = { 0.44, 0.44, 0.42 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { 0, -0.18, 0.22 }, sz = { 0.48, 0.62, 0.48 }, c = C_BASALT, r = { -18, 0, 0 }, tint = "secondary" },
			{ p = { 0, -0.18, 0.02 }, sz = { 0.42, 0.52, 0.22 }, c = C_CRIMSON, r = { -16, 0, 0 }, tint = "primary" },
			{ p = { side * 0.26, -0.16, 0.38 }, sz = { 0.14, 0.32, 0.26 }, c = C_GOLD, r = { -28, 0, 0 }, tint = "secondary" },
			-- Knee, golden knee spike & thick striated thigh overlapping Torso pelvis
			{ p = { 0, 0.18, -0.02 }, sz = { 0.58, 0.52, 0.58 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { 0, 0.24, -0.34 }, sz = { 0.32, 0.34, 0.22 }, c = C_GOLD, r = { 24, 0, 0 }, tint = "secondary" },
			{ p = { 0, 0.58, 0.06 }, sz = { 0.68, 0.78, 0.72 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { side * 0.08, 0.60, -0.10 }, sz = { 0.62, 0.62, 0.44 }, c = C_CRIMSON, r = { 26, 0, side * -12 }, tint = "primary" },
			{ p = { side * 0.38, 0.66, 0.04 }, sz = { 0.20, 0.44, 0.42 }, c = C_GOLD, r = { -18, 0, side * 24 }, tint = "secondary" },
		}
		-- 3 Splayed Crimson Toes & Ivory Claws (minimal Z overlap < 0.03 with sole to avoid coplanar minY Z-fight)
		for _, tx in ipairs({ -0.22, 0, 0.22 }) do
			table.insert(voxels, { p = { tx, -0.84, -0.55 }, sz = { 0.18, 0.24, 0.30 }, c = C_CRIMSON, tint = "primary" })
			table.insert(voxels, { p = { tx, -0.86, -0.80 }, sz = { 0.12, 0.20, 0.22 }, c = C_IVORY, tint = "secondary" })
		end
		return voxels
	end

	-- 7. COLOSSAL BATTLE-TATTERED CRIMSON/OBSIDIAN WINGS + LOWER SPIKED WING-TENDRILS
	local function makeCataclysmWings(side: number): ({ VoxelSpec }, { VoxelSpec })
		local inner: { VoxelSpec } = {
			-- Root shoulder-wing bridge
			{ p = { side * 0.02, 0.02, 0.02 }, sz = { 0.56, 0.66, 0.54 }, c = C_OBSIDIAN, tint = "primary" },
			-- Ascending crimson primary wing-arm + basalt spar + wrist bolster
			{ p = { side * 0.78, 1.06, 0.10 }, sz = { 0.42, 2.38, 0.44 }, c = C_CRIMSON, r = { 8, 0, side * -34 }, tint = "primary" },
			{ p = { side * 0.72, 0.96, 0.22 }, sz = { 0.28, 2.24, 0.28 }, c = C_BASALT, r = { 8, 0, side * -34 }, tint = "secondary" },
			-- Inner crimson muscle sail + tattered obsidian trailing panels
			{ p = { side * 0.62, 0.72, 0.26 }, sz = { 0.92, 1.56, 0.16 }, c = C_CRIMSON_DARK, r = { 10, side * 14, side * -28 }, tint = "primary" },
			{ p = { side * 1.18, 1.38, 0.24 }, sz = { 0.96, 1.24, 0.14 }, c = C_OBSIDIAN, r = { 10, side * 12, side * -30 }, tint = "primary" },
			{ p = { side * 1.12, 0.72, 0.28 }, sz = { 0.88, 1.06, 0.12 }, c = C_CRIMSON_DARK, r = { 10, side * 12, side * -22 }, tint = "primary" },
			{ p = { side * 0.54, 0.06, 0.34 }, sz = { 0.88, 1.12, 0.14 }, c = C_OBSIDIAN, r = { 12, side * 12, side * -12 }, tint = "primary" },
			{ p = { side * 0.84, -0.34, 0.36 }, sz = { 0.62, 0.88, 0.12 }, c = C_OBSIDIAN, r = { 10, side * 10, side * -8 }, tint = "primary" },
			{ p = { side * 0.66, -0.62, 0.36 }, sz = { 0.54, 0.36, 0.14 }, c = C_CRIMSON, r = { 10, side * 10, side * -12 }, tint = "primary" },
			-- Wing-wrist hub & Sovereign Gold Thumb-Claw
			{ p = { side * 1.48, 2.08, 0.16 }, sz = { 0.44, 0.48, 0.44 }, c = C_CRIMSON, tint = "primary" },
			{ p = { side * 1.44, 2.52, 0.08 }, sz = { 0.18, 0.64, 0.20 }, c = C_GOLD, r = { -16, 0, side * 14 }, tint = "secondary" },
			{ p = { side * 1.24, 2.34, 0.10 }, sz = { 0.14, 0.40, 0.16 }, c = C_AMBER, r = { -12, 0, side * 26 }, tint = "secondary" },
			-- Signature Spiked Lower Wing-Tendril (6-limbed Elder Dragon silhouette)
			{ p = { side * 0.86, -0.44, 0.10 }, sz = { 1.44, 0.28, 0.28 }, c = C_OBSIDIAN, r = { 0, side * 14, side * -32 }, tint = "primary" },
			{ p = { side * 0.84, -0.36, 0.02 }, sz = { 1.32, 0.16, 0.20 }, c = C_CRIMSON, r = { 0, side * 14, side * -32 }, tint = "primary" },
			{ p = { side * 1.76, -1.04, 0.04 }, sz = { 1.06, 0.22, 0.22 }, c = C_BASALT, r = { 0, side * 18, side * -38 }, tint = "secondary" },
			{ p = { side * 2.26, -1.40, -0.02 }, sz = { 0.46, 0.14, 0.16 }, c = C_GOLD, r = { 0, side * 16, side * -40 }, tint = "secondary" },
			{ p = { side * 2.16, -1.56, 0.02 }, sz = { 0.16, 0.44, 0.16 }, c = C_GOLD, r = { 0, 0, side * 24 }, tint = "secondary" },
			{ p = { side * 2.28, -1.24, 0.06 }, sz = { 0.36, 0.14, 0.14 }, c = C_IVORY, r = { 0, side * 16, side * -12 }, tint = "secondary" },
		}

		local outer: { VoxelSpec } = {
			-- Wrist bridge into Wing
			{ p = { side * 0.02, -0.02, -0.02 }, sz = { 0.38, 0.38, 0.38 }, c = C_CRIMSON, tint = "primary" },
			-- High Crimson Leading-Edge Wing Beam & Peak Gold Spur (world Y ~ 7.12)
			{ p = { side * 0.96, 0.62, 0.02 }, sz = { 2.06, 0.36, 0.30 }, c = C_CRIMSON, r = { 6, side * 14, side * 32 }, tint = "primary" },
			{ p = { side * 1.04, 0.72, 0.06 }, sz = { 1.78, 0.20, 0.20 }, c = C_BASALT, r = { 6, side * 14, side * 32 }, tint = "secondary" },
			{ p = { side * 1.98, 1.24, 0.08 }, sz = { 0.62, 0.20, 0.18 }, c = C_GOLD, r = { 6, side * 14, side * 34 }, tint = "secondary" },
			-- Upper crimson membrane zone (Wing Detail reference)
			{ p = { side * 0.88, 0.38, 0.10 }, sz = { 1.62, 0.44, 0.14 }, c = C_CRIMSON, r = { 6, side * 12, side * 20 }, tint = "primary" },
			{ p = { side * 1.48, 0.64, 0.12 }, sz = { 0.88, 0.38, 0.12 }, c = C_CRIMSON_DARK, r = { 6, side * 12, side * 22 }, tint = "primary" },
			-- Splayed Finger Spar 1 (Horizontal Reach -> ~4.8 st side wingspan)
			{ p = { side * 1.12, 0.14, 0.08 }, sz = { 2.24, 0.22, 0.20 }, c = C_BASALT, r = { 4, side * 12, side * 6 }, tint = "secondary" },
			{ p = { side * 2.34, 0.26, 0.18 }, sz = { 0.52, 0.16, 0.16 }, c = C_GOLD, r = { 4, side * 12, side * 8 }, tint = "secondary" },
			{ p = { side * 0.92, -0.04, 0.14 }, sz = { 1.54, 0.42, 0.12 }, c = C_OBSIDIAN, r = { 6, side * 12, side * -4 }, tint = "primary" },
			{ p = { side * 1.72, -0.02, 0.16 }, sz = { 0.78, 0.34, 0.10 }, c = C_OBSIDIAN, r = { 6, side * 12, side * -2 }, tint = "primary" },
			-- Splayed Finger Spar 2 (Mid Fan)
			{ p = { side * 1.00, -0.44, 0.14 }, sz = { 2.10, 0.20, 0.18 }, c = C_BASALT, r = { 6, side * 12, side * -24 }, tint = "secondary" },
			{ p = { side * 2.02, -0.92, 0.24 }, sz = { 0.44, 0.14, 0.14 }, c = C_GOLD, r = { 6, side * 12, side * -26 }, tint = "secondary" },
			{ p = { side * 0.84, -0.58, 0.18 }, sz = { 1.46, 0.46, 0.12 }, c = C_OBSIDIAN, r = { 8, side * 10, side * -32 }, tint = "primary" },
			-- Splayed Finger Spar 3 (Lower-Mid)
			{ p = { side * 0.78, -0.96, 0.18 }, sz = { 1.78, 0.18, 0.16 }, c = C_OBSIDIAN, r = { 8, side * 10, side * -46 }, tint = "primary" },
			{ p = { side * 0.62, -1.04, 0.22 }, sz = { 1.18, 0.42, 0.12 }, c = C_OBSIDIAN, r = { 8, side * 10, side * -52 }, tint = "primary" },
			{ p = { side * 1.24, -1.48, 0.26 }, sz = { 0.56, 0.28, 0.10 }, c = C_CRIMSON_DARK, r = { 8, side * 10, side * -48 }, tint = "primary" },
			-- Splayed Finger Spar 4 (Inner Trailing Tatter)
			{ p = { side * 0.48, -1.32, 0.20 }, sz = { 1.46, 0.16, 0.16 }, c = C_OBSIDIAN, r = { 8, side * 8, side * -66 }, tint = "primary" },
			{ p = { side * 0.34, -1.48, 0.22 }, sz = { 0.64, 0.38, 0.12 }, c = C_CRIMSON, r = { 8, side * 8, side * -68 }, tint = "primary" },
		}

		return inner, outer
	end

	-- 8. SEGMENTED STRIPED TAIL + GOLD SPINES & SCYTHE TIP (stays strictly above Y >= 0.28)
	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.06, -0.04 }, sz = { 0.86, 0.74, 0.78 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, -0.32, 0.56 }, sz = { 0.72, 0.62, 0.90 }, c = C_OBSIDIAN, r = { -26, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.22, 0.48 }, sz = { 0.76, 0.46, 0.42 }, c = C_CRIMSON, r = { -26, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.58, 0.46 }, sz = { 0.44, 0.16, 0.78 }, c = C_IVORY, r = { -26, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.12, 0.38 }, sz = { 0.22, 0.32, 0.30 }, c = C_GOLD, r = { 16, 0, 0 }, tint = "secondary" },
		{ p = { 0, -0.08, 0.78 }, sz = { 0.20, 0.30, 0.28 }, c = C_GOLD, r = { 12, 0, 0 }, tint = "secondary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, -0.10, 0.36 }, sz = { 0.56, 0.50, 1.24 }, c = C_OBSIDIAN, r = { -10, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.06, 0.12 }, sz = { 0.60, 0.42, 0.34 }, c = C_CRIMSON, r = { -10, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.14, 0.66 }, sz = { 0.58, 0.38, 0.34 }, c = C_CRIMSON, r = { -10, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.32, 0.38 }, sz = { 0.34, 0.14, 1.08 }, c = C_IVORY, r = { -10, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.20, 0.14 }, sz = { 0.18, 0.28, 0.26 }, c = C_GOLD, r = { 14, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.12, 0.68 }, sz = { 0.16, 0.26, 0.26 }, c = C_GOLD, r = { 14, 0, 0 }, tint = "secondary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.02, 0.42 }, sz = { 0.40, 0.38, 1.04 }, c = C_OBSIDIAN, r = { 8, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.08, 0.62 }, sz = { 0.44, 0.32, 0.32 }, c = C_CRIMSON, r = { 10, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.14, 0.42 }, sz = { 0.24, 0.14, 0.88 }, c = C_IVORY, r = { 8, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.24, 0.24 }, sz = { 0.16, 0.24, 0.24 }, c = C_GOLD, r = { 20, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.24, 1.12 }, sz = { 0.20, 0.30, 0.70 }, c = C_GOLD, r = { 24, 0, 0 }, tint = "secondary" },
		{ p = { -0.26, 0.16, 0.92 }, sz = { 0.22, 0.18, 0.50 }, c = C_GOLD, r = { 18, -28, 0 }, tint = "secondary" },
		{ p = { 0.26, 0.16, 0.92 }, sz = { 0.22, 0.18, 0.50 }, c = C_GOLD, r = { 18, 28, 0 }, tint = "secondary" },
	}

	-- Assemble All 14 Skeletal Bone Clusters
	local torso = session:AddBone("Torso", Vector3.new(0, 2.56, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 3.88, -0.46), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 4.96, -0.96), headVoxels)
	local jaw = session:AddBone("Jaw", Vector3.new(0, 4.70, -1.08), jawVoxels)

	local wLIn, wLOut = makeCataclysmWings(-1)
	local wRIn, wROut = makeCataclysmWings(1)
	local wingL = session:AddBone("WingL", Vector3.new(-0.78, 3.48, 0.24), wLIn)
	local wingTipL = session:AddBone("WingTipL", Vector3.new(-2.32, 5.62, 0.42), wLOut)
	local wingR = session:AddBone("WingR", Vector3.new(0.78, 3.48, 0.24), wRIn)
	local wingTipR = session:AddBone("WingTipR", Vector3.new(2.32, 5.62, 0.42), wROut)

	local legFL = session:AddBone("LegFL", Vector3.new(-1.06, 2.78, -0.34), makeBossArm(-1))
	local legFR = session:AddBone("LegFR", Vector3.new(1.06, 2.78, -0.34), makeBossArm(1))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.78, 0.96, 0.10), makeBossLeg(-1))
	local legBR = session:AddBone("LegBR", Vector3.new(0.78, 0.96, 0.10), makeBossLeg(1))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.48, 0.72), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.82, 1.88), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 0.58, 3.04), tail3Voxels)

	if not isStatic then
		-- Attach 15 Articulated Motor6D Joints (including JawJoint)
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 2.20, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 3.58, -0.32))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 4.78, -0.76))
		session:AttachMotor("JawJoint", head, jaw, Vector3.new(0, 4.78, -0.92))

		session:AttachMotor("WingLJoint", torso, wingL, Vector3.new(-0.68, 3.42, 0.22))
		session:AttachMotor("WingTipLJoint", wingL, wingTipL, Vector3.new(-2.26, 5.54, 0.40))
		session:AttachMotor("WingRJoint", torso, wingR, Vector3.new(0.68, 3.42, 0.22))
		session:AttachMotor("WingTipRJoint", wingR, wingTipR, Vector3.new(2.26, 5.54, 0.40))

		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.88, 3.24, -0.22))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.88, 3.24, -0.22))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.74, 1.78, 0.12))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.74, 1.78, 0.12))

		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.62, 0.56))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.92, 1.76))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 0.62, 2.94))

		local headCore = model:FindFirstChild("Head_V1") or head
		local ratio = s / 1.50
		local headFlashSpecs = {
			{
				color = Color3.fromRGB(255, 0, 4),
				lightEmission = 1,
				lightInfluence = 0,
				lifetime = 0.2,
				rate = 10,
				zOffset = 8.6244,
				sizes = { { 0, 10.4396 }, { 0.5026, 16.1921 }, { 0.9958, 20.6662 }, { 1, 21.3054 } },
			},
			{
				color = Color3.fromRGB(0, 0, 0),
				lightEmission = 0,
				lightInfluence = 1,
				lifetime = 0.4,
				rate = 2,
				zOffset = 3.30,
				sizes = { { 0, 3.9946 }, { 0.5042, 13.6141 }, { 0.9900, 15.0 }, { 1, 15.0 } },
			},
		}
		for _, spec in ipairs(headFlashSpecs) do
			local keypoints = table.create(#spec.sizes)
			for i, kp in ipairs(spec.sizes) do
				keypoints[i] = NumberSequenceKeypoint.new(kp[1], kp[2] * ratio)
			end
			local em = Instance.new("ParticleEmitter")
			em.Name = "Flash"
			em.Texture = "rbxassetid://11372606236"
			em.Color = ColorSequence.new(spec.color)
			em.Brightness = 5
			em.LightEmission = spec.lightEmission
			em.LightInfluence = spec.lightInfluence
			em.Lifetime = NumberRange.new(spec.lifetime, spec.lifetime)
			em.Rate = spec.rate
			em.Speed = NumberRange.new(0, 0)
			em.Rotation = NumberRange.new(-360, 360)
			em.RotSpeed = NumberRange.new(0, 0)
			em.SpreadAngle = Vector2.new(-360, 360)
			em.Shape = Enum.ParticleEmitterShape.Box
			em.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			em.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			em.ShapePartial = 1
			em.Orientation = Enum.ParticleOrientation.FacingCamera
			em.EmissionDirection = Enum.NormalId.Top
			em.LockedToPart = false
			em.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			em.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			em.FlipbookFramerate = NumberRange.new(20, 20)
			em.FlipbookBlendFrames = true
			em.ZOffset = spec.zOffset * ratio
			em.Size = NumberSequence.new(keypoints)
			em.Transparency = NumberSequence.new(0)
			em.Enabled = true
			em:SetAttribute("EmitDelay", 0)
			em:SetAttribute("EmitCount", 1)
			em.Parent = headCore
		end
	end

	return session
end

return VharazhulCataclysm
