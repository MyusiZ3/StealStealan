--!strict
-- VoidSingularityScorpion_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #6 Realistic: Segmented Cube-3D Textured Mesh Void Scorpion (7 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_VIOLET = Color3.fromRGB(192, 78, 255)
local C_ORCHID = Color3.fromRGB(240, 156, 255)

local VoidSingularityScorpion_Real: RigCore.SpeciesModule
VoidSingularityScorpion_Real = {
	Id = "VoidSingularityScorpion_Real",
	DisplayName = "Void Singularity Scorpion (Realistic)",
	Archetype = "ArachnidScorpion",
	VisualStyle = "Realistic",
	StagingSlot = 6,
	BaseConceptId = "VoidSingularityScorpion",
	PublishedAssetId = "88656729573606",
	BaseMeshScale = 1.02,
	DefaultScale = 1.35,
	AccentColor = C_VIOLET,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://134534749552404",
			textureId = "rbxassetid://90743139411679",
			pos = { -0.003, 0.825, 0.470 },
			sz = { 0.915, 1.064, 3.530 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Torso",
			jointName = "HeadJoint",
			meshId = "rbxassetid://103636731462814",
			textureId = "rbxassetid://138044454554907",
			pos = { 0.001, 0.972, -0.952 },
			sz = { 1.170, 0.896, 1.602 },
			pivot = { 0.000, 0.880, -0.520 },
		},
		{
			key = "left_pincer_claw",
			bone = "WingL",
			parentBone = "Torso",
			jointName = "WingLJoint",
			meshId = "rbxassetid://120395236549271",
			textureId = "rbxassetid://98813183537117",
			pos = { -0.850, 1.074, -2.078 },
			sz = { 0.838, 0.612, 1.644 },
			pivot = { -0.520, 0.980, -1.360 },
		},
		{
			key = "right_pincer_claw",
			bone = "WingR",
			parentBone = "Torso",
			jointName = "WingRJoint",
			meshId = "rbxassetid://72311434138062",
			textureId = "rbxassetid://101706648798794",
			pos = { 0.804, 1.069, -2.054 },
			sz = { 0.938, 0.643, 1.688 },
			pivot = { 0.500, 0.980, -1.360 },
		},
		{
			key = "left_legs",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://80337659525970",
			textureId = "rbxassetid://85304248873598",
			pos = { -0.966, 0.606, -0.195 },
			sz = { 1.430, 1.057, 2.488 },
			pivot = { -0.440, 0.780, -0.195 },
		},
		{
			key = "right_legs",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://83138498235947",
			textureId = "rbxassetid://106285344242687",
			pos = { 0.966, 0.605, -0.196 },
			sz = { 1.429, 1.054, 2.493 },
			pivot = { 0.440, 0.780, -0.196 },
		},
		{
			key = "stinger_tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://139015830188751",
			textureId = "rbxassetid://93762842778780",
			pos = { -0.003, 0.317, 2.479 },
			sz = { 0.751, 0.633, 0.842 },
			pivot = { -0.003, 0.520, 2.120 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(VoidSingularityScorpion_Real, s, ctx, isStatic, model, Vector3.new(2.0, 1.4, 2.8))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.25, 0), "VoidMeshVFX", { C_VIOLET, C_ORCHID }, 7, 0.28)
			end
		end
		return session
	end,
}

return VoidSingularityScorpion_Real
