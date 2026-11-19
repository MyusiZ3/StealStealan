--!strict
-- SubzeroKraken.luau (Promoted Voxel; legacy alias: RunicHydroPlesiosaur)
-- Candidate #9: Sapphire Runic Hydro Plesiosaur with Glowing Cyan Circuit Markings,
-- Ornate Champagne-Gold Chest Collar, Pearl Horns w/ Water Halos & 4 Sweeping Flippers.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_SAPPHIRE = Color3.fromRGB(22, 74, 168)
local C_BELLY = Color3.fromRGB(82, 168, 236)
local C_RUNE = Color3.fromRGB(68, 240, 255)
local C_GOLD = Color3.fromRGB(198, 182, 134)
local C_PEARL = Color3.fromRGB(226, 236, 252)

local SubzeroKraken = {
	Id = "SubzeroKraken",
	DisplayName = "Runic Hydro Plesiosaur",
	Archetype = "AquaticPlesiosaur" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	Aliases = { "RunicHydroPlesiosaur" },
	DefaultScale = 1.30,
	AccentColor = C_RUNE,
}

function SubzeroKraken.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.56, 1.04, 2.36), C_SAPPHIRE)

	-- Torso hub at Y = 0.62 -> unrotated belly keel minV.Y = 0.62 - 0.46 - 0.16 = 0.00
	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0 }, sz = { 1.44, 0.86, 2.16 }, c = C_SAPPHIRE, tint = "primary" },
		{ p = { 0, -0.46, 0 }, sz = { 1.12, 0.32, 1.88 }, c = C_BELLY, tint = "secondary" },
		-- Ornate champagne-gold chest collar + glowing hydro emblem
		{ p = { 0, 0.12, -0.96 }, sz = { 1.36, 0.68, 0.34 }, c = C_GOLD, m = Enum.Material.Metal, tint = "secondary" },
		{ p = { 0, 0.08, -1.16 }, sz = { 0.42, 0.42, 0.14 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" },
		-- Glowing cyan circuit/spiral runes along flanks
		{ p = { -0.74, 0.12, -0.18 }, sz = { 0.06, 0.38, 0.38 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0.74, 0.12, -0.18 }, sz = { 0.06, 0.38, 0.38 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" },
		{ p = { -0.74, 0.16, 0.44 }, sz = { 0.06, 0.12, 0.68 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0.74, 0.16, 0.44 }, sz = { 0.06, 0.12, 0.68 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.28, -0.04 }, sz = { 0.64, 0.84, 0.64 }, c = C_SAPPHIRE, tint = "primary" },
		{ p = { 0, 0.92, -0.08 }, sz = { 0.54, 0.78, 0.54 }, c = C_SAPPHIRE, r = { 12, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.56, -0.34 }, sz = { 0.42, 1.32, 0.18 }, c = C_BELLY, r = { 6, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.58, -0.44 }, sz = { 0.10, 1.18, 0.06 }, c = C_RUNE, m = Enum.Material.Neon, r = { 6, 0, 0 }, tint = "keep" },
		-- Floating cyan water-ring encircling neck
		{ p = { 0, 0.88, -0.06 }, sz = { 0.98, 0.10, 0.98 }, c = C_RUNE, m = Enum.Material.Neon, tr = 0.28, r = { 14, 0, -10 }, allowFloat = true, tint = "keep" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, -0.06 }, sz = { 0.66, 0.48, 0.76 }, c = C_SAPPHIRE, tint = "primary" },
		{ p = { 0, -0.04, -0.56 }, sz = { 0.44, 0.30, 0.48 }, c = C_SAPPHIRE, r = { 8, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.28, -0.26 }, sz = { 0.18, 0.12, 0.32 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" },
		-- Holographic cyan monocle lens on right eye
		{ p = { -0.38, 0.08, -0.36 }, sz = { 0.06, 0.22, 0.24 }, c = C_RUNE, m = Enum.Material.Glass, tr = 0.30, tint = "keep" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.34, 0.08, -0.24 }, sz = { 0.06, 0.12, 0.20 }, c = C_RUNE, m = Enum.Material.Neon, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.24, 0.28, 0.04 }, sz = { 0.22, 0.18, 0.22 }, c = C_GOLD, m = Enum.Material.Metal, tint = "secondary" })
		table.insert(headVoxels, { p = { side * 0.30, 0.58, 0.16 }, sz = { 0.14, 0.62, 0.16 }, c = C_PEARL, r = { -22, 0, side * -14 }, tint = "keep" })
	end

	-- Floating water halos around the twin pearl horns
	local function makeHornHalo(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.08, 0.24, 0.08 }, sz = { 0.56, 0.08, 0.56 }, c = C_RUNE, m = Enum.Material.Neon, tr = 0.25, r = { -20, 0, side * -16 }, allowFloat = true, tint = "keep" },
		}
	end

	local function makeFlipper(side: number, isFront: boolean): { VoxelSpec }
		local span = if isFront then 1.18 else 0.92
		return {
			{ p = { side * 0.20, 0.04, 0 }, sz = { 0.42, 0.24, 0.48 }, c = C_GOLD, m = Enum.Material.Metal, r = { 0, side * -16, side * 14 }, tint = "secondary" },
			{ p = { side * 0.22, 0.14, 0 }, sz = { 0.18, 0.10, 0.20 }, c = C_RUNE, m = Enum.Material.Neon, r = { 0, side * -16, side * 14 }, tint = "keep" },
			{ p = { side * (0.34 + span * 0.35), -0.08, 0.14 }, sz = { span, 0.14, 0.52 }, c = C_SAPPHIRE, r = { 0, side * -22, side * 12 }, tint = "primary" },
			{ p = { side * (0.36 + span * 0.38), -0.04, 0.14 }, sz = { span * 0.72, 0.06, 0.12 }, c = C_RUNE, m = Enum.Material.Neon, r = { 0, side * -22, side * 12 }, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0.34 }, sz = { 0.74, 0.52, 0.84 }, c = C_SAPPHIRE, r = { 14, 0, 0 }, tint = "primary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.24, 0.34 }, sz = { 0.42, 0.34, 0.82 }, c = C_SAPPHIRE, r = { 32, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.46, 0.58 }, sz = { 0.22, 0.36, 0.48 }, c = C_RUNE, m = Enum.Material.Neon, r = { 42, 0, 0 }, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 0.62, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.04, -0.96), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.32, -1.08), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.30, 2.66, -0.96), makeHornHalo(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.30, 2.66, -0.96), makeHornHalo(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.66, 0.46, -0.58), makeFlipper(-1, true))
	local legFR = session:AddBone("LegFR", Vector3.new(0.66, 0.46, -0.58), makeFlipper(1, true))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.62, 0.44, 0.58), makeFlipper(-1, false))
	local legBR = session:AddBone("LegBR", Vector3.new(0.62, 0.44, 0.58), makeFlipper(1, false))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.64, 1.02), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.82, 1.72), tail2Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 0.62, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 0.92, -0.90))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.24, -1.04))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.30, 2.66, -0.96))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.30, 2.66, -0.96))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.64, 0.48, -0.58))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.64, 0.48, -0.58))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.60, 0.46, 0.58))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.60, 0.46, 0.58))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.64, 0.98))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.80, 1.68))

		VFXPresets.AttachTailTrail(tail2, s, Vector3.new(0, 0.58, 0.64), Vector3.new(0, 0.28, 0.64), C_RUNE, C_SAPPHIRE, 0.55, "HydroRuneTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.34, -0.20), "HydroBubbleVFX", { C_RUNE, C_BELLY, C_PEARL }, 9, 0.28)
	end

	return session
end

return SubzeroKraken
