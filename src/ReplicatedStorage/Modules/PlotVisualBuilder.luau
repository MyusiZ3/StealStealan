--!strict
-- PlotVisualBuilder.luau
-- Builds & updates evolving Open-Pen Fencing (5 visual tiers), evolving Treadmills (5 visual tiers),
-- clean belt stand anchors facing the console screen, and 3D Wooden-Post Upgrade Signboards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotVisualBuilder = {}

local BELT_LOCAL_REL_Y = 1.24

function PlotVisualBuilder.MakePart(props: {
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
	if props.shape then
		p.Shape = props.shape
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

local makePart = PlotVisualBuilder.MakePart

function PlotVisualBuilder.AddSurfaceSign(part: BasePart, face: Enum.NormalId, titleText: string, subText: string?, bgColor: Color3?, accentColor: Color3?)
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

function PlotVisualBuilder.MakeEnhancedPad(opts: {
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

	-- 4. Interactive Top Deck
	local deck = makePart({
		name = opts.name,
		size = opts.size,
		cframe = opts.cframe,
		color = opts.bgColor,
		material = Enum.Material.SmoothPlastic,
		canCollide = col,
		parent = opts.parent,
	})
	PlotVisualBuilder.AddSurfaceSign(deck, Enum.NormalId.Top, opts.titleText, opts.subText, opts.bgColor, opts.accentColor)

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

function PlotVisualBuilder.AddPrompt(parent: Instance, actionText: string, objectText: string, tag: string): ProximityPrompt
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

function PlotVisualBuilder.GetPenTier(penLevel: number): number
	if penLevel >= 16 then
		return 5
	elseif penLevel >= 11 then
		return 4
	elseif penLevel >= 7 then
		return 3
	elseif penLevel >= 4 then
		return 2
	end
	return 1
end

function PlotVisualBuilder.GetTreadmillTier(treadLevel: number): number
	if treadLevel >= 17 then
		return 5
	elseif treadLevel >= 11 then
		return 4
	elseif treadLevel >= 7 then
		return 3
	elseif treadLevel >= 4 then
		return 2
	end
	return 1
end

function PlotVisualBuilder.GetPlotSurfaceY(plotCF: CFrame): number
	return plotCF.Position.Y + 1.0 -- PlotBase size.Y=2 centered at plotCF.Y => top is +1.0
end

local function buildFenceSegment(
	parent: Instance,
	startPos: Vector3,
	endPos: Vector3,
	plotCF: CFrame,
	surfaceY: number,
	tier: number
)
	local a = (plotCF * CFrame.new(startPos.X, 0, startPos.Z)).Position
	local b = (plotCF * CFrame.new(endPos.X, 0, endPos.Z)).Position
	local flatA = Vector3.new(a.X, surfaceY, a.Z)
	local flatB = Vector3.new(b.X, surfaceY, b.Z)
	local segVec = flatB - flatA
	local length = segVec.Magnitude
	if length < 0.5 then
		return
	end
	local mid = (flatA + flatB) * 0.5
	local segCF = CFrame.lookAt(mid, flatB)

	if tier == 1 then
		-- Rustic Wood Ranch Fence
		local railCol = Color3.fromRGB(142, 96, 54)
		makePart({
			name = "FenceRail",
			size = Vector3.new(1.3, 3.0, length),
			cframe = segCF * CFrame.new(0, 1.5, 0),
			color = railCol,
			material = Enum.Material.Wood,
			parent = parent,
		})
	elseif tier == 2 then
		-- Clean White Picket Fence with Oak Trim (Image 9 style!)
		local railCol = Color3.fromRGB(242, 245, 250)
		local postCol = Color3.fromRGB(132, 86, 48)
		makePart({
			name = "LowerRail",
			size = Vector3.new(0.8, 0.55, length),
			cframe = segCF * CFrame.new(0, 1.0, 0),
			color = railCol,
			parent = parent,
		})
		makePart({
			name = "UpperRail",
			size = Vector3.new(0.85, 0.55, length),
			cframe = segCF * CFrame.new(0, 2.7, 0),
			color = railCol,
			parent = parent,
		})
		makePart({
			name = "InvisibleCollider",
			size = Vector3.new(1.2, 3.4, length),
			cframe = segCF * CFrame.new(0, 1.7, 0),
			color = railCol,
			transparency = 1,
			canQuery = false,
			parent = parent,
		})
		local step = 2.6
		local count = math.max(1, math.floor(length / step))
		for i = 0, count do
			local zOff = -length * 0.5 + (i / count) * length
			local isPost = (i == 0 or i == count or i % 4 == 0)
			makePart({
				name = if isPost then "OakPost" else "WhitePicket",
				size = if isPost then Vector3.new(1.2, 3.7, 1.2) else Vector3.new(0.55, 3.3, 0.65),
				cframe = segCF * CFrame.new(0, if isPost then 1.85 else 1.65, zOff),
				color = if isPost then postCol else railCol,
				material = if isPost then Enum.Material.Wood else Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				parent = parent,
			})
		end
	elseif tier == 3 then
		-- Stone & Wrought-Iron Bastion with Warm Lanterns
		local stoneCol = Color3.fromRGB(118, 122, 134)
		local ironCol = Color3.fromRGB(38, 42, 50)
		makePart({
			name = "StoneCurb",
			size = Vector3.new(1.5, 1.0, length),
			cframe = segCF * CFrame.new(0, 0.5, 0),
			color = stoneCol,
			material = Enum.Material.Cobblestone,
			studded = true,
			parent = parent,
		})
		makePart({
			name = "IronTopBar",
			size = Vector3.new(0.7, 0.45, length),
			cframe = segCF * CFrame.new(0, 3.8, 0),
			color = ironCol,
			material = Enum.Material.Metal,
			parent = parent,
		})
		makePart({
			name = "InvisibleCollider",
			size = Vector3.new(1.4, 4.0, length),
			cframe = segCF * CFrame.new(0, 2.0, 0),
			color = ironCol,
			transparency = 1,
			canQuery = false,
			parent = parent,
		})
		local count = math.max(2, math.floor(length / 2.8))
		for i = 0, count do
			local zOff = -length * 0.5 + (i / count) * length
			local isPier = (i == 0 or i == count or i % 5 == 0)
			if isPier then
				makePart({
					name = "StonePier",
					size = Vector3.new(1.8, 4.4, 1.8),
					cframe = segCF * CFrame.new(0, 2.2, zOff),
					color = stoneCol,
					material = Enum.Material.Cobblestone,
					canQuery = false,
					parent = parent,
				})
				makePart({
					name = "LanternCap",
					size = Vector3.new(0.95, 0.75, 0.95),
					cframe = segCF * CFrame.new(0, 4.7, zOff),
					color = Color3.fromRGB(255, 204, 88),
					material = Enum.Material.Neon,
					canCollide = false,
					canQuery = false,
					parent = parent,
				})
			else
				makePart({
					name = "IronSpindle",
					size = Vector3.new(0.32, 2.8, 0.32),
					cframe = segCF * CFrame.new(0, 2.35, zOff),
					color = ironCol,
					material = Enum.Material.Metal,
					canCollide = false,
					canQuery = false,
					parent = parent,
				})
			end
		end
	elseif tier == 4 then
		-- Royal Marble & Gold Conservatory with Emerald Orbs
		local marbleCol = Color3.fromRGB(238, 240, 245)
		local goldCol = Color3.fromRGB(246, 196, 56)
		makePart({
			name = "MarbleWall",
			size = Vector3.new(1.6, 1.4, length),
			cframe = segCF * CFrame.new(0, 0.7, 0),
			color = marbleCol,
			material = Enum.Material.Marble,
			parent = parent,
		})
		makePart({
			name = "GoldRail",
			size = Vector3.new(0.65, 0.45, length),
			cframe = segCF * CFrame.new(0, 3.85, 0),
			color = goldCol,
			material = Enum.Material.Metal,
			parent = parent,
		})
		makePart({
			name = "InvisibleCollider",
			size = Vector3.new(1.5, 4.2, length),
			cframe = segCF * CFrame.new(0, 2.1, 0),
			color = marbleCol,
			transparency = 1,
			canQuery = false,
			parent = parent,
		})
		local count = math.max(2, math.floor(length / 3.2))
		for i = 0, count do
			local zOff = -length * 0.5 + (i / count) * length
			local isPillar = (i == 0 or i == count or i % 4 == 0)
			if isPillar then
				makePart({
					name = "MarblePillar",
					size = Vector3.new(1.9, 4.8, 1.9),
					cframe = segCF * CFrame.new(0, 2.4, zOff),
					color = marbleCol,
					material = Enum.Material.Marble,
					canQuery = false,
					parent = parent,
				})
				makePart({
					name = "EmeraldFinial",
					size = Vector3.new(1.1, 1.1, 1.1),
					cframe = segCF * CFrame.new(0, 5.2, zOff),
					color = Color3.fromRGB(64, 248, 148),
					material = Enum.Material.Neon,
					shape = Enum.PartType.Ball,
					canCollide = false,
					canQuery = false,
					parent = parent,
				})
			else
				makePart({
					name = "GoldBar",
					size = Vector3.new(0.32, 2.6, 0.32),
					cframe = segCF * CFrame.new(0, 2.6, zOff),
					color = goldCol,
					material = Enum.Material.Metal,
					canCollide = false,
					canQuery = false,
					parent = parent,
				})
			end
		end
	else
		-- Tier 5: Celestial Obsidian & Neon Sanctum
		local obsCol = Color3.fromRGB(32, 28, 42)
		local goldCol = Color3.fromRGB(255, 210, 72)
		local neonCol = Color3.fromRGB(72, 238, 255)
		makePart({
			name = "ObsidianBase",
			size = Vector3.new(1.7, 1.6, length),
			cframe = segCF * CFrame.new(0, 0.8, 0),
			color = obsCol,
			material = Enum.Material.Basalt,
			studded = true,
			parent = parent,
		})
		makePart({
			name = "NeonLaserMid",
			size = Vector3.new(0.3, 0.3, length),
			cframe = segCF * CFrame.new(0, 2.7, 0),
			color = neonCol,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			parent = parent,
		})
		makePart({
			name = "GoldCrestRail",
			size = Vector3.new(0.75, 0.5, length),
			cframe = segCF * CFrame.new(0, 4.1, 0),
			color = goldCol,
			material = Enum.Material.Metal,
			parent = parent,
		})
		makePart({
			name = "InvisibleCollider",
			size = Vector3.new(1.6, 4.4, length),
			cframe = segCF * CFrame.new(0, 2.2, 0),
			color = obsCol,
			transparency = 1,
			canQuery = false,
			parent = parent,
		})
		local count = math.max(2, math.floor(length / 5))
		for i = 0, count do
			local zOff = -length * 0.5 + (i / count) * length
			makePart({
				name = "ObsidianBeacon",
				size = Vector3.new(2.0, 5.2, 2.0),
				cframe = segCF * CFrame.new(0, 2.6, zOff),
				color = obsCol,
				material = Enum.Material.Basalt,
				canQuery = false,
				parent = parent,
			})
			makePart({
				name = "StarOrb",
				size = Vector3.new(1.25, 1.25, 1.25),
				cframe = segCF * CFrame.new(0, 5.8, zOff),
				color = if i % 2 == 0 then neonCol else Color3.fromRGB(238, 92, 255),
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
				canCollide = false,
				canQuery = false,
				parent = parent,
			})
		end
	end
end

function PlotVisualBuilder.BuildPenFences(plotModel: Model, plotCF: CFrame, penLevel: number)
	-- Clear old fence container & legacy single-part fences
	local old = plotModel:FindFirstChild("PenFenceVisuals")
	if old then
		old:Destroy()
	end
	for _, legacyName in ipairs({ "FenceBack", "FenceLeft", "FenceRight", "FenceFront_-16.5", "FenceFront_16.5" }) do
		local leg = plotModel:FindFirstChild(legacyName)
		if leg then
			leg:Destroy()
		end
	end

	local tier = PlotVisualBuilder.GetPenTier(penLevel)
	local folder = Instance.new("Model")
	folder.Name = "PenFenceVisuals"
	folder.Parent = plotModel

	local surfaceY = PlotVisualBuilder.GetPlotSurfaceY(plotCF)
	buildFenceSegment(folder, Vector3.new(-26.5, 0, 28.5), Vector3.new(26.5, 0, 28.5), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(-26.5, 0, -8.5), Vector3.new(-26.5, 0, 28.5), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(26.5, 0, -8.5), Vector3.new(26.5, 0, 28.5), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(-26.5, 0, -8.5), Vector3.new(-7.0, 0, -8.5), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(7.0, 0, -8.5), Vector3.new(26.5, 0, -8.5), plotCF, surfaceY, tier)

	-- Match paddock border highlight trim subtly by tier
	local paddock = plotModel:FindFirstChild("OpenPaddockFloor")
	if paddock and paddock:IsA("BasePart") then
		if tier >= 5 then
			paddock.Color = Color3.fromRGB(98, 212, 138)
		elseif tier >= 3 then
			paddock.Color = Color3.fromRGB(114, 204, 102)
		else
			paddock.Color = Color3.fromRGB(122, 198, 94)
		end
	end
	plotModel:SetAttribute("AppliedPenTier", tier)
end

function PlotVisualBuilder.BuildTreadmillTier(plotModel: Model, plotCF: CFrame, treadLevel: number)
	-- Remove previous visual models cleanly
	for _, oldName in ipairs({ "TreadmillVisual", "Hero_Treadmill_AI", "Hero_Treadmill" }) do
		local ex = plotModel:FindFirstChild(oldName)
		if ex then
			ex:Destroy()
		end
	end

	local tier = PlotVisualBuilder.GetTreadmillTier(treadLevel)
	local surfaceY = PlotVisualBuilder.GetPlotSurfaceY(plotCF)

	-- Base CFrame at front-right of plot; local +Z points toward front road (where tall screen console sits)
	-- Player stands at local -Z on the belt and faces +Z (toward the screen console!).
	local treadBaseCF = plotCF * CFrame.new(12, 0, -23.5) * CFrame.Angles(0, math.pi, 0)
	local treadModel = Instance.new("Model")
	treadModel.Name = "TreadmillVisual"
	treadModel.Parent = plotModel

	local beltSurfaceY = surfaceY + BELT_LOCAL_REL_Y
	local usedHero = false

	if tier == 1 then
		local ca = ReplicatedStorage:FindFirstChild("CuratedAssets")
		local tpl = if ca then (ca:FindFirstChild("Hero_Treadmill_AI") or ca:FindFirstChild("Hero_Treadmill")) else nil
		if tpl and tpl:IsA("Model") then
			local clone = tpl:Clone()
			pcall(function()
				clone:ScaleTo(clone:GetScale() * 1.35)
			end)
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				elseif d:IsA("BaseScript") then
					d:Destroy()
				end
			end
			clone:PivotTo(treadBaseCF)
			clone.Parent = treadModel
			local cf, sz = clone:GetBoundingBox()
			local currentBottomY = cf.Position.Y - sz.Y * 0.5
			clone:PivotTo(clone:GetPivot() + Vector3.new(0, surfaceY - currentBottomY, 0))
			beltSurfaceY = surfaceY + BELT_LOCAL_REL_Y
			usedHero = true
		end
	end

	if not usedHero then
		-- Stylized Multi-Part Tiered Treadmills (Tier 2 Electric, Tier 3 Cyber, Tier 4 Jade Dragon like Image 8, Tier 5 Celestial)
		local deckCol = Color3.fromRGB(36, 42, 54)
		local trimCol = Color3.fromRGB(58, 178, 255)
		local railCol = Color3.fromRGB(210, 224, 240)
		local beltCol = Color3.fromRGB(48, 228, 255)
		local archCol = trimCol

		if tier == 3 then
			deckCol = Color3.fromRGB(32, 26, 46)
			trimCol = Color3.fromRGB(224, 72, 255)
			railCol = Color3.fromRGB(58, 62, 78)
			beltCol = Color3.fromRGB(255, 92, 220)
			archCol = Color3.fromRGB(168, 54, 242)
		elseif tier == 4 then
			-- Jade & Gold Dragon Shrine Treadmill (Image 8 inspiration)
			deckCol = Color3.fromRGB(52, 134, 78)
			trimCol = Color3.fromRGB(244, 194, 52)
			railCol = Color3.fromRGB(72, 178, 92)
			beltCol = Color3.fromRGB(108, 248, 168)
			archCol = Color3.fromRGB(246, 198, 54)
		elseif tier >= 5 then
			deckCol = Color3.fromRGB(26, 22, 36)
			trimCol = Color3.fromRGB(0, 245, 224)
			railCol = Color3.fromRGB(255, 206, 62)
			beltCol = Color3.fromRGB(118, 248, 255)
			archCol = Color3.fromRGB(255, 196, 52)
		end

		local groundedCF = CFrame.new(treadBaseCF.Position.X, surfaceY, treadBaseCF.Position.Z)
			* (treadBaseCF - treadBaseCF.Position)

		-- Main deck chassis
		makePart({
			name = "DeckChassis",
			size = Vector3.new(5.6, 1.15, 8.8),
			cframe = groundedCF * CFrame.new(0, 0.58, 0),
			color = deckCol,
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
			parent = treadModel,
		})
		-- Running belt strip (top surface = 1.24 studs above floor)
		makePart({
			name = "RunningBelt",
			size = Vector3.new(3.8, 0.22, 7.6),
			cframe = groundedCF * CFrame.new(0, 1.13, -0.35),
			color = Color3.fromRGB(24, 28, 34),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			parent = treadModel,
		})
		-- Chevron speed stripes along the belt pointing toward +Z (console forward!)
		for idx = -2, 2 do
			makePart({
				name = "BeltChevron_" .. idx,
				size = Vector3.new(2.2, 0.06, 0.36),
				cframe = groundedCF * CFrame.new(0, 1.25, idx * 1.25 - 0.35),
				color = beltCol,
				material = Enum.Material.Neon,
				canCollide = false,
				canQuery = false,
				parent = treadModel,
			})
		end
		-- Side curb trim & handrails
		for _, sx in { -2.4, 2.4 } do
			makePart({
				name = "SideCurb",
				size = Vector3.new(0.85, 1.4, 8.8),
				cframe = groundedCF * CFrame.new(sx, 0.7, 0),
				color = trimCol,
				material = Enum.Material.Metal,
				canCollide = false,
				canQuery = false,
				parent = treadModel,
			})
			makePart({
				name = "FrontPillar",
				size = Vector3.new(1.05, 5.4, 1.05),
				cframe = groundedCF * CFrame.new(sx, 2.7, 2.8),
				color = railCol,
				material = if tier == 4 then Enum.Material.Marble else Enum.Material.Metal,
				canCollide = false,
				canQuery = false,
				parent = treadModel,
			})
			makePart({
				name = "HandRail",
				size = Vector3.new(0.45, 0.45, 4.6),
				cframe = groundedCF * CFrame.new(sx, 3.2, 0.6) * CFrame.Angles(math.rad(14), 0, 0),
				color = trimCol,
				material = Enum.Material.Metal,
				canCollide = false,
				canQuery = false,
				parent = treadModel,
			})
			if tier >= 4 then
				-- Stylized Dragon / Zenith Pillar Crest atop each pillar
				makePart({
					name = "DragonCrest",
					size = Vector3.new(1.4, 1.6, 1.8),
					cframe = groundedCF * CFrame.new(sx, 5.9, 2.7),
					color = if tier == 4 then Color3.fromRGB(78, 198, 86) else Color3.fromRGB(255, 214, 72),
					material = Enum.Material.SmoothPlastic,
					canCollide = false,
					canQuery = false,
					parent = treadModel,
				})
				makePart({
					name = "DragonEyeGlow",
					size = Vector3.new(1.48, 0.45, 0.55),
					cframe = groundedCF * CFrame.new(sx, 6.15, 2.1),
					color = beltCol,
					material = Enum.Material.Neon,
					canCollide = false,
					canQuery = false,
					parent = treadModel,
				})
			end
		end
		-- Overhead Console Arch & Glowing Screen at local +Z = +2.8
		makePart({
			name = "ConsoleCrossbar",
			size = Vector3.new(5.8, 0.9, 1.1),
			cframe = groundedCF * CFrame.new(0, 5.1, 2.8),
			color = archCol,
			material = Enum.Material.Metal,
			canCollide = false,
			canQuery = false,
			parent = treadModel,
		})
		makePart({
			name = "ConsoleScreen",
			size = Vector3.new(2.8, 1.6, 0.5),
			cframe = groundedCF * CFrame.new(0, 4.3, 2.4) * CFrame.Angles(math.rad(-15), 0, 0),
			color = beltCol,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			parent = treadModel,
		})
		beltSurfaceY = surfaceY + 1.26
	end

	-- Keep invisible trigger zone for TrainingSystem (NO visible glowing slab on floor!)
	local oldZone = plotModel:FindFirstChild("TreadmillPad")
	if oldZone and oldZone:IsA("BasePart") then
		oldZone.Size = Vector3.new(7.5, 6.0, 9.2)
		oldZone.CFrame = CFrame.new(treadBaseCF.Position.X, surfaceY + 2.5, treadBaseCF.Position.Z)
			* (treadBaseCF - treadBaseCF.Position)
		oldZone.Transparency = 1
		oldZone.CanCollide = false
		oldZone.CanQuery = false
		oldZone.CanTouch = false
	end

	-- Position TreadmillStandAnchor ON the belt (local z = -0.8) facing +Z (straight into the console screen!)
	local standAnchor = plotModel:FindFirstChild("TreadmillStandAnchor")
	if standAnchor and standAnchor:IsA("BasePart") then
		local rotOnly = treadBaseCF - treadBaseCF.Position
		local standWorldPos = Vector3.new(treadBaseCF.Position.X, beltSurfaceY + 3.05, treadBaseCF.Position.Z)
			+ (rotOnly * Vector3.new(0, 0, -0.8))
		local lookTargetPos = Vector3.new(treadBaseCF.Position.X, beltSurfaceY + 3.05, treadBaseCF.Position.Z)
			+ (rotOnly * Vector3.new(0, 0, 3.0))
		standAnchor.CFrame = CFrame.lookAt(standWorldPos, lookTargetPos)
		standAnchor:SetAttribute("BeltSurfaceY", beltSurfaceY)

		local oldBadge = standAnchor:FindFirstChild("TreadmillStepBadge")
		if oldBadge then
			oldBadge:Destroy()
		end
		local stepBb = Instance.new("BillboardGui")
		stepBb.Name = "TreadmillStepBadge"
		stepBb.Size = UDim2.fromOffset(168, 36)
		stepBb.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
		stepBb.AlwaysOnTop = false
		stepBb.MaxDistance = 85
		stepBb.Enabled = false
		stepBb.Parent = standAnchor

		local stepLbl = Instance.new("TextLabel")
		stepLbl.Name = "ValueLabel"
		stepLbl.Size = UDim2.fromScale(1, 1)
		stepLbl.BackgroundTransparency = 1
		stepLbl.Text = "👟 +1/Step"
		stepLbl.TextColor3 = Color3.fromRGB(96, 224, 255)
		stepLbl.Font = Enum.Font.FredokaOne
		stepLbl.TextScaled = true
		stepLbl.Parent = stepBb
		local stepSt = Instance.new("UIStroke")
		stepSt.Thickness = 2.6
		stepSt.Color = Color3.fromRGB(10, 14, 20)
		stepSt.Parent = stepLbl
	end

	plotModel:SetAttribute("AppliedTreadTier", tier)
end

function PlotVisualBuilder.BuildUpgradeSignboard(opts: {
	name: string,
	boardCF: CFrame,
	surfaceY: number,
	titleText: string,
	subText: string,
	priceText: string,
	accentColor: Color3,
	promptName: string,
	actionText: string,
	objectText: string,
	plotIndex: number,
	parent: Instance,
}): Part
	local rotOnly = opts.boardCF - opts.boardCF.Position
	local basePos = Vector3.new(opts.boardCF.Position.X, opts.surfaceY, opts.boardCF.Position.Z)
	local groundedCF = CFrame.new(basePos) * rotOnly

	-- Wooden base rail & post holding the board cleanly above ground
	makePart({
		name = opts.name .. "_WoodBase",
		size = Vector3.new(5.8, 0.55, 1.3),
		cframe = groundedCF * CFrame.new(0, 0.28, 0),
		color = Color3.fromRGB(132, 86, 48),
		material = Enum.Material.Wood,
		canQuery = false,
		parent = opts.parent,
	})
	makePart({
		name = opts.name .. "_Post",
		size = Vector3.new(1.1, 2.2, 0.8),
		cframe = groundedCF * CFrame.new(0, 1.3, 0),
		color = Color3.fromRGB(24, 30, 44),
		canQuery = false,
		parent = opts.parent,
	})

	local board = makePart({
		name = opts.name,
		size = Vector3.new(6.8, 4.4, 0.55),
		cframe = groundedCF * CFrame.new(0, 3.9, 0),
		color = Color3.fromRGB(20, 26, 40),
		material = Enum.Material.SmoothPlastic,
		parent = opts.parent,
	})
	board:SetAttribute("PlotIndex", opts.plotIndex)

	local function buildBoardGui(face: Enum.NormalId)
		local gui = Instance.new("SurfaceGui")
		gui.Name = if face == Enum.NormalId.Front then "SignGui" else "SignGuiBack"
		gui.Face = face
		gui.Active = false
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 46
		gui.LightInfluence = 0.2
		gui.Parent = board

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local st = Instance.new("UIStroke")
		st.Thickness = 5
		st.Color = opts.accentColor
		st.Parent = frame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(0.92, 0.28)
		title.Position = UDim2.fromScale(0.04, 0.05)
		title.BackgroundTransparency = 1
		title.Text = opts.titleText
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Parent = frame
		local ts = Instance.new("UIStroke")
		ts.Thickness = 2.8
		ts.Color = Color3.fromRGB(8, 10, 14)
		ts.Parent = title

		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.Size = UDim2.fromScale(0.92, 0.24)
		sub.Position = UDim2.fromScale(0.04, 0.34)
		sub.BackgroundTransparency = 1
		sub.Text = opts.subText
		sub.TextColor3 = Color3.fromRGB(132, 238, 255)
		sub.Font = Enum.Font.FredokaOne
		sub.TextScaled = true
		sub.Parent = frame
		local ss = Instance.new("UIStroke")
		ss.Thickness = 2.4
		ss.Color = Color3.fromRGB(8, 10, 14)
		ss.Parent = sub

		local btnBox = Instance.new("TextLabel")
		btnBox.Name = "PriceButton"
		btnBox.Size = UDim2.fromScale(0.84, 0.30)
		btnBox.Position = UDim2.fromScale(0.08, 0.62)
		btnBox.BackgroundColor3 = Color3.fromRGB(88, 218, 42)
		btnBox.Text = opts.priceText
		btnBox.TextColor3 = Color3.new(1, 1, 1)
		btnBox.Font = Enum.Font.FredokaOne
		btnBox.TextScaled = true
		btnBox.Parent = frame
		Instance.new("UICorner", btnBox).CornerRadius = UDim.new(0, 12)
		local bs = Instance.new("UIStroke")
		bs.Thickness = 3
		bs.Color = Color3.fromRGB(10, 14, 18)
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = btnBox
		local bts = Instance.new("UIStroke")
		bts.Thickness = 2.5
		bts.Color = Color3.fromRGB(10, 12, 16)
		bts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		bts.Parent = btnBox
	end

	buildBoardGui(Enum.NormalId.Front)
	buildBoardGui(Enum.NormalId.Back)

	local cd = Instance.new("ClickDetector")
	cd.Name = opts.promptName .. "_Click"
	cd.MaxActivationDistance = 24
	cd.Parent = board

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = opts.promptName
	prompt.ActionText = opts.actionText
	prompt.ObjectText = opts.objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = board

	return board
end

function PlotVisualBuilder.UpdateUpgradeBoardGui(board: Instance?, titleText: string, subText: string, priceText: string, isMaxed: boolean?)
	if not board then
		return
	end
	for _, guiName in ipairs({ "SignGui", "SignGuiBack" }) do
		local gui = board:FindFirstChild(guiName)
		local frame = if gui then gui:FindFirstChildOfClass("Frame") else nil
		if frame then
			local title = frame:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				title.Text = titleText
			end
			local sub = frame:FindFirstChild("Subtitle")
			if sub and sub:IsA("TextLabel") then
				sub.Text = subText
			end
			local btn = frame:FindFirstChild("PriceButton")
			if btn and btn:IsA("TextLabel") then
				btn.Text = priceText
				btn.BackgroundColor3 = if isMaxed then Color3.fromRGB(245, 194, 48) else Color3.fromRGB(88, 218, 42)
			end
		end
	end
end

function PlotVisualBuilder.ApplyPlotEvolution(plotModel: Model, penLevel: number, treadmillLevel: number)
	local base = plotModel.PrimaryPart or plotModel:FindFirstChild("PlotBase")
	if not base or not base:IsA("BasePart") then
		return
	end
	local plotCF = base.CFrame

	local targetPenTier = PlotVisualBuilder.GetPenTier(penLevel)
	if plotModel:GetAttribute("AppliedPenTier") ~= targetPenTier then
		PlotVisualBuilder.BuildPenFences(plotModel, plotCF, penLevel)
	end

	local targetTreadTier = PlotVisualBuilder.GetTreadmillTier(treadmillLevel)
	if plotModel:GetAttribute("AppliedTreadTier") ~= targetTreadTier then
		PlotVisualBuilder.BuildTreadmillTier(plotModel, plotCF, treadmillLevel)
	end
end

return PlotVisualBuilder
