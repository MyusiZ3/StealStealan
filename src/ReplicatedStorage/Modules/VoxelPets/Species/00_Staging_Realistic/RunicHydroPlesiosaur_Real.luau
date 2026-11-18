--!strict
-- RunicHydroPlesiosaur_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #9 Realistic: Segmented Cube-3D Textured Mesh Runic Hydro Plesiosaur (7 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_RUNE = Color3.fromRGB(72, 244, 255)
local C_SAPPHIRE = Color3.fromRGB(22, 76, 172)

local RunicHydroPlesiosaur_Real: RigCore.SpeciesModule
RunicHydroPlesiosaur_Real = {
	Id = "RunicHydroPlesiosaur_Real",
	DisplayName = "Runic Hydro Plesiosaur (Realistic)",
	Archetype = "AquaticPlesiosaur",
	VisualStyle = "Realistic",
	StagingSlot = 9,
	BaseConceptId = "RunicHydroPlesiosaur",
	PublishedAssetId = "102224783867388",
	BaseMeshScale = 0.80,
	DefaultScale = 1.30,
	AccentColor = C_RUNE,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://77471649609377",
			textureId = "rbxassetid://76623177887538",
			pos = { 0.005, 1.611, -0.981 },
			sz = { 1.091, 1.896, 2.025 },
		},
		{
			key = "neck",
			bone = "Neck",
			parentBone = "Torso",
			jointName = "NeckJoint",
			meshId = "rbxassetid://115897711996842",
			textureId = "rbxassetid://114849859190905",
			pos = { 0.003, 3.219, -0.668 },
			sz = { 0.607, 2.194, 1.797 },
			pivot = { 0.004, 2.380, -0.980 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Neck",
			jointName = "HeadJoint",
			meshId = "rbxassetid://80399896817720",
			textureId = "rbxassetid://105471126371536",
			pos = { 0.003, 4.242, -1.168 },
			sz = { 1.002, 1.117, 2.467 },
			pivot = { 0.003, 3.920, -0.820 },
		},
		{
			key = "front_left_flipper",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://125315806295051",
			textureId = "rbxassetid://137770448161352",
			pos = { -1.316, 1.805, -0.940 },
			sz = { 2.268, 2.068, 0.940 },
			pivot = { -0.450, 1.480, -0.940 },
		},
		{
			key = "front_right_flipper",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://82836645978442",
			textureId = "rbxassetid://137644225711706",
			pos = { 1.321, 1.810, -0.936 },
			sz = { 2.258, 2.068, 0.947 },
			pivot = { 0.450, 1.480, -0.936 },
		},
		{
			key = "back_flippers",
			bone = "LegBL",
			parentBone = "Torso",
			jointName = "LegBLJoint",
			meshId = "rbxassetid://106041028838611",
			textureId = "rbxassetid://94832763332219",
			pos = { -0.005, 0.659, -0.432 },
			sz = { 1.244, 0.475, 0.479 },
			pivot = { -0.005, 0.820, -0.432 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://117219506817507",
			textureId = "rbxassetid://130716545326962",
			pos = { 0.006, 0.731, 0.877 },
			sz = { 1.398, 1.462, 3.048 },
			pivot = { 0.006, 1.120, -0.180 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(RunicHydroPlesiosaur_Real, s, ctx, isStatic, model, Vector3.new(1.8, 2.2, 2.2))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.25, 0), "HydroMeshVFX", { C_RUNE, C_SAPPHIRE }, 6, 0.26)
			end
		end
		return session
	end,
}

return RunicHydroPlesiosaur_Real
