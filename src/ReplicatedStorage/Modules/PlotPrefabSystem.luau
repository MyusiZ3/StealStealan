--!strict
-- PlotPrefabSystem.luau
-- Unity-style Prefab system for Open-Pen Plots: maintains ReplicatedStorage.Prefabs.OpenPlotPrefab
-- as the single editable source template and synchronizes Plot_1..Plot_6 from it cleanly.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlotVisualBuilder = require(ReplicatedStorage.Modules.PlotVisualBuilder)

local PlotPrefabSystem = {}

local RESURFACE_STUDS_COLOR_MAP = "rbxassetid://10509831729"
local RESURFACE_STUDS_NORMAL_MAP = "rbxassetid://10509831753"

function PlotPrefabSystem.EnsureClassicStudsVariant(): MaterialVariant
	for _, obj in ipairs(MaterialService:GetDescendants()) do
		if obj:IsA("MaterialVariant")
			and obj.ColorMap == RESURFACE_STUDS_COLOR_MAP
			and obj.NormalMap == RESURFACE_STUDS_NORMAL_MAP
			and obj.StudsPerTile == 1
		then
			return obj
		end
	end
	local variant = Instance.new("MaterialVariant")
	variant.Name = "Studs"
	variant.BaseMaterial = Enum.Material.Plastic
	variant.ColorMap = RESURFACE_STUDS_COLOR_MAP
	variant.NormalMap = RESURFACE_STUDS_NORMAL_MAP
	variant.StudsPerTile = 1
	variant.Parent = MaterialService
	return variant
end

PlotPrefabSystem.PLOT_BASE_Y = -0.98 -- PlotBase Size.Y = 2 -> top at +0.02 (flush with HubFloor Y=0 without Z-fighting)
PlotPrefabSystem.Z_POSITIONS = { -82, -4, 74 }
PlotPrefabSystem.PREFAB_ORIGIN_CF = CFrame.new(0, PlotPrefabSystem.PLOT_BASE_Y, 0)

local PLOT_INDEX_PARTS = {
	OpenPaddockFloor = true,
	CashCollectorPad = true,
	PenUpgradeBoard = true,
	TreadmillUpgradeBoard = true,
	TreadmillPad = true,
	TreadmillStandAnchor = true,
}

function PlotPrefabSystem.GetPlotSlotCFrame(plotIndex: number): CFrame
	local col = if plotIndex <= 3 then 1 else 2
	local row = ((plotIndex - 1) % 3) + 1
	local x = if col == 1 then -62 else 62
	local facingDirX = if col == 1 then 1 else -1
	local yaw = if facingDirX > 0 then -math.pi / 2 else math.pi / 2
	local z = PlotPrefabSystem.Z_POSITIONS[row] or 0
	return CFrame.new(Vector3.new(x, PlotPrefabSystem.PLOT_BASE_Y, z)) * CFrame.Angles(0, yaw, 0)
end

function PlotPrefabSystem.GetOrCreatePrefabsFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Prefabs")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Prefabs"
	folder.Parent = ReplicatedStorage
	return folder
end

function PlotPrefabSystem.GetOpenPlotPrefab(): Model?
	local prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
	if not prefabs then
		return nil
	end
	local model = prefabs:FindFirstChild("OpenPlotPrefab")
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

function PlotPrefabSystem.BuildDefaultOpenPlotPrefab(forceRebuild: boolean?): Model
	PlotPrefabSystem.EnsureClassicStudsVariant()
	local prefabsFolder = PlotPrefabSystem.GetOrCreatePrefabsFolder()
	local existing = prefabsFolder:FindFirstChild("OpenPlotPrefab")
	if existing and existing:IsA("Model") and not forceRebuild then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local prefabModel = Instance.new("Model")
	prefabModel.Name = "OpenPlotPrefab"
	prefabModel:SetAttribute("IsPlotPrefab", true)
	prefabModel:SetAttribute("PlotIndex", 0)
	prefabModel:SetAttribute("OwnerUserId", 0)
	prefabModel:SetAttribute("PrefabVersion", 1)

	local plotCF = PlotPrefabSystem.PREFAB_ORIGIN_CF
	local surfaceY = PlotVisualBuilder.GetPlotSurfaceY(plotCF)

	-- 1. Main Plot Foundation (64 wide x 64 deep), flush with surrounding terrain
	local base = PlotVisualBuilder.MakePart({
		name = "PlotBase",
		size = Vector3.new(64, 2, 64),
		cframe = plotCF,
		color = Color3.fromRGB(108, 184, 88),
		material = Enum.Material.Plastic,
		materialVariant = "Studs",
		studded = true,
		parent = prefabModel,
	})
	prefabModel.PrimaryPart = base
	prefabModel.WorldPivot = plotCF

	-- Flush front stone border inlay (no protruding step!)
	PlotVisualBuilder.MakePart({
		name = "FrontCurb",
		size = Vector3.new(64, 0.08, 2.2),
		cframe = plotCF * CFrame.new(0, 1.00, -30.9),
		color = Color3.fromRGB(224, 206, 168),
		material = Enum.Material.Plastic,
		materialVariant = "Studs",
		studded = true,
		parent = prefabModel,
	})

	-- 2. Flush Open-Pen Roaming Paddock (no elevated tier above PlotBase)
	local paddockFloor = PlotVisualBuilder.MakePart({
		name = "OpenPaddockFloor",
		size = Vector3.new(52, 0.08, 36),
		cframe = plotCF * CFrame.new(0, 1.00, 10),
		color = Color3.fromRGB(122, 198, 94),
		material = Enum.Material.Plastic,
		materialVariant = "Studs",
		studded = true,
		parent = prefabModel,
	})
	paddockFloor:SetAttribute("IsOpenPaddock", true)
	paddockFloor:SetAttribute("PlotIndex", 0)
	PlotVisualBuilder.AddPrompt(paddockFloor, "Drop Carried Crates", "Sanctuary Pen", "PenDropPrompt")

	-- Tier 1 evolving perimeter fence
	PlotVisualBuilder.BuildPenFences(prefabModel, plotCF, 1)

	-- 3. Compact Cash Collector Pad (right side near front gate)
	local cashPad = PlotVisualBuilder.MakeEnhancedPad({
		name = "CashCollectorPad",
		size = Vector3.new(7.5, 0.5, 9.0),
		cframe = plotCF * CFrame.new(-8, 1.24, -15.5) * CFrame.Angles(0, math.rad(90), 0),
		accentColor = Color3.fromRGB(68, 252, 126),
		bgColor = Color3.fromRGB(14, 52, 28),
		titleText = "COLLECT: $0",
		subText = "$0/s Pen Income",
		canCollide = false,
		withHalo = true,
		parent = prefabModel,
	})
	cashPad:SetAttribute("PlotIndex", 0)
	PlotVisualBuilder.AddPrompt(cashPad, "Collect Coins", "Zoo Pen Cash", "CollectCashPrompt")

	-- 4. 3D Wooden-Post Pen Upgrade Signboard placed beside CashCollectorPad in front of right fence (Image 1 layout)
	PlotVisualBuilder.BuildUpgradeSignboard({
		name = "PenUpgradeBoard",
		boardCF = plotCF * CFrame.new(-19.5, surfaceY, -13.5),
		surfaceY = surfaceY,
		titleText = "Upgrade Pen",
		subText = "Lv. 1 > Lv. 2 (8 > 9)",
		priceText = "$600",
		accentColor = Color3.fromRGB(184, 102, 255),
		promptName = "UpgradePenPrompt",
		actionText = "Upgrade Pen",
		objectText = "Pen Upgrade Board",
		plotIndex = 0,
		parent = prefabModel,
	})

	-- 5. Personal Evolving Treadmill & Stand Anchor (left side)
	local treadmillZone = PlotVisualBuilder.MakePart({
		name = "TreadmillPad",
		size = Vector3.new(7.5, 6.0, 9.2),
		cframe = plotCF * CFrame.new(12, 3.5, -23.5) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(0, 255, 255),
		canCollide = false,
		canQuery = false,
		transparency = 1,
		parent = prefabModel,
	})
	treadmillZone:SetAttribute("IsTreadmillZone", true)
	treadmillZone:SetAttribute("PlotIndex", 0)

	local treadAnchor = PlotVisualBuilder.MakePart({
		name = "TreadmillStandAnchor",
		size = Vector3.new(2, 1, 2),
		cframe = plotCF * CFrame.new(12, 5.3, -22.5),
		color = Color3.fromRGB(0, 255, 255),
		canCollide = false,
		canQuery = false,
		transparency = 1,
		parent = prefabModel,
	})
	treadAnchor:SetAttribute("PlotIndex", 0)

	PlotVisualBuilder.BuildTreadmillTier(prefabModel, plotCF, 1)

	-- 6. 3D Wooden-Post Treadmill Upgrade Signboard angled beside outer edge of Treadmill (Image 1 & 2 layout)
	PlotVisualBuilder.BuildUpgradeSignboard({
		name = "TreadmillUpgradeBoard",
		boardCF = plotCF * CFrame.new(18.8, surfaceY, -22.5) * CFrame.Angles(0, math.rad(-32), 0),
		surfaceY = surfaceY,
		titleText = "Upgrade Treadmill",
		subText = "Lv. 1 > Lv. 2 (+2 > +6)",
		priceText = "$400",
		accentColor = Color3.fromRGB(48, 212, 255),
		promptName = "UpgradeTreadmillPrompt",
		actionText = "Upgrade Treadmill",
		objectText = "Treadmill Board",
		plotIndex = 0,
		parent = prefabModel,
	})

	prefabModel.Parent = prefabsFolder
	return prefabModel
end

function PlotPrefabSystem.InstantiatePlotFromPrefab(prefab: Model, plotIndex: number, plotCF: CFrame, parent: Instance): Model
	local clone = prefab:Clone()
	local cloneBase = clone.PrimaryPart or clone:FindFirstChild("PlotBase")
	assert(cloneBase and cloneBase:IsA("BasePart"), "OpenPlotPrefab requires a BasePart named PlotBase (or PrimaryPart)")
	clone.PrimaryPart = cloneBase

	local oldSurfaceY = PlotVisualBuilder.GetPlotSurfaceY(cloneBase.CFrame)
	-- Align WorldPivot to PlotBase so any Studio edits inside OpenPlotPrefab preserve exact relative offsets
	clone.WorldPivot = cloneBase.CFrame
	clone:PivotTo(plotCF)

	clone.Name = "Plot_" .. tostring(plotIndex)
	clone:SetAttribute("IsPlotPrefab", nil)
	clone:SetAttribute("PrefabSource", prefab.Name)
	clone:SetAttribute("PlotIndex", plotIndex)
	clone:SetAttribute("OwnerUserId", 0)
	if clone:GetAttribute("AppliedPenTier") == nil then
		clone:SetAttribute("AppliedPenTier", 1)
	end
	if clone:GetAttribute("AppliedTreadTier") == nil then
		clone:SetAttribute("AppliedTreadTier", 1)
	end

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:GetAttribute("PlotIndex") ~= nil or PLOT_INDEX_PARTS[desc.Name] then
			desc:SetAttribute("PlotIndex", plotIndex)
		end
	end

	local standAnchor = clone:FindFirstChild("TreadmillStandAnchor")
	if standAnchor and standAnchor:IsA("BasePart") then
		local newSurfaceY = PlotVisualBuilder.GetPlotSurfaceY(cloneBase.CFrame)
		local oldBeltY = standAnchor:GetAttribute("BeltSurfaceY")
		local beltRelOffset = if type(oldBeltY) == "number" then (oldBeltY - oldSurfaceY) else 1.24
		standAnchor:SetAttribute("BeltSurfaceY", newSurfaceY + beltRelOffset)
	end

	clone.Parent = parent
	return clone
end

function PlotPrefabSystem.SyncAllPlotsFromPrefab(worldFolder: Instance?, createIfMissing: boolean?): number
	if not worldFolder then
		return 0
	end
	local hub = worldFolder:FindFirstChild("SanctuaryHub")
	local plotsFolder = if hub then hub:FindFirstChild("Plots") else nil
	if not plotsFolder then
		return 0
	end

	local prefab = PlotPrefabSystem.GetOpenPlotPrefab()
	if not prefab then
		if createIfMissing then
			prefab = PlotPrefabSystem.BuildDefaultOpenPlotPrefab(false)
		else
			return 0
		end
	end
	if not prefab then
		return 0
	end

	local existingSlots: { [number]: CFrame } = {}
	for _, child in ipairs(plotsFolder:GetChildren()) do
		if child:IsA("Model") then
			local pIdx = tonumber(child:GetAttribute("PlotIndex"))
			if pIdx then
				local base = child.PrimaryPart or child:FindFirstChild("PlotBase")
				if base and base:IsA("BasePart") then
					existingSlots[pIdx] = base.CFrame
				end
			end
		end
	end

	local synced = 0
	for i = 1, 6 do
		local oldPlot = plotsFolder:FindFirstChild("Plot_" .. tostring(i))
		local targetCF = existingSlots[i] or PlotPrefabSystem.GetPlotSlotCFrame(i)
		if oldPlot then
			oldPlot:Destroy()
		end
		PlotPrefabSystem.InstantiatePlotFromPrefab(prefab, i, targetCF, plotsFolder)
		synced += 1
	end

	return synced
end

function PlotPrefabSystem.SyncWorkspacePlots(): number
	return PlotPrefabSystem.SyncAllPlotsFromPrefab(Workspace:FindFirstChild("GameWorld"), false)
end

return PlotPrefabSystem
