--!strict
-- VFXDirectorClient.client.luau
-- Binds wild Cosmic+ crate ground runes/shards and dispatches broadcasted world VFX
-- (LassoExtract, MergeBurst, RebirthAscend) via CinematicVFX.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CinematicVFX = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CinematicVFX"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local lowVFX = false

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and type(profile.settings) == "table" then
		lowVFX = (profile.settings.lowVFX == true)
	end
end)

CinematicVFX.BindWildCrateAuras(function()
	return lowVFX
end)

Remotes.Get("PlayWorldVFX").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "LassoExtract" then
		if typeof(payload.pos) == "Vector3" then
			CinematicVFX.PlayLassoExtractBurst(
				payload.pos,
				tostring(payload.rarity or "Common"),
				tostring(payload.biomeId or "PineWoods"),
				tonumber(payload.scale) or 1.0,
				lowVFX
			)
		end
	elseif kind == "MergeBurst" then
		local p = Players:GetPlayerByUserId(tonumber(payload.userId) or 0)
		local target: any = if p and p.Character then p.Character else Vector3.new(0, 4, 0)
		CinematicVFX.PlayMergeBurst(
			target,
			tostring(payload.rarity or "Mythic"),
			tostring(payload.mutation or "None"),
			tonumber(payload.scale) or 1.15,
			lowVFX
		)
	elseif kind == "RebirthAscend" then
		local p = Players:GetPlayerByUserId(tonumber(payload.userId) or 0)
		if p and p.Character then
			CinematicVFX.PlayRebirthAscension(p.Character, tonumber(payload.rebirths) or 1, lowVFX)
		end
	end
end)
