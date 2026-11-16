--!strict
-- Remotes.luau
-- Creates and retrieves RemoteEvents and RemoteFunctions under ReplicatedStorage.RemotesFolder

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "GameRemotes"

local EVENT_NAMES = {
	-- Rescue & Lasso
	"RequestStartPull",
	"RequestCancelPull",
	"LassoTapBoost",
	"PullProgressSync",
	"PlaceCrateInStall",
	"CrateDelivered",
	-- Plot & Zoo
	"ClaimStallCoins",
	"UpgradeStall",
	"OpenCrate",
	"EquipAnimalToStall",
	"UnequipStallAnimal",
	"MountAnimal",
	-- Fuse & Merge
	"RequestMergeAnimals",
	"RequestCrossFuse",
	-- Economy & Shop
	"BuyLasso",
	"EquipLasso",
	"BuyVehicle",
	"EquipVehicle",
	"SpawnVehicle",
	"RequestRebirth",
	-- Training
	"TrainingPulse",
	"TrainingTapOrb",
	-- Settings, Daily & Sync
	"UpdateSettings",
	"ClaimDailyReward",
	"ProfileSync",
	"NotifyClient",
	"PoacherAlertSync",
	-- Monetization
	"PromptGamePass",
	"PromptProduct",
}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		for _, name in EVENT_NAMES do
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
		return folder
	else
		return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
end

function Remotes.InitServer()
	if RunService:IsServer() then
		getFolder()
	end
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getFolder()
	local ev = folder:WaitForChild(name, 10)
	assert(ev and ev:IsA("RemoteEvent"), "[Remotes] Missing RemoteEvent: " .. name)
	return ev :: RemoteEvent
end

return Remotes
