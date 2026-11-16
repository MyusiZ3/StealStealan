--!strict
-- LeaderboardService.luau
-- Global OrderedDataStore Leaderboard for Top 100 Money/s, Top 100 Speed, and Top 100 Playtime.
-- Refreshes every 5 minutes (300 seconds) + initial server startup load.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local LeaderboardService = {}

local REFRESH_INTERVAL = 300 -- 5 minutes
local MAX_ENTRIES = 100

local moneyStore: OrderedDataStore? = nil
local speedStore: OrderedDataStore? = nil
local playtimeStore: OrderedDataStore? = nil

pcall(function()
	moneyStore = DataStoreService:GetOrderedDataStore("GlobalTopMoneyRate_v1")
	speedStore = DataStoreService:GetOrderedDataStore("GlobalTopSpeed_v1")
	playtimeStore = DataStoreService:GetOrderedDataStore("GlobalTopPlaytime_v1")
end)

export type LeaderboardEntry = {
	userId: number,
	username: string,
	value: number,
}

export type LeaderboardPayload = {
	money: { LeaderboardEntry },
	speed: { LeaderboardEntry },
	playtime: { LeaderboardEntry },
	nextRefreshAt: number,
	updatedAt: number,
}

local sessionJoinAt: { [number]: number } = {}
local usernameCache: { [number]: string } = {}

local cachedPayload: LeaderboardPayload = {
	money = {},
	speed = {},
	playtime = {},
	nextRefreshAt = os.time() + REFRESH_INTERVAL,
	updatedAt = os.time(),
}

-- Monotonically-preserving log10 encoding so numbers up to 1e308 fit cleanly in OrderedDataStore signed int64
local LOG_SCALE = 10000000
local function encodeLogValue(val: number): number
	if val <= 0 then
		return 0
	end
	return math.floor(math.log10(val + 1) * LOG_SCALE)
end

local function decodeLogValue(encoded: number): number
	if encoded <= 0 then
		return 0
	end
	return math.max(0, math.pow(10, encoded / LOG_SCALE) - 1)
end

local function resolveUsername(userId: number): string
	if userId <= 0 then
		return "Ranger"
	end
	if usernameCache[userId] then
		return usernameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		usernameCache[userId] = online.Name
		return online.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" and name ~= "" then name else ("Player_" .. tostring(userId))
	usernameCache[userId] = resolved
	return resolved
end

local function getPlayerSessionPlaytime(player: Player, profile: any): number
	local baseTime = (profile.analyticsMeta and profile.analyticsMeta.totalPlaytimeSeconds) or 0
	local joined = sessionJoinAt[player.UserId] or os.time()
	return math.max(0, baseTime + math.max(0, os.time() - joined))
end

local function fetchTop100FromStore(
	store: OrderedDataStore?,
	isLogEncoded: boolean,
	liveMap: { [number]: { username: string, value: number } }
): { LeaderboardEntry }
	local byUser: { [number]: LeaderboardEntry } = {}

	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, MAX_ENTRIES)
		end)
		if ok and pages then
			local curOk, pageItems = pcall(function()
				return pages:GetCurrentPage()
			end)
			if curOk and type(pageItems) == "table" then
				for _, item in ipairs(pageItems) do
					local uid = tonumber(item.key)
					local rawVal = tonumber(item.value) or 0
					if uid and uid > 0 then
						local val = if isLogEncoded then decodeLogValue(rawVal) else rawVal
						byUser[uid] = {
							userId = uid,
							username = resolveUsername(uid),
							value = val,
						}
					end
				end
			end
		end
	end

	-- Merge live online players so current players always reflect up-to-date values
	for uid, info in pairs(liveMap) do
		local existing = byUser[uid]
		if not existing or info.value >= existing.value then
			byUser[uid] = {
				userId = uid,
				username = info.username,
				value = info.value,
			}
		end
	end

	local list: { LeaderboardEntry } = {}
	for _, entry in pairs(byUser) do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if a.value == b.value then
			return a.userId < b.userId
		end
		return a.value > b.value
	end)
	if #list > MAX_ENTRIES then
		for i = #list, MAX_ENTRIES + 1, -1 do
			table.remove(list, i)
		end
	end
	return list
end

function LeaderboardService.RefreshGlobalLeaderboards()
	local liveMoney: { [number]: { username: string, value: number } } = {}
	local liveSpeed: { [number]: { username: string, value: number } } = {}
	local livePlaytime: { [number]: { username: string, value: number } } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.GetProfile(player)
		if profile then
			usernameCache[player.UserId] = player.Name
			local perSec = PlotService.ComputePlayerIncomePerSec(player, profile)
			local spd = profile.speedStat or 0
			local pTime = getPlayerSessionPlaytime(player, profile)

			liveMoney[player.UserId] = { username = player.Name, value = perSec }
			liveSpeed[player.UserId] = { username = player.Name, value = spd }
			livePlaytime[player.UserId] = { username = player.Name, value = pTime }

			local key = tostring(player.UserId)
			if moneyStore then
				pcall(function()
					moneyStore:SetAsync(key, encodeLogValue(perSec))
				end)
			end
			if speedStore then
				pcall(function()
					speedStore:SetAsync(key, encodeLogValue(spd))
				end)
			end
			if playtimeStore then
				pcall(function()
					playtimeStore:SetAsync(key, math.floor(pTime))
				end)
			end
		end
	end

	local moneyList = fetchTop100FromStore(moneyStore, true, liveMoney)
	local speedList = fetchTop100FromStore(speedStore, true, liveSpeed)
	local playList = fetchTop100FromStore(playtimeStore, false, livePlaytime)

	local now = os.time()
	cachedPayload = {
		money = moneyList,
		speed = speedList,
		playtime = playList,
		nextRefreshAt = now + REFRESH_INTERVAL,
		updatedAt = now,
	}

	Remotes.Get("LeaderboardSync"):FireAllClients(cachedPayload)
end

function LeaderboardService.SendToPlayer(player: Player)
	Remotes.Get("LeaderboardSync"):FireClient(player, cachedPayload)
end

function LeaderboardService.OnPlayerReady(player: Player)
	sessionJoinAt[player.UserId] = os.time()
	usernameCache[player.UserId] = player.Name
	task.defer(function()
		task.wait(0.8)
		if not player.Parent then
			return
		end
		local hasPlayer = false
		for _, e in ipairs(cachedPayload.money) do
			if e.userId == player.UserId then
				hasPlayer = true
				break
			end
		end
		if #cachedPayload.money == 0 or not hasPlayer then
			LeaderboardService.RefreshGlobalLeaderboards()
		else
			LeaderboardService.SendToPlayer(player)
		end
	end)
end

function LeaderboardService.Init()
	Players.PlayerAdded:Connect(function(player)
		sessionJoinAt[player.UserId] = os.time()
		usernameCache[player.UserId] = player.Name
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessionJoinAt[player.UserId] = nil
	end)

	-- Refresh global leaderboards every 5 minutes (300s)
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			LeaderboardService.RefreshGlobalLeaderboards()
		end
	end)
end

return LeaderboardService
