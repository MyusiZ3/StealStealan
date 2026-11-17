--!strict
-- AdminService.luau
-- Zero-Trust Server-Verified Admin RBAC (UserId + Username), Dynamic ServerStorage UI Provisioning,
-- Superadmin-Only Titles (Owner / Admin), Overhead & Chat Tags, Moderation (Kill/Kick/Ban/TP/Freeze),
-- Economy (Give/Set Money, Give/Set Speed, Tuners), World & Pet Spawner, & Admin Abuse Events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)
local LassoConfig = require(ReplicatedStorage.Config.LassoConfig)
local TrailConfig = require(ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(ReplicatedStorage.Config.VehicleConfig)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AdminConfig = require(script.Parent.AdminConfig)
local DataService = require(script.Parent.DataService)
local PassManager = require(script.Parent.PassManager)
local PlotService = require(script.Parent.PlotService)

local AdminService = {}

type VerifiedRoleRecord = {
	rank: number,
	title: string,
	isRoot: boolean,
	username: string,
}

local verifiedRoles: { [number]: VerifiedRoleRecord } = {}
local activeEvents: { [string]: number } = {}
local activeEventDurations: { [string]: number } = {}
local liveTuners = {
	cashMult = 1.0,
	speedMult = 1.0,
	poacherSpeedMult = 1.0,
	resistanceMult = 1.0,
	rarityLuckMult = 1.0,
	mutationLuckMult = 1.0,
}

local rarityWeightOverrides: { [string]: number } = {}
local mutationWeightOverrides: { [string]: number } = {}
local forcedWildMutation: string = "Random"

local selfTools: { [number]: {
	godMode: boolean,
	instantPull: boolean,
	instantUnbox: boolean,
	superSpeed: boolean,
	invisible: boolean,
} } = {}

local commandCooldowns: { [string]: number } = {}

local crateRainCallback: (() -> ())? = nil
local worldSpawnerCallback: ((string, Types.AnimalRarity?, string?, Vector3?) -> boolean)? = nil
local killCleanupCallback: ((Player, Vector3) -> ())? = nil
local waveResetCallback: (() -> ())? = nil

function AdminService.RegisterCrateRainCallback(fn: () -> ())
	crateRainCallback = fn
end

function AdminService.RegisterWorldSpawnerCallback(fn: (string, Types.AnimalRarity?, string?, Vector3?) -> boolean)
	worldSpawnerCallback = fn
end

function AdminService.RegisterKillCleanupCallback(fn: (Player, Vector3) -> ())
	killCleanupCallback = fn
end

function AdminService.RegisterWaveResetCallback(fn: () -> ())
	waveResetCallback = fn
end

local function isFiniteNonNeg(n: any, maxLimit: number): number?
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(n, 0, maxLimit)
end

local function verifyPlayerRole(player: Player): VerifiedRoleRecord
	local uid = player.UserId
	local uname = player.Name
	local lowerName = string.lower(uname)

	-- 1. Place Creator (when User-owned)
	if uid > 0 and game.CreatorType == Enum.CreatorType.User and uid == game.CreatorId then
		return { rank = 3, title = "Owner", isRoot = true, username = uname }
	end

	-- 2. Static Root Owners (Requires BOTH UserId and exact Username match)
	for _, entry in ipairs(AdminConfig.ROOT_OWNERS) do
		if entry.userId == uid and string.lower(entry.username) == lowerName then
			return { rank = 3, title = "Owner", isRoot = true, username = uname }
		end
	end

	-- 3. Static Admins (Requires BOTH UserId and exact Username match)
	for _, entry in ipairs(AdminConfig.STATIC_ADMINS) do
		if entry.userId == uid and string.lower(entry.username) == lowerName then
			return { rank = entry.rank, title = entry.title, isRoot = false, username = uname }
		end
	end

	-- 4. Runtime / DataStore Superadmin Grants (Requires BOTH UserId and exact Username match)
	local grant = DataService.GetAdminRoleGrant(uid, uname)
	if grant then
		return { rank = grant.rank, title = grant.title, isRoot = false, username = uname }
	end

	-- 5. Studio local test convenience (strictly isolated to Studio Creator / Player1, NOT live servers & NOT Player2 -2)
	if RunService:IsStudio() then
		if uid == -1 or uid == game.CreatorId or lowerName == "archenciel32" then
			return { rank = 3, title = "Owner", isRoot = true, username = uname }
		end
	end

	return { rank = 0, title = "", isRoot = false, username = uname }
end

local function refreshRoleCacheForPlayer(player: Player): VerifiedRoleRecord
	local rec = verifyPlayerRole(player)
	verifiedRoles[player.UserId] = rec
	player:SetAttribute("AdminRank", rec.rank)
	player:SetAttribute("AdminTitle", rec.title)
	return rec
end

function AdminService.GetVerifiedRank(player: Player): number
	local cached = verifiedRoles[player.UserId]
	if cached and string.lower(cached.username) == string.lower(player.Name) then
		return cached.rank
	end
	return refreshRoleCacheForPlayer(player).rank
end

function AdminService.GetAdminRank(userId: number): number
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return AdminService.GetVerifiedRank(p)
	end
	local cached = verifiedRoles[userId]
	return if cached then cached.rank else 0
end

local function stripAdminUI(player: Player)
	local pgui = player:FindFirstChildOfClass("PlayerGui")
	if pgui then
		local existing = pgui:FindFirstChild("AdminControlPanel")
		if existing then
			existing:Destroy()
		end
	end
end

local function provisionAdminUI(player: Player)
	if AdminService.GetVerifiedRank(player) < 2 then
		stripAdminUI(player)
		return
	end
	local pgui = player:WaitForChild("PlayerGui", 10)
	if not pgui or not player.Parent then
		return
	end
	if pgui:FindFirstChild("AdminControlPanel") then
		return
	end

	local adminUiFolder = script.Parent:FindFirstChild("AdminUI")
	local panelScriptTemplate = if adminUiFolder then adminUiFolder:FindFirstChild("AdminPanel") else nil
	if not panelScriptTemplate or not panelScriptTemplate:IsA("LocalScript") then
		warn("[AdminService] ServerScriptService.Services.AdminUI.AdminPanel LocalScript missing!")
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AdminControlPanel"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 20

	local clonedScript = panelScriptTemplate:Clone()
	clonedScript.Parent = screenGui
	screenGui.Parent = pgui
end

local function applyInvisibilityToCharacter(player: Player, isInvisible: boolean)
	local char = player.Character
	if not char or not char.Parent then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if d:GetAttribute("_AdminOrigTrans") == nil then
				d:SetAttribute("_AdminOrigTrans", d.Transparency)
			end
			d.Transparency = if isInvisible then 1 else (tonumber(d:GetAttribute("_AdminOrigTrans")) or 0)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			if d:GetAttribute("_AdminOrigTrans") == nil then
				d:SetAttribute("_AdminOrigTrans", d.Transparency)
			end
			d.Transparency = if isInvisible then 1 else (tonumber(d:GetAttribute("_AdminOrigTrans")) or 0)
		elseif d:IsA("BillboardGui") and d.Name == "AdminRoleTag" then
			d.Enabled = not isInvisible
		end
	end
end

function AdminService.ApplyCharacterTag(player: Player, character: Model?)
	local char = character or player.Character
	if not char or not char.Parent then return end

	local oldTag = char:FindFirstChild("AdminRoleTag", true)
	if oldTag then oldTag:Destroy() end

	local rec = verifiedRoles[player.UserId] or refreshRoleCacheForPlayer(player)
	if rec.rank < 2 or rec.title == "" then
		return
	end

	local titleMeta = (AdminConfig.TITLES :: any)[rec.title] or AdminConfig.TITLES.Admin
	local head = (char:FindFirstChild("Head") or char:WaitForChild("Head", 3) or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not head or not head:IsA("BasePart") then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "AdminRoleTag"
	bb.Size = UDim2.fromOffset(170, 34)
	bb.StudsOffset = Vector3.new(0, 2.55, 0)
	bb.MaxDistance = 85
	bb.AlwaysOnTop = false
	bb.Adornee = head
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Name = "RoleTitleLabel"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = titleMeta.badgeText
	lbl.TextColor3 = titleMeta.color
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = bb

	local st = Instance.new("UIStroke")
	st.Thickness = 2.6
	st.Color = titleMeta.strokeColor
	st.Parent = lbl

	local tools = selfTools[player.UserId]
	if tools and tools.invisible then
		applyInvisibilityToCharacter(player, true)
	end
end

function AdminService.IsEventActive(eventId: string): boolean
	local exp = activeEvents[eventId]
	if exp and os.time() < exp then
		return true
	end
	activeEvents[eventId] = nil
	activeEventDurations[eventId] = nil
	return false
end

local function syncEventWorldAttributes()
	Workspace:SetAttribute("InstantUnboxParty", AdminService.IsEventActive("InstantUnboxParty"))
	Workspace:SetAttribute("TitanicZooActive", AdminService.IsEventActive("TitanicZoo"))
end

local function refreshAllPlayersEconomy()
	for _, p in ipairs(Players:GetPlayers()) do
		PlotService.RefreshPlotBoardVisuals(p)
		DataService.SyncProfile(p)
	end
end

function AdminService.GetCashMultiplier(): number
	local mult = liveTuners.cashMult
	if AdminService.IsEventActive("DoubleCash") then mult *= 2.0 end
	if AdminService.IsEventActive("GoldenFever") then mult *= 25.0 end
	if AdminService.IsEventActive("PoacherStampede") then mult *= 5.0 end
	return mult
end

function AdminService.GetSpeedMultiplier(): number
	local mult = liveTuners.speedMult
	if AdminService.IsEventActive("DoubleSpeed") then mult *= 2.0 end
	if AdminService.IsEventActive("GoldenFever") then mult *= 25.0 end
	return mult
end

function AdminService.GetRarityLuckMultiplier(): number
	local mult = liveTuners.rarityLuckMult
	if AdminService.IsEventActive("SuperLuck5x") then mult *= 5.0 end
	if AdminService.IsEventActive("CrateRain") then mult *= 2.0 end
	return mult
end

function AdminService.GetMutationLuckMultiplier(): number
	local eventMult = if AdminService.IsEventActive("MutationParty100x") then 100.0 else 1.0
	return liveTuners.mutationLuckMult * eventMult
end

function AdminService.GetRarityWeightOverrides(): { [string]: number }?
	return if next(rarityWeightOverrides) ~= nil then rarityWeightOverrides else nil
end

function AdminService.GetMutationWeightOverrides(): { [string]: number }?
	return if next(mutationWeightOverrides) ~= nil then mutationWeightOverrides else nil
end

function AdminService.GetForcedWildMutation(): string?
	return if forcedWildMutation ~= "Random" then forcedWildMutation else nil
end

function AdminService.GetGiantSizeMultiplier(): number
	if AdminService.IsEventActive("MutationParty100x") then
		return 12.0
	elseif AdminService.IsEventActive("TitanicZoo") then
		return 2.5
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
	if AdminService.IsEventActive("PoacherStampede") then mult *= 2.5 end
	return mult
end

function AdminService.HasGodMode(player: Player): boolean
	local t = selfTools[player.UserId]
	return t ~= nil and t.godMode and AdminService.GetVerifiedRank(player) >= 2
end

function AdminService.HasInstantPull(player: Player): boolean
	local t = selfTools[player.UserId]
	return (t ~= nil and t.instantPull and AdminService.GetVerifiedRank(player) >= 2) or AdminService.IsEventActive("ZeroResistance")
end

function AdminService.HasInstantUnbox(player: Player): boolean
	local t = selfTools[player.UserId]
	return (t ~= nil and t.instantUnbox and AdminService.GetVerifiedRank(player) >= 2) or AdminService.IsEventActive("InstantUnboxParty")
end

local function buildEventsCatalog(): { { id: string, order: number, icon: string, shortLabel: string, title: string, description: string, durationSeconds: number, color: Color3 } }
	local out = {}
	for id, def in pairs(AdminConfig.ADMIN_ABUSE_EVENTS) do
		table.insert(out, {
			id = id,
			order = def.order or 99,
			icon = def.icon or "🔥",
			shortLabel = def.shortLabel or def.title,
			title = def.title,
			description = def.description or "",
			durationSeconds = def.durationSeconds or 120,
			color = def.color,
		})
	end
	table.sort(out, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.id < b.id
	end)
	return out
end

function AdminService.BroadcastActiveBuffs(targetPlayer: Player?)
	local unixNow = os.time()
	local serverNow = math.floor(Workspace:GetServerTimeNow())
	local buffs = {}

	for eventId, exp in pairs(activeEvents) do
		local rem = exp - unixNow
		if rem > 0 then
			local def = (AdminConfig.ADMIN_ABUSE_EVENTS :: any)[eventId]
			if def then
				local c: Color3 = def.color or Color3.fromRGB(255, 214, 72)
				table.insert(buffs, {
					id = eventId,
					icon = def.icon or "🔥",
					shortLabel = def.shortLabel or def.title,
					detail = def.description or def.title,
					color = { math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255) },
					endsAt = serverNow + rem,
					duration = activeEventDurations[eventId] or def.durationSeconds,
					order = def.order or 50,
				})
			end
		else
			activeEvents[eventId] = nil
			activeEventDurations[eventId] = nil
		end
	end

	local serverLuckRem = PassManager.GetServerLuckRemainingSeconds()
	if serverLuckRem > 0 then
		table.insert(buffs, {
			id = "ServerLuckBoost10x",
			icon = "✨",
			shortLabel = "10x Mut Luck",
			detail = "10x Server Mutation Luck Boost!",
			color = { 224, 92, 255 },
			endsAt = serverNow + serverLuckRem,
			duration = 900,
			order = 100,
		})
	end

	local function pushLiveTuner(key: string, val: number, icon: string, label: string, detail: string, rgb: { number }, order: number)
		if math.abs(val - 1.0) > 0.001 then
			table.insert(buffs, {
				id = "Live_" .. key,
				icon = icon,
				shortLabel = label,
				detail = detail,
				color = rgb,
				endsAt = nil,
				duration = 0,
				order = order,
			})
		end
	end

	pushLiveTuner("cashMult", liveTuners.cashMult, "💰", FormatUtil.Number(liveTuners.cashMult) .. "x Cash", string.format("Live Admin Cash Multiplier (%.2gx)", liveTuners.cashMult), { 45, 212, 191 }, 201)
	pushLiveTuner("speedMult", liveTuners.speedMult, "⚡", FormatUtil.Number(liveTuners.speedMult) .. "x Speed", string.format("Live Admin Speed Multiplier (%.2gx)", liveTuners.speedMult), { 56, 189, 248 }, 202)
	pushLiveTuner("rarityLuckMult", liveTuners.rarityLuckMult, "🎲", FormatUtil.Number(liveTuners.rarityLuckMult) .. "x Crate Luck", string.format("Live Crate Rarity Luck (%.2gx)", liveTuners.rarityLuckMult), { 250, 204, 21 }, 203)
	pushLiveTuner("mutationLuckMult", liveTuners.mutationLuckMult, "🧬", FormatUtil.Number(liveTuners.mutationLuckMult) .. "x Mut Luck", string.format("Live Mutation Luck (%.2gx)", liveTuners.mutationLuckMult), { 192, 132, 252 }, 204)
	pushLiveTuner("resistanceMult", liveTuners.resistanceMult, "🧲", string.format("%.2gx Res", liveTuners.resistanceMult), string.format("Live Crate Resistance Multiplier (%.2gx)", liveTuners.resistanceMult), { 94, 234, 212 }, 205)
	pushLiveTuner("poacherSpeedMult", liveTuners.poacherSpeedMult, "🚨", string.format("%.2gx Poacher", liveTuners.poacherSpeedMult), string.format("Live Poacher Speed Multiplier (%.2gx)", liveTuners.poacherSpeedMult), { 248, 113, 113 }, 206)

	table.sort(buffs, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.id < b.id
	end)

	local payload = {
		serverNow = serverNow,
		buffs = buffs,
	}
	if targetPlayer then
		Remotes.Get("ActiveEventsSync"):FireClient(targetPlayer, payload)
	else
		Remotes.Get("ActiveEventsSync"):FireAllClients(payload)
	end
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
		local rec = verifiedRoles[p.UserId] or refreshRoleCacheForPlayer(p)
		table.insert(playerList, {
			userId = p.UserId,
			name = p.Name,
			displayName = p.DisplayName,
			rank = rec.rank,
			title = rec.title,
			isRoot = rec.isRoot,
		})
	end
	local eventsCatalog = buildEventsCatalog()

	local function sendTo(p: Player)
		local rec = verifiedRoles[p.UserId] or refreshRoleCacheForPlayer(p)
		if rec.rank < 2 then
			Remotes.Get("AdminStateSync"):FireClient(p, {
				rank = 0,
				title = "",
				isRoot = false,
			})
			return
		end
		Remotes.Get("AdminStateSync"):FireClient(p, {
			rank = rec.rank,
			title = rec.title,
			isRoot = rec.isRoot,
			activeEvents = eventsSnapshot,
			eventsCatalog = eventsCatalog,
			liveTuners = liveTuners,
			rarityWeightOverrides = rarityWeightOverrides,
			mutationWeightOverrides = mutationWeightOverrides,
			forcedWildMutation = forcedWildMutation,
			selfTools = selfTools[p.UserId] or { godMode = false, instantPull = false, instantUnbox = false, superSpeed = false, invisible = false },
			players = playerList,
		})
	end

	if targetPlayer then
		sendTo(targetPlayer)
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if AdminService.GetVerifiedRank(p) >= 2 then
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

local function canModerateTarget(caller: Player, callerRank: number, target: Player): (boolean, string?)
	local targetRec = verifiedRoles[target.UserId] or refreshRoleCacheForPlayer(target)
	if target == caller then
		return false, "Cannot target yourself with this moderation action."
	end
	if targetRec.isRoot then
		return false, "Root Owner is protected against moderation."
	end
	if targetRec.rank >= callerRank then
		return false, "Cannot moderate an equal or higher rank."
	end
	return true, nil
end

local function filterBroadcastMessage(player: Player, rawText: string): string
	local clean = string.sub(rawText, 1, 140)
	local ok, filtered = pcall(function()
		local res = TextService:FilterStringAsync(clean, player.UserId, Enum.TextFilterContext.PublicChat)
		return res:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(filtered) == "string" and #filtered > 0 then
		return filtered
	end
	return clean
end

local function getZoneTeleportCFrame(zoneId: string): CFrame
	if zoneId == "SafeZone" then
		return CFrame.new(0, 5, 110)
	end
	for _, b in ipairs(BiomeConfig) do
		if b.id == zoneId then
			return CFrame.new(0, 8, (b.zStart + b.zEnd) * 0.5)
		end
	end
	return CFrame.new(0, 5, 110)
end

local function resolveCrateSpecies(biomeId: string, rarity: string, requestedSpeciesId: string?, useSelectedSpecies: boolean): AnimalConfig.AnimalSpec
	if useSelectedSpecies and requestedSpeciesId and requestedSpeciesId ~= "" then
		local explicit = AnimalConfig.GetById(requestedSpeciesId)
		if explicit then
			return explicit
		end
	end
	local exact: { AnimalConfig.AnimalSpec } = {}
	local sameRarity: { AnimalConfig.AnimalSpec } = {}
	for _, s in ipairs(AnimalConfig.ALL) do
		if s.rarity == rarity then
			table.insert(sameRarity, s)
			if s.biomeId == biomeId then
				table.insert(exact, s)
			end
		end
	end
	if #exact > 0 then
		return exact[math.random(1, #exact)]
	elseif #sameRarity > 0 then
		return sameRarity[math.random(1, #sameRarity)]
	end
	return AnimalConfig.RollSpeciesForBiome(biomeId, 1.0, nil)
end

local function sanitizeMutation(rawMut: string?): Types.AnimalMutation
	local s = tostring(rawMut or "None")
	for _, m in ipairs(GameConfig.MUTATION_ORDER) do
		if m == s then
			return m :: Types.AnimalMutation
		end
	end
	return "None"
end

function AdminService.OnPlayerJoined(player: Player)
	local rec = refreshRoleCacheForPlayer(player)
	if rec.rank >= 2 then
		provisionAdminUI(player)
		task.delay(1.2, function()
			if not player.Parent then return end
			AdminService.ApplyCharacterTag(player, nil)
			AdminService.SyncAdminState(player)
			AdminService.SyncAdminState(nil)
			AdminService.BroadcastActiveBuffs(player)
			local titleMeta = (AdminConfig.TITLES :: any)[rec.title] or AdminConfig.TITLES.Admin
			Remotes.Get("NotifyClient"):FireAllClients(
				string.format("%s %s joined the server!", titleMeta.badgeText, player.DisplayName),
				titleMeta.color
			)
		end)
	else
		stripAdminUI(player)
		task.delay(1.2, function()
			if player.Parent then
				AdminService.SyncAdminState(nil)
				AdminService.BroadcastActiveBuffs(player)
			end
		end)
	end
end

function AdminService.Init()
	PlotService.RegisterLiveGetters({
		getCashMultiplier = AdminService.GetCashMultiplier,
		getMutationLuckMultiplier = AdminService.GetMutationLuckMultiplier,
		getGiantSizeMultiplier = AdminService.GetGiantSizeMultiplier,
		isInstantUnbox = AdminService.HasInstantUnbox,
		getMutationWeightOverrides = AdminService.GetMutationWeightOverrides,
		getForcedWildMutation = AdminService.GetForcedWildMutation,
	})
	syncEventWorldAttributes()

	Remotes.Get("AdminCommand").OnServerEvent:Connect(function(adminPlayer, action, payload)
		if typeof(action) ~= "string" then return end

		-- Re-verify dual UserId + Username identity on EVERY server remote invocation!
		local rank = AdminService.GetVerifiedRank(adminPlayer)
		if rank < 2 then
			warn(string.format("[AdminSecurity] Blocked unauthorized AdminCommand '%s' from %s (%d)", action, adminPlayer.Name, adminPlayer.UserId))
			stripAdminUI(adminPlayer)
			return
		end

		payload = if type(payload) == "table" then payload else {}
		local subKey = tostring(payload.eventId or payload.tool or payload.key or "")
		local cdKey = string.format("%d:%s:%s", adminPlayer.UserId, action, subKey)
		local nowClk = os.clock()
		local lastClk = commandCooldowns[cdKey] or 0
		if nowClk - lastClk < 0.06 then
			return
		end
		commandCooldowns[cdKey] = nowClk

		-- MODERATION & TELEPORT (Rank 2+)
		if action == "Kill" then
			local target = findTargetPlayer(payload) or adminPlayer
			if target ~= adminPlayer then
				local allowed, err = canModerateTarget(adminPlayer, rank, target)
				if not allowed then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, tostring(err), Color3.fromRGB(255, 96, 96))
					return
				end
			end
			local char = target.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if killCleanupCallback then
				local dropPos = if root and root:IsA("BasePart") then root.Position else Vector3.new(0, 2, 160)
				killCleanupCallback(target, dropPos)
			end
			if hum then
				hum.Health = 0
			elseif char then
				char:BreakJoints()
			end
			Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Killed " .. target.Name, Color3.fromRGB(255, 96, 96))

		elseif action == "Kick" then
			local target = findTargetPlayer(payload)
			if not target then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Target player not found!", Color3.fromRGB(255, 96, 96))
				return
			end
			local allowed, err = canModerateTarget(adminPlayer, rank, target)
			if not allowed then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, tostring(err), Color3.fromRGB(255, 96, 96))
				return
			end
			target:Kick(string.sub(tostring(payload.reason or "Kicked by Server Admin"), 1, 120))

		elseif action == "Ban" then
			local targetId = tonumber(payload.targetUserId)
			if not targetId then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Provide a valid UserId to ban!", Color3.fromRGB(255, 96, 96))
				return
			end
			targetId = math.floor(targetId)
			local targetOnline = Players:GetPlayerByUserId(targetId)
			if targetOnline then
				local allowed, err = canModerateTarget(adminPlayer, rank, targetOnline)
				if not allowed then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, tostring(err), Color3.fromRGB(255, 96, 96))
					return
				end
			else
				for _, entry in ipairs(AdminConfig.ROOT_OWNERS) do
					if entry.userId == targetId then
						Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Cannot ban Root Owner.", Color3.fromRGB(255, 96, 96))
						return
					end
				end
				if targetId == adminPlayer.UserId or (game.CreatorType == Enum.CreatorType.User and targetId == game.CreatorId) then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Cannot ban self or Game Creator.", Color3.fromRGB(255, 96, 96))
					return
				end
			end
			local dur = math.floor(isFiniteNonNeg(tonumber(payload.durationSeconds) or 0, 315360000) or 0)
			local reason = string.sub(tostring(payload.reason or "Banned by Admin"), 1, 140)
			DataService.BanUser(targetId, dur, reason, adminPlayer.Name)
			Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Banned UserId %d (%s)", targetId, if dur > 0 then FormatUtil.Time(dur) else "PERMANENT"), Color3.fromRGB(255, 96, 96))

		elseif action == "Unban" then
			local targetId = tonumber(payload.targetUserId)
			if targetId and targetId == targetId then
				DataService.UnbanUser(math.floor(targetId))
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Unbanned UserId " .. tostring(math.floor(targetId)), Color3.fromRGB(84, 245, 148))
			else
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Enter a valid numeric UserId to unban!", Color3.fromRGB(255, 196, 62))
			end

		elseif action == "TeleportTo" or action == "Bring" then
			local target = findTargetPlayer(payload)
			local aChar = adminPlayer.Character
			local tChar = if target then target.Character else nil
			local aRoot = if aChar then aChar:FindFirstChild("HumanoidRootPart") else nil
			local tRoot = if tChar then tChar:FindFirstChild("HumanoidRootPart") else nil
			if target and aRoot and tRoot and aRoot:IsA("BasePart") and tRoot:IsA("BasePart") then
				if action == "TeleportTo" then
					aRoot.AssemblyLinearVelocity = Vector3.zero
					aRoot.CFrame = tRoot.CFrame + Vector3.new(0, 4, 4)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Teleported to " .. target.Name, Color3.fromRGB(58, 188, 255))
				else
					tRoot.AssemblyLinearVelocity = Vector3.zero
					tRoot.CFrame = aRoot.CFrame + Vector3.new(0, 4, 4)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Brought " .. target.Name .. " to you", Color3.fromRGB(58, 188, 255))
				end
			else
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Character not spawned for teleport!", Color3.fromRGB(255, 196, 62))
			end

		elseif action == "TeleportToPlot" then
			local target = findTargetPlayer(payload) or adminPlayer
			PlotService.TeleportPlayerToPlot(target)
			Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Teleported " .. target.Name .. " -> Sanctuary Plot!", Color3.fromRGB(84, 245, 148))

		elseif action == "TeleportToZone" then
			local target = findTargetPlayer(payload) or adminPlayer
			local zoneId = tostring(payload.zoneId or "SafeZone")
			local char = target.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = getZoneTeleportCFrame(zoneId)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Teleported %s -> %s", target.Name, zoneId), Color3.fromRGB(58, 188, 255))
			end

		elseif action == "HealUnstun" then
			local target = findTargetPlayer(payload) or adminPlayer
			target:SetAttribute("FrozenByAdmin", false)
			target:SetAttribute("StunnedUntil", 0)
			local char = target.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					root.AssemblyLinearVelocity = Vector3.zero
				end
				if hum then
					hum.PlatformStand = false
					hum.Health = hum.MaxHealth
					hum.WalkSpeed = GameConfig.SPEED.BASE_WALK_SPEED
				end
			end
			Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Healed & Unstunned " .. target.Name, Color3.fromRGB(84, 245, 148))

		elseif action == "Freeze" or action == "Unfreeze" then
			local target = findTargetPlayer(payload) or adminPlayer
			if action == "Freeze" and target ~= adminPlayer then
				local allowed, err = canModerateTarget(adminPlayer, rank, target)
				if not allowed then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, tostring(err), Color3.fromRGB(255, 96, 96))
					return
				end
			end
			target:SetAttribute("FrozenByAdmin", action == "Freeze")
			if target.Character then
				local hum = target.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = if action == "Freeze" then 0 else GameConfig.SPEED.BASE_WALK_SPEED
				end
			end
			Remotes.Get("NotifyClient"):FireClient(
				adminPlayer,
				(if action == "Freeze" then "Froze " else "Unfroze ") .. target.Name,
				if action == "Freeze" then Color3.fromRGB(56, 189, 248) else Color3.fromRGB(84, 245, 148)
			)

		-- SUPERADMIN ONLY: TITLE ASSIGNMENT & DATA WIPE (Rank 3)
		elseif action == "GrantTitle" or action == "RevokeTitle" or action == "ResetPlayerData" then
			if rank < 3 then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Superadmin (Owner) only!", Color3.fromRGB(255, 96, 96))
				return
			end
			if action == "GrantTitle" then
				local reqTitle = tostring(payload.title or "Admin")
				if reqTitle ~= "Admin" and reqTitle ~= "Owner" then
					return
				end
				local newRank = if reqTitle == "Owner" then 3 else 2
				local targetOnline = findTargetPlayer(payload)
				local tUid = if targetOnline then targetOnline.UserId else tonumber(payload.targetUserId)
				local tName = if targetOnline then targetOnline.Name else tostring(payload.targetUsername or "")
				if not tUid or tName == "" then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Provide valid online Player or UserId + Username!", Color3.fromRGB(255, 196, 62))
					return
				end
				DataService.SetAdminRoleGrant(math.floor(tUid), tName, reqTitle :: any, newRank, adminPlayer.Name)
				if targetOnline then
					refreshRoleCacheForPlayer(targetOnline)
					provisionAdminUI(targetOnline)
					AdminService.ApplyCharacterTag(targetOnline, nil)
					local titleMeta = (AdminConfig.TITLES :: any)[reqTitle]
					Remotes.Get("NotifyClient"):FireAllClients(
						string.format("%s %s was promoted to [%s] by %s!", titleMeta.badgeText, targetOnline.DisplayName, reqTitle, adminPlayer.DisplayName),
						titleMeta.color
					)
				else
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Granted %s Title to %s (%d)", reqTitle, tName, math.floor(tUid)), Color3.fromRGB(255, 214, 62))
				end
			elseif action == "RevokeTitle" then
				local tUid = tonumber(payload.targetUserId)
				if not tUid then return end
				tUid = math.floor(tUid)
				for _, entry in ipairs(AdminConfig.ROOT_OWNERS) do
					if entry.userId == tUid then
						Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Cannot revoke Root Owner title.", Color3.fromRGB(255, 96, 96))
						return
					end
				end
				if tUid == game.CreatorId or tUid == adminPlayer.UserId then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Cannot revoke primary Owner title.", Color3.fromRGB(255, 96, 96))
					return
				end
				DataService.RemoveAdminRoleGrant(tUid)
				local targetOnline = Players:GetPlayerByUserId(tUid)
				if targetOnline then
					stripAdminUI(targetOnline)
					refreshRoleCacheForPlayer(targetOnline)
					AdminService.ApplyCharacterTag(targetOnline, nil)
					AdminService.SyncAdminState(targetOnline)
					Remotes.Get("NotifyClient"):FireClient(targetOnline, "Your Admin Title has been removed by Owner.", Color3.fromRGB(255, 96, 96))
				end
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Revoked Admin Title for UserId " .. tostring(tUid), Color3.fromRGB(255, 196, 62))
			elseif action == "ResetPlayerData" then
				local target = findTargetPlayer(payload)
				if not target then return end
				local tRec = verifiedRoles[target.UserId]
				if tRec and tRec.isRoot and target ~= adminPlayer then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Cannot reset Root Owner data.", Color3.fromRGB(255, 96, 96))
					return
				end
				DataService.ResetProfileData(target)
				PlotService.RefreshPlotBoardVisuals(target)
				PlotService.BroadcastAllPlotsSync()
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Reset profile data for " .. target.Name, Color3.fromRGB(255, 196, 62))
			end

		-- ECONOMY, SPEED & VALUES (Rank 2+)
		elseif action == "GiveCoins" or action == "SetCoins" then
			local target = findTargetPlayer(payload) or adminPlayer
			local prof = DataService.GetProfile(target)
			local parsed = FormatUtil.ParseCompactNumber(tostring(payload.amount or "1M"))
			local amt = isFiniteNonNeg(parsed, 1e35)
			if prof and amt then
				prof.coins = if action == "SetCoins" then amt else math.min(1e35, prof.coins + amt)
				DataService.SyncProfile(target)
				PlotService.RefreshPlotBoardVisuals(target)
				Remotes.Get("NotifyClient"):FireClient(
					adminPlayer,
					string.format("%s Coins ($%s) -> %s", if action == "SetCoins" then "Set" else "Gave", FormatUtil.Number(amt), target.Name),
					Color3.fromRGB(84, 245, 148)
				)
			end

		elseif action == "GiveSpeed" or action == "SetSpeed" then
			local target = findTargetPlayer(payload) or adminPlayer
			local prof = DataService.GetProfile(target)
			local parsed = FormatUtil.ParseCompactNumber(tostring(payload.amount or "500"))
			local amt = isFiniteNonNeg(parsed, 1e30)
			if prof and amt then
				prof.speedStat = if action == "SetSpeed" then math.floor(amt) else math.min(1e30, prof.speedStat + math.floor(amt))
				DataService.SyncProfile(target)
				PlotService.RefreshPlotBoardVisuals(target)
				Remotes.Get("NotifyClient"):FireClient(
					adminPlayer,
					string.format("%s Speed (%s) -> %s", if action == "SetSpeed" then "Set" else "Added", FormatUtil.Number(amt), target.Name),
					Color3.fromRGB(58, 188, 255)
				)
			end

		elseif action == "GiveRebirth" or action == "SetRebirth" then
			local target = findTargetPlayer(payload) or adminPlayer
			local prof = DataService.GetProfile(target)
			local val = isFiniteNonNeg(tonumber(payload.amount) or 1, 10000)
			if prof and val then
				if action == "SetRebirth" then
					prof.rebirths = math.floor(val)
				else
					prof.rebirths = math.min(10000, prof.rebirths + math.max(1, math.floor(val)))
				end
				PlotService.RefreshPlotBoardVisuals(target)
				DataService.SyncProfile(target)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("%s Rebirths -> #%d!", target.Name, prof.rebirths), Color3.fromRGB(255, 132, 224))
			end

		elseif action == "SetTreadmillLevel" then
			local target = findTargetPlayer(payload) or adminPlayer
			local prof = DataService.GetProfile(target)
			local lvl = math.clamp(math.floor(tonumber(payload.level) or 10), 1, 100)
			if prof then
				prof.treadmillLevel = lvl
				PlotService.RefreshPlotBoardVisuals(target)
				DataService.SyncProfile(target)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("%s Treadmill -> Lv.%d!", target.Name, lvl), Color3.fromRGB(58, 188, 255))
			end

		elseif action == "SetPenCapacity" then
			local target = findTargetPlayer(payload) or adminPlayer
			local prof = DataService.GetProfile(target)
			local cap = math.clamp(math.floor(tonumber(payload.capacity) or 20), 8, 25)
			if prof then
				prof.penCapacity = cap
				prof.penUpgradeLevel = math.max(1, cap - GameConfig.PEN.STARTING_CAPACITY + 1)
				DataService.SyncProfile(target)
				PlotService.RefreshPlotBoardVisuals(target)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("%s Pen Capacity -> %d!", target.Name, cap), Color3.fromRGB(192, 132, 252))
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
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Unlocked all Lassos, Trails, Vehicles & Index for " .. target.Name, Color3.fromRGB(255, 214, 72))
			end

		elseif action == "SpawnAnimal" or action == "GivePet" then
			local target = findTargetPlayer(payload) or adminPlayer
			local spec = AnimalConfig.GetById(tostring(payload.speciesId or "MythicWhiteTiger")) or AnimalConfig.ALL[1]
			local validMut = sanitizeMutation(payload.mutation or "Rainbow")
			local sizeRatio = math.clamp(tonumber(payload.sizeRatio) or 2.5, 0.5, 10.0)
			local animal = PlotService.GrantAnimalToPlayer(target, spec.id, sizeRatio, validMut, {
				originSource = "Admin",
			})
			if animal then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Gave [%s] %s (%.1fx) to %s!", validMut, spec.name, sizeRatio, target.Name), Color3.fromRGB(224, 92, 255))
				if target ~= adminPlayer then
					Remotes.Get("NotifyClient"):FireClient(target, string.format("Admin gave you [%s] %s (%.1fx)!", validMut, spec.name, sizeRatio), Color3.fromRGB(224, 92, 255))
				end
			end

		elseif action == "GiveCrate" then
			local target = findTargetPlayer(payload) or adminPlayer
			local biomeId = tostring(payload.biomeId or "PineWoods")
			local rarity = tostring(payload.rarity or "Legendary") :: Types.AnimalRarity
			local useSpec = payload.useSelectedSpecies == true
			local spec = resolveCrateSpecies(biomeId, rarity, tostring(payload.speciesId or ""), useSpec)
			local customMut = sanitizeMutation(payload.mutation)
			local sizeRatio = tonumber(payload.sizeRatio)
			local crateUid = PlotService.AddCrateToInventory(target, biomeId, rarity, spec.id, nil, {
				customMutation = if customMut ~= "None" then customMut else nil,
				customSizeRatio = if sizeRatio and sizeRatio > 0 then math.clamp(sizeRatio, 0.5, 10.0) else nil,
				originSource = "Wild",
			})
			if crateUid then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Gave [%s] %s Crate (%s) to %s's Inventory!", rarity, biomeId, spec.name, target.Name), Color3.fromRGB(84, 245, 148))
				if target ~= adminPlayer then
					Remotes.Get("NotifyClient"):FireClient(target, string.format("Admin gave you a [%s] %s Crate!", rarity, biomeId), Color3.fromRGB(84, 245, 148))
				end
			end

		elseif action == "GivePenCrate" then
			local target = findTargetPlayer(payload) or adminPlayer
			local biomeId = tostring(payload.biomeId or "PineWoods")
			local rarity = tostring(payload.rarity or "Legendary") :: Types.AnimalRarity
			local useSpec = payload.useSelectedSpecies == true
			local spec = resolveCrateSpecies(biomeId, rarity, tostring(payload.speciesId or ""), useSpec)
			local okAdd = PlotService.AddPendingCrate(target, biomeId, rarity, spec.id)
			if okAdd then
				if payload.instantReady == true then
					local prof = DataService.GetProfile(target)
					if prof then
						local nowUnix = os.time()
						for _, cr in pairs(prof.pendingCrates) do
							if cr.speciesId == spec.id and cr.rarity == rarity then
								cr.unlockAt = nowUnix
							end
						end
						PlotService.BroadcastAllPlotsSync()
						DataService.SyncProfile(target)
					end
				end
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Placed Ready [%s] %s Crate (%s) in %s's Pen!", rarity, biomeId, spec.name, target.Name), Color3.fromRGB(84, 245, 148))
			end

		elseif action == "InstantReadyCrates" then
			local target = findTargetPlayer(payload) or adminPlayer
			local prof = DataService.GetProfile(target)
			if prof then
				local nowUnix = os.time()
				local count = 0
				for _, cr in pairs(prof.pendingCrates) do
					if cr.unlockAt > nowUnix then
						cr.unlockAt = nowUnix
						count += 1
					end
				end
				PlotService.RefreshPlotBoardVisuals(target)
				PlotService.BroadcastAllPlotsSync()
				DataService.SyncProfile(target)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Instant-Readied %d Pen crate(s) for %s!", count, target.Name), Color3.fromRGB(250, 204, 21))
			end

		elseif action == "SpawnWorldCrate" then
			if not worldSpawnerCallback then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "World spawner not initialized!", Color3.fromRGB(255, 96, 96))
				return
			end
			local biomeId = tostring(payload.biomeId or "PineWoods")
			local rarity = tostring(payload.rarity or "Legendary") :: Types.AnimalRarity
			local speciesArg: string? = nil
			if payload.useSelectedSpecies == true then
				local spec = AnimalConfig.GetById(tostring(payload.speciesId or ""))
				if spec then
					speciesArg = spec.id
				end
			end
			local nearPos: Vector3? = nil
			local spawnNote = biomeId
			if payload.nearAdmin == true and adminPlayer.Character then
				local hrp = adminPlayer.Character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					local desired = hrp.Position + hrp.CFrame.LookVector * 9
					if desired.Z <= GameConfig.WORLD.SAFE_ZONE_Z_MAX + 12 then
						nearPos = Vector3.new(math.clamp(desired.X, -58, 58), desired.Y, GameConfig.WORLD.SAFE_ZONE_Z_MAX + 16)
						spawnNote = "Safe Zone Gate (Z=" .. tostring(math.round(nearPos.Z)) .. ")"
					else
						nearPos = desired
						spawnNote = "Near You (Z=" .. tostring(math.round(desired.Z)) .. ")"
					end
				end
			end
			local okSpawn = worldSpawnerCallback(biomeId, rarity, speciesArg, nearPos)
			if okSpawn then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Spawned %s crate -> %s!", rarity, spawnNote), Color3.fromRGB(84, 245, 148))
			else
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "World crate spawn failed!", Color3.fromRGB(255, 96, 96))
			end

		elseif action == "SetLiveMultiplier" then
			local key = tostring(payload.key or "")
			local rawNum = tonumber(payload.value)
			local val = if rawNum then isFiniteNonNeg(rawNum, 10000) else nil
			if val and (liveTuners :: any)[key] ~= nil then
				if (key == "rarityLuckMult" or key == "mutationLuckMult") and rank < 3 then
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Owner rank required for Luck multipliers!", Color3.fromRGB(255, 96, 96))
					return
				end
				val = math.max(0.05, val)
				;(liveTuners :: any)[key] = val
				refreshAllPlayersEconomy()
				AdminService.BroadcastActiveBuffs(nil)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("Live %s set to %.2fx", key, val), Color3.fromRGB(0, 245, 212))
			end

		elseif action == "ResetMultipliers" then
			liveTuners.cashMult = 1.0
			liveTuners.speedMult = 1.0
			liveTuners.poacherSpeedMult = 1.0
			liveTuners.resistanceMult = 1.0
			if rank >= 3 then
				liveTuners.rarityLuckMult = 1.0
				liveTuners.mutationLuckMult = 1.0
			end
			refreshAllPlayersEconomy()
			AdminService.BroadcastActiveBuffs(nil)
			Remotes.Get("NotifyClient"):FireClient(adminPlayer, "All live multipliers reset to 1.0x!", Color3.fromRGB(84, 245, 148))

		-- OWNER / SUPERADMIN SPAWN & MUTATION RATE CONTROLS (Rank >= 3)
		elseif action == "SetRarityLuck" or action == "SetMutationLuck" or action == "SetRarityWeight" or action == "SetMutationWeight" or action == "SetForcedMutation" or action == "ResetSpawnRates" or action == "TriggerWaveReset" then
			if rank < 3 then
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Owner (Superadmin) rank required to modify spawn rates!", Color3.fromRGB(255, 96, 96))
				return
			end
			if action == "SetRarityLuck" or action == "SetMutationLuck" then
				local val = isFiniteNonNeg(tonumber(payload.value) or 1.0, 10000)
				if val then
					val = math.max(0.05, val)
					if action == "SetRarityLuck" then
						liveTuners.rarityLuckMult = val
					else
						liveTuners.mutationLuckMult = val
					end
					AdminService.BroadcastActiveBuffs(nil)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("[Owner] %s = %.2fx", action, val), Color3.fromRGB(255, 214, 72))
				end
			elseif action == "SetRarityWeight" then
				local rar = tostring(payload.rarity or "")
				if GameConfig.RARITY_TIER_INDEX[rar] then
					local rawW = tonumber(payload.weight)
					if not rawW or rawW < 0 then
						rarityWeightOverrides[rar] = nil
						Remotes.Get("NotifyClient"):FireClient(adminPlayer, "[Owner] Reset crate weight for " .. rar, Color3.fromRGB(168, 224, 255))
					else
						local cleanW = isFiniteNonNeg(rawW, 1000000) or 0
						rarityWeightOverrides[rar] = cleanW
						Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("[Owner] %s Crate Weight -> %.3f", rar, cleanW), Color3.fromRGB(255, 214, 72))
					end
				end
			elseif action == "SetMutationWeight" then
				local mut = tostring(payload.mutation or "")
				if (GameConfig.MUTATIONS :: any)[mut] then
					local rawW = tonumber(payload.weight)
					if not rawW or rawW < 0 then
						mutationWeightOverrides[mut] = nil
						Remotes.Get("NotifyClient"):FireClient(adminPlayer, "[Owner] Reset mutation weight for " .. mut, Color3.fromRGB(168, 224, 255))
					else
						local cleanW = isFiniteNonNeg(rawW, 1000000) or 0
						mutationWeightOverrides[mut] = cleanW
						Remotes.Get("NotifyClient"):FireClient(adminPlayer, string.format("[Owner] %s Mutation Weight -> %.3f", mut, cleanW), Color3.fromRGB(192, 132, 252))
					end
				end
			elseif action == "SetForcedMutation" then
				local mut = tostring(payload.mutation or "Random")
				if mut == "Random" or (GameConfig.MUTATIONS :: any)[mut] then
					forcedWildMutation = mut
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "[Owner] Forced Wild Mutation: " .. mut, Color3.fromRGB(224, 92, 255))
				end
			elseif action == "ResetSpawnRates" then
				liveTuners.rarityLuckMult = 1.0
				liveTuners.mutationLuckMult = 1.0
				table.clear(rarityWeightOverrides)
				table.clear(mutationWeightOverrides)
				forcedWildMutation = "Random"
				AdminService.BroadcastActiveBuffs(nil)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "[Owner] All crate rarity & mutation rates reset to default!", Color3.fromRGB(84, 245, 148))
			elseif action == "TriggerWaveReset" then
				if waveResetCallback then
					task.spawn(waveResetCallback)
					Remotes.Get("NotifyClient"):FireClient(adminPlayer, "[Owner] Respawned all biome crates using current rates!", Color3.fromRGB(84, 245, 148))
				end
			end

		elseif action == "TriggerEvent" then
			local eventId = tostring(payload.eventId or "")
			local def = (AdminConfig.ADMIN_ABUSE_EVENTS :: any)[eventId]
			if def then
				local rawDur = tonumber(payload.durationSeconds)
				local customDur = math.clamp(math.floor(rawDur or def.durationSeconds), 5, 86400)
				local unixNow = os.time()
				if payload.mode == "extend" and activeEvents[eventId] and activeEvents[eventId] > unixNow then
					activeEvents[eventId] += customDur
				else
					activeEvents[eventId] = unixNow + customDur
				end
				activeEventDurations[eventId] = customDur
				local totalRem = math.max(1, activeEvents[eventId] - unixNow)
				syncEventWorldAttributes()
				refreshAllPlayersEconomy()
				AdminService.BroadcastActiveBuffs(nil)

				local bannerDurText = if totalRem >= 60 then string.format("%dm %ds", math.floor(totalRem / 60), totalRem % 60) else (tostring(totalRem) .. "s")
				Remotes.Get("GlobalEventBanner"):FireAllClients(string.format("%s %s (%s) — %s", def.icon or "🔥", def.title, bannerDurText, def.description), def.color, 9)
				if eventId == "CrateRain" and crateRainCallback then
					task.spawn(crateRainCallback)
				elseif eventId == "TitanicZoo" then
					PlotService.BroadcastAllPlotsSync()
				end
			end

		elseif action == "StopEvent" then
			local eventId = tostring(payload.eventId or "")
			local def = (AdminConfig.ADMIN_ABUSE_EVENTS :: any)[eventId]
			if activeEvents[eventId] ~= nil then
				activeEvents[eventId] = nil
				activeEventDurations[eventId] = nil
				syncEventWorldAttributes()
				refreshAllPlayersEconomy()
				AdminService.BroadcastActiveBuffs(nil)
				Remotes.Get("NotifyClient"):FireClient(adminPlayer, "Stopped event: " .. (if def then def.shortLabel else eventId), Color3.fromRGB(255, 196, 62))
			end

		elseif action == "StopAllEvents" then
			table.clear(activeEvents)
			table.clear(activeEventDurations)
			liveTuners.cashMult = 1.0
			liveTuners.speedMult = 1.0
			liveTuners.poacherSpeedMult = 1.0
			liveTuners.resistanceMult = 1.0
			syncEventWorldAttributes()
			refreshAllPlayersEconomy()
			AdminService.BroadcastActiveBuffs(nil)
			Remotes.Get("GlobalEventBanner"):FireAllClients("Admin ended active server events.", Color3.fromRGB(180, 190, 210), 4)

		elseif action == "Broadcast" then
			local rec = verifiedRoles[adminPlayer.UserId] or refreshRoleCacheForPlayer(adminPlayer)
			local tag = if rec.title == "Owner" then "[OWNER " else "[ADMIN "
			local filteredMsg = filterBroadcastMessage(adminPlayer, tostring(payload.message or "Hello Rangers!"))
			Remotes.Get("GlobalEventBanner"):FireAllClients(tag .. adminPlayer.DisplayName .. "]: " .. filteredMsg, Color3.fromRGB(255, 214, 62), 7)

		elseif action == "ToggleSelfTool" then
			local key = tostring(payload.tool or "")
			selfTools[adminPlayer.UserId] = selfTools[adminPlayer.UserId] or { godMode = false, instantPull = false, instantUnbox = false, superSpeed = false, invisible = false }
			local st = selfTools[adminPlayer.UserId]
			if (st :: any)[key] ~= nil then
				local newState = not ((st :: any)[key] == true)
				;(st :: any)[key] = newState
				adminPlayer:SetAttribute("AdminSuperSpeed", st.superSpeed)
				adminPlayer:SetAttribute("AdminInstantUnbox", st.instantUnbox)
				adminPlayer:SetAttribute("AdminInvisible", st.invisible)
				if key == "superSpeed" and adminPlayer.Character then
					local hum = adminPlayer.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.WalkSpeed = if newState then 140 else GameConfig.SPEED.BASE_WALK_SPEED
					end
				elseif key == "invisible" then
					applyInvisibilityToCharacter(adminPlayer, newState)
				end
				Remotes.Get("NotifyClient"):FireClient(
					adminPlayer,
					string.format("%s: %s", key, if newState then "ENABLED" else "DISABLED"),
					if newState then Color3.fromRGB(84, 245, 148) else Color3.fromRGB(148, 163, 184)
				)
			end
		end

		AdminService.SyncAdminState(nil)
	end)

	Players.PlayerRemoving:Connect(function(player)
		selfTools[player.UserId] = nil
		verifiedRoles[player.UserId] = nil
		local prefix = tostring(player.UserId) .. ":"
		for k in pairs(commandCooldowns) do
			if string.sub(k, 1, #prefix) == prefix then
				commandCooldowns[k] = nil
			end
		end
		task.defer(function()
			AdminService.SyncAdminState(nil)
		end)
	end)

	-- 1-second server ticker: expires finished Admin Abuse events, refreshes economy/attributes, and syncs live buff timers
	task.spawn(function()
		local lastServerLuckActive = PassManager.GetServerLuckRemainingSeconds() > 0
		local syncTick = 0
		while true do
			task.wait(1)
			local unixNow = os.time()
			local anyExpired = false
			local hasActiveTimed = false
			for eventId, exp in pairs(activeEvents) do
				if unixNow >= exp then
					activeEvents[eventId] = nil
					activeEventDurations[eventId] = nil
					anyExpired = true
				else
					hasActiveTimed = true
				end
			end

			local serverLuckNow = PassManager.GetServerLuckRemainingSeconds() > 0
			local serverLuckChanged = (serverLuckNow ~= lastServerLuckActive)
			lastServerLuckActive = serverLuckNow
			if serverLuckNow then
				hasActiveTimed = true
			end

			syncTick += 1
			if anyExpired then
				syncEventWorldAttributes()
				refreshAllPlayersEconomy()
				AdminService.BroadcastActiveBuffs(nil)
				AdminService.SyncAdminState(nil)
			elseif serverLuckChanged or (hasActiveTimed and syncTick % 5 == 0) then
				AdminService.BroadcastActiveBuffs(nil)
				AdminService.SyncAdminState(nil)
			end
		end
	end)
end

return AdminService
