--!strict
-- SylphPlumeDrake.luau
-- Reference 1: Teal-crested Purple/Pink Striped Dragon with Ivory Throat & Plume Tail.

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

type VoxelSpec = RigCore.VoxelSpec

local C_PLUM = Color3.fromRGB(78, 40, 132)
local C_ORCHID = Color3.fromRGB(152, 78, 192)
local C_BLACK = Color3.fromRGB(22, 16, 34)
local C_CREAM = Color3.fromRGB(244, 236, 220)
local C_TEAL = Color3.fromRGB(24, 174, 166)
local C_TEAL_HI = Color3.fromRGB(64, 224, 208)
local C_COPPER = Color3.fromRGB(204, 122, 58)
local C_PINK = Color3.fromRGB(246, 174, 212)
local C_WING_LAV = Color3.fromRGB(182, 118, 212)
local C_WING_PINK = Color3.fromRGB(248, 206, 228)
local C_SPOT = Color3.fromRGB(72, 238, 232)
local C_WHITE = Color3.fromRGB(252, 252, 255)

local SylphPlumeDrake = {
	Id = "SylphPlumeDrake",
	DisplayName = "Sylph Plume Drake",
	Archetype = "WingedDrake" :: RigCore.ArchetypeId,
	DefaultScale = 1.35,
	AccentColor = Color3.fromRGB(162, 92, 216),
}

function SylphPlumeDrake.Build(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
	local session = RigCore.CreateSession(model, s, ctx, isStatic, Vector3.new(1.5, 1.05, 1.9), C_PLUM)

	local torsoVoxels: { VoxelSpec } = {
		{ p = { 0, 0, 0 }, sz = { 1.48, 1.05, 1.92 }, c = C_PLUM, tint = "primary" },
		{ p = { 0, 0.34, 0.05 }, sz = { 1.18, 0.44, 1.72 }, c = C_ORCHID, tint = "primary" },
		{ p = { 0, -0.14, -0.52 }, sz = { 1.04, 0.78, 0.96 }, c = C_CREAM, tint = "secondary" },
		{ p = { 0, -0.44, 0.08 }, sz = { 0.94, 0.24, 1.56 }, c = C_CREAM, tint = "secondary" },
	}
	for _, zOff in ipairs({ -0.55, -0.12, 0.32, 0.72 }) do
		table.insert(torsoVoxels, { p = { 0, 0.56, zOff }, sz = { 1.24, 0.12, 0.14 }, c = C_BLACK, tint = "keep" })
		table.insert(torsoVoxels, { p = { -0.74, 0.12, zOff }, sz = { 0.08, 0.58, 0.12 }, c = C_BLACK, tint = "keep" })
		table.insert(torsoVoxels, { p = { 0.74, 0.12, zOff }, sz = { 0.08, 0.58, 0.12 }, c = C_BLACK, tint = "keep" })
	end
	for i = 0, 4 do
		local zOff = -0.35 + i * 0.30
		local h = 0.52 + (i % 2) * 0.14
		table.insert(torsoVoxels, { p = { 0, 0.76, zOff }, sz = { 0.18, h, 0.22 }, c = C_TEAL, r = { 28, 0, 0 }, tint = "secondary" })
		table.insert(torsoVoxels, { p = { 0, 0.94, zOff + 0.12 }, sz = { 0.14, 0.34, 0.16 }, c = C_TEAL_HI, r = { 38, 0, 0 }, tint = "secondary" })
	end

	local neckVoxels: { VoxelSpec } = {
		{ p = { 0, 0.14, -0.02 }, sz = { 0.86, 0.80, 0.86 }, c = C_PLUM, tint = "primary" },
		{ p = { 0, 0.52, -0.20 }, sz = { 0.56, 0.44, 0.56 }, c = C_ORCHID, tint = "primary" }, -- recessed upper neck socket inside Head
		{ p = { 0, 0.14, -0.42 }, sz = { 0.62, 0.78, 0.22 }, c = C_CREAM, tint = "secondary" }, -- cream throat front (below jaw)
	}
	for i = 1, 3 do
		if i <= 2 then
			table.insert(neckVoxels, { p = { -0.42, 0.04 + i * 0.20, -0.06 * i }, sz = { 0.08, 0.10, 0.50 }, c = C_BLACK, tint = "keep" })
			table.insert(neckVoxels, { p = { 0.42, 0.04 + i * 0.20, -0.06 * i }, sz = { 0.08, 0.10, 0.50 }, c = C_BLACK, tint = "keep" })
		end
		table.insert(neckVoxels, { p = { 0, 0.10 + i * 0.22, 0.38 - 0.06 * i }, sz = { 0.16, 0.38, 0.20 }, c = C_TEAL, r = { 35, 0, 0 }, tint = "secondary" })
	end

	local headVoxels: { VoxelSpec } = {
		{ p = { 0, 0.08, -0.06 }, sz = { 0.96, 0.82, 0.96 }, c = C_BLACK, tint = "primary" },
		{ p = { 0, 0.22, 0.12 }, sz = { 0.92, 0.60, 0.74 }, c = C_PLUM, tint = "primary" },
		{ p = { 0, -0.08, -0.68 }, sz = { 0.56, 0.44, 0.56 }, c = C_BLACK, tint = "primary" },
		{ p = { 0, -0.26, -0.58 }, sz = { 0.44, 0.16, 0.46 }, c = C_CREAM, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.46
		table.insert(headVoxels, { p = { x * 0.96, 0.08, -0.34 }, sz = { 0.12, 0.38, 0.42 }, c = C_PINK, tint = "keep" })
		table.insert(headVoxels, { p = { x * 1.03, 0.09, -0.34 }, sz = { 0.10, 0.30, 0.34 }, c = C_BLACK, tint = "keep" })
		table.insert(headVoxels, { p = { x * 1.08, 0.16, -0.40 }, sz = { 0.08, 0.11, 0.11 }, c = C_WHITE, tint = "keep" })
	end
	for i = 0, 5 do
		local fy = 0.48 + i * 0.07
		local fz = -0.32 + i * 0.18
		local ang = 28 + i * 8
		table.insert(headVoxels, { p = { 0, fy, fz }, sz = { 0.24, 0.54, 0.24 }, c = if i % 2 == 0 then C_TEAL else C_TEAL_HI, r = { ang, 0, 0 }, tint = "secondary" })
		table.insert(headVoxels, { p = { -0.22, fy - 0.06, fz + 0.04 }, sz = { 0.14, 0.44, 0.18 }, c = C_TEAL, r = { ang + 5, 0, 12 }, tint = "secondary" })
		table.insert(headVoxels, { p = { 0.22, fy - 0.06, fz + 0.04 }, sz = { 0.14, 0.44, 0.18 }, c = C_TEAL, r = { ang + 5, 0, -12 }, tint = "secondary" })
	end
	for _, side in ipairs({ -1, 1 }) do
		for seg = 1, 5 do
			table.insert(headVoxels, {
				p = { side * (0.26 + seg * 0.05), 0.44 + math.sin(seg * 0.45) * 0.22, 0.16 + seg * 0.22 },
				sz = { 0.16, 0.16, 0.24 },
				c = C_COPPER,
				m = Enum.Material.Metal,
				r = { -16 + seg * 7, side * 8, seg * 25 },
				tint = "keep",
			})
		end
	end

	local function makeWingClusters(side: number): ({ VoxelSpec }, { VoxelSpec })
		local inner: { VoxelSpec } = {
			{ p = { side * 0.42, 0.06, 0 }, sz = { 0.88, 0.22, 0.82 }, c = C_WING_LAV, tint = "primary" },
			{ p = { side * 0.45, -0.02, 0.44 }, sz = { 0.84, 0.16, 0.16 }, c = C_BLACK, tint = "keep" },
			{ p = { side * 0.34, 0.18, -0.26 }, sz = { 0.26, 0.18, 0.26 }, c = C_WING_PINK, tint = "secondary" },
			{ p = { side * 0.34, 0.24, -0.26 }, sz = { 0.12, 0.10, 0.12 }, c = C_PINK, tint = "keep" },
			{ p = { side * 0.48, 0.16, -0.04 }, sz = { 0.44, 0.12, 0.24 }, c = C_PINK, r = { 0, side * -18, 0 }, tint = "secondary" },
			{ p = { side * 0.36, 0.16, 0.14 }, sz = { 0.42, 0.12, 0.24 }, c = C_WING_PINK, r = { 0, side * -38, 0 }, tint = "secondary" },
			{ p = { side * 0.22, 0.16, 0.28 }, sz = { 0.38, 0.12, 0.22 }, c = C_PINK, r = { 0, side * -56, 0 }, tint = "secondary" },
			{ p = { side * 0.62, 0.12, 0.18 }, sz = { 0.18, 0.16, 0.18 }, c = C_SPOT, tint = "keep" },
		}
		local outer: { VoxelSpec } = {
			{ p = { side * 0.42, 0.02, 0.06 }, sz = { 0.88, 0.18, 0.92 }, c = C_ORCHID, tint = "primary" },
			{ p = { side * 0.92, 0.04, 0.12 }, sz = { 0.34, 0.16, 0.68 }, c = C_PLUM, tint = "primary" },
			{ p = { side * 0.96, 0.02, -0.34 }, sz = { 0.44, 0.16, 0.22 }, c = C_PINK, tint = "secondary" },
			{ p = { side * 0.56, -0.015, 0.54 }, sz = { 0.84, 0.14, 0.14 }, c = C_BLACK, tint = "keep" },
			{ p = { side * 0.44, 0.12, 0.22 }, sz = { 0.16, 0.08, 0.16 }, c = C_SPOT, tint = "keep" },
			{ p = { side * 0.70, 0.12, 0.08 }, sz = { 0.18, 0.08, 0.18 }, c = C_SPOT, tint = "keep" },
			{ p = { side * 0.84, 0.12, 0.30 }, sz = { 0.14, 0.08, 0.14 }, c = C_SPOT, tint = "keep" },
		}
		return inner, outer
	end

	local function makeLegVoxels(isFront: boolean): { VoxelSpec }
		return {
			{ p = { 0, 0.04, 0 }, sz = { 0.38, 0.52, 0.38 }, c = C_PLUM, tint = "primary" },
			{ p = { 0, -0.14, -0.06 }, sz = { 0.42, 0.24, 0.46 }, c = C_BLACK, tint = "primary" },
			{ p = { 0, if isFront then 0.26 else 0.28, 0 }, sz = { 0.44, 0.28, 0.44 }, c = C_ORCHID, tint = "primary" },
		}
	end

	local tail1Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.34 }, sz = { 0.86, 0.68, 0.86 }, c = C_PLUM, tint = "primary" },
		{ p = { 0, -0.26, 0.34 }, sz = { 0.64, 0.18, 0.78 }, c = C_CREAM, tint = "secondary" },
		{ p = { 0, 0.36, 0.24 }, sz = { 0.74, 0.10, 0.14 }, c = C_BLACK, tint = "keep" },
		{ p = { -0.54, 0.08, 0.46 }, sz = { 0.46, 0.16, 0.26 }, c = C_TEAL, r = { 0, -28, -10 }, tint = "secondary" },
		{ p = { 0.54, 0.08, 0.46 }, sz = { 0.46, 0.16, 0.26 }, c = C_TEAL, r = { 0, 28, 10 }, tint = "secondary" },
		{ p = { 0, 0.52, 0.44 }, sz = { 0.18, 0.48, 0.22 }, c = C_TEAL_HI, r = { 34, 0, 0 }, tint = "secondary" },
	}
	local tail2Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.38 }, sz = { 0.60, 0.48, 0.88 }, c = C_ORCHID, tint = "primary" },
		{ p = { 0, 0.26, 0.28 }, sz = { 0.50, 0.10, 0.12 }, c = C_BLACK, tint = "keep" },
		{ p = { 0, 0.42, 0.52 }, sz = { 0.16, 0.46, 0.22 }, c = C_TEAL, r = { 42, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(tail2Voxels, { p = { side * 0.48, 0.04, 0.24 }, sz = { 0.54, 0.15, 0.24 }, c = C_TEAL, r = { 0, side * 32, 0 }, tint = "secondary" })
		table.insert(tail2Voxels, { p = { side * 0.54, 0.04, 0.56 }, sz = { 0.62, 0.15, 0.24 }, c = C_TEAL_HI, r = { 0, side * 38, 0 }, tint = "secondary" })
	end
	local tail3Voxels: { VoxelSpec } = {
		{ p = { 0, 0, 0.42 }, sz = { 0.36, 0.30, 0.92 }, c = C_PLUM, tint = "primary" },
		{ p = { 0, 0.16, 0.88 }, sz = { 0.20, 0.18, 0.68 }, c = C_TEAL_HI, r = { 12, 0, 0 }, tint = "secondary" },
	}
	for _, side in ipairs({ -1, 1 }) do
		for k = 1, 3 do
			table.insert(tail3Voxels, {
				p = { side * (0.34 + k * 0.10), 0.02, 0.16 + k * 0.28 },
				sz = { 0.60 - k * 0.06, 0.14, 0.24 },
				c = if k % 2 == 1 then C_TEAL else C_TEAL_HI,
				r = { 4, side * (36 + k * 8), side * 6 },
				tint = "secondary",
			})
		end
	end

	local torso = session:AddBone("Torso", Vector3.new(0, 1.05, 0), torsoVoxels)
	local neck = session:AddBone("Neck", Vector3.new(0, 1.48, -0.92), neckVoxels)
	local head = session:AddBone("Head", Vector3.new(0, 2.38, -1.32), headVoxels)

	local wLIn, wLOut = makeWingClusters(-1)
	local wRIn, wROut = makeWingClusters(1)
	local wingL = session:AddBone("WingL", Vector3.new(-0.76, 1.38, -0.22), wLIn)
	local wingTipL = session:AddBone("WingTipL", Vector3.new(-1.60, 1.44, -0.10), wLOut)
	local wingR = session:AddBone("WingR", Vector3.new(0.76, 1.38, -0.22), wRIn)
	local wingTipR = session:AddBone("WingTipR", Vector3.new(1.60, 1.44, -0.10), wROut)

	local legFL = session:AddBone("LegFL", Vector3.new(-0.56, 0.26, -0.62), makeLegVoxels(true))
	local legFR = session:AddBone("LegFR", Vector3.new(0.56, 0.26, -0.62), makeLegVoxels(true))
	local legBL = session:AddBone("LegBL", Vector3.new(-0.58, 0.26, 0.62), makeLegVoxels(false))
	local legBR = session:AddBone("LegBR", Vector3.new(0.58, 0.26, 0.62), makeLegVoxels(false))

	local tail1 = session:AddBone("Tail1", Vector3.new(0, 0.92, 0.96), tail1Voxels)
	local tail2 = session:AddBone("Tail2", Vector3.new(0, 0.84, 1.72), tail2Voxels)
	local tail3 = session:AddBone("Tail3", Vector3.new(0, 0.78, 2.52), tail3Voxels)

	if not isStatic then
		session:AttachMotor("RootJoint", session.Root, torso, Vector3.new(0, 1.05, 0))
		session:AttachMotor("NeckJoint", torso, neck, Vector3.new(0, 1.35, -0.82))
		session:AttachMotor("HeadJoint", neck, head, Vector3.new(0, 2.15, -1.14))
		session:AttachMotor("WingLJoint", torso, wingL, Vector3.new(-0.68, 1.38, -0.22))
		session:AttachMotor("WingTipLJoint", wingL, wingTipL, Vector3.new(-1.44, 1.42, -0.14))
		session:AttachMotor("WingRJoint", torso, wingR, Vector3.new(0.68, 1.38, -0.22))
		session:AttachMotor("WingTipRJoint", wingR, wingTipR, Vector3.new(1.44, 1.42, -0.14))
		session:AttachMotor("LegFLJoint", torso, legFL, Vector3.new(-0.56, 0.62, -0.62))
		session:AttachMotor("LegFRJoint", torso, legFR, Vector3.new(0.56, 0.62, -0.62))
		session:AttachMotor("LegBLJoint", torso, legBL, Vector3.new(-0.58, 0.64, 0.62))
		session:AttachMotor("LegBRJoint", torso, legBR, Vector3.new(0.58, 0.64, 0.62))
		session:AttachMotor("Tail1Joint", torso, tail1, Vector3.new(0, 0.96, 0.92))
		session:AttachMotor("Tail2Joint", tail1, tail2, Vector3.new(0, 0.86, 1.66))
		session:AttachMotor("Tail3Joint", tail2, tail3, Vector3.new(0, 0.80, 2.46))

		VFXPresets.AttachWingTrails(wingTipL, wingTipR, s, Vector3.new(-0.95, 0, 0.1), Vector3.new(0.95, 0, 0.1), 0.12, C_TEAL_HI, C_PINK, 0.55, "FairyWingTrail")
		VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.2, 0), "SylphPollenVFX", { C_TEAL_HI, C_ORCHID, C_PINK }, 10, 0.30)
	end

	return session
end

return SylphPlumeDrake
