--!strict
-- ObsidianNightmare.luau
-- Ref 2: Midnight-Indigo Scaled Dark Unicorn Steed with Ice-Violet Spiral Horn,
-- Gunmetal-Emerald Saddle, Ember Eyes, and Snow-White Lower Shins & Claws.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_OBSIDIAN = Color3.fromRGB(28, 26, 44)
local C_CHARCOAL = Color3.fromRGB(46, 44, 68)
local C_SLATE_SILVER = Color3.fromRGB(168, 178, 198)
local C_GUNMETAL = Color3.fromRGB(128, 136, 154)
local C_EMERALD_CLOTH = Color3.fromRGB(36, 132, 98)
local C_RUBY = Color3.fromRGB(224, 42, 58)
local C_HORN_ICE = Color3.fromRGB(178, 198, 255)
local C_SNOW_WHITE = Color3.fromRGB(246, 248, 255)
local C_EMBER = Color3.fromRGB(255, 118, 36)
local C_GOLD_EYE = Color3.fromRGB(255, 212, 72)

local ObsidianNightmare = {
	Id = "ObsidianNightmare",
	DisplayName = "Obsidian Moonhorn Steed",
	Archetype = "QuadrupedBeast" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(148, 168, 255),
}

function ObsidianNightmare.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.32, 1.30, 2.26), C_OBSIDIAN)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.00, 0 }, sz = { 1.04, 0.90, 2.12 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, -0.02, -0.56 }, sz = { 1.10, 0.88, 0.94 }, c = C_CHARCOAL, tint = "primary" },
		-- Silver-dusted front shoulders
		{ p = { -0.54, 0.06, -0.62 }, sz = { 0.14, 0.56, 0.56 }, c = C_SLATE_SILVER, tint = "secondary" },
		{ p = { 0.54, 0.06, -0.62 }, sz = { 0.14, 0.56, 0.56 }, c = C_SLATE_SILVER, tint = "secondary" },
		-- Sculpted gunmetal saddle, emerald cloth inlay, & ruby cantle gem
		{ p = { 0, 0.44, 0.06 }, sz = { 1.14, 0.20, 0.94 }, c = C_EMERALD_CLOTH, tint = "secondary" },
		{ p = { 0, 0.54, 0.06 }, sz = { 0.92, 0.16, 0.78 }, c = C_GUNMETAL, m = Enum.Material.Metal, tint = "secondary" },
		{ p = { 0, 0.68, -0.26 }, sz = { 0.68, 0.22, 0.18 }, c = C_GUNMETAL, r = { -16, 0, 0 }, m = Enum.Material.Metal, tint = "secondary" },
		{ p = { 0, 0.68, 0.40 }, sz = { 0.72, 0.24, 0.18 }, c = C_GUNMETAL, r = { 18, 0, 0 }, m = Enum.Material.Metal, tint = "secondary" },
		{ p = { 0, 0.78, 0.46 }, sz = { 0.16, 0.16, 0.14 }, c = C_RUBY, tint = "keep" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.12, 0 }, sz = { 0.66, 0.96, 0.72 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.62, -0.10 }, sz = { 0.42, 0.38, 0.42 }, c = C_OBSIDIAN, tint = "primary" }, -- recessed upper neck socket strictly inside Head
		{ p = { 0, 0.04, -0.32 }, sz = { 0.46, 0.86, 0.20 }, c = C_SLATE_SILVER, tint = "secondary" },
		-- Subtle lightning scale markings on nape sides
		{ p = { -0.33, 0.26, 0.04 }, sz = { 0.06, 0.44, 0.16 }, c = C_SLATE_SILVER, r = { -12, 0, 0 }, tint = "keep" },
		{ p = { 0.33, 0.26, 0.04 }, sz = { 0.06, 0.44, 0.16 }, c = C_SLATE_SILVER, r = { -12, 0, 0 }, tint = "keep" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0.02 }, sz = { 0.72, 0.64, 0.86 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, -0.06, -0.60 }, sz = { 0.44, 0.38, 0.56 }, c = C_OBSIDIAN, tint = "primary" },
		{ p = { 0, 0.14, -0.44 }, sz = { 0.36, 0.16, 0.56 }, c = C_CHARCOAL, r = { 12, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.18, -0.26 }, sz = { 0.16, 0.12, 0.24 }, c = C_SLATE_SILVER, tint = "keep" },
		-- Prominent ice-violet / snow-white Unicorn Horn pointing proud forward-upward
		{ p = { 0, 0.48, -0.36 }, sz = { 0.20, 0.58, 0.20 }, c = C_HORN_ICE, r = { 34, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.78, -0.58 }, sz = { 0.14, 0.46, 0.14 }, c = C_SNOW_WHITE, r = { 34, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.34, 0.08, -0.24 }, sz = { 0.10, 0.16, 0.26 }, c = C_EMBER, r = { -12, 0, 0 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.36, 0.08, -0.24 }, sz = { 0.08, 0.09, 0.14 }, c = C_GOLD_EYE, r = { -12, 0, 0 }, tint = "keep" })
	end

	local function makeStallionEar(side: number): { VoxelSpec }
		return {
			{ p = { 0, 0.16, 0 }, sz = { 0.18, 0.34, 0.18 }, c = C_OBSIDIAN, r = { 6, 0, side * -12 }, tint = "primary" },
			{ p = { 0, 0.16, -0.06 }, sz = { 0.10, 0.22, 0.08 }, c = C_CHARCOAL, r = { 6, 0, side * -12 }, tint = "primary" },
		}
	end

	local function makeNightmareLeg(): { VoxelSpec }
		return {
			{ p = { 0, 0.26, 0 }, sz = { 0.42, 0.62, 0.44 }, c = C_CHARCOAL, tint = "primary" },
			{ p = { 0, -0.22, 0 }, sz = { 0.26, 0.52, 0.26 }, c = C_HORN_ICE, tint = "secondary" },
			{ p = { 0, -0.54, -0.05 }, sz = { 0.34, 0.20, 0.42 }, c = C_SNOW_WHITE, tint = "secondary" },
			{ p = { -0.10, -0.57, -0.30 }, sz = { 0.09, 0.14, 0.16 }, c = C_SNOW_WHITE, tint = "keep" },
			{ p = { 0.10, -0.57, -0.30 }, sz = { 0.09, 0.14, 0.16 }, c = C_SNOW_WHITE, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0.18 }, sz = { 0.28, 0.28, 0.42 }, c = C_HORN_ICE, r = { 18, 0, 0 }, tint = "secondary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.12, 0.22 }, sz = { 0.34, 0.36, 0.48 }, c = C_SNOW_WHITE, r = { 26, 0, 0 }, tint = "secondary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.18, 0.18 }, sz = { 0.24, 0.26, 0.38 }, c = C_SNOW_WHITE, r = { 34, 0, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.38, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.94, -0.84), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.72, -1.08), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.28, 3.04, -0.78), makeStallionEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.28, 3.04, -0.78), makeStallionEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.44, 0.64, -0.74), makeNightmareLeg())
	local legFR = session:AddBone("LegFR", Vector3.new(0.44, 0.64, -0.74), makeNightmareLeg())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.46, 0.64, 0.74), makeNightmareLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.46, 0.64, 0.74), makeNightmareLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.50, 1.00), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.60, 1.32), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.72, 1.62), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.38, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.68, -0.76))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.52, -0.98))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.26, 2.98, -0.78))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.26, 2.98, -0.78))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.44, 1.04, -0.74))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.44, 1.04, -0.74))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.46, 1.04, 0.74))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.46, 1.04, 0.74))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.50, 0.96))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.58, 1.28))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.68, 1.58))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.24, 0.30), Vector3.new(0, 0.04, 0.30), C_HORN_ICE, C_EMBER, 0.52, "NightmareMoonTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.38, 0), "NightmareShadowVFX", { C_HORN_ICE, C_CHARCOAL, C_EMBER }, 10, 0.32)
	end

	return session
end

return ObsidianNightmare
