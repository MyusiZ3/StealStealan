--!strict
-- JadeKirinSteed.luau
-- Ref 1: Emerald-Jade & Sapphire Armored Qilin/Kirin Steed with Twin Curved Horns,
-- Silver Cloud Saddle, Chest Bell Tassel, Flowing Silver Mane & Spiked Greaves.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_JADE = Color3.fromRGB(32, 174, 110)
local C_JADE_LIGHT = Color3.fromRGB(68, 214, 148)
local C_SAPPHIRE = Color3.fromRGB(22, 88, 152)
local C_SILVER = Color3.fromRGB(226, 236, 248)
local C_SILVER_SHADE = Color3.fromRGB(162, 178, 202)
local C_HORN_DARK = Color3.fromRGB(24, 52, 42)
local C_GOLD = Color3.fromRGB(214, 162, 68)
local C_SADDLE_DARK = Color3.fromRGB(92, 54, 34)
local C_CRIMSON = Color3.fromRGB(226, 52, 44)
local C_EYE_GOLD = Color3.fromRGB(255, 224, 68)
local C_HOOF = Color3.fromRGB(174, 146, 98)

local JadeKirinSteed = {
	Id = "JadeKirinSteed",
	DisplayName = "Jade Kirin Steed",
	Archetype = "QuadrupedBeast" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(46, 214, 156),
}

function JadeKirinSteed.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.36, 1.28, 2.24), C_JADE)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0.00, -0.44 }, sz = { 1.12, 0.96, 1.10 }, c = C_JADE, tint = "primary" },
		{ p = { 0, -0.01, 0.48 }, sz = { 1.06, 0.90, 1.08 }, c = C_SAPPHIRE, tint = "primary" },
		{ p = { 0, -0.25, -0.36 }, sz = { 0.86, 0.40, 0.92 }, c = C_JADE_LIGHT, tint = "secondary" },
		-- Silver cloud breastplate armor + crimson shoulder tassels
		{ p = { 0, 0.04, -1.04 }, sz = { 0.92, 0.68, 0.24 }, c = C_SILVER, tint = "secondary" },
		{ p = { 0, 0.20, -1.16 }, sz = { 0.64, 0.34, 0.14 }, c = C_SILVER_SHADE, tint = "secondary" },
		{ p = { -0.48, -0.10, -1.06 }, sz = { 0.18, 0.34, 0.18 }, c = C_CRIMSON, r = { 0, 0, -10 }, tint = "keep" },
		{ p = { 0.48, -0.10, -1.06 }, sz = { 0.18, 0.34, 0.18 }, c = C_CRIMSON, r = { 0, 0, 10 }, tint = "keep" },
		-- Ornate saddle with cloud silver trim & gold-trimmed seat
		{ p = { 0, 0.42, 0.12 }, sz = { 1.18, 0.22, 0.98 }, c = C_SILVER, tint = "secondary" },
		{ p = { 0, 0.54, 0.12 }, sz = { 0.88, 0.14, 0.72 }, c = C_SADDLE_DARK, tint = "keep" },
		{ p = { 0, 0.62, 0.40 }, sz = { 0.66, 0.18, 0.20 }, c = C_GOLD, r = { 18, 0, 0 }, tint = "keep" },
		-- Swept silver-white cloud feathers rising over rump
		{ p = { 0, 0.62, 0.66 }, sz = { 0.34, 0.62, 0.36 }, c = C_SILVER, r = { 34, 0, 0 }, tint = "secondary" },
		{ p = { -0.34, 0.54, 0.62 }, sz = { 0.24, 0.52, 0.28 }, c = C_SILVER_SHADE, r = { 30, 0, -16 }, tint = "secondary" },
		{ p = { 0.34, 0.54, 0.62 }, sz = { 0.24, 0.52, 0.28 }, c = C_SILVER_SHADE, r = { 30, 0, 16 }, tint = "secondary" },
	}

	local bowVoxels: { VoxelSpec } = {
		{ p = { 0, 0.02, 0 }, sz = { 0.22, 0.22, 0.22 }, c = C_SILVER, m = Enum.Material.Metal, tint = "secondary" },
		{ p = { 0, -0.22, -0.02 }, sz = { 0.20, 0.32, 0.20 }, c = C_CRIMSON, tint = "keep" },
		{ p = { 0, -0.40, -0.02 }, sz = { 0.26, 0.12, 0.26 }, c = C_CRIMSON, tint = "keep" },
	}

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.10, 0.00 }, sz = { 0.68, 0.88, 0.74 }, c = C_JADE, tint = "primary" },
		{ p = { 0, 0.58, -0.10 }, sz = { 0.44, 0.38, 0.44 }, c = C_JADE, tint = "primary" }, -- recessed upper neck socket strictly inside Head
		{ p = { 0, 0.08, -0.32 }, sz = { 0.52, 0.80, 0.22 }, c = C_JADE_LIGHT, tint = "secondary" },
	}
	for i = 0, 3 do
		table.insert(neckVoxels, {
			p = { 0, -0.12 + i * 0.24, 0.42 },
			sz = { 0.26, 0.48, 0.36 },
			c = if i % 2 == 0 then C_SILVER else C_SILVER_SHADE,
			r = { 28 + i * 4, 0, 0 },
			tint = "secondary",
		})
	end

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, 0.02 }, sz = { 0.78, 0.66, 0.86 }, c = C_JADE, tint = "primary" },
		{ p = { 0, -0.06, -0.58 }, sz = { 0.50, 0.44, 0.54 }, c = C_JADE, tint = "primary" },
		{ p = { 0, -0.24, -0.56 }, sz = { 0.42, 0.14, 0.46 }, c = C_JADE_LIGHT, tint = "secondary" },
		{ p = { 0, 0.24, -0.34 }, sz = { 0.60, 0.28, 0.54 }, c = C_SILVER, tint = "secondary" },
		{ p = { 0, 0.16, -0.80 }, sz = { 0.18, 0.20, 0.22 }, c = C_SILVER, tint = "secondary" },
		{ p = { 0, -0.34, -0.74 }, sz = { 0.16, 0.22, 0.18 }, c = C_SILVER, r = { -22, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(headVoxels, { p = { side * 0.38, 0.08, -0.24 }, sz = { 0.10, 0.18, 0.24 }, c = C_HORN_DARK, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.40, 0.08, -0.24 }, sz = { 0.08, 0.10, 0.14 }, c = C_EYE_GOLD, tint = "keep" })
		-- Twin curved dark-jade Kirin horns anchored directly into crown
		table.insert(headVoxels, { p = { side * 0.20, 0.50, -0.02 }, sz = { 0.16, 0.46, 0.16 }, c = C_HORN_DARK, r = { -22, 0, side * 10 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.28, 0.84, 0.14 }, sz = { 0.12, 0.44, 0.12 }, c = C_HORN_DARK, r = { -38, 0, side * 14 }, tint = "keep" })
	end
	for i = 0, 3 do
		table.insert(headVoxels, {
			p = { 0, 0.44 + i * 0.10, 0.22 + i * 0.16 },
			sz = { 0.30, 0.46, 0.28 },
			c = if i % 2 == 0 then C_SILVER else C_SILVER_SHADE,
			r = { 26 + i * 6, 0, 0 },
			tint = "secondary",
		})
	end

	local function makeKirinEar(side: number): { VoxelSpec }
		return {
			{ p = { 0, 0.14, 0 }, sz = { 0.22, 0.36, 0.18 }, c = C_SILVER, r = { 10, 0, side * -24 }, tint = "secondary" },
			{ p = { side * 0.06, -0.04, -0.02 }, sz = { 0.09, 0.18, 0.09 }, c = C_CRIMSON, tint = "keep" },
		}
	end

	local function makeKirinLeg(isHind: boolean): { VoxelSpec }
		local upperCol = if isHind then C_SAPPHIRE else C_JADE
		return {
			{ p = { 0, 0.24, 0 }, sz = { 0.42, 0.58, 0.42 }, c = upperCol, tint = "primary" },
			{ p = { 0, -0.14, 0.02 }, sz = { 0.30, 0.48, 0.30 }, c = upperCol, tint = "primary" },
			{ p = { 0, -0.16, 0.02 }, sz = { 0.38, 0.36, 0.36 }, c = C_SILVER, tint = "secondary" },
			{ p = { 0, -0.02, 0.18 }, sz = { 0.22, 0.32, 0.18 }, c = C_SILVER_SHADE, r = { 26, 0, 0 }, tint = "secondary" },
			{ p = { 0, -0.49, -0.02 }, sz = { 0.34, 0.26, 0.38 }, c = C_HOOF, m = Enum.Material.Metal, tint = "keep" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.22 }, sz = { 0.30, 0.28, 0.52 }, c = C_SAPPHIRE, r = { -16, 0, 0 }, tint = "primary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0.22 }, sz = { 0.36, 0.36, 0.56 }, c = C_SILVER_SHADE, r = { -6, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.24, 0.30 }, sz = { 0.24, 0.44, 0.34 }, c = C_SILVER, r = { 24, 0, 0 }, tint = "secondary" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.08, 0.28 }, sz = { 0.40, 0.48, 0.64 }, c = C_SILVER, r = { 18, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.26, 0.54 }, sz = { 0.26, 0.36, 0.44 }, c = C_SILVER_SHADE, r = { 34, 0, 0 }, tint = "secondary" },
		{ p = { -0.18, 0.12, 0.36 }, sz = { 0.18, 0.34, 0.40 }, c = C_SILVER, r = { 14, -22, 0 }, tint = "secondary" },
		{ p = { 0.18, 0.12, 0.36 }, sz = { 0.18, 0.34, 0.40 }, c = C_SILVER, r = { 14, 22, 0 }, tint = "secondary" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.36, 0), torsoVoxels)
	local bow = session:AddBone("BowRibbon", Vector3.new(0, 1.12, -1.16), bowVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.88, -0.84), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.66, -1.08), headVoxels)
	local earL = session:AddBone("EarL", Vector3.new(-0.38, 2.94, -0.84), makeKirinEar(-1))
	local earR = session:AddBone("EarR", Vector3.new(0.38, 2.94, -0.84), makeKirinEar(1))

	local legFL = session:AddBone("LegFL", Vector3.new(-0.46, 0.62, -0.70), makeKirinLeg(false))
	local legFR = session:AddBone("LegFR", Vector3.new(0.46, 0.62, -0.70), makeKirinLeg(false))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.48, 0.62, 0.72), makeKirinLeg(true))
	local legBR = session:AddBone("LegBR", Vector3.new(0.48, 0.62, 0.72), makeKirinLeg(true))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.40, 1.02), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 1.32, 1.44), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 1.30, 1.88), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.36, 0))
		session:AttachMotor("BowJoint", torso, bow, Vector3.new(0, 1.24, -1.10))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.64, -0.78))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.46, -0.98))
		session:AttachMotor("EarLJoint", head, earL, Vector3.new(-0.34, 2.86, -0.84))
		session:AttachMotor("EarRJoint", head, earR, Vector3.new(0.34, 2.86, -0.84))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.46, 1.02, -0.70))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.46, 1.02, -0.70))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.48, 1.02, 0.72))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.48, 1.02, 0.72))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.40, 0.98))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 1.32, 1.40))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 1.30, 1.84))

		VFXPresets.AttachTailTrail(tail3, s, Vector3.new(0, 0.32, 0.56), Vector3.new(0, 0.04, 0.56), C_JADE_LIGHT, C_SILVER, 0.55, "JadeKirinTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.42, 0), "JadeKirinMistVFX", { C_JADE_LIGHT, C_SILVER, C_EYE_GOLD }, 11, 0.34)
	end

	return session
end

return JadeKirinSteed
