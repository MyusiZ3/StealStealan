--!strict
-- Remotes.luau
-- Initializes and retrieves RemoteEvents under ReplicatedStorage.GameRemotes

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
	"GrabExtractedCrate",
	"DropCarriedCrate",
	"DeliverCrateToPen",
	"CrateDelivered",
	"PlayerKnockback",
	-- Open-Pen Zoo & Upgrades
	"ClaimPenCoins",
	"UpgradePen",
	"UpgradeTreadmill",
	"OpenPendingCrate",
	"PlaceCrateInPen",
	"PlacePetInPen",
	"CrateHatchReveal",
	"EquipAnimalToPen",
	"EquipBestAnimals",
	"UnequipPenAnimal",
	"ToggleLockAnimal",
	"SellAnimal",
	"MountAnimal",
	-- Index & Fuse/Merge
	"ClaimIndexReward",
	"ClaimAllIndexRewards",
	"RequestMergeAnimals",
	"RequestCrossFuse",
	-- Gear, Trails & Vehicles
	"BuyLasso",
	"EquipLasso",
	"BuyTrail",
	"EquipTrail",
	"BuyVehicle",
	"EquipVehicle",
	"SpawnVehicle",
	"RequestRebirth",
	"SetHeldItem",
	-- Training
	"TrainingPulse",
	"TrainingTapOrb",
	"SetMovementState",
	"TreadmillState",
	-- Settings, Daily & Sync
	"UpdateSettings",
	"ClaimDailyReward",
	"ProfileSync",
	"AllPlotsSync",
	"LeaderboardSync",
	"NotifyClient",
	"PoacherAlertSync",
	-- Admin Panel & Live Events
	"AdminCommand",
	"AdminStateSync",
	"GlobalEventBanner",
	"BiomeWaveSync",
	"CrateSpawnAnnounce",
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
		for _, name in ipairs(EVENT_NAMES) do
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
		local folder = getFolder()
		for _, name in ipairs(EVENT_NAMES) do
			if not folder:FindFirstChild(name) then
				local ev = Instance.new("RemoteEvent")
				ev.Name = name
				ev.Parent = folder
			end
		end
	end
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getFolder()
	local ev = folder:WaitForChild(name, 10)
	assert(ev and ev:IsA("RemoteEvent"), "[Remotes] Missing RemoteEvent: " .. name)
	return ev :: RemoteEvent
end

return Remotes
