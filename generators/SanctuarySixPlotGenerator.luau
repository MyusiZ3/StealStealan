--!strict
-- SanctuarySixPlotGenerator.luau
-- Generates the Sanctuary Base Hub (Safe Zone), 6 Pre-Allocated Zoo Plots (for MaxPlayers=6),
-- Central Fuse & Merge Plaza, Shop Booths, and Dyno Training Zones using Blocky Studded aesthetics + Curated Assets.

local Workspace = game:GetService("Workspace")
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
	transparency: number?,
	shape: Enum.PartType?,
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
	if props.studded then
		p.TopSurface = Enum.SurfaceType.Studs
	else
		p.TopSurface = Enum.SurfaceType.Smooth
	end
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	p.Transparency = props.transparency or 0
	if props.shape then
		p.Shape = props.shape
	end
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
	prompt.MaxActivationDistance = 12
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

local function cloneCuratedModel(name: string, targetCFrame: CFrame, scaleFactor: number, parent: Instance, groundY: number?): Model?
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

local function buildSinglePlot(plotIndex: number, centerPos: Vector3, facingDirX: number, parentFolder: Folder)
	local plotModel = Instance.new("Model")
	plotModel.Name = "Plot_" .. tostring(plotIndex)
	plotModel:SetAttribute("PlotIndex", plotIndex)
	plotModel:SetAttribute("OwnerUserId", 0)
	plotModel.Parent = parentFolder

	-- Plot facing: Left plots face +X (rotation -90 deg around Y), Right plots face -X (+90 deg)
	local yaw = if facingDirX > 0 then -math.pi / 2 else math.pi / 2
	local plotCF = CFrame.new(centerPos) * CFrame.Angles(0, yaw, 0)

	-- 1. Main Plot Foundation (66 wide along Z-axis of hub, 64 deep along X)
	local base = makePart({
		name = "PlotBase",
		size = Vector3.new(64, 2, 62),
		cframe = plotCF * CFrame.new(0, 0, 0),
		color = Color3.fromRGB(108, 184, 88),
		material = Enum.Material.Grass,
		materialVariant = "BlockyStudGrass",
		studded = true,
		parent = plotModel,
	})
	plotModel.PrimaryPart = base

	-- Border curb
	makePart({
		name = "FrontCurb",
		size = Vector3.new(64, 0.8, 3),
		cframe = plotCF * CFrame.new(0, 1.1, -29.5),
		color = Color3.fromRGB(224, 206, 168),
		material = Enum.Material.Cobblestone,
		studded = true,
		parent = plotModel,
	})

	-- 2. Owner Signboard at Plot Entrance
	local signPost = makePart({
		name = "OwnerSignPost",
		size = Vector3.new(1.5, 9, 1.5),
		cframe = plotCF * CFrame.new(-24, 5.5, -28),
		color = Color3.fromRGB(98, 68, 44),
		material = Enum.Material.Wood,
		parent = plotModel,
	})
	local signBoard = makePart({
		name = "OwnerSignBoard",
		size = Vector3.new(16, 6, 1),
		cframe = plotCF * CFrame.new(-24, 10, -28),
		color = Color3.fromRGB(34, 42, 56),
		material = Enum.Material.SmoothPlastic,
		parent = plotModel,
	})
	signPost.CanQuery = false
	addSurfaceSign(signBoard, Enum.NormalId.Front, "SANCTUARY PLOT #" .. plotIndex, "Claimed automatically on join", Color3.fromRGB(30, 42, 58))
	addSurfaceSign(signBoard, Enum.NormalId.Back, "SANCTUARY PLOT #" .. plotIndex, "Claimed automatically on join", Color3.fromRGB(30, 42, 58))

	-- 3. Personal Dyno / Speed Training Track (Front strip of the plot)
	local dynoTrack = makePart({
		name = "DynoTrainingPad",
		size = Vector3.new(38, 0.6, 10),
		cframe = plotCF * CFrame.new(4, 1.3, -22),
		color = Color3.fromRGB(58, 168, 255),
		material = Enum.Material.SmoothPlastic,
		studded = true,
		parent = plotModel,
	})
	dynoTrack:SetAttribute("IsDynoZone", true)
	dynoTrack:SetAttribute("PlotIndex", plotIndex)
	addSurfaceSign(dynoTrack, Enum.NormalId.Top, "SPEED TRAINING TRACK", "Ride Vehicle or Pet here for +SPEED!", Color3.fromRGB(24, 96, 178))

	-- Curated Wooden Fence Gate at entrance
	local gateClone = cloneCuratedModel("WoodenFenceGate", plotCF * CFrame.new(-14, 3.6, -29.5), 1.3, plotModel, 1.2)
	if not gateClone then
		makePart({
			name = "FallbackGateArch",
			size = Vector3.new(10, 1.5, 1.5),
			cframe = plotCF * CFrame.new(-14, 8, -29.5),
			color = Color3.fromRGB(145, 96, 52),
			material = Enum.Material.Wood,
			parent = plotModel,
		})
	end

	-- 4. Zoo Enclosure Stalls (20 Stalls in 4 rows x 5 columns)
	-- Stalls 1..14 = Free unlockable, Stalls 15..20 = Extra Zoo Capacity Pass
	local stallsFolder = Instance.new("Folder")
	stallsFolder.Name = "Stalls"
	stallsFolder.Parent = plotModel

	local cols = 5
	local spacingX = 11.5
	local spacingZ = 10.5
	local startX = -23
	local startZ = -8

	for i = 1, 20 do
		local row = math.floor((i - 1) / cols)
		local col = (i - 1) % cols
		local localPos = Vector3.new(startX + col * spacingX, 1.2, startZ + row * spacingZ)

		local stallModel = Instance.new("Model")
		stallModel.Name = "Stall_" .. tostring(i)
		stallModel:SetAttribute("StallIndex", i)
		stallModel:SetAttribute("PlotIndex", plotIndex)
		stallModel:SetAttribute("UnlockedByDefault", i <= 4)
		stallModel:SetAttribute("RequiresPass", i > 14)
		stallModel.Parent = stallsFolder

		local isStarter = i <= 4
		local isPassOnly = i > 14

		local padColor = if isStarter
			then Color3.fromRGB(94, 212, 128)
			elseif isPassOnly then Color3.fromRGB(238, 186, 62)
			else Color3.fromRGB(132, 146, 162)

		local pad = makePart({
			name = "StallPad",
			size = Vector3.new(9.5, 0.5, 8.5),
			cframe = plotCF * CFrame.new(localPos),
			color = padColor,
			material = Enum.Material.SmoothPlastic,
			studded = true,
			parent = stallModel,
		})
		stallModel.PrimaryPart = pad

		-- Enclosure low fence rails (left, right, back)
		local railColor = Color3.fromRGB(136, 92, 52)
		makePart({
			name = "FenceBack",
			size = Vector3.new(9.5, 1.6, 0.6),
			cframe = plotCF * CFrame.new(localPos + Vector3.new(0, 1.0, 4.0)),
			color = railColor,
			material = Enum.Material.Wood,
			canCollide = false,
			parent = stallModel,
		})
		makePart({
			name = "FenceLeft",
			size = Vector3.new(0.6, 1.6, 8.2),
			cframe = plotCF * CFrame.new(localPos + Vector3.new(-4.45, 1.0, 0)),
			color = railColor,
			material = Enum.Material.Wood,
			canCollide = false,
			parent = stallModel,
		})
		makePart({
			name = "FenceRight",
			size = Vector3.new(0.6, 1.6, 8.2),
			cframe = plotCF * CFrame.new(localPos + Vector3.new(4.45, 1.0, 0)),
			color = railColor,
			material = Enum.Material.Wood,
			canCollide = false,
			parent = stallModel,
		})

		-- Collect / Action Pad in front of stall
		local collectPad = makePart({
			name = "ActionPad",
			size = Vector3.new(4.2, 0.35, 2.2),
			cframe = plotCF * CFrame.new(localPos + Vector3.new(0, 0.3, -3.2)),
			color = if isStarter then Color3.fromRGB(255, 214, 62) else Color3.fromRGB(92, 102, 118),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = stallModel,
		})
		collectPad:SetAttribute("StallIndex", i)
		collectPad:SetAttribute("PlotIndex", plotIndex)

		-- Anchor where rescued animal / crate spawns
		local anchor = makePart({
			name = "AnimalAnchor",
			size = Vector3.new(1, 0.2, 1),
			cframe = plotCF * CFrame.new(localPos + Vector3.new(0, 0.35, 0.8)),
			color = Color3.fromRGB(255, 255, 255),
			transparency = 1,
			canCollide = false,
			parent = stallModel,
		})
		anchor.CanQuery = false
		anchor.CanTouch = false

		local labelText = if isStarter
			then "STALL #" .. i .. " (EMPTY)"
			elseif isPassOnly then "VIP STALL #" .. i
			else "LOCKED #" .. i
		addSurfaceSign(pad, Enum.NormalId.Top, labelText, if isStarter then "Bring a crate here!" else nil, Color3.fromRGB(28, 36, 48))

		addPrompt(collectPad, "Interact", "Zoo Stall #" .. i, "StallPrompt")
	end
end

function SanctuarySixPlotGenerator.Build(worldFolder: Folder)
	local existing = worldFolder:FindFirstChild("SanctuaryHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "SanctuaryHub"
	hub.Parent = worldFolder

	-- 1. Main Sanctuary Ground Platform (Blocky Studded Lawn)
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

	-- Central Stone Boulevard leading to Biome 1
	makePart({
		name = "CentralBoulevard",
		size = Vector3.new(44, 0.6, 290),
		cframe = CFrame.new(0, 0.25, 5),
		color = Color3.fromRGB(162, 158, 148),
		material = Enum.Material.Cobblestone,
		studded = true,
		parent = hub,
	})

	-- Curb stripes along boulevard
	for _, side in { -22.5, 22.5 } do
		makePart({
			name = "BoulevardCurb_" .. tostring(side),
			size = Vector3.new(2, 1.0, 290),
			cframe = CFrame.new(side, 0.5, 5),
			color = Color3.fromRGB(238, 224, 178),
			material = Enum.Material.SmoothPlastic,
			studded = true,
			parent = hub,
		})
	end

	-- 2. Spawn Plaza & SpawnLocation
	makePart({
		name = "SpawnPlaza",
		size = Vector3.new(36, 0.8, 36),
		cframe = CFrame.new(0, 0.4, -105),
		color = Color3.fromRGB(76, 156, 224),
		material = Enum.Material.SmoothPlastic,
		studded = true,
		parent = hub,
	})
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "RangerSpawn"
	spawnLoc.Size = Vector3.new(12, 1, 12)
	spawnLoc.CFrame = CFrame.new(0, 0.85, -105)
	spawnLoc.Anchored = true
	spawnLoc.Neutral = true
	spawnLoc.Color = Color3.fromRGB(255, 206, 56)
	spawnLoc.Material = Enum.Material.SmoothPlastic
	spawnLoc.TopSurface = Enum.SurfaceType.Studs
	spawnLoc.Duration = 0
	spawnLoc.Parent = hub

	-- 3. Central Fuse & Merge Plaza (using AI-Generated Hero_FuseMachine)
	local fuseZone = Instance.new("Model")
	fuseZone.Name = "FuseAndMergePlaza"
	fuseZone.Parent = hub

	local fusePad = makePart({
		name = "FusePad",
		size = Vector3.new(22, 0.9, 22),
		cframe = CFrame.new(0, 0.5, -35),
		color = Color3.fromRGB(168, 86, 255),
		material = Enum.Material.SmoothPlastic,
		studded = true,
		parent = fuseZone,
	})
	addSurfaceSign(fusePad, Enum.NormalId.Top, "FUSE & MERGE MACHINE", "3x Normal -> Golden -> Rainbow!", Color3.fromRGB(84, 34, 158))
	local fuseHero = cloneCuratedModel("Hero_FuseMachine", CFrame.new(0, 5.2, -35), 1.0, fuseZone, 0.95)
	local promptTarget: BasePart = fusePad
	if fuseHero then
		for _, p in ipairs(fuseHero:GetDescendants()) do
			if p:IsA("BasePart") then
				promptTarget = p
				break
			end
		end
	end
	addPrompt(promptTarget, "Open Fuse & Merge", "Animal Evolution Machine", "FusePrompt")

	-- 4. Lasso Shop Booth (Left of Boulevard) & Vehicle Garage (Right of Boulevard)
	local lassoShopPad = makePart({
		name = "LassoShopPad",
		size = Vector3.new(16, 0.9, 14),
		cframe = CFrame.new(-15, 0.5, 45),
		color = Color3.fromRGB(244, 162, 52),
		material = Enum.Material.SmoothPlastic,
		studded = true,
		parent = hub,
	})
	addSurfaceSign(lassoShopPad, Enum.NormalId.Top, "LASSO GEAR SHOP", "Upgrade Pull Power!", Color3.fromRGB(148, 82, 18))
	addPrompt(lassoShopPad, "Open Lasso Shop", "Ranger Gear Shop", "LassoShopPrompt")

	local vehicleShopPad = makePart({
		name = "VehicleGaragePad",
		size = Vector3.new(16, 0.9, 14),
		cframe = CFrame.new(15, 0.5, 45),
		color = Color3.fromRGB(64, 188, 128),
		material = Enum.Material.SmoothPlastic,
		studded = true,
		parent = hub,
	})
	addSurfaceSign(vehicleShopPad, Enum.NormalId.Top, "VEHICLE GARAGE", "Spawn & Upgrade Ride!", Color3.fromRGB(28, 108, 68))
	cloneCuratedModel("Hero_SafariATV", CFrame.new(15, 3.6, 45) * CFrame.Angles(0, math.rad(-145), 0), 1.15, hub, 0.95)
	addPrompt(vehicleShopPad, "Open Vehicle Garage", "Expedition Vehicles", "VehicleShopPrompt")

	-- Rebirth & Daily Altar
	local rebirthPad = makePart({
		name = "RebirthAltarPad",
		size = Vector3.new(16, 0.9, 16),
		cframe = CFrame.new(0, 0.5, 95),
		color = Color3.fromRGB(255, 86, 132),
		material = Enum.Material.SmoothPlastic,
		studded = true,
		parent = hub,
	})
	addSurfaceSign(rebirthPad, Enum.NormalId.Top, "REBIRTH & DAILY", "Reset for Permanent Multiplier!", Color3.fromRGB(142, 26, 68))
	addPrompt(rebirthPad, "Open Rebirth / Daily", "Ranger Prestige", "RebirthPrompt")

	-- 5. Grand Sanctuary Safe-Zone Gate at Z = 148
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
		material = Enum.Material.SmoothPlastic,
		parent = gateFolder,
	})
	addSurfaceSign(gateBanner, Enum.NormalId.Front, "LEAVING SAFE ZONE ->", "Watch out for Poachers!", Color3.fromRGB(178, 54, 48))
	addSurfaceSign(gateBanner, Enum.NormalId.Back, "<- SANCTUARY SAFE ZONE", "Bring rescued crates home!", Color3.fromRGB(42, 146, 86))

	-- Safe Zone Visual Laser Line
	makePart({
		name = "SafeZoneLine",
		size = Vector3.new(260, 0.25, 2),
		cframe = CFrame.new(0, 0.2, 150),
		color = Color3.fromRGB(68, 255, 138),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = gateFolder,
	})

	-- Hub Perimeter Walls (Keep hub enclosed except the exit trail)
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

	-- 6. Build All 6 Pre-Allocated Zoo Plots (3 Left, 3 Right)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = hub

	local zPositions = { -82, -4, 74 }
	for i = 1, 3 do
		buildSinglePlot(i, Vector3.new(-62, 0.2, zPositions[i]), 1, plotsFolder)
	end
	for i = 1, 3 do
		buildSinglePlot(i + 3, Vector3.new(62, 0.2, zPositions[i]), -1, plotsFolder)
	end

	return hub
end

return SanctuarySixPlotGenerator
