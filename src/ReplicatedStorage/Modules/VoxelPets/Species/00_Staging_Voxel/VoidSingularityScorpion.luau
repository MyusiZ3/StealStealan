--!strict
-- VoidSingularityScorpion.luau (Voxel)
-- Candidate #6: Purple-Obsidian Armored Void Scorpion with Glowing Amethyst Carapace Core,
-- 8 Splayed Arachnid Legs, Giant Spiked Pincers & Overhead Black-Hole Accretion Stinger Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_CHITIN = Color3.fromRGB(34, 20, 50)
local C_ARMOR = Color3.fromRGB(72, 34, 118)
local C_VIOLET = Color3.fromRGB(186, 72, 255)
local C_ORCHID = Color3.fromRGB(236, 148, 255)
local C_BLACK_HOLE = Color3.fromRGB(6, 2, 12)

local VoidSingularityScorpion = {
	Id = "VoidSingularityScorpion",
	DisplayName = "Void Singularity Scorpion",
	Archetype = "ArachnidScorpion" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	StagingSlot = 6,
	BaseConceptId = "VoidSingularityScorpion",
	DefaultScale = 1.25,
	AccentColor = C_VIOLET,
}

function VoidSingularityScorpion.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.56, 0.88, 1.96), C_CHITIN)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0 }, sz = { 1.38, 0.62, 1.76 }, c = C_CHITIN, tint = "primary" },
		{ p = { 0, 0.28, -0.10 }, sz = { 1.16, 0.32, 1.42 }, c = C_ARMOR, tint = "secondary" },
		-- Glowing amethyst crystal shield core on dorsal carapace
		{ p = { 0, 0.44, -0.22 }, sz = { 0.68, 0.18, 0.88 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" },
		{ p = { -0.48, 0.36, -0.34 }, sz = { 0.22, 0.28, 0.72 }, c = C_CHITIN, r = { 10, -14, 0 }, tint = "primary" },
		{ p = { 0.48, 0.36, -0.34 }, sz = { 0.22, 0.28, 0.72 }, c = C_CHITIN, r = { 10, 14, 0 }, tint = "primary" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, -0.02, -0.18 }, sz = { 0.86, 0.42, 0.56 }, c = C_CHITIN, tint = "primary" },
		{ p = { -0.28, 0.08, -0.44 }, sz = { 0.14, 0.12, 0.18 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0.28, 0.08, -0.44 }, sz = { 0.14, 0.12, 0.18 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" },
		{ p = { -0.16, -0.14, -0.52 }, sz = { 0.14, 0.16, 0.28 }, c = C_ARMOR, tint = "secondary" },
		{ p = { 0.16, -0.14, -0.52 }, sz = { 0.14, 0.16, 0.28 }, c = C_ARMOR, tint = "secondary" },
	}

	local function makePincerArm(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.24, -0.04, -0.32 }, sz = { 0.38, 0.32, 0.72 }, c = C_CHITIN, r = { 8, side * -18, 0 }, tint = "primary" },
			{ p = { side * 0.38, 0.02, -0.84 }, sz = { 0.52, 0.42, 0.78 }, c = C_ARMOR, r = { 6, side * 12, 0 }, tint = "secondary" },
			{ p = { side * 0.42, 0.18, -0.82 }, sz = { 0.24, 0.14, 0.48 }, c = C_VIOLET, m = Enum.Material.Neon, r = { 6, side * 12, 0 }, tint = "keep" },
			-- Inner fixed pincer claw
			{ p = { side * 0.20, -0.04, -1.36 }, sz = { 0.18, 0.22, 0.56 }, c = C_CHITIN, r = { 0, side * 22, 0 }, tint = "primary" },
		}
	end
	local function makePincerClawTip(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.08, 0, -0.32 }, sz = { 0.20, 0.24, 0.68 }, c = C_CHITIN, r = { 0, side * 24, 0 }, tint = "primary" },
			{ p = { side * 0.10, 0.08, -0.30 }, sz = { 0.10, 0.10, 0.44 }, c = C_VIOLET, m = Enum.Material.Neon, r = { 0, side * 24, 0 }, tint = "keep" },
		}
	end

	-- Each leg bank holds 2 splayed arachnid legs (4 banks x 2 = 8 scorpion legs!)
	local function makeArachnidLegPair(side: number): { VoxelSpec }
		-- Hub Y = 0.48 -> unrotated tarsus tips at relY = -0.40, szY = 0.16 -> 0.48 - 0.40 - 0.08 = 0.00
		local out: { VoxelSpec } = {}
		for _, zOff in ipairs({ -0.24, 0.24 }) do
			table.insert(out, { p = { side * 0.30, 0.12, zOff }, sz = { 0.58, 0.20, 0.20 }, c = C_ARMOR, r = { 0, 0, side * 22 }, tint = "secondary" })
			table.insert(out, { p = { side * 0.66, -0.14, zOff }, sz = { 0.20, 0.48, 0.20 }, c = C_CHITIN, r = { 0, 0, side * -16 }, tint = "primary" })
			table.insert(out, { p = { side * 0.74, -0.40, zOff }, sz = { 0.16, 0.16, 0.16 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" })
		end
		return out
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.26, 0.24 }, sz = { 0.56, 0.62, 0.58 }, c = C_CHITIN, r = { 28, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.66, 0.40 }, sz = { 0.48, 0.56, 0.48 }, c = C_ARMOR, r = { 12, 0, 0 }, tint = "secondary" },
		{ p = { -0.28, 0.66, 0.40 }, sz = { 0.10, 0.22, 0.22 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0.28, 0.66, 0.40 }, sz = { 0.10, 0.22, 0.22 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.38, -0.06 }, sz = { 0.44, 0.78, 0.46 }, c = C_CHITIN, r = { -22, 0, 0 }, tint = "primary" },
		-- Embedded mini black hole orb on upper tail
		{ p = { 0, 0.56, -0.22 }, sz = { 0.52, 0.30, 0.30 }, c = C_VIOLET, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0, 0.56, -0.24 }, sz = { 0.56, 0.18, 0.18 }, c = C_BLACK_HOLE, tint = "keep" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.18, -0.38 }, sz = { 0.40, 0.40, 0.76 }, c = C_ARMOR, r = { 16, 0, 0 }, tint = "secondary" },
		-- Giant Singularity Black-Hole Stinger Sphere + Accretion Ring + Curved Stinger Blade
		{ p = { 0, 0.28, -0.96 }, sz = { 0.86, 0.86, 0.86 }, c = C_ORCHID, m = Enum.Material.Neon, tr = 0.35, tint = "keep" },
		{ p = { 0, 0.28, -0.96 }, sz = { 0.54, 0.54, 0.54 }, c = C_BLACK_HOLE, tint = "keep" },
		{ p = { 0, 0.28, -0.96 }, sz = { 1.24, 0.10, 0.22 }, c = C_VIOLET, m = Enum.Material.Neon, r = { 0, 24, -28 }, tint = "keep" },
		{ p = { 0, 0.62, -1.28 }, sz = { 0.18, 0.22, 0.68 }, c = C_CHITIN, r = { 28, 0, 0 }, tint = "primary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 0.68, 0), torsoVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 0.68, -0.92), headVoxels)

	local wingL = session:AddBone("WingL", Vector3.new(-0.56, 0.68, -0.78), makePincerArm(-1))
	local wingTipL = session:AddBone("WingTipL", Vector3.new(-1.08, 0.70, -1.96), makePincerClawTip(-1))
	local wingR = session:AddBone("WingR", Vector3.new(0.56, 0.68, -0.78), makePincerArm(1))
	local wingTipR = session:AddBone("WingTipR", Vector3.new(1.08, 0.70, -1.96), makePincerClawTip(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.58, 0.48, -0.36), makeArachnidLegPair(-1))
	local legFR = session:AddBone("LegFR", Vector3.new(0.58, 0.48, -0.36), makeArachnidLegPair(1))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.58, 0.48, 0.42), makeArachnidLegPair(-1))
	local legBR = session:AddBone("LegBR", Vector3.new(0.58, 0.48, 0.42), makeArachnidLegPair(1))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.84, 0.80), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.72, 1.24), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 2.44, 0.96), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 0.68, 0))
		session:AttachMotor("HeadJoint", torso, head, Vector3.new(0, 0.68, -0.84))
		session:AttachMotor("WingLJoint", torso, wingL, Vector3.new(-0.52, 0.68, -0.74))
		session:AttachMotor("WingTipLJoint", wingL, wingTipL, Vector3.new(-1.04, 0.70, -1.90))
		session:AttachMotor("WingRJoint", torso, wingR, Vector3.new(0.52, 0.68, -0.74))
		session:AttachMotor("WingTipRJoint", wingR, wingTipR, Vector3.new(1.04, 0.70, -1.90))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.58, 0.60, -0.36))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.58, 0.60, -0.36))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.58, 0.60, 0.42))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.58, 0.60, 0.42))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.84, 0.76))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.68, 1.20))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 2.40, 0.98))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.56, -0.96), Vector3.new(0, 0.02, -0.96), C_VIOLET, C_ORCHID, 0.55, "VoidHoleTrail")
		VFXPresets.AttachBodyAura(tail3, s, Vector3.new(0, 0.28, -0.96), "SingularityStingerVFX", { C_ORCHID, C_VIOLET, C_BLACK_HOLE }, 11, 0.36)
	end

	return session
end

return VoidSingularityScorpion
