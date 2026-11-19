--!strict
-- EternalAshenKitsune.luau (Promoted Voxel; legacy alias: ImperialGoldQilin)
-- Candidate #7: Radiant Golden-Scaled Imperial Qilin with Flowing Silver-White Cloud Mane,
-- Tall Branched Amber Antlers, Crimson Whisker Tendrils & Clawed Dragon Paws.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_GOLD = Color3.fromRGB(244, 198, 48)
local C_AMBER = Color3.fromRGB(204, 146, 26)
local C_CLOUD = Color3.fromRGB(244, 248, 255)
local C_SILVER = Color3.fromRGB(192, 204, 222)
local C_CRIMSON = Color3.fromRGB(228, 48, 42)
local C_ANTLER = Color3.fromRGB(118, 76, 38)

local EternalAshenKitsune = {
	Id = "EternalAshenKitsune",
	DisplayName = "Imperial Gold Qilin",
	Archetype = "QuadrupedBeast" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	Aliases = { "ImperialGoldQilin" },
	DefaultScale = 1.35,
	AccentColor = C_GOLD,
}

function EternalAshenKitsune.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.34, 1.28, 2.22), C_GOLD)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.02, -0.42 }, sz = { 1.12, 0.96, 1.10 }, c = C_GOLD, tint = "primary" },
		{ p = { 0, 0.00, 0.48 }, sz = { 1.02, 0.88, 1.06 }, c = C_AMBER, tint = "primary" },
		{ p = { 0, -0.28, -0.34 }, sz = { 0.86, 0.36, 0.94 }, c = C_GOLD, m = Enum.Material.Metal, tint = "primary" },
		-- Swirling silver-white cloud shoulder & hip wisps + crimson flame accents
		{ p = { -0.58, 0.18, -0.56 }, sz = { 0.16, 0.46, 0.58 }, c = C_CLOUD, r = { 18, -12, 0 }, tint = "secondary" },
		{ p = { 0.58, 0.18, -0.56 }, sz = { 0.16, 0.46, 0.58 }, c = C_CLOUD, r = { 18, 12, 0 }, tint = "secondary" },
		{ p = { -0.54, 0.22, 0.44 }, sz = { 0.14, 0.42, 0.54 }, c = C_CLOUD, r = { 22, -10, 0 }, tint = "secondary" },
		{ p = { 0.54, 0.22, 0.44 }, sz = { 0.14, 0.42, 0.54 }, c = C_CLOUD, r = { 22, 10, 0 }, tint = "secondary" },
		{ p = { -0.60, 0.14, -0.44 }, sz = { 0.08, 0.24, 0.34 }, c = C_CRIMSON, r = { 18, 0, 0 }, tint = "keep" },
		{ p = { 0.60, 0.14, -0.44 }, sz = { 0.08, 0.24, 0.34 }, c = C_CRIMSON, r = { 18, 0, 0 }, tint = "keep" },
		{ p = { 0, 0.56, 0.14 }, sz = { 0.26, 0.32, 1.42 }, c = C_CLOUD, tint = "secondary" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.14, -0.02 }, sz = { 0.68, 0.92, 0.72 }, c = C_GOLD, tint = "primary" },
		{ p = { 0, 0.12, -0.34 }, sz = { 0.52, 0.84, 0.18 }, c = C_AMBER, m = Enum.Material.Metal, tint = "primary" },
	}
	for i = 0, 3 do
		table.insert(neckVoxels, {
			p = { 0, -0.08 + i * 0.24, 0.42 },
			sz = { 0.28, 0.46, 0.42 },
			c = if i % 2 == 0 then C_CLOUD else C_SILVER,
			r = { 28 + i * 5, 0, 0 },
			tint = "secondary",
		})
	end

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, 0.02 }, sz = { 0.78, 0.64, 0.84 }, c = C_GOLD, tint = "primary" },
		{ p = { 0, -0.04, -0.56 }, sz = { 0.52, 0.38, 0.52 }, c = C_GOLD, tint = "primary" },
		{ p = { 0, -0.24, -0.48 }, sz = { 0.44, 0.18, 0.48 }, c = C_CRIMSON, r = { 14, 0, 0 }, tint = "keep" },
		{ p = { 0, 0.48, 0.26 }, sz = { 0.32, 0.44, 0.58 }, c = C_CLOUD, r = { 28, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.38, 0.10, -0.24 }, sz = { 0.08, 0.14, 0.22 }, c = C_CRIMSON, m = Enum.Material.Neon, tint = "keep" })
		-- Tall branched imperial antlers
		table.insert(headVoxels, { p = { side * 0.22, 0.56, 0.04 }, sz = { 0.14, 0.62, 0.16 }, c = C_ANTLER, r = { -20, 0, side * 12 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.30, 0.94, 0.22 }, sz = { 0.10, 0.48, 0.12 }, c = C_ANTLER, r = { -34, 0, side * 16 }, tint = "keep" })
		-- Crimson dragon whisker tendrils curling upward
		table.insert(headVoxels, { p = { side * 0.34, 0.20, -0.44 }, sz = { 0.10, 0.48, 0.12 }, c = C_CRIMSON, m = Enum.Material.Neon, r = { 24, 0, side * -18 }, tint = "keep" })
	end

	local function makeQilinEar(side: number): { VoxelSpec }
		return {
			{ p = { 0, 0.14, 0.04 }, sz = { 0.20, 0.36, 0.22 }, c = C_CLOUD, r = { -12, 0, side * -22 }, tint = "secondary" },
		}
	end

	local function makeQilinLeg(): { VoxelSpec }
		-- Hub Y = 0.62 -> dragon paw sole 0.62 - 0.50 - 0.12 = 0.00
		return {
			{ p = { 0, 0.24, 0 }, sz = { 0.42, 0.56, 0.44 }, c = C_GOLD, tint = "primary" },
			{ p = { 0, -0.14, 0.02 }, sz = { 0.34, 0.46, 0.36 }, c = C_AMBER, tint = "primary" },
			{ p = { 0, 0.02, 0.22 }, sz = { 0.20, 0.36, 0.20 }, c = C_GOLD, r = { 28, 0, 0 }, tint = "primary" },
			{ p = { 0, -0.50, -0.06 }, sz = { 0.40, 0.24, 0.48 }, c = C_AMBER, tint = "primary" },
			{ p = { -0.12, -0.50, -0.36 }, sz = { 0.09, 0.16, 0.22 }, c = C_ANTLER, tint = "keep" },
			{ p = { 0.12, -0.50, -0.36 }, sz = { 0.09, 0.16, 0.22 }, c = C_ANTLER, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0.28 }, sz = { 0.30, 0.28, 0.64 }, c = C_GOLD, r = { 18, 0, 0 }, tint = "primary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.18, 0.26 }, sz = { 0.36, 0.38, 0.62 }, c = C_SILVER, r = { 28, 0, 0 }, tint = "secondary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.24, 0.28 }, sz = { 0.44, 0.52, 0.68 }, c = C_CLOUD, r = { 22, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.44, 0.52 }, sz = { 0.28, 0.38, 0.46 }, c = C_SILVER, r = { 36, 0, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.36, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.88, -0.84), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.66, -1.06), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.36, 2.92, -0.84), makeQilinEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.36, 2.92, -0.84), makeQilinEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.46, 0.62, -0.70), makeQilinLeg())
	local legFR = session:AddBone("LegFR", Vector3.new(0.46, 0.62, -0.70), makeQilinLeg())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.46, 0.62, 0.72), makeQilinLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.46, 0.62, 0.72), makeQilinLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.40, 1.00), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.54, 1.54), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.82, 2.02), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.36, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.64, -0.78))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.48, -0.96))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.34, 2.86, -0.84))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.34, 2.86, -0.84))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.46, 1.02, -0.70))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.46, 1.02, -0.70))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.46, 1.02, 0.72))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.46, 1.02, 0.72))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.40, 0.96))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.52, 1.50))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.80, 1.98))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.44, 0.56), Vector3.new(0, 0.14, 0.56), C_GOLD, C_CLOUD, 0.55, "GoldQilinTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.38, 0), "GoldQilinCloudVFX", { C_GOLD, C_CLOUD, C_CRIMSON }, 10, 0.32)
	end

	return session
end

return EternalAshenKitsune
