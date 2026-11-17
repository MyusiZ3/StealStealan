--!strict
-- SanctuarySixPlotGenerator.luau
-- Generates the Sanctuary Base Hub (Safe Zone), 6 Pre-Allocated Open-Pen Roaming Plots (no stalls, 8->20 capacity),
-- Personal Upgradeable Treadmills, Cash Collector Pads, Trail Shop, Lasso Shop, Fuse Machine, Vehicle Garage, & Merchant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotVisualBuilder = require(ReplicatedStorage.Modules.PlotVisualBuilder)

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

local function addSurfaceSign(part: BasePart, face: Enum.NormalId, titleText: string, subText: string?, bgColor: Color3?, accentColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.Active = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.LightInfluence = 0.25
	gui.Parent = part

	local baseCol = bgColor or Color3.fromRGB(24, 30, 42)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = baseCol
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, baseCol:Lerp(Color3.new(1, 1, 1), 0.14)),
		ColorSequenceKeypoint.new(1, baseCol:Lerp(Color3.new(0, 0, 0), 0.35)),
	})
	grad.Parent = frame

	if accentColor then
		local inner = Instance.new("Frame")
		inner.Name = "InsetFrame"
		inner.Size = UDim2.new(1, -18, 1, -18)
		inner.Position = UDim2.fromOffset(9, 9)
		inner.BackgroundColor3 = baseCol:Lerp(Color3.new(0, 0, 0), 0.22)
		inner.BackgroundTransparency = 0.35
		inner.BorderSizePixel = 0
		inner.ZIndex = 1
		inner.Parent = frame
		local ic = Instance.new("UICorner")
		ic.CornerRadius = UDim.new(0, 14)
		ic.Parent = inner
		local ist = Instance.new("UIStroke")
		ist.Thickness = 4
		ist.Color = accentColor
		ist.Parent = inner
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = if subText then UDim2.fromScale(0.88, 0.50) else UDim2.fromScale(0.88, 0.80)
	title.Position = UDim2.fromScale(0.06, 0.12)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.ZIndex = 2
	title.Parent = frame
	local tStroke = Instance.new("UIStroke")
	tStroke.Thickness = 3
	tStroke.Color = Color3.fromRGB(10, 12, 16)
	tStroke.Parent = title

	if subText then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.Size = UDim2.fromScale(0.88, 0.28)
		sub.Position = UDim2.fromScale(0.06, 0.63)
		sub.BackgroundTransparency = 1
		sub.Text = subText
		sub.TextColor3 = Color3.fromRGB(255, 224, 96)
		sub.Font = Enum.Font.FredokaOne
		sub.TextScaled = true
		sub.ZIndex = 2
		sub.Parent = frame
		local sStroke = Instance.new("UIStroke")
		sStroke.Thickness = 2.2
		sStroke.Color = Color3.fromRGB(10, 12, 16)
		sStroke.Parent = sub
	end
end

local function makeEnhancedPad(opts: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	accentColor: Color3,
	bgColor: Color3,
	titleText: string,
	subText: string,
	canCollide: boolean?,
	withHalo: boolean?,
	parent: Instance,
}): Part
	local col = if opts.canCollide ~= nil then opts.canCollide else true

	-- 1. Dark Metallic Base Plinth
	makePart({
		name = opts.name .. "_Plinth",
		size = Vector3.new(opts.size.X + 1.8, opts.size.Y + 0.12, opts.size.Z + 1.8),
		cframe = opts.cframe * CFrame.new(0, -0.14, 0),
		color = Color3.fromRGB(24, 28, 38),
		material = Enum.Material.Metal,
		canCollide = col,
		canQuery = false,
		parent = opts.parent,
	})

	-- 2. Glowing Neon Perimeter Rim
	makePart({
		name = opts.name .. "_NeonRim",
		size = Vector3.new(opts.size.X + 0.95, opts.size.Y - 0.08, opts.size.Z + 0.95),
		cframe = opts.cframe * CFrame.new(0, -0.06, 0),
		color = opts.accentColor,
		material = Enum.Material.Neon,
		canCollide = false,
		canQuery = false,
		parent = opts.parent,
	})

	-- 3. Corner Accent Pillars with Neon Caps
	local hx = opts.size.X * 0.5 + 0.45
	local hz = opts.size.Z * 0.5 + 0.45
	for i, corner in ipairs({
		Vector3.new(-hx, 0, -hz),
		Vector3.new(hx, 0, -hz),
		Vector3.new(-hx, 0, hz),
		Vector3.new(hx, 0, hz),
	}) do
		makePart({
			name = opts.name .. "_Corner_" .. i,
			size = Vector3.new(1.15, opts.size.Y + 0.36, 1.15),
			cframe = opts.cframe * CFrame.new(corner + Vector3.new(0, 0.04, 0)),
			color = Color3.fromRGB(32, 36, 48),
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
			parent = opts.parent,
		})
		makePart({
			name = opts.name .. "_CornerGlow_" .. i,
			size = Vector3.new(0.85, 0.16, 0.85),
			cframe = opts.cframe * CFrame.new(corner + Vector3.new(0, opts.size.Y * 0.5 + 0.24, 0)),
			color = opts.accentColor,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			parent = opts.parent,
		})
	end

	-- 4. Interactive Top Deck (keeps exact name & SignGui structure for PlotService/TrainingSystem)
	local deck = makePart({
		name = opts.name,
		size = opts.size,
		cframe = opts.cframe,
		color = opts.bgColor,
		material = Enum.Material.SmoothPlastic,
		canCollide = col,
		parent = opts.parent,
	})
	addSurfaceSign(deck, Enum.NormalId.Top, opts.titleText, opts.subText, opts.bgColor, opts.accentColor)

	if opts.withHalo then
		local halo = makePart({
			name = opts.name .. "_Halo",
			size = Vector3.new(opts.size.X + 2.8, 0.08, opts.size.Z + 2.8),
			cframe = opts.cframe * CFrame.new(0, -opts.size.Y * 0.5 + 0.05, 0),
			color = opts.accentColor,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			transparency = 0.65,
			parent = opts.parent,
		})
		halo.CastShadow = false
		local pl = Instance.new("PointLight")
		pl.Name = "PadGlow"
		pl.Color = opts.accentColor
		pl.Range = 14
		pl.Brightness = 0.75
		pl.Shadows = false
		pl.Parent = deck
	end

	return deck
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
			if nonCollide or d:IsA("SpawnLocation") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
			if d:IsA("SpawnLocation") then
				d:Destroy()
			end
		elseif d:IsA("BaseScript") or d:IsA("ForceField") then
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

	-- 2. Open-Pen Roaming Paddock (clean front entry without bulky signboard or curb gate)
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

	-- Perimeter Evolving Fence around Open Paddock (starts at Tier 1, evolves as pen upgrades!)
	PlotVisualBuilder.BuildPenFences(plotModel, plotCF, 1)

	-- Prompt on OpenPaddockFloor for dropping carried crates directly inside the Pen
	addPrompt(paddockFloor, "Drop Carried Crates", "Sanctuary Pen", "PenDropPrompt")

	local surfaceY = PlotVisualBuilder.GetPlotSurfaceY(plotCF)

	-- 4. Clean Front Functional Station: Compact Cash Collector + Signboards for Pen & Treadmill Upgrades
	-- A. Compact Cash Collector Pad in front of Pen gate
	local cashPad = makeEnhancedPad({
		name = "CashCollectorPad",
		size = Vector3.new(7.5, 0.5, 9.0),
		cframe = plotCF * CFrame.new(-8, 1.3, -15.5) * CFrame.Angles(0, math.rad(90), 0),
		accentColor = Color3.fromRGB(68, 252, 126),
		bgColor = Color3.fromRGB(14, 52, 28),
		titleText = "COLLECT: $0",
		subText = "$0/s Pen Income",
		canCollide = false,
		withHalo = true,
		parent = plotModel,
	})
	cashPad:SetAttribute("PlotIndex", plotIndex)
	addPrompt(cashPad, "Collect Coins", "Zoo Pen Cash", "CollectCashPrompt")

	-- B. 3D Wooden-Post Pen Upgrade Signboard beside Pen Fence (no floor slab!)
	PlotVisualBuilder.BuildUpgradeSignboard({
		name = "PenUpgradeBoard",
		boardCF = plotCF * CFrame.new(12, surfaceY, -11.5),
		surfaceY = surfaceY,
		titleText = "Upgrade Pen",
		subText = "Lv. 1 > Lv. 2 (8 > 9)",
		priceText = "$600",
		accentColor = Color3.fromRGB(184, 102, 255),
		promptName = "UpgradePenPrompt",
		actionText = "Upgrade Pen",
		objectText = "Pen Upgrade Board",
		plotIndex = plotIndex,
		parent = plotModel,
	})

	-- C. Personal Evolving Treadmill (Clean floor underneath: invisible trigger zone only!)
	local treadmillZone = makePart({
		name = "TreadmillPad",
		size = Vector3.new(7.5, 6.0, 9.2),
		cframe = plotCF * CFrame.new(12, surfaceY + 2.5, -23.5) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(0, 255, 255),
		canCollide = false,
		canQuery = false,
		transparency = 1,
		parent = plotModel,
	})
	treadmillZone:SetAttribute("IsTreadmillZone", true)
	treadmillZone:SetAttribute("PlotIndex", plotIndex)

	local treadAnchor = makePart({
		name = "TreadmillStandAnchor",
		size = Vector3.new(2, 1, 2),
		cframe = plotCF * CFrame.new(12, surfaceY + 4.3, -22.5),
		color = Color3.fromRGB(0, 255, 255),
		canCollide = false,
		canQuery = false,
		transparency = 1,
		parent = plotModel,
	})
	treadAnchor:SetAttribute("PlotIndex", plotIndex)

	PlotVisualBuilder.BuildTreadmillTier(plotModel, plotCF, 1)

	-- D. 3D Wooden-Post Treadmill Upgrade Signboard standing beside Treadmill
	PlotVisualBuilder.BuildUpgradeSignboard({
		name = "TreadmillUpgradeBoard",
		boardCF = plotCF * CFrame.new(20.5, surfaceY, -23.5),
		surfaceY = surfaceY,
		titleText = "Upgrade Treadmill",
		subText = "Lv. 1 > Lv. 2",
		priceText = "$250",
		accentColor = Color3.fromRGB(48, 212, 255),
		promptName = "UpgradeTreadmillPrompt",
		actionText = "Upgrade Treadmill",
		objectText = "Treadmill Board",
		plotIndex = plotIndex,
		parent = plotModel,
	})
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

	-- 3-Board Global Leaderboard Wall at Front-Right Plaza (Top Rebirth | Top Speed | Top Playtime — Top 100 each)
	local lbWall = Instance.new("Model")
	lbWall.Name = "LeaderboardWall"
	lbWall.Parent = hub

	local wallCenterCF = CFrame.lookAt(Vector3.new(68, 0, 128), Vector3.new(10, 0, 75))
	local boardSpecs = {
		{
			name = "TopRebirthBoard",
			offsetX = 13.8,
			title = "♻️ Top Rebirth ♻️",
			frameColor = Color3.fromRGB(36, 224, 92),
			headerColor = Color3.fromRGB(28, 198, 64),
			darkBg = Color3.fromRGB(16, 48, 28),
		},
		{
			name = "TopSpeedBoard",
			offsetX = 0,
			title = "👟 Top Speed 👟",
			frameColor = Color3.fromRGB(48, 168, 255),
			headerColor = Color3.fromRGB(24, 128, 248),
			darkBg = Color3.fromRGB(16, 36, 68),
		},
		{
			name = "TopPlaytimeBoard",
			offsetX = -13.8,
			title = "🕒 Top Playtime 🕒",
			frameColor = Color3.fromRGB(255, 68, 118),
			headerColor = Color3.fromRGB(238, 38, 86),
			darkBg = Color3.fromRGB(58, 16, 32),
		},
	}

	for _, spec in ipairs(boardSpecs) do
		local bm = Instance.new("Model")
		bm.Name = spec.name
		bm.Parent = lbWall

		local bCF = wallCenterCF * CFrame.new(spec.offsetX, 0, 0)

		-- Neon Base Pedestal Glow Strip
		makePart({
			name = "BasePedestal",
			size = Vector3.new(13.6, 0.5, 2.4),
			cframe = bCF * CFrame.new(0, 0.25, 0),
			color = spec.frameColor,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = bm,
		})

		-- Outer Colored Frame
		makePart({
			name = "OuterFrame",
			size = Vector3.new(13.0, 17.6, 1.2),
			cframe = bCF * CFrame.new(0, 9.2, 0),
			color = spec.frameColor,
			material = Enum.Material.SmoothPlastic,
			parent = bm,
		})

		-- White/Ice Inner Border Accent
		makePart({
			name = "InnerBorder",
			size = Vector3.new(12.2, 16.8, 1.3),
			cframe = bCF * CFrame.new(0, 9.2, -0.02),
			color = Color3.fromRGB(236, 244, 255),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = bm,
		})

		-- Main Dark Backing + Interactive Display SurfaceGui (Top 100 ScrollList)
		local display = makePart({
			name = "DisplaySurface",
			size = Vector3.new(11.4, 15.8, 1.4),
			cframe = bCF * CFrame.new(0, 9.1, -0.05),
			color = spec.darkBg,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = bm,
		})

		-- Colored Top Header Banner Ribbon
		local headerPart = makePart({
			name = "HeaderBanner",
			size = Vector3.new(14.2, 2.9, 1.7),
			cframe = bCF * CFrame.new(0, 18.8, -0.15),
			color = spec.headerColor,
			material = Enum.Material.SmoothPlastic,
			parent = bm,
		})
		addSurfaceSign(headerPart, Enum.NormalId.Front, spec.title, nil, spec.headerColor, spec.frameColor)
		addSurfaceSign(headerPart, Enum.NormalId.Back, spec.title, nil, spec.headerColor, spec.frameColor)

		local boardGui = Instance.new("SurfaceGui")
		boardGui.Name = "BoardGui"
		boardGui.Face = Enum.NormalId.Front
		boardGui.Active = false
		boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		boardGui.PixelsPerStud = 36
		boardGui.LightInfluence = 0.2
		boardGui.Parent = display

		local container = Instance.new("Frame")
		container.Name = "Container"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundColor3 = spec.darkBg
		container.BorderSizePixel = 0
		container.Parent = boardGui

		local cGrad = Instance.new("UIGradient")
		cGrad.Rotation = 90
		cGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, spec.darkBg:Lerp(Color3.new(1, 1, 1), 0.08)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 24)),
		})
		cGrad.Parent = container

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "ScrollList"
		scroll.Size = UDim2.new(1, -14, 1, -46)
		scroll.Position = UDim2.fromOffset(7, 8)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 8
		scroll.ScrollBarImageColor3 = spec.frameColor
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.fromScale(0, 0)
		scroll.Parent = container

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 6)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = scroll

		local listPad = Instance.new("UIPadding")
		listPad.PaddingTop = UDim.new(0, 4)
		listPad.PaddingLeft = UDim.new(0, 3)
		listPad.Parent = scroll

		local footer = Instance.new("TextLabel")
		footer.Name = "FooterLabel"
		footer.Size = UDim2.new(1, -12, 0, 28)
		footer.Position = UDim2.new(0, 6, 1, -33)
		footer.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
		footer.Text = "Top 100 • Updates every 5:00"
		footer.TextColor3 = Color3.fromRGB(255, 224, 96)
		footer.Font = Enum.Font.FredokaOne
		footer.TextScaled = true
		footer.Parent = container
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 6)
		fc.Parent = footer
		local fst = Instance.new("UIStroke")
		fst.Thickness = 2
		fst.Color = Color3.fromRGB(10, 12, 16)
		fst.Parent = footer
	end

	-- Floating 3D Shop & Machine Signboards helper
	local function addFloatingBoothLabel(pos: Vector3, text: string, color: Color3)
		local anchor = makePart({
			name = "BoothSignAnchor_" .. text,
			size = Vector3.new(1, 1, 1),
			cframe = CFrame.new(pos),
			color = color,
			canCollide = false,
			canQuery = false,
			transparency = 1,
			parent = hub,
		})
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(156, 36)
		bb.MaxDistance = 85
		bb.Parent = anchor
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 2.5
		st.Color = Color3.fromRGB(12, 12, 16)
		st.Parent = lbl
	end

	-- Clean Glowing Green Auto-Open Stand Zone (NO bulky black floor pads!)
	local function makeGreenStandZone(opts: {
		name: string,
		pos: Vector3,
		radius: number,
		modalName: string,
		labelTitle: string,
		labelSub: string?,
		accentColor: Color3?,
	}): Part
		local r = opts.radius
		local col = opts.accentColor or Color3.fromRGB(68, 255, 118)

		local outerRing = makePart({
			name = opts.name,
			size = Vector3.new(0.16, r * 2, r * 2),
			cframe = CFrame.new(opts.pos.X, 0.42, opts.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color = col,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			transparency = 0.48,
			parent = hub,
		})
		outerRing.Shape = Enum.PartType.Cylinder
		outerRing.CastShadow = false
		outerRing:SetAttribute("ShopZoneModal", opts.modalName)
		outerRing:SetAttribute("ShopZoneRadius", r)

		local innerFill = makePart({
			name = opts.name .. "_Inner",
			size = Vector3.new(0.18, r * 1.66, r * 1.66),
			cframe = CFrame.new(opts.pos.X, 0.43, opts.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(28, 168, 68),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			transparency = 0.55,
			parent = hub,
		})
		innerFill.Shape = Enum.PartType.Cylinder
		innerFill.CastShadow = false

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(172, 46)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.MaxDistance = 75
		bb.AlwaysOnTop = true
		bb.Parent = outerRing
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = if opts.labelSub then (opts.labelTitle .. "\n" .. opts.labelSub) else opts.labelTitle
		lbl.TextColor3 = Color3.fromRGB(142, 255, 168)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 2.5
		st.Color = Color3.fromRGB(10, 14, 12)
		st.Parent = lbl

		return outerRing
	end

	-- 3. FRONT-LEFT PLAZA (Z ~ 120..132): Merge Pets Machine (using Hero_RebirthPortal 3D) + Lasso Shop!
	local fuseZone = Instance.new("Model")
	fuseZone.Name = "FuseAndMergePlaza"
	fuseZone.Parent = hub

	local fuseHero = cloneCuratedModel("Hero_RebirthPortal", CFrame.new(-56, 5.5, 128) * CFrame.Angles(0, math.rad(165), 0), 0.78, fuseZone, 0.45)
		or cloneCuratedModel("Hero_FuseMachine_HQ", CFrame.new(-56, 5.5, 128) * CFrame.Angles(0, math.rad(165), 0), 1.18, fuseZone, 0.45)
	local mergeAnchor = makePart({
		name = "MergePromptAnchor",
		size = Vector3.new(6, 5, 6),
		cframe = CFrame.new(-56, 3.0, 126.5),
		color = Color3.fromRGB(168, 92, 255),
		canCollide = false,
		canQuery = false,
		transparency = if fuseHero then 1 else 0.2,
		parent = fuseZone,
	})
	local mergePrompt = addPrompt(mergeAnchor, "Hold [E] to Merge Pets", "Merge Machine", "FusePrompt")
	mergePrompt.HoldDuration = 0.6
	mergePrompt.MaxActivationDistance = 16
	addFloatingBoothLabel(Vector3.new(-56, 13.8, 128), "Merge Pets", Color3.fromRGB(142, 212, 255))

	-- Lasso Shop right beside Merge Machine on the Front-Left!
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(-34, 6, 132) * CFrame.Angles(0, math.rad(180), 0), 0.95, hub, 0.45, true)
	addFloatingBoothLabel(Vector3.new(-34, 13.5, 132), "Lasso Shop", Color3.fromRGB(255, 198, 64))
	makeGreenStandZone({
		name = "LassoShopZone",
		pos = Vector3.new(-34, 0.42, 122),
		radius = 5.5,
		modalName = "Lassos",
		labelTitle = "LASSO SHOP",
		labelSub = "Stand Here",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- 4. FRONT-RIGHT PLAZA (Z ~ 120..132): Trail Shop + 3-Board Leaderboard Wall!
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(34, 6, 132) * CFrame.Angles(0, math.rad(180), 0), 0.95, hub, 0.45, true)
	addFloatingBoothLabel(Vector3.new(34, 13.5, 132), "Trails Shop", Color3.fromRGB(84, 245, 255))
	makeGreenStandZone({
		name = "TrailShopZone",
		pos = Vector3.new(34, 0.42, 122),
		radius = 5.5,
		modalName = "Trails",
		labelTitle = "TRAILS SHOP",
		labelSub = "Stand Here",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- 5. MID-HUB BOULEVARD STATIONS (Green Stand Zones, NO Black Floor Pads!)
	-- Vehicle Garage (Right side mid-hub)
	local garageZone = Instance.new("Model")
	garageZone.Name = "VehicleGaragePlaza"
	garageZone.Parent = hub
	cloneCuratedModel("Hero_VehicleGarage", CFrame.new(19, 6.0, 68) * CFrame.Angles(0, math.rad(-90), 0), 1.15, garageZone, 0.45, false)
	cloneCuratedModel("Hero_SafariATV", CFrame.new(15.5, 3.0, 60.5) * CFrame.Angles(0, math.rad(-145), 0), 1.0, garageZone, 0.45, false)
	addFloatingBoothLabel(Vector3.new(19, 15.2, 68), "Vehicle Garage", Color3.fromRGB(84, 245, 162))
	makeGreenStandZone({
		name = "VehicleShopZone",
		pos = Vector3.new(8.5, 0.42, 68),
		radius = 5.8,
		modalName = "Vehicles",
		labelTitle = "VEHICLE GARAGE",
		labelSub = "Stand Here",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- Rebirth is accessed directly from the HUD button (former 3D Portal asset is now the Merge Machine)
	-- Animal Index & Merchant Booth (Right side boulevard)
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(18, 6, 12) * CFrame.Angles(0, math.rad(-90), 0), 0.95, hub, 0.45, true)
	addFloatingBoothLabel(Vector3.new(18, 13.5, 12), "Index & Sell", Color3.fromRGB(255, 224, 72))
	makeGreenStandZone({
		name = "IndexMerchantZone",
		pos = Vector3.new(8.5, 0.42, 12),
		radius = 5.5,
		modalName = "Index",
		labelTitle = "INDEX & SELL",
		labelSub = "Stand Here",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

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
