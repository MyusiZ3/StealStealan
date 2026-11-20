--!strict
-- PlotVisualBuilder.luau
-- Builds & updates evolving Open-Pen Fencing (5 visual tiers), evolving Treadmills (5 visual tiers),
-- clean belt stand anchors facing the console screen, and 3D Wooden-Post Upgrade Signboards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VoxelTreadmillBuilder = require(ReplicatedStorage.Modules.VoxelTreadmillBuilder)

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
	if props.materialVariant == "Studs" or (props.studded and (not props.materialVariant or props.materialVariant == "")) then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = "Studs"
		p.TopSurface = Enum.SurfaceType.Smooth
	else
		p.Material = props.material or Enum.Material.SmoothPlastic
		if props.materialVariant and props.materialVariant ~= "" then
			p.MaterialVariant = props.materialVariant
		end
		p.TopSurface = if props.studded then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	end
	if props.shape then
		p.Shape = props.shape
	end
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

	-- 2. Crisp Clean Perimeter Rim (Non-Neon so sunlight/bloom never blows out!)
	makePart({
		name = opts.name .. "_NeonRim",
		size = Vector3.new(opts.size.X + 0.95, opts.size.Y - 0.08, opts.size.Z + 0.95),
		cframe = opts.cframe * CFrame.new(0, -0.06, 0),
		color = opts.accentColor,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		canQuery = false,
		parent = opts.parent,
	})

	-- 3. Corner Accent Pillars with Colored Caps
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
			material = Enum.Material.SmoothPlastic,
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
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			transparency = 0.72,
			parent = opts.parent,
		})
		halo.CastShadow = false
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
	local lv = math.max(1, math.floor(tonumber(penLevel) or 1))
	return math.clamp(math.floor((lv - 1) / 3) + 1, 1, 5)
end

function PlotVisualBuilder.GetTreadmillTier(treadLevel: number): number
	return math.clamp(math.floor(tonumber(treadLevel) or 1), 1, 12)
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
		-- Clean Soft White Picket Fence with Oak Trim
		local railCol = Color3.fromRGB(224, 228, 236)
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
			material = Enum.Material.Plastic,
			materialVariant = "Studs",
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
					color = Color3.fromRGB(245, 194, 78),
					material = Enum.Material.SmoothPlastic,
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
		-- Royal Marble & Gold Conservatory with Emerald Finials
		local marbleCol = Color3.fromRGB(220, 224, 232)
		local goldCol = Color3.fromRGB(236, 188, 56)
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
					color = Color3.fromRGB(58, 212, 132),
					material = Enum.Material.Glass,
					shape = Enum.PartType.Ball,
					canCollide = false,
					canQuery = false,
					transparency = 0.15,
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
		-- Tier 5: Celestial Obsidian & Trim Sanctum (Non-glare)
		local obsCol = Color3.fromRGB(32, 28, 42)
		local goldCol = Color3.fromRGB(238, 194, 68)
		local trimCol = Color3.fromRGB(58, 198, 235)
		makePart({
			name = "ObsidianBase",
			size = Vector3.new(1.7, 1.6, length),
			cframe = segCF * CFrame.new(0, 0.8, 0),
			color = obsCol,
			material = Enum.Material.Plastic,
			materialVariant = "Studs",
			studded = true,
			parent = parent,
		})
		makePart({
			name = "NeonLaserMid",
			size = Vector3.new(0.3, 0.3, length),
			cframe = segCF * CFrame.new(0, 2.7, 0),
			color = trimCol,
			material = Enum.Material.SmoothPlastic,
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
				color = if i % 2 == 0 then trimCol else Color3.fromRGB(196, 88, 238),
				material = Enum.Material.SmoothPlastic,
				shape = Enum.PartType.Ball,
				canCollide = false,
				canQuery = false,
				parent = parent,
			})
		end
	end
end

local PEN_TIER_ACCENTS: { [number]: { post: Color3, glow: Color3, trim: Color3 } } = {
	[1] = { post = Color3.fromRGB(112, 74, 42), glow = Color3.fromRGB(255, 198, 76), trim = Color3.fromRGB(142, 96, 54) },
	[2] = { post = Color3.fromRGB(132, 86, 48), glow = Color3.fromRGB(255, 224, 128), trim = Color3.fromRGB(232, 236, 244) },
	[3] = { post = Color3.fromRGB(48, 52, 62), glow = Color3.fromRGB(255, 174, 62), trim = Color3.fromRGB(118, 122, 134) },
	[4] = { post = Color3.fromRGB(238, 192, 64), glow = Color3.fromRGB(128, 224, 255), trim = Color3.fromRGB(242, 242, 248) },
	[5] = { post = Color3.fromRGB(28, 24, 38), glow = Color3.fromRGB(186, 88, 255), trim = Color3.fromRGB(58, 198, 235) },
}

local function buildCornerLanternPost(parent: Instance, worldPos: Vector3, pal: { post: Color3, glow: Color3, trim: Color3 }, tag: string)
	makePart({
		name = "CornerLanternPost_" .. tag,
		size = Vector3.new(1.5, 5.4, 1.5),
		cframe = CFrame.new(worldPos + Vector3.new(0, 2.7, 0)),
		color = pal.post,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
		parent = parent,
	})
	makePart({
		name = "CornerLanternCap_" .. tag,
		size = Vector3.new(2.0, 0.55, 2.0),
		cframe = CFrame.new(worldPos + Vector3.new(0, 5.65, 0)),
		color = pal.trim,
		material = Enum.Material.Metal,
		canCollide = false,
		canQuery = false,
		parent = parent,
	})
	makePart({
		name = "CornerLanternOrb_" .. tag,
		size = Vector3.new(1.15, 1.15, 1.15),
		cframe = CFrame.new(worldPos + Vector3.new(0, 6.45, 0)),
		color = pal.glow,
		material = Enum.Material.Neon,
		canCollide = false,
		canQuery = false,
		parent = parent,
	})
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

	local lv = math.max(1, math.floor(tonumber(penLevel) or 1))
	local tier = PlotVisualBuilder.GetPenTier(lv)
	local subLevel = (lv - 1) % 3
	local folder = Instance.new("Model")
	folder.Name = "PenFenceVisuals"
	folder.Parent = plotModel

	local surfaceY = PlotVisualBuilder.GetPlotSurfaceY(plotCF)
	-- True 1:1 square (40x40) at Lv. 1; fixed front gate at Z = -8.5 and expands +2.5 studs backward (+Z) per level
	local penWidth = 40.0
	local xFence = 20.5
	local zFront = -8.5
	local penDepth = 40.0 + (lv - 1) * 2.5
	local zBack = zFront + penDepth
	local zCenter = (zFront + zBack) * 0.5

	local paddock = plotModel:FindFirstChild("OpenPaddockFloor")
	if paddock and paddock:IsA("BasePart") then
		paddock.Size = Vector3.new(penWidth, 0.08, penDepth)
		paddock.CFrame = plotCF * CFrame.new(0, 1.00, zCenter)
		if tier >= 5 then
			paddock.Color = Color3.fromRGB(98, 212, 138)
		elseif tier >= 3 then
			paddock.Color = Color3.fromRGB(114, 204, 102)
		else
			paddock.Color = Color3.fromRGB(122, 198, 94)
		end
	end

	-- Extend PlotBase foundation seamlessly backward (+Z) when pen grows beyond default Z=+32
	if lv > 1 and (zBack + 2.5 > 32.0) then
		local extLen = (zBack + 2.5) - 32.0
		local extMidZ = 32.0 + extLen * 0.5
		makePart({
			name = "PlotBaseRearExt",
			size = Vector3.new(64, 2, extLen),
			cframe = plotCF * CFrame.new(0, 0, extMidZ),
			color = Color3.fromRGB(108, 184, 88),
			material = Enum.Material.Plastic,
			materialVariant = "Studs",
			studded = true,
			parent = folder,
		})
	end

	buildFenceSegment(folder, Vector3.new(-xFence, 0, zBack), Vector3.new(xFence, 0, zBack), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(-xFence, 0, zFront), Vector3.new(-xFence, 0, zBack), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(xFence, 0, zFront), Vector3.new(xFence, 0, zBack), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(-xFence, 0, zFront), Vector3.new(-6.5, 0, zFront), plotCF, surfaceY, tier)
	buildFenceSegment(folder, Vector3.new(6.5, 0, zFront), Vector3.new(xFence, 0, zFront), plotCF, surfaceY, tier)

	-- Progressive Accessories: Sub-Level +1 (Lanterns + Gate Arch), Sub-Level +2 (Rear Totems + Planter Trim)
	local pal = PEN_TIER_ACCENTS[tier] or PEN_TIER_ACCENTS[1]
	if subLevel >= 1 or tier >= 2 then
		for idx, cLocal in ipairs({
			Vector3.new(-xFence, 0, zFront),
			Vector3.new(xFence, 0, zFront),
			Vector3.new(-xFence, 0, zBack),
			Vector3.new(xFence, 0, zBack),
		}) do
			local wp = (plotCF * CFrame.new(cLocal)).Position
			buildCornerLanternPost(folder, Vector3.new(wp.X, surfaceY, wp.Z), pal, tostring(idx))
		end

		-- Front Gate Archway (keeps entrance clear for player & pets)
		local gateLeft = (plotCF * CFrame.new(-7.4, 0, zFront)).Position
		local gateRight = (plotCF * CFrame.new(7.4, 0, zFront)).Position
		local rotOnly = plotCF - plotCF.Position
		for _, gp in ipairs({
			{ tag = "L", p = gateLeft },
			{ tag = "R", p = gateRight },
		}) do
			makePart({
				name = "GateArchPillar_" .. gp.tag,
				size = Vector3.new(1.5, 7.8, 1.5),
				cframe = CFrame.new(gp.p.X, surfaceY + 3.9, gp.p.Z) * rotOnly,
				color = pal.post,
				material = Enum.Material.Metal,
				canCollide = false,
				canQuery = false,
				parent = folder,
			})
		end
		local gateMid = (gateLeft + gateRight) * 0.5
		makePart({
			name = "GateArchBeam",
			size = Vector3.new(16.4, 1.15, 1.6),
			cframe = CFrame.new(gateMid.X, surfaceY + 8.0, gateMid.Z) * rotOnly,
			color = pal.trim,
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			parent = folder,
		})
		makePart({
			name = "GateArchCrestGlow",
			size = Vector3.new(11.0, 0.35, 1.75),
			cframe = CFrame.new(gateMid.X, surfaceY + 8.65, gateMid.Z) * rotOnly,
			color = pal.glow,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			parent = folder,
		})
	end

	if subLevel >= 2 then
		local rotOnly = plotCF - plotCF.Position
		-- Rear Totem / Statue Ornaments + Planter Trim Boxes
		for sideIdx, sx in ipairs({ -13.0, 0, 13.0 }) do
			local wp = (plotCF * CFrame.new(sx, 0, zBack - 2.2)).Position
			makePart({
				name = "RearTotemBase_" .. sideIdx,
				size = Vector3.new(2.2, 4.4, 2.2),
				cframe = CFrame.new(wp.X, surfaceY + 2.2, wp.Z) * rotOnly,
				color = pal.post,
				material = Enum.Material.Metal,
				canCollide = false,
				canQuery = false,
				parent = folder,
			})
			makePart({
				name = "RearTotemGem_" .. sideIdx,
				size = Vector3.new(1.3, 1.3, 1.3),
				cframe = CFrame.new(wp.X, surfaceY + 5.2, wp.Z) * rotOnly * CFrame.Angles(0, math.rad(45), math.rad(45)),
				color = pal.glow,
				material = Enum.Material.Neon,
				canCollide = false,
				canQuery = false,
				parent = folder,
			})
		end

		for boxIdx, bLocal in ipairs({
			Vector3.new(-13.5, 0, zFront - 1.4),
			Vector3.new(13.5, 0, zFront - 1.4),
			Vector3.new(-(xFence + 1.3), 0, zCenter),
			Vector3.new(xFence + 1.3, 0, zCenter),
		}) do
			local bp = (plotCF * CFrame.new(bLocal)).Position
			makePart({
				name = "DecoPlanter_" .. boxIdx,
				size = if math.abs(bLocal.X) > xFence then Vector3.new(1.5, 0.85, 6.0) else Vector3.new(5.6, 0.85, 1.4),
				cframe = CFrame.new(bp.X, surfaceY + 0.42, bp.Z) * rotOnly,
				color = pal.trim,
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				parent = folder,
			})
			makePart({
				name = "DecoFlora_" .. boxIdx,
				size = if math.abs(bLocal.X) > xFence then Vector3.new(1.0, 0.5, 5.2) else Vector3.new(4.8, 0.5, 0.9),
				cframe = CFrame.new(bp.X, surfaceY + 1.0, bp.Z) * rotOnly,
				color = pal.glow,
				material = Enum.Material.Grass,
				canCollide = false,
				canQuery = false,
				parent = folder,
			})
		end
	end

	-- Kandang tidak punya collider: semua part pagar/dekorasi tembus, kecuali lantai perluasan plot
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "PlotBaseRearExt" then
			d.CanCollide = false
			d.CanQuery = false
		end
	end

	plotModel:SetAttribute("AppliedPenTier", tier)
	plotModel:SetAttribute("AppliedPenLevel", lv)
end

function PlotVisualBuilder.BuildTreadmillTier(plotModel: Model, plotCF: CFrame, treadLevel: number)
	-- Remove previous visual models cleanly
	for _, oldName in ipairs({ "TreadmillVisual", "Hero_Treadmill_AI", "Hero_Treadmill" }) do
		local ex = plotModel:FindFirstChild(oldName)
		if ex then
			ex:Destroy()
		end
	end

	local lv = PlotVisualBuilder.GetTreadmillTier(treadLevel)
	local surfaceY = PlotVisualBuilder.GetPlotSurfaceY(plotCF)
	local treadScale = 0.84

	-- Base CFrame at front-right of plot; local +Z points toward front road (where tall screen console sits)
	-- Player stands at local -Z on the belt and faces +Z (toward the screen console!).
	local treadBaseCF = plotCF * CFrame.new(12, 0, -23.5) * CFrame.Angles(0, math.pi, 0)
	local rotOnly = treadBaseCF - treadBaseCF.Position
	local groundedCF = CFrame.new(treadBaseCF.Position.X, surfaceY, treadBaseCF.Position.Z) * rotOnly

	local treadModel = VoxelTreadmillBuilder.Build(lv, groundedCF)
	treadModel.Name = "TreadmillVisual"
	treadModel:SetAttribute("TreadScale", treadScale)
	for _, d in ipairs(treadModel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	treadModel.Parent = plotModel
	pcall(function()
		treadModel:ScaleTo(treadScale)
	end)

	local beltSurfaceY = surfaceY + 1.325 * treadScale

	-- Invisible solid floor at beltSurfaceY so Humanoid never clips into decorative parts or grass
	makePart({
		name = "BeltFloorCollider",
		size = Vector3.new(4.2, 0.3, 8.6),
		cframe = CFrame.new(treadBaseCF.Position.X, beltSurfaceY - 0.15, treadBaseCF.Position.Z)
			* rotOnly
			* CFrame.new(0, 0, -0.4),
		color = Color3.fromRGB(24, 28, 34),
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
		canCollide = true,
		canQuery = true,
		parent = treadModel,
	})

	-- Keep invisible trigger zone for TrainingSystem (NO visible glowing slab on floor!)
	local oldZone = plotModel:FindFirstChild("TreadmillPad")
	if oldZone and oldZone:IsA("BasePart") then
		oldZone.Size = Vector3.new(7.2, 6.0, 10.6)
		oldZone.CFrame = CFrame.new(treadBaseCF.Position.X, surfaceY + 2.5, treadBaseCF.Position.Z) * rotOnly
		oldZone.Transparency = 1
		oldZone.CanCollide = false
		oldZone.CanQuery = false
		oldZone.CanTouch = false
	end

	-- Position TreadmillStandAnchor ON the belt (local z = -0.7) facing +Z (straight into the console screen!)
	local standAnchor = plotModel:FindFirstChild("TreadmillStandAnchor")
	if standAnchor and standAnchor:IsA("BasePart") then
		local standWorldPos = Vector3.new(treadBaseCF.Position.X, beltSurfaceY + 3.05, treadBaseCF.Position.Z)
			+ (rotOnly * Vector3.new(0, 0, -0.7))
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
		stepLbl.Text = "👟 +2/Step"
		stepLbl.TextColor3 = Color3.fromRGB(96, 224, 255)
		stepLbl.Font = Enum.Font.FredokaOne
		stepLbl.TextScaled = true
		stepLbl.Parent = stepBb
		local stepSt = Instance.new("UIStroke")
		stepSt.Thickness = 2.6
		stepSt.Color = Color3.fromRGB(10, 14, 20)
		stepSt.Parent = stepLbl
	end

	plotModel:SetAttribute("AppliedTreadTier", lv)
	plotModel:SetAttribute("AppliedTreadLevel", lv)
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

function PlotVisualBuilder.UpdateCashPileVisual(plotModel: Model, unclaimedCoins: number, incomePerSec: number): number
	local cashPad = plotModel:FindFirstChild("CashCollectorPad")
	if not cashPad or not cashPad:IsA("BasePart") then
		return 0
	end

	local targetBundles = 0
	if unclaimedCoins >= 1 then
		local ratio = if incomePerSec > 0 then (unclaimedCoins / incomePerSec) else (math.log10(1 + unclaimedCoins) * 4)
		targetBundles = math.clamp(math.ceil(ratio / 2.0), 1, 24)
	end

	local pileModel = plotModel:FindFirstChild("VoxelCashPile")
	if not pileModel or not pileModel:IsA("Model") then
		if pileModel then pileModel:Destroy() end
		local nm = Instance.new("Model")
		nm.Name = "VoxelCashPile"
		nm.Parent = plotModel
		pileModel = nm
	end
	local pm = pileModel :: Model
	if pm:GetAttribute("BundleCount") == targetBundles then
		return targetBundles
	end

	pm:ClearAllChildren()
	pm:SetAttribute("BundleCount", targetBundles)

	for i = 1, targetBundles do
		local layer = math.floor((i - 1) / 12)
		local idxInLayer = (i - 1) % 12
		local col = idxInLayer % 4
		local row = math.floor(idxInLayer / 4)
		local ox = (col - 1.5) * 1.45
		local oz = (row - 1.0) * 1.85
		local oy = 0.38 + layer * 0.30
		local isGold = (i > 20)
		local yaw = ((i * 19) % 15 - 7) * 0.025
		local billCF = cashPad.CFrame * CFrame.new(ox, oy, oz) * CFrame.Angles(0, yaw, 0)

		local bill = makePart({
			name = "CashBundle_" .. i,
			size = Vector3.new(1.18, 0.26, 0.68),
			cframe = billCF,
			color = if isGold then Color3.fromRGB(255, 206, 54) else Color3.fromRGB(68, 204, 92),
			material = if isGold then Enum.Material.Metal else Enum.Material.SmoothPlastic,
			canCollide = false,
			canQuery = false,
			parent = pm,
		})
		bill.CastShadow = false

		if not isGold then
			local band = makePart({
				name = "Band_" .. i,
				size = Vector3.new(0.32, 0.28, 0.72),
				cframe = billCF,
				color = Color3.fromRGB(242, 246, 242),
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				canQuery = false,
				parent = pm,
			})
			band.CastShadow = false
		end
	end

	return targetBundles
end

function PlotVisualBuilder.ApplyPlotEvolution(plotModel: Model, penLevel: number, treadmillLevel: number)
	local base = plotModel.PrimaryPart or plotModel:FindFirstChild("PlotBase")
	if not base or not base:IsA("BasePart") then
		return
	end
	local plotCF = base.CFrame

	local cleanPenLv = math.max(1, math.floor(tonumber(penLevel) or 1))
	if plotModel:GetAttribute("AppliedPenLevel") ~= cleanPenLv then
		PlotVisualBuilder.BuildPenFences(plotModel, plotCF, cleanPenLv)
	end

	local targetTreadLv = PlotVisualBuilder.GetTreadmillTier(treadmillLevel)
	if plotModel:GetAttribute("AppliedTreadLevel") ~= targetTreadLv then
		PlotVisualBuilder.BuildTreadmillTier(plotModel, plotCF, targetTreadLv)
	end
end

return PlotVisualBuilder
