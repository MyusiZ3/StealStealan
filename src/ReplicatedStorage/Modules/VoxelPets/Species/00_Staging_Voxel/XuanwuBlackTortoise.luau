--!strict
-- XuanwuBlackTortoise.luau (Voxel)
-- Candidate #5: Mythical Black Tortoise-Dragon (Xuanwu) with Massive Obsidian Carapace,
-- Pale Ice-Blue Spectral Shell Mist, Heavy Pillar Legs, Tall Dragon Neck & Azure Flame Maw.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_OBSIDIAN = Color3.fromRGB(20, 24, 34)
local C_SHELL_HI = Color3.fromRGB(46, 52, 68)
local C_SLATE = Color3.fromRGB(142, 152, 184)
local C_MIST = Color3.fromRGB(204, 232, 255)
local C_AZURE = Color3.fromRGB(68, 158, 255)

local XuanwuBlackTortoise = {
	Id = "XuanwuBlackTortoise",
	DisplayName = "Xuanwu Black Tortoise",
	Archetype = "QuadrupedBeast" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	StagingSlot = 5,
	BaseConceptId = "XuanwuBlackTortoise",
	DefaultScale = 1.30,
	AccentColor = C_AZURE,
}

function XuanwuBlackTortoise.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(2.10, 1.30, 2.36), C_OBSIDIAN)

	local torsoVoxels: { VoxelSpec } = {
		-- Wide domed obsidian tortoise shell tiers + pale plastron
		{ p = { 0, 0.02, 0.04 }, sz = { 1.96, 0.56, 2.18 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.44, 0.08 }, sz = { 1.62, 0.46, 1.84 }, c = C_SHELL_HI, tint = "primary" },
		{ p = { 0, 0.78, 0.12 }, sz = { 1.14, 0.34, 1.36 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, -0.32, 0.00 }, sz = { 1.56, 0.24, 1.82 }, c = C_SLATE, tint = "secondary" },
		-- Pale ice-blue spectral mist flames curling up around shell rim
		{ p = { -0.96, 0.24, -0.58 }, sz = { 0.22, 0.62, 0.56 }, c = C_MIST, r = { 14, 0, 18 }, tint = "secondary" },
		{ p = { 0.96, 0.24, -0.58 }, sz = { 0.22, 0.62, 0.56 }, c = C_MIST, r = { 14, 0, -18 }, tint = "secondary" },
		{ p = { -0.94, 0.20, 0.38 }, sz = { 0.18, 0.52, 0.52 }, c = C_AZURE, m = Enum.Material.Neon, r = { -12, 0, 20 }, tint = "keep" },
		{ p = { 0.94, 0.20, 0.38 }, sz = { 0.18, 0.52, 0.52 }, c = C_AZURE, m = Enum.Material.Neon, r = { -12, 0, -20 }, tint = "keep" },
		{ p = { 0, 0.14, -1.12 }, sz = { 1.04, 0.48, 0.24 }, c = C_MIST, tint = "secondary" },
	}

	local neckVoxels: { VoxelSpec } = {
		-- Tall S-curved serpent-dragon neck rising high above shell
		{ p = { 0, 0.24, -0.06 }, sz = { 0.68, 0.78, 0.68 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.84, 0.08 }, sz = { 0.60, 0.78, 0.62 }, c = C_OBSIDIAN, r = { -18, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.48, -0.36 }, sz = { 0.48, 1.18, 0.22 }, c = C_SLATE, r = { -10, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.68, 0.42 }, sz = { 0.16, 1.08, 0.34 }, c = C_SHELL_HI, r = { -14, 0, 0 }, tint = "primary" },
		{ p = { -0.38, 0.86, 0.12 }, sz = { 0.12, 0.22, 0.68 }, c = C_MIST, r = { 24, -22, 0 }, tint = "secondary" },
		{ p = { 0.38, 0.86, 0.12 }, sz = { 0.12, 0.22, 0.68 }, c = C_MIST, r = { 24, 22, 0 }, tint = "secondary" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.02, -0.14 }, sz = { 0.72, 0.56, 0.84 }, c = C_OBSIDIAN, r = { 22, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.18, -0.62 }, sz = { 0.48, 0.34, 0.52 }, c = C_OBSIDIAN, r = { 28, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.34, -0.50 }, sz = { 0.38, 0.22, 0.48 }, c = C_AZURE, m = Enum.Material.Neon, r = { 28, 0, 0 }, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.36, 0.04, -0.34 }, sz = { 0.08, 0.12, 0.26 }, c = C_AZURE, m = Enum.Material.Neon, r = { 22, 0, 0 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.24, 0.42, 0.04 }, sz = { 0.14, 0.62, 0.22 }, c = C_OBSIDIAN, r = { -24, 0, side * -12 }, tint = "primary" })
	end

	local function makePillarLeg(): { VoxelSpec }
		-- Hub Y = 0.46 -> sole pad 0.46 - 0.34 - 0.12 = 0.00
		return {
			{ p = { 0, 0.14, 0 }, sz = { 0.58, 0.52, 0.58 }, c = C_SLATE, tint = "secondary" },
			{ p = { 0, -0.14, -0.04 }, sz = { 0.52, 0.38, 0.54 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { 0, -0.34, -0.08 }, sz = { 0.58, 0.24, 0.62 }, c = C_OBSIDIAN, tint = "primary" },
			{ p = { -0.16, -0.36, -0.44 }, sz = { 0.12, 0.16, 0.20 }, c = C_SHELL_HI, tint = "keep" },
			{ p = { 0.00, -0.36, -0.46 }, sz = { 0.12, 0.16, 0.20 }, c = C_SHELL_HI, tint = "keep" },
			{ p = { 0.16, -0.36, -0.44 }, sz = { 0.12, 0.16, 0.20 }, c = C_SHELL_HI, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0.34 }, sz = { 0.36, 0.34, 0.78 }, c = C_OBSIDIAN, r = { 16, 0, 0 }, tint = "primary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.22, 0.32 }, sz = { 0.26, 0.26, 0.76 }, c = C_SHELL_HI, r = { 34, 0, 0 }, tint = "primary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.36, 0.24 }, sz = { 0.18, 0.20, 0.68 }, c = C_MIST, r = { 46, 0, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 0.88, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.24, -1.04), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.48, -1.02), headVoxels)

	local legFL = session:AddBone("LegFL", Vector3.new(-0.88, 0.46, -0.76), makePillarLeg())
	local legFR = session:AddBone("LegFR", Vector3.new(0.88, 0.46, -0.76), makePillarLeg())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.88, 0.46, 0.76), makePillarLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.88, 0.46, 0.76), makePillarLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.84, 1.08), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.96, 1.74), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.28, 2.28), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 0.88, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.12, -0.96))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.38, -0.98))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.88, 0.74, -0.76))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.88, 0.74, -0.76))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.88, 0.74, 0.76))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.88, 0.74, 0.76))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.84, 1.04))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.94, 1.70))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.26, 2.24))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.56, 0.44), Vector3.new(0, 0.24, 0.44), C_MIST, C_AZURE, 0.55, "XuanwuMistTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.36, 0), "XuanwuShellMistVFX", { C_MIST, C_AZURE, C_SLATE }, 10, 0.34)
	end

	return session
end

return XuanwuBlackTortoise
