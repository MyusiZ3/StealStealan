--!strict
-- AstralStarDragon.luau (Promoted Voxel; legacy alias: AzureFlameMechaBeast)
-- Candidate #2: White-Silver Angular Mecha Dragon-Wolf with Electric-Blue Plasma Wing Flames,
-- Diamond Shoulder Cores, Forearm Arm-Blades & Segmented Scorpion-Whip Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_WHITE = Color3.fromRGB(238, 244, 254)
local C_SILVER = Color3.fromRGB(174, 192, 224)
local C_STEEL = Color3.fromRGB(58, 76, 114)
local C_PLASMA = Color3.fromRGB(28, 162, 255)
local C_CORE = Color3.fromRGB(112, 232, 255)

local AstralStarDragon = {
	Id = "AstralStarDragon",
	DisplayName = "Azure Flame Mecha",
	Archetype = "WingedDrake" :: RigCore.ArchetypeId,
	VisualStyle = "Voxel" :: "Voxel",
	Aliases = { "AzureFlameMechaBeast" },
	DefaultScale = 1.30,
	AccentColor = C_PLASMA,
}

function AstralStarDragon.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.36, 1.18, 2.24), C_WHITE)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.04, -0.38 }, sz = { 1.16, 0.88, 1.16 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.08, 0.52 }, sz = { 0.94, 0.74, 1.02 }, c = C_SILVER, tint = "secondary" },
		{ p = { 0, -0.28, -0.26 }, sz = { 0.86, 0.30, 1.02 }, c = C_STEEL, tint = "keep" },
		{ p = { 0, -0.14, -0.92 }, sz = { 0.56, 0.42, 0.24 }, c = C_CORE, m = Enum.Material.Neon, tint = "keep" },
		-- Angular mecha shoulder cowls with glowing diamond reactor cores
		{ p = { -0.68, 0.28, -0.52 }, sz = { 0.32, 0.64, 0.68 }, c = C_WHITE, r = { 12, 0, 14 }, tint = "primary" },
		{ p = { 0.68, 0.28, -0.52 }, sz = { 0.32, 0.64, 0.68 }, c = C_WHITE, r = { 12, 0, -14 }, tint = "primary" },
		{ p = { -0.82, 0.28, -0.52 }, sz = { 0.12, 0.28, 0.28 }, c = C_CORE, m = Enum.Material.Neon, r = { 45, 0, 0 }, tint = "keep" },
		{ p = { 0.82, 0.28, -0.52 }, sz = { 0.12, 0.28, 0.28 }, c = C_CORE, m = Enum.Material.Neon, r = { 45, 0, 0 }, tint = "keep" },
		-- Dorsal spinal armor crests
		{ p = { 0, 0.58, -0.34 }, sz = { 0.26, 0.36, 0.48 }, c = C_WHITE, r = { -26, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.52, 0.26 }, sz = { 0.22, 0.30, 0.44 }, c = C_SILVER, r = { -26, 0, 0 }, tint = "secondary" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.04, -0.14 }, sz = { 0.72, 0.64, 0.74 }, c = C_STEEL, tint = "keep" },
		{ p = { 0, 0.20, -0.16 }, sz = { 0.80, 0.42, 0.66 }, c = C_WHITE, tint = "primary" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, -0.04 }, sz = { 0.78, 0.56, 0.86 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, -0.02, -0.62 }, sz = { 0.48, 0.36, 0.62 }, c = C_WHITE, r = { 10, 0, 0 }, tint = "primary" },
		{ p = { 0, -0.18, -0.48 }, sz = { 0.40, 0.18, 0.58 }, c = C_PLASMA, m = Enum.Material.Neon, tint = "keep" },
		{ p = { 0, 0.34, 0.18 }, sz = { 0.26, 0.34, 0.76 }, c = C_SILVER, r = { 24, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.38, 0.08, -0.32 }, sz = { 0.10, 0.12, 0.34 }, c = C_CORE, m = Enum.Material.Neon, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.34, 0.36, 0.24 }, sz = { 0.14, 0.18, 0.74 }, c = C_WHITE, r = { 26, side * -14, 0 }, tint = "primary" })
	end

	local function makePlasmaWing(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.26, 0.24, 0.12 }, sz = { 0.48, 0.38, 0.64 }, c = C_PLASMA, m = Enum.Material.Neon, r = { 22, 0, side * -28 }, tint = "keep" },
			{ p = { side * 0.52, 0.54, 0.38 }, sz = { 0.64, 0.26, 0.88 }, c = C_CORE, m = Enum.Material.Neon, r = { 28, side * -12, side * -34 }, tint = "keep" },
		}
	end
	local function makePlasmaWingTip(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.36, 0.32, 0.34 }, sz = { 0.68, 0.18, 0.94 }, c = C_PLASMA, m = Enum.Material.Neon, r = { 24, side * -16, side * -24 }, tint = "keep" },
			{ p = { side * 0.68, 0.56, 0.66 }, sz = { 0.48, 0.12, 0.72 }, c = C_CORE, m = Enum.Material.Neon, r = { 30, side * -20, side * -28 }, tint = "keep" },
		}
	end

	local function makeForeGauntlet(side: number): { VoxelSpec }
		-- Hub Y = 0.60 -> sole pad 0.60 - 0.48 - 0.12 = 0.00
		return {
			{ p = { 0, 0.22, 0 }, sz = { 0.42, 0.56, 0.44 }, c = C_STEEL, tint = "keep" },
			{ p = { 0, -0.14, -0.06 }, sz = { 0.44, 0.50, 0.46 }, c = C_WHITE, tint = "primary" },
			-- Swept mecha forearm blade + plasma flare
			{ p = { side * 0.24, 0.16, 0.18 }, sz = { 0.12, 0.78, 0.36 }, c = C_WHITE, r = { -28, 0, side * -10 }, tint = "primary" },
			{ p = { side * 0.28, 0.22, 0.38 }, sz = { 0.08, 0.52, 0.24 }, c = C_PLASMA, m = Enum.Material.Neon, r = { -32, 0, 0 }, tint = "keep" },
			-- Clawed mecha paw resting cleanly at Y = 0.00
			{ p = { 0, -0.48, -0.14 }, sz = { 0.46, 0.24, 0.52 }, c = C_SILVER, tint = "secondary" },
			{ p = { -0.14, -0.48, -0.44 }, sz = { 0.10, 0.16, 0.22 }, c = C_WHITE, tint = "primary" },
			{ p = { 0.14, -0.48, -0.44 }, sz = { 0.10, 0.16, 0.22 }, c = C_WHITE, tint = "primary" },
		}
	end

	local function makeHindLeg(): { VoxelSpec }
		return {
			{ p = { 0, 0.24, 0.04 }, sz = { 0.46, 0.56, 0.54 }, c = C_WHITE, tint = "primary" },
			{ p = { 0, -0.14, 0.10 }, sz = { 0.36, 0.46, 0.40 }, c = C_STEEL, tint = "keep" },
			{ p = { 0, -0.48, -0.06 }, sz = { 0.44, 0.24, 0.52 }, c = C_WHITE, tint = "primary" },
			{ p = { -0.12, -0.48, -0.36 }, sz = { 0.10, 0.16, 0.20 }, c = C_CORE, m = Enum.Material.Neon, tint = "keep" },
			{ p = { 0.12, -0.48, -0.36 }, sz = { 0.10, 0.16, 0.20 }, c = C_CORE, m = Enum.Material.Neon, tint = "keep" },
		}
	end

	-- Arched segmented mecha whip tail curving high over back
	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0.18, 0.28 }, sz = { 0.38, 0.38, 0.68 }, c = C_WHITE, r = { 36, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.38, 0.52 }, sz = { 0.28, 0.28, 0.36 }, c = C_PLASMA, m = Enum.Material.Neon, r = { 48, 0, 0 }, tint = "keep" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.42, 0.16 }, sz = { 0.32, 0.76, 0.34 }, c = C_SILVER, r = { -16, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.80, -0.04 }, sz = { 0.24, 0.32, 0.26 }, c = C_PLASMA, m = Enum.Material.Neon, r = { -32, 0, 0 }, tint = "keep" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.22, -0.36 }, sz = { 0.28, 0.28, 0.78 }, c = C_WHITE, r = { 18, 0, 0 }, tint = "primary" },
		{ p = { 0, 0.34, -0.92 }, sz = { 0.22, 0.34, 0.76 }, c = C_CORE, m = Enum.Material.Neon, r = { 12, 0, 0 }, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.18, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.42, -0.92), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 1.56, -1.46), headVoxels)

	local wingL = session:AddBone("WingL", Vector3.new(-0.56, 1.54, -0.42), makePlasmaWing(-1))
	local wingTipL = session:AddBone("WingTipL", Vector3.new(-1.14, 2.08, -0.02), makePlasmaWingTip(-1))
	local wingR = session:AddBone("WingR", Vector3.new(0.56, 1.54, -0.42), makePlasmaWing(1))
	local wingTipR = session:AddBone("WingTipR", Vector3.new(1.14, 2.08, -0.02), makePlasmaWingTip(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.58, 0.60, -0.66), makeForeGauntlet(-1))
	local legFR = session:AddBone("LegFR", Vector3.new(0.58, 0.60, -0.66), makeForeGauntlet(1))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.54, 0.60, 0.68), makeHindLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.54, 0.60, 0.68), makeHindLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.32, 0.98), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.72, 1.52), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 2.52, 1.42), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.18, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.34, -0.82))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 1.52, -1.26))
		session:AttachMotor("WingLJoint", torso, wingL, Vector3.new(-0.52, 1.50, -0.42))
		session:AttachMotor("WingTipLJoint", wingL, wingTipL, Vector3.new(-1.10, 2.04, -0.04))
		session:AttachMotor("WingRJoint", torso, wingR, Vector3.new(0.52, 1.50, -0.42))
		session:AttachMotor("WingTipRJoint", wingR, wingTipR, Vector3.new(1.10, 2.04, -0.04))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.58, 0.98, -0.66))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.58, 0.98, -0.66))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.54, 0.98, 0.68))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.54, 0.98, 0.68))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.32, 0.94))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.70, 1.48))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 2.48, 1.44))

		VFXPresets.AttachWingTrails(wingTipL, wingTipR, s, Vector3.new(-0.60, 0.44, 0.56), Vector3.new(0.60, 0.44, 0.56), 0.24, C_CORE, C_PLASMA, 0.48, "MechaPlasmaTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.36, -0.20), "AzurePlasmaVFX", { C_CORE, C_PLASMA, C_WHITE }, 11, 0.34)
	end

	return session
end

return AstralStarDragon
