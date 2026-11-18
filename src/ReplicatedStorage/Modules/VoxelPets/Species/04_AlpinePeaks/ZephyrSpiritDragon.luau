--!strict
-- ZephyrSpiritDragon.luau
-- Ref 3: Ivory-White & Emerald-Maned Eastern River/Sky Dragon with Warm Belly Scutes,
-- Brown Antlers, Flowing Whiskers, and Leaf-Plumed Sinuous Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_WHITE = Color3.fromRGB(246, 248, 252)
local C_PEACH_BELLY = Color3.fromRGB(224, 182, 162)
local C_EMERALD = Color3.fromRGB(44, 174, 110)
local C_MINT = Color3.fromRGB(88, 214, 146)
local C_SNOUT_GREY = Color3.fromRGB(192, 200, 218)
local C_ANTLER_BROWN = Color3.fromRGB(148, 96, 54)
local C_ROSE_EAR = Color3.fromRGB(234, 156, 158)
local C_DARK_EYE = Color3.fromRGB(22, 34, 28)

local ZephyrSpiritDragon = {
	Id = "ZephyrSpiritDragon",
	DisplayName = "Zephyr River Dragon",
	Archetype = "EasternSerpent" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(58, 204, 136),
}

function ZephyrSpiritDragon.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.10, 1.00, 2.40), C_WHITE)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0 }, sz = { 0.94, 0.78, 2.24 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, -0.34, 0 }, sz = { 0.78, 0.24, 2.12 }, c = C_PEACH_BELLY, tint = "secondary" },
	}
	for i = 0, 5 do
		table.insert(torsoVoxels, {
			p = { 0, 0.56, -0.84 + i * 0.34 },
			sz = { 0.34, 0.44, 0.28 },
			c = if i % 2 == 0 then C_EMERALD else C_MINT,
			r = { 28, 0, 0 },
			tint = "secondary",
		})
	end

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.10, 0.00 }, sz = { 0.66, 0.72, 0.72 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.48, -0.14 }, sz = { 0.42, 0.34, 0.42 }, c = C_WHITE, tint = "primary" }, -- recessed upper neck socket strictly inside Head
		{ p = { 0, 0.02, -0.28 }, sz = { 0.50, 0.58, 0.22 }, c = C_PEACH_BELLY, tint = "secondary" },
		{ p = { 0, 0.22, 0.34 }, sz = { 0.30, 0.52, 0.24 }, c = C_EMERALD, r = { 32, 0, 0 }, tint = "secondary" },
	}

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0.00 }, sz = { 0.80, 0.64, 0.88 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, -0.04, -0.58 }, sz = { 0.54, 0.44, 0.58 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.18, -0.56 }, sz = { 0.38, 0.12, 0.46 }, c = C_SNOUT_GREY, tint = "keep" },
		{ p = { 0, 0.08, -0.86 }, sz = { 0.22, 0.14, 0.12 }, c = C_ROSE_EAR, tint = "keep" },
		{ p = { 0, -0.22, -0.53 }, sz = { 0.46, 0.14, 0.50 }, c = C_PEACH_BELLY, tint = "secondary" },
	}
	for i = 0, 2 do
		table.insert(headVoxels, {
			p = { 0, 0.44 + i * 0.06, -0.06 + i * 0.22 },
			sz = { 0.34, 0.44, 0.28 },
			c = if i % 2 == 0 then C_EMERALD else C_MINT,
			r = { 28, 0, 0 },
			tint = "secondary",
		})
	end
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.38, 0.06, -0.24 }, sz = { 0.10, 0.18, 0.24 }, c = C_EMERALD, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.40, 0.06, -0.24 }, sz = { 0.08, 0.11, 0.14 }, c = C_DARK_EYE, tint = "keep" })
		-- Swept-back brown antlers anchored into crown
		table.insert(headVoxels, { p = { side * 0.22, 0.44, 0.14 }, sz = { 0.11, 0.11, 0.70 }, c = C_ANTLER_BROWN, r = { -22, side * 12, 0 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.28, 0.56, 0.38 }, sz = { 0.09, 0.09, 0.38 }, c = C_ANTLER_BROWN, r = { -38, side * 18, 0 }, tint = "keep" })
		-- Long flowing white whiskers anchored cleanly into snout sides
		table.insert(headVoxels, { p = { side * 0.44, -0.04, -0.36 }, sz = { 0.54, 0.06, 0.06 }, c = C_WHITE, r = { 0, side * 42, side * -6 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.70, -0.08, 0.08 }, sz = { 0.06, 0.06, 0.72 }, c = C_WHITE, r = { -4, side * 16, 0 }, tint = "keep" })
	end

	local function makeDragonEar(side: number): { VoxelSpec }
		return {
			{ p = { side * 0.08, 0.12, 0.10 }, sz = { 0.20, 0.22, 0.44 }, c = C_WHITE, r = { -14, side * -26, 0 }, tint = "primary" },
			{ p = { side * 0.06, 0.12, 0.08 }, sz = { 0.12, 0.14, 0.30 }, c = C_ROSE_EAR, r = { -14, side * -26, 0 }, tint = "keep" },
		}
	end

	local function makeDragonLeg(): { VoxelSpec }
		return {
			{ p = { 0, 0.06, 0 }, sz = { 0.34, 0.62, 0.34 }, c = C_WHITE, tint = "primary" },
			{ p = { 0, -0.32, -0.06 }, sz = { 0.38, 0.20, 0.44 }, c = C_PEACH_BELLY, tint = "secondary" },
			{ p = { -0.10, -0.35, -0.30 }, sz = { 0.09, 0.14, 0.14 }, c = C_PEACH_BELLY, tint = "keep" },
			{ p = { 0.10, -0.35, -0.30 }, sz = { 0.09, 0.14, 0.14 }, c = C_PEACH_BELLY, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.38 }, sz = { 0.72, 0.60, 0.96 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, -0.26, 0.38 }, sz = { 0.56, 0.18, 0.88 }, c = C_PEACH_BELLY, tint = "secondary" },
		{ p = { 0, 0.40, 0.38 }, sz = { 0.26, 0.38, 0.58 }, c = C_EMERALD, r = { 24, 0, 0 }, tint = "secondary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.38 }, sz = { 0.50, 0.44, 0.92 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, -0.18, 0.38 }, sz = { 0.38, 0.14, 0.84 }, c = C_PEACH_BELLY, tint = "secondary" },
		{ p = { 0, 0.30, 0.40 }, sz = { 0.22, 0.32, 0.56 }, c = C_MINT, r = { 26, 0, 0 }, tint = "secondary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.34 }, sz = { 0.30, 0.26, 0.78 }, c = C_WHITE, tint = "primary" },
		{ p = { 0, 0.04, 0.92 }, sz = { 0.48, 0.28, 0.82 }, c = C_EMERALD, r = { 12, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.10, 1.38 }, sz = { 0.30, 0.20, 0.56 }, c = C_MINT, r = { 18, 0, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 0.96, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.28, -1.16), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 1.76, -1.62), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.36, 1.98, -1.30), makeDragonEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.36, 1.98, -1.30), makeDragonEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.52, 0.42, -0.78), makeDragonLeg())
	local legFR = session:AddBone("LegFR", Vector3.new(0.52, 0.42, -0.78), makeDragonLeg())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.52, 0.42, 0.78), makeDragonLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.52, 0.42, 0.78), makeDragonLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.90, 1.12), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.92, 1.96), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 0.98, 2.76), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 0.96, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.12, -1.04))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 1.62, -1.42))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.32, 1.94, -1.34))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.32, 1.94, -1.34))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.52, 0.70, -0.78))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.52, 0.70, -0.78))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.52, 0.70, 0.78))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.52, 0.70, 0.78))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.90, 1.08))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.92, 1.92))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 0.96, 2.72))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.22, 1.38), Vector3.new(0, -0.02, 1.38), C_MINT, C_WHITE, 0.62, "ZephyrRiverTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.28, 0), "ZephyrPetalVFX", { C_MINT, C_WHITE, C_PEACH_BELLY }, 10, 0.30)
	end

	return session
end

return ZephyrSpiritDragon
