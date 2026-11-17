--!strict
-- AdminService.luau
-- Server-verified RBAC Admin Panel, Moderation (Ban/Kick/Freeze/TP),
-- Live Value Tuner, Custom Animal/Crate Spawner, and "Admin Abuse" Live Server Events.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(game.ReplicatedStorage.Shared.Types)
local AdminConfig = require(game.ReplicatedStorage.Config.AdminConfig)
local AnimalConfig = require(game.ReplicatedStorage.Config.AnimalConfig)
local BiomeConfig = require(game.ReplicatedStorage.Config.BiomeConfig)
local LassoConfig = require(game.ReplicatedStorage.Config.LassoConfig)
local TrailConfig = require(game.ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(game.ReplicatedStorage.Config.VehicleConfig)
local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local FormatUtil = require(game.ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local AdminService = {}

local activeEvents: { [string]: number } = {} -- eventId -> expiresAt os.time()
local liveTuners = {
	cashMult = 1.0,
	speedMult = 1.0,
	poacherSpeedMult = 1.0,
	resistanceMult = 1.0,
}

local selfTools: { [number]: {
	godMode: boolean,
	instantPull: boolean,
	instantUnbox: boolean,
	superSpeed: boolean,
} } = {}

local crateRainCallback: (() -> ())? = nil

function AdminService.RegisterCrateRainCallback(fn: () -> ())
	crateRainCallback = fn
end

function AdminService.GetAdminRank(userId: number): number
	if RunService:IsStudio() or userId <= 0 or userId == game.CreatorId then
		return 3
	end
	return AdminConfig.ROLE_USER_IDS[userId] or 0
end

function AdminService.IsEventActive(eventId: string): boolean
	local exp = activeEvents[eventId]
	if exp and os.time() < exp then
		return true
	end
	activeEvents[eventId] = nil
	return false
end

function AdminService.GetCashMultiplier(): number
	local mult = liveTuners.cashMult
	if AdminService.IsEventActive("GoldenFever") then
		mult *= 25.0
	end
	if AdminService.IsEventActive("PoacherStampede") then
		mult *= 5.0
	end
	return mult
end

function AdminService.GetSpeedMultiplier(): number
	local mult = liveTuners.speedMult
	if AdminService.IsEventActive("GoldenFever") then
		mult *= 25.0
	end
	return mult
end

function AdminService.GetMutationLuckMultiplier(): number
	if AdminService.IsEventActive("MutationParty100x") then
		return 100.0
	end
	return 1.0
end

function AdminService.GetGiantSizeMultiplier(): number
	if AdminService.IsEventActive("MutationParty100x") then
		return 12.0
	end
	return 1.0
end

function AdminService.GetResistanceMultiplier(): number
	if AdminService.IsEventActive("ZeroResistance") then
		return 0.0001
	end
	return liveTuners.resistanceMult
end

function AdminService.GetPoacherSpeedMultiplier(): number
	local mult = liveTuners.poacherSpeedMult
	if AdminService.IsEventActive("PoacherStampede") then
		mult *= 2.5
	end
	return mult
end

function AdminService.HasGodMode(player: Player): boolean
	local t = selfTools[player.UserId]
	return t ~= nil and t.godMode
end

function AdminService.HasInstantPull(player: Player): boolean
	local t = selfTools[player.UserId]
	return (t ~= nil and t.instantPull) or AdminService.IsEventActive("ZeroResistance")
end

function AdminService.HasInstantUnbox(player: Player): boolean
	local t = selfTools[player.UserId]
	return t ~= nil and t.instantUnbox
end

function AdminService.SyncAdminState(targetPlayer: Player?)
	local now = os.time()
	local eventsSnapshot: { [string]: number } = {}
	for id, exp in pairs(activeEvents) do
		if exp > now then
			eventsSnapshot[id] = exp - now
		end
	end
	local playerList = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(playerList, { userId = p.UserId, name = p.Name, displayName = p.DisplayName })
	end

	local function sendTo(p: Player)
		local rank = AdminService.GetAdminRank(p.UserId)
		Remotes.Get("AdminStateSync"):FireClient(p, {
			rank = rank,
			activeEvents = eventsSnapshot,
			liveTuners = liveTuners,
			selfTools = selfTools[p.UserId] or { godMode = false, instantPull = false, instantUnbox = false, superSpeed = false },
			players = playerList,
		})
	end

	if targetPlayer then
		sendTo(targetPlayer)
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if AdminService.GetAdminRank(p.UserId) >= 1 then
				sendTo(p)
			end
		end
	end
end

local function findTargetPlayer(payload: any): Player?
	if type(payload.targetUserId) == "number" then
		return Players:GetPlayerByUserId(payload.targetUserId)
	end
	return nil
end

function AdminService.Init()
	PlotService.RegisterLiveGetters({
		getCashMultiplier = AdminService.GetCashMultiplier,
		getMutationLuckMultiplier = AdminService.GetMutationLuckMultiplier,
		getGiantSizeMultiplier = AdminService.GetGiantSizeMultiplier,
		isInstantUnbox = AdminService.HasInstantUnbox,
	})

	Remotes.Get("AdminCommand").OnServerEvent:Connect(function(adminPlayer, action, payload)
		if typeof(action) ~= "string" then return end
		local rank = AdminService.GetAdminRank(adminPlayer.UserId)
		if rank < 1 then
			warn("[AdminService] Unauthorized command attempt by", adminPlayer.Name)
			return
		end
		payload = if type(payload) == "table" then payload else {}

		-- Rank 1+: Moderation
		if action == "Kick" then
			local target = findTargetPlayer(payload)
			if target and target ~= adminPlayer then
				target:Kick(tostring(payload.reason or "Kicked by Moderator"))
			end
		elseif action == "Ban" then
			local targetId = tonumber(payload.targetUserId)
			if targetId and targetId ~= adminPlayer.UserId then
				local dur = tonumber(payload.durationSeconds) or 0
				DataService.BanUser(targetId, dur, tostring(payload.reason or "Banned by Admin"), adminPlayer.Name)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Banned UserId " .. targetId, Color3.fromRGB(255, 96, 96))
			end
		elseif action == "Unban" then
			local targetId = tonumber(payload.targetUserId)
			if targetId then
				DataService.UnbanUser(targetId)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Unbanned UserId " .. targetId, Color3.fromRGB(84, 245, 148))
			end
		elseif action == "TeleportTo" or action == "Bring" then
			local target = findTargetPlayer(payload)
			local aChar = adminPlayer.Character
			local tChar = if target then target.Character else nil
			local aRoot = if aChar then aChar:FindFirstChild("HumanoidRootPart") else nil
			local tRoot = if tChar then tChar:FindFirstChild("HumanoidRootPart") else nil
			if aRoot and tRoot and aRoot:IsA("BasePart") and tRoot:IsA("BasePart") then
				if action == "TeleportTo" then
					aRoot.CFrame = tRoot.CFrame + Vector3.new(0, 4, 4)
				else
					tRoot.CFrame = aRoot.CFrame + Vector3.new(0, 4, 4)
				end
			end
		elseif action == "Freeze" or action == "Unfreeze" then
			local target = findTargetPlayer(payload)
			if target and target.Character then
				local hum = target.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = if action == "Freeze" then 0 else GameConfig.SPEED.BASE_WALK_SPEED
					target:SetAttribute("FrozenByAdmin", action == "Freeze")
				end
			end
		-- Rank 2+: Economy, Spawning, & Admin Abuse Events
		elseif rank >= 2 then
			if action == "GiveCoins" then
				local target = findTargetPlayer(payload) or adminPlayer
				local prof = DataService.GetProfile(target)
				local amt = FormatUtil.ParseCompactNumber(tostring(payload.amount or "1M")) or 1000000
				if prof then
					prof.coins = math.max(0, prof.coins + amt)
					DataService.SyncProfile(target)
					PlotService.RefreshPlotBoardVisuals(target)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Gave $" .. FormatUtil.Number(amt) .. " to " .. target.Name, Color3.fromRGB(84, 245, 148))
				end
			elseif action == "GiveSpeed" then
				local target = findTargetPlayer(payload) or adminPlayer
				local prof = DataService.GetProfile(target)
				local amt = FormatUtil.ParseCompactNumber(tostring(payload.amount or "100")) or 100
				if prof then
					prof.speedStat = math.max(0, prof.speedStat + amt)
					DataService.SyncProfile(target)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Added " .. FormatUtil.Number(amt) .. " Speed to " .. target.Name, Color3.fromRGB(58, 188, 255))
				end
			elseif action == "SetPenCapacity" then
				local target = findTargetPlayer(payload) or adminPlayer
				local prof = DataService.GetProfile(target)
				local cap = math.clamp(tonumber(payload.capacity) or 20, 8, 25)
				if prof then
					prof.penCapacity = cap
					prof.penUpgradeLevel = math.max(1, cap - GameConfig.PEN.STARTING_CAPACITY + 1)
					DataService.SyncProfile(target)
					PlotService.RefreshPlotBoardVisuals(target)
				end
			elseif action == "UnlockAll" then
				local target = findTargetPlayer(payload) or adminPlayer
				local prof = DataService.GetProfile(target)
				if prof then
					for _, l in ipairs(LassoConfig) do prof.ownedLassos[l.id] = true end
					prof.equippedLasso = LassoConfig[#LassoConfig].id
					for _, t in ipairs(TrailConfig) do prof.ownedTrails[t.id] = true end
					prof.equippedTrail = TrailConfig[#TrailConfig].id
					for _, v in ipairs(VehicleConfig) do prof.ownedVehicles[v.id] = true end
					prof.equippedVehicle = VehicleConfig[#VehicleConfig].id
					for _, s in ipairs(AnimalConfig.ALL) do
						PlotService.RegisterAnimalDiscovery(prof, s.id, 2.5, "Celestial")
					end
					DataService.SyncProfile(target)
					PlotService.RefreshPlotBoardVisuals(target)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Unlocked all 10 Lassos, 10 Trails, 6 Vehicles & 63 Index!", Color3.fromRGB(255, 214, 72))
				end
			elseif action == "SpawnAnimal" then
				local target = findTargetPlayer(payload) or adminPlayer
				local speciesId = tostring(payload.speciesId or "MythicWhiteTiger")
				local mutation = tostring(payload.mutation or "Rainbow") :: Types.AnimalMutation
				local sizeRatio = math.clamp(tonumber(payload.sizeRatio) or 2.5, 0.5, 10.0)
				local animal = PlotService.GrantAnimalToPlayer(target, speciesId, sizeRatio, mutation, {
					originSource = "Admin",
				})
				if animal then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Spawned %s (%s, %.1fx) for %s!", speciesId, mutation, sizeRatio, target.Name), Color3.fromRGB(224, 92, 255))
				end
			elseif action == "SetLiveMultiplier" then
				local key = tostring(payload.key or "")
				local val = math.clamp(tonumber(payload.value) or 1.0, 0.05, 10000)
				if (liveTuners :: any)[key] ~= nil then
					(liveTuners :: any)[key] = val
					for _, p in ipairs(Players:GetPlayers()) do
						DataService.SyncProfile(p)
					end
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Live %s set to %.2fx", key, val), Color3.fromRGB(0, 245, 212))
				end
			elseif action == "TriggerEvent" then
				local eventId = tostring(payload.eventId or "")
				local def = (AdminConfig.ADMIN_ABUSE_EVENTS :: any)[eventId]
				if def then
					activeEvents[eventId] = os.time() + def.durationSeconds
					Remotes.Get("GlobalEventBanner"):FireAllClients(def.title .. " — " .. def.description, def.color, 9)
					for _, p in ipairs(Players:GetPlayers()) do
						DataService.SyncProfile(p)
					end
					if eventId == "CrateRain" and crateRainCallback then
						crateRainCallback()
					elseif eventId == "TitanicZoo" then
						for _, p in ipairs(Players:GetPlayers()) do
							local prof = DataService.GetProfile(p)
							if prof then
								for _, uid in ipairs(prof.roamingAnimalUids) do
									local a = prof.inventoryAnimals[uid]
									if a then a.sizeRatio = math.max(a.sizeRatio, 2.8) end
								end
								PlotService.BroadcastAllPlotsSync()
							end
						end
					end
				end
			elseif action == "StopAllEvents" then
				table.clear(activeEvents)
				liveTuners.cashMult = 1.0
				liveTuners.speedMult = 1.0
				liveTuners.poacherSpeedMult = 1.0
				liveTuners.resistanceMult = 1.0
				for _, p in ipairs(Players:GetPlayers()) do
					DataService.SyncProfile(p)
				end
				Remotes.Get("GlobalEventBanner"):FireAllClients("Admin ended active server events.", Color3.fromRGB(180, 190, 210), 4)
			elseif action == "Broadcast" then
				local msg = string.sub(tostring(payload.message or "Hello Rangers!"), 1, 160)
				Remotes.Get("GlobalEventBanner"):FireAllClients("[ADMIN " .. adminPlayer.DisplayName .. "]: " .. msg, Color3.fromRGB(255, 214, 62), 7)
			elseif action == "ToggleSelfTool" then
				local key = tostring(payload.tool or "")
				selfTools[adminPlayer.UserId] = selfTools[adminPlayer.UserId] or { godMode = false, instantPull = false, instantUnbox = false, superSpeed = false }
				local st = selfTools[adminPlayer.UserId]
				if (st :: any)[key] ~= nil then
					(st :: any)[key] = not (st :: any)[key]
					adminPlayer:SetAttribute("AdminSuperSpeed", st.superSpeed)
				end
			end
		end

		AdminService.SyncAdminState(nil)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(1.5, function()
			AdminService.SyncAdminState(player)
			AdminService.SyncAdminState(nil)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		selfTools[player.UserId] = nil
		task.defer(function()
			AdminService.SyncAdminState(nil)
		end)
	end)
end

return AdminService
