--!strict
-- DataService.luau
-- Unified DataStore (PlayerData_v2) + BanStore (BanStore_v1) with graceful Studio fallback & retry

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Types = require(game.ReplicatedStorage.Shared.Types)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local VehicleConfig = require(game.ReplicatedStorage.Config.VehicleConfig)
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = {}

local function getVehicleMultiplier(player: Player, vehicleId: string): number
	if player:GetAttribute("IsRidingVehicle") ~= true then
		return 1
	end
	for _, v in ipairs(VehicleConfig) do
		if v.id == vehicleId then
			return v.speedMultiplier
		end
	end
	return 1
end

local speedMetricsFn: ((Player, Types.PlayerProfileSchema) -> (number, number, number, number))? = nil

function DataService.RegisterSpeedMetricsGetter(fn: (Player, Types.PlayerProfileSchema) -> (number, number, number, number))
	speedMetricsFn = fn
end

local function computeSpeedMetricsFallback(player: Player, profile: Types.PlayerProfileSchema): (number, number, number, number)
	if speedMetricsFn then
		return speedMetricsFn(player, profile)
	end
	local vehMult = getVehicleMultiplier(player, profile.equippedVehicle)
	local riding = player:GetAttribute("IsRidingVehicle") == true
	local displayed = profile.speedStat * (if riding then vehMult else 1)
	return displayed, 1.0, (if riding then 1.0 + vehMult else 1.0), vehMult
end

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
local savingPlayers: { [number]: boolean } = {}

-- ============================================================================
-- ANTI-DUPE ENGINE: Global UID Registry, Consumed Tombstones & Transaction Mutex
-- ============================================================================
local MAX_CONSUMED_HISTORY = 160
local SESSION_LOCK_TTL = 75
local SERVER_SESSION_ID = if game.JobId ~= "" then game.JobId else ("Studio_" .. HttpService:GenerateGUID(false))

-- Maps active Item/Crate UID -> { ownerUserId, container ("PetInv" | "CrateInv" | "PendingCrate") }
local globalActiveUids: { [string]: { ownerUserId: number, container: string } } = {}
local lockedUids: { [string]: boolean } = {}
local playerTxLocks: { [number]: boolean } = {}

function DataService.NewGuid(): string
	return HttpService:GenerateGUID(false)
end

function DataService.IsUidConsumed(profile: Types.PlayerProfileSchema, uid: string): boolean
	if type(profile.consumedUids) ~= "table" then
		return false
	end
	return table.find(profile.consumedUids, uid) ~= nil
end

function DataService.MarkUidConsumed(profile: Types.PlayerProfileSchema, uid: string)
	if typeof(uid) ~= "string" or uid == "" then
		return
	end
	globalActiveUids[uid] = nil
	if type(profile.consumedUids) ~= "table" then
		profile.consumedUids = {}
	end
	local list = profile.consumedUids :: { string }
	if not table.find(list, uid) then
		table.insert(list, uid)
		while #list > MAX_CONSUMED_HISTORY do
			table.remove(list, 1)
		end
	end
end

function DataService.RegisterUidOwner(uid: string, userId: number, container: string): boolean
	if typeof(uid) ~= "string" or uid == "" then
		return false
	end
	local existing = globalActiveUids[uid]
	if existing and existing.ownerUserId ~= userId then
		warn(string.format("[AntiDupe] Blocked cross-player duplicate UID %s (Owner=%d, Attempt=%d, Container=%s)", uid, existing.ownerUserId, userId, container))
		return false
	end
	globalActiveUids[uid] = {
		ownerUserId = userId,
		container = container,
	}
	return true
end

function DataService.UnregisterPlayerUids(userId: number)
	for uid, info in pairs(globalActiveUids) do
		if info.ownerUserId == userId then
			globalActiveUids[uid] = nil
		end
	end
end

function DataService.MintUniqueId(profile: Types.PlayerProfileSchema): (string, number)
	local nextSerial = (tonumber(profile.itemSerialCounter) or 0) + 1
	profile.itemSerialCounter = nextSerial
	local uid = HttpService:GenerateGUID(false)
	while globalActiveUids[uid] ~= nil or DataService.IsUidConsumed(profile, uid) do
		uid = HttpService:GenerateGUID(false)
	end
	return uid, nextSerial
end

function DataService.AcquireTransactionLock(userId: number, uids: { string }?): boolean
	if playerTxLocks[userId] then
		return false
	end
	if uids then
		local seenInBatch: { [string]: boolean } = {}
		for _, u in ipairs(uids) do
			if typeof(u) ~= "string" or u == "" or lockedUids[u] or seenInBatch[u] then
				return false
			end
			seenInBatch[u] = true
		end
		for _, u in ipairs(uids) do
			lockedUids[u] = true
		end
	end
	playerTxLocks[userId] = true
	return true
end

function DataService.ReleaseTransactionLock(userId: number, uids: { string }?)
	playerTxLocks[userId] = nil
	if uids then
		for _, u in ipairs(uids) do
			if typeof(u) == "string" then
				lockedUids[u] = nil
			end
		end
	end
end

function DataService.SanitizeProfileIntegrity(userId: number, profile: Types.PlayerProfileSchema): number
	local purged = 0
	if type(profile.consumedUids) ~= "table" then
		profile.consumedUids = {}
	end
	local consumedSet: { [string]: boolean } = {}
	for _, cuid in ipairs(profile.consumedUids :: { string }) do
		if type(cuid) == "string" then
			consumedSet[cuid] = true
		end
	end

	-- 1. Validate inventoryAnimals: unique UID, matches key, not consumed, not owned by another player
	if type(profile.inventoryAnimals) ~= "table" then
		profile.inventoryAnimals = {}
	end
	local seenUidsInProfile: { [string]: string } = {}
	for uidKey, animal in pairs(profile.inventoryAnimals) do
		if type(animal) ~= "table" or typeof(uidKey) ~= "string" or uidKey == "" then
			profile.inventoryAnimals[uidKey] = nil
			purged += 1
		else
			animal.uid = uidKey
			if consumedSet[uidKey] or seenUidsInProfile[uidKey] or not DataService.RegisterUidOwner(uidKey, userId, "PetInv") then
				warn(string.format("[AntiDupe] Purged duplicate/consumed Pet UID %s from userId %d", uidKey, userId))
				profile.inventoryAnimals[uidKey] = nil
				purged += 1
			else
				seenUidsInProfile[uidKey] = "PetInv"
			end
		end
	end

	-- 2. Validate pendingCrates (in Pen): unique UID, not consumed, not in PetInv
	if type(profile.pendingCrates) ~= "table" then
		profile.pendingCrates = {}
	end
	for uidKey, crate in pairs(profile.pendingCrates) do
		if type(crate) ~= "table" or typeof(uidKey) ~= "string" or uidKey == "" then
			profile.pendingCrates[uidKey] = nil
			purged += 1
		else
			crate.uid = uidKey
			if consumedSet[uidKey] or seenUidsInProfile[uidKey] or not DataService.RegisterUidOwner(uidKey, userId, "PendingCrate") then
				warn(string.format("[AntiDupe] Purged duplicate/consumed PendingCrate UID %s from userId %d", uidKey, userId))
				profile.pendingCrates[uidKey] = nil
				purged += 1
			else
				seenUidsInProfile[uidKey] = "PendingCrate"
			end
		end
	end

	-- 3. Validate crateInventory (in Backpack): mutual exclusion with pendingCrates & PetInv!
	if type(profile.crateInventory) ~= "table" then
		profile.crateInventory = {}
	end
	for uidKey, crate in pairs(profile.crateInventory) do
		if type(crate) ~= "table" or typeof(uidKey) ~= "string" or uidKey == "" then
			profile.crateInventory[uidKey] = nil
			purged += 1
		else
			crate.uid = uidKey
			if consumedSet[uidKey] or seenUidsInProfile[uidKey] or not DataService.RegisterUidOwner(uidKey, userId, "CrateInv") then
				warn(string.format("[AntiDupe] Purged duplicate/consumed Backpack Crate UID %s from userId %d", uidKey, userId))
				profile.crateInventory[uidKey] = nil
				purged += 1
			else
				seenUidsInProfile[uidKey] = "CrateInv"
			end
		end
	end

	-- 4. Deduplicate & verify roamingAnimalUids against verified inventoryAnimals
	if type(profile.roamingAnimalUids) ~= "table" then
		profile.roamingAnimalUids = {}
	end
	local cleanRoaming: { string } = {}
	local roamingSeen: { [string]: boolean } = {}
	for _, rUid in ipairs(profile.roamingAnimalUids) do
		if typeof(rUid) == "string" and not roamingSeen[rUid] and profile.inventoryAnimals[rUid] ~= nil then
			roamingSeen[rUid] = true
			table.insert(cleanRoaming, rUid)
		else
			purged += 1
		end
	end
	profile.roamingAnimalUids = cleanRoaming

	return purged
end

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
		crateInventory = {},
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
		saveVersion = 1,
		itemSerialCounter = 0,
		consumedUids = {},
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
		local gq = raw.settings.graphicsQuality
		if gq ~= "Low" and gq ~= "Medium" and gq ~= "High" then
			raw.settings.graphicsQuality = "Medium"
		end
	end
	raw.penCapacity = math.max(GameConfig.PEN.STARTING_CAPACITY, raw.penCapacity or GameConfig.PEN.STARTING_CAPACITY)
	raw.penUpgradeLevel = math.max(1, raw.penUpgradeLevel or 1)
	raw.treadmillLevel = math.max(1, raw.treadmillLevel or 1)
	raw.saveVersion = math.max(1, tonumber(raw.saveVersion) or 1)
	raw.itemSerialCounter = math.max(0, tonumber(raw.itemSerialCounter) or 0)
	if type(raw.consumedUids) ~= "table" then
		raw.consumedUids = {}
	end
	if type(raw.crateInventory) ~= "table" then
		raw.crateInventory = {}
	end
	if type(raw.pendingCrates) == "table" then
		local usedSlots: { [number]: boolean } = {}
		for _, c in pairs(raw.pendingCrates) do
			if type(c) == "table" and type(c.placedSlot) == "number" then
				usedSlots[c.placedSlot] = true
			end
		end
		for _, c in pairs(raw.pendingCrates) do
			if type(c) == "table" then
				if type(c.sizeScale) ~= "number" then
					c.sizeScale = GameConfig.ComputeCrateScale(tostring(c.rarity or "Common"))
				end
				if type(c.hatchDuration) ~= "number" then
					c.hatchDuration = GameConfig.ComputeHatchSeconds(tostring(c.rarity or "Common"), tostring(c.biomeId or "PineWoods"))
				end
				if type(c.placedSlot) ~= "number" then
					for s = 1, GameConfig.PEN.MAX_PLACED_CRATES do
						if not usedSlots[s] then
							usedSlots[s] = true
							c.placedSlot = s
							break
						end
					end
				end
			end
		end
	end
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
			local lockedByOther = false
			local ok, result = pcall(function()
				return (playerStore :: DataStore):UpdateAsync(key, function(oldData: any)
					local now = os.time()
					if type(oldData) == "table" and type(oldData.sessionLock) == "table" then
						local lockJob = tostring(oldData.sessionLock.jobId or "")
						local lockTime = tonumber(oldData.sessionLock.timestamp) or 0
						if lockJob ~= "" and lockJob ~= SERVER_SESSION_ID and (now - lockTime) < SESSION_LOCK_TTL and attempt < 3 then
							lockedByOther = true
							return nil
						end
					end
					if type(oldData) ~= "table" then
						local fresh = DataService.CreateDefaultProfile()
						fresh.sessionLock = { jobId = SERVER_SESSION_ID, timestamp = now }
						return fresh
					end
					oldData.sessionLock = { jobId = SERVER_SESSION_ID, timestamp = now }
					return oldData
				end)
			end)
			if ok and not lockedByOther then
				loaded = result
				print(string.format("[DataService] Loaded DataStore profile for %s (%s)", player.Name, if result then "existing" else "new"))
				break
			end
			if not ok and string.find(tostring(result), "StudioAccessToApisNotAllowed", 1, true) then
				warn("[DataService] Studio API Access is OFF. Enable 'Enable Studio Access to API Services' in Game Settings -> Security for cloud DataStore persistence in Studio.")
				playerStore = nil
				banStore = nil
				break
			end
			task.wait(0.5 * attempt)
		end
	end

	local profile = migrateProfile(loaded)
	DataService.SanitizeProfileIntegrity(userId, profile)
	profiles[userId] = profile
	return profile
end

function DataService.SaveProfile(player: Player, releaseSessionLock: boolean?): boolean
	local uid = player.UserId
	if savingPlayers[uid] then
		return true
	end
	local profile = profiles[uid]
	if not profile then
		return false
	end
	DataService.SanitizeProfileIntegrity(uid, profile)
	if not playerStore then
		return true
	end
	savingPlayers[uid] = true
	local key = "player_" .. tostring(uid)
	for attempt = 1, 3 do
		local rejectedByVersion = false
		local ok, err = pcall(function()
			(playerStore :: DataStore):UpdateAsync(key, function(oldData: any)
				local oldVer = if type(oldData) == "table" then (tonumber(oldData.saveVersion) or 0) else 0
				local curVer = tonumber(profile.saveVersion) or 1
				if oldVer > curVer then
					warn(string.format("[AntiDupe] Blocked stale save overwrite for %s (LocalVer=%d < CloudVer=%d)", player.Name, curVer, oldVer))
					rejectedByVersion = true
					return nil
				end
				local nextVer = math.max(oldVer, curVer) + 1
				profile.saveVersion = nextVer
				local snapshot = deepCopy(profile)
				if releaseSessionLock then
					snapshot.sessionLock = nil
				else
					snapshot.sessionLock = { jobId = SERVER_SESSION_ID, timestamp = os.time() }
				end
				return snapshot
			end)
		end)
		if ok then
			savingPlayers[uid] = nil
			if not rejectedByVersion then
				print(string.format("[DataService] Saved DataStore profile for %s (Coins=%s, Speed=%s)", player.Name, tostring(profile.coins), tostring(profile.speedStat)))
			end
			return not rejectedByVersion
		end
		if string.find(tostring(err), "StudioAccessToApisNotAllowed", 1, true) then
			playerStore = nil
			savingPlayers[uid] = nil
			return true
		end
		task.wait(0.4 * attempt)
	end
	savingPlayers[uid] = nil
	return false
end

function DataService.GetProfile(player: Player): Types.PlayerProfileSchema?
	return profiles[player.UserId]
end

function DataService.ReleaseProfile(player: Player)
	DataService.SaveProfile(player, true)
	DataService.UnregisterPlayerUids(player.UserId)
	playerTxLocks[player.UserId] = nil
	profiles[player.UserId] = nil
end

function DataService.SyncProfile(player: Player)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	DataService.SanitizeProfileIntegrity(player.UserId, profile)
	local displayedSpeed, baseMult, totalMult, vehMult = computeSpeedMetricsFallback(player, profile)
	player:SetAttribute("EffectiveSpeedStat", displayedSpeed)
	player:SetAttribute("BaseSpeedMult", baseMult)
	player:SetAttribute("TotalSpeedMult", totalMult)
	player:SetAttribute("VehicleSpeedMult", vehMult)

	local ls = player:FindFirstChild("leaderstats")
	local spd = if ls then ls:FindFirstChild("Speed") else nil
	if spd and spd:IsA("StringValue") then
		spd.Value = FormatUtil.Number(displayedSpeed)
	end
	Remotes.Get("ProfileSync"):FireClient(player, profile)
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
