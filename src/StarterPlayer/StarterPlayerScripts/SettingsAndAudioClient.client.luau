--!strict
-- SettingsAndAudioClient.client.luau
-- Manages Music (BGMGroup) & SFX (SFXGroup) SoundGroups and audio cues synced with DataStore settings

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local SoundConfig = require(ReplicatedStorage.Config.SoundConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

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

local function playSFX(assetId: string)
	local s = Instance.new("Sound")
	s.SoundId = assetId
	s.SoundGroup = sfxGroup
	s.Volume = 0.8
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

local function applyAudioSettings(settings: any)
	bgmGroup.Volume = if settings.musicEnabled then (settings.musicVolume or 0.45) else 0
	sfxGroup.Volume = if settings.sfxEnabled then (settings.sfxVolume or 0.75) else 0
end

applyAudioSettings(GameConfig.DEFAULT_SETTINGS)

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and type(profile.settings) == "table" then
		applyAudioSettings(profile.settings)
	end
end)

Remotes.Get("CrateDelivered").OnClientEvent:Connect(function()
	playSFX(SoundConfig.SFX.CoinCollect)
end)

Remotes.Get("PoacherAlertSync").OnClientEvent:Connect(function(active)
	if active then
		playSFX(SoundConfig.SFX.PoacherAlarm)
	end
end)

Remotes.Get("PullProgressSync").OnClientEvent:Connect(function(data)
	if data.completed then
		playSFX(SoundConfig.SFX.CratePop)
	end
end)
