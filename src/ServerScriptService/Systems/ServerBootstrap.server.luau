--!strict
-- ServerBootstrap.server.luau
-- Master Server Entrypoint initializing Remotes, Services, Systems, Player Lifecycle, & Character Trails

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.InitServer()

local Services = script.Parent.Parent.Services
local Systems = script.Parent

local DataService = require(Services.DataService)
local PassManager = require(Services.PassManager)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)
local AdminService = require(Services.AdminService)
local AnalyticsTracker = require(Services.AnalyticsTracker)
local LeaderboardService = require(Services.LeaderboardService)

local PoacherAISystem = require(Systems.PoacherAISystem)
local LassoRescueSystem = require(Systems.LassoRescueSystem)
local TrainingSystem = require(Systems.TrainingSystem)
local FuseMergeSystem = require(Systems.FuseMergeSystem)

local sessionStartTimes: { [number]: number } = {}

-- Initialize Services & Systems
PassManager.Init()
PlotService.Init()
EconomyService.Init()
AdminService.Init()
LeaderboardService.Init()
PoacherAISystem.Init()
LassoRescueSystem.Init()
TrainingSystem.Init()
FuseMergeSystem.Init()
DataService.StartAutoSaveLoop()

-- Player Lifecycle
Players.PlayerAdded:Connect(function(player)
	local isBanned, reason = DataService.CheckBan(player.UserId)
	if isBanned then
		player:Kick("Banned: " .. tostring(reason))
		return
	end

	local profile = DataService.LoadProfile(player)
	sessionStartTimes[player.UserId] = os.time()
	AnalyticsTracker.LogOnboardingStep(player, 1, "JoinedExperience")
	PlotService.AssignPlot(player)
	LeaderboardService.OnPlayerReady(player)
	PoacherAISystem.ResetShieldsForPlayer(player)

	-- Wire Settings update remote
	task.defer(function()
		DataService.SyncProfile(player)
		PlotService.BroadcastAllPlotsSync()
	end)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		PoacherAISystem.ResetShieldsForPlayer(player)
		local prof = DataService.GetProfile(player)
		if prof then
			player:SetAttribute("EquippedTrail", prof.equippedTrail)
		end
		-- Ensure HumanoidRootPart exists cleanly
		character:WaitForChild("HumanoidRootPart", 5)
	end)
end)

Remotes.Get("UpdateSettings").OnServerEvent:Connect(function(player, newSettings)
	if type(newSettings) ~= "table" then return end
	local profile = DataService.GetProfile(player)
	if not profile then return end
	if type(newSettings.musicEnabled) == "boolean" then profile.settings.musicEnabled = newSettings.musicEnabled end
	if type(newSettings.musicVolume) == "number" then profile.settings.musicVolume = math.clamp(newSettings.musicVolume, 0, 1) end
	if type(newSettings.sfxEnabled) == "boolean" then profile.settings.sfxEnabled = newSettings.sfxEnabled end
	if type(newSettings.sfxVolume) == "number" then profile.settings.sfxVolume = math.clamp(newSettings.sfxVolume, 0, 1) end
	if type(newSettings.hideOtherAnimals) == "boolean" then profile.settings.hideOtherAnimals = newSettings.hideOtherAnimals end
	if type(newSettings.hideOwnAnimals) == "boolean" then profile.settings.hideOwnAnimals = newSettings.hideOwnAnimals end
	if type(newSettings.lowVFX) == "boolean" then profile.settings.lowVFX = newSettings.lowVFX end
	if newSettings.graphicsQuality == "Low" or newSettings.graphicsQuality == "Medium" or newSettings.graphicsQuality == "High" then
		profile.settings.graphicsQuality = newSettings.graphicsQuality
	end
	DataService.SyncProfile(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local started = sessionStartTimes[player.UserId]
	if started then
		AnalyticsTracker.LogCustom(player, "SessionEnd", os.time() - started)
		sessionStartTimes[player.UserId] = nil
	end
	PlotService.ReleasePlot(player)
	DataService.ReleaseProfile(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.SaveProfile(player)
	end
end)
