--!strict
-- AbyssTideLeviathan.luau (Voxel)
-- Candidate #1: Midnight-Navy Armored Abyssal Leviathan Serpent with Bioluminescent Aqua Maw,
-- Twin Swept Head Horns, Jagged Dorsal Fins, Pale Belly Plates & Cyan Clawed Forelimbs.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_NAVY = Color3.fromRGB(16, 30, 66)
local C_DEEP = Color3.fromRGB(10, 18, 42)
local C_COBALT = Color3.fromRGB(28, 72, 138)
local C_BELLY = Color3.fromRGB(196, 218, 236)
local C_SLATE = Color3.fromRGB(58, 70, 88)
local C_TEAL = Color3.fromRGB(24, 158, 172)
local C_AQUA = Color3.fromRGB(44, 244, 228)

local AbyssTideLeviathan = {
	Id = "AbyssTideLeviathan",
	DisplayName = "Abyss Tide Leviathan",
	Archetype = "EasternSerpent" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	StagingSlot = 1,
	BaseConceptId = "AbyssTideLeviathan",
	DefaultScale = 1.30,
	AccentColor = C_AQUA,
}

function AbyssTideLeviathan.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.24, 1.10, 2.50), C_NAVY)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0 }, sz = { 1.06, 0.86, 2.30 }, c = C_NAVY, tint = "primary" },
		{ p = { 0, 0.24, -0.10 }, sz = { 1.12, 0.44, 1.84 }, c = C_COBALT, tint = "primary" },
		{ p = { 0, -0.34, 0 }, sz = { 0.86, 0.26, 2.18 }, c = C_BELLY, tint = "secondary" },
		-- Bioluminescent lateral energy veins
		{ p = { -0.56, 0.10, -0.20 }, sz = { 0.06, 0.10, 1.72 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0.56, 0.10, -0.20 }, sz = { 0.06, 0.10, 1.72 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" },
		-- Slate shoulder pauldrons
		{ p = { -0.58, 0.18, -0.76 }, sz = { 0.24, 0.42, 0.62 }, c = C_SLATE, tint = "secondary" },
		{ p = { 0.58, 0.18, -0.76 }, sz = { 0.24, 0.42, 0.62 }, c = C_SLATE, tint = "secondary" },
	}
	-- Jagged dorsal shark-leviathan fins
	for i = 0, 3 do
		table.insert(torsoVoxels, {
			p = { 0, 0.68 - i * 0.04, -0.72 + i * 0.50 },
			sz = { 0.16, 0.58 - i * 0.06, 0.38 },
			c = if i % 2 == 0 then C_TEAL else C_COBALT,
			r = { -28, 0, 0 },
			tint = "secondary",
		})
		table.insert(torsoVoxels, {
			p = { 0, 0.54, -0.78 + i * 0.50 },
			sz = { 0.22, 0.24, 0.18 },
			c = C_SLATE,
			tint = "keep",
		})
	end

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.12, 0 }, sz = { 0.84, 0.80, 0.82 }, c = C_NAVY, tint = "primary" },
		{ p = { 0, 0.50, -0.14 }, sz = { 0.54, 0.36, 0.52 }, c = C_COBALT, tint = "primary" },
		{ p = { 0, -0.18, -0.26 }, sz = { 0.66, 0.52, 0.32 }, c = C_BELLY, tint = "secondary" },
		{ p = { 0, 0.58, 0.18 }, sz = { 0.16, 0.52, 0.34 }, c = C_TEAL, r = { -30, 0, 0 }, tint = "secondary" },
	}

	local headVoxels: { VoxelSpec } = {
		-- Armored upper skull & shark snout
		{ p = { 0, 0.14, 0.02 }, sz = { 0.88, 0.52, 0.92 }, c = C_NAVY, tint = "primary" },
		{ p = { 0, 0.08, -0.64 }, sz = { 0.60, 0.36, 0.68 }, c = C_DEEP, tint = "primary" },
		{ p = { 0, 0.04, -1.06 }, sz = { 0.36, 0.22, 0.34 }, c = C_NAVY, tint = "primary" },
		-- Glowing cyan-aqua open abyssal maw interior
		{ p = { 0, -0.10, -0.56 }, sz = { 0.48, 0.20, 0.66 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" },
		-- Pale armored lower jaw + chin spike
		{ p = { 0, -0.26, -0.48 }, sz = { 0.54, 0.18, 0.76 }, c = C_BELLY, r = { 10, 0, 0 }, tint = "secondary" },
		{ p = { 0, -0.40, -0.78 }, sz = { 0.20, 0.22, 0.22 }, c = C_BELLY, r = { 24, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		-- Glowing slit eyes
		table.insert(headVoxels, { p = { side * 0.44, 0.14, -0.32 }, sz = { 0.08, 0.10, 0.24 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" })
		-- Jagged upper/lower teeth blocks
		table.insert(headVoxels, { p = { side * 0.22, -0.06, -0.74 }, sz = { 0.08, 0.14, 0.36 }, c = C_BELLY, tint = "keep" })
		-- Long swept-back abyssal crown horns
		table.insert(headVoxels, { p = { side * 0.28, 0.48, 0.18 }, sz = { 0.14, 0.16, 0.86 }, c = C_SLATE, r = { 28, side * -12, 0 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.34, 0.72, 0.58 }, sz = { 0.10, 0.12, 0.62 }, c = C_TEAL, r = { 34, side * -16, 0 }, tint = "secondary" })
		-- Bioluminescent cheek flame-tendrils
		table.insert(headVoxels, { p = { side * 0.48, 0.04, 0.06 }, sz = { 0.10, 0.14, 0.68 }, c = C_AQUA, m = Enum.Material.Neon, r = { 8, side * -22, 0 }, tint = "keep" })
	end

	local function makeFinEar(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.12, 0.04, 0.18 }, sz = { 0.12, 0.28, 0.54 }, c = C_TEAL, r = { 12, side * -26, 0 }, tint = "secondary" },
		}
	end

	local function makeForeClaw(side: number): { VoxelSpec }
		-- Hub at Y = 0.50 -> bottom of unrotated sole pad = 0.50 - 0.41 - 0.09 = 0.00
		return {
			{ p = { 0, 0.16, 0 }, sz = { 0.38, 0.52, 0.40 }, c = C_SLATE, tint = "secondary" },
			{ p = { 0, -0.18, -0.08 }, sz = { 0.34, 0.36, 0.38 }, c = C_NAVY, tint = "primary" },
			{ p = { 0, -0.41, -0.14 }, sz = { 0.38, 0.18, 0.44 }, c = C_DEEP, tint = "primary" },
			{ p = { -0.12, -0.38, -0.42 }, sz = { 0.09, 0.14, 0.28 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" },
			{ p = { 0.00, -0.38, -0.44 }, sz = { 0.09, 0.14, 0.30 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" },
			{ p = { 0.12, -0.38, -0.42 }, sz = { 0.09, 0.14, 0.28 }, c = C_AQUA, m = Enum.Material.Neon, tint = "keep" },
			{ p = { side * 0.18, 0.04, 0.18 }, sz = { 0.10, 0.28, 0.34 }, c = C_TEAL, r = { -18, 0, 0 }, tint = "secondary" },
		}
	end

	local function makePelvicFin(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.10, -0.06, 0.12 }, sz = { 0.16, 0.44, 0.56 }, c = C_NAVY, r = { -22, 0, side * -28 }, tint = "primary" },
			{ p = { side * 0.18, -0.18, 0.30 }, sz = { 0.10, 0.34, 0.44 }, c = C_TEAL, r = { -26, 0, side * -32 }, tint = "secondary" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.42 }, sz = { 0.80, 0.68, 1.02 }, c = C_NAVY, tint = "primary" },
		{ p = { 0, -0.28, 0.42 }, sz = { 0.62, 0.20, 0.94 }, c = C_BELLY, tint = "secondary" },
		{ p = { 0, 0.46, 0.44 }, sz = { 0.14, 0.42, 0.52 }, c = C_TEAL, r = { -26, 0, 0 }, tint = "secondary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.42 }, sz = { 0.56, 0.50, 0.98 }, c = C_COBALT, tint = "primary" },
		{ p = { 0, -0.20, 0.42 }, sz = { 0.42, 0.16, 0.90 }, c = C_BELLY, tint = "secondary" },
		{ p = { 0, 0.34, 0.44 }, sz = { 0.12, 0.36, 0.48 }, c = C_AQUA, m = Enum.Material.Neon, r = { -28, 0, 0 }, tint = "keep" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.38 }, sz = { 0.34, 0.30, 0.88 }, c = C_NAVY, tint = "primary" },
		-- Swept crescent caudal fin blades
		{ p = { 0, 0.24, 0.96 }, sz = { 0.12, 0.58, 0.72 }, c = C_AQUA, m = Enum.Material.Neon, r = { -32, 0, 0 }, tint = "keep" },
		{ p = { 0, -0.18, 0.92 }, sz = { 0.12, 0.42, 0.62 }, c = C_TEAL, r = { 28, 0, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.04, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.44, -1.18), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 1.88, -1.66), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.42, 1.96, -1.36), makeFinEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.42, 1.96, -1.36), makeFinEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.62, 0.50, -0.78), makeForeClaw(-1))
	local legFR = session:AddBone("LegFR", Vector3.new(0.62, 0.50, -0.78), makeForeClaw(1))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.52, 0.72, 0.76), makePelvicFin(-1))
	local legBR = session:AddBone("LegBR", Vector3.new(0.52, 0.72, 0.76), makePelvicFin(1))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.98, 1.12), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.96, 2.02), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 0.96, 2.88), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.04, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.26, -1.06))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 1.76, -1.48))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.38, 1.94, -1.38))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.38, 1.94, -1.38))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.62, 0.82, -0.78))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.62, 0.82, -0.78))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.48, 0.82, 0.76))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.48, 0.82, 0.76))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.98, 1.08))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.96, 1.98))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 0.96, 2.84))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.42, 1.12), Vector3.new(0, -0.24, 1.06), C_AQUA, C_COBALT, 0.60, "AbyssTideTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.24, 0), "AbyssCurrentVFX", { C_AQUA, C_TEAL, C_COBALT }, 10, 0.32)
	end

	return session
end

return AbyssTideLeviathan
