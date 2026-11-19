--!strict
-- VoxelFusionMachineBuilder.luau
-- Builds the Sci-Fi Fantasy Voxel Pet Fusion Machine / Synthesis Altar
-- based on the 5-view orthographic reference design (Front, Side, Back, Top, Bottom).
-- Pure Roblox Block/Cylinder Parts (SmoothPlastic, Metal, Neon) with zero external asset IDs.

local TweenService = game:GetService("TweenService")

local VoxelFusionMachineBuilder = {}

-- Color Palette
local STONE_DARK = Color3.fromRGB(36, 34, 46)        -- Deep slate/basalt stone
local STONE_MID = Color3.fromRGB(50, 47, 62)         -- Midtone slate stone
local STONE_LIGHT = Color3.fromRGB(68, 64, 82)       -- Accent slate stone
local GOLD_PRIMARY = Color3.fromRGB(248, 172, 36)    -- Vibrant warm gold trim
local GOLD_DARK = Color3.fromRGB(205, 130, 24)       -- Shaded amber gold
local GOLD_BRIGHT = Color3.fromRGB(255, 212, 88)     -- Highlight gold
local NEON_PURPLE = Color3.fromRGB(225, 65, 255)     -- Radiant magenta/purple neon
local NEON_PURPLE_DEEP = Color3.fromRGB(180, 40, 245)-- Deep violet neon
local NEON_CORE = Color3.fromRGB(250, 145, 255)      -- High-energy core white-magenta
local CYAN_SCREEN = Color3.fromRGB(48, 205, 255)     -- Hologram terminal display cyan
local BANNER_PURPLE = Color3.fromRGB(135, 32, 210)   -- Royal velvet purple banner cloth
local METAL_GRILLE = Color3.fromRGB(28, 26, 34)      -- Exhaust vent grille slats

export type BuildOptions = {
	withPrompt: boolean?,
	withLabel: boolean?,
	parent: Instance?,
	scale: number?,
}

-- Internal helper to instantiate an anchored part
local function makePart(props: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
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
	if props.shape then
		p.Shape = props.shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else false
	p.CanQuery = if props.canQuery ~= nil then props.canQuery else false
	p.Transparency = props.transparency or 0
	p.Parent = props.parent
	return p
end

-- Renders a pure vector/UI Pet Paw Print into a container Frame
local function renderPawIcon(container: GuiObject, padColor: Color3, sizeScale: number?)
	local scale = sizeScale or 1
	local pawHolder = Instance.new("Frame")
	pawHolder.Name = "PawHolder"
	pawHolder.BackgroundTransparency = 1
	pawHolder.Size = UDim2.fromScale(1, 1)
	pawHolder.Position = UDim2.fromScale(0, 0)
	pawHolder.Parent = container

	-- Main Central Palm Pad
	local palm = Instance.new("Frame")
	palm.Name = "Palm"
	palm.Size = UDim2.fromScale(0.48 * scale, 0.40 * scale)
	palm.Position = UDim2.fromScale(0.5, 0.62)
	palm.AnchorPoint = Vector2.new(0.5, 0.5)
	palm.BackgroundColor3 = padColor
	palm.BorderSizePixel = 0
	local palmCorner = Instance.new("UICorner")
	palmCorner.CornerRadius = UDim.new(0.45, 0)
	palmCorner.Parent = palm
	palm.Parent = pawHolder

	-- 4 Rounded Toes (Outer-Left, Mid-Left, Mid-Right, Outer-Right)
	local toeDefs = {
		{ x = 0.26, y = 0.38, w = 0.16, h = 0.22, rot = -20 },
		{ x = 0.42, y = 0.25, w = 0.17, h = 0.24, rot = -7 },
		{ x = 0.58, y = 0.25, w = 0.17, h = 0.24, rot = 7 },
		{ x = 0.74, y = 0.38, w = 0.16, h = 0.22, rot = 20 },
	}
	for i, td in ipairs(toeDefs) do
		local toe = Instance.new("Frame")
		toe.Name = "Toe_" .. i
		toe.Size = UDim2.fromScale(td.w * scale, td.h * scale)
		toe.Position = UDim2.fromScale(td.x, td.y)
		toe.AnchorPoint = Vector2.new(0.5, 0.5)
		toe.Rotation = td.rot
		toe.BackgroundColor3 = padColor
		toe.BorderSizePixel = 0
		local toeCorner = Instance.new("UICorner")
		toeCorner.CornerRadius = UDim.new(0.5, 0)
		toeCorner.Parent = toe
		toe.Parent = pawHolder
	end
end

-- Builds the Interactive Terminal Console (Pedestal + Angled Screen + Sci-Fi UI)
local function buildConsole(rootCF: CFrame, side: number, scale: number, parent: Instance)
	-- side: -1 for Left, +1 for Right
	local s = scale
	local consoleCF = rootCF * CFrame.new(side * 5.6 * s, 1.3 * s, -5.8 * s) * CFrame.Angles(0, math.rad(side * 28), 0)

	-- Base Plinth
	makePart({
		name = "ConsolePlinth_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.4 * s, 0.4 * s, 2.4 * s),
		cframe = consoleCF * CFrame.new(0, 0.2 * s, 0),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	-- Gold Plinth Border
	makePart({
		name = "ConsolePlinthGold_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.6 * s, 0.15 * s, 2.6 * s),
		cframe = consoleCF * CFrame.new(0, 0.08 * s, 0),
		color = GOLD_PRIMARY,
		canCollide = true,
		parent = parent,
	})

	-- Vertical Stand Pillar
	makePart({
		name = "ConsolePillar_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(1.4 * s, 1.8 * s, 1.4 * s),
		cframe = consoleCF * CFrame.new(0, 1.2 * s, 0),
		color = STONE_MID,
		canCollide = true,
		parent = parent,
	})
	-- Vertical Gold Corner Struts
	for _, dx in ipairs({ -0.65, 0.65 }) do
		makePart({
			name = "ConsoleStrut",
			size = Vector3.new(0.2 * s, 1.8 * s, 0.2 * s),
			cframe = consoleCF * CFrame.new(dx * s, 1.2 * s, -0.65 * s),
			color = GOLD_PRIMARY,
			parent = parent,
		})
	end

	-- Angled Console Head (tilted back ~35 deg so it faces up toward player)
	local headCF = consoleCF * CFrame.new(0, 2.25 * s, 0) * CFrame.Angles(math.rad(-35), 0, 0)

	-- Console Housing
	makePart({
		name = "ConsoleHousing_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.8 * s, 2.0 * s, 0.5 * s),
		cframe = headCF * CFrame.new(0, 0, 0),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	-- Gold Housing Bevel Frame
	makePart({
		name = "ConsoleGoldRim",
		size = Vector3.new(3.0 * s, 2.2 * s, 0.2 * s),
		cframe = headCF * CFrame.new(0, 0, 0.16 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- Glowing Screen Part
	local screenPart = makePart({
		name = "ConsoleScreen_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.4 * s, 1.65 * s, 0.15 * s),
		cframe = headCF * CFrame.new(0, 0, -0.22 * s),
		color = CYAN_SCREEN,
		material = Enum.Material.Neon,
		transparency = 0.05,
		parent = parent,
	})

	-- Soft PointLight from Screen
	local screenLight = Instance.new("PointLight")
	screenLight.Name = "ScreenGlow"
	screenLight.Color = CYAN_SCREEN
	screenLight.Brightness = 1.4
	screenLight.Range = 6.0 * s
	screenLight.Shadows = false
	screenLight.Parent = screenPart

	-- SurfaceGui on the Screen with Authentic Pixel-Art High-Tech Readouts
	local sg = Instance.new("SurfaceGui")
	sg.Name = "TerminalUI"
	sg.Face = Enum.NormalId.Back
	sg.LightInfluence = 0
	sg.CanvasSize = Vector2.new(320, 220)
	sg.Parent = screenPart

	local bg = Instance.new("Frame")
	bg.Name = "ScreenBg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 20, 36)
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local innerRim = Instance.new("UIStroke")
	innerRim.Color = Color3.fromRGB(64, 218, 255)
	innerRim.Thickness = 2
	innerRim.Parent = bg

	if side < 0 then
		-- LEFT CONSOLE: "PET SYNTHESIS" & Paw Diagnostics
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -16, 0, 28)
		header.Position = UDim2.fromOffset(8, 6)
		header.BackgroundTransparency = 1
		header.Text = "PET SYNTHESIS"
		header.TextColor3 = Color3.fromRGB(120, 235, 255)
		header.TextSize = 18
		header.Font = Enum.Font.GothamBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = bg

		-- Small Paw Icon in top-right of screen
		local pawBox = Instance.new("Frame")
		pawBox.Size = UDim2.fromOffset(40, 40)
		pawBox.Position = UDim2.new(1, -48, 0, 6)
		pawBox.BackgroundTransparency = 1
		pawBox.Parent = bg
		renderPawIcon(pawBox, Color3.fromRGB(255, 255, 255), 0.9)

		-- Slot A & Slot B Panels
		for i, name in ipairs({ "PRIMARY PET [A]", "SECONDARY PET [B]" }) do
			local slot = Instance.new("Frame")
			slot.Size = UDim2.new(1, -16, 0, 48)
			slot.Position = UDim2.fromOffset(8, 38 + (i - 1) * 54)
			slot.BackgroundColor3 = Color3.fromRGB(14, 32, 54)
			slot.BorderSizePixel = 0
			slot.Parent = bg

			local slotStroke = Instance.new("UIStroke")
			slotStroke.Color = Color3.fromRGB(48, 160, 210)
			slotStroke.Thickness = 1
			slotStroke.Parent = slot

			local slotLbl = Instance.new("TextLabel")
			slotLbl.Size = UDim2.new(1, -8, 0, 18)
			slotLbl.Position = UDim2.fromOffset(6, 4)
			slotLbl.BackgroundTransparency = 1
			slotLbl.Text = name .. " - SYNCED"
			slotLbl.TextColor3 = Color3.fromRGB(180, 240, 255)
			slotLbl.TextSize = 12
			slotLbl.Font = Enum.Font.GothamBold
			slotLbl.TextXAlignment = Enum.TextXAlignment.Left
			slotLbl.Parent = slot

			local barBg = Instance.new("Frame")
			barBg.Size = UDim2.new(1, -12, 0, 14)
			barBg.Position = UDim2.fromOffset(6, 26)
			barBg.BackgroundColor3 = Color3.fromRGB(20, 48, 76)
			barBg.BorderSizePixel = 0
			barBg.Parent = slot

			local barFill = Instance.new("Frame")
			barFill.Size = UDim2.fromScale(i == 1 and 0.88 or 0.72, 1)
			barFill.BackgroundColor3 = Color3.fromRGB(64, 235, 180)
			barFill.BorderSizePixel = 0
			barFill.Parent = barBg
		end

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(1, -16, 0, 24)
		statusLbl.Position = UDim2.fromOffset(8, 150)
		statusLbl.BackgroundColor3 = Color3.fromRGB(18, 54, 42)
		statusLbl.Text = "READY TO FUSE - 100% STABLE"
		statusLbl.TextColor3 = Color3.fromRGB(80, 255, 160)
		statusLbl.TextSize = 13
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.BorderSizePixel = 0
		statusLbl.Parent = bg
	else
		-- RIGHT CONSOLE: "FUSION CORE" Telemetry & Waveform Matrix
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -16, 0, 28)
		header.Position = UDim2.fromOffset(8, 6)
		header.BackgroundTransparency = 1
		header.Text = "FUSION CORE TELEMETRY"
		header.TextColor3 = Color3.fromRGB(120, 235, 255)
		header.TextSize = 17
		header.Font = Enum.Font.GothamBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = bg

		-- Matrix Telemetry Grid Bars
		local gridBox = Instance.new("Frame")
		gridBox.Size = UDim2.new(1, -16, 0, 95)
		gridBox.Position = UDim2.fromOffset(8, 38)
		gridBox.BackgroundColor3 = Color3.fromRGB(12, 28, 48)
		gridBox.BorderSizePixel = 0
		gridBox.Parent = bg

		local gridStroke = Instance.new("UIStroke")
		gridStroke.Color = Color3.fromRGB(48, 160, 210)
		gridStroke.Thickness = 1
		gridStroke.Parent = gridBox

		-- Simulated Voxel Waveform Bars
		local barCount = 14
		for b = 1, barCount do
			local h = math.sin((b / barCount) * math.pi) * 0.7 + 0.25
			local wBar = Instance.new("Frame")
			wBar.Size = UDim2.new(1 / barCount, -3, h, 0)
			wBar.Position = UDim2.new((b - 1) / barCount, 2, 1 - h, 0)
			wBar.BackgroundColor3 = Color3.fromRGB(80, 215, 255)
			wBar.BorderSizePixel = 0
			wBar.Parent = gridBox
		end

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(1, -16, 0, 24)
		statusLbl.Position = UDim2.fromOffset(8, 142)
		statusLbl.BackgroundColor3 = Color3.fromRGB(42, 24, 64)
		statusLbl.Text = "OUTPUT: PRIMORDIAL TIER"
		statusLbl.TextColor3 = Color3.fromRGB(235, 120, 255)
		statusLbl.TextSize = 13
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.BorderSizePixel = 0
		statusLbl.Parent = bg

		local promptHint = Instance.new("TextLabel")
		promptHint.Size = UDim2.new(1, -16, 0, 20)
		promptHint.Position = UDim2.fromOffset(8, 172)
		promptHint.BackgroundTransparency = 1
		promptHint.Text = "PRESS [E] AT ALTAR TO MERGE"
		promptHint.TextColor3 = Color3.fromRGB(245, 195, 60)
		promptHint.TextSize = 12
		promptHint.Font = Enum.Font.GothamBold
		promptHint.Parent = bg
	end
end

-- Builds a Massive Flanking Pillar with Banner, Vertical Neon & Gold Brackets
local function buildPillar(rootCF: CFrame, side: number, scale: number, parent: Instance)
	local s = scale
	local pX = side * 7.2 * s
	local pZ = -0.5 * s

	-- Main Pillar Shaft (Base up to Lintel)
	makePart({
		name = "PillarShaft_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(4.2 * s, 9.6 * s, 4.4 * s),
		cframe = rootCF * CFrame.new(pX, 6.6 * s, pZ),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})

	-- Pillar Base Plinth Bracket (Gold wrap)
	makePart({
		name = "PillarBaseGold_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(4.6 * s, 1.2 * s, 4.8 * s),
		cframe = rootCF * CFrame.new(pX, 2.4 * s, pZ),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Pillar Mid-Height Gold Trim Band
	makePart({
		name = "PillarMidGold_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(4.5 * s, 0.6 * s, 4.7 * s),
		cframe = rootCF * CFrame.new(pX, 7.6 * s, pZ),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Pillar Top Capital (Under Arch)
	makePart({
		name = "PillarCapGold_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(4.8 * s, 0.8 * s, 5.0 * s),
		cframe = rootCF * CFrame.new(pX, 11.4 * s, pZ),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Pillar Top Battlement / Turret Block (Extends above arch)
	makePart({
		name = "PillarBattlement_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(4.0 * s, 1.6 * s, 4.2 * s),
		cframe = rootCF * CFrame.new(pX, 12.6 * s, pZ),
		color = STONE_MID,
		parent = parent,
	})
	-- 4 Gold Corner Battlement Caps
	for _, dx in ipairs({ -1.7, 1.7 }) do
		for _, dz in ipairs({ -1.8, 1.8 }) do
			makePart({
				name = "BattlementCornerCap",
				size = Vector3.new(0.7 * s, 0.5 * s, 0.7 * s),
				cframe = rootCF * CFrame.new(pX + dx * s, 13.55 * s, pZ + dz * s),
				color = GOLD_PRIMARY,
				parent = parent,
			})
		end
	end

	-- FRONT FACE VERTICAL NEON CHANNEL (Recessed into Pillar)
	makePart({
		name = "PillarFrontNeon_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(0.7 * s, 7.2 * s, 0.3 * s),
		cframe = rootCF * CFrame.new(pX, 6.6 * s, pZ - 2.25 * s),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		parent = parent,
	})
	-- Flanking Gold Trim for Front Neon Channel
	for _, dx in ipairs({ -0.55, 0.55 }) do
		makePart({
			name = "PillarFrontNeonTrim",
			size = Vector3.new(0.2 * s, 7.2 * s, 0.2 * s),
			cframe = rootCF * CFrame.new(pX + dx * s, 6.6 * s, pZ - 2.25 * s),
			color = GOLD_PRIMARY,
			parent = parent,
		})
	end

	-- HANGING ROYAL PURPLE PET PAW BANNER (Mounted to front of Pillar)
	-- Gold Mounting Rod
	makePart({
		name = "BannerRod_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(3.4 * s, 0.35 * s, 0.5 * s),
		cframe = rootCF * CFrame.new(pX, 9.8 * s, pZ - 2.5 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Rod Finials (Gold spheres/cubes at ends)
	for _, dx in ipairs({ -1.75, 1.75 }) do
		makePart({
			name = "BannerFinial",
			size = Vector3.new(0.45 * s, 0.45 * s, 0.45 * s),
			cframe = rootCF * CFrame.new(pX + dx * s, 9.8 * s, pZ - 2.5 * s),
			color = GOLD_BRIGHT,
			parent = parent,
		})
	end

	-- Banner Cloth Part
	local bannerCloth = makePart({
		name = "BannerCloth_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.8 * s, 4.8 * s, 0.15 * s),
		cframe = rootCF * CFrame.new(pX, 7.1 * s, pZ - 2.55 * s),
		color = BANNER_PURPLE,
		parent = parent,
	})
	-- Banner Bottom Swallowtail / Gold Border
	makePart({
		name = "BannerGoldBottom_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.8 * s, 0.45 * s, 0.2 * s),
		cframe = rootCF * CFrame.new(pX, 4.5 * s, pZ - 2.55 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Center Swallowtail Point
	makePart({
		name = "BannerSwallowtailPoint",
		size = Vector3.new(0.8 * s, 0.5 * s, 0.2 * s),
		cframe = rootCF * CFrame.new(pX, 4.15 * s, pZ - 2.55 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- SurfaceGui for Crisp White Pet Paw Insignia on Banner
	local bannerGui = Instance.new("SurfaceGui")
	bannerGui.Name = "BannerPawGui"
	bannerGui.Face = Enum.NormalId.Front
	bannerGui.LightInfluence = 0.2
	bannerGui.CanvasSize = Vector2.new(256, 384)
	bannerGui.Parent = bannerCloth

	local bannerFrame = Instance.new("Frame")
	bannerFrame.Size = UDim2.fromScale(1, 1)
	bannerFrame.BackgroundTransparency = 1
	bannerFrame.Parent = bannerGui

	-- White Stylized Paw Print in Center of Banner
	local pawContainer = Instance.new("Frame")
	pawContainer.Size = UDim2.fromOffset(180, 180)
	pawContainer.Position = UDim2.fromScale(0.5, 0.45)
	pawContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	pawContainer.BackgroundTransparency = 1
	pawContainer.Parent = bannerFrame
	renderPawIcon(pawContainer, Color3.fromRGB(255, 255, 255), 1.0)

	-- OUTER SIDE BUTTRESS & WING (Visible in Front & Side views)
	local wingX = pX + side * 2.8 * s
	makePart({
		name = "PillarSideWing_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(1.8 * s, 7.6 * s, 3.8 * s),
		cframe = rootCF * CFrame.new(wingX, 5.6 * s, pZ),
		color = STONE_MID,
		canCollide = true,
		parent = parent,
	})
	-- Outer Vertical Neon Strip on Side Face
	makePart({
		name = "PillarSideNeon_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(0.25 * s, 6.0 * s, 0.7 * s),
		cframe = rootCF * CFrame.new(wingX + side * 0.95 * s, 5.6 * s, pZ),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		parent = parent,
	})
	-- Gold Cap on Outer Side Wing
	makePart({
		name = "PillarSideWingGold_" .. (side < 0 and "L" or "R"),
		size = Vector3.new(2.0 * s, 0.5 * s, 4.0 * s),
		cframe = rootCF * CFrame.new(wingX, 9.65 * s, pZ),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- REAR FACE VERTICAL NEON CHANNELS (Visible in Back View)
	for _, dx in ipairs({ -1.0, 1.0 }) do
		makePart({
			name = "PillarRearNeon",
			size = Vector3.new(0.45 * s, 7.2 * s, 0.25 * s),
			cframe = rootCF * CFrame.new(pX + dx * s, 6.6 * s, pZ + 2.25 * s),
			color = NEON_PURPLE,
			material = Enum.Material.Neon,
			parent = parent,
		})
	end
end

-- Builds the Upper Canopy Arch, Forward Visor, Underside Emitter & Apex Crown Gem
local function buildCanopyAndCrown(rootCF: CFrame, scale: number, parent: Instance)
	local s = scale
	local cZ = -0.5 * s

	-- Main Overhead Crossbeam (Spans between Left and Right Pillars)
	makePart({
		name = "ArchCrossbeam",
		size = Vector3.new(12.4 * s, 2.2 * s, 4.6 * s),
		cframe = rootCF * CFrame.new(0, 11.2 * s, cZ),
		color = STONE_DARK,
		parent = parent,
	})
	-- Forward Visor / Overhang Cornice
	makePart({
		name = "ArchForwardVisor",
		size = Vector3.new(12.8 * s, 1.2 * s, 2.2 * s),
		cframe = rootCF * CFrame.new(0, 11.1 * s, cZ - 2.6 * s),
		color = STONE_MID,
		parent = parent,
	})
	-- Gold Trim Rim outlining the bottom front of the arch
	makePart({
		name = "ArchGoldRimFront",
		size = Vector3.new(13.2 * s, 0.45 * s, 0.5 * s),
		cframe = rootCF * CFrame.new(0, 10.4 * s, cZ - 3.7 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Gold Trim along bottom perimeter of canopy
	for _, sx in ipairs({ -6.2, 6.2 }) do
		makePart({
			name = "ArchGoldRimSide",
			size = Vector3.new(0.5 * s, 0.45 * s, 4.6 * s),
			cframe = rootCF * CFrame.new(sx * s, 10.4 * s, cZ - 1.2 * s),
			color = GOLD_PRIMARY,
			parent = parent,
		})
	end

	-- Canopy Top Deck Slab
	makePart({
		name = "ArchTopDeck",
		size = Vector3.new(10.8 * s, 0.6 * s, 4.4 * s),
		cframe = rootCF * CFrame.new(0, 12.5 * s, cZ),
		color = STONE_MID,
		parent = parent,
	})

	-- UNDERSIDE RECESSED CIRCULAR NEON EMITTER RING (Projects glow downward into fusion core)
	local topRingBase = makePart({
		name = "ArchUndersideRingBase",
		size = Vector3.new(5.0 * s, 0.3 * s, 5.0 * s),
		cframe = rootCF * CFrame.new(0, 10.15 * s, cZ),
		color = STONE_DARK,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	topRingBase.CFrame = rootCF * CFrame.new(0, 10.15 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	local topNeonRing = makePart({
		name = "ArchUndersideNeonRing",
		size = Vector3.new(4.4 * s, 0.35 * s, 4.4 * s),
		cframe = rootCF * CFrame.new(0, 10.05 * s, cZ),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	topNeonRing.CFrame = rootCF * CFrame.new(0, 10.05 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	-- APEX GOLDEN CROWN & MAGENTA FLOATING DIAMOND CRYSTAL (Front & Back Views)
	-- Multi-tier Gold Crest Pedestal
	makePart({
		name = "CrownBaseTier1",
		size = Vector3.new(5.0 * s, 0.6 * s, 2.8 * s),
		cframe = rootCF * CFrame.new(0, 12.9 * s, cZ - 1.2 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	makePart({
		name = "CrownBaseTier2",
		size = Vector3.new(3.8 * s, 0.5 * s, 2.4 * s),
		cframe = rootCF * CFrame.new(0, 13.4 * s, cZ - 1.2 * s),
		color = GOLD_BRIGHT,
		parent = parent,
	})

	-- 3 Golden Crown Prongs
	-- Center Back Crest
	makePart({
		name = "CrownCenterCrest",
		size = Vector3.new(2.2 * s, 2.2 * s, 0.6 * s),
		cframe = rootCF * CFrame.new(0, 14.5 * s, cZ - 0.7 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	-- Left & Right Flanking Prongs
	makePart({
		name = "CrownProng_L",
		size = Vector3.new(0.7 * s, 1.8 * s, 0.7 * s),
		cframe = rootCF * CFrame.new(-1.6 * s, 14.3 * s, cZ - 1.2 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	makePart({
		name = "CrownProng_R",
		size = Vector3.new(0.7 * s, 1.8 * s, 0.7 * s),
		cframe = rootCF * CFrame.new(1.6 * s, 14.3 * s, cZ - 1.2 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- Glowing Apex Diamond Crystal (Magenta Octahedron / Diamond)
	local apexCrystal = makePart({
		name = "ApexCrownDiamond",
		size = Vector3.new(1.5 * s, 1.8 * s, 1.5 * s),
		cframe = rootCF * CFrame.new(0, 14.6 * s, cZ - 1.2 * s) * CFrame.Angles(0, math.rad(45), 0),
		color = NEON_CORE,
		material = Enum.Material.Neon,
		transparency = 0.05,
		parent = parent,
	})

	-- Crown Ambient PointLight
	local crownLight = Instance.new("PointLight")
	crownLight.Name = "CrownGlow"
	crownLight.Color = NEON_PURPLE
	crownLight.Brightness = 2.4
	crownLight.Range = 12.0 * s
	crownLight.Shadows = false
	crownLight.Parent = apexCrystal
end

-- Builds Central Fusion Core, Plasma Cylinder, Rotating Energy Cube & Particle Vortex
local function buildFusionVortex(rootCF: CFrame, scale: number, parent: Instance): BasePart
	local s = scale
	local cZ = -0.5 * s

	-- Lower Emitter Ring on the Altar Floor
	local botRing = makePart({
		name = "FusionLowerEmitterRing",
		size = Vector3.new(5.0 * s, 0.35 * s, 5.0 * s),
		cframe = rootCF * CFrame.new(0, 2.15 * s, cZ),
		color = STONE_DARK,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	botRing.CFrame = rootCF * CFrame.new(0, 2.15 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	local botNeonRing = makePart({
		name = "FusionLowerNeonRing",
		size = Vector3.new(4.4 * s, 0.4 * s, 4.4 * s),
		cframe = rootCF * CFrame.new(0, 2.2 * s, cZ),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	botNeonRing.CFrame = rootCF * CFrame.new(0, 2.2 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	-- Vertical Glowing Plasma Column (Translucent Neon Magenta Cylinder)
	local plasmaColumn = makePart({
		name = "FusionPlasmaBeam",
		size = Vector3.new(2.8 * s, 7.8 * s, 2.8 * s),
		cframe = rootCF * CFrame.new(0, 6.25 * s, cZ),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		transparency = 0.65,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	plasmaColumn.CFrame = rootCF * CFrame.new(0, 6.25 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	-- 4 Perimeter Vertical Neon Rods / Containment Plasma Conduits
	for _, angle in ipairs({ 45, 135, 225, 315 }) do
		local rad = math.rad(angle)
		local rx = math.cos(rad) * 2.2 * s
		local rz = math.sin(rad) * 2.2 * s
		makePart({
			name = "ContainmentRod",
			size = Vector3.new(0.3 * s, 7.8 * s, 0.3 * s),
			cframe = rootCF * CFrame.new(rx, 6.25 * s, cZ + rz),
			color = NEON_PURPLE,
			material = Enum.Material.Neon,
			parent = parent,
		})
	end

	-- Central Floating Energy Core (Bright White-Magenta Tilted Cube)
	local coreCube = makePart({
		name = "FusionEnergyCore",
		size = Vector3.new(2.0 * s, 2.0 * s, 2.0 * s),
		cframe = rootCF * CFrame.new(0, 6.4 * s, cZ) * CFrame.Angles(math.rad(25), math.rad(45), math.rad(15)),
		color = NEON_CORE,
		material = Enum.Material.Neon,
		transparency = 0.05,
		parent = parent,
	})

	-- Outer Gold Gyro Bracket Framing the Core
	makePart({
		name = "CoreGyroRing",
		size = Vector3.new(2.6 * s, 0.25 * s, 2.6 * s),
		cframe = rootCF * CFrame.new(0, 6.4 * s, cZ) * CFrame.Angles(math.rad(-20), math.rad(30), math.rad(45)),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- Radiant Altar PointLight
	local coreLight = Instance.new("PointLight")
	coreLight.Name = "AltarCoreGlow"
	coreLight.Color = NEON_PURPLE
	coreLight.Brightness = 4.0
	coreLight.Range = 26.0 * s
	coreLight.Shadows = false
	coreLight.Parent = coreCube

	-- Particle Emitter (Ascending ethereal purple spark motes and energy rings)
	local vfx = Instance.new("ParticleEmitter")
	vfx.Name = "FusionSparks"
	vfx.LightEmission = 1.0
	vfx.LightInfluence = 0
	vfx.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4 * s),
		NumberSequenceKeypoint.new(0.5, 0.9 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	vfx.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	vfx.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(225, 65, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 40, 240)),
	})
	vfx.Speed = NumberRange.new(2.5 * s, 4.5 * s)
	vfx.Lifetime = NumberRange.new(1.4, 2.2)
	vfx.Rate = 18
	vfx.SpreadAngle = Vector2.new(15, 15)
	vfx.Acceleration = Vector3.new(0, 3.5 * s, 0)
	vfx.Parent = coreCube

	return coreCube
end

-- Builds the Reinforced Back Wall, Exhaust Louvers & Reactor Conduit (Back View)
local function buildRearWallAndConduit(rootCF: CFrame, scale: number, parent: Instance)
	local s = scale
	local rZ = 1.7 * s

	-- Main Rear Wall Panel connecting Pillars
	makePart({
		name = "RearWallMain",
		size = Vector3.new(10.6 * s, 9.6 * s, 1.2 * s),
		cframe = rootCF * CFrame.new(0, 6.6 * s, rZ),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})

	-- Gold Framing Beams on Rear Wall
	makePart({
		name = "RearWallGoldTop",
		size = Vector3.new(11.0 * s, 0.5 * s, 1.4 * s),
		cframe = rootCF * CFrame.new(0, 11.2 * s, rZ),
		color = GOLD_PRIMARY,
		parent = parent,
	})
	makePart({
		name = "RearWallGoldBot",
		size = Vector3.new(11.0 * s, 0.5 * s, 1.4 * s),
		cframe = rootCF * CFrame.new(0, 2.2 * s, rZ),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- CENTRAL COOLING & POWER HOUSING (Projecting back at rZ + 0.8)
	local houseZ = rZ + 0.7 * s
	makePart({
		name = "ReactorHousing",
		size = Vector3.new(4.6 * s, 8.8 * s, 0.8 * s),
		cframe = rootCF * CFrame.new(0, 6.5 * s, houseZ),
		color = STONE_MID,
		canCollide = true,
		parent = parent,
	})
	-- Gold Frame around Reactor Housing
	makePart({
		name = "ReactorGoldFrame",
		size = Vector3.new(5.0 * s, 9.2 * s, 0.25 * s),
		cframe = rootCF * CFrame.new(0, 6.5 * s, houseZ + 0.35 * s),
		color = GOLD_PRIMARY,
		parent = parent,
	})

	-- UPPER EXHAUST VENTILATION GRILLE (Slotted louvers)
	local ventY = 9.2 * s
	makePart({
		name = "ExhaustVentCavity",
		size = Vector3.new(3.6 * s, 1.8 * s, 0.4 * s),
		cframe = rootCF * CFrame.new(0, ventY, houseZ + 0.35 * s),
		color = STONE_DARK,
		parent = parent,
	})
	-- 4 Dark Horizontal Louver Slats
	for i = 1, 4 do
		local sy = ventY - 0.65 * s + (i - 1) * 0.42 * s
		makePart({
			name = "VentLouver_" .. i,
			size = Vector3.new(3.4 * s, 0.15 * s, 0.5 * s),
			cframe = rootCF * CFrame.new(0, sy, houseZ + 0.45 * s),
			color = METAL_GRILLE,
			parent = parent,
		})
	end

	-- LOWER REACTOR POWER CONDUIT / SEGMENTED ENERGY GAUGE
	local gaugeCavity = makePart({
		name = "ReactorGaugeCavity",
		size = Vector3.new(1.8 * s, 5.0 * s, 0.4 * s),
		cframe = rootCF * CFrame.new(0, 5.0 * s, houseZ + 0.35 * s),
		color = STONE_DARK,
		parent = parent,
	})

	-- 8 Horizontal Glowing Purple Neon Ladder Rungs (Energy Meter segments)
	local rungCount = 8
	for r = 1, rungCount do
		local ry = 2.8 * s + (r - 1) * 0.6 * s
		makePart({
			name = "ConduitRung_" .. r,
			size = Vector3.new(1.3 * s, 0.3 * s, 0.2 * s),
			cframe = rootCF * CFrame.new(0, ry, houseZ + 0.48 * s),
			color = NEON_PURPLE,
			material = Enum.Material.Neon,
			parent = parent,
		})
	end

	-- Rear Foundation Stepped Plinth with Purple Neon Lights
	makePart({
		name = "RearPlinthStep",
		size = Vector3.new(14.0 * s, 0.6 * s, 2.4 * s),
		cframe = rootCF * CFrame.new(0, 0.3 * s, 7.2 * s),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	makePart({
		name = "RearNeonLightStrip",
		size = Vector3.new(8.0 * s, 0.3 * s, 0.3 * s),
		cframe = rootCF * CFrame.new(0, 0.35 * s, 8.45 * s),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		parent = parent,
	})
end

-- Builds the 3-Tier Solid Walkable Dais, Front Step Projections & Inset Neon Strips
local function buildSteppedPlatform(rootCF: CFrame, scale: number, parent: Instance): Part
	local s = scale
	local cZ = -0.5 * s

	-- TIER 1: GROUND BASE (Y = 0.0 .. 0.6)
	-- Main slab
	local baseAnchor = makePart({
		name = "BaseAnchor",
		size = Vector3.new(18.0 * s, 0.6 * s, 14.0 * s),
		cframe = rootCF * CFrame.new(0, 0.3 * s, cZ),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	-- Front step extension 1
	makePart({
		name = "Step1_FrontExt",
		size = Vector3.new(10.0 * s, 0.6 * s, 3.2 * s),
		cframe = rootCF * CFrame.new(0, 0.3 * s, -7.6 * s),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	-- Front neon strip 1
	makePart({
		name = "Step1_NeonStrip",
		size = Vector3.new(8.2 * s, 0.3 * s, 0.3 * s),
		cframe = rootCF * CFrame.new(0, 0.35 * s, -9.25 * s),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		parent = parent,
	})
	-- Gold corner caps on front step 1
	for _, dx in ipairs({ -4.3, 4.3 }) do
		makePart({
			name = "Step1_GoldCap",
			size = Vector3.new(0.8 * s, 0.65 * s, 0.8 * s),
			cframe = rootCF * CFrame.new(dx * s, 0.32 * s, -9.0 * s),
			color = GOLD_PRIMARY,
			canCollide = true,
			parent = parent,
		})
	end

	-- Left & Right Side Plinth Wings
	for _, sx in ipairs({ -1, 1 }) do
		makePart({
			name = "SideWingBase_" .. (sx < 0 and "L" or "R"),
			size = Vector3.new(3.5 * s, 0.6 * s, 10.0 * s),
			cframe = rootCF * CFrame.new(sx * 9.75 * s, 0.3 * s, cZ),
			color = STONE_DARK,
			canCollide = true,
			parent = parent,
		})
		-- Side horizontal neon light strip
		makePart({
			name = "SideWingNeon_" .. (sx < 0 and "L" or "R"),
			size = Vector3.new(0.3 * s, 0.3 * s, 7.0 * s),
			cframe = rootCF * CFrame.new(sx * 11.55 * s, 0.35 * s, cZ),
			color = NEON_PURPLE,
			material = Enum.Material.Neon,
			parent = parent,
		})
		-- Gold side corner brackets
		for _, dz in ipairs({ -4.2, 4.2 }) do
			makePart({
				name = "SideWingGoldCap",
				size = Vector3.new(0.8 * s, 0.65 * s, 0.8 * s),
				cframe = rootCF * CFrame.new(sx * 11.2 * s, 0.32 * s, cZ + dz * s),
				color = GOLD_PRIMARY,
				canCollide = true,
				parent = parent,
			})
		end
	end

	-- TIER 2: INTERMEDIATE PODIUM STEP (Y = 0.6 .. 1.2)
	makePart({
		name = "Step2_Deck",
		size = Vector3.new(15.0 * s, 0.6 * s, 11.8 * s),
		cframe = rootCF * CFrame.new(0, 0.9 * s, cZ),
		color = STONE_MID,
		canCollide = true,
		parent = parent,
	})
	makePart({
		name = "Step2_FrontExt",
		size = Vector3.new(8.2 * s, 0.6 * s, 2.6 * s),
		cframe = rootCF * CFrame.new(0, 0.9 * s, -6.6 * s),
		color = STONE_MID,
		canCollide = true,
		parent = parent,
	})
	makePart({
		name = "Step2_NeonStrip",
		size = Vector3.new(6.8 * s, 0.25 * s, 0.25 * s),
		cframe = rootCF * CFrame.new(0, 0.95 * s, -7.95 * s),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		parent = parent,
	})

	-- TIER 3: MAIN WALKABLE ALTAR DECK (Y = 1.2 .. 1.8)
	makePart({
		name = "Step3_MainDeck",
		size = Vector3.new(12.8 * s, 0.6 * s, 9.6 * s),
		cframe = rootCF * CFrame.new(0, 1.5 * s, cZ),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	makePart({
		name = "Step3_FrontExt",
		size = Vector3.new(6.6 * s, 0.6 * s, 2.0 * s),
		cframe = rootCF * CFrame.new(0, 1.5 * s, -5.6 * s),
		color = STONE_DARK,
		canCollide = true,
		parent = parent,
	})
	makePart({
		name = "Step3_NeonStrip",
		size = Vector3.new(5.2 * s, 0.25 * s, 0.25 * s),
		cframe = rootCF * CFrame.new(0, 1.55 * s, -6.65 * s),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		parent = parent,
	})

	-- RECESSED CONCENTRIC GLOWING PURPLE NEON FUSION RING ON ALTAR FLOOR
	local floorRingBase = makePart({
		name = "FloorRingStoneFrame",
		size = Vector3.new(7.6 * s, 0.2 * s, 7.6 * s),
		cframe = rootCF * CFrame.new(0, 1.82 * s, cZ),
		color = GOLD_PRIMARY,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	floorRingBase.CFrame = rootCF * CFrame.new(0, 1.82 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	local floorNeonRing = makePart({
		name = "FloorNeonRingInlay",
		size = Vector3.new(6.8 * s, 0.25 * s, 6.8 * s),
		cframe = rootCF * CFrame.new(0, 1.85 * s, cZ),
		color = NEON_PURPLE,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Cylinder,
		parent = parent,
	})
	floorNeonRing.CFrame = rootCF * CFrame.new(0, 1.85 * s, cZ) * CFrame.Angles(0, 0, math.rad(90))

	-- 4 Gold Latch Brackets pinning the fusion ring
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local rad = math.rad(angle)
		local lx = math.cos(rad) * 3.4 * s
		local lz = math.sin(rad) * 3.4 * s
		makePart({
			name = "FloorRingGoldLatch",
			size = Vector3.new(0.6 * s, 0.3 * s, 0.6 * s),
			cframe = rootCF * CFrame.new(lx, 1.95 * s, cZ + lz),
			color = GOLD_BRIGHT,
			parent = parent,
		})
	end

	return baseAnchor
end

-- Attaches the ProximityPrompt and Gameplay Trigger Anchor
local function attachGameplayElements(model: Model, rootCF: CFrame, scale: number, options: BuildOptions)
	local s = scale
	local cZ = -0.5 * s

	-- MergePromptAnchor (Part with ProximityPrompt)
	local promptAnchor = makePart({
		name = "MergePromptAnchor",
		size = Vector3.new(6.0 * s, 5.0 * s, 6.0 * s),
		cframe = rootCF * CFrame.new(0, 3.2 * s, -4.2 * s),
		color = NEON_PURPLE,
		transparency = 1,
		canCollide = false,
		canQuery = false,
		parent = model,
	})

	if options.withPrompt ~= false then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FusePrompt"
		prompt.ActionText = "Hold [E] to Merge Pets"
		prompt.ObjectText = "Merge Machine"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = promptAnchor
	end

	-- Floating 3D Billboard Label "Merge Pets"
	if options.withLabel ~= false then
		local labelAnchor = makePart({
			name = "BoothSignAnchor_Merge Pets",
			size = Vector3.new(8.0 * s, 1.0 * s, 1.0 * s),
			cframe = rootCF * CFrame.new(0, 16.5 * s, cZ - 2.2 * s),
			color = STONE_DARK,
			transparency = 1,
			canCollide = false,
			parent = model,
		})

		local bb = Instance.new("BillboardGui")
		bb.Name = "BoothLabelGui"
		bb.Size = UDim2.fromScale(10.5, 3.2)
		bb.StudsOffset = Vector3.new(0, 0.5 * s, 0)
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		bb.MaxDistance = 120
		bb.Parent = labelAnchor

		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.fromScale(0.85, 0.75)
		badge.Position = UDim2.fromScale(0.5, 0.5)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
		badge.BackgroundTransparency = 0.15
		badge.BorderSizePixel = 0
		badge.Parent = bb

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0.3, 0)
		badgeCorner.Parent = badge

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = GOLD_PRIMARY
		badgeStroke.Thickness = 2.5
		badgeStroke.Parent = badge

		local txt = Instance.new("TextLabel")
		txt.Name = "TitleText"
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = "MERGE PETS"
		txt.TextColor3 = Color3.fromRGB(255, 230, 110)
		txt.Font = Enum.Font.FredokaOne
		txt.TextScaled = true
		txt.Parent = badge

		local txtStroke = Instance.new("UIStroke")
		txtStroke.Color = Color3.fromRGB(50, 12, 85)
		txtStroke.Thickness = 2
		txtStroke.Parent = txt
	end
end

--- Public Builder API
--- @param cframe CFrame The root world CFrame (floor center of the machine)
--- @param scale number? Optional scale multiplier (default = 1.0)
--- @param options BuildOptions? Options for prompts, labels, and parenting
function VoxelFusionMachineBuilder.Build(cframe: CFrame, scale: number?, options: BuildOptions?): Model
	local opt: BuildOptions = options or {}
	local s = scale or opt.scale or 1.0

	local model = Instance.new("Model")
	model.Name = "Hero_VoxelFusionMachine"

	-- 1. Solid Stepped Platform & Inset Neon Base
	local baseAnchor = buildSteppedPlatform(cframe, s, model)
	model.PrimaryPart = baseAnchor

	-- 2. Flanking Left & Right Pillars with Banners, Battlement Crowns & Neon Bars
	buildPillar(cframe, -1, s, model)
	buildPillar(cframe, 1, s, model)

	-- 3. Upper Canopy Arch, Visor & Apex Golden Crown with Diamond Crystal
	buildCanopyAndCrown(cframe, s, model)

	-- 4. Central Fusion Vortex (Plasma Column, Floating Energy Core, VFX & Light)
	buildFusionVortex(cframe, s, model)

	-- 5. Dual Front Interactive Terminal Consoles with Cyan UI Displays
	buildConsole(cframe, -1, s, model)
	buildConsole(cframe, 1, s, model)

	-- 6. Reinforced Back Wall, Exhaust Vent Louvers & Reactor Conduit Gauge
	buildRearWallAndConduit(cframe, s, model)

	-- 7. Attach Gameplay Prompt & 3D Floating Booth Label
	attachGameplayElements(model, cframe, s, opt)

	if opt.parent then
		model.Parent = opt.parent
	end

	return model
end

return VoxelFusionMachineBuilder
