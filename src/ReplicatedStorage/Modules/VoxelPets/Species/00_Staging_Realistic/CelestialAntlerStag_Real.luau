--!strict
-- CelestialAntlerStag_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #8 Realistic: Segmented Cube-3D Textured Mesh Celestial Antler Stag (8 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_CYAN = Color3.fromRGB(132, 234, 248)
local C_STAR = Color3.fromRGB(255, 252, 220)

local CelestialAntlerStag_Real: RigCore.SpeciesModule
CelestialAntlerStag_Real = {
	Id = "CelestialAntlerStag_Real",
	DisplayName = "Celestial Antler Stag (Realistic)",
	Archetype = "QuadrupedBeast",
	VisualStyle = "Realistic",
	StagingSlot = 8,
	BaseConceptId = "CelestialAntlerStag",
	PublishedAssetId = "130443040254982",
	BaseMeshScale = 0.78,
	DefaultScale = 1.35,
	AccentColor = C_CYAN,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://130834283282914",
			textureId = "rbxassetid://82985292935999",
			pos = { -0.002, 2.990, 0.009 },
			sz = { 1.363, 2.361, 3.595 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Torso",
			jointName = "HeadJoint",
			meshId = "rbxassetid://75773432055314",
			textureId = "rbxassetid://84973116314514",
			pos = { -0.002, 3.783, -1.443 },
			sz = { 1.483, 1.274, 1.439 },
			pivot = { -0.002, 3.480, -1.180 },
		},
		{
			key = "antlers",
			bone = "Head",
			meshId = "rbxassetid://75705274341652",
			textureId = "rbxassetid://99337740310787",
			pos = { 0.000, 4.907, -1.300 },
			sz = { 2.531, 1.385, 0.567 },
		},
		{
			key = "front_left_leg",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://91471829433824",
			textureId = "rbxassetid://76267799669389",
			pos = { -0.365, 1.256, -1.103 },
			sz = { 0.489, 2.509, 0.668 },
			pivot = { -0.365, 2.220, -1.103 },
		},
		{
			key = "front_right_leg",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://73092881538795",
			textureId = "rbxassetid://78355572339324",
			pos = { 0.355, 1.254, -1.099 },
			sz = { 0.486, 2.506, 0.669 },
			pivot = { 0.355, 2.220, -1.099 },
		},
		{
			key = "back_left_leg",
			bone = "LegBL",
			parentBone = "Torso",
			jointName = "LegBLJoint",
			meshId = "rbxassetid://138453757022531",
			textureId = "rbxassetid://103097505669083",
			pos = { -0.281, 1.455, 1.225 },
			sz = { 0.729, 2.909, 1.199 },
			pivot = { -0.281, 2.480, 1.200 },
		},
		{
			key = "back_right_leg",
			bone = "LegBR",
			parentBone = "Torso",
			jointName = "LegBRJoint",
			meshId = "rbxassetid://137889096611621",
			textureId = "rbxassetid://80832029726496",
			pos = { 0.279, 1.457, 1.225 },
			sz = { 0.726, 2.913, 1.200 },
			pivot = { 0.279, 2.480, 1.200 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://70505379880035",
			textureId = "rbxassetid://78719363383338",
			pos = { -0.002, 2.867, 1.860 },
			sz = { 0.406, 0.544, 0.606 },
			pivot = { -0.002, 2.840, 1.660 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(CelestialAntlerStag_Real, s, ctx, isStatic, model, Vector3.new(1.4, 2.3, 2.2))
		if not isStatic then
			local head = model:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				VFXPresets.AttachBodyAura(head, s, Vector3.new(0, 0.7, 0), "StagMeshVFX", { C_STAR, C_CYAN }, 7, 0.24)
			end
		end
		return session
	end,
}

return CelestialAntlerStag_Real
