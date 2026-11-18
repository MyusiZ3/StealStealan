--!strict
-- AnimArchetypes.luau
-- Shared bone hierarchy, 60 FPS procedural pose curves (Idle/Walk/Fly/Ride/StressTest),
-- and KeyframeSequence AnimSaves generator per body archetype.

local RigCore = require(script.Parent.RigCore)

export type AnimMode = RigCore.AnimMode
export type ArchetypeId = RigCore.ArchetypeId

local AnimArchetypes = {}

type BonePoseTree = {
	[string]: CFrame,
}

local BONE_PARENTS: { [string]: string } = {
	Torso = "Root",
	Neck = "Torso",
	Head = "Neck",
	EarL = "Head",
	EarR = "Head",
	BowRibbon = "Torso",
	WingL = "Torso",
	WingTipL = "WingL",
	WingR = "Torso",
	WingTipR = "WingR",
	LegFL = "Torso",
	LegFR = "Torso",
	LegBL = "Torso",
	LegBR = "Torso",
	Tail1 = "Torso",
	Tail2 = "Tail1",
	Tail3 = "Tail2",
}

local JOINT_TO_BONE: { [string]: string } = {
	RootJoint = "Torso",
	NeckJoint = "Neck",
	HeadJoint = "Head",
	EarLJoint = "EarL",
	EarRJoint = "EarR",
	BowJoint = "BowRibbon",
	WingLJoint = "WingL",
	WingTipLJoint = "WingTipL",
	WingRJoint = "WingR",
	WingTipRJoint = "WingTipR",
	LegFLJoint = "LegFL",
	LegFRJoint = "LegFR",
	LegBLJoint = "LegBL",
	LegBRJoint = "LegBR",
	Tail1Joint = "Tail1",
	Tail2Joint = "Tail2",
	Tail3Joint = "Tail3",
}

local function buildPoseHierarchy(boneSet: { [string]: boolean }, posesByBone: BonePoseTree): Pose
	local rootPose = Instance.new("Pose")
	rootPose.Name = "Root"
	rootPose.Weight = 0
	rootPose.CFrame = CFrame.new()

	local poseObjs: { [string]: Pose } = { Root = rootPose }
	for boneName in pairs(boneSet) do
		if boneName ~= "Root" then
			local p = Instance.new("Pose")
			p.Name = boneName
			p.Weight = 1
			p.CFrame = posesByBone[boneName] or CFrame.new()
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			poseObjs[boneName] = p
		end
	end

	for boneName, poseInst in pairs(poseObjs) do
		if boneName ~= "Root" then
			local parentName = BONE_PARENTS[boneName] or "Torso"
			local parentPose = poseObjs[parentName] or rootPose
			poseInst.Parent = parentPose
		end
	end
	return rootPose
end

function AnimArchetypes.SamplePoseDeltas(mode: AnimMode, u: number, s: number, archetype: ArchetypeId): { [string]: CFrame }
	local out: { [string]: CFrame } = {}
	local hasWings = (archetype == "WingedDrake")
	local isCat = (archetype == "QuadrupedFeline")
	local isBeast = (archetype == "QuadrupedBeast")
	local isSerpent = (archetype == "EasternSerpent")
	local isScorpion = (archetype == "ArachnidScorpion")
	local isPlesio = (archetype == "AquaticPlesiosaur")

	if isScorpion then
		local breath = math.sin(u)
		local sway = math.sin(u * 0.5)
		if mode == "Idle" then
			out.RootJoint = CFrame.new(0, breath * 0.03 * s, 0) * CFrame.Angles(breath * 0.02, sway * 0.05, 0)
			out.HeadJoint = CFrame.Angles(breath * 0.04, sway * 0.08, 0)
			out.WingLJoint = CFrame.Angles(0.05 + breath * 0.04, 0.10 + math.sin(u) * 0.12, 0)
			out.WingRJoint = CFrame.Angles(0.05 + breath * 0.04, -(0.10 + math.sin(u) * 0.12), 0)
			out.WingTipLJoint = CFrame.Angles(0, -math.max(0, math.sin(u * 1.5)) * 0.24, 0)
			out.WingTipRJoint = CFrame.Angles(0, math.max(0, math.sin(u * 1.5)) * 0.24, 0)
			out.Tail1Joint = CFrame.Angles(math.sin(u) * 0.07, sway * 0.08, 0)
			out.Tail2Joint = CFrame.Angles(math.sin(u - 0.6) * 0.11, sway * 0.10, 0)
			out.Tail3Joint = CFrame.Angles(math.sin(u - 1.2) * 0.15, sway * 0.12, 0)
			return out
		elseif mode == "Walk" or mode == "Ride" then
			local amp = if mode == "Ride" then 0.34 else 0.24
			local sA = math.sin(u * 2) * amp
			local sB = math.sin(u * 2 + math.pi) * amp
			out.RootJoint = CFrame.new(0, math.abs(math.sin(u * 2)) * 0.05 * s, 0) * CFrame.Angles(math.sin(u * 2) * 0.03, math.sin(u) * 0.06, math.sin(u * 2) * 0.03)
			out.HeadJoint = CFrame.Angles(-0.04, math.sin(u) * 0.08, 0)
			out.WingLJoint = CFrame.Angles(0.08, 0.14 + math.sin(u * 2) * 0.16, 0)
			out.WingRJoint = CFrame.Angles(0.08, -(0.14 - math.sin(u * 2) * 0.16), 0)
			out.WingTipLJoint = CFrame.Angles(0, -math.abs(math.sin(u * 2)) * 0.28, 0)
			out.WingTipRJoint = CFrame.Angles(0, math.abs(math.cos(u * 2)) * 0.28, 0)
			out.LegFLJoint = CFrame.Angles(sA * 0.4, sA, -math.max(0, math.cos(u * 2)) * 0.16)
			out.LegBRJoint = CFrame.Angles(sA * 0.4, -sA, math.max(0, math.cos(u * 2)) * 0.16)
			out.LegFRJoint = CFrame.Angles(sB * 0.4, -sB, math.max(0, math.cos(u * 2 + math.pi)) * 0.16)
			out.LegBLJoint = CFrame.Angles(sB * 0.4, sB, -math.max(0, math.cos(u * 2 + math.pi)) * 0.16)
			out.Tail1Joint = CFrame.Angles(-0.10 + math.sin(u * 2) * 0.10, math.sin(u) * 0.10, 0)
			out.Tail2Joint = CFrame.Angles(-0.14 + math.sin(u * 2 - 0.5) * 0.14, math.sin(u) * 0.12, 0)
			out.Tail3Joint = CFrame.Angles(-0.18 + math.sin(u * 2 - 1.0) * 0.20, 0, 0)
			return out
		elseif mode == "StressTest" then
			local s1, c1 = math.sin(u), math.cos(u)
			out.RootJoint = CFrame.new(0, s1 * 0.05 * s, 0) * CFrame.Angles(s1 * 0.06, c1 * 0.08, 0)
			out.WingLJoint = CFrame.Angles(s1 * 0.20, 0.22 + c1 * 0.26, 0)
			out.WingRJoint = CFrame.Angles(s1 * 0.20, -(0.22 + c1 * 0.26), 0)
			out.WingTipLJoint = CFrame.Angles(0, -math.abs(s1) * 0.38, 0)
			out.WingTipRJoint = CFrame.Angles(0, math.abs(s1) * 0.38, 0)
			out.LegFLJoint = CFrame.Angles(0, s1 * 0.32, c1 * 0.18)
			out.LegFRJoint = CFrame.Angles(0, -s1 * 0.32, -c1 * 0.18)
			out.LegBLJoint = CFrame.Angles(0, -s1 * 0.32, c1 * 0.18)
			out.LegBRJoint = CFrame.Angles(0, s1 * 0.32, -c1 * 0.18)
			out.Tail1Joint = CFrame.Angles(-0.22 + s1 * 0.24, c1 * 0.18, 0)
			out.Tail2Joint = CFrame.Angles(-0.26 + c1 * 0.28, s1 * 0.20, 0)
			out.Tail3Joint = CFrame.Angles(-0.30 + s1 * 0.34, 0, 0)
			return out
		else -- "Fly" (Void Levitation)
			local hover = math.sin(u) * 0.22 * s
			local strike = math.sin(u * 2)
			out.RootJoint = CFrame.new(0, (0.68 * s) + hover, 0) * CFrame.Angles(math.sin(u) * 0.08, sway * 0.10, 0)
			out.WingLJoint = CFrame.Angles(-0.12, 0.24 + strike * 0.14, -0.10)
			out.WingRJoint = CFrame.Angles(-0.12, -(0.24 + strike * 0.14), 0.10)
			out.WingTipLJoint = CFrame.Angles(0, -0.28 - strike * 0.18, 0)
			out.WingTipRJoint = CFrame.Angles(0, 0.28 + strike * 0.18, 0)
			out.LegFLJoint = CFrame.Angles(0.16, 0, -0.22 + math.sin(u) * 0.08)
			out.LegFRJoint = CFrame.Angles(0.16, 0, 0.22 - math.sin(u) * 0.08)
			out.LegBLJoint = CFrame.Angles(-0.16, 0, -0.26 - math.sin(u) * 0.08)
			out.LegBRJoint = CFrame.Angles(-0.16, 0, 0.26 + math.sin(u) * 0.08)
			out.Tail1Joint = CFrame.Angles(-0.18 + strike * 0.14, 0, 0)
			out.Tail2Joint = CFrame.Angles(-0.24 + math.sin(u * 2 - 0.6) * 0.18, 0, 0)
			out.Tail3Joint = CFrame.Angles(-0.28 + math.sin(u * 2 - 1.1) * 0.24, 0, 0)
			return out
		end
	end

	if isPlesio then
		local breath = math.sin(u)
		local sway = math.sin(u * 0.5)
		if mode == "Idle" then
			out.RootJoint = CFrame.new(0, (0.04 + breath * 0.04) * s, 0) * CFrame.Angles(breath * 0.03, sway * 0.06, math.cos(u * 0.5) * 0.03)
			out.NeckJoint = CFrame.Angles(math.sin(u - 0.5) * 0.07, sway * 0.14, 0)
			out.HeadJoint = CFrame.Angles(math.sin(u - 1.0) * 0.06, math.sin(u * 0.5 - 0.6) * 0.16, sway * 0.05)
			out.EarLJoint = CFrame.Angles(breath * 0.08, u % (math.pi * 2) * 0, math.sin(u) * 0.08)
			out.EarRJoint = CFrame.Angles(-breath * 0.08, 0, -math.sin(u) * 0.08)
			out.LegFLJoint = CFrame.Angles(math.sin(u) * 0.10, 0, -math.sin(u - 0.4) * 0.16)
			out.LegFRJoint = CFrame.Angles(math.sin(u) * 0.10, 0, math.sin(u - 0.4) * 0.16)
			out.LegBLJoint = CFrame.Angles(math.sin(u - 1.1) * 0.08, 0, -math.sin(u - 1.5) * 0.14)
			out.LegBRJoint = CFrame.Angles(math.sin(u - 1.1) * 0.08, 0, math.sin(u - 1.5) * 0.14)
			out.Tail1Joint = CFrame.Angles(math.sin(u - 0.6) * 0.08, sway * 0.20, 0)
			out.Tail2Joint = CFrame.Angles(math.sin(u - 1.2) * 0.12, math.sin(u * 0.5 - 0.8) * 0.28, 0)
			return out
		elseif mode == "Walk" or mode == "Ride" or mode == "Fly" then
			local isFlyMode = (mode == "Fly")
			local baseY = if isFlyMode then (0.74 * s + math.sin(u) * 0.24 * s) else (0.06 * s + math.abs(math.sin(u)) * 0.08 * s)
			local strokeF = math.sin(u * 1.5)
			local strokeB = math.sin(u * 1.5 - 1.2)
			local amp = if isFlyMode then 0.46 elseif mode == "Ride" then 0.40 else 0.32
			out.RootJoint = CFrame.new(0, baseY, 0) * CFrame.Angles(math.cos(u * 1.5) * 0.06, sway * 0.08, 0)
			out.NeckJoint = CFrame.Angles(-math.cos(u * 1.5) * 0.08, sway * 0.12, 0)
			out.HeadJoint = CFrame.Angles(math.sin(u * 1.5 - 0.6) * 0.07, sway * 0.14, 0)
			out.LegFLJoint = CFrame.Angles(strokeF * amp * 0.65, strokeF * 0.22, -strokeF * amp)
			out.LegFRJoint = CFrame.Angles(strokeF * amp * 0.65, -strokeF * 0.22, strokeF * amp)
			out.LegBLJoint = CFrame.Angles(strokeB * amp * 0.55, strokeB * 0.18, -strokeB * amp * 0.85)
			out.LegBRJoint = CFrame.Angles(strokeB * amp * 0.55, -strokeB * 0.18, strokeB * amp * 0.85)
			out.Tail1Joint = CFrame.Angles(math.sin(u * 1.5 - 0.8) * 0.12, math.sin(u) * 0.24, 0)
			out.Tail2Joint = CFrame.Angles(math.sin(u * 1.5 - 1.5) * 0.18, math.sin(u - 0.7) * 0.32, 0)
			return out
		else -- "StressTest"
			local s1, c1 = math.sin(u), math.cos(u)
			out.RootJoint = CFrame.new(0, s1 * 0.08 * s, 0) * CFrame.Angles(s1 * 0.08, c1 * 0.10, 0)
			out.NeckJoint = CFrame.Angles(s1 * 0.18, c1 * 0.24, 0)
			out.HeadJoint = CFrame.Angles(c1 * 0.18, s1 * 0.26, c1 * 0.10)
			out.LegFLJoint = CFrame.Angles(s1 * 0.35, c1 * 0.25, -s1 * 0.45)
			out.LegFRJoint = CFrame.Angles(s1 * 0.35, -c1 * 0.25, s1 * 0.45)
			out.LegBLJoint = CFrame.Angles(-s1 * 0.30, c1 * 0.20, c1 * 0.40)
			out.LegBRJoint = CFrame.Angles(-s1 * 0.30, -c1 * 0.20, -c1 * 0.40)
			out.Tail1Joint = CFrame.Angles(s1 * 0.22, c1 * 0.28, 0)
			out.Tail2Joint = CFrame.Angles(c1 * 0.26, s1 * 0.34, 0)
			return out
		end
	end

	if mode == "Idle" then
		local breath = math.sin(u)
		local sway = math.sin(u * 0.5)
		if isSerpent then
			local floatY = (0.10 + math.sin(u * 0.9) * 0.08) * s
			out.RootJoint = CFrame.new(math.sin(u * 0.5) * 0.06 * s, floatY, 0) * CFrame.Angles(breath * 0.04, sway * 0.14, math.cos(u * 0.5) * 0.05)
			out.NeckJoint = CFrame.Angles(math.sin(u - 0.6) * 0.06, math.sin(u * 0.5 - 0.6) * 0.18, 0)
			out.HeadJoint = CFrame.Angles(math.sin(u - 1.1) * 0.05, math.sin(u * 0.5 - 1.1) * 0.22, math.sin(u * 0.5) * 0.06)
			out.EarLJoint = CFrame.Angles(-0.08 + breath * 0.05, 0, 0.06)
			out.EarRJoint = CFrame.Angles(-0.08 + breath * 0.05, 0, -0.06)
			out.LegFLJoint = CFrame.Angles(-0.18 + math.sin(u) * 0.08, 0, 0)
			out.LegFRJoint = CFrame.Angles(-0.18 - math.sin(u) * 0.08, 0, 0)
			out.LegBLJoint = CFrame.Angles(-0.22 - math.sin(u) * 0.08, 0, 0)
			out.LegBRJoint = CFrame.Angles(-0.22 + math.sin(u) * 0.08, 0, 0)
			out.Tail1Joint = CFrame.Angles(math.sin(u * 0.9 - 0.5) * 0.08, math.sin(u * 0.8 - 0.7) * 0.24, 0)
			out.Tail2Joint = CFrame.Angles(math.sin(u * 0.9 - 1.2) * 0.11, math.sin(u * 0.8 - 1.4) * 0.32, 0)
			out.Tail3Joint = CFrame.Angles(math.sin(u * 0.9 - 1.9) * 0.14, math.sin(u * 0.8 - 2.1) * 0.38, 0)
			return out
		end

		out.RootJoint = CFrame.new(0, breath * 0.04 * s, 0) * CFrame.Angles(breath * 0.025, sway * 0.03, 0)
		out.NeckJoint = CFrame.Angles(math.sin(u - 0.5) * 0.055, sway * 0.09, 0)
		out.HeadJoint = CFrame.Angles(math.sin(u - 1.0) * 0.045, math.sin(u * 0.5 + 0.4) * 0.14, math.sin(u * 0.5) * 0.06)
		out.Tail1Joint = CFrame.Angles(math.rad(6) + breath * 0.05, math.sin(u) * 0.16, 0)
		out.Tail2Joint = CFrame.Angles(math.rad(5) + math.sin(u - 0.8) * 0.06, math.sin(u - 0.8) * 0.22, 0)
		out.Tail3Joint = CFrame.Angles(math.sin(u - 1.5) * 0.07, math.sin(u - 1.5) * 0.26, 0)
		if isCat or isBeast then
			local earTwitchL = math.pow(math.max(0, math.sin(u * 1.5)), 6) * (if isBeast then 0.18 else 0.24)
			local earTwitchR = math.pow(math.max(0, math.sin(u * 1.5 + 1.9)), 6) * (if isBeast then 0.18 else 0.24)
			out.EarLJoint = CFrame.Angles(-earTwitchL, 0, earTwitchL * 0.45)
			out.EarRJoint = CFrame.Angles(-earTwitchR, 0, -earTwitchR * 0.45)
			out.BowJoint = CFrame.Angles(math.sin(u - 0.4) * (if isBeast then 0.10 else 0.08), sway * 0.06, math.sin(u) * 0.06)
		elseif hasWings then
			local flap = math.sin(u) * 0.12
			out.WingLJoint = CFrame.Angles(0.04, -flap * 0.25, -flap)
			out.WingRJoint = CFrame.Angles(0.04, flap * 0.25, flap)
			out.WingTipLJoint = CFrame.Angles(0, 0, -math.sin(u - 0.7) * 0.14)
			out.WingTipRJoint = CFrame.Angles(0, 0, math.sin(u - 0.7) * 0.14)
		end
	elseif mode == "Walk" or mode == "Ride" then
		if isSerpent then
			local stride = math.sin(u) * (if mode == "Ride" then 0.50 else 0.36)
			local slitherYaw = math.sin(u * 0.85)
			out.RootJoint = CFrame.new(slitherYaw * 0.14 * s, math.abs(math.sin(u)) * 0.09 * s, 0) * CFrame.Angles(math.sin(u * 2) * 0.04, slitherYaw * 0.16, slitherYaw * 0.05)
			out.NeckJoint = CFrame.Angles(math.sin(u * 2 - 0.5) * 0.07, math.sin(u * 0.85 - 0.7) * 0.20, 0)
			out.HeadJoint = CFrame.Angles(-0.04, math.sin(u * 0.85 - 1.3) * 0.22, 0)
			out.EarLJoint = CFrame.Angles(-0.10, 0, 0.08)
			out.EarRJoint = CFrame.Angles(-0.10, 0, -0.08)
			out.LegFLJoint = CFrame.Angles(stride, 0, 0)
			out.LegBRJoint = CFrame.Angles(stride, 0, 0)
			out.LegFRJoint = CFrame.Angles(-stride, 0, 0)
			out.LegBLJoint = CFrame.Angles(-stride, 0, 0)
			out.Tail1Joint = CFrame.Angles(math.sin(u * 2 - 0.4) * 0.08, math.sin(u * 0.85 - 0.7) * 0.28, 0)
			out.Tail2Joint = CFrame.Angles(math.sin(u * 2 - 1.0) * 0.12, math.sin(u * 0.85 - 1.4) * 0.36, 0)
			out.Tail3Joint = CFrame.Angles(math.sin(u * 2 - 1.6) * 0.16, math.sin(u * 0.85 - 2.1) * 0.42, 0)
			return out
		end

		local strideAmp = if mode == "Ride" then 0.58 elseif isBeast then 0.48 else 0.42
		local bobAmp = if mode == "Ride" then 0.11 elseif isBeast then 0.09 else 0.07
		local liftAmp = if isBeast then 0.14 else 0.10
		local strideA = math.sin(u) * strideAmp
		local strideB = math.sin(u + math.pi) * strideAmp
		local liftA = math.max(0, math.cos(u)) * liftAmp * s
		local liftB = math.max(0, math.cos(u + math.pi)) * liftAmp * s
		local pitch = math.sin(u * 2) * 0.045
		out.RootJoint = CFrame.new(0, math.abs(math.sin(u)) * bobAmp * s, 0) * CFrame.Angles(pitch, 0, math.sin(u) * 0.03)
		out.NeckJoint = CFrame.Angles(-pitch * 0.7 + math.sin(u * 2 - 0.5) * 0.06, math.sin(u) * 0.05, 0)
		out.HeadJoint = CFrame.Angles(-pitch * 0.4, math.sin(u) * 0.06, 0)
		out.LegFLJoint = CFrame.new(0, liftA, 0) * CFrame.Angles(strideA, 0, 0)
		out.LegBRJoint = CFrame.new(0, liftA, 0) * CFrame.Angles(strideA, 0, 0)
		out.LegFRJoint = CFrame.new(0, liftB, 0) * CFrame.Angles(strideB, 0, 0)
		out.LegBLJoint = CFrame.new(0, liftB, 0) * CFrame.Angles(strideB, 0, 0)
		out.Tail1Joint = CFrame.Angles(math.rad(10), math.sin(u) * 0.24, 0)
		out.Tail2Joint = CFrame.Angles(math.rad(6), math.sin(u - 0.7) * 0.30, 0)
		out.Tail3Joint = CFrame.Angles(0, math.sin(u - 1.4) * 0.34, 0)
		if isCat or isBeast then
			out.EarLJoint = CFrame.Angles(-0.08 + math.sin(u * 2) * 0.08, 0, 0)
			out.EarRJoint = CFrame.Angles(-0.08 + math.cos(u * 2) * 0.08, 0, 0)
			out.BowJoint = CFrame.Angles(math.rad(12) + math.abs(math.sin(u)) * 0.16, 0, math.sin(u) * 0.14)
		elseif hasWings then
			local flap = math.sin(u * 2) * 0.20 + 0.12
			out.WingLJoint = CFrame.Angles(0, -0.06, -flap)
			out.WingRJoint = CFrame.Angles(0, 0.06, flap)
			out.WingTipLJoint = CFrame.Angles(0, 0, -math.sin(u * 2 - 0.6) * 0.22)
			out.WingTipRJoint = CFrame.Angles(0, 0, math.sin(u * 2 - 0.6) * 0.22)
		end
	elseif mode == "StressTest" then
		local s1 = math.sin(u)
		local c1 = math.cos(u)
		local s2 = math.sin(u * 1.5)
		out.RootJoint = CFrame.new(0, s1 * 0.05 * s, 0) * CFrame.Angles(s1 * 0.05, c1 * 0.05, s2 * 0.04)
		out.NeckJoint = CFrame.Angles(s1 * 0.14, c1 * 0.20, s2 * 0.08)
		out.HeadJoint = CFrame.Angles(c1 * 0.16, s1 * 0.26, c1 * 0.12)
		out.LegFLJoint = CFrame.Angles(s1 * 0.45, 0, 0)
		out.LegFRJoint = CFrame.Angles(-s1 * 0.45, 0, 0)
		out.LegBLJoint = CFrame.Angles(-s1 * 0.45, 0, 0)
		out.LegBRJoint = CFrame.Angles(s1 * 0.45, 0, 0)
		out.Tail1Joint = CFrame.Angles(s1 * 0.22, c1 * 0.26, 0)
		out.Tail2Joint = CFrame.Angles(c1 * 0.22, s1 * 0.30, 0)
		out.Tail3Joint = CFrame.Angles(s2 * 0.22, c1 * 0.34, 0)
		if isCat or isBeast or isSerpent then
			out.EarLJoint = CFrame.Angles(s2 * 0.24, 0, c1 * 0.16)
			out.EarRJoint = CFrame.Angles(-s2 * 0.24, 0, -c1 * 0.16)
			out.BowJoint = CFrame.Angles(s1 * 0.18, c1 * 0.14, s2 * 0.14)
		elseif hasWings then
			out.WingLJoint = CFrame.Angles(0.08, -0.08, -(0.24 + s1 * 0.52))
			out.WingRJoint = CFrame.Angles(0.08, 0.08, 0.24 + s1 * 0.52)
			out.WingTipLJoint = CFrame.Angles(0, 0, -(c1 * 0.42))
			out.WingTipRJoint = CFrame.Angles(0, 0, c1 * 0.42)
		end
	else -- "Fly"
		if isSerpent then
			local wave = math.sin(u)
			local skyYaw = math.sin(u * 0.85)
			out.RootJoint = CFrame.new(skyYaw * 0.20 * s, (0.82 * s) + wave * 0.28 * s, 0) * CFrame.Angles(math.cos(u) * 0.12, skyYaw * 0.24, skyYaw * 0.10)
			out.NeckJoint = CFrame.Angles(-math.cos(u) * 0.10, math.sin(u * 0.85 - 0.7) * 0.26, 0)
			out.HeadJoint = CFrame.Angles(0.04 + math.sin(u - 0.8) * 0.08, math.sin(u * 0.85 - 1.4) * 0.28, 0)
			out.EarLJoint = CFrame.Angles(math.rad(-18), 0, 0.12)
			out.EarRJoint = CFrame.Angles(math.rad(-18), 0, -0.12)
			out.LegFLJoint = CFrame.Angles(math.rad(-32) + wave * 0.10, 0, 0)
			out.LegFRJoint = CFrame.Angles(math.rad(-32) - wave * 0.10, 0, 0)
			out.LegBLJoint = CFrame.Angles(math.rad(-38) - wave * 0.10, 0, 0)
			out.LegBRJoint = CFrame.Angles(math.rad(-38) + wave * 0.10, 0, 0)
			out.Tail1Joint = CFrame.Angles(math.sin(u - 0.6) * 0.16, math.sin(u * 0.85 - 0.7) * 0.34, 0)
			out.Tail2Joint = CFrame.Angles(math.sin(u - 1.3) * 0.22, math.sin(u * 0.85 - 1.4) * 0.42, 0)
			out.Tail3Joint = CFrame.Angles(math.sin(u - 2.0) * 0.26, math.sin(u * 0.85 - 2.1) * 0.48, 0)
			return out
		end

		local hover = math.sin(u) * 0.26 * s
		local flap = math.sin(u * 2)
		local tipLag = math.sin(u * 2 - 0.75)
		out.RootJoint = CFrame.new(0, (0.72 * s) + hover, 0) * CFrame.Angles(math.sin(u) * 0.08, math.cos(u * 0.5) * 0.07, 0)
		out.NeckJoint = CFrame.Angles(math.rad(6) + math.sin(u * 2 - 0.4) * 0.07, 0, 0)
		out.HeadJoint = CFrame.Angles(math.rad(-4) + math.sin(u - 0.8) * 0.06, math.sin(u * 0.5) * 0.12, 0)
		if isBeast then
			-- Sky-gallop pose for Kirin & Moonhorn Steeds
			local gallopF = math.sin(u * 2) * 0.48
			local gallopB = math.sin(u * 2 + 0.9) * 0.52
			out.LegFLJoint = CFrame.Angles(math.rad(-20) + gallopF, 0, 0)
			out.LegFRJoint = CFrame.Angles(math.rad(-20) + math.sin(u * 2 + 0.4) * 0.48, 0, 0)
			out.LegBLJoint = CFrame.Angles(math.rad(14) + gallopB, 0, 0)
			out.LegBRJoint = CFrame.Angles(math.rad(14) + math.sin(u * 2 + 1.3) * 0.52, 0, 0)
		else
			out.LegFLJoint = CFrame.Angles(math.rad(-28) + flap * 0.08, 0, 0)
			out.LegFRJoint = CFrame.Angles(math.rad(-28) - flap * 0.08, 0, 0)
			out.LegBLJoint = CFrame.Angles(math.rad(-34) - flap * 0.08, 0, 0)
			out.LegBRJoint = CFrame.Angles(math.rad(-34) + flap * 0.08, 0, 0)
		end
		out.Tail1Joint = CFrame.Angles(math.sin(u * 2) * 0.14, math.sin(u) * 0.22, 0)
		out.Tail2Joint = CFrame.Angles(math.sin(u * 2 - 0.7) * 0.18, math.sin(u - 0.7) * 0.28, 0)
		out.Tail3Joint = CFrame.Angles(math.sin(u * 2 - 1.4) * 0.22, math.sin(u - 1.4) * 0.34, 0)
		if isCat or isBeast then
			out.EarLJoint = CFrame.Angles(math.rad(-14) + flap * 0.12, 0, 0.10)
			out.EarRJoint = CFrame.Angles(math.rad(-14) + flap * 0.12, 0, -0.10)
			out.BowJoint = CFrame.Angles(math.rad(18) + flap * 0.18, 0, math.sin(u) * 0.16)
		elseif hasWings then
			out.WingLJoint = CFrame.Angles(math.rad(6), -0.05, -(0.28 + flap * 0.55))
			out.WingRJoint = CFrame.Angles(math.rad(6), 0.05, 0.28 + flap * 0.55)
			out.WingTipLJoint = CFrame.Angles(0, 0, -(tipLag * 0.42))
			out.WingTipRJoint = CFrame.Angles(0, 0, tipLag * 0.42)
		end
	end
	return out
end

function AnimArchetypes.PopulateAnimSaves(model: Model, boneSet: { [string]: boolean }, s: number, archetype: ArchetypeId)
	local animSaves = Instance.new("Model")
	animSaves.Name = "AnimSaves"
	animSaves.Parent = model

	local specs: { { name: string, mode: AnimMode, dur: number, prio: Enum.AnimationPriority } } = {
		{ name = "Idle", mode = "Idle", dur = 2.0, prio = Enum.AnimationPriority.Idle },
		{ name = "Walk", mode = "Walk", dur = 1.0, prio = Enum.AnimationPriority.Movement },
		{ name = "Special", mode = "Fly", dur = 1.4, prio = Enum.AnimationPriority.Action },
	}
	for _, sp in ipairs(specs) do
		local kfs = Instance.new("KeyframeSequence")
		kfs.Name = sp.name
		kfs.Loop = true
		kfs.Priority = sp.prio
		kfs.Parent = animSaves

		local stepCount = 4
		for step = 0, stepCount do
			local frac = step / stepCount
			local deltas = AnimArchetypes.SamplePoseDeltas(sp.mode, frac * math.pi * 2, s, archetype)
			local poses: BonePoseTree = {}
			for jName, dCF in pairs(deltas) do
				local bName = JOINT_TO_BONE[jName]
				if bName then
					poses[bName] = dCF
				end
			end
			local kf = Instance.new("Keyframe")
			kf.Name = "KF_" .. tostring(step)
			kf.Time = frac * sp.dur
			buildPoseHierarchy(boneSet, poses).Parent = kf
			kf.Parent = kfs
		end
	end
end

return AnimArchetypes
