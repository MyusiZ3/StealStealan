--!strict
-- XuanwuBlackTortoise_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #5 Realistic: Segmented Cube-3D Textured Mesh Xuanwu Tortoise-Dragon (8 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_MIST = Color3.fromRGB(168, 224, 255)
local C_AZURE = Color3.fromRGB(58, 174, 255)

local XuanwuBlackTortoise_Real: RigCore.SpeciesModule
XuanwuBlackTortoise_Real = {
	Id = "XuanwuBlackTortoise_Real",
	DisplayName = "Xuanwu Black Tortoise (Realistic)",
	Archetype = "QuadrupedBeast",
	VisualStyle = "Realistic",
	StagingSlot = 5,
	BaseConceptId = "XuanwuBlackTortoise",
	PublishedAssetId = "73675939380927",
	BaseMeshScale = 0.82,
	DefaultScale = 1.30,
	AccentColor = C_AZURE,
	MeshParts = {
		{
			key = "shell_body",
			bone = "Torso",
			meshId = "rbxassetid://115714021640632",
			textureId = "rbxassetid://82370806448612",
			pos = { 0.000, 1.721, 0.088 },
			sz = { 2.878, 2.594, 3.793 },
		},
		{
			key = "neck",
			bone = "Neck",
			parentBone = "Torso",
			jointName = "NeckJoint",
			meshId = "rbxassetid://113823712165048",
			textureId = "rbxassetid://116146491552382",
			pos = { 0.004, 2.034, -1.391 },
			sz = { 1.210, 2.744, 1.837 },
			pivot = { 0.004, 1.350, -1.120 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Neck",
			jointName = "HeadJoint",
			meshId = "rbxassetid://86176483315004",
			textureId = "rbxassetid://110659868728417",
			pos = { -0.005, 3.191, -2.114 },
			sz = { 1.281, 1.315, 1.372 },
			pivot = { -0.002, 2.980, -1.820 },
		},
		{
			key = "front_left_leg",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://70955555159002",
			textureId = "rbxassetid://128940819340286",
			pos = { -1.049, 0.654, -1.286 },
			sz = { 1.426, 1.309, 1.204 },
			pivot = { -0.920, 1.080, -1.180 },
		},
		{
			key = "front_right_leg",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://122318935128111",
			textureId = "rbxassetid://73966898129174",
			pos = { 1.054, 0.658, -1.280 },
			sz = { 1.416, 1.301, 1.216 },
			pivot = { 0.920, 1.080, -1.180 },
		},
		{
			key = "back_left_leg",
			bone = "LegBL",
			parentBone = "Torso",
			jointName = "LegBLJoint",
			meshId = "rbxassetid://129908841003728",
			textureId = "rbxassetid://72642124366153",
			pos = { -1.089, 0.651, 1.153 },
			sz = { 1.305, 1.285, 1.044 },
			pivot = { -0.960, 1.060, 1.080 },
		},
		{
			key = "back_right_leg",
			bone = "LegBR",
			parentBone = "Torso",
			jointName = "LegBRJoint",
			meshId = "rbxassetid://137447367828350",
			textureId = "rbxassetid://97363590453150",
			pos = { 1.090, 0.646, 1.154 },
			sz = { 1.310, 1.288, 1.054 },
			pivot = { 0.960, 1.060, 1.080 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://136045188191170",
			textureId = "rbxassetid://77671063530833",
			pos = { -0.607, 2.091, 1.984 },
			sz = { 2.087, 2.828, 1.632 },
			pivot = { -0.100, 1.480, 1.680 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(XuanwuBlackTortoise_Real, s, ctx, isStatic, model, Vector3.new(2.0, 1.9, 2.4))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.2, 0), "XuanwuMeshVFX", { C_MIST, C_AZURE }, 7, 0.28)
			end
		end
		return session
	end,
}

return XuanwuBlackTortoise_Real
