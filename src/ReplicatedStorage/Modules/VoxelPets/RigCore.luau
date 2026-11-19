--!strict
-- RigCore.luau
-- Core voxel builder, mutation color/material resolver, and Motor6D rig session helper.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.Types)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local RigCore = {}

export type AnimMode = "Idle" | "Walk" | "Fly" | "Ride" | "StressTest"
export type ArchetypeId =
	"WingedDrake"
	| "QuadrupedFeline"
	| "QuadrupedBeast"
	| "EasternSerpent"
	| "ArachnidScorpion"
	| "AquaticPlesiosaur"
	| "CataclysmColossus"

export type PartShapeKind = "Block" | "Sphere" | "Cylinder" | "Wedge" | "CornerWedge"

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
	sh: PartShapeKind?,
}

export type MeshPartSpec = {
	key: string,
	bone: string,
	parentBone: string?,
	jointName: string?,
	meshId: string,
	textureId: string,
	pos: { number },
	sz: { number },
	pivot: { number }?,
	rot: { number }?,
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
	VisualStyle: ("Voxel" | "Realistic")?,
	StagingSlot: number?,
	BaseConceptId: string?,
	Aliases: { string }?,
	DefaultScale: number?,
	CameraHeightOffset: number?,
	CameraDistMult: number?,
	BaseMeshScale: number?,
	PublishedAssetId: string?,
	MeshParts: { MeshPartSpec }?,
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
	local outMat = if rawMat == Enum.Material.Neon
		then Enum.Material.Neon
		elseif rawMat == Enum.Material.Metal then Enum.Material.Metal
		else ctx.mat
	return outCol, outMat, ctx.transparency
end

function RigCore.MakeStyledPart(
	name: string,
	size: Vector3,
	cf: CFrame,
	col: Color3,
	mat: Enum.Material,
	tr: number,
	anchored: boolean,
	shapeKind: PartShapeKind?,
	parent: Instance
): BasePart
	local p: BasePart
	if shapeKind == "Wedge" then
		p = Instance.new("WedgePart")
	elseif shapeKind == "CornerWedge" then
		p = Instance.new("CornerWedgePart")
	else
		local block = Instance.new("Part")
		if shapeKind == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif shapeKind == "Sphere" then
			block.Shape = Enum.PartType.Block
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.Sphere
			sm.Parent = block
		end
		p = block
	end
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
	if math.max(size.X, size.Y, size.Z) < 0.65 or mat == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
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
		local part = RigCore.MakeStyledPart(vName, Vector3.new(v.sz[1], v.sz[2], v.sz[3]) * s, partCF, col, mat, finalTr, isStatic, v.sh, parentModel)
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

function RigCore.EnsureSpeciesMeshTemplates(specMod: SpeciesModule): Folder?
	local meshList = specMod.MeshParts
	if not meshList or #meshList == 0 then
		return nil
	end

	local tmplRoot = ReplicatedStorage:FindFirstChild("RealisticMeshTemplates")
	if not tmplRoot then
		if not RunService:IsServer() then
			return nil
		end
		local f = Instance.new("Folder")
		f.Name = "RealisticMeshTemplates"
		f.Parent = ReplicatedStorage
		tmplRoot = f
	end

	local spFolder = tmplRoot:FindFirstChild(specMod.Id)
	if not spFolder then
		if not RunService:IsServer() then
			return nil
		end
		local f = Instance.new("Folder")
		f.Name = specMod.Id
		f.Parent = tmplRoot
		spFolder = f
	end

	if RunService:IsServer() then
		for _, mpSpec in ipairs(meshList) do
			if not spFolder:FindFirstChild(mpSpec.key) then
				local ok, created = pcall(function()
					return InsertService:CreateMeshPartAsync(
						mpSpec.meshId,
						Enum.CollisionFidelity.Box,
						Enum.RenderFidelity.Automatic
					)
				end)
				if ok and created then
					created.Name = mpSpec.key
					created.TextureID = mpSpec.textureId
					created.CFrame = CFrame.new(0, 0, 0)
					created.Anchored = true
					created.CanCollide = false
					created.CanQuery = false
					created.CanTouch = false
					created.Massless = true
					if math.max(mpSpec.sz[1], mpSpec.sz[2], mpSpec.sz[3]) < 1.25 then
						created.CastShadow = false
					end
					created.Parent = spFolder
				end
			end
		end
	end

	return spFolder :: Folder
end

function RigCore.BuildMeshSpecies(
	specMod: SpeciesModule,
	s: number,
	ctx: MutContext,
	isStatic: boolean,
	model: Model,
	unscaledRootSize: Vector3?
): RigSession
	local meshScale = specMod.BaseMeshScale or 0.78
	local effScale = s * meshScale
	local rootSz = unscaledRootSize or Vector3.new(1.35, 1.35, 2.10)
	local session = RigCore.CreateSession(model, s, ctx, isStatic, rootSz, specMod.AccentColor)
	model:SetAttribute("IsTexturedMesh", true)
	if specMod.PublishedAssetId then
		model:SetAttribute("PublishedAssetId", specMod.PublishedAssetId)
	end

	local spFolder = RigCore.EnsureSpeciesMeshTemplates(specMod)
	local meshList = specMod.MeshParts or {}
	local boneHubs: { [string]: Part } = {}

	for idx, mpSpec in ipairs(meshList) do
		local scaledPos = Vector3.new(mpSpec.pos[1], mpSpec.pos[2], mpSpec.pos[3]) * effScale
		local scaledSz = Vector3.new(mpSpec.sz[1], mpSpec.sz[2], mpSpec.sz[3]) * effScale
		local deg = mpSpec.rot
		local rotCF = if deg then CFrame.Angles(math.rad(deg[1]), math.rad(deg[2]), math.rad(deg[3])) else CFrame.new()
		local partCF = CFrame.new(scaledPos) * rotCF

		local hub = boneHubs[mpSpec.bone]
		if not hub then
			hub = RigCore.MakePart(
				mpSpec.bone,
				Vector3.new(0.18 * s, 0.18 * s, 0.18 * s),
				CFrame.new(scaledPos),
				Color3.new(1, 1, 1),
				Enum.Material.SmoothPlastic,
				1,
				isStatic,
				model
			)
			hub.CastShadow = false
			boneHubs[mpSpec.bone] = hub
			session.BoneSet[mpSpec.bone] = true
		end

		local part: BasePart
		local tmpl = if spFolder then spFolder:FindFirstChild(mpSpec.key) else nil
		if tmpl and tmpl:IsA("MeshPart") then
			local cloned = tmpl:Clone()
			cloned.Name = mpSpec.bone .. "_Mesh_" .. mpSpec.key
			cloned.Size = scaledSz
			cloned.CFrame = partCF
			cloned.TextureID = mpSpec.textureId
			cloned.Color = Color3.new(1, 1, 1)
			cloned.Transparency = if ctx.mutation == "Diamond" then 0.08 else 0
			cloned.Anchored = isStatic
			cloned.Massless = not isStatic
			cloned.CanCollide = false
			cloned.CanQuery = false
			cloned.CanTouch = false
			if math.max(scaledSz.X, scaledSz.Y, scaledSz.Z) < 1.15 then
				cloned.CastShadow = false
			end
			cloned.Parent = model
			part = cloned
		else
			-- Safe fallback ellipsoid if mesh template is ever unavailable offline
			part = RigCore.MakeStyledPart(
				mpSpec.bone .. "_Fallback_" .. tostring(idx),
				scaledSz,
				partCF,
				specMod.AccentColor,
				Enum.Material.SmoothPlastic,
				0,
				isStatic,
				"Sphere",
				model
			)
		end

		part:SetAttribute("BoneCluster", mpSpec.bone)
		if not isStatic then
			local w = Instance.new("WeldConstraint")
			w.Part0 = hub
			w.Part1 = part
			w.Parent = hub
		end
	end

	if not isStatic then
		local torsoHub = boneHubs["Torso"]
		if torsoHub then
			attachMotor("RootJoint", session.Root, torsoHub, torsoHub.Position)
		end
		for _, mpSpec in ipairs(meshList) do
			if mpSpec.jointName and mpSpec.parentBone then
				local p0 = boneHubs[mpSpec.parentBone]
				local p1 = boneHubs[mpSpec.bone]
				if p0 and p1 and p0 ~= p1 then
					local pivVec = if mpSpec.pivot
						then (Vector3.new(mpSpec.pivot[1], mpSpec.pivot[2], mpSpec.pivot[3]) * effScale)
						else p1.Position
					attachMotor(mpSpec.jointName, p0, p1, pivVec)
				end
			end
		end
	end

	if ctx.active then
		local hl = Instance.new("Highlight")
		hl.Name = "MutationHighlight"
		hl.Adornee = model
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.FillColor = ctx.mutColor
		hl.FillTransparency = if ctx.mutation == "Shadow" or ctx.mutation == "Void" then 0.36 else 0.58
		hl.OutlineColor = ctx.mutColor
		hl.OutlineTransparency = 0.14
		if ctx.mutation == "Rainbow" then
			hl:SetAttribute("RainbowHighlight", true)
		end
		hl.Parent = model
	end

	return session
end

return RigCore
