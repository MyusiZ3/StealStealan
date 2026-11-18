--!strict
-- ByakkoInkTiger.luau (Voxel)
-- Candidate #4: Mythical White Tiger (Baihu) with Bold Swirling Black Sumi-e Ink Stripes,
-- Twin Forehead Horns, Golden Cheek Wisps, Spiked Black Back Crest & Amber Eyes.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_WHITE = Color3.fromRGB(248, 250, 252)
local C_CREAM = Color3.fromRGB(224, 212, 176)
local C_INK = Color3.fromRGB(24, 20, 22)
local C_AMBER = Color3.fromRGB(248, 168, 38)
local C_MAW = Color3.fromRGB(172, 58, 68)
local C_EAR_PINK = Color3.fromRGB(224, 152, 156)

local ByakkoInkTiger = {
	Id = "ByakkoInkTiger",
	DisplayName = "Byakko Ink Tiger",
	Archetype = "QuadrupedFeline" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	StagingSlot = 4,
	BaseConceptId = "ByakkoInkTiger",
	DefaultScale = 1.30,
	AccentColor = C_AMBER,
}

function ByakkoInkTiger.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.32, 1.18, 2.28), C_WHITE)

	local torsoVoxels: { VoxelSpec } = {
		-- Muscular broad chest & leaner waist
		{ p = { 0, 0.06, -0.44 }, sz = { 1.16, 0.98, 1.14 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.02, 0.52 }, sz = { 0.98, 0.84, 1.06 }, c = C_WHITE, tint = "primary" },
		-- Protruding black sumi-e ink bands & tall shoulder ink spike crest
		{ p = { 0, 0.58, -0.48 }, sz = { 0.20, 0.24, 0.96 }, c = C_INK, tint = "keep" },
		{ p = { 0, 0.92, -0.58 }, sz = { 0.14, 0.66, 0.34 }, c = C_INK, r = { 24, 0, 0 }, tint = "keep" },
		{ p = { -0.60, 0.16, -0.42 }, sz = { 0.08, 0.56, 0.24 }, c = C_INK, r = { 14, 0, 0 }, tint = "keep" },
		{ p = { 0.60, 0.16, -0.42 }, sz = { 0.08, 0.56, 0.24 }, c = C_INK, r = { 14, 0, 0 }, tint = "keep" },
		{ p = { -0.51, 0.12, 0.38 }, sz = { 0.08, 0.48, 0.22 }, c = C_INK, r = { -16, 0, 0 }, tint = "keep" },
		{ p = { 0.51, 0.12, 0.38 }, sz = { 0.08, 0.48, 0.22 }, c = C_INK, r = { -16, 0, 0 }, tint = "keep" },
		-- Cream-gold shoulder wisps
		{ p = { -0.58, 0.28, -0.78 }, sz = { 0.14, 0.20, 0.46 }, c = C_CREAM, r = { 12, -18, 0 }, tint = "secondary" },
		{ p = { 0.58, 0.28, -0.78 }, sz = { 0.14, 0.20, 0.46 }, c = C_CREAM, r = { 12, 18, 0 }, tint = "secondary" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, -0.06 }, sz = { 0.88, 0.78, 0.78 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.46, 0.10 }, sz = { 0.18, 0.28, 0.52 }, c = C_INK, r = { 18, 0, 0 }, tint = "keep" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.10, 0.02 }, sz = { 0.88, 0.68, 0.82 }, c = C_WHITE, tint = "primary" },
		-- Roaring upper snout + open crimson maw + lower fanged jaw
		{ p = { 0, 0.06, -0.54 }, sz = { 0.58, 0.34, 0.48 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.18, -0.78 }, sz = { 0.20, 0.12, 0.10 }, c = C_INK, tint = "keep" },
		{ p = { 0, -0.12, -0.46 }, sz = { 0.40, 0.22, 0.42 }, c = C_MAW, tint = "keep" },
		{ p = { 0, -0.28, -0.46 }, sz = { 0.48, 0.16, 0.48 }, c = C_WHITE, r = { 12, 0, 0 }, tint = "primary" },
		-- Forehead black king-mark & twin white spirit horns
		{ p = { 0, 0.46, -0.14 }, sz = { 0.28, 0.08, 0.36 }, c = C_INK, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.44, 0.14, -0.24 }, sz = { 0.08, 0.14, 0.22 }, c = C_AMBER, m = Enum.Material.Neon, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.18, -0.06, -0.68 }, sz = { 0.08, 0.18, 0.08 }, c = C_WHITE, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.20, 0.58, -0.04 }, sz = { 0.14, 0.46, 0.16 }, c = C_WHITE, r = { -16, 0, side * -8 }, tint = "primary" })
		-- Sweeping golden cheek whiskers & black cheek ruff
		table.insert(headVoxels, { p = { side * 0.48, -0.04, 0.02 }, sz = { 0.16, 0.34, 0.42 }, c = C_WHITE, r = { 0, side * -18, 0 }, tint = "primary" })
		table.insert(headVoxels, { p = { side * 0.54, 0.04, 0.26 }, sz = { 0.10, 0.14, 0.56 }, c = C_CREAM, r = { 10, side * -24, 0 }, tint = "secondary" })
	end

	local function makeTigerEar(side: number): { VoxelSpec }
		return {
			{ p = { 0, 0.14, 0 }, sz = { 0.24, 0.32, 0.18 }, c = C_INK, r = { -8, 0, side * -16 }, tint = "keep" },
			{ p = { 0, 0.12, -0.08 }, sz = { 0.14, 0.20, 0.08 }, c = C_EAR_PINK, r = { -8, 0, side * -16 }, tint = "keep" },
		}
	end

	local function makeTigerLeg(side: number): { VoxelSpec }
		-- Hub Y = 0.56 -> paw sole 0.56 - 0.45 - 0.11 = 0.00
		return {
			{ p = { 0, 0.22, 0 }, sz = { 0.46, 0.56, 0.48 }, c = C_WHITE, tint = "primary" },
			{ p = { side * 0.24, 0.18, 0.02 }, sz = { 0.06, 0.34, 0.22 }, c = C_INK, tint = "keep" },
			{ p = { 0, -0.16, -0.02 }, sz = { 0.38, 0.42, 0.40 }, c = C_WHITE, tint = "primary" },
			{ p = { side * 0.20, -0.16, -0.02 }, sz = { 0.06, 0.24, 0.18 }, c = C_INK, tint = "keep" },
			{ p = { 0, -0.45, -0.10 }, sz = { 0.44, 0.22, 0.50 }, c = C_WHITE, tint = "primary" },
			{ p = { -0.14, -0.46, -0.38 }, sz = { 0.08, 0.14, 0.18 }, c = C_INK, tint = "keep" },
			{ p = { 0.00, -0.46, -0.40 }, sz = { 0.08, 0.14, 0.18 }, c = C_INK, tint = "keep" },
			{ p = { 0.14, -0.46, -0.38 }, sz = { 0.08, 0.14, 0.18 }, c = C_INK, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0.34 }, sz = { 0.26, 0.26, 0.78 }, c = C_WHITE, r = { -14, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.06, 0.44 }, sz = { 0.30, 0.30, 0.16 }, c = C_INK, r = { -14, 0, 0 }, tint = "keep" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.10, 0.34 }, sz = { 0.22, 0.22, 0.76 }, c = C_WHITE, r = { 12, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.12, 0.44 }, sz = { 0.26, 0.26, 0.16 }, c = C_INK, r = { 12, 0, 0 }, tint = "keep" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.22, 0.28 }, sz = { 0.20, 0.20, 0.64 }, c = C_INK, r = { 34, 0, 0 }, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.14, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.48, -0.92), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 1.82, -1.36), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.36, 2.20, -1.16), makeTigerEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.36, 2.20, -1.16), makeTigerEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.52, 0.56, -0.68), makeTigerLeg(-1))
	local legFR = session:AddBone("LegFR", Vector3.new(0.52, 0.56, -0.68), makeTigerLeg(1))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.48, 0.56, 0.72), makeTigerLeg(-1))
	local legBR = session:AddBone("LegBR", Vector3.new(0.48, 0.56, 0.72), makeTigerLeg(1))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.18, 1.02), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.12, 1.70), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.26, 2.34), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.14, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.36, -0.82))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 1.72, -1.20))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.34, 2.14, -1.16))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.34, 2.14, -1.16))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.52, 0.96, -0.68))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.52, 0.96, -0.68))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.48, 0.96, 0.72))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.48, 0.96, 0.72))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.18, 0.98))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.12, 1.66))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.24, 2.30))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.34, 0.50), Vector3.new(0, 0.10, 0.50), C_INK, C_CREAM, 0.50, "ByakkoInkTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.32, -0.20), "ByakkoSpiritVFX", { C_WHITE, C_CREAM, C_AMBER }, 9, 0.30)
	end

	return session
end

return ByakkoInkTiger
