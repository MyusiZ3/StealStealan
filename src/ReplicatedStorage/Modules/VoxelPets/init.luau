--!strict
-- VoxelPets/init.luau
-- Registry & public entry point for modular 1-file-per-pet Voxel 3D Rigs,
-- KeyframeSequence AnimSaves, 60 FPS procedural animation, and geometry validation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)

local RigCore = require(script.RigCore)
local AnimArchetypes = require(script.AnimArchetypes)
local VFXPresets = require(script.VFXPresets)
local Validator = require(script.Validator)

local VoxelPets = {}

export type AnimMode = RigCore.AnimMode
export type ArchetypeId = RigCore.ArchetypeId
export type SpeciesModule = RigCore.SpeciesModule
export type InspectResult = Validator.InspectResult

type MotorCacheEntry = {
	motor: Motor6D,
	baseC0: CFrame,
}

local PREFERRED_ORDER = {
	"SylphPlumeDrake",
	"FaeLaceDragon",
	"CelestiaStarCat",
}

local registry: { [string]: SpeciesModule } = {}
local orderedIds: { string } = {}

local function loadSpeciesRegistry()
	local speciesFolder = script:FindFirstChild("Species")
	if not speciesFolder then
		return
	end

	for _, child in ipairs(speciesFolder:GetChildren()) do
		if child:IsA("ModuleScript") and string.sub(child.Name, 1, 1) ~= "_" then
			local ok, mod = pcall(require, child)
			if ok and type(mod) == "table" and type(mod.Id) == "string" and type(mod.Build) == "function" then
				registry[mod.Id] = mod :: SpeciesModule
			else
				warn("[VoxelPets] Failed to load species module:", child.Name, mod)
			end
		end
	end

	local seen: { [string]: boolean } = {}
	for _, id in ipairs(PREFERRED_ORDER) do
		if registry[id] then
			table.insert(orderedIds, id)
			seen[id] = true
		end
	end

	local extras: { string } = {}
	for id in pairs(registry) do
		if not seen[id] then
			table.insert(extras, id)
		end
	end
	table.sort(extras)
	for _, id in ipairs(extras) do
		table.insert(orderedIds, id)
	end
end

loadSpeciesRegistry()

function VoxelPets.GetSpeciesIds(): { string }
	return table.clone(orderedIds)
end

function VoxelPets.GetSpeciesModule(speciesId: string): SpeciesModule?
	return registry[speciesId]
end

function VoxelPets.IsVoxelRigSpecies(speciesId: string): boolean
	return registry[speciesId] ~= nil
end

function VoxelPets.IsFantasyVoxelSpecies(speciesId: string): boolean
	return registry[speciesId] ~= nil
end

function VoxelPets.Build(speciesId: string, sizeRatio: number, mutation: Types.AnimalMutation?, lowVFX: boolean?): Model
	local mod = registry[speciesId] or registry[orderedIds[1]]
	assert(mod, "[VoxelPets] No registered species available for: " .. tostring(speciesId))

	local mut: Types.AnimalMutation = (mutation or "None") :: Types.AnimalMutation
	local spec = AnimalConfig.GetById(mod.Id)
	local s = math.clamp(sizeRatio or 1.0, 0.42, 6.0)
	local isStatic = (lowVFX == true)
	local ctx = RigCore.MakeMutContext(mut)

	local model = Instance.new("Model")
	model.Name = "Animal_" .. mod.Id
	model:SetAttribute("SpeciesId", mod.Id)
	model:SetAttribute("Mutation", mut)
	model:SetAttribute("SizeRatio", s)
	model:SetAttribute("VoxelRig", true)
	model:SetAttribute("Archetype", mod.Archetype)
	if spec then
		model:SetAttribute("Rarity", spec.rarity)
	end

	local session = mod.Build(s, ctx, isStatic, model)
	model.WorldPivot = CFrame.new(0, 0, 0)

	if mut == "Rainbow" and #session.RainbowParts > 0 then
		for _, rp in ipairs(session.RainbowParts) do
			rp:SetAttribute("RainbowTarget", true)
		end
	end

	if not isStatic then
		VFXPresets.AttachMutationVFX(model, s, mut)

		local animCtrl = Instance.new("AnimationController")
		animCtrl.Name = "AnimationController"
		animCtrl.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = animCtrl
		AnimArchetypes.PopulateAnimSaves(model, session.BoneSet, s, mod.Archetype)
	end

	return model
end

local cachedJointMaps: { [Model]: { [string]: MotorCacheEntry } } = setmetatable({}, { __mode = "k" }) :: any

local function getJointMap(model: Model): { [string]: MotorCacheEntry }
	local cached = cachedJointMaps[model]
	if cached then
		return cached
	end
	local map: { [string]: MotorCacheEntry } = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Motor6D") then
			local baseAttr = desc:GetAttribute("BaseC0")
			local baseCF = if typeof(baseAttr) == "CFrame" then baseAttr else desc.C0
			map[desc.Name] = { motor = desc, baseC0 = baseCF }
		end
	end
	cachedJointMaps[model] = map
	return map
end

function VoxelPets.ResetRig(model: Model)
	if not model or not model.Parent then
		return
	end
	local joints = getJointMap(model)
	for _, entry in pairs(joints) do
		if entry.motor.Parent then
			entry.motor.C0 = entry.baseC0
		end
	end
end

function VoxelPets.StepRig(model: Model, mode: AnimMode, now: number, phase: number?)
	if not model or not model.Parent then
		return
	end
	local s = tonumber(model:GetAttribute("SizeRatio")) or 1.0
	local archAttr = model:GetAttribute("Archetype")
	local archetype: ArchetypeId
	if archAttr == "WingedDrake" or archAttr == "QuadrupedFeline" or archAttr == "QuadrupedBeast" then
		archetype = archAttr :: ArchetypeId
	else
		local spId = tostring(model:GetAttribute("SpeciesId") or "")
		local mod = registry[spId]
		archetype = if mod then mod.Archetype elseif spId == "CelestiaStarCat" then "QuadrupedFeline" else "WingedDrake"
	end

	local ph = phase or 0
	local freq = if mode == "Ride"
		then 11.5
		elseif mode == "Walk" then 7.8
		elseif mode == "Fly" then 4.2
		elseif mode == "StressTest" then 2.2
		else 2.6
	local u = now * freq + ph

	local deltas = AnimArchetypes.SamplePoseDeltas(mode, u, s, archetype)
	local joints = getJointMap(model)
	for jName, entry in pairs(joints) do
		if entry.motor.Parent then
			local d = deltas[jName]
			entry.motor.C0 = if d then (entry.baseC0 * d) else entry.baseC0
		end
	end
end

function VoxelPets.InspectModel(model: Model): InspectResult
	return Validator.InspectModel(model)
end

return VoxelPets
