--!strict
-- CelestialAntlerStag.luau (Voxel)
-- Candidate #8: Noble Pure-White Spirit Stag with Fluffy Chest Ruff, Cyan Flank Swirls,
-- Sweeping Bronze-Ember Antlers & Radiant Floating 4-Point Celestial Star.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_WHITE = Color3.fromRGB(248, 250, 255)
local C_PEARL = Color3.fromRGB(224, 232, 244)
local C_BRONZE = Color3.fromRGB(96, 72, 60)
local C_EMBER = Color3.fromRGB(238, 98, 48)
local C_CYAN = Color3.fromRGB(132, 234, 248)
local C_STAR = Color3.fromRGB(255, 252, 220)
local C_ROSE = Color3.fromRGB(232, 152, 158)
local C_CLAW = Color3.fromRGB(48, 44, 52)

local CelestialAntlerStag = {
	Id = "CelestialAntlerStag",
	DisplayName = "Celestial Antler Stag",
	Archetype = "QuadrupedBeast" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	StagingSlot = 8,
	BaseConceptId = "CelestialAntlerStag",
	DefaultScale = 1.35,
	AccentColor = C_CYAN,
}

function CelestialAntlerStag.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.26, 1.48, 2.24), C_WHITE)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, -0.44 }, sz = { 1.08, 1.04, 1.08 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.02, 0.50 }, sz = { 0.96, 0.90, 1.06 }, c = C_WHITE, tint = "primary" },
		-- Fluffy layered chest mane ruff
		{ p = { 0, 0.14, -0.94 }, sz = { 1.18, 0.98, 0.44 }, c = C_PEARL, tint = "secondary" },
		{ p = { 0, -0.24, -1.02 }, sz = { 0.86, 0.56, 0.36 }, c = C_WHITE, tint = "primary" },
		-- Glowing pale-cyan celestial flank swirls
		{ p = { -0.52, 0.10, 0.24 }, sz = { 0.06, 0.36, 0.98 }, c = C_CYAN, m = Enum.Material.Neon, r = { -8, 0, 0 }, tint = "keep" },
		{ p = { 0.52, 0.10, 0.24 }, sz = { 0.06, 0.36, 0.98 }, c = C_CYAN, m = Enum.Material.Neon, r = { -8, 0, 0 }, tint = "keep" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.34, -0.04 }, sz = { 0.78, 1.08, 0.78 }, c = C_PEARL, tint = "secondary" },
		{ p = { 0, 0.68, -0.08 }, sz = { 0.92, 0.54, 0.82 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.38, -0.46 }, sz = { 0.10, 0.82, 0.10 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, -0.06 }, sz = { 0.54, 0.50, 0.68 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, -0.04, -0.52 }, sz = { 0.34, 0.30, 0.44 }, c = C_WHITE, r = { 12, 0, 0 }, tint = "primary" },
		-- Floating 4-point celestial star nestled between inner antler tines
		{ p = { 0, 0.82, -0.04 }, sz = { 0.18, 0.58, 0.18 }, c = C_STAR, m = Enum.Material.Neon, allowFloat = true, tint = "keep" },
		{ p = { 0, 0.82, -0.04 }, sz = { 0.58, 0.18, 0.18 }, c = C_STAR, m = Enum.Material.Neon, allowFloat = true, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.28, 0.10, -0.22 }, sz = { 0.06, 0.10, 0.18 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.36, 0.14, 0.04 }, sz = { 0.32, 0.14, 0.14 }, c = C_ROSE, r = { 0, 0, side * -18 }, tint = "keep" })
		-- Inner upright tines framing the star
		table.insert(headVoxels, { p = { side * 0.18, 0.56, -0.04 }, sz = { 0.12, 0.64, 0.12 }, c = C_BRONZE, r = { 0, 0, side * 12 }, tint = "keep" })
	end

	-- Sweeping giant lateral bronze-ember antlers on EarL / EarR
	local function makeSweepingAntler(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.42, 0.14, 0 }, sz = { 0.92, 0.22, 0.22 }, c = C_BRONZE, r = { 0, 0, side * -14 }, tint = "keep" },
			{ p = { side * 0.44, 0.16, -0.10 }, sz = { 0.72, 0.08, 0.08 }, c = C_EMBER, m = Enum.Material.Neon, r = { 0, 0, side * -14 }, tint = "keep" },
			{ p = { side * 1.02, 0.44, 0.04 }, sz = { 0.76, 0.24, 0.22 }, c = C_BRONZE, r = { 0, 0, side * -38 }, tint = "keep" },
			{ p = { side * 1.44, 0.96, 0.06 }, sz = { 0.20, 0.88, 0.20 }, c = C_BRONZE, r = { 0, 0, side * 12 }, tint = "keep" },
			{ p = { side * 0.86, 0.02, 0.02 }, sz = { 0.52, 0.14, 0.14 }, c = C_BRONZE, r = { 0, 0, side * 26 }, tint = "keep" },
		}
	end

	local function makeStagLeg(): { VoxelSpec }
		-- Hub Y = 0.70 -> feathered fetlock sole 0.70 - 0.58 - 0.12 = 0.00
		return {
			{ p = { 0, 0.28, 0 }, sz = { 0.40, 0.66, 0.42 }, c = C_WHITE, tint = "primary" },
			{ p = { 0, -0.18, 0.02 }, sz = { 0.28, 0.54, 0.30 }, c = C_WHITE, tint = "primary" },
			{ p = { 0, -0.44, 0.12 }, sz = { 0.38, 0.36, 0.38 }, c = C_PEARL, r = { 18, 0, 0 }, tint = "secondary" },
			{ p = { 0, -0.58, -0.02 }, sz = { 0.38, 0.24, 0.44 }, c = C_WHITE, tint = "primary" },
			{ p = { -0.10, -0.58, -0.28 }, sz = { 0.08, 0.14, 0.16 }, c = C_CLAW, tint = "keep" },
			{ p = { 0.10, -0.58, -0.28 }, sz = { 0.08, 0.14, 0.16 }, c = C_CLAW, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.14, 0.22 }, sz = { 0.32, 0.34, 0.48 }, c = C_WHITE, r = { 28, 0, 0 }, tint = "primary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.22, 0.18 }, sz = { 0.24, 0.36, 0.36 }, c = C_PEARL, r = { 38, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.42, 0.26 }, sz = { 0.14, 0.30, 0.16 }, c = C_CYAN, m = Enum.Material.Neon, r = { 24, 0, 0 }, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.48, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.98, -0.82), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.92, -0.94), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.24, 3.16, -0.92), makeSweepingAntler(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.24, 3.16, -0.92), makeSweepingAntler(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.42, 0.70, -0.68), makeStagLeg())
	local legFR = session:AddBone("LegFR", Vector3.new(0.42, 0.70, -0.68), makeStagLeg())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.42, 0.70, 0.70), makeStagLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.42, 0.70, 0.70), makeStagLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.56, 0.98), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.72, 1.32), tail2Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.48, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.78, -0.78))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.82, -0.90))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.22, 3.14, -0.92))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.22, 3.14, -0.92))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.42, 1.14, -0.68))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.42, 1.14, -0.68))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.42, 1.14, 0.70))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.42, 1.14, 0.70))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.56, 0.94))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.70, 1.28))

		VFXPresets.AttachBodyAura(head, s, Vector3.new(0, 0.82, -0.04), "StagStarVFX", { C_STAR, C_CYAN, C_EMBER }, 9, 0.28)
	end

	return session
end

return CelestialAntlerStag
