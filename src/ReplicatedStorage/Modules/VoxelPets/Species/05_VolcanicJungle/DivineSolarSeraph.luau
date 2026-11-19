--!strict
-- DivineSolarSeraph.luau (Promoted Voxel; legacy alias: SeraphicRingDragon)
-- Candidate #3: White & Periwinkle Celestial Dragon with Giant Sacred Halo Ring,
-- Tall Top Spire Crest, 4 Crystal-Eyed Seraphic Wings, Cyan Chest Gems & Whip Spear Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_PEARL = Color3.fromRGB(242, 246, 255)
local C_PERI = Color3.fromRGB(162, 180, 236)
local C_COBALT_TRIM = Color3.fromRGB(88, 116, 208)
local C_CYAN = Color3.fromRGB(64, 224, 248)
local C_TEAL = Color3.fromRGB(78, 192, 226)

local DivineSolarSeraph = {
	Id = "DivineSolarSeraph",
	DisplayName = "Seraphic Ring Dragon",
	Archetype = "WingedDrake" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	Aliases = { "SeraphicRingDragon" },
	DefaultScale = 1.25,
	AccentColor = C_CYAN,
}

function DivineSolarSeraph.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.16, 1.40, 1.90), C_PEARL)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, -0.10 }, sz = { 0.88, 1.08, 1.18 }, c = C_PEARL, tint = "primary" },
		{ p = { 0, 0.14, -0.72 }, sz = { 0.68, 0.88, 0.24 }, c = C_TEAL, tint = "secondary" },
		-- Twin glowing cyan chest gems
		{ p = { -0.18, 0.28, -0.86 }, sz = { 0.24, 0.30, 0.12 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0.18, 0.28, -0.86 }, sz = { 0.24, 0.30, 0.12 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
		-- Sacred Dorsal Halo Ring + Top Spire Crest anchored to upper back
		{ p = { 0, 0.84, 0.44 }, sz = { 0.52, 0.60, 0.26 }, c = C_PERI, tint = "secondary" },
		{ p = { -0.58, 1.26, 0.46 }, sz = { 0.24, 1.14, 0.22 }, c = C_PERI, r = { 0, 0, 34 }, tint = "secondary" },
		{ p = { 0.58, 1.26, 0.46 }, sz = { 0.24, 1.14, 0.22 }, c = C_PERI, r = { 0, 0, -34 }, tint = "secondary" },
		{ p = { -0.54, 1.98, 0.46 }, sz = { 0.24, 1.04, 0.22 }, c = C_PEARL, r = { 0, 0, -38 }, tint = "primary" },
		{ p = { 0.54, 1.98, 0.46 }, sz = { 0.24, 1.04, 0.22 }, c = C_PEARL, r = { 0, 0, 38 }, tint = "primary" },
		{ p = { 0, 2.38, 0.46 }, sz = { 0.48, 0.56, 0.24 }, c = C_PEARL, tint = "primary" },
		{ p = { 0, 2.38, 0.32 }, sz = { 0.22, 0.30, 0.12 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0, 3.12, 0.50 }, sz = { 0.28, 1.14, 0.22 }, c = C_PEARL, r = { -10, 0, 0 }, tint = "primary" },
		{ p = { 0, 3.74, 0.62 }, sz = { 0.18, 0.62, 0.18 }, c = C_PERI, r = { -18, 0, 0 }, tint = "secondary" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.26, -0.06 }, sz = { 0.56, 0.96, 0.58 }, c = C_PEARL, tint = "primary" },
		{ p = { 0, 0.24, -0.36 }, sz = { 0.42, 0.88, 0.14 }, c = C_TEAL, tint = "secondary" },
		{ p = { 0, 0.42, 0.28 }, sz = { 0.12, 0.56, 0.22 }, c = C_CYAN, m = Enum.Material.Neon, r = { -18, 0, 0 }, tint = "keep" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.04, -0.08 }, sz = { 0.62, 0.50, 0.78 }, c = C_PEARL, tint = "primary" },
		{ p = { 0, -0.08, -0.60 }, sz = { 0.42, 0.32, 0.52 }, c = C_PEARL, r = { 12, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.24, -0.36 }, sz = { 0.22, 0.14, 0.38 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
		{ p = { -0.26, 0.34, 0.14 }, sz = { 0.14, 0.46, 0.22 }, c = C_PEARL, r = { -28, 0, 14 }, tint = "primary" },
		{ p = { 0.26, 0.34, 0.14 }, sz = { 0.14, 0.46, 0.22 }, c = C_PEARL, r = { -28, 0, -14 }, tint = "primary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.32, 0.04, -0.26 }, sz = { 0.08, 0.12, 0.22 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" })
	end

	local function makeSeraphWing(side: number): { VoxelSpec }
		return {
			-- Wing root clasp bridging upper & lower pinions directly into the sacred ring
			{ p = { side * 0.08, 0.02, 0.04 }, sz = { 0.36, 0.74, 0.22 }, c = C_PEARL, tint = "primary" },
			-- Upper crystal pylon + wing root
			{ p = { side * 0.42, 0.38, 0.04 }, sz = { 0.92, 0.34, 0.22 }, c = C_PEARL, r = { 0, 0, side * -26 }, tint = "primary" },
			{ p = { side * 0.36, 0.36, -0.08 }, sz = { 0.24, 0.20, 0.10 }, c = C_CYAN, m = Enum.Material.Neon, r = { 0, 0, side * -26 }, tint = "keep" },
			-- Lower curved seraph pinion arch
			{ p = { side * 0.50, -0.32, 0.08 }, sz = { 1.06, 0.46, 0.18 }, c = C_PERI, r = { 0, 0, side * 16 }, tint = "secondary" },
			{ p = { side * 0.72, -0.78, 0.10 }, sz = { 0.78, 0.56, 0.16 }, c = C_COBALT_TRIM, r = { 0, 0, side * 42 }, tint = "secondary" },
		}
	end
	local function makeSeraphWingTip(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.58, 0.34, 0.04 }, sz = { 1.24, 0.36, 0.16 }, c = C_PEARL, r = { 0, 0, side * -24 }, tint = "primary" },
			{ p = { side * 0.52, 0.10, 0.06 }, sz = { 1.08, 0.28, 0.14 }, c = C_PERI, r = { 0, 0, side * -12 }, tint = "secondary" },
			{ p = { side * 0.62, 0.24, -0.04 }, sz = { 0.56, 0.12, 0.08 }, c = C_CYAN, m = Enum.Material.Neon, r = { 0, 0, side * -20 }, tint = "keep" },
		}
	end

	local function makeForeClaw(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.14, -0.06, -0.20 }, sz = { 0.26, 0.36, 0.46 }, c = C_PEARL, r = { 18, 0, 0 }, tint = "primary" },
			{ p = { side * 0.16, -0.16, -0.48 }, sz = { 0.22, 0.18, 0.26 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
		}
	end

	local function makeHindTalon(): { VoxelSpec }
		-- Hub Y = 0.62 -> talon base 0.62 - 0.50 - 0.12 = 0.00
		return {
			{ p = { 0, 0.22, 0 }, sz = { 0.42, 0.56, 0.48 }, c = C_PEARL, tint = "primary" },
			{ p = { 0, -0.16, 0.03 }, sz = { 0.32, 0.46, 0.36 }, c = C_PERI, tint = "secondary" },
			{ p = { 0, -0.50, -0.08 }, sz = { 0.38, 0.24, 0.48 }, c = C_PEARL, tint = "primary" },
			{ p = { -0.12, -0.50, -0.38 }, sz = { 0.09, 0.16, 0.22 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
			{ p = { 0.12, -0.50, -0.38 }, sz = { 0.09, 0.16, 0.22 }, c = C_CYAN, m = Enum.Material.Neon, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, -0.06, 0.36 }, sz = { 0.52, 0.46, 0.86 }, c = C_PEARL, tint = "primary" },
		{ p = { 0, -0.24, 0.36 }, sz = { 0.38, 0.14, 0.80 }, c = C_TEAL, tint = "secondary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.02, 0.42 }, sz = { 0.34, 0.32, 0.94 }, c = C_PERI, tint = "secondary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.10, 0.38 }, sz = { 0.20, 0.20, 0.86 }, c = C_PEARL, r = { 12, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.22, 0.92 }, sz = { 0.26, 0.26, 0.44 }, c = C_CYAN, m = Enum.Material.Neon, r = { 16, 0, 45 }, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.24, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.88, -0.44), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.66, -0.68), headVoxels)

	local wingL = session:AddBone("WingL", Vector3.new(-0.88, 2.64, 0.46), makeSeraphWing(-1))
	local wingTipL = session:AddBone("WingTipL", Vector3.new(-1.68, 3.06, 0.46), makeSeraphWingTip(-1))
	local wingR = session:AddBone("WingR", Vector3.new(0.88, 2.64, 0.46), makeSeraphWing(1))
	local wingTipR = session:AddBone("WingTipR", Vector3.new(1.68, 3.06, 0.46), makeSeraphWingTip(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.48, 1.46, -0.58), makeForeClaw(-1))
	local legFR = session:AddBone("LegFR", Vector3.new(0.48, 1.46, -0.58), makeForeClaw(1))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.46, 0.62, 0.22), makeHindTalon())
	local legBR = session:AddBone("LegBR", Vector3.new(0.46, 0.62, 0.22), makeHindTalon())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.94, 0.62), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.88, 1.42), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 0.92, 2.28), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.24, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.72, -0.38))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.54, -0.56))
		session:AttachMotor("WingLJoint", torso, wingL, Vector3.new(-0.82, 2.60, 0.46))
		session:AttachMotor("WingTipLJoint", wingL, wingTipL, Vector3.new(-1.64, 3.02, 0.46))
		session:AttachMotor("WingRJoint", torso, wingR, Vector3.new(0.82, 2.60, 0.46))
		session:AttachMotor("WingTipRJoint", wingR, wingTipR, Vector3.new(1.64, 3.02, 0.46))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.44, 1.50, -0.50))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.44, 1.50, -0.50))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.46, 0.98, 0.22))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.46, 0.98, 0.22))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.94, 0.58))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.88, 1.38))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 0.92, 2.24))

		VFXPresets.AttachWingTrails(wingTipL, wingTipR, s, Vector3.new(-1.08, 0.46, 0.04), Vector3.new(1.08, 0.46, 0.04), 0.22, C_CYAN, C_PEARL, 0.55, "SeraphWingTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 1.60, 0.42), "SeraphHaloVFX", { C_CYAN, C_PEARL, C_PERI }, 10, 0.30)
	end

	return session
end

return DivineSolarSeraph
