--!strict
-- _TemplateSpecies.luau
-- Starter template for adding a new Voxel Pet (1 file = 1 pet).
-- Files starting with '_' are ignored by VoxelPets loader until duplicated & renamed to a SpeciesId.

local RigCore = require(script.Parent.Parent.RigCore)
local VFXPresets = require(script.Parent.Parent.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_PRIMARY = Color3.fromRGB(92, 168, 240)
local C_SECONDARY = Color3.fromRGB(240, 244, 255)
local C_EYE = Color3.fromRGB(20, 24, 34)

local TemplatePet = {
	Id = "TemplatePet",
	DisplayName = "Template Pet",
	Archetype = "QuadrupedBeast" :: RigCore.ArchetypeId, -- "WingedDrake" | "QuadrupedFeline" | "QuadrupedBeast"
	DefaultScale = 1.2,
	AccentColor = C_PRIMARY,
}

function TemplatePet.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.4, 1.1, 1.8), C_PRIMARY)

	local torso = session:AddBone("Torso", Vector3.new(0, 1.05, 0), {
		{ p = { 0, 0, 0 }, sz = { 1.32, 0.96, 1.76 }, c = C_PRIMARY, tint = "primary" },
		{ p = { 0, -0.32, 0 }, sz = { 0.96, 0.34, 1.48 }, c = C_SECONDARY, tint = "secondary" },
	})

	-- Keep upper neck socket narrower & strictly inside Head perimeter to prevent seam poking!
	local neck = session:AddBone("Neck", Vector3.new(0, 1.42, -0.82), {
		{ p = { 0, 0.14, 0 }, sz = { 0.64, 0.64, 0.64 }, c = C_PRIMARY, tint = "primary" },
		{ p = { 0, 0.42, -0.06 }, sz = { 0.44, 0.32, 0.44 }, c = C_PRIMARY, tint = "primary" },
	})

	local head = session:AddBone("Head", Vector3.new(0, 2.08, -1.04), {
		{ p = { 0, 0.04, -0.04 }, sz = { 0.96, 0.78, 0.92 }, c = C_PRIMARY, tint = "primary" },
		{ p = { 0, -0.12, -0.56 }, sz = { 0.56, 0.36, 0.38 }, c = C_SECONDARY, tint = "secondary" },
		{ p = { -0.49, 0.08, -0.26 }, sz = { 0.08, 0.22, 0.22 }, c = C_EYE, tint = "keep" },
		{ p = { 0.49, 0.08, -0.26 }, sz = { 0.08, 0.22, 0.22 }, c = C_EYE, tint = "keep" },
	})

	local function legVoxels(): { VoxelSpec }
		return {
			{ p = { 0, 0.08, 0 }, sz = { 0.36, 0.52, 0.36 }, c = C_PRIMARY, tint = "primary" },
			{ p = { 0, -0.18, -0.04 }, sz = { 0.40, 0.18, 0.42 }, c = C_SECONDARY, tint = "secondary" }, -- sole rests at Y = 0 when hubY = 0.27
		}
	end

	local legFL = session:AddBone("LegFL", Vector3.new(-0.48, 0.27, -0.58), legVoxels())
	local legFR = session:AddBone("LegFR", Vector3.new(0.48, 0.27, -0.58), legVoxels())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.50, 0.27, 0.58), legVoxels())
	local legBR = session:AddBone("LegBR", Vector3.new(0.50, 0.27, 0.58), legVoxels())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.02, 0.92), {
		{ p = { 0, 0.08, 0.28 }, sz = { 0.38, 0.38, 0.72 }, c = C_SECONDARY, r = { 16, 0, 0 }, tint = "secondary" },
	})

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.05, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.32, -0.78))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 1.88, -0.94))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.48, 0.68, -0.58))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.48, 0.68, -0.58))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.50, 0.68, 0.58))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.50, 0.68, 0.58))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.02, 0.86))
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.3, 0), "TemplateAuraVFX", { C_PRIMARY, C_SECONDARY }, 6, 0.26)
	end

	return session
end

return TemplatePet
