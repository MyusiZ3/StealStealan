--!strict
-- DataService.luau
-- Unified DataStore (PlayerData_v2) + BanStore (BanStore_v1) with graceful Studio fallback & retry

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Types = require(game.ReplicatedStorage.Shared.Types)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = {}

local DATASTORE_NAME = "PlayerData_v2"
local BANSTORE_NAME = "BanStore_v1"

local playerStore: DataStore? = nil
local banStore: DataStore? = nil
pcall(function()
	playerStore = DataStoreService:GetDataStore(DATASTORE_NAME)
	banStore = DataStoreService:GetDataStore(BANSTORE_NAME)
end)

local profiles: { [number]: Types.PlayerProfileSchema } = {}
local memoryBans: { [number]: { expiresAt: number, reason: string, byAdmin: string } } = {}

local function deepCopy<T>(tbl: T): T
	if type(tbl) ~= "table" then
		return tbl
	end
	local copy: any = {}
	for k, v in pairs(tbl :: any) do
		copy[k] = deepCopy(v)
	end
	return copy :: T
end

function DataService.CreateDefaultProfile(): Types.PlayerProfileSchema
	return {
		schemaVersion = 2,
		coins = GameConfig.ECONOMY.STARTING_COINS,
		gems = 0,
		speedStat = 0,
		rebirths = 0,

		penCapacity = GameConfig.PEN.STARTING_CAPACITY,
		penUpgradeLevel = 1,
		treadmillLevel = 1,
		unclaimedPenCoins = 0,

		equippedLasso = "RopeLasso",
		ownedLassos = { RopeLasso = true },
		equippedTrail = "BreezeTrail",
		ownedTrails = { BreezeTrail = true },
		equippedVehicle = "StarterATV",
		ownedVehicles = { StarterATV = true },

		roamingAnimalUids = {},
		inventoryAnimals = {},
		pendingCrates = {},
		discoveredIndex = {},
		zoneIndexBonusesClaimed = {},

		dailyReward = {
			lastClaimTime = 0,
			streak = 0,
		},
		settings = deepCopy(GameConfig.DEFAULT_SETTINGS),
		analyticsMeta = {
			firstJoinTime = os.time(),
			totalPlaytimeSeconds = 0,
			onboardingStep = 0,
		},
	}
end

local function migrateProfile(raw: any): Types.PlayerProfileSchema
	local def = DataService.CreateDefaultProfile()
	if type(raw) ~= "table" then
		return def
	end
	for k, v in pairs(def :: any) do
		if raw[k] == nil then
			raw[k] = deepCopy(v)
		end
	end
	if type(raw.settings) ~= "table" then
		raw.settings = deepCopy(GameConfig.DEFAULT_SETTINGS)
	else
		for sk, sv in pairs(GameConfig.DEFAULT_SETTINGS :: any) do
			if raw.settings[sk] == nil then
				raw.settings[sk] = sv
			end
		end
	end
	raw.penCapacity = math.max(GameConfig.PEN.STARTING_CAPACITY, raw.penCapacity or GameConfig.PEN.STARTING_CAPACITY)
	raw.penUpgradeLevel = math.max(1, raw.penUpgradeLevel or 1)
	raw.treadmillLevel = math.max(1, raw.treadmillLevel or 1)
	raw.schemaVersion = 2
	return raw :: Types.PlayerProfileSchema
end

function DataService.CheckBan(userId: number): (boolean, string?)
	local mem = memoryBans[userId]
	if mem then
		if mem.expiresAt == 0 or mem.expiresAt > os.time() then
			return true, mem.reason
		else
			memoryBans[userId] = nil
		end
	end
	if banStore then
		local ok, data = pcall(function()
			return (banStore :: DataStore):GetAsync("ban_" .. tostring(userId))
		end)
		if ok and type(data) == "table" then
			if data.expiresAt == 0 or data.expiresAt > os.time() then
				return true, tostring(data.reason or "Banned by Moderator")
			end
		elseif not ok and string.find(tostring(data), "StudioAccessToApisNotAllowed", 1, true) then
			banStore = nil
			playerStore = nil
		end
	end
	return false, nil
end

function DataService.BanUser(userId: number, durationSeconds: number, reason: string, byAdmin: string)
	local expiresAt = if durationSeconds <= 0 then 0 else os.time() + durationSeconds
	local record = {
		expiresAt = expiresAt,
		reason = reason,
		byAdmin = byAdmin,
		createdAt = os.time(),
	}
	memoryBans[userId] = record
	if banStore then
		pcall(function()
			(banStore :: DataStore):SetAsync("ban_" .. tostring(userId), record)
		end)
	end
	local target = Players:GetPlayerByUserId(userId)
	if target then
		target:Kick("You have been banned: " .. reason)
	end
end

function DataService.UnbanUser(userId: number)
	memoryBans[userId] = nil
	if banStore then
		pcall(function()
			(banStore :: DataStore):RemoveAsync("ban_" .. tostring(userId))
		end)
	end
end

function DataService.LoadProfile(player: Player): Types.PlayerProfileSchema
	local userId = player.UserId
	local key = "player_" .. tostring(userId)
	local loaded: any = nil

	if playerStore then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (playerStore :: DataStore):GetAsync(key)
			end)
			if ok then
				loaded = result
				print(string.format("[DataService] Loaded DataStore profile for %s (%s)", player.Name, if result then "existing" else "new"))
				break
			end
			if string.find(tostring(result), "StudioAccessToApisNotAllowed", 1, true) then
				warn("[DataService] Studio API Access is OFF. Enable 'Enable Studio Access to API Services' in Game Settings -> Security for cloud DataStore persistence in Studio.")
				playerStore = nil
				banStore = nil
				break
			end
			task.wait(0.4 * attempt)
		end
	end

	local profile = migrateProfile(loaded)
	profiles[userId] = profile
	return profile
end

function DataService.SaveProfile(player: Player): boolean
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	if not playerStore then
		return true
	end
	local key = "player_" .. tostring(player.UserId)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(playerStore :: DataStore):SetAsync(key, profile)
		end)
		if ok then
			print(string.format("[DataService] Saved DataStore profile for %s (Coins=%s, Speed=%s)", player.Name, tostring(profile.coins), tostring(profile.speedStat)))
			return true
		end
		if string.find(tostring(err), "StudioAccessToApisNotAllowed", 1, true) then
			playerStore = nil
			return true
		end
		task.wait(0.4 * attempt)
	end
	return false
end

function DataService.GetProfile(player: Player): Types.PlayerProfileSchema?
	return profiles[player.UserId]
end

function DataService.ReleaseProfile(player: Player)
	DataService.SaveProfile(player)
	profiles[player.UserId] = nil
end

function DataService.SyncProfile(player: Player)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	Remotes.Get("ProfileSync"):FireClient(player, profile)
end

function DataService.NewGuid(): string
	return HttpService:GenerateGUID(false)
end

function DataService.StartAutoSaveLoop()
	task.spawn(function()
		while true do
			task.wait(90)
			for _, player in ipairs(Players:GetPlayers()) do
				local prof = profiles[player.UserId]
				if prof then
					prof.analyticsMeta.totalPlaytimeSeconds += 90
					DataService.SaveProfile(player)
				end
			end
		end
	end)
end

return DataService
