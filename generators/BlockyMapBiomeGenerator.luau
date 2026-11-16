--!strict
-- BlockyMapBiomeGenerator.luau
-- Generates all 5 Stylized Blocky Studded Biomes (Steal an Egg / Steal a Pet style)
-- Combines custom BlockyStud* MaterialVariants, Creator Store Nature Packs, AI Hero Meshes,
-- Crate Spawn Anchors, and Poacher Patrol Waypoints.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeConfig = require(ReplicatedStorage.Config.BiomeConfig)

local BlockyMapBiomeGenerator = {}

local function makeBlock(props: {
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
	p.TopSurface = if props.studded ~= false then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	p.CanQuery = if props.canQuery ~= nil then props.canQuery else true
	p.Transparency = props.transparency or 0
	p.Parent = props.parent
	return p
end

local function addBiomeArchSign(zPos: number, biome: any, parent: Instance)
	local signModel = Instance.new("Model")
	signModel.Name = "BiomeGate_" .. biome.id
	signModel.Parent = parent

	for _, x in { -23, 23 } do
		makeBlock({
			name = "Pillar",
			size = Vector3.new(4, 18, 4),
			cframe = CFrame.new(x, 9, zPos),
			color = biome.cliffColor,
			material = Enum.Material.Slate,
			parent = signModel,
		})
	end

	local banner = makeBlock({
		name = "Banner",
		size = Vector3.new(50, 6, 2.5),
		cframe = CFrame.new(0, 17, zPos),
		color = Color3.fromRGB(30, 34, 44),
		material = Enum.Material.SmoothPlastic,
		studded = false,
		parent = signModel,
	})

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = banner

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(0.92, 0.55)
		lbl.Position = UDim2.fromScale(0.04, 0.08)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("ZONE %d: %s", biome.order, string.upper(biome.name))
		lbl.TextColor3 = biome.accentColor
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = frame

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.fromScale(0.92, 0.30)
		sub.Position = UDim2.fromScale(0.04, 0.65)
		sub.BackgroundTransparency = 1
		sub.Text = string.format("%s | Boss: %s (Rec. Speed: %d)", biome.subtitle, biome.bossName, biome.recommendedSpeed)
		sub.TextColor3 = Color3.fromRGB(235, 240, 248)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.Parent = frame
	end
end

local function findCuratedTemplate(packPath: { string }): Instance?
	local curr: Instance? = ReplicatedStorage:FindFirstChild("CuratedAssets")
	for _, seg in packPath do
		if not curr then
			return nil
		end
		curr = curr:FindFirstChild(seg)
	end
	return curr
end

local function placeDecorProp(template: Instance?, pos: Vector3, yawRad: number, scaleMult: number, parent: Instance)
	if not template then
		return
	end
	local clone = template:Clone()
	if clone:IsA("Model") then
		if scaleMult ~= 1 then
			pcall(function()
				clone:ScaleTo(clone:GetScale() * scaleMult)
			end)
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanQuery = false
				d.CanTouch = false
			elseif d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		clone:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yawRad, 0))
		clone.Parent = parent
		local cf, size = clone:GetBoundingBox()
		local currentBottomY = cf.Position.Y - size.Y * 0.5
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, pos.Y - 0.1 - currentBottomY, 0))
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanQuery = false
		clone.CanTouch = false
		clone.Size = clone.Size * scaleMult
		clone.CFrame = CFrame.new(pos + Vector3.new(0, clone.Size.Y * 0.5 - 0.1, 0)) * CFrame.Angles(0, yawRad, 0)
		clone.Parent = parent
	else
		clone:Destroy()
	end
end

local function getBiomeTemplates(biomeId: string): { Instance }
	local list: { Instance } = {}
	local function addPath(path: { string })
		local inst = findCuratedTemplate(path)
		if inst then
			table.insert(list, inst)
		end
	end

	if biomeId == "PineWoods" then
		addPath({ "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "Spruce1" })
		addPath({ "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "Spruce2" })
		addPath({ "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "Spruce3" })
		addPath({ "Pack_Veedubmike1_Nature", "Trees", "Oak Tree" })
		addPath({ "Pack_Veedubmike1_Nature", "Rocks", "Rock A" })
		addPath({ "Pack_Veedubmike1_Nature", "Bushes", "Bush A" })
	elseif biomeId == "MangroveSwamp" then
		addPath({ "Pack_Veedubmike1_Nature", "Trees", "Dead Tree A" })
		addPath({ "Pack_Veedubmike1_Nature", "Trees", "Dead Tree B" })
		addPath({ "Pack_Veedubmike1_Nature", "Water Plants", "Cattails" })
		addPath({ "Pack_Veedubmike1_Nature", "Ground Details", "Mushroom A" })
		addPath({ "Pack_Veedubmike1_Nature", "Logs and Stumps", "Stump A" })
	elseif biomeId == "SavannaCamp" then
		addPath({ "Savanna_PalmTree" })
		addPath({ "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Rock" })
		addPath({ "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Rock2" })
		addPath({ "Pack_Veedubmike1_Nature", "Trees", "Maple Tree" })
	elseif biomeId == "AlpinePeaks" then
		addPath({ "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "SpruceSnowy1" })
		addPath({ "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "SpruceSnowy2" })
		addPath({ "Pack_Cliosow_PineSnowy", "Low-Poly Pine Trees by Cliosow", "SpruceSnowy3" })
		addPath({ "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Rock3" })
	elseif biomeId == "VolcanicJungle" then
		addPath({ "Pack_Veedubmike1_Nature", "Trees", "Dead Tree A" })
		addPath({ "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Rock" })
		addPath({ "Pack_K3LLo29_Nature", "LowPolyNaturePack", "Rock2" })
	end
	return list
end

local function buildBlockyTree(pos: Vector3, scale: number, leafCol: Color3, snowyCap: boolean, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "BlockySkylineTree"
	m.Parent = parent

	local trunkH = 9 * scale
	makeBlock({
		name = "Trunk",
		size = Vector3.new(2.6 * scale, trunkH, 2.6 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, trunkH * 0.5 - 0.1, 0)),
		color = Color3.fromRGB(118, 62, 42),
		material = Enum.Material.Wood,
		studded = false,
		canQuery = false,
		parent = m,
	})
	makeBlock({
		name = "CanopyBase",
		size = Vector3.new(9 * scale, 5.2 * scale, 9 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, trunkH + 2.2 * scale, 0)),
		color = leafCol,
		material = Enum.Material.Grass,
		studded = true,
		canQuery = false,
		parent = m,
	})
	local topCol = if snowyCap then Color3.fromRGB(244, 248, 255) else leafCol:Lerp(Color3.new(1, 1, 1), 0.14)
	makeBlock({
		name = "CanopyTop",
		size = Vector3.new(6.2 * scale, 3.6 * scale, 6.2 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, trunkH + 5.8 * scale, 0)),
		color = topCol,
		material = if snowyCap then Enum.Material.Snow else Enum.Material.Grass,
		studded = true,
		canQuery = false,
		parent = m,
	})
end

local function buildStepPyramid(pos: Vector3, scale: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "DesertStepPyramid"
	m.Parent = parent
	local sandCol = Color3.fromRGB(218, 186, 114)
	for tier = 0, 5 do
		local w = (36 - tier * 5.2) * scale
		local h = 3.2 * scale
		makeBlock({
			name = "Tier_" .. tier,
			size = Vector3.new(w, h, w),
			cframe = CFrame.new(pos + Vector3.new(0, (tier * h) + h * 0.5 - 0.1, 0)),
			color = if tier % 2 == 0 then sandCol else sandCol:Lerp(Color3.fromRGB(168, 128, 72), 0.15),
			material = Enum.Material.Sandstone,
			studded = true,
			canQuery = false,
			parent = m,
		})
	end
end

local function buildBlockyCactus(pos: Vector3, scale: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "BlockyCactus"
	m.Parent = parent
	local col = Color3.fromRGB(68, 198, 74)
	makeBlock({
		name = "Stem",
		size = Vector3.new(2.4 * scale, 9.5 * scale, 2.4 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, 4.7 * scale, 0)),
		color = col,
		studded = true,
		canQuery = false,
		parent = m,
	})
	makeBlock({
		name = "ArmL",
		size = Vector3.new(4.2 * scale, 2.0 * scale, 2.0 * scale),
		cframe = CFrame.new(pos + Vector3.new(-2.4 * scale, 5.4 * scale, 0)),
		color = col,
		studded = true,
		canQuery = false,
		parent = m,
	})
	makeBlock({
		name = "ArmLUp",
		size = Vector3.new(2.0 * scale, 3.6 * scale, 2.0 * scale),
		cframe = CFrame.new(pos + Vector3.new(-3.5 * scale, 7.2 * scale, 0)),
		color = col,
		studded = true,
		canQuery = false,
		parent = m,
	})
	makeBlock({
		name = "ArmR",
		size = Vector3.new(3.8 * scale, 2.0 * scale, 2.0 * scale),
		cframe = CFrame.new(pos + Vector3.new(2.2 * scale, 4.2 * scale, 0)),
		color = col,
		studded = true,
		canQuery = false,
		parent = m,
	})
end

local function buildSwampMushroom(pos: Vector3, scale: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "GiantSwampMushroom"
	m.Parent = parent
	makeBlock({
		name = "Stem",
		size = Vector3.new(2.4 * scale, 7.5 * scale, 2.4 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, 3.7 * scale, 0)),
		color = Color3.fromRGB(224, 212, 186),
		canQuery = false,
		parent = m,
	})
	makeBlock({
		name = "Cap",
		size = Vector3.new(8.2 * scale, 3.2 * scale, 8.2 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, 8.2 * scale, 0)),
		color = Color3.fromRGB(112, 232, 148),
		material = Enum.Material.Neon,
		studded = false,
		canQuery = false,
		parent = m,
	})
end

local function buildIceSpire(pos: Vector3, scale: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "AlpineIceSpire"
	m.Parent = parent
	for tier = 0, 3 do
		local w = (12 - tier * 2.6) * scale
		local h = 5.5 * scale
		makeBlock({
			name = "IceLayer_" .. tier,
			size = Vector3.new(w, h, w),
			cframe = CFrame.new(pos + Vector3.new(0, tier * h + h * 0.5 - 0.1, 0)) * CFrame.Angles(0, math.rad(tier * 12), 0),
			color = if tier % 2 == 0 then Color3.fromRGB(142, 224, 255) else Color3.fromRGB(218, 244, 255),
			material = Enum.Material.Ice,
			studded = false,
			canQuery = false,
			parent = m,
		})
	end
end

local function buildVolcanoSpire(pos: Vector3, scale: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "VolcanoSpire"
	m.Parent = parent
	for tier = 0, 3 do
		local w = (22 - tier * 4.5) * scale
		local h = 4.8 * scale
		makeBlock({
			name = "Basalt_" .. tier,
			size = Vector3.new(w, h, w),
			cframe = CFrame.new(pos + Vector3.new(0, tier * h + h * 0.5 - 0.1, 0)),
			color = Color3.fromRGB(46, 38, 52),
			material = Enum.Material.Basalt,
			studded = true,
			canQuery = false,
			parent = m,
		})
	end
	makeBlock({
		name = "LavaCore",
		size = Vector3.new(7 * scale, 2.2 * scale, 7 * scale),
		cframe = CFrame.new(pos + Vector3.new(0, 19.2 * scale, 0)),
		color = Color3.fromRGB(255, 96, 28),
		material = Enum.Material.Neon,
		studded = false,
		canQuery = false,
		parent = m,
	})
end

function BlockyMapBiomeGenerator.Build(worldFolder: Folder)
	local existing = worldFolder:FindFirstChild("Biomes")
	if existing then
		existing:Destroy()
	end

	local biomesFolder = Instance.new("Folder")
	biomesFolder.Name = "Biomes"
	biomesFolder.Parent = worldFolder

	local rng = Random.new(42069)
	local mapWidth = 220

	for _, biome in ipairs(BiomeConfig) do
		local biomeModel = Instance.new("Folder")
		biomeModel.Name = biome.id
		biomeModel:SetAttribute("BiomeId", biome.id)
		biomeModel:SetAttribute("ZStart", biome.zStart)
		biomeModel:SetAttribute("ZEnd", biome.zEnd)
		biomeModel.Parent = biomesFolder

		local lenZ = biome.zEnd - biome.zStart
		local centerZ = (biome.zStart + biome.zEnd) / 2

		-- 1. Main Blocky Studded Ground Floor (Split into stepped checkerboard tiles for blocky visual depth)
		local terrainGroup = Instance.new("Folder")
		terrainGroup.Name = "BlockyTerrain"
		terrainGroup.Parent = biomeModel

		makeBlock({
			name = "BiomeMainFloor",
			size = Vector3.new(mapWidth, 4, lenZ),
			cframe = CFrame.new(0, -2, centerZ),
			color = biome.groundColor,
			material = biome.materialName,
			materialVariant = biome.materialVariant,
			studded = true,
			parent = terrainGroup,
		})

		-- Central Expedition Road (clear driving strip down the middle)
		makeBlock({
			name = "ExpeditionTrail",
			size = Vector3.new(34, 0.5, lenZ),
			cframe = CFrame.new(0, 0.2, centerZ),
			color = biome.accentColor,
			material = Enum.Material.SmoothPlastic,
			studded = true,
			parent = terrainGroup,
		})

		-- 2. Wide Stepped Blocky Cliff Plateaus along Left & Right Edges (Y = 26.5 top terrace)
		local cliffHeight = 24
		local capThickness = 2.5
		local plateauTopY = cliffHeight + capThickness -- 26.5
		local plateauWidth = 68
		local plateauCenterX = 94 + plateauWidth * 0.5 -- X spans 94..162

		for _, sideSign in { -1, 1 } do
			-- Main vertical cliff wall (stone/earth tone)
			makeBlock({
				name = "CliffWall_" .. tostring(sideSign),
				size = Vector3.new(plateauWidth, cliffHeight, lenZ),
				cframe = CFrame.new(sideSign * plateauCenterX, cliffHeight * 0.5, centerZ),
				color = biome.cliffColor,
				material = Enum.Material.Brick,
				studded = true,
				canQuery = false,
				parent = terrainGroup,
			})
			-- Biome-colored top plateau cap (matches floor color/material cleanly like Steal an Egg!)
			makeBlock({
				name = "CliffTopPlateau_" .. tostring(sideSign),
				size = Vector3.new(plateauWidth + 1.5, capThickness, lenZ),
				cframe = CFrame.new(sideSign * plateauCenterX, cliffHeight + capThickness * 0.5, centerZ),
				color = biome.groundColor,
				material = biome.materialName,
				materialVariant = biome.materialVariant,
				studded = true,
				canQuery = false,
				parent = terrainGroup,
			})
			-- Front lower cliff ledge steps for silhouette variety
			local sliceStep = 72
			for z = biome.zStart + 36, biome.zEnd - 36, sliceStep do
				local ledgeH = rng:NextInteger(8, 13)
				makeBlock({
					name = "CliffLedge",
					size = Vector3.new(12, ledgeH, 34),
					cframe = CFrame.new(sideSign * 88, ledgeH * 0.5, z),
					color = biome.cliffColor:Lerp(Color3.new(0, 0, 0), 0.12),
					material = biome.materialName,
					materialVariant = biome.materialVariant,
					studded = true,
					canQuery = false,
					parent = terrainGroup,
				})
			end
		end

		-- Biome-specific blocky hazards/props (Mud pools in Mangrove, Ice slabs in Alpine, Lava channels in Volcanic)
		if biome.id == "MangroveSwamp" then
			for z = biome.zStart + 45, biome.zEnd - 45, 75 do
				makeBlock({
					name = "SwampMudPool",
					size = Vector3.new(46, 0.35, 32),
					cframe = CFrame.new(rng:NextNumber(-45, 45), 0.15, z),
					color = Color3.fromRGB(64, 52, 34),
					material = Enum.Material.Mud,
					materialVariant = "BlockyStudMud",
					studded = true,
					parent = terrainGroup,
				})
			end
		elseif biome.id == "AlpinePeaks" then
			for z = biome.zStart + 45, biome.zEnd - 45, 80 do
				makeBlock({
					name = "GlacierIcePatch",
					size = Vector3.new(40, 0.4, 34),
					cframe = CFrame.new(rng:NextNumber(-42, 42), 0.18, z),
					color = Color3.fromRGB(148, 226, 255),
					material = Enum.Material.Ice,
					studded = true,
					parent = terrainGroup,
				})
			end
		elseif biome.id == "VolcanicJungle" then
			for z = biome.zStart + 55, biome.zEnd - 55, 85 do
				makeBlock({
					name = "LavaTrench",
					size = Vector3.new(150, 0.3, 18),
					cframe = CFrame.new(0, 0.12, z),
					color = Color3.fromRGB(255, 92, 28),
					material = Enum.Material.Neon,
					studded = false,
					parent = terrainGroup,
				})
				-- Safe Obsidian Bridge across the lava trench
				makeBlock({
					name = "ObsidianBridge",
					size = Vector3.new(36, 1.2, 22),
					cframe = CFrame.new(0, 0.65, z),
					color = Color3.fromRGB(48, 42, 58),
					material = Enum.Material.Basalt,
					materialVariant = "BlockyStudVolcanic",
					studded = true,
					parent = terrainGroup,
				})
			end
		end

		-- 3. Biome Arch Gate
		if biome.order == 1 then
			addBiomeArchSign(biome.zStart + 10, biome, biomeModel)
		else
			addBiomeArchSign(biome.zStart, biome, biomeModel)
		end

		-- 4. Curated Creator Store Foliage & Props (Arena Floor + Rich Upper Cliff Skyline!)
		local propsFolder = Instance.new("Folder")
		propsFolder.Name = "CuratedDecor"
		propsFolder.Parent = biomeModel

		local templates = getBiomeTemplates(biome.id)
		if #templates > 0 then
			-- Arena lower floor props (outside the 34-stud central road)
			for _ = 1, 20 do
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local px = side * rng:NextNumber(26, 76)
				local pz = rng:NextNumber(biome.zStart + 20, biome.zEnd - 20)
				local tpl = templates[rng:NextInteger(1, #templates)]
				local scale = rng:NextNumber(0.85, 1.25)
				placeDecorProp(tpl, Vector3.new(px, 0, pz), rng:NextNumber(0, math.pi * 2), scale, propsFolder)
			end
			-- Upper Cliff Plateau curated trees & rocks (both left & right ridges!)
			for _, sideSign in { -1, 1 } do
				for _ = 1, 12 do
					local px = sideSign * rng:NextNumber(102, 154)
					local pz = rng:NextNumber(biome.zStart + 18, biome.zEnd - 18)
					local tpl = templates[rng:NextInteger(1, #templates)]
					local scale = rng:NextNumber(1.1, 1.75)
					placeDecorProp(tpl, Vector3.new(px, plateauTopY, pz), rng:NextNumber(0, math.pi * 2), scale, propsFolder)
				end
			end
		end

		-- Stylized Blocky Upper Cliff Trees & Hero Skyline Landmarks per Biome
		for _, sideSign in { -1, 1 } do
			for idx = 1, 7 do
				local zPos = biome.zStart + 25 + ((idx - 1) / 6) * (lenZ - 50) + rng:NextNumber(-10, 10)
				local xPos = sideSign * rng:NextNumber(102, 146)
				local sc = rng:NextNumber(0.95, 1.45)
				if biome.id == "PineWoods" then
					buildBlockyTree(Vector3.new(xPos, plateauTopY, zPos), sc, Color3.fromRGB(58, 178, 52), false, propsFolder)
				elseif biome.id == "MangroveSwamp" then
					if idx % 2 == 0 then
						buildSwampMushroom(Vector3.new(xPos, plateauTopY, zPos), sc, propsFolder)
					else
						buildBlockyTree(Vector3.new(xPos, plateauTopY, zPos), sc, Color3.fromRGB(54, 118, 72), false, propsFolder)
					end
				elseif biome.id == "SavannaCamp" then
					buildBlockyCactus(Vector3.new(xPos, plateauTopY, zPos), sc, propsFolder)
					if idx % 3 == 0 then
						buildBlockyCactus(Vector3.new(sideSign * rng:NextNumber(32, 72), 0, zPos), sc * 0.85, propsFolder)
					end
				elseif biome.id == "AlpinePeaks" then
					buildBlockyTree(Vector3.new(xPos, plateauTopY, zPos), sc * 1.1, Color3.fromRGB(48, 142, 62), true, propsFolder)
				elseif biome.id == "VolcanicJungle" then
					buildBlockyTree(Vector3.new(xPos, plateauTopY, zPos), sc, Color3.fromRGB(168, 52, 34), false, propsFolder)
				end
			end

			-- Signature Giant Cliff Landmark per Biome Side
			local landmarkZ = centerZ + sideSign * 45
			if biome.id == "SavannaCamp" then
				buildStepPyramid(Vector3.new(sideSign * 126, plateauTopY, landmarkZ), 1.15, propsFolder)
			elseif biome.id == "AlpinePeaks" then
				buildIceSpire(Vector3.new(sideSign * 124, plateauTopY, landmarkZ), 1.25, propsFolder)
				buildIceSpire(Vector3.new(sideSign * 134, plateauTopY, centerZ - sideSign * 55), 0.95, propsFolder)
			elseif biome.id == "VolcanicJungle" then
				buildVolcanoSpire(Vector3.new(sideSign * 126, plateauTopY, landmarkZ), 1.2, propsFolder)
				buildVolcanoSpire(Vector3.new(sideSign * 132, plateauTopY, centerZ - sideSign * 65), 0.9, propsFolder)
			end
		end

		-- Place Poacher Watchtower outpost in each biome
		local towerTpl = findCuratedTemplate({ "Hero_PoacherWatchtower" })
		if towerTpl then
			local side = if biome.order % 2 == 1 then 1 else -1
			placeDecorProp(towerTpl, Vector3.new(side * 48, 0, centerZ), if side > 0 then -math.pi / 2 else math.pi / 2, 1.1, propsFolder)
		end

		-- 5. Deterministic Crate Spawn Anchors (12 per biome, including 1 Onboarding Crate right at Z=172 in Biome 1)
		local crateSpawnsFolder = Instance.new("Folder")
		crateSpawnsFolder.Name = "CrateSpawns"
		crateSpawnsFolder.Parent = biomeModel

		if biome.order == 1 then
			local onboardingAnchor = makeBlock({
				name = "OnboardingCrateSpawn",
				size = Vector3.new(4, 0.4, 4),
				cframe = CFrame.new(10, 0.25, 174),
				color = Color3.fromRGB(255, 224, 92),
				material = Enum.Material.Neon,
				canCollide = false,
				transparency = 0.6,
				parent = crateSpawnsFolder,
			})
			onboardingAnchor:SetAttribute("IsOnboarding", true)
			onboardingAnchor:SetAttribute("BiomeId", biome.id)
		end

		for s = 1, 11 do
			local side = if s % 2 == 0 then 1 else -1
			local sx = side * rng:NextNumber(20, 68)
			local sz = biome.zStart + 30 + ((s - 1) / 10) * (lenZ - 65)
			local anchor = makeBlock({
				name = "CrateSpawn_" .. tostring(s),
				size = Vector3.new(4, 0.3, 4),
				cframe = CFrame.new(sx, 0.2, sz),
				color = biome.accentColor,
				material = Enum.Material.SmoothPlastic,
				canCollide = false,
				transparency = 0.75,
				parent = crateSpawnsFolder,
			})
			anchor:SetAttribute("BiomeId", biome.id)
		end

		-- 6. Poacher Patrol Waypoints & Boss Arena Marker
		local patrolFolder = Instance.new("Folder")
		patrolFolder.Name = "PoacherPatrol"
		patrolFolder.Parent = biomeModel

		local waypoints = {
			Vector3.new(-32, 3, biome.zStart + lenZ * 0.25),
			Vector3.new(32, 3, biome.zStart + lenZ * 0.45),
			Vector3.new(-28, 3, biome.zStart + lenZ * 0.70),
			Vector3.new(28, 3, biome.zStart + lenZ * 0.85),
		}
		for idx, wp in ipairs(waypoints) do
			local marker = makeBlock({
				name = "Waypoint_" .. idx,
				size = Vector3.new(2, 2, 2),
				cframe = CFrame.new(wp),
				color = Color3.fromRGB(255, 64, 64),
				canCollide = false,
				transparency = 1,
				parent = patrolFolder,
			})
			marker:SetAttribute("Order", idx)
		end
	end

	-- End of World Abyss Wall after Biome 5
	local endZ = BiomeConfig[#BiomeConfig].zEnd + 10
	makeBlock({
		name = "EndOfWorldWall",
		size = Vector3.new(mapWidth + 20, 32, 16),
		cframe = CFrame.new(0, 16, endZ),
		color = Color3.fromRGB(32, 24, 34),
		material = Enum.Material.Basalt,
		materialVariant = "BlockyStudVolcanic",
		studded = true,
		parent = biomesFolder,
	})

	return biomesFolder
end

return BlockyMapBiomeGenerator
