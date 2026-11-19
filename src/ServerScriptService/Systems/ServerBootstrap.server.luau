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
PassManager.RegisterRewardCallbacks({
	addCrateToInventory = function(p, biomeId, rarity, speciesId, sizeScale, customStats)
		return PlotService.AddCrateToInventory(p, biomeId, rarity, speciesId, sizeScale, customStats)
	end,
	refreshPlotVisuals = PlotService.RefreshPlotBoardVisuals,
	refreshLeaderboards = LeaderboardService.RefreshGlobalLeaderboards,
})
EconomyService.Init()
AdminService.Init()
LeaderboardService.Init()
PoacherAISystem.Init()
LassoRescueSystem.Init()
TrainingSystem.Init()
FuseMergeSystem.Init()
DataService.StartAutoSaveLoop()

-- Player Lifecycle
local function onPlayerAdded(player: Player)
	if sessionStartTimes[player.UserId] then
		return
	end
	local isBanned, reason = DataService.CheckBan(player.UserId)
	if isBanned then
		player:Kick("Banned: " .. tostring(reason))
		return
	end

	local profile = DataService.LoadProfile(player)
	sessionStartTimes[player.UserId] = os.time()
	AnalyticsTracker.LogOnboardingStep(player, 1, "JoinedExperience")
	PlotService.AssignPlot(player)
	AdminService.OnPlayerJoined(player)
	LeaderboardService.OnPlayerReady(player)
	PoacherAISystem.ResetShieldsForPlayer(player)

	-- Wire Settings update remote
	task.defer(function()
		DataService.SyncProfile(player)
		PlotService.BroadcastAllPlotsSync()
	end)

	local function onCharacterAdded(character: Model)
		PoacherAISystem.ResetShieldsForPlayer(player)
		AdminService.ApplyCharacterTag(player, character)
		local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if hum and hum:IsA("Humanoid") then
			hum.Died:Connect(function()
				LassoRescueSystem.CancelPull(player)
				local hrp = character:FindFirstChild("HumanoidRootPart")
				local dropPos = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.new(0, 2, 160)
				LassoRescueSystem.DropPlayerCrates(player, dropPos)
			end)
		end
		local prof = DataService.GetProfile(player)
		if prof then
			player:SetAttribute("EquippedTrail", prof.equippedTrail)
		end
		-- Remove any accidental ForceField immediately so character never shimmers/flickers at spawn
		for _, ch in ipairs(character:GetChildren()) do
			if ch:IsA("ForceField") then
				ch:Destroy()
			end
		end
		character.ChildAdded:Connect(function(ch)
			if ch:IsA("ForceField") then
				ch:Destroy()
			end
		end)
		-- Ensure HumanoidRootPart exists cleanly and place at player's Base without delayed Hub flicker
		if not character:FindFirstChild("HumanoidRootPart") then
			character:WaitForChild("HumanoidRootPart", 5)
		end
		PlotService.TeleportPlayerToPlot(player)
		task.defer(function()
			if character.Parent then
				PlotService.TeleportPlayerToPlot(player)
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, existingPlayer in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, existingPlayer)
end

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
	if type(newSettings.hatchCutsceneEnabled) == "boolean" then profile.settings.hatchCutsceneEnabled = newSettings.hatchCutsceneEnabled end
	if newSettings.graphicsQuality == "Low" or newSettings.graphicsQuality == "Medium" or newSettings.graphicsQuality == "High" then
		profile.settings.graphicsQuality = newSettings.graphicsQuality
	end
	DataService.SyncProfile(player)
end)

Remotes.Get("SetHeldItem").OnServerEvent:Connect(function(player, itemType, itemId)
	if typeof(itemType) ~= "string" then return end
	local profile = DataService.GetProfile(player)
	if not profile then return end

	if itemType == "Pet" and typeof(itemId) == "string" then
		local animal = profile.inventoryAnimals[itemId]
		if animal then
			player:SetAttribute("HeldItemType", "Pet")
			player:SetAttribute("HeldItemId", itemId)
			player:SetAttribute("HeldItemSpecies", animal.speciesId)
			player:SetAttribute("HeldItemMutation", animal.mutation)
			player:SetAttribute("HeldItemBiome", "")
			player:SetAttribute("HeldItemRarity", "")
			player:SetAttribute("HeldItemScale", 1)
			player:SetAttribute("HeldItemMerged", false)
			return
		end
	elseif itemType == "Crate" and typeof(itemId) == "string" then
		local crate = if type(profile.crateInventory) == "table" then profile.crateInventory[itemId] else nil
		if crate then
			player:SetAttribute("HeldItemType", "Crate")
			player:SetAttribute("HeldItemId", itemId)
			player:SetAttribute("HeldItemSpecies", crate.speciesId or "")
			player:SetAttribute("HeldItemMutation", crate.customMutation or "")
			player:SetAttribute("HeldItemBiome", crate.biomeId)
			player:SetAttribute("HeldItemRarity", crate.rarity)
			player:SetAttribute("HeldItemScale", crate.sizeScale or 1)
			player:SetAttribute("HeldItemMerged", crate.originSource == "Merge")
			return
		end
	elseif itemType == "Vehicle" then
		player:SetAttribute("HeldItemType", "Vehicle")
		player:SetAttribute("HeldItemId", profile.equippedVehicle)
		player:SetAttribute("HeldItemSpecies", "")
		player:SetAttribute("HeldItemMutation", "")
		player:SetAttribute("HeldItemBiome", "")
		player:SetAttribute("HeldItemRarity", "")
		player:SetAttribute("HeldItemScale", 1)
		player:SetAttribute("HeldItemMerged", false)
		return
	elseif itemType == "Lasso" then
		player:SetAttribute("HeldItemType", "Lasso")
		player:SetAttribute("HeldItemId", profile.equippedLasso)
		player:SetAttribute("HeldItemSpecies", "")
		player:SetAttribute("HeldItemMutation", "")
		player:SetAttribute("HeldItemBiome", "")
		player:SetAttribute("HeldItemRarity", "")
		player:SetAttribute("HeldItemScale", 1)
		player:SetAttribute("HeldItemMerged", false)
		return
	end

	player:SetAttribute("HeldItemType", "")
	player:SetAttribute("HeldItemId", "")
	player:SetAttribute("HeldItemSpecies", "")
	player:SetAttribute("HeldItemMutation", "")
	player:SetAttribute("HeldItemBiome", "")
	player:SetAttribute("HeldItemRarity", "")
	player:SetAttribute("HeldItemScale", 1)
	player:SetAttribute("HeldItemMerged", false)
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
		DataService.SaveProfile(player, true)
	end
end)
