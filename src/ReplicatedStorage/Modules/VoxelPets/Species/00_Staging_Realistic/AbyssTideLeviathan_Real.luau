--!strict
-- AbyssTideLeviathan_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #1 Realistic: Segmented Cube-3D Textured Mesh Leviathan (6 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_AQUA = Color3.fromRGB(48, 248, 232)
local C_COBALT = Color3.fromRGB(26, 68, 134)

local AbyssTideLeviathan_Real: RigCore.SpeciesModule
AbyssTideLeviathan_Real = {
	Id = "AbyssTideLeviathan_Real",
	DisplayName = "Abyss Tide Leviathan (Realistic)",
	Archetype = "EasternSerpent",
	VisualStyle = "Realistic",
	StagingSlot = 1,
	BaseConceptId = "AbyssTideLeviathan",
	PublishedAssetId = "133217116513800",
	BaseMeshScale = 0.86,
	DefaultScale = 1.30,
	AccentColor = C_AQUA,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://140668249612691",
			textureId = "rbxassetid://92368917010361",
			pos = { 0.011, 1.946, -0.400 },
			sz = { 2.463, 3.892, 1.878 },
		},
		{
			key = "dorsal_fin",
			bone = "Torso",
			meshId = "rbxassetid://127588189620874",
			textureId = "rbxassetid://73120718262467",
			pos = { 0.009, 2.908, -0.380 },
			sz = { 3.170, 1.168, 1.178 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Torso",
			jointName = "HeadJoint",
			meshId = "rbxassetid://137521271238497",
			textureId = "rbxassetid://84548487122296",
			pos = { 0.005, 3.351, -1.449 },
			sz = { 1.698, 1.697, 1.468 },
			pivot = { 0.008, 3.050, -0.920 },
		},
		{
			key = "left_arm",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://81415862933433",
			textureId = "rbxassetid://122530065585018",
			pos = { -1.235, 1.861, -0.517 },
			sz = { 1.310, 2.140, 1.044 },
			pivot = { -0.820, 2.550, -0.480 },
		},
		{
			key = "right_arm",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://104654824689260",
			textureId = "rbxassetid://115549043398027",
			pos = { 1.237, 1.854, -0.520 },
			sz = { 1.308, 2.153, 1.043 },
			pivot = { 0.820, 2.550, -0.480 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://127757647412557",
			textureId = "rbxassetid://108520941304175",
			pos = { 0.361, 1.107, 0.766 },
			sz = { 1.758, 1.566, 2.833 },
			pivot = { 0.080, 1.250, 0.320 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(AbyssTideLeviathan_Real, s, ctx, isStatic, model, Vector3.new(1.6, 2.2, 2.2))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.3, 0), "AbyssMeshVFX", { C_AQUA, C_COBALT }, 6, 0.26)
			end
		end
		return session
	end,
}

return AbyssTideLeviathan_Real
