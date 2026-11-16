--!strict
-- SanctuarySixPlotGenerator.luau
-- Generates the Sanctuary Base Hub (Safe Zone), 6 Pre-Allocated Open-Pen Roaming Plots (no stalls, 8->20 capacity),
-- Personal Upgradeable Treadmills, Cash Collector Pads, Trail Shop, Lasso Shop, Fuse Machine, Vehicle Garage, & Merchant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SanctuarySixPlotGenerator = {}

local function makePart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	materialVariant: string?,
	studded: boolean?,
	canCollide: boolean?,
	canQuery: boolean?,
	transparency: number?,
	parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.name
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	if props.materialVariant and props.materialVariant ~= "" then
		p.MaterialVariant = props.materialVariant
	end
	p.TopSurface = if props.studded then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	p.CanQuery = if props.canQuery ~= nil then props.canQuery else true
	p.Transparency = props.transparency or 0
	p.Parent = props.parent
	return p
end

local function addSurfaceSign(part: BasePart, face: Enum.NormalId, titleText: string, subText: string?, bgColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = bgColor or Color3.fromRGB(26, 32, 42)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = if subText then UDim2.fromScale(0.92, 0.55) else UDim2.fromScale(0.92, 0.85)
	title.Position = UDim2.fromScale(0.04, 0.08)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Parent = frame

	if subText then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.Size = UDim2.fromScale(0.92, 0.30)
		sub.Position = UDim2.fromScale(0.04, 0.64)
		sub.BackgroundTransparency = 1
		sub.Text = subText
		sub.TextColor3 = Color3.fromRGB(255, 214, 92)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.Parent = frame
	end
end

local function addPrompt(parent: Instance, actionText: string, objectText: string, tag: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = tag
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function groundModel(model: Model, targetBottomY: number)
	local cf, size = model:GetBoundingBox()
	local currentBottomY = cf.Position.Y - size.Y * 0.5
	local deltaY = targetBottomY - currentBottomY
	if math.abs(deltaY) > 0.02 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, deltaY, 0))
	end
end

local function cloneCuratedModel(name: string, targetCFrame: CFrame, scaleFactor: number, parent: Instance, groundY: number?, nonCollide: boolean?): Model?
	local ca = ReplicatedStorage:FindFirstChild("CuratedAssets")
	if not ca then
		return nil
	end
	local src = ca:FindFirstChild(name)
	if not src or not src:IsA("Model") then
		return nil
	end
	local clone = src:Clone()
	if scaleFactor ~= 1 then
		pcall(function()
			clone:ScaleTo(clone:GetScale() * scaleFactor)
		end)
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if nonCollide then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	clone:PivotTo(targetCFrame)
	clone.Parent = parent
	if groundY ~= nil then
		groundModel(clone, groundY)
	end
	return clone
end

local function buildSingleOpenPlot(plotIndex: number, centerPos: Vector3, facingDirX: number, parentFolder: Folder)
	local plotModel = Instance.new("Model")
	plotModel.Name = "Plot_" .. tostring(plotIndex)
	plotModel:SetAttribute("PlotIndex", plotIndex)
	plotModel:SetAttribute("OwnerUserId", 0)
	plotModel.Parent = parentFolder

	local yaw = if facingDirX > 0 then -math.pi / 2 else math.pi / 2
	local plotCF = CFrame.new(centerPos) * CFrame.Angles(0, yaw, 0)

	-- 1. Main Plot Foundation (64 wide x 64 deep)
	local base = makePart({
		name = "PlotBase",
		size = Vector3.new(64, 2, 64),
		cframe = plotCF,
		color = Color3.fromRGB(108, 184, 88),
		material = Enum.Material.Grass,
		materialVariant = "BlockyStudGrass",
		studded = true,
		parent = plotModel,
	})
	plotModel.PrimaryPart = base

	makePart({
		name = "FrontCurb",
		size = Vector3.new(64, 0.8, 3),
		cframe = plotCF * CFrame.new(0, 1.1, -30.5),
		color = Color3.fromRGB(224, 206, 168),
		material = Enum.Material.Cobblestone,
		studded = true,
		parent = plotModel,
	})

	-- 2. Owner Signboard
	local signPost = makePart({
		name = "OwnerSignPost",
		size = Vector3.new(1.5, 9, 1.5),
		cframe = plotCF * CFrame.new(-24, 5.5, -29),
		color = Color3.fromRGB(98, 68, 44),
		material = Enum.Material.Wood,
		canQuery = false,
		parent = plotModel,
	})
	local signBoard = makePart({
		name = "OwnerSignBoard",
		size = Vector3.new(16, 6, 1),
		cframe = plotCF * CFrame.new(-24, 10, -29),
		color = Color3.fromRGB(34, 42, 56),
		parent = plotModel,
	})
	addSurfaceSign(signBoard, Enum.NormalId.Front, "ZOO SANCTUARY #" .. plotIndex, "Open-Pen (0/8 Animals)", Color3.fromRGB(30, 42, 58))
	addSurfaceSign(signBoard, Enum.NormalId.Back, "ZOO SANCTUARY #" .. plotIndex, "Open-Pen (0/8 Animals)", Color3.fromRGB(30, 42, 58))
	signPost.CanCollide = true

	cloneCuratedModel("WoodenFenceGate", plotCF * CFrame.new(-12, 3.6, -30.5), 1.3, plotModel, 1.2)

	-- 3. Open-Pen Roaming Paddock (NO STALLS! Animals walk around freely inside 52 x 36 enclosure)
	local paddockFloor = makePart({
		name = "OpenPaddockFloor",
		size = Vector3.new(52, 0.5, 36),
		cframe = plotCF * CFrame.new(0, 1.25, 10),
		color = Color3.fromRGB(122, 198, 94),
		material = Enum.Material.Grass,
		materialVariant = "BlockyStudGrass",
		studded = true,
		parent = plotModel,
	})
	paddockFloor:SetAttribute("IsOpenPaddock", true)
	paddockFloor:SetAttribute("PlotIndex", plotIndex)

	-- Perimeter Fence around Open Paddock (leaving open front walkway)
	local fenceColor = Color3.fromRGB(142, 96, 54)
	makePart({
		name = "FenceBack",
		size = Vector3.new(54, 3.2, 1.4),
		cframe = plotCF * CFrame.new(0, 2.8, 28.5),
		color = fenceColor,
		material = Enum.Material.Wood,
		parent = plotModel,
	})
	makePart({
		name = "FenceLeft",
		size = Vector3.new(1.4, 3.2, 38),
		cframe = plotCF * CFrame.new(-26.5, 2.8, 10),
		color = fenceColor,
		material = Enum.Material.Wood,
		parent = plotModel,
	})
	makePart({
		name = "FenceRight",
		size = Vector3.new(1.4, 3.2, 38),
		cframe = plotCF * CFrame.new(26.5, 2.8, 10),
		color = fenceColor,
		material = Enum.Material.Wood,
		parent = plotModel,
	})
	-- Front Fence with 14-stud wide entrance gap in center
	for _, xSide in { -16.5, 16.5 } do
		makePart({
			name = "FenceFront_" .. tostring(xSide),
			size = Vector3.new(20, 3.2, 1.4),
			cframe = plotCF * CFrame.new(xSide, 2.8, -8.5),
			color = fenceColor,
			material = Enum.Material.Wood,
			parent = plotModel,
		})
	end

	-- 4. Front Functional Pads (Unbox Crate | Cash Collector | Pen Capacity Upgrade | Personal Treadmill)
	-- A. Crate Unbox Pad
	local unboxPad = makePart({
		name = "CrateUnboxPad",
		size = Vector3.new(11, 0.6, 8),
		cframe = plotCF * CFrame.new(-20, 1.3, -16),
		color = Color3.fromRGB(255, 168, 52),
		studded = true,
		parent = plotModel,
	})
	unboxPad:SetAttribute("PlotIndex", plotIndex)
	addSurfaceSign(unboxPad, Enum.NormalId.Top, "DROP & UNBOX CRATE", "Step here with crate!", Color3.fromRGB(168, 86, 22))
	addPrompt(unboxPad, "Drop / Open Crate", "Crate Unbox Pad", "UnboxPadPrompt")

	-- B. Cash Collector Pad
	local cashPad = makePart({
		name = "CashCollectorPad",
		size = Vector3.new(12, 0.6, 8),
		cframe = plotCF * CFrame.new(-6, 1.3, -16),
		color = Color3.fromRGB(82, 232, 118),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = plotModel,
	})
	cashPad:SetAttribute("PlotIndex", plotIndex)
	addSurfaceSign(cashPad, Enum.NormalId.Top, "COLLECT CASH: $0", "0/s Pen Income", Color3.fromRGB(24, 122, 54))
	addPrompt(cashPad, "Collect Coins", "Zoo Pen Cash", "CollectCashPrompt")

	-- C. Pen Capacity Upgrade Stand (8 -> 20)
	local upgradePad = makePart({
		name = "PenUpgradePad",
		size = Vector3.new(11, 0.6, 8),
		cframe = plotCF * CFrame.new(8, 1.3, -16),
		color = Color3.fromRGB(152, 92, 255),
		studded = true,
		parent = plotModel,
	})
	upgradePad:SetAttribute("PlotIndex", plotIndex)
	addSurfaceSign(upgradePad, Enum.NormalId.Top, "UPGRADE PEN (8/20)", "Next: $600", Color3.fromRGB(84, 34, 158))
	addPrompt(upgradePad, "Upgrade Pen Capacity", "Zoo Capacity (8->20)", "UpgradePenPrompt")

	-- D. Personal Upgradeable Treadmill Track (Right Front) + 3D Treadmill Model & Snap Anchor
	local treadmillPad = makePart({
		name = "TreadmillPad",
		size = Vector3.new(26, 0.6, 8.5),
		cframe = plotCF * CFrame.new(12, 1.3, -24.5),
		color = Color3.fromRGB(58, 168, 255),
		studded = true,
		parent = plotModel,
	})
	treadmillPad:SetAttribute("IsTreadmillZone", true)
	treadmillPad:SetAttribute("PlotIndex", plotIndex)
	addSurfaceSign(treadmillPad, Enum.NormalId.Top, "TREADMILL LV.1", "Step on Belt to Run!", Color3.fromRGB(24, 96, 178))
	addPrompt(treadmillPad, "Upgrade Treadmill", "Speed Training Lv.1", "UpgradeTreadmillPrompt")

	local treadMesh = cloneCuratedModel("Hero_Treadmill_AI", plotCF * CFrame.new(12, 4.0, -24.5) * CFrame.Angles(0, math.pi, 0), 1.35, plotModel, 1.6, true)
	if not treadMesh then
		cloneCuratedModel("Hero_Treadmill", plotCF * CFrame.new(12, 4.0, -24.5), 1.0, plotModel, 1.6, true)
	end

	local treadAnchor = makePart({
		name = "TreadmillStandAnchor",
		size = Vector3.new(2, 1, 2),
		cframe = plotCF * CFrame.new(12, 4.4, -24.5) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(0, 255, 255),
		canCollide = false,
		canQuery = false,
		transparency = 1,
		parent = plotModel,
	})
	treadAnchor:SetAttribute("PlotIndex", plotIndex)
end

function SanctuarySixPlotGenerator.Build(worldFolder: Folder)
	local existing = worldFolder:FindFirstChild("SanctuaryHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "SanctuaryHub"
	hub.Parent = worldFolder

	-- 1. Main Sanctuary Floor (Blocky Studded Grass)
	makePart({
		name = "HubFloor",
		size = Vector3.new(260, 4, 290),
		cframe = CFrame.new(0, -2, 5),
		color = Color3.fromRGB(94, 174, 82),
		material = Enum.Material.Grass,
		materialVariant = "BlockyStudGrass",
		studded = true,
		parent = hub,
	})

	-- Central Stone Boulevard
	makePart({
		name = "CentralBoulevard",
		size = Vector3.new(44, 0.6, 290),
		cframe = CFrame.new(0, 0.25, 5),
		color = Color3.fromRGB(162, 158, 148),
		material = Enum.Material.Cobblestone,
		studded = true,
		parent = hub,
	})

	for _, side in { -22.5, 22.5 } do
		makePart({
			name = "BoulevardCurb_" .. tostring(side),
			size = Vector3.new(2, 1.0, 290),
			cframe = CFrame.new(side, 0.5, 5),
			color = Color3.fromRGB(238, 224, 178),
			studded = true,
			parent = hub,
		})
	end

	-- 2. Spawn Plaza (Z = -110)
	makePart({
		name = "SpawnPlaza",
		size = Vector3.new(36, 0.8, 36),
		cframe = CFrame.new(0, 0.4, -110),
		color = Color3.fromRGB(76, 156, 224),
		studded = true,
		parent = hub,
	})
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "RangerSpawn"
	spawnLoc.Size = Vector3.new(12, 1, 12)
	spawnLoc.CFrame = CFrame.new(0, 0.85, -110)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(255, 206, 56)
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.TopSurface = Enum.SurfaceType.Studs
	spawnLoc.Duration = 0
	spawnLoc.Parent = hub

	-- 3. Row 1 (Z = -55): Lasso Gear Shop (Left) & Trail Multiplier Shop (Right)
	local lassoShopPad = makePart({
		name = "LassoShopPad",
		size = Vector3.new(15, 0.9, 14),
		cframe = CFrame.new(-13, 0.5, -55),
		color = Color3.fromRGB(244, 162, 52),
		studded = true,
		parent = hub,
	})
	addSurfaceSign(lassoShopPad, Enum.NormalId.Top, "LASSO GEAR SHOP", "10 Tiers: 150 -> 750Qi!", Color3.fromRGB(148, 82, 18))
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(-16, 6, -55) * CFrame.Angles(0, math.rad(90), 0), 0.95, hub, 0.95, true)
	addPrompt(lassoShopPad, "Open Lasso Shop", "10 Lasso Tiers", "LassoShopPrompt")

	local trailShopPad = makePart({
		name = "TrailShopPad",
		size = Vector3.new(15, 0.9, 14),
		cframe = CFrame.new(13, 0.5, -55),
		color = Color3.fromRGB(0, 212, 255),
		studded = true,
		parent = hub,
	})
	addSurfaceSign(trailShopPad, Enum.NormalId.Top, "TRAIL SPEED SHOP", "1.25x -> 750x Speed!", Color3.fromRGB(18, 108, 158))
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(16, 6, -55) * CFrame.Angles(0, math.rad(-90), 0), 0.95, hub, 0.95, true)
	addPrompt(trailShopPad, "Open Trail Shop", "Speed Multiplier Trails", "TrailShopPrompt")

	-- 4. Row 2 (Z = 0): Mutation & Fuse Machine (Left) & Vehicle Garage (Right)
	local fuseZone = Instance.new("Model")
	fuseZone.Name = "FuseAndMergePlaza"
	fuseZone.Parent = hub

	local fusePad = makePart({
		name = "FusePad",
		size = Vector3.new(18, 0.9, 18),
		cframe = CFrame.new(-12, 0.5, 0),
		color = Color3.fromRGB(168, 86, 255),
		studded = true,
		parent = fuseZone,
	})
	addSurfaceSign(fusePad, Enum.NormalId.Top, "FUSE & MUTATION", "Merge -> Golden/Rainbow/Celestial!", Color3.fromRGB(84, 34, 158))
	local fuseHero = cloneCuratedModel("Hero_FuseMachine", CFrame.new(-12, 5.2, 0), 0.9, fuseZone, 0.95)
	local fusePromptPart: BasePart = fusePad
	if fuseHero then
		for _, p in ipairs(fuseHero:GetDescendants()) do
			if p:IsA("BasePart") then
				fusePromptPart = p
				break
			end
		end
	end
	addPrompt(fusePromptPart, "Open Fuse Machine", "Mutation & Fuse Machine", "FusePrompt")

	local vehicleShopPad = makePart({
		name = "VehicleGaragePad",
		size = Vector3.new(18, 0.9, 18),
		cframe = CFrame.new(12, 0.5, 0),
		color = Color3.fromRGB(64, 188, 128),
		studded = true,
		parent = hub,
	})
	addSurfaceSign(vehicleShopPad, Enum.NormalId.Top, "VEHICLE GARAGE", "Spawn & Upgrade Ride!", Color3.fromRGB(28, 108, 68))
	cloneCuratedModel("Hero_SafariATV", CFrame.new(12, 3.6, 0) * CFrame.Angles(0, math.rad(-145), 0), 1.15, hub, 0.95)
	addPrompt(vehicleShopPad, "Open Vehicle Garage", "Expedition Vehicles", "VehicleShopPrompt")

	-- 5. Row 3 (Z = 58): Rebirth Shrine (Left) & Animal Merchant / Index Board (Right)
	local rebirthPad = makePart({
		name = "RebirthAltarPad",
		size = Vector3.new(15, 0.9, 14),
		cframe = CFrame.new(-13, 0.5, 58),
		color = Color3.fromRGB(255, 86, 132),
		studded = true,
		parent = hub,
	})
	addSurfaceSign(rebirthPad, Enum.NormalId.Top, "REBIRTH & DAILY", "Permanent Multiplier!", Color3.fromRGB(142, 26, 68))
	cloneCuratedModel("Hero_RebirthPortal", CFrame.new(-16, 6, 58), 0.72, hub, 0.95, true)
	addPrompt(rebirthPad, "Open Rebirth / Daily", "Ranger Prestige", "RebirthPrompt")

	local merchantPad = makePart({
		name = "AnimalMerchantPad",
		size = Vector3.new(15, 0.9, 14),
		cframe = CFrame.new(13, 0.5, 58),
		color = Color3.fromRGB(255, 206, 62),
		studded = true,
		parent = hub,
	})
	addSurfaceSign(merchantPad, Enum.NormalId.Top, "INDEX & MERCHANT", "Sell Extras & Claim 63 Index!", Color3.fromRGB(132, 92, 18))
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(16, 6, 58) * CFrame.Angles(0, math.rad(-90), 0), 0.95, hub, 0.95, true)
	addPrompt(merchantPad, "Open Index / Sell", "Animal Index & Merchant", "IndexPrompt")

	-- 6. Grand Sanctuary Safe-Zone Exit Gate at Z = 148
	local gateFolder = Instance.new("Model")
	gateFolder.Name = "SanctuaryExitGate"
	gateFolder.Parent = hub

	makePart({
		name = "GatePillarLeft",
		size = Vector3.new(6, 22, 6),
		cframe = CFrame.new(-24, 11, 148),
		color = Color3.fromRGB(118, 82, 48),
		material = Enum.Material.Wood,
		parent = gateFolder,
	})
	makePart({
		name = "GatePillarRight",
		size = Vector3.new(6, 22, 6),
		cframe = CFrame.new(24, 11, 148),
		color = Color3.fromRGB(118, 82, 48),
		material = Enum.Material.Wood,
		parent = gateFolder,
	})
	local gateBanner = makePart({
		name = "GateBanner",
		size = Vector3.new(54, 7, 3),
		cframe = CFrame.new(0, 21, 148),
		color = Color3.fromRGB(36, 46, 62),
		parent = gateFolder,
	})
	addSurfaceSign(gateBanner, Enum.NormalId.Front, "LEAVING SAFE ZONE ->", "63 Animals Across 5 Zones!", Color3.fromRGB(178, 54, 48))
	addSurfaceSign(gateBanner, Enum.NormalId.Back, "<- SANCTUARY SAFE ZONE", "Bring rescued crates home!", Color3.fromRGB(42, 146, 86))

	makePart({
		name = "SafeZoneLine",
		size = Vector3.new(260, 0.25, 2),
		cframe = CFrame.new(0, 0.2, 150),
		color = Color3.fromRGB(68, 255, 138),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = gateFolder,
	})

	-- Hub Perimeter Walls
	makePart({
		name = "HubWallBack",
		size = Vector3.new(264, 18, 6),
		cframe = CFrame.new(0, 9, -142),
		color = Color3.fromRGB(98, 92, 86),
		material = Enum.Material.Slate,
		studded = true,
		parent = hub,
	})
	for _, xSide in { -130, 130 } do
		makePart({
			name = "HubWallSide_" .. tostring(xSide),
			size = Vector3.new(6, 18, 294),
			cframe = CFrame.new(xSide, 9, 5),
			color = Color3.fromRGB(98, 92, 86),
			material = Enum.Material.Slate,
			studded = true,
			parent = hub,
		})
	end

	-- 7. Build All 6 Pre-Allocated Open-Pen Plots (3 Left, 3 Right)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = hub

	local zPositions = { -82, -4, 74 }
	for i = 1, 3 do
		buildSingleOpenPlot(i, Vector3.new(-62, 0.2, zPositions[i]), 1, plotsFolder)
	end
	for i = 1, 3 do
		buildSingleOpenPlot(i + 3, Vector3.new(62, 0.2, zPositions[i]), -1, plotsFolder)
	end

	return hub
end

return SanctuarySixPlotGenerator
