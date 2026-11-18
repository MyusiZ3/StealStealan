--!strict
-- ByakkoInkTiger_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #4 Realistic: Segmented Cube-3D Textured Mesh White Ink Tiger (7 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_WHITE = Color3.fromRGB(248, 250, 252)
local C_AMBER = Color3.fromRGB(252, 174, 42)

local ByakkoInkTiger_Real: RigCore.SpeciesModule
ByakkoInkTiger_Real = {
	Id = "ByakkoInkTiger_Real",
	DisplayName = "Byakko Ink Tiger (Realistic)",
	Archetype = "QuadrupedFeline",
	VisualStyle = "Realistic",
	StagingSlot = 4,
	BaseConceptId = "ByakkoInkTiger",
	PublishedAssetId = "133313827595493",
	BaseMeshScale = 0.80,
	DefaultScale = 1.30,
	AccentColor = C_AMBER,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://109837155681903",
			textureId = "rbxassetid://122084535148286",
			pos = { 0.006, 2.396, -0.142 },
			sz = { 2.133, 2.849, 3.802 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Torso",
			jointName = "HeadJoint",
			meshId = "rbxassetid://94076847270320",
			textureId = "rbxassetid://87956285660111",
			pos = { 0.012, 3.325, -1.643 },
			sz = { 2.467, 1.751, 1.801 },
			pivot = { 0.010, 2.960, -1.220 },
		},
		{
			key = "front_left_leg",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://118228878437664",
			textureId = "rbxassetid://133955693518557",
			pos = { -0.524, 1.298, -1.188 },
			sz = { 1.017, 2.597, 1.166 },
			pivot = { -0.524, 2.180, -1.150 },
		},
		{
			key = "front_right_leg",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://87968081033589",
			textureId = "rbxassetid://97522942616289",
			pos = { 0.541, 1.302, -1.179 },
			sz = { 1.014, 2.598, 1.167 },
			pivot = { 0.541, 2.180, -1.150 },
		},
		{
			key = "back_left_leg",
			bone = "LegBL",
			parentBone = "Torso",
			jointName = "LegBLJoint",
			meshId = "rbxassetid://107772179836359",
			textureId = "rbxassetid://83068051682368",
			pos = { -0.643, 1.043, 0.930 },
			sz = { 1.018, 2.084, 1.281 },
			pivot = { -0.620, 1.820, 0.880 },
		},
		{
			key = "back_right_leg",
			bone = "LegBR",
			parentBone = "Torso",
			jointName = "LegBRJoint",
			meshId = "rbxassetid://117759168683470",
			textureId = "rbxassetid://116582544062574",
			pos = { 0.662, 1.037, 0.931 },
			sz = { 1.009, 2.069, 1.284 },
			pivot = { 0.640, 1.820, 0.880 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://113265892796891",
			textureId = "rbxassetid://103632555656964",
			pos = { 0.000, 1.552, 1.901 },
			sz = { 2.562, 2.024, 1.285 },
			pivot = { 0.000, 2.040, 1.480 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(ByakkoInkTiger_Real, s, ctx, isStatic, model, Vector3.new(1.5, 1.9, 2.4))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.2, 0), "ByakkoMeshVFX", { C_WHITE, C_AMBER }, 6, 0.26)
			end
		end
		return session
	end,
}

return ByakkoInkTiger_Real
