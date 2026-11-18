--!strict
-- AzureFlameMechaBeast_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #2 Realistic: Segmented Cube-3D Textured Mesh Mecha Dragon-Wolf (7 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_AZURE = Color3.fromRGB(36, 178, 255)
local C_ICE = Color3.fromRGB(168, 236, 255)

local AzureFlameMechaBeast_Real: RigCore.SpeciesModule
AzureFlameMechaBeast_Real = {
	Id = "AzureFlameMechaBeast_Real",
	DisplayName = "Azure Flame Mecha (Realistic)",
	Archetype = "WingedDrake",
	VisualStyle = "Realistic",
	StagingSlot = 2,
	BaseConceptId = "AzureFlameMechaBeast",
	PublishedAssetId = "112423357158547",
	BaseMeshScale = 0.84,
	DefaultScale = 1.30,
	AccentColor = C_AZURE,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://86354927017331",
			textureId = "rbxassetid://110577932760498",
			pos = { -0.001, 2.240, -0.948 },
			sz = { 0.965, 1.752, 1.386 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Torso",
			jointName = "HeadJoint",
			meshId = "rbxassetid://130984408993923",
			textureId = "rbxassetid://105559587348430",
			pos = { 0.001, 3.162, -1.163 },
			sz = { 0.648, 0.908, 0.960 },
			pivot = { 0.000, 2.860, -1.040 },
		},
		{
			key = "left_wing",
			bone = "WingL",
			parentBone = "Torso",
			jointName = "WingLJoint",
			meshId = "rbxassetid://72648144717656",
			textureId = "rbxassetid://107387860938312",
			pos = { -1.204, 3.154, -0.965 },
			sz = { 2.071, 2.085, 0.819 },
			pivot = { -0.420, 2.580, -0.950 },
		},
		{
			key = "right_wing",
			bone = "WingR",
			parentBone = "Torso",
			jointName = "WingRJoint",
			meshId = "rbxassetid://92667255924751",
			textureId = "rbxassetid://136648302237367",
			pos = { 1.205, 3.153, -0.970 },
			sz = { 2.070, 2.094, 0.805 },
			pivot = { 0.420, 2.580, -0.950 },
		},
		{
			key = "front_legs",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://95152905255424",
			textureId = "rbxassetid://71536410983975",
			pos = { -0.001, 0.947, -1.319 },
			sz = { 0.921, 1.895, 0.919 },
			pivot = { -0.001, 1.650, -1.220 },
		},
		{
			key = "back_legs",
			bone = "LegBR",
			parentBone = "Torso",
			jointName = "LegBRJoint",
			meshId = "rbxassetid://139677896761811",
			textureId = "rbxassetid://99836748960444",
			pos = { -0.004, 0.833, 0.308 },
			sz = { 1.148, 1.639, 0.976 },
			pivot = { -0.004, 1.480, 0.220 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://90492017194437",
			textureId = "rbxassetid://110705656265700",
			pos = { -0.364, 1.287, 0.512 },
			sz = { 1.636, 1.773, 2.532 },
			pivot = { -0.050, 1.680, -0.250 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(AzureFlameMechaBeast_Real, s, ctx, isStatic, model, Vector3.new(1.5, 2.0, 2.2))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.2, 0), "MechaMeshVFX", { C_AZURE, C_ICE }, 7, 0.28)
			end
		end
		return session
	end,
}

return AzureFlameMechaBeast_Real
