--!strict
-- SanctuarySixPlotGenerator.luau
-- Generates the Sanctuary Base Hub (Safe Zone), 6 Pre-Allocated Open-Pen Roaming Plots (no stalls, 8->20 capacity),
-- Personal Upgradeable Treadmills, Cash Collector Pads, Trail Shop, Lasso Shop, Fuse Machine, Vehicle Garage, & Merchant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotVisualBuilder = require(ReplicatedStorage.Modules.PlotVisualBuilder)
local PlotPrefabSystem = require(ReplicatedStorage.Modules.PlotPrefabSystem)

local SanctuarySixPlotGenerator = {}

local makePart = PlotVisualBuilder.MakePart
local addSurfaceSign = PlotVisualBuilder.AddSurfaceSign
local makeEnhancedPad = PlotVisualBuilder.MakeEnhancedPad
local addPrompt = PlotVisualBuilder.AddPrompt

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
			if d.Material == Enum.Material.Neon then
				d.Material = Enum.Material.SmoothPlastic
			end
			if nonCollide or d:IsA("SpawnLocation") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
			if d:IsA("SpawnLocation") then
				d:Destroy()
			end
		elseif d:IsA("BaseScript") or d:IsA("ForceField") or d:IsA("Light") then
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

local function placeCuratedNatureProp(
	packPath: { string },
	targetCF: CFrame,
	scaleFactor: number,
	leafTint: Color3?,
	parent: Instance,
	groundY: number
): Model?
	local curr: Instance? = ReplicatedStorage:FindFirstChild("CuratedAssets")
	for _, seg in ipairs(packPath) do
		if not curr then
			return nil
		end
		curr = curr:FindFirstChild(seg)
	end
	if not curr or not curr:IsA("Model") then
		return nil
	end
	local clone = curr:Clone()
	if scaleFactor ~= 1 then
		pcall(function()
			clone:ScaleTo(clone:GetScale() * scaleFactor)
		end)
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Material == Enum.Material.Neon then
				d.Material = Enum.Material.SmoothPlastic
			end
			if leafTint then
				local lower = string.lower(d.Name)
				local isTrunk = string.find(lower, "trunk") or string.find(lower, "wood") or string.find(lower, "stick") or string.find(lower, "stem")
				local isCanopy = string.find(lower, "canopy") or string.find(lower, "leaf") or string.find(lower, "leaves") or string.find(lower, "foliage")
				if (isCanopy or (not isTrunk and d.Color.G > d.Color.R + 0.05)) and (not d:IsA("MeshPart") or d.TextureID == "") then
					d.Color = leafTint
				end
			end
		elseif d:IsA("BaseScript") or d:IsA("ForceField") or d:IsA("Light") then
			d:Destroy()
		end
	end
	clone:PivotTo(targetCF)
	clone.Parent = parent
	groundModel(clone, groundY)
	return clone
end

function SanctuarySixPlotGenerator.Build(worldFolder: Folder)
	if not worldFolder:FindFirstChild("BrushedDecor") then
		local brushed = Instance.new("Folder")
		brushed.Name = "BrushedDecor"
		brushed.Parent = worldFolder
	end

	local existing = worldFolder:FindFirstChild("SanctuaryHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "SanctuaryHub"
	hub.Parent = worldFolder

	-- 1. Main Sanctuary Floor (Classic Studs via Resurface)
	makePart({
		name = "HubFloor",
		size = Vector3.new(260, 4, 290),
		cframe = CFrame.new(0, -2, 5),
		color = Color3.fromRGB(94, 174, 82),
		material = Enum.Material.Plastic,
		materialVariant = "Studs",
		parent = hub,
	})

	-- Central Stone Boulevard
	makePart({
		name = "CentralBoulevard",
		size = Vector3.new(44, 0.6, 290),
		cframe = CFrame.new(0, 0.25, 5),
		color = Color3.fromRGB(162, 158, 148),
		material = Enum.Material.Plastic,
		materialVariant = "Studs",
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

	-- 3-Board Global Leaderboard Wall at Front-Right Plaza (Top Money/s | Top Speed | Top Playtime — Image 7 style)
	local lbWall = Instance.new("Model")
	lbWall.Name = "LeaderboardWall"
	lbWall.Parent = hub

	local wallCenterCF = CFrame.lookAt(Vector3.new(68, 0, 128), Vector3.new(10, 0, 75))
	local boardSpecs = {
		{
			name = "TopMoneyBoard",
			offsetX = 16.5,
			title = "💵 Top Money 💵",
			frameColor = Color3.fromRGB(36, 208, 86),
			headerColor = Color3.fromRGB(28, 186, 62),
			darkBg = Color3.fromRGB(222, 230, 242),
		},
		{
			name = "TopSpeedBoard",
			offsetX = 0,
			title = "👟 Top Speed 👟",
			frameColor = Color3.fromRGB(48, 158, 238),
			headerColor = Color3.fromRGB(24, 122, 228),
			darkBg = Color3.fromRGB(222, 230, 242),
		},
		{
			name = "TopPlaytimeBoard",
			offsetX = -16.5,
			title = "🕒 Top Playtime 🕒",
			frameColor = Color3.fromRGB(238, 66, 112),
			headerColor = Color3.fromRGB(218, 38, 84),
			darkBg = Color3.fromRGB(222, 230, 242),
		},
	}

	for _, spec in ipairs(boardSpecs) do
		local bm = Instance.new("Model")
		bm.Name = spec.name
		bm.Parent = lbWall

		local bCF = wallCenterCF * CFrame.new(spec.offsetX, 0, 0)

		-- Crisp Accent Base Pedestal (SmoothPlastic prevents HDR glare)
		makePart({
			name = "BasePedestal",
			size = Vector3.new(14.0, 0.5, 2.4),
			cframe = bCF * CFrame.new(0, 0.25, 0),
			color = spec.frameColor,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = bm,
		})

		-- Outer Colored Frame
		makePart({
			name = "OuterFrame",
			size = Vector3.new(13.2, 18.0, 1.2),
			cframe = bCF * CFrame.new(0, 9.4, 0),
			color = spec.frameColor,
			material = Enum.Material.SmoothPlastic,
			parent = bm,
		})

		-- Bright Inner Border Accent
		makePart({
			name = "InnerBorder",
			size = Vector3.new(12.2, 17.0, 1.3),
			cframe = bCF * CFrame.new(0, 9.4, -0.02),
			color = Color3.fromRGB(246, 250, 255),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = bm,
		})

		-- Light Clean Display Backing + Interactive SurfaceGui (Top 100 ScrollList)
		local display = makePart({
			name = "DisplaySurface",
			size = Vector3.new(11.4, 16.0, 1.4),
			cframe = bCF * CFrame.new(0, 9.3, -0.05),
			color = spec.darkBg,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = bm,
		})

		-- Colored Top Header Banner Ribbon
		local headerPart = makePart({
			name = "HeaderBanner",
			size = Vector3.new(14.6, 3.0, 1.7),
			cframe = bCF * CFrame.new(0, 19.2, -0.15),
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
		boardGui.LightInfluence = 0
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
			ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 250, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(204, 214, 228)),
		})
		cGrad.Parent = container

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "ScrollList"
		scroll.Size = UDim2.new(1, -16, 1, -50)
		scroll.Position = UDim2.fromOffset(8, 8)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 8
		scroll.ScrollBarImageColor3 = spec.headerColor
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.fromScale(0, 0)
		scroll.Parent = container

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 10)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = scroll

		local listPad = Instance.new("UIPadding")
		listPad.PaddingTop = UDim.new(0, 6)
		listPad.PaddingBottom = UDim.new(0, 6)
		listPad.PaddingLeft = UDim.new(0, 4)
		listPad.PaddingRight = UDim.new(0, 4)
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

	-- Clean Glowing Green Transparent Light & VFX Stand Zone (NO bulky black floor pads or "Stand Here" text clutter!)
	local function makeGreenStandZone(opts: {
		name: string,
		pos: Vector3,
		radius: number,
		modalName: string,
		accentColor: Color3?,
	}): Part
		local r = opts.radius
		local col = opts.accentColor or Color3.fromRGB(68, 255, 118)

		local outerRing = makePart({
			name = opts.name,
			size = Vector3.new(0.16, r * 2, r * 2),
			cframe = CFrame.new(opts.pos.X, 0.42, opts.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color = col,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			transparency = 0.34,
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
			color = Color3.fromRGB(44, 224, 104),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			transparency = 0.68,
			parent = hub,
		})
		innerFill.Shape = Enum.PartType.Cylinder
		innerFill.CastShadow = false

		-- Translucent Green Aura Column marking the stand zone cleanly in 3D space
		local lightAura = makePart({
			name = opts.name .. "_LightAura",
			size = Vector3.new(3.8, r * 1.80, r * 1.80),
			cframe = CFrame.new(opts.pos.X, 2.25, opts.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			color = col,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			transparency = 0.86,
			parent = hub,
		})
		lightAura.Shape = Enum.PartType.Cylinder
		lightAura.CastShadow = false

		local vfx = Instance.new("ParticleEmitter")
		vfx.Name = "StandZoneVFX"
		vfx.EmissionDirection = Enum.NormalId.Right -- Cylinder rotated 90 deg around Z -> +X faces world +Y up
		vfx.Rate = 12
		vfx.Lifetime = NumberRange.new(1.1, 1.8)
		vfx.Speed = NumberRange.new(1.8, 3.2)
		vfx.SpreadAngle = Vector2.new(16, 16)
		vfx.LightEmission = 0.20
		vfx.Color = ColorSequence.new(Color3.fromRGB(118, 255, 164), Color3.fromRGB(48, 232, 102))
		vfx.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.24),
			NumberSequenceKeypoint.new(0.5, 0.34),
			NumberSequenceKeypoint.new(1, 0),
		})
		vfx.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		vfx.Parent = outerRing

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
	makeGreenStandZone({
		name = "LassoShopZone",
		pos = Vector3.new(-34, 0.42, 122),
		radius = 5.5,
		modalName = "Lassos",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- 4. FRONT-RIGHT PLAZA (Z ~ 120..132): Trail Shop + 3-Board Leaderboard Wall!
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(34, 6, 132) * CFrame.Angles(0, math.rad(180), 0), 0.95, hub, 0.45, true)
	makeGreenStandZone({
		name = "TrailShopZone",
		pos = Vector3.new(34, 0.42, 122),
		radius = 5.5,
		modalName = "Trails",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- 5. MID-HUB BOULEVARD STATIONS (Green Light/VFX Stand Zones, NO Stand Here Text!)
	-- Vehicle Garage (Right side mid-hub)
	local garageZone = Instance.new("Model")
	garageZone.Name = "VehicleGaragePlaza"
	garageZone.Parent = hub
	cloneCuratedModel("Hero_VehicleGarage", CFrame.new(19, 6.0, 68) * CFrame.Angles(0, math.rad(-90), 0), 1.15, garageZone, 0.45, false)
	cloneCuratedModel("Hero_SafariATV", CFrame.new(15.5, 3.0, 60.5) * CFrame.Angles(0, math.rad(-145), 0), 1.0, garageZone, 0.45, false)
	makeGreenStandZone({
		name = "VehicleShopZone",
		pos = Vector3.new(8.5, 0.42, 68),
		radius = 5.8,
		modalName = "Vehicles",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- Rebirth is accessed directly from the HUD button (former 3D Portal asset is now the Merge Machine)
	-- Animal Index & Merchant Booth (Right side boulevard)
	cloneCuratedModel("Hero_ShopBooth", CFrame.new(18, 6, 12) * CFrame.Angles(0, math.rad(-90), 0), 0.95, hub, 0.45, true)
	makeGreenStandZone({
		name = "IndexMerchantZone",
		pos = Vector3.new(8.5, 0.42, 12),
		radius = 5.5,
		modalName = "Index",
		accentColor = Color3.fromRGB(84, 255, 132),
	})

	-- 6. Grand Sanctuary Safe-Zone Exit Barrier at Z = 148.5 (Open Horizon — NO Gapura!)
	local gateFolder = Instance.new("Model")
	gateFolder.Name = "SanctuaryExitGate"
	gateFolder.Parent = hub

	makePart({
		name = "SafeZoneLine",
		size = Vector3.new(260, 0.25, 2),
		cframe = CFrame.new(0, 0.2, 150),
		color = Color3.fromRGB(64, 218, 122),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		parent = gateFolder,
	})

	local barrier = makePart({
		name = "BiomeResetBarrier",
		size = Vector3.new(272, 28, 3.2),
		cframe = CFrame.new(0, 14, 148.5),
		color = Color3.fromRGB(246, 224, 238),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canQuery = false,
		transparency = 1,
		parent = gateFolder,
	})
	barrier.CastShadow = false

	-- Invisible Safe-Zone Edge Colliders (Open sky horizon matching Image 3, ZERO opaque perimeter walls!)
	local backWall = makePart({
		name = "HubWallBack",
		size = Vector3.new(272, 38, 6),
		cframe = CFrame.new(0, 19, -142),
		color = Color3.fromRGB(220, 215, 200),
		transparency = 1,
		canQuery = false,
		parent = hub,
	})
	backWall.CastShadow = false

	for _, xSide in { -131, 131 } do
		local sideWall = makePart({
			name = "HubWallSide_" .. tostring(xSide),
			size = Vector3.new(6, 38, 294),
			cframe = CFrame.new(xSide, 19, 5),
			color = Color3.fromRGB(220, 215, 200),
			transparency = 1,
			canQuery = false,
			parent = hub,
		})
		sideWall.CastShadow = false

		-- Crisp Low Rim Trim along cliff dropoff edge
		makePart({
			name = "HubEdgeTrim_" .. tostring(xSide),
			size = Vector3.new(3.2, 0.9, 294),
			cframe = CFrame.new(xSide - (if xSide > 0 then 1.5 else -1.5), 0.35, 5),
			color = Color3.fromRGB(226, 214, 184),
			material = Enum.Material.Cobblestone,
			studded = true,
			parent = hub,
		})
	end
	makePart({
		name = "HubEdgeTrim_Back",
		size = Vector3.new(264, 0.9, 3.2),
		cframe = CFrame.new(0, 0.35, -139),
		color = Color3.fromRGB(226, 214, 184),
		material = Enum.Material.Cobblestone,
		studded = true,
		parent = hub,
	})

	-- Floating Island Rock Underside & Cliff Dropoff Hull beneath SanctuaryHub
	local islandHullSpecs = {
		{ name = "IslandCrustRim", size = Vector3.new(258, 12, 286), y = -9.5, col = Color3.fromRGB(132, 98, 72), mat = Enum.Material.Slate },
		{ name = "IslandRockUpper", size = Vector3.new(224, 18, 248), y = -22.5, col = Color3.fromRGB(112, 96, 92), mat = Enum.Material.Slate },
		{ name = "IslandRockMid", size = Vector3.new(172, 22, 196), y = -41.0, col = Color3.fromRGB(88, 78, 84), mat = Enum.Material.Slate },
		{ name = "IslandRockKeel", size = Vector3.new(104, 24, 128), y = -61.5, col = Color3.fromRGB(68, 62, 74), mat = Enum.Material.Basalt },
	}
	for _, hs in ipairs(islandHullSpecs) do
		local hp = makePart({
			name = hs.name,
			size = hs.size,
			cframe = CFrame.new(0, hs.y, 5),
			color = hs.col,
			material = hs.mat,
			canCollide = false,
			canQuery = false,
			parent = hub,
		})
		hp.CastShadow = false
	end

	-- Hanging Edge Rock Columns around Floating Island Perimeter
	for _, cornerOff in { Vector3.new(-108, -28, -110), Vector3.new(108, -30, -110), Vector3.new(-112, -26, 25), Vector3.new(112, -28, 25), Vector3.new(-102, -32, 120), Vector3.new(102, -29, 120) } do
		local col = makePart({
			name = "FloatingIslandSpire",
			size = Vector3.new(26, 42, 26),
			cframe = CFrame.new(cornerOff) * CFrame.Angles(0, math.rad(22), 0),
			color = Color3.fromRGB(96, 84, 86),
			material = Enum.Material.Slate,
			canCollide = false,
			canQuery = false,
			parent = hub,
		})
		col.CastShadow = false
	end

	-- Distant Floating Sky Islands (No CloudSea flat slabs! Lush CuratedAssets Nature + Resurface Terrain!)
	local oldSky = worldFolder:FindFirstChild("SkyIslands")
	if oldSky then oldSky:Destroy() end
	local skyIslands = Instance.new("Folder")
	skyIslands.Name = "SkyIslands"
	skyIslands.Parent = worldFolder

	-- Perimeter Sakura & Nature clusters along outer SanctuaryHub cliff lawn (safely outside X=+-62 plots)
	local hubDecorFolder = Instance.new("Folder")
	hubDecorFolder.Name = "HubPerimeterNature"
	hubDecorFolder.Parent = hub
	for _, zPos in ipairs({ -118, -42, 36, 114 }) do
		for _, xSide in ipairs({ -116, 116 }) do
			local yaw = (if xSide > 0 then 0.5 else -0.5) + zPos * 0.02
			placeCuratedNatureProp(
				{ "Pack_Veedubmike1_Nature", "Trees", if (math.abs(zPos) % 8 == 2) then "Oak Tree" else "Maple Tree" },
				CFrame.new(xSide, 0, zPos) * CFrame.Angles(0, yaw, 0),
				1.05,
				Color3.fromRGB(255, 146, 198),
				hubDecorFolder,
				0
			)
			placeCuratedNatureProp(
				{ "Pack_Veedubmike1_Nature", "Bushes", if zPos > 0 then "Bush A" else "Bush B" },
				CFrame.new(xSide + (if xSide > 0 then -6.5 else 6.5), 0, zPos + 5) * CFrame.Angles(0, yaw + 1.1, 0),
				1.15,
				nil,
				hubDecorFolder,
				0
			)
			placeCuratedNatureProp(
				{ "Pack_Veedubmike1_Nature", "Rocks", "Rock A" },
				CFrame.new(xSide + (if xSide > 0 then -4.5 else 4.5), 0, zPos - 6) * CFrame.Angles(0, yaw + 2.0, 0),
				1.25,
				nil,
				hubDecorFolder,
				0
			)
		end
	end

	local skySpots = {
		{ pos = Vector3.new(-320, 46, -150), sc = 1.4, treeCol = Color3.fromRGB(255, 146, 198), hasWaterfall = true, isSnow = false },
		{ pos = Vector3.new(310, 54, -95), sc = 1.25, treeCol = Color3.fromRGB(255, 168, 214), hasWaterfall = true, isSnow = false },
		{ pos = Vector3.new(-340, 38, 320), sc = 1.5, treeCol = Color3.fromRGB(92, 186, 98), hasWaterfall = true, isSnow = false },
		{ pos = Vector3.new(350, 52, 690), sc = 1.6, treeCol = Color3.fromRGB(255, 152, 206), hasWaterfall = true, isSnow = false },
		{ pos = Vector3.new(-355, 48, 1220), sc = 1.45, treeCol = Color3.fromRGB(168, 224, 250), hasWaterfall = true, isSnow = true },
		{ pos = Vector3.new(330, 56, 1920), sc = 1.55, treeCol = Color3.fromRGB(238, 124, 62), hasWaterfall = false, isSnow = false },
	}
	for idx, sp in ipairs(skySpots) do
		local sc = sp.sc
		local isl = Instance.new("Model")
		isl.Name = "SkyIsland_" .. idx
		isl.Parent = skyIslands

		local deckHeight = 6 * sc
		local deckTopY = sp.pos.Y + deckHeight * 0.5
		local topGrass = makePart({
			name = "IslandDeck",
			size = Vector3.new(88 * sc, deckHeight, 78 * sc),
			cframe = CFrame.new(sp.pos),
			color = if sp.isSnow then Color3.fromRGB(218, 236, 248) else Color3.fromRGB(108, 178, 86),
			material = if sp.isSnow then Enum.Material.Snow else Enum.Material.Grass,
			materialVariant = if sp.isSnow then "BlockyStudSnow" else "BlockyStudGrass",
			studded = false,
			canCollide = false,
			canQuery = false,
			parent = isl,
		})
		topGrass.CastShadow = false
		isl.PrimaryPart = topGrass

		local hull1 = makePart({
			name = "IslandHullUpper",
			size = Vector3.new(72 * sc, 24 * sc, 64 * sc),
			cframe = CFrame.new(sp.pos - Vector3.new(0, 15 * sc, 0)),
			color = Color3.fromRGB(134, 104, 84),
			material = Enum.Material.Slate,
			materialVariant = "CartoonCliffWall",
			canCollide = false,
			canQuery = false,
			parent = isl,
		})
		hull1.CastShadow = false
		local hull2 = makePart({
			name = "IslandHullTip",
			size = Vector3.new(42 * sc, 28 * sc, 38 * sc),
			cframe = CFrame.new(sp.pos - Vector3.new(0, 38 * sc, 0)),
			color = Color3.fromRGB(92, 76, 74),
			material = Enum.Material.Slate,
			materialVariant = "CartoonCliffWall",
			canCollide = false,
			canQuery = false,
			parent = isl,
		})
		hull2.CastShadow = false

		-- Asymmetric tapered side rock ledges for an organic floating-island silhouette
		for sideIdx, sideOff in ipairs({ Vector3.new(-28 * sc, -12 * sc, 16 * sc), Vector3.new(26 * sc, -16 * sc, -14 * sc) }) do
			local ledge = makePart({
				name = "IslandSideLedge_" .. sideIdx,
				size = Vector3.new(30 * sc, 18 * sc, 28 * sc),
				cframe = CFrame.new(sp.pos + sideOff) * CFrame.Angles(0, math.rad(sideIdx * 24), 0),
				color = Color3.fromRGB(114, 92, 82),
				material = Enum.Material.Slate,
				materialVariant = "CartoonCliffWall",
				canCollide = false,
				canQuery = false,
				parent = isl,
			})
			ledge.CastShadow = false
		end

		-- Rich Multi-Part Nature Trees, Boulders & Bushes from CuratedAssets
		local primaryTreePath = if sp.isSnow
			then { "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "SpruceSnowy1" }
			elseif idx % 2 == 1 then { "Pack_Veedubmike1_Nature", "Trees", "Oak Tree" }
			else { "Pack_Veedubmike1_Nature", "Trees", "Maple Tree" }
		local secondaryTreePath = if sp.isSnow
			then { "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "SpruceSnowy3" }
			else { "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Tree1" }

		placeCuratedNatureProp(
			primaryTreePath,
			CFrame.new(sp.pos.X - 10 * sc, deckTopY, sp.pos.Z - 4 * sc) * CFrame.Angles(0, idx * 0.9, 0),
			1.95 * sc,
			if sp.isSnow then nil else sp.treeCol,
			isl,
			deckTopY - 0.3
		)
		placeCuratedNatureProp(
			secondaryTreePath,
			CFrame.new(sp.pos.X + 18 * sc, deckTopY, sp.pos.Z + 14 * sc) * CFrame.Angles(0, idx * 1.4, 0),
			1.85 * sc,
			nil,
			isl,
			deckTopY - 0.3
		)
		placeCuratedNatureProp(
			{ "Pack_Veedubmike1_Nature", "Rocks", "Rock A" },
			CFrame.new(sp.pos.X + 14 * sc, deckTopY, sp.pos.Z - 14 * sc) * CFrame.Angles(0, idx * 0.7, 0),
			2.4 * sc,
			nil,
			isl,
			deckTopY - 0.4
		)
		placeCuratedNatureProp(
			{ "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Rock2" },
			CFrame.new(sp.pos.X - 22 * sc, deckTopY, sp.pos.Z + 16 * sc) * CFrame.Angles(0, idx * 1.2, 0),
			2.1 * sc,
			nil,
			isl,
			deckTopY - 0.4
		)
		placeCuratedNatureProp(
			{ "Pack_Veedubmike1_Nature", "Bushes", "Bush A" },
			CFrame.new(sp.pos.X + 4 * sc, deckTopY, sp.pos.Z + 18 * sc) * CFrame.Angles(0, idx * 0.5, 0),
			2.2 * sc,
			nil,
			isl,
			deckTopY - 0.2
		)

		if sp.hasWaterfall then
			local fall = makePart({
				name = "SkyWaterfall",
				size = Vector3.new(16 * sc, 118, 4 * sc),
				cframe = CFrame.new(sp.pos + Vector3.new((if sp.pos.X > 0 then -38 else 38) * sc, -54, 0)),
				color = Color3.fromRGB(118, 204, 245),
				material = Enum.Material.Glass,
				transparency = 0.35,
				canCollide = false,
				canQuery = false,
				parent = isl,
			})
			fall.CastShadow = false
		end
	end

	-- 7. Build All 6 Pre-Allocated Open-Pen Plots from Single Editable OpenPlotPrefab
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = hub

	local openPlotPrefab = PlotPrefabSystem.BuildDefaultOpenPlotPrefab(true)
	for i = 1, 6 do
		PlotPrefabSystem.InstantiatePlotFromPrefab(openPlotPrefab, i, PlotPrefabSystem.GetPlotSlotCFrame(i), plotsFolder)
	end

	return hub
end

return SanctuarySixPlotGenerator
