--!strict
-- SeraphicRingDragon_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #3 Realistic: Segmented Cube-3D Textured Mesh Seraphic Ring Dragon (7 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_CYAN = Color3.fromRGB(68, 228, 252)
local C_PEARL = Color3.fromRGB(244, 248, 255)

local SeraphicRingDragon_Real: RigCore.SpeciesModule
SeraphicRingDragon_Real = {
	Id = "SeraphicRingDragon_Real",
	DisplayName = "Seraphic Ring Dragon (Realistic)",
	Archetype = "WingedDrake",
	VisualStyle = "Realistic",
	StagingSlot = 3,
	BaseConceptId = "SeraphicRingDragon",
	PublishedAssetId = "91336994793989",
	BaseMeshScale = 0.72,
	DefaultScale = 1.25,
	AccentColor = C_CYAN,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://77946567252510",
			textureId = "rbxassetid://90876267682774",
			pos = { -0.005, 3.241, -0.250 },
			sz = { 0.917, 1.712, 1.277 },
		},
		{
			key = "neck",
			bone = "Neck",
			parentBone = "Torso",
			jointName = "NeckJoint",
			meshId = "rbxassetid://131236054155716",
			textureId = "rbxassetid://106251240870943",
			pos = { -0.005, 4.079, -0.362 },
			sz = { 0.688, 1.167, 0.756 },
			pivot = { -0.005, 3.720, -0.310 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Neck",
			jointName = "HeadJoint",
			meshId = "rbxassetid://93626986459975",
			textureId = "rbxassetid://133455516982623",
			pos = { 0.000, 4.866, -0.232 },
			sz = { 0.917, 1.077, 1.009 },
			pivot = { 0.000, 4.520, -0.300 },
		},
		{
			key = "left_wings",
			bone = "WingL",
			parentBone = "Torso",
			jointName = "WingLJoint",
			meshId = "rbxassetid://89776678682703",
			textureId = "rbxassetid://87905164890304",
			pos = { -1.571, 4.622, -0.423 },
			sz = { 2.837, 2.757, 0.669 },
			pivot = { -0.450, 3.820, -0.380 },
		},
		{
			key = "right_wings",
			bone = "WingR",
			parentBone = "Torso",
			jointName = "WingRJoint",
			meshId = "rbxassetid://74295002961303",
			textureId = "rbxassetid://73783849556554",
			pos = { 1.628, 4.614, -0.418 },
			sz = { 2.723, 2.753, 0.663 },
			pivot = { 0.450, 3.820, -0.380 },
		},
		{
			key = "legs",
			bone = "LegBL",
			parentBone = "Torso",
			jointName = "LegBLJoint",
			meshId = "rbxassetid://81583814349400",
			textureId = "rbxassetid://127925672060801",
			pos = { 0.000, 2.391, -0.281 },
			sz = { 2.039, 2.438, 1.080 },
			pivot = { 0.000, 2.820, -0.260 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://84739303518447",
			textureId = "rbxassetid://101447031951038",
			pos = { -0.542, 1.642, 0.000 },
			sz = { 2.020, 3.284, 3.052 },
			pivot = { -0.080, 2.520, -0.100 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(SeraphicRingDragon_Real, s, ctx, isStatic, model, Vector3.new(1.5, 2.4, 1.8))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.4, 0), "SeraphMeshVFX", { C_CYAN, C_PEARL }, 7, 0.26)
			end
		end
		return session
	end,
}

return SeraphicRingDragon_Real
