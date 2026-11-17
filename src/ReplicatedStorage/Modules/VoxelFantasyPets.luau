--!strict
-- VoxelFantasyPets.luau
-- Thin backward-compatible wrapper delegating to the modular VoxelPets package.

local VoxelPets = require(script.Parent.VoxelPets)

local VoxelFantasyPets = {}

export type AnimMode = VoxelPets.AnimMode

VoxelFantasyPets.GetSpeciesIds = VoxelPets.GetSpeciesIds
VoxelFantasyPets.IsFantasyVoxelSpecies = VoxelPets.IsFantasyVoxelSpecies
VoxelFantasyPets.IsVoxelRigSpecies = VoxelPets.IsVoxelRigSpecies
VoxelFantasyPets.Build = VoxelPets.Build
VoxelFantasyPets.StepRig = VoxelPets.StepRig
VoxelFantasyPets.ResetRig = VoxelPets.ResetRig
VoxelFantasyPets.InspectModel = VoxelPets.InspectModel

return VoxelFantasyPets
