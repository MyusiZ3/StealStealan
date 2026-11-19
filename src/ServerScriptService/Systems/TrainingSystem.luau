--!strict
-- TrainingSystem.luau
-- Server-validated Treadmill Speed Training + Trail Multipliers + Dynamic WalkSpeed & Terrain Penalties

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game.ReplicatedStorage.Config.GameConfig)
local BiomeConfig = require(game.ReplicatedStorage.Config.BiomeConfig)
local TrailConfig = require(game.ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(game.ReplicatedStorage.Config.VehicleConfig)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.Parent.Services.DataService)
local PlotService = require(script.Parent.Parent.Services.PlotService)
local PassManager = require(script.Parent.Parent.Services.PassManager)
local AdminService = require(script.Parent.Parent.Services.AdminService)

local TrainingSystem = {}

local lastOrbTap: { [number]: number } = {}
local treadmillCooldownUntil: { [number]: number } = {}
local treadmillEnteredAt: { [number]: number } = {}
local bubbleBoostUntil: { [number]: number } = {}
local lastBubbleClaim: { [number]: number } = {}

local function getTrailSpeedMult(trailId: string): number
	for _, t in ipairs(TrailConfig) do
		if t.id == trailId then return t.speedMultiplier end
	end
	return 1.0
end

local function getVehicleDef(vehicleId: string)
	for _, v in ipairs(VehicleConfig) do
		if v.id == vehicleId then return v end
	end
	return VehicleConfig[1]
end

local function computeBaseAndTotalMultiplier(player: Player, profile: any): (number, number, number)
	local trailMult = getTrailSpeedMult(profile.equippedTrail)
	local passMult = if PassManager.OwnsPass(player, "DoubleSpeed") then 2.0 else 1.0
	local vipMult = if PassManager.OwnsPass(player, "VIP") then 1.5 else 1.0
	local indexMult = 1.0
	if profile.zoneIndexBonusesClaimed.PineWoods then indexMult += 0.15 end
	if profile.zoneIndexBonusesClaimed.AlpinePeaks then indexMult += 0.50 end
	if profile.zoneIndexBonusesClaimed.VolcanicJungle then indexMult += 1.00 end
	local bubbleMult = if os.clock() < (bubbleBoostUntil[player.UserId] or 0) then 3.0 else 1.0
	local baseMult = trailMult * passMult * vipMult * indexMult * AdminService.GetSpeedMultiplier() * bubbleMult
	local vehicleDef = getVehicleDef(profile.equippedVehicle)
	local totalMult = baseMult
	if player:GetAttribute("IsRidingVehicle") == true then
		totalMult += vehicleDef.speedMultiplier
	end
	return baseMult, totalMult, vehicleDef.speedMultiplier
end

function TrainingSystem.ComputeSpeedMetrics(player: Player, profile: any): (number, number, number, number)
	local baseMult, totalMult, vehMult = computeBaseAndTotalMultiplier(player, profile)
	local riding = player:GetAttribute("IsRidingVehicle") == true
	local displayedSpeed = profile.speedStat * (if riding then vehMult else 1)
	local baseStep = GameConfig.GetTreadmillBaseStep(profile.treadmillLevel)
	local stepGain = math.max(1, math.floor(baseStep * totalMult))
	player:SetAttribute("StepGainPerPulse", stepGain)
	return displayedSpeed, baseMult, totalMult, vehMult
end

local function computeSpeedGainPerPulse(player: Player): (number, number)
	local profile = DataService.GetProfile(player)
	if not profile then return 0, 1.0 end
	local base = GameConfig.GetTreadmillBaseStep(profile.treadmillLevel)
	local _, totalMult = computeBaseAndTotalMultiplier(player, profile)
	return base * totalMult, totalMult
end

function TrainingSystem.ComputeEffectiveWalkSpeed(player: Player, zPos: number): number
	if player:GetAttribute("FrozenByAdmin") then
		return 0
	end
	local stunnedUntil = tonumber(player:GetAttribute("StunnedUntil")) or 0
	if os.clock() < stunnedUntil then
		return 0
	end
	if player:GetAttribute("OnTreadmill") == true then
		return 0
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return GameConfig.SPEED.BASE_WALK_SPEED
	end
	local vehicleDef = getVehicleDef(profile.equippedVehicle)
	local ridingVehicle = player:GetAttribute("IsRidingVehicle") == true
	local effectiveSpeedStat = profile.speedStat * (if ridingVehicle then vehicleDef.speedMultiplier else 1)
	local statBonus = if effectiveSpeedStat > 0
		then math.log10(1 + effectiveSpeedStat) * GameConfig.SPEED.STAT_TO_WALKSPEED_LOG_SCALE
		else 0
	local vehicleBonus = if ridingVehicle then vehicleDef.baseSpeedBonus else 0
	local mountBonus = tonumber(player:GetAttribute("MountedAnimalSpeedBonus")) or 0
	local total = math.min(GameConfig.SPEED.MAX_EFFECTIVE_WALKSPEED, GameConfig.SPEED.BASE_WALK_SPEED + statBonus + vehicleBonus + mountBonus)

	-- Terrain penalty unless riding a terrain-ignoring vehicle
	if zPos > GameConfig.WORLD.SAFE_ZONE_Z_MAX and not (ridingVehicle and vehicleDef.ignoresTerrainPenalty) then
		for _, biome in ipairs(BiomeConfig) do
			if zPos >= biome.zStart and zPos <= biome.zEnd then
				total *= (1 - biome.speedPenalty)
				break
			end
		end
	end

	if player:GetAttribute("SlowMode") == true then
		total *= GameConfig.SPEED.SLOW_MODE_MULTIPLIER
	end
	if player:GetAttribute("AdminSuperSpeed") == true then
		total = math.max(total, 140)
	end
	return math.max(6, total)
end

function TrainingSystem.Init()
	DataService.RegisterSpeedMetricsGetter(TrainingSystem.ComputeSpeedMetrics)

	Remotes.Get("SetMovementState").OnServerEvent:Connect(function(player, stateKey, stateVal)
		if typeof(stateKey) ~= "string" or typeof(stateVal) ~= "boolean" then
			return
		end
		if stateKey == "SlowMode" or stateKey == "IsRidingVehicle" then
			player:SetAttribute(stateKey, stateVal)
			PlotService.RefreshPlotBoardVisuals(player)
			DataService.SyncProfile(player)
		end
	end)

	Remotes.Get("TrainingTapOrb").OnServerEvent:Connect(function(player, mode)
		local now = os.clock()
		if mode == "BubbleBoost" then
			if player:GetAttribute("OnTreadmill") ~= true then
				return
			end
			if now - (lastBubbleClaim[player.UserId] or 0) < 10.0 then
				return
			end
			lastBubbleClaim[player.UserId] = now
			bubbleBoostUntil[player.UserId] = now + 15.0
			local expiresUnix = math.floor(workspace:GetServerTimeNow()) + 15
			player:SetAttribute("TreadmillBoostEndsAt", expiresUnix)
			local profile = DataService.GetProfile(player)
			if profile then
				TrainingSystem.ComputeSpeedMetrics(player, profile)
			end
			PlotService.RefreshPlotBoardVisuals(player)
			DataService.SyncProfile(player)
			Remotes.Get("NotifyClient"):FireClient(player, "⚡ x3 TREADMILL SPEED BOOST ACTIVE (15s)!", Color3.fromRGB(58, 228, 255))
			return
		end
		if now - (lastOrbTap[player.UserId] or 0) < 0.35 then
			return
		end
		lastOrbTap[player.UserId] = now
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local gain = computeSpeedGainPerPulse(player) * 2.5
		profile.speedStat += math.floor(gain)
		DataService.SyncProfile(player)
	end)

	Remotes.Get("TreadmillState").OnServerEvent:Connect(function(player, wantsJoin)
		if typeof(wantsJoin) ~= "boolean" then return end
		if not wantsJoin then
			treadmillEnteredAt[player.UserId] = nil
			player:SetAttribute("OnTreadmill", false)
			treadmillCooldownUntil[player.UserId] = os.clock() + 2.0
			Remotes.Get("TreadmillState"):FireClient(player, false, nil)
		end
	end)

	-- Periodic check if player enters/stands on their Plot's TreadmillPad + update WalkSpeed
	local accum = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accum += dt
		local doTrainingTick = accum >= 0.50
		if doTrainingTick then
			accum = 0
		end

		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if hum and root and root:IsA("BasePart") then
				hum.WalkSpeed = TrainingSystem.ComputeEffectiveWalkSpeed(player, root.Position.Z)

				local plotIdx = PlotService.GetPlayerPlotIndex(player)
				local plotModel = if plotIdx then PlotService.GetPlotModel(plotIdx) else nil
				local treadPad = if plotModel then plotModel:FindFirstChild("TreadmillPad") else nil
				local treadAnchor = if plotModel then plotModel:FindFirstChild("TreadmillStandAnchor") else nil

				if treadPad and treadPad:IsA("BasePart") then
					local localOffset = treadPad.CFrame:PointToObjectSpace(root.Position)
					local inZone = math.abs(localOffset.X) <= (treadPad.Size.X * 0.5 + 1.0)
						and math.abs(localOffset.Z) <= (treadPad.Size.Z * 0.5 + 1.0)
						and math.abs(localOffset.Y) <= 9
					local inExitZone = math.abs(localOffset.X) <= (treadPad.Size.X * 0.5 + 3.0)
						and math.abs(localOffset.Z) <= (treadPad.Size.Z * 0.5 + 3.0)
						and math.abs(localOffset.Y) <= 12

					local isOn = player:GetAttribute("OnTreadmill") == true
					if not isOn and inZone and now >= (treadmillCooldownUntil[player.UserId] or 0) then
						local stunnedUntil = tonumber(player:GetAttribute("StunnedUntil")) or 0
						if now >= stunnedUntil then
							-- Set OnTreadmill BEFORE dismounting so client mount handler skips +0.8 hop-up!
							treadmillEnteredAt[player.UserId] = now
							player:SetAttribute("OnTreadmill", true)
							if player:GetAttribute("IsRidingVehicle") == true then
								player:SetAttribute("IsRidingVehicle", false)
								Remotes.Get("SpawnVehicle"):FireClient(player, false)
							end
							if tostring(player:GetAttribute("MountedAnimalUid") or "") ~= "" then
								player:SetAttribute("MountedAnimalUid", "")
								player:SetAttribute("MountedAnimalId", "")
								player:SetAttribute("MountedAnimalMutation", "None")
								player:SetAttribute("MountedAnimalSize", 1)
								player:SetAttribute("MountedAnimalSpeedBonus", 0)
							end
							local snapCF = if treadAnchor and treadAnchor:IsA("BasePart")
								then treadAnchor.CFrame
								else (treadPad.CFrame * CFrame.new(0, 3.0, 0))
							local beltY = if treadAnchor then treadAnchor:GetAttribute("BeltSurfaceY") else nil
							Remotes.Get("TreadmillState"):FireClient(player, true, snapCF, beltY)
							isOn = true
						end
					elseif isOn and not inExitZone and (now - (treadmillEnteredAt[player.UserId] or 0)) >= 0.85 then
						treadmillEnteredAt[player.UserId] = nil
						treadmillCooldownUntil[player.UserId] = now + 2.0
						player:SetAttribute("OnTreadmill", false)
						Remotes.Get("TreadmillState"):FireClient(player, false, nil)
						isOn = false
					end

					if doTrainingTick and (isOn or inZone) then
						local profile = DataService.GetProfile(player)
						if profile then
							TrainingSystem.ComputeSpeedMetrics(player, profile)
							local rawGain, totalMult = computeSpeedGainPerPulse(player)
							local gain = math.max(1, math.floor(rawGain))
							profile.speedStat += gain
							Remotes.Get("TrainingPulse"):FireClient(player, gain, totalMult, true)
							DataService.SyncProfile(player)
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastOrbTap[player.UserId] = nil
		treadmillCooldownUntil[player.UserId] = nil
		treadmillEnteredAt[player.UserId] = nil
		bubbleBoostUntil[player.UserId] = nil
		lastBubbleClaim[player.UserId] = nil
	end)
end

return TrainingSystem
