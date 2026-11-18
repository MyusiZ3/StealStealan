--!strict
-- ImperialGoldQilin_Real.luau (AI Textured 3D Mesh + Motor6D Rig)
-- Candidate #7 Realistic: Segmented Cube-3D Textured Mesh Imperial Gold Qilin (8 MeshParts, Box Collision, Auto LOD).

local VoxelPetsRoot = game:GetService("ReplicatedStorage").Modules.VoxelPets
local RigCore = require(VoxelPetsRoot.RigCore)
local VFXPresets = require(VoxelPetsRoot.VFXPresets)

local C_GOLD = Color3.fromRGB(244, 198, 48)
local C_CLOUD = Color3.fromRGB(244, 248, 255)

local ImperialGoldQilin_Real: RigCore.SpeciesModule
ImperialGoldQilin_Real = {
	Id = "ImperialGoldQilin_Real",
	DisplayName = "Imperial Gold Qilin (Realistic)",
	Archetype = "QuadrupedBeast",
	VisualStyle = "Realistic",
	StagingSlot = 7,
	BaseConceptId = "ImperialGoldQilin",
	PublishedAssetId = "123846700334863",
	BaseMeshScale = 0.80,
	DefaultScale = 1.35,
	AccentColor = C_GOLD,
	MeshParts = {
		{
			key = "body",
			bone = "Torso",
			meshId = "rbxassetid://105819064655829",
			textureId = "rbxassetid://121450662466930",
			pos = { -0.002, 2.020, -0.432 },
			sz = { 1.365, 1.673, 3.676 },
		},
		{
			key = "neck",
			bone = "Neck",
			parentBone = "Torso",
			jointName = "NeckJoint",
			meshId = "rbxassetid://77649337340099",
			textureId = "rbxassetid://84453098307271",
			pos = { -0.002, 2.801, -1.490 },
			sz = { 0.970, 2.608, 1.559 },
			pivot = { -0.002, 2.280, -1.280 },
		},
		{
			key = "head",
			bone = "Head",
			parentBone = "Neck",
			jointName = "HeadJoint",
			meshId = "rbxassetid://81483660108724",
			textureId = "rbxassetid://82600974695641",
			pos = { 0.000, 3.739, -1.651 },
			sz = { 1.749, 2.123, 1.243 },
			pivot = { 0.000, 3.320, -1.520 },
		},
		{
			key = "front_left_leg",
			bone = "LegFL",
			parentBone = "Torso",
			jointName = "LegFLJoint",
			meshId = "rbxassetid://122251555382148",
			textureId = "rbxassetid://83222605276446",
			pos = { -0.561, 1.320, -1.640 },
			sz = { 0.874, 2.633, 1.230 },
			pivot = { -0.520, 2.180, -1.580 },
		},
		{
			key = "front_right_leg",
			bone = "LegFR",
			parentBone = "Torso",
			jointName = "LegFRJoint",
			meshId = "rbxassetid://134154673870744",
			textureId = "rbxassetid://71998588397904",
			pos = { 0.553, 1.318, -1.640 },
			sz = { 0.891, 2.636, 1.238 },
			pivot = { 0.520, 2.180, -1.580 },
		},
		{
			key = "back_left_leg",
			bone = "LegBL",
			parentBone = "Torso",
			jointName = "LegBLJoint",
			meshId = "rbxassetid://89889583022348",
			textureId = "rbxassetid://134251479184981",
			pos = { -0.492, 1.200, 0.631 },
			sz = { 0.953, 2.385, 1.300 },
			pivot = { -0.480, 1.980, 0.620 },
		},
		{
			key = "back_right_leg",
			bone = "LegBR",
			parentBone = "Torso",
			jointName = "LegBRJoint",
			meshId = "rbxassetid://94915637396175",
			textureId = "rbxassetid://89922475029931",
			pos = { 0.487, 1.199, 0.635 },
			sz = { 0.962, 2.388, 1.299 },
			pivot = { 0.480, 1.980, 0.620 },
		},
		{
			key = "tail",
			bone = "Tail1",
			parentBone = "Torso",
			jointName = "Tail1Joint",
			meshId = "rbxassetid://114586490590844",
			textureId = "rbxassetid://101548169444057",
			pos = { 0.000, 2.599, 1.513 },
			sz = { 0.922, 1.445, 1.519 },
			pivot = { 0.000, 2.280, 1.160 },
		},
	},
	Build = function(s: number, ctx: RigCore.MutContext, isStatic: boolean, model: Model): RigCore.RigSession
		local session = RigCore.BuildMeshSpecies(ImperialGoldQilin_Real, s, ctx, isStatic, model, Vector3.new(1.4, 2.1, 2.3))
		if not isStatic then
			local torso = model:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				VFXPresets.AttachBodyAura(torso, s, Vector3.new(0, 0.25, 0), "QilinMeshVFX", { C_GOLD, C_CLOUD }, 7, 0.28)
			end
		end
		return session
	end,
}

return ImperialGoldQilin_Real
