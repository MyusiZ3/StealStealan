--!strict
-- CelestiaStarCat.luau
-- Reference 3: Luminous Cyan Star-Spotted Cat with Pink Throat Ribbon Bow & Whiskers.

local RigCore = require(script.Parent.Parent.RigCore)
local VFXPresets = require(script.Parent.Parent.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_CYAN = Color3.fromRGB(38, 178, 248)
local C_SAPPHIRE = Color3.fromRGB(22, 114, 214)
local C_ICE_WHITE = Color3.fromRGB(228, 248, 255)
local C_BOW_PINK = Color3.fromRGB(255, 152, 206)
local C_INNER_PINK = Color3.fromRGB(248, 146, 192)
local C_NOSE = Color3.fromRGB(252, 108, 158)
local C_GOLD_SPOT = Color3.fromRGB(255, 238, 174)
local C_PINK_SPOT = Color3.fromRGB(255, 178, 222)
local C_DARK_EYE = Color3.fromRGB(16, 28, 56)
local C_AMBER_EYE = Color3.fromRGB(246, 188, 62)

local CelestiaStarCat = {
	Id = "CelestiaStarCat",
	DisplayName = "Celestia Starlight Cat",
	Archetype = "QuadrupedFeline" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(42, 178, 248),
}

function CelestiaStarCat.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.36, 1.10, 1.88), C_CYAN)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0, 0 }, sz = { 1.32, 1.06, 1.88 }, c = C_CYAN, tint = "primary" },
		{ p = { 0, 0.42, 0.04 }, sz = { 0.92, 0.26, 1.66 }, c = C_SAPPHIRE, tint = "primary" },
		{ p = { 0, 0.08, -0.78 }, sz = { 1.14, 0.96, 0.64 }, c = C_CYAN, tint = "primary" },
		{ p = { 0, 0.14, -1.04 }, sz = { 0.86, 0.82, 0.26 }, c = C_ICE_WHITE, tint = "secondary" },
		{ p = { -0.64, 0.04, 0.48 }, sz = { 0.10, 0.36, 0.36 }, c = C_PINK_SPOT, tint = "keep" },
		{ p = { 0.64, 0.04, 0.48 }, sz = { 0.10, 0.36, 0.36 }, c = C_PINK_SPOT, tint = "keep" },
		{ p = { -0.64, 0.22, -0.18 }, sz = { 0.10, 0.24, 0.24 }, c = C_GOLD_SPOT, tint = "keep" },
		{ p = { 0.64, 0.22, -0.18 }, sz = { 0.10, 0.24, 0.24 }, c = C_GOLD_SPOT, tint = "keep" },
		{ p = { -0.64, -0.14, 0.12 }, sz = { 0.10, 0.18, 0.18 }, c = C_ICE_WHITE, tint = "keep" },
		{ p = { 0.64, -0.14, 0.12 }, sz = { 0.10, 0.18, 0.18 }, c = C_ICE_WHITE, tint = "keep" },
	}

	local bowVoxels: { VoxelSpec } = {
		{ p = { 0, 0, -0.02 }, sz = { 0.26, 0.22, 0.20 }, c = C_BOW_PINK, tint = "secondary" },
		{ p = { -0.26, 0.06, 0.02 }, sz = { 0.34, 0.22, 0.14 }, c = C_BOW_PINK, r = { 0, 0, 14 }, tint = "secondary" },
		{ p = { 0.26, 0.06, 0.02 }, sz = { 0.34, 0.22, 0.14 }, c = C_BOW_PINK, r = { 0, 0, -14 }, tint = "secondary" },
		{ p = { -0.14, -0.34, -0.04 }, sz = { 0.12, 0.56, 0.10 }, c = C_BOW_PINK, r = { -8, 0, -10 }, tint = "secondary" },
		{ p = { 0.16, -0.40, -0.04 }, sz = { 0.12, 0.66, 0.10 }, c = C_BOW_PINK, r = { -6, 0, 12 }, tint = "secondary" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.14, -0.10 }, sz = { 0.72, 0.58, 0.72 }, c = C_CYAN, tint = "primary" },
		{ p = { 0, 0.06, -0.40 }, sz = { 0.62, 0.44, 0.22 }, c = C_ICE_WHITE, tint = "secondary" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, -0.04 }, sz = { 1.18, 1.02, 1.06 }, c = C_CYAN, tint = "primary" },
		{ p = { 0, 0.52, -0.04 }, sz = { 0.72, 0.16, 0.72 }, c = C_SAPPHIRE, tint = "primary" },
		{ p = { 0, -0.18, -0.56 }, sz = { 0.66, 0.38, 0.28 }, c = C_ICE_WHITE, tint = "secondary" },
		{ p = { 0, -0.08, -0.70 }, sz = { 0.20, 0.14, 0.12 }, c = C_NOSE, tint = "keep" },
		{ p = { -0.34, 0.10, -0.56 }, sz = { 0.24, 0.26, 0.10 }, c = C_SAPPHIRE, tint = "keep" },
		{ p = { 0.34, 0.10, -0.56 }, sz = { 0.24, 0.26, 0.10 }, c = C_AMBER_EYE, tint = "keep" },
		{ p = { -0.34, 0.10, -0.59 }, sz = { 0.12, 0.18, 0.08 }, c = C_DARK_EYE, tint = "keep" },
		{ p = { 0.34, 0.10, -0.59 }, sz = { 0.12, 0.18, 0.08 }, c = C_DARK_EYE, tint = "keep" },
		{ p = { -0.38, 0.16, -0.61 }, sz = { 0.08, 0.08, 0.06 }, c = C_ICE_WHITE, tint = "keep" },
		{ p = { 0.30, 0.16, -0.61 }, sz = { 0.08, 0.08, 0.06 }, c = C_ICE_WHITE, tint = "keep" },
		{ p = { -0.44, -0.08, -0.54 }, sz = { 0.14, 0.10, 0.08 }, c = C_PINK_SPOT, tint = "keep" },
		{ p = { 0.44, -0.08, -0.54 }, sz = { 0.14, 0.10, 0.08 }, c = C_PINK_SPOT, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		for w = -1, 1 do
			table.insert(headVoxels, {
				p = { side * 0.62, -0.14 + w * 0.10, -0.50 },
				sz = { 0.62, 0.04, 0.04 },
				c = C_ICE_WHITE,
				r = { 0, side * -10, side * (w * 12) },
				tint = "keep",
			})
		end
	end

	local function makeEar(side: number): { VoxelSpec }
		return {
			{ p = { 0, 0.22, 0 }, sz = { 0.40, 0.48, 0.28 }, c = C_CYAN, r = { 0, 0, side * -8 }, tint = "primary" },
			{ p = { 0, 0.48, 0 }, sz = { 0.24, 0.24, 0.20 }, c = C_SAPPHIRE, r = { 0, 0, side * -8 }, tint = "primary" },
			{ p = { 0, 0.20, -0.11 }, sz = { 0.22, 0.34, 0.10 }, c = C_INNER_PINK, tint = "keep" },
		}
	end

	local function makeCatLeg(isHind: boolean): { VoxelSpec }
		return {
			{ p = { 0, 0.20, 0 }, sz = { if isHind then 0.46 else 0.40, 0.48, if isHind then 0.56 else 0.42 }, c = C_CYAN, tint = "primary" },
			{ p = { 0, -0.12, -0.02 }, sz = { 0.34, 0.42, 0.36 }, c = C_CYAN, tint = "primary" },
			{ p = { 0, -0.32, -0.10 }, sz = { 0.40, 0.20, 0.46 }, c = C_ICE_WHITE, tint = "secondary" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.08, 0.24 }, sz = { 0.44, 0.44, 0.68 }, c = C_CYAN, tint = "primary" },
		{ p = { -0.22, 0.08, 0.26 }, sz = { 0.08, 0.18, 0.18 }, c = C_GOLD_SPOT, tint = "keep" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.16, 0.24 }, sz = { 0.42, 0.42, 0.68 }, c = C_SAPPHIRE, r = { 26, 0, 0 }, tint = "primary" },
		{ p = { 0.20, 0.18, 0.26 }, sz = { 0.08, 0.18, 0.18 }, c = C_PINK_SPOT, tint = "keep" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.22, 0.16 }, sz = { 0.42, 0.42, 0.62 }, c = C_ICE_WHITE, r = { 54, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.36, 0.22 }, sz = { 0.22, 0.22, 0.22 }, c = C_GOLD_SPOT, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.18, 0), torsoVoxels)
	local bow = session:AddBone("BowRibbon", Vector3.new(0, 1.24, -1.24), bowVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.72, -0.74), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.38, -0.92), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.42, 2.90, -0.88), makeEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.42, 2.90, -0.88), makeEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.48, 0.42, -0.66), makeCatLeg(false))
	local legFR = session:AddBone("LegFR", Vector3.new(0.48, 0.42, -0.66), makeCatLeg(false))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.52, 0.42, 0.64), makeCatLeg(true))
	local legBR = session:AddBone("LegBR", Vector3.new(0.52, 0.42, 0.64), makeCatLeg(true))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.14, 0.90), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.28, 1.42), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.54, 1.84), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.18, 0))
		session:AttachMotor("BowJoint", torso, bow, Vector3.new(0, 1.28, -1.16))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.62, -0.72))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.22, -0.86))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.40, 2.82, -0.88))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.40, 2.82, -0.88))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.48, 0.84, -0.66))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.48, 0.84, -0.66))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.52, 0.86, 0.64))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.52, 0.86, 0.64))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.14, 0.86))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.24, 1.38))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.50, 1.80))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.44, 0.28), Vector3.new(0, 0.24, 0.28), C_BOW_PINK, C_CYAN, 0.55, "StarlightTailTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.35, 0), "StarlightBokehVFX", { C_PINK_SPOT, C_GOLD_SPOT, C_CYAN }, 10, 0.34)
	end

	return session
end

return CelestiaStarCat
