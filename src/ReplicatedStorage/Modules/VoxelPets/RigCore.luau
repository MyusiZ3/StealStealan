--!strict
-- RigCore.luau
-- Core voxel builder, mutation color/material resolver, and Motor6D rig session helper.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local RigCore = {}

export type AnimMode = "Idle" | "Walk" | "Fly" | "Ride" | "StressTest"
export type ArchetypeId = "WingedDrake" | "QuadrupedFeline" | "QuadrupedBeast"

export type VoxelSpec = {
	n: string?,
	p: { number },
	sz: { number },
	c: Color3,
	m: Enum.Material?,
	r: { number }?,
	tr: number?,
	tint: string?,
	allowFloat: boolean?,
}

export type MutContext = {
	active: boolean,
	mutColor: Color3,
	mat: Enum.Material,
	transparency: number,
	mutation: Types.AnimalMutation,
}

export type RigSession = {
	Model: Model,
	Scale: number,
	Ctx: MutContext,
	IsStatic: boolean,
	Root: Part,
	BoneSet: { [string]: boolean },
	RainbowParts: { BasePart },
	AddBone: (self: RigSession, name: string, unscaledHubPos: Vector3, voxels: { VoxelSpec }) -> Part,
	AttachMotor: (self: RigSession, jointName: string, part0: BasePart, part1: BasePart, unscaledWorldPivot: Vector3) -> Motor6D?,
}

export type SpeciesModule = {
	Id: string,
	DisplayName: string,
	Archetype: ArchetypeId,
	DefaultScale: number?,
	AccentColor: Color3,
	Build: (s: number, ctx: MutContext, isStatic: boolean, model: Model) -> RigSession,
}

function RigCore.MakeMutContext(mutation: Types.AnimalMutation): MutContext
	local mutInfo = (GameConfig.MUTATIONS :: any)[mutation] or GameConfig.MUTATIONS.None
	local mat = Enum.Material.SmoothPlastic
	local tr = 0
	if mutation == "Golden" or mutation == "Silver" then
		mat = Enum.Material.Metal
	elseif mutation == "Diamond" then
		mat = Enum.Material.Glass
		tr = 0.14
	end
	return {
		active = (mutation ~= "None"),
		mutColor = mutInfo.color or Color3.new(1, 1, 1),
		mat = mat,
		transparency = tr,
		mutation = mutation,
	}
end

function RigCore.ResolveColorAndMat(rawCol: Color3, rawMat: Enum.Material?, tintKind: string?, ctx: MutContext): (Color3, Enum.Material, number)
	if not ctx.active or tintKind == "keep" then
		return rawCol, rawMat or Enum.Material.SmoothPlastic, 0
	end
	local blendAlpha = if tintKind == "secondary" then 0.50 else 0.72
	local outCol = rawCol:Lerp(ctx.mutColor, blendAlpha)
	local outMat = if rawMat == Enum.Material.Metal then Enum.Material.Metal else ctx.mat
	return outCol, outMat, ctx.transparency
end

function RigCore.MakePart(name: string, size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, tr: number, anchored: boolean, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Material = mat
	p.Transparency = tr
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = anchored
	p.Massless = not anchored
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function buildCluster(
	hubName: string,
	hubPos: Vector3,
	voxels: { VoxelSpec },
	s: number,
	ctx: MutContext,
	isStatic: boolean,
	parentModel: Model,
	rainbowParts: { BasePart }
): Part
	local hubCF = CFrame.new(hubPos * s)
	local hub = RigCore.MakePart(hubName, Vector3.new(0.18 * s, 0.18 * s, 0.18 * s), hubCF, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1, isStatic, parentModel)
	hub.CastShadow = false

	for idx, v in ipairs(voxels) do
		local col, mat, tr = RigCore.ResolveColorAndMat(v.c, v.m, v.tint, ctx)
		local finalTr = math.max(tr, v.tr or 0)
		local deg = v.r
		local rotCF = if deg then CFrame.Angles(math.rad(deg[1]), math.rad(deg[2]), math.rad(deg[3])) else CFrame.new()
		local relCF = CFrame.new(Vector3.new(v.p[1], v.p[2], v.p[3]) * s) * rotCF
		local partCF = hubCF * relCF
		local vName = v.n or (hubName .. "_V" .. tostring(idx))
		local part = RigCore.MakePart(vName, Vector3.new(v.sz[1], v.sz[2], v.sz[3]) * s, partCF, col, mat, finalTr, isStatic, parentModel)
		part:SetAttribute("BoneCluster", hubName)
		if v.allowFloat then
			part:SetAttribute("AllowFloating", true)
		end

		if ctx.mutation == "Rainbow" and v.tint ~= "keep" then
			table.insert(rainbowParts, part)
		end
		if not isStatic then
			local w = Instance.new("WeldConstraint")
			w.Part0 = hub
			w.Part1 = part
			w.Parent = hub
		end
	end
	return hub
end

local function attachMotor(jointName: string, part0: BasePart, part1: BasePart, worldPivot: Vector3): Motor6D
	local pivotCF = CFrame.new(worldPivot)
	local m = Instance.new("Motor6D")
	m.Name = jointName
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(pivotCF)
	m.C1 = part1.CFrame:ToObjectSpace(pivotCF)
	m.CurrentAngle = 0
	m.MaxVelocity = 0.25
	m:SetAttribute("BaseC0", m.C0)
	m.Parent = part0
	return m
end

function RigCore.CreateSession(
	model: Model,
	s: number,
	ctx: MutContext,
	isStatic: boolean,
	unscaledRootSize: Vector3,
	rootColor: Color3
): RigSession
	local root = RigCore.MakePart(
		"Root",
		unscaledRootSize * s,
		CFrame.new(0, unscaledRootSize.Y * 0.5 * s, 0),
		rootColor,
		Enum.Material.SmoothPlastic,
		1,
		true,
		model
	)
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -unscaledRootSize.Y * 0.5 * s, 0)
	model.PrimaryPart = root

	local boneSet: { [string]: boolean } = { Root = true }
	local rainbowParts: { BasePart } = {}

	local session: RigSession = {
		Model = model,
		Scale = s,
		Ctx = ctx,
		IsStatic = isStatic,
		Root = root,
		BoneSet = boneSet,
		RainbowParts = rainbowParts,
		AddBone = function(self: RigSession, name: string, unscaledHubPos: Vector3, voxels: { VoxelSpec }): Part
			self.BoneSet[name] = true
			return buildCluster(name, unscaledHubPos, voxels, self.Scale, self.Ctx, self.IsStatic, self.Model, self.RainbowParts)
		end,
		AttachMotor = function(self: RigSession, jointName: string, part0: BasePart, part1: BasePart, unscaledWorldPivot: Vector3): Motor6D?
			if self.IsStatic then
				return nil
			end
			return attachMotor(jointName, part0, part1, unscaledWorldPivot * self.Scale)
		end,
	}
	return session
end

return RigCore
