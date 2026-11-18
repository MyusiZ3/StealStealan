--!strict
-- VoxelPets/init.luau
-- Registry & public entry point for modular 1-file-per-pet Voxel 3D Rigs,
-- KeyframeSequence AnimSaves, 60 FPS procedural animation, and geometry validation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

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

local BIOME_ORDER_MAP: { [string]: number } = {}
for _, b in ipairs(BiomeConfig) do
	BIOME_ORDER_MAP[b.id] = b.order or 99
end

local registry: { [string]: SpeciesModule } = {}
local orderedIds: { string } = {}

local function loadSpeciesRegistry()
	local speciesFolder = script:FindFirstChild("Species")
	if not speciesFolder then
		return
	end

	for _, desc in ipairs(speciesFolder:GetDescendants()) do
		if desc:IsA("ModuleScript") and string.sub(desc.Name, 1, 1) ~= "_" then
			local ok, mod = pcall(require, desc)
			if ok and type(mod) == "table" and type(mod.Id) == "string" and type(mod.Build) == "function" then
				registry[mod.Id] = mod :: SpeciesModule
			else
				warn("[VoxelPets] Failed to load species module:", desc.Name, mod)
			end
		end
	end

	for id in pairs(registry) do
		table.insert(orderedIds, id)
	end

	table.sort(orderedIds, function(a, b)
		local ma = registry[a]
		local mb = registry[b]
		local stA = if ma and ma.StagingSlot then ma.StagingSlot else 0
		local stB = if mb and mb.StagingSlot then mb.StagingSlot else 0
		if (stA > 0) ~= (stB > 0) then
			return stA == 0 -- Assigned biome species first, staging candidates after
		end
		if stA > 0 and stB > 0 then
			if stA ~= stB then
				return stA < stB
			end
			local styA = if ma and ma.VisualStyle == "Realistic" then 2 else 1
			local styB = if mb and mb.VisualStyle == "Realistic" then 2 else 1
			if styA ~= styB then
				return styA < styB
			end
			return a < b
		end

		local sa = AnimalConfig.GetById(a)
		local sb = AnimalConfig.GetById(b)
		local ba = if sa then (BIOME_ORDER_MAP[sa.biomeId] or 99) else 99
		local bb = if sb then (BIOME_ORDER_MAP[sb.biomeId] or 99) else 99
		if ba ~= bb then
			return ba < bb
		end
		local ra = if sa then GameConfig.GetRarityTier(sa.rarity) else 99
		local rb = if sb then GameConfig.GetRarityTier(sb.rarity) else 99
		if ra ~= rb then
			return ra < rb
		end
		local ia = if sa then sa.indexNumber else 999
		local ib = if sb then sb.indexNumber else 999
		if ia ~= ib then
			return ia < ib
		end
		return a < b
	end)
end

loadSpeciesRegistry()

export type StagingPair = {
	slot: number,
	baseId: string,
	voxelId: string?,
	realisticId: string?,
}

function VoxelPets.GetSpeciesIds(): { string }
	return table.clone(orderedIds)
end

function VoxelPets.GetStagingPairs(): { StagingPair }
	local bySlot: { [number]: StagingPair } = {}
	local slots: { number } = {}
	for _, id in ipairs(orderedIds) do
		local m = registry[id]
		if m and m.StagingSlot and m.StagingSlot > 0 then
			local sl = m.StagingSlot
			local entry = bySlot[sl]
			if not entry then
				entry = {
					slot = sl,
					baseId = m.BaseConceptId or id,
					voxelId = nil,
					realisticId = nil,
				}
				bySlot[sl] = entry
				table.insert(slots, sl)
			end
			if m.VisualStyle == "Realistic" then
				entry.realisticId = id
			else
				entry.voxelId = id
			end
		end
	end
	table.sort(slots)
	local out: { StagingPair } = {}
	for _, sl in ipairs(slots) do
		table.insert(out, bySlot[sl])
	end
	return out
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

function VoxelPets.EnsureMeshTemplatesLoaded()
	for _, id in ipairs(orderedIds) do
		local mod = registry[id]
		if mod and mod.MeshParts and #mod.MeshParts > 0 then
			RigCore.EnsureSpeciesMeshTemplates(mod)
		end
	end
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
	model:SetAttribute("VisualStyle", mod.VisualStyle or "Voxel")
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
	if
		archAttr == "WingedDrake"
		or archAttr == "QuadrupedFeline"
		or archAttr == "QuadrupedBeast"
		or archAttr == "EasternSerpent"
		or archAttr == "ArachnidScorpion"
		or archAttr == "AquaticPlesiosaur"
	then
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
