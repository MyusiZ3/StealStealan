--!strict
-- FaeLaceDragon.luau
-- Reference 2: Magenta/Cobalt-Blue Lace-Winged Feather Dragon with Black Twig Antlers & White Plume Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_BLUE = Color3.fromRGB(48, 86, 224)
local C_MAGENTA = Color3.fromRGB(232, 52, 162)
local C_PINK_FLUFF = Color3.fromRGB(252, 118, 194)
local C_BLACK = Color3.fromRGB(20, 18, 26)
local C_LACE_PURP = Color3.fromRGB(142, 46, 198)
local C_RIB_INDIGO = Color3.fromRGB(64, 96, 232)
local C_WHITE = Color3.fromRGB(248, 250, 255)
local C_PLUM_MARK = Color3.fromRGB(62, 28, 72)
local C_AMBER = Color3.fromRGB(248, 192, 62)

local FaeLaceDragon = {
	Id = "FaeLaceDragon",
	DisplayName = "Fae Lacewing Dragon",
	Archetype = "WingedDrake" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(232, 52, 162),
}

function FaeLaceDragon.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.4, 1.25, 2.2), C_MAGENTA)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0, -0.58 }, sz = { 1.12, 0.94, 1.14 }, c = C_BLUE, tint = "primary" },
		{ p = { 0, 0.02, 0.42 }, sz = { 1.18, 0.96, 1.32 }, c = C_MAGENTA, tint = "primary" },
		{ p = { 0, -0.22, -0.40 }, sz = { 0.88, 0.42, 1.00 }, c = C_PINK_FLUFF, tint = "secondary" },
	}
	for _, zOff in ipairs({ -0.62, -0.18, 0.28, 0.74 }) do
		table.insert(torsoVoxels, { p = { -0.60, 0.08, zOff }, sz = { 0.10, 0.48, 0.20 }, c = C_BLACK, tint = "keep" })
		table.insert(torsoVoxels, { p = { 0.60, 0.08, zOff }, sz = { 0.10, 0.48, 0.20 }, c = C_BLACK, tint = "keep" })
		table.insert(torsoVoxels, { p = { 0, 0.50, zOff }, sz = { 0.96, 0.12, 0.18 }, c = C_BLACK, tint = "keep" })
	end
	for i = 0, 5 do
		table.insert(torsoVoxels, { p = { 0, 0.68, -0.68 + i * 0.34 }, sz = { 0.32, 0.38, 0.24 }, c = C_PINK_FLUFF, r = { 26, 0, 0 }, tint = "secondary" })
	end

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.22, 0.00 }, sz = { 0.68, 0.88, 0.68 }, c = C_BLUE, tint = "primary" },
		{ p = { 0, 0.72, -0.14 }, sz = { 0.42, 0.36, 0.42 }, c = C_BLUE, tint = "primary" }, -- recessed upper neck socket strictly inside Head
		{ p = { 0, 0.18, -0.40 }, sz = { 0.54, 0.86, 0.22 }, c = C_PINK_FLUFF, tint = "secondary" }, -- shaggy pink chest-throat mane (cleanly below jaw)
		{ p = { 0, 0.26, 0.32 }, sz = { 0.36, 0.74, 0.22 }, c = C_PINK_FLUFF, r = { 14, 0, 0 }, tint = "secondary" }, -- back neck fluff
	}
	for _, side in ipairs({ -1, 1 }) do
		for row = 1, 2 do
			table.insert(neckVoxels, { p = { side * 0.35, -0.16 + row * 0.26, -0.02 * row }, sz = { 0.06, 0.14, 0.18 }, c = C_BLACK, tint = "keep" })
		end
	end

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.06, -0.02 }, sz = { 0.76, 0.62, 0.92 }, c = C_BLACK, tint = "primary" }, -- cranium housing neck socket with generous margin
		{ p = { 0, 0.09, -0.14 }, sz = { 0.78, 0.36, 0.62 }, c = C_BLUE, tint = "primary" }, -- cobalt cheek band (non-coplanar Z)
		{ p = { 0, -0.06, -0.64 }, sz = { 0.48, 0.38, 0.54 }, c = C_BLACK, tint = "primary" }, -- tapered muzzle
		{ p = { 0, -0.22, -0.54 }, sz = { 0.44, 0.14, 0.48 }, c = C_PINK_FLUFF, tint = "secondary" }, -- soft pink lower jaw
		{ p = { 0, 0.22, -0.80 }, sz = { 0.14, 0.22, 0.14 }, c = C_BLACK, r = { -18, 0, 0 }, tint = "keep" }, -- nose hornlet
		{ p = { 0, 0.36, 0.18 }, sz = { 0.30, 0.20, 0.50 }, c = C_BLACK, r = { -16, 0, 0 }, tint = "keep" }, -- sleek swept-up crown crest
	}
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.39
		table.insert(headVoxels, { p = { x, 0.06, -0.30 }, sz = { 0.10, 0.24, 0.24 }, c = C_AMBER, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.42, 0.06, -0.30 }, sz = { 0.07, 0.16, 0.12 }, c = C_BLACK, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.40, -0.06, -0.44 }, sz = { 0.07, 0.07, 0.07 }, c = C_WHITE, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.40, -0.08, -0.30 }, sz = { 0.07, 0.07, 0.07 }, c = C_WHITE, tint = "keep" })
		-- Connected branching black twig antlers sweeping upward & backward (-rx pitches +Z upward)
		table.insert(headVoxels, { p = { side * 0.34, 0.43, 0.53 }, sz = { 0.12, 0.12, 0.82 }, c = C_BLACK, r = { -22, side * 14, 0 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.41, 0.57, 0.68 }, sz = { 0.10, 0.10, 0.50 }, c = C_BLACK, r = { -42, side * 20, 0 }, tint = "keep" })
		table.insert(headVoxels, { p = { side * 0.47, 0.49, 0.80 }, sz = { 0.09, 0.09, 0.44 }, c = C_BLACK, r = { -6, side * 32, 0 }, tint = "keep" })
	end

	local function makeRaptorLeg(): { VoxelSpec }
		return {
			{ p = { 0, 0.28, 0.02 }, sz = { 0.36, 0.48, 0.42 }, c = C_BLACK, tint = "keep" },
			{ p = { 0, -0.06, 0.04 }, sz = { 0.26, 0.46, 0.26 }, c = C_BLACK, tint = "keep" },
			{ p = { 0, -0.34, -0.08 }, sz = { 0.34, 0.20, 0.42 }, c = C_BLACK, tint = "keep" },
			{ p = { -0.10, -0.37, -0.34 }, sz = { 0.08, 0.14, 0.20 }, c = C_BLACK, tint = "keep" },
			{ p = { 0.10, -0.37, -0.34 }, sz = { 0.08, 0.14, 0.20 }, c = C_BLACK, tint = "keep" },
		}
	end

	local function makeLaceWings(side: number): ({ VoxelSpec }, { VoxelSpec })
		local inner: { VoxelSpec } = {
			{ p = { side * 0.16, 0.55, 0.04 }, sz = { 0.22, 1.32, 0.24 }, c = C_BLACK, r = { 10, 0, side * -12 }, tint = "keep" },
			{ p = { side * 0.24, 1.24, 0.18 }, sz = { 0.18, 1.10, 0.20 }, c = C_RIB_INDIGO, r = { 16, 0, side * -16 }, tint = "primary" },
			{ p = { side * 0.22, 0.72, 0.34 }, sz = { 0.12, 0.44, 0.44 }, c = C_LACE_PURP, tint = "primary" },
			{ p = { side * 0.28, 1.18, 0.46 }, sz = { 0.12, 0.48, 0.52 }, c = C_LACE_PURP, tint = "primary" },
			{ p = { side * 0.24, 0.96, 0.24 }, sz = { 0.14, 0.30, 0.30 }, c = C_MAGENTA, tint = "secondary" },
			{ p = { side * 0.22, 0.48, 0.42 }, sz = { 0.14, 0.30, 0.38 }, c = C_PINK_FLUFF, tint = "secondary" },
		}
		local outer: { VoxelSpec } = {}
		local ribConfigs = {
			{ angX = 12, angZ = -26, len = 1.72, zEnd = 0.34, yEnd = 1.48 },
			{ angX = 34, angZ = -34, len = 1.66, zEnd = 0.88, yEnd = 1.12 },
			{ angX = 54, angZ = -40, len = 1.52, zEnd = 1.24, yEnd = 0.60 },
			{ angX = 74, angZ = -44, len = 1.32, zEnd = 1.28, yEnd = 0.08 },
		}
		for idx, rc in ipairs(ribConfigs) do
			table.insert(outer, {
				p = { side * (0.28 + idx * 0.16), rc.yEnd * 0.5, rc.zEnd * 0.5 },
				sz = { 0.14, rc.len, 0.16 },
				c = C_RIB_INDIGO,
				r = { rc.angX, 0, side * rc.angZ },
				tint = "primary",
			})
			table.insert(outer, {
				p = { side * (0.36 + idx * 0.18), rc.yEnd * 0.62, rc.zEnd * 0.62 },
				sz = { 0.10, 0.36, 0.38 },
				c = C_LACE_PURP,
				r = { rc.angX, 0, side * rc.angZ },
				tint = "primary",
			})
			table.insert(outer, {
				p = { side * (0.46 + idx * 0.22), rc.yEnd, rc.zEnd },
				sz = { 0.14, 0.48, 0.54 },
				c = C_MAGENTA,
				r = { rc.angX + 8, 0, side * rc.angZ },
				tint = "secondary",
			})
			table.insert(outer, {
				p = { side * (0.50 + idx * 0.22), rc.yEnd + 0.14, rc.zEnd + 0.14 },
				sz = { 0.12, 0.26, 0.30 },
				c = C_PINK_FLUFF,
				r = { rc.angX + 12, 0, side * rc.angZ },
				tint = "secondary",
			})
		end
		return inner, outer
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.36 }, sz = { 0.90, 0.72, 0.92 }, c = C_MAGENTA, tint = "primary" },
		{ p = { 0, 0.38, 0.34 }, sz = { 0.44, 0.38, 0.72 }, c = C_PINK_FLUFF, tint = "secondary" },
		{ p = { 0, 0.18, 0.48 }, sz = { 0.96, 0.22, 0.42 }, c = C_PLUM_MARK, tint = "keep" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0.02, 0.46 }, sz = { 1.02, 0.80, 1.06 }, c = C_WHITE, tint = "secondary" },
		{ p = { 0, 0.34, 0.42 }, sz = { 0.58, 0.28, 0.80 }, c = C_PINK_FLUFF, tint = "secondary" },
		{ p = { -0.50, 0.08, 0.48 }, sz = { 0.18, 0.30, 0.30 }, c = C_PLUM_MARK, tint = "keep" },
		{ p = { 0.50, 0.08, 0.48 }, sz = { 0.18, 0.30, 0.30 }, c = C_PLUM_MARK, tint = "keep" },
	}
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0.04, 0.54 }, sz = { 1.06, 0.82, 1.18 }, c = C_WHITE, r = { 8, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.14, 1.24 }, sz = { 0.78, 0.54, 0.88 }, c = C_WHITE, r = { 14, 0, 0 }, tint = "secondary" },
		{ p = { 0, 0.22, 1.72 }, sz = { 0.42, 0.32, 0.56 }, c = C_WHITE, r = { 20, 0, 0 }, tint = "secondary" },
		{ p = { -0.56, 0.02, 0.72 }, sz = { 0.36, 0.36, 0.86 }, c = C_WHITE, r = { 8, -16, 0 }, tint = "secondary" },
		{ p = { 0.56, 0.02, 0.72 }, sz = { 0.36, 0.36, 0.86 }, c = C_WHITE, r = { 8, 16, 0 }, tint = "secondary" },
		{ p = { 0, 0.38, 0.62 }, sz = { 0.30, 0.24, 0.76 }, c = C_PLUM_MARK, tint = "keep" },
		{ p = { -0.48, 0.06, 0.78 }, sz = { 0.14, 0.24, 0.26 }, c = C_PLUM_MARK, tint = "keep" },
		{ p = { 0.48, 0.06, 0.78 }, sz = { 0.14, 0.24, 0.26 }, c = C_PLUM_MARK, tint = "keep" },
	}

	local torso = session:AddBone("Torso", Vector3.new(0, 1.24, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.56, -1.04), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.66, -1.32), headVoxels)

	local wLIn, wLOut = makeLaceWings(-1)
	local wRIn, wROut = makeLaceWings(1)
	local wingL = session:AddBone("WingL", Vector3.new(-0.54, 1.62, -0.24), wLIn)
	local wingTipL = session:AddBone("WingTipL", Vector3.new(-0.78, 2.86, -0.06), wLOut)
	local wingR = session:AddBone("WingR", Vector3.new(0.54, 1.62, -0.24), wRIn)
	local wingTipR = session:AddBone("WingTipR", Vector3.new(0.78, 2.86, -0.06), wROut)

	local legFL = session:AddBone("LegFL", Vector3.new(-0.56, 0.44, -0.78), makeRaptorLeg())
	local legFR = session:AddBone("LegFR", Vector3.new(0.56, 0.44, -0.78), makeRaptorLeg())
	local legBL = session:AddBone("LegBL", Vector3.new(-0.60, 0.44, 0.72), makeRaptorLeg())
	local legBR = session:AddBone("LegBR", Vector3.new(0.60, 0.44, 0.72), makeRaptorLeg())

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 1.08, 1.06), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.86, 1.88), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 0.64, 2.78), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.24, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.48, -0.96))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.40, -1.18))
		session:AttachMotor("WingLJoint", torso, wingL, Vector3.new(-0.52, 1.64, -0.22))
		session:AttachMotor("WingTipLJoint", wingL, wingTipL, Vector3.new(-0.76, 2.78, -0.06))
		session:AttachMotor("WingRJoint", torso, wingR, Vector3.new(0.52, 1.64, -0.22))
		session:AttachMotor("WingTipRJoint", wingR, wingTipR, Vector3.new(0.76, 2.78, -0.06))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.56, 0.92, -0.78))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.56, 0.92, -0.78))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.60, 0.96, 0.72))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.60, 0.96, 0.72))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 1.10, 1.02))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.88, 1.82))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 0.66, 2.72))

		VFXPresets.AttachWingTrails(wingTipL, wingTipR, s, Vector3.new(-0.48, 1.2, 0.8), Vector3.new(0.48, 1.2, 0.8), 0.18, C_MAGENTA, C_BLUE, 0.60, "FaeLaceTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.4, 0.2), "FaeSporeVFX", { C_PINK_FLUFF, C_BLUE, C_WHITE }, 11, 0.34)
	end

	return session
end

return FaeLaceDragon
