--!strict
-- PetLabBootstrap.server.luau
-- Initializes the isolated Pet Lab workbench stage on server boot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetLabStageBuilder = require(ReplicatedStorage:WaitForChild("PetLab"):WaitForChild("PetLabStageBuilder"))
PetLabStageBuilder.BuildStage()
