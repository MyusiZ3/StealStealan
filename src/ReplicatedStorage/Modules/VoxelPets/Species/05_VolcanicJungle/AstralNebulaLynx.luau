--!strict
-- AstralNebulaLynx.luau
-- Ref 4: Three-Eyed Midnight-Indigo Cosmic Spirit Caracal with White Shoulder Mantle,
-- Golden-Trimmed Spirit Talisman, Tall Glowing Cyan Ears & Orchid Nebula Plume Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_INDIGO = Color3.fromRGB(28, 34, 78)
local C_COBALT = Color3.fromRGB(42, 86, 212)
local C_CYAN = Color3.fromRGB(48, 214, 255)
local C_SHAWL_WHITE = Color3.fromRGB(224, 238, 255)
local C_GOLD = Color3.fromRGB(232, 188, 92)
local C_ORCHID = Color3.fromRGB(246, 148, 232)
local C_STAR_WHITE = Color3.fromRGB(252, 248, 255)
local C_EYE_GLOW = Color3.fromRGB(248, 224, 255)
local C_EAR_NAVY = Color3.fromRGB(16, 20, 48)

local AstralNebulaLynx = {
	Id = "AstralNebulaLynx",
	DisplayName = "Astral Nebula Lynx",
	Archetype = "QuadrupedFeline" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(64, 212, 255),
}

function AstralNebulaLynx.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.24, 1.06, 1.88), C_INDIGO)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.00, 0 }, sz = { 1.06, 0.88, 1.78 }, c = C_INDIGO, tint = "primary" },
		{ p = { 0, 0.01, -0.52 }, sz = { 1.12, 0.82, 0.72 }, c = C_COBALT, tint = "primary" },
		-- White feathered shoulder mantle/capelet with gold trim points
		{ p = { 0, 0.34, -0.06 }, sz = { 1.24, 0.36, 1.16 }, c = C_SHAWL_WHITE, tint = "secondary" },
		{ p = { -0.58, 0.16, 0.02 }, sz = { 0.16, 0.32, 0.82 }, c = C_SHAWL_WHITE, r = { 0, 0, -14 }, tint = "secondary" },
		{ p = { 0.58, 0.16, 0.02 }, sz = { 0.16, 0.32, 0.82 }, c = C_SHAWL_WHITE, r = { 0, 0, 14 }, tint = "secondary" },
		{ p = { -0.60, 0.04, 0.04 }, sz = { 0.14, 0.12, 0.88 }, c = C_GOLD, r = { 0, 0, -14 }, m = Enum.Material.Metal, tint = "keep" },
		{ p = { 0.60, 0.04, 0.04 }, sz = { 0.14, 0.12, 0.88 }, c = C_GOLD, r = { 0, 0, 14 }, m = Enum.Material.Metal, tint = "keep" },
	}

	local bowVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, 0.02 }, sz = { 0.24, 0.24, 0.16 }, c = C_GOLD, m = Enum.Material.Metal, tint = "keep" },
		{ p = { 0, -0.18, -0.02 }, sz = { 0.22, 0.38, 0.10 }, c = C_SHAWL_WHITE, tint = "keep" },
		{ p = { 0, -0.18, -0.04 }, sz = { 0.12, 0.26, 0.08 }, c = C_CYAN, tint = "keep" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.10, -0.02 }, sz = { 0.66, 0.62, 0.66 }, c = C_INDIGO, tint = "primary" },
		{ p = { 0, 0.40, -0.08 }, sz = { 0.46, 0.34, 0.46 }, c = C_INDIGO, tint = "primary" }, -- recessed upper neck socket inside Head
		{ p = { 0, 0.02, -0.32 }, sz = { 0.54, 0.44, 0.20 }, c = C_COBALT, tint = "secondary" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0.00 }, sz = { 1.06, 0.86, 0.96 }, c = C_INDIGO, tint = "primary" },
		{ p = { 0, -0.16, -0.50 }, sz = { 0.54, 0.32, 0.26 }, c = C_COBALT, tint = "primary" },
		{ p = { 0, -0.08, -0.62 }, sz = { 0.16, 0.12, 0.10 }, c = C_CYAN, tint = "keep" },
		-- Three luminous lavender-white eyes (Left, Right, and vertical Forehead Third Eye)
		{ p = { -0.28, 0.06, -0.50 }, sz = { 0.22, 0.22, 0.10 }, c = C_EYE_GLOW, tint = "keep" },
		{ p = { 0.28, 0.06, -0.50 }, sz = { 0.22, 0.22, 0.10 }, c = C_EYE_GLOW, tint = "keep" },
		{ p = { 0, 0.32, -0.49 }, sz = { 0.14, 0.24, 0.10 }, c = C_EYE_GLOW, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.58, -0.06, -0.42 }, sz = { 0.44, 0.06, 0.06 }, c = C_EAR_NAVY, r = { 0, side * -12, side * 10 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.56, -0.16, -0.42 }, sz = { 0.40, 0.06, 0.06 }, c = C_EAR_NAVY, r = { 0, side * -12, side * -8 }, tint = "keep" })
	end

	local function makeLynxEar(side: number): { VoxelSpec }
		return {
			{ p = { 0, 0.38, 0.02 }, sz = { 0.42, 0.88, 0.28 }, c = C_EAR_NAVY, r = { -6, 0, side * -10 }, tint = "primary" },
			{ p = { 0, 0.84, 0.04 }, sz = { 0.22, 0.28, 0.18 }, c = C_EAR_NAVY, r = { -6, 0, side * -12 }, tint = "primary" },
			{ p = { 0, 0.36, -0.09 }, sz = { 0.26, 0.64, 0.10 }, c = C_COBALT, r = { -6, 0, side * -10 }, tint = "secondary" },
			{ p = { 0, 0.48, -0.11 }, sz = { 0.18, 0.40, 0.08 }, c = C_CYAN, r = { -6, 0, side * -10 }, tint = "secondary" },
			{ p = { side * 0.22, 0.06, 0.02 }, sz = { 0.24, 0.28, 0.22 }, c = C_COBALT, r = { 0, 0, side * -28 }, tint = "secondary" },
		}
	end

	local function makeLynxLeg(isHind: boolean): { VoxelSpec }
		return {
			{ p = { 0, 0.12, 0 }, sz = { if isHind then 0.42 else 0.38, 0.56, if isHind then 0.48 else 0.40 }, c = C_INDIGO, tint = "primary" },
			{ p = { 0, -0.22, -0.02 }, sz = { 0.30, 0.34, 0.32 }, c = C_COBALT, tint = "primary" },
			{ p = { 0, -0.36, -0.06 }, sz = { 0.34, 0.16, 0.38 }, c = C_CYAN, tint = "secondary" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.08, 0.30 }, sz = { 0.48, 0.48, 0.78 }, c = C_COBALT, r = { 18, 0, 0 }, tint = "primary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.18, 0.32 }, sz = { 0.66, 0.62, 0.86 }, c = C_CYAN, r = { 34, 0, 0 }, tint = "secondary" },
		{ p = { -0.36, 0.20, 0.32 }, sz = { 0.22, 0.44, 0.56 }, c = C_COBALT, r = { 28, -14, 0 }, tint = "primary" },
		{ p = { 0.36, 0.20, 0.32 }, sz = { 0.22, 0.44, 0.56 }, c = C_COBALT, r = { 28, 14, 0 }, tint = "primary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.34, 0.28 }, sz = { 0.78, 0.82, 0.84 }, c = C_ORCHID, r = { 48, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.72, 0.48 }, sz = { 0.48, 0.68, 0.54 }, c = C_STAR_WHITE, r = { 56, 0, 0 }, tint = "secondary" },
		{ p = { -0.34, 0.56, 0.36 }, sz = { 0.24, 0.58, 0.42 }, c = C_STAR_WHITE, r = { 50, -18, 0 }, tint = "secondary" },
		{ p = { 0.34, 0.56, 0.36 }, sz = { 0.24, 0.58, 0.42 }, c = C_STAR_WHITE, r = { 50, 18, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.12, 0), torsoVoxels)
	local bow = session:AddBone("BowRibbon", Vector3.new(0, 1.04, -1.04), bowVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.56, -0.68), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.16, -0.86), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.38, 2.66, -0.82), makeLynxEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.38, 2.66, -0.82), makeLynxEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.44, 0.44, -0.62), makeLynxLeg(false))
	local legFR = session:AddBone("LegFR", Vector3.new(0.44, 0.44, -0.62), makeLynxLeg(false))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.46, 0.44, 0.62), makeLynxLeg(true))
	local legBR = session:AddBone("LegBR", Vector3.new(0.46, 0.44, 0.62), makeLynxLeg(true))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.14, 0.86), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.38, 1.50), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.82, 2.04), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.12, 0))
		session:AttachMotor("BowJoint", torso, bow, Vector3.new(0, 1.16, -0.96))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.44, -0.64))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 1.98, -0.80))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.36, 2.54, -0.82))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.36, 2.54, -0.82))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.44, 0.84, -0.62))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.44, 0.84, -0.62))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.46, 0.86, 0.62))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.46, 0.86, 0.62))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.14, 0.82))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.34, 1.44))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.76, 1.98))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.86, 0.56), Vector3.new(0, 0.42, 0.56), C_ORCHID, C_CYAN, 0.62, "AstralNebulaTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.35, 0), "AstralNebulaDustVFX", { C_CYAN, C_ORCHID, C_STAR_WHITE }, 11, 0.34)
	end

	return session
end

return AstralNebulaLynx
