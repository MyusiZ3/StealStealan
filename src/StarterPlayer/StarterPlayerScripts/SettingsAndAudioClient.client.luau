--!strict
-- SettingsAndAudioClient.client.luau
-- Manages Music (BGMGroup) looping per zone, SFX (SFXGroup) cues, and audio settings sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local SoundConfig = require(ReplicatedStorage.Config.SoundConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

local function ensureGroup(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local sg = Instance.new("SoundGroup")
	sg.Name = name
	sg.Volume = 1
	sg.Parent = SoundService
	return sg
end

local bgmGroup = ensureGroup(SoundConfig.GROUPS.BGM)
local sfxGroup = ensureGroup(SoundConfig.GROUPS.SFX)

local bgmPlayer = Instance.new("Sound")
bgmPlayer.Name = "MainBGMPlayer"
bgmPlayer.Looped = true
bgmPlayer.Volume = 0.5
bgmPlayer.SoundGroup = bgmGroup
bgmPlayer.SoundId = SoundConfig.BGM.Hub
bgmPlayer.Parent = SoundService

local currentTrackId = SoundConfig.BGM.Hub
local inBossChase = false

local function switchBGM(trackId: string)
	if currentTrackId == trackId and bgmPlayer.IsPlaying then
		return
	end
	currentTrackId = trackId
	bgmPlayer.SoundId = trackId
	pcall(function()
		bgmPlayer:Play()
	end)
end

local function playSFX(assetId: string, vol: number?)
	local s = Instance.new("Sound")
	s.SoundId = assetId
	s.SoundGroup = sfxGroup
	s.Volume = vol or 0.75
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function applyAudioSettings(settings: any)
	bgmGroup.Volume = if settings.musicEnabled then (settings.musicVolume or 0.45) else 0
	sfxGroup.Volume = if settings.sfxEnabled then (settings.sfxVolume or 0.75) else 0
	if settings.musicEnabled and not bgmPlayer.IsPlaying then
		pcall(function()
			bgmPlayer:Play()
		end)
	end
end

applyAudioSettings(GameConfig.DEFAULT_SETTINGS)

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and type(profile.settings) == "table" then
		applyAudioSettings(profile.settings)
	end
end)

Remotes.Get("CrateDelivered").OnClientEvent:Connect(function()
	playSFX(SoundConfig.SFX.CoinCollect, 0.85)
end)

Remotes.Get("CrateHatchReveal").OnClientEvent:Connect(function(data)
	local isLocal = (type(data) ~= "table" or data.openerUserId == nil or data.openerUserId == localPlayer.UserId)
	if not isLocal then
		return
	end
	local rarity = if type(data) == "table" then tostring(data.rarity or "Common") else "Common"
	local tier = GameConfig.GetRarityTier(rarity)
	local chargeDur = if tier >= 11 then 1.60 elseif tier >= 7 then 1.20 elseif tier >= 4 then 0.90 else 0.65

	-- Scaled multi-stage hatch SFX synchronized cleanly to charge & detonation duration
	local tickCount = if tier >= 11 then 6 elseif tier >= 7 then 5 else 3
	for k = 0, tickCount - 1 do
		local frac = k / math.max(1, tickCount)
		local delayT = frac * (chargeDur - 0.14)
		local vol = 0.62 + frac * 0.34
		if delayT <= 0.01 then
			playSFX(SoundConfig.SFX.LassoPullTick, vol)
		else
			task.delay(delayT, function()
				playSFX(SoundConfig.SFX.LassoPullTick, vol)
			end)
		end
	end
	task.delay(chargeDur, function()
		playSFX(SoundConfig.SFX.CratePop, 1.0)
	end)
	task.delay(chargeDur + 0.28, function()
		playSFX(SoundConfig.SFX.MergeSuccess, 0.92)
	end)
	if tier >= 7 then
		task.delay(chargeDur + 0.56, function()
			playSFX(SoundConfig.SFX.CoinCollect, 0.95)
			playSFX(SoundConfig.SFX.MergeSuccess, 0.85)
		end)
	end
end)

Remotes.Get("PlayWorldVFX").OnClientEvent:Connect(function(vfxType)
	if vfxType == "CashPileSuction" then
		playSFX(SoundConfig.SFX.CoinCollect, 0.90)
	end
end)

local lastAlarmTick = 0
local function playPoacherAlarmDebounced()
	local now = os.clock()
	if (now - lastAlarmTick) < 1.0 then
		return
	end
	lastAlarmTick = now
	playSFX(SoundConfig.SFX.PoacherAlarm, 0.85)
end

Remotes.Get("PoacherAlertSync").OnClientEvent:Connect(function(active)
	local cnt = tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0
	inBossChase = (active == true) and (cnt > 0)
	if inBossChase then
		playPoacherAlarmDebounced()
	end
end)

localPlayer:GetAttributeChangedSignal("TowedCrateCount"):Connect(function()
	local cnt = tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0
	if cnt > 0 then
		playPoacherAlarmDebounced()
	else
		inBossChase = false
	end
end)

Remotes.Get("PlayerKnockback").OnClientEvent:Connect(function()
	playSFX(SoundConfig.SFX.PoacherCatch, 0.9)
end)

Remotes.Get("NotifyClient").OnClientEvent:Connect(function(msg)
	if type(msg) == "string" and (string.find(msg, "MERGED!") or string.find(msg, "CROSS-FUSE")) then
		playSFX(SoundConfig.SFX.MergeSuccess, 0.9)
	end
end)

local wasPulling = false
Remotes.Get("PullProgressSync").OnClientEvent:Connect(function(data)
	if data.active and not wasPulling then
		wasPulling = true
		playSFX(SoundConfig.SFX.LassoThrow, 0.75)
	elseif not data.active then
		wasPulling = false
	end
	if data.completed then
		playSFX(SoundConfig.SFX.CratePop, 0.85)
	end
end)

-- Single seamless BGM loop using SoundConfig.BGM.Hub across all biomes (prevents transition glitches)
local accum = 0
RunService.Heartbeat:Connect(function(dt: number)
	accum += dt
	if accum < 1.0 then return end
	accum = 0
	if currentTrackId ~= SoundConfig.BGM.Hub then
		switchBGM(SoundConfig.BGM.Hub)
	elseif bgmGroup.Volume > 0 and not bgmPlayer.IsPlaying then
		pcall(function()
			bgmPlayer:Play()
		end)
	end
end)
