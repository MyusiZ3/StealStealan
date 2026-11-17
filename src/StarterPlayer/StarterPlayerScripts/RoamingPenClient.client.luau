--!strict
-- RoamingPenClient.client.luau
-- Spawns & animates free-roaming blocky animals AND up to 30 hatching crates inside each plot's Open-Pen Paddock.
-- Supports random sizeRatio scaling, 7 mutation VFX, Rainbow hue cycling, varied crate biome/rarity visuals, and live hatch countdowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local AnimalConfig = require(ReplicatedStorage.Config.AnimalConfig)
local AnimalVisualBuilder = require(ReplicatedStorage.Modules.AnimalVisualBuilder)
local VoxelPets = require(ReplicatedStorage.Modules.VoxelPets)
local CinematicVFX = require(ReplicatedStorage.Modules.CinematicVFX)
local RarityEffects = require(ReplicatedStorage.Modules.RarityEffects)
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

RarityEffects.BindWorldCrateEffects()

local localPlayer = Players.LocalPlayer

type RoamingEntity = {
	uid: string,
	plotIndex: number,
	model: Model,
	isRainbow: boolean,
	isScrambled: boolean,
	orbitParts: { { part: BasePart, radius: number, phase: number, y: number } },
	pos: Vector3,
	targetPos: Vector3,
	yaw: number,
	speed: number,
	waitUntil: number,
	phase: number,
	paddockCF: CFrame,
	topY: number,
	footBotRel: number,
}

type PlacedCrateVisual = {
	uid: string,
	plotIndex: number,
	isOwn: boolean,
	model: Model,
	baseCF: CFrame,
	localX: number,
	localZ: number,
	sizeScale: number,
	hatchDuration: number,
	lastRelScale: number,
	originSource: string?,
	unlockAt: number,
	rarity: Types.AnimalRarity,
	statusLabel: TextLabel,
	prompt: ProximityPrompt?,
	phase: number,
}

local function isClientInstantUnbox(isOwnPlot: boolean): boolean
	return Workspace:GetAttribute("InstantUnboxParty") == true
		or (isOwnPlot and localPlayer:GetAttribute("AdminInstantUnbox") == true)
end

local currentPlotsPayload: any = {}
local currentSettings: Types.PlayerSettings = GameConfig.DEFAULT_SETTINGS
local activeEntities: { RoamingEntity } = {}
local activeEntitiesByUid: { [string]: RoamingEntity } = {}
local activePlacedCrates: { PlacedCrateVisual } = {}
local activeCratesByUid: { [string]: PlacedCrateVisual } = {}
local rainbowParts: { BasePart } = {}
local delayedAnimalUids: { [string]: boolean } = {}
local lastAnimalHideSig = ""

local function clearAllEntities()
	for _, ent in ipairs(activeEntities) do
		if ent.model then
			ent.model:Destroy()
		end
	end
	for _, cr in ipairs(activePlacedCrates) do
		if cr.model then
			cr.model:Destroy()
		end
	end
	table.clear(activeEntities)
	table.clear(activeEntitiesByUid)
	table.clear(activePlacedCrates)
	table.clear(activeCratesByUid)
	table.clear(rainbowParts)
end

local terrainGroundRayParams = RaycastParams.new()
terrainGroundRayParams.FilterType = Enum.RaycastFilterType.Include
terrainGroundRayParams.FilterDescendantsInstances = { Workspace.Terrain }

local function randomLocalPaddockPos(paddockTopY: number?): Vector3
	local topY = paddockTopY or 0.04
	return Vector3.new(math.random(-20, 20), topY, math.random(-13, 13))
end

local function computeEntityGroundCFrame(paddockCF: CFrame, localX: number, topY: number, localZ: number, hopY: number, yaw: number, footBotRel: number): CFrame
	local basePos = (paddockCF * CFrame.new(localX, topY, localZ)).Position
	local hit = Workspace:Raycast(basePos + Vector3.new(0, 12, 0), Vector3.new(0, -16, 0), terrainGroundRayParams)
	local surfaceY = if hit and hit.Position.Y > basePos.Y then hit.Position.Y else basePos.Y
	local rotOnly = paddockCF - paddockCF.Position
	return CFrame.new(basePos.X, surfaceY + hopY - footBotRel, basePos.Z) * rotOnly * CFrame.Angles(0, yaw, 0)
end

-- Deterministic 6x5 grid across the 52x36 OpenPaddockFloor supporting up to 30 hatching crates neatly
local function computePenCrateSlotLocalPos(slotIndex: number, localX: number?, localZ: number?, paddockTopY: number?): Vector3
	local topY = paddockTopY or 0.04
	if type(localX) == "number" and type(localZ) == "number" then
		return Vector3.new(math.clamp(localX, -22.5, 22.5), topY, math.clamp(localZ, -14.5, 14.5))
	end
	local idx0 = math.clamp(slotIndex - 1, 0, GameConfig.PEN.MAX_PLACED_CRATES - 1)
	local col = idx0 % 6
	local row = math.floor(idx0 / 6)
	local x = -20 + col * 8.0
	local z = -10 + row * 6.0
	return Vector3.new(x, topY, z)
end

local function rebuildEntities(forceReset: boolean?)
	local hideSig = tostring(currentSettings.hideOwnAnimals) .. "|" .. tostring(currentSettings.hideOtherAnimals) .. "|" .. tostring(currentSettings.lowVFX)
	if forceReset or hideSig ~= lastAnimalHideSig then
		lastAnimalHideSig = hideSig
		clearAllEntities()
	end

	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local plotsFolder = if hub then hub:FindFirstChild("Plots") else nil
	if not plotsFolder then return end

	local entitiesRoot = gw:FindFirstChild("ClientRoamingAnimals")
	if not entitiesRoot then
		entitiesRoot = Instance.new("Folder")
		entitiesRoot.Name = "ClientRoamingAnimals"
		entitiesRoot.Parent = gw
	end

	local wantedAnimalUids: { [string]: boolean } = {}
	local wantedCrateUids: { [string]: boolean } = {}

	for _, plotData in pairs(currentPlotsPayload) do
		local isOwn = (plotData.ownerUserId == localPlayer.UserId)
		local shouldHideAnimals = (isOwn and currentSettings.hideOwnAnimals) or ((not isOwn) and currentSettings.hideOtherAnimals)

		if plotData.ownerUserId ~= 0 then
			local plotModel = plotsFolder:FindFirstChild("Plot_" .. tostring(plotData.plotIndex))
			local paddock = if plotModel then plotModel:FindFirstChild("OpenPaddockFloor") else nil
			if paddock and paddock:IsA("BasePart") then
				local paddockCF = paddock.CFrame
				local paddockTopY = paddock.Size.Y * 0.5

				-- 1. Diff/Preserve Roaming Animals inside Paddock (Equip Best NEVER resets existing pets!)
				if not shouldHideAnimals and type(plotData.roamingAnimals) == "table" then
					for idx, animal in ipairs(plotData.roamingAnimals) do
						if not delayedAnimalUids[animal.uid] then
							wantedAnimalUids[animal.uid] = true
							local existing = activeEntitiesByUid[animal.uid]
							if existing and existing.model and existing.model.Parent and existing.plotIndex == plotData.plotIndex then
								existing.paddockCF = paddockCF
								existing.topY = paddockTopY
							else
								if existing and existing.model then
									existing.model:Destroy()
								end
								local titanicActive = Workspace:GetAttribute("TitanicZooActive") == true
								local visualSizeRatio = if titanicActive then math.max(animal.sizeRatio * 2.1, 2.8) else animal.sizeRatio
								local model = AnimalVisualBuilder.BuildAnimalModel(animal.speciesId, visualSizeRatio, animal.mutation, currentSettings.lowVFX)
								model.Name = string.format("P%d_%s_%s", plotData.plotIndex, animal.speciesId, string.sub(animal.uid, 1, 6))

								local root = model.PrimaryPart :: BasePart
								local spec = AnimalConfig.GetById(animal.speciesId)
								local bb = Instance.new("BillboardGui")
								bb.Size = UDim2.fromOffset(170, 44)
								bb.StudsOffset = Vector3.new(0, 3.6 * visualSizeRatio, 0)
								bb.MaxDistance = 65
								bb.Parent = root

								local lbl = Instance.new("TextLabel")
								lbl.Size = UDim2.fromScale(1, 1)
								lbl.BackgroundTransparency = 1
								local mutPrefix = if animal.mutation ~= "None" then ("[" .. animal.mutation .. "] ") else ""
								local inc = AnimalConfig.ComputeIncomePerSec(animal)
								lbl.Text = string.format("%s%s (%.2fx)\n$%s/s", mutPrefix, spec and spec.name or animal.speciesId, animal.sizeRatio, FormatUtil.Number(inc))
								lbl.TextColor3 = (GameConfig.MUTATIONS[animal.mutation] and GameConfig.MUTATIONS[animal.mutation].color) or Color3.new(1, 1, 1)
								lbl.Font = Enum.Font.FredokaOne
								lbl.TextScaled = true
								lbl.Parent = bb
								local lblSt = Instance.new("UIStroke")
								lblSt.Thickness = 2.6
								lblSt.Color = Color3.fromRGB(10, 12, 16)
								lblSt.Parent = lbl
								if spec and GameConfig.IsCosmicOrAbove(spec.rarity) then
									RarityEffects.ApplyTextEffect(lbl, spec.rarity)
								end

								local footBotRel = AnimalVisualBuilder.GetModelVerticalBounds(model)
								local startLocal = randomLocalPaddockPos(paddockTopY)
								local initYaw = math.random() * math.pi * 2
								model:PivotTo(computeEntityGroundCFrame(paddockCF, startLocal.X, paddockTopY, startLocal.Z, 0, initYaw, footBotRel))
								model.Parent = entitiesRoot

								local entOrbits: { { part: BasePart, radius: number, phase: number, y: number } } = {}
								for _, d in ipairs(model:GetDescendants()) do
									if d:IsA("BasePart") then
										if animal.mutation == "Rainbow" and d.Name ~= "Eye" then
											table.insert(rainbowParts, d)
										end
										if d:GetAttribute("OrbitRing") == true then
											table.insert(entOrbits, {
												part = d,
												radius = tonumber(d:GetAttribute("OrbitRadius")) or 1.8,
												phase = tonumber(d:GetAttribute("OrbitPhase")) or 0,
												y = tonumber(d:GetAttribute("OrbitY")) or 2.2,
											})
										end
									end
								end

								local newEnt: RoamingEntity = {
									uid = animal.uid,
									plotIndex = plotData.plotIndex,
									model = model,
									isRainbow = (animal.mutation == "Rainbow"),
									isScrambled = (animal.mutation == "Scrambled"),
									orbitParts = entOrbits,
									pos = startLocal,
									targetPos = randomLocalPaddockPos(paddockTopY),
									yaw = initYaw,
									speed = math.random(4, 7),
									waitUntil = os.clock() + (idx * 0.2),
									phase = idx * 0.9,
									paddockCF = paddockCF,
									topY = paddockTopY,
									footBotRel = footBotRel,
								}
								activeEntitiesByUid[animal.uid] = newEnt
								table.insert(activeEntities, newEnt)
							end
						end
					end
				end

				-- 2. Diff/Preserve Up to 30 Hatching Crates Physically Inside Open Paddock
				if type(plotData.pendingCrates) == "table" then
					local nowUnix = os.time()
					for idx, crate in ipairs(plotData.pendingCrates) do
						wantedCrateUids[crate.uid] = true
						local existingCr = activeCratesByUid[crate.uid]
						if existingCr and existingCr.model and existingCr.model.Parent and existingCr.plotIndex == plotData.plotIndex then
							existingCr.unlockAt = crate.unlockAt or nowUnix
						else
							if existingCr and existingCr.model then
								existingCr.model:Destroy()
							end
							local slotIdx = tonumber(crate.placedSlot) or idx
							local sc = tonumber(crate.sizeScale) or GameConfig.ComputeCrateScale(crate.rarity)
							local crateSpec = AnimalConfig.GetById(crate.speciesId)
							local variantIdx = if crateSpec then ((crateSpec.indexNumber % 3) + 1) else ((slotIdx % 3) + 1)
							local crateTitle = AnimalVisualBuilder.GetCrateVariantInfo(crate.biomeId, crate.rarity, variantIdx)
							local crateModel = AnimalVisualBuilder.BuildCrateModel(crate.rarity, crate.biomeId, sc, {
								isBuried = false,
								canCollide = false,
								showBeacon = false,
								variant = variantIdx,
							})
							crateModel.Name = string.format("PenCrate_%d_%s", slotIdx, string.sub(crate.uid, 1, 6))

							local localPos = computePenCrateSlotLocalPos(slotIdx, crate.localX, crate.localZ, paddockTopY)
							local yaw = ((slotIdx * 37) % 360) * math.pi / 180
							local baseCF = paddockCF * CFrame.new(localPos) * CFrame.Angles(0, yaw, 0)
							crateModel:PivotTo(baseCF)

							local cRoot = crateModel.PrimaryPart :: BasePart
							cRoot.CanQuery = true

							local rarityCol = GameConfig.RARITY_COLORS[crate.rarity] or Color3.new(1, 1, 1)
							local bb = Instance.new("BillboardGui")
							bb.Size = UDim2.fromOffset(182, 52)
							bb.StudsOffset = Vector3.new(0, 3.6 * sc + 1.4, 0)
							bb.MaxDistance = 75
							bb.Parent = cRoot

							-- Clean 2-line floating text (Image 11 style: Crate Name + Rarity/Status, NO dark box!)
							local topLbl = Instance.new("TextLabel")
							topLbl.Size = UDim2.new(1, -4, 0.48, 0)
							topLbl.Position = UDim2.fromOffset(2, 2)
							topLbl.BackgroundTransparency = 1
							local mergePrefix = if crate.originSource == "Merge" then "⚡ MERGED " else ""
							topLbl.Text = string.format("%s%s (%s)", mergePrefix, crateTitle, crate.rarity)
							topLbl.TextColor3 = if crate.originSource == "Merge" then Color3.fromRGB(118, 240, 255) else rarityCol
							topLbl.Font = Enum.Font.FredokaOne
							topLbl.TextScaled = true
							topLbl.Parent = bb
							local topSt = Instance.new("UIStroke")
							topSt.Thickness = 2.5
							topSt.Color = Color3.fromRGB(10, 12, 16)
							topSt.Parent = topLbl
							RarityEffects.ApplyTextEffect(topLbl, crate.rarity)

							local srvNow = math.floor(Workspace:GetServerTimeNow())
							local rem = math.max(0, (crate.unlockAt or 0) - srvNow)
							local hDur = math.max(1, tonumber(crate.hatchDuration) or GameConfig.ComputeHatchSeconds(crate.rarity, crate.biomeId))
							local initProg = math.clamp(1 - (rem / hDur), 0, 1)
							local initRelScale = 0.72 + initProg * 0.34
							pcall(function()
								crateModel:ScaleTo(initRelScale)
							end)
							local instantNow = isClientInstantUnbox(isOwn)
							local statLbl = Instance.new("TextLabel")
							statLbl.Size = UDim2.new(1, -4, 0.48, 0)
							statLbl.Position = UDim2.new(0, 2, 0.50, 0)
							statLbl.BackgroundTransparency = 1
							statLbl.Text = if rem > 0 and instantNow then "⚡ INSTANT UNBOX! [E]" elseif rem > 0 then ("⏳ Hatch: " .. FormatUtil.Time(rem)) else "✨ READY! Click / [E]"
							statLbl.TextColor3 = if rem > 0 and instantNow then Color3.fromRGB(56, 224, 255) elseif rem > 0 then Color3.fromRGB(255, 224, 96) else Color3.fromRGB(108, 255, 132)
							statLbl.Font = Enum.Font.FredokaOne
							statLbl.TextScaled = true
							statLbl.Parent = bb
							local statSt = Instance.new("UIStroke")
							statSt.Thickness = 2.5
							statSt.Color = Color3.fromRGB(10, 12, 16)
							statSt.Parent = statLbl

							local hatchPrompt: ProximityPrompt? = nil
							if isOwn then
								local cd = Instance.new("ClickDetector")
								cd.MaxActivationDistance = 24
								cd.Parent = cRoot
								cd.MouseClick:Connect(function()
									Remotes.Get("OpenPendingCrate"):FireServer(crate.uid)
								end)

								local p = Instance.new("ProximityPrompt")
								p.Name = "HatchPenCratePrompt"
								p.ActionText = if rem > 0 and instantNow then "⚡ Instant Unbox!" elseif rem > 0 then ("Hatching (" .. FormatUtil.Time(rem) .. ")") else "Hatch / Open Crate"
								p.ObjectText = string.upper(crate.rarity) .. " " .. crate.biomeId .. " Crate"
								p.HoldDuration = 0
								p.MaxActivationDistance = 12
								p.RequiresLineOfSight = false
								p.Parent = cRoot
								p.Triggered:Connect(function()
									Remotes.Get("OpenPendingCrate"):FireServer(crate.uid)
								end)
								hatchPrompt = p
							end

							crateModel.Parent = entitiesRoot
							local newCr: PlacedCrateVisual = {
								uid = crate.uid,
								plotIndex = plotData.plotIndex,
								isOwn = isOwn,
								model = crateModel,
								baseCF = baseCF,
								localX = localPos.X,
								localZ = localPos.Z,
								sizeScale = sc,
								hatchDuration = hDur,
								lastRelScale = initRelScale,
								originSource = crate.originSource,
								unlockAt = crate.unlockAt or srvNow,
								rarity = crate.rarity,
								statusLabel = statLbl,
								prompt = hatchPrompt,
								phase = slotIdx * 0.7,
							}
							activeCratesByUid[crate.uid] = newCr
							table.insert(activePlacedCrates, newCr)
						end
					end
				end
			end
		end
	end

	-- Remove only animals or crates that are no longer active
	for i = #activeEntities, 1, -1 do
		local ent = activeEntities[i]
		if not wantedAnimalUids[ent.uid] then
			if ent.model then
				ent.model:Destroy()
			end
			activeEntitiesByUid[ent.uid] = nil
			table.remove(activeEntities, i)
		end
	end
	for i = #activePlacedCrates, 1, -1 do
		local cr = activePlacedCrates[i]
		if not wantedCrateUids[cr.uid] then
			if cr.model then
				cr.model:Destroy()
			end
			activeCratesByUid[cr.uid] = nil
			table.remove(activePlacedCrates, i)
		end
	end
	for i = #rainbowParts, 1, -1 do
		if not rainbowParts[i].Parent then
			table.remove(rainbowParts, i)
		end
	end
end

-- ============================================================================
-- PLOT PRIVACY VISIBILITY (#2 Hide Other Treadmills Unless Active, #3 Hide Other Upgrade Boards)
-- ============================================================================
local function setInstSubtreeVisible(inst: Instance?, visible: boolean, allowPrompt: boolean)
	if not inst then return end
	if inst:IsA("BasePart") then
		if inst:GetAttribute("_OrigTrans") == nil then
			inst:SetAttribute("_OrigTrans", inst.Transparency)
		end
		inst.Transparency = if visible then (tonumber(inst:GetAttribute("_OrigTrans")) or 0) else 1
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute("_OrigTrans") == nil then
				d:SetAttribute("_OrigTrans", d.Transparency)
			end
			d.Transparency = if visible then (tonumber(d:GetAttribute("_OrigTrans")) or 0) else 1
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = visible
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = allowPrompt
		elseif d:IsA("ClickDetector") then
			d.MaxActivationDistance = if allowPrompt then 24 else 0
		end
	end
end

local function updatePlotPrivacyVisuals()
	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local plotsFolder = if hub then hub:FindFirstChild("Plots") else nil
	if not plotsFolder then return end

	for _, plotModel in ipairs(plotsFolder:GetChildren()) do
		if plotModel:IsA("Model") then
			local ownerId = tonumber(plotModel:GetAttribute("OwnerUserId")) or 0
			local isMine = (ownerId == localPlayer.UserId)
			local ownerPlr = if ownerId > 0 then Players:GetPlayerByUserId(ownerId) else nil
			local ownerOnTread = (ownerPlr ~= nil and ownerPlr:GetAttribute("OnTreadmill") == true)

			-- #2 Treadmill invisible on other plots unless owner is actively using it!
			local treadVis = plotModel:FindFirstChild("TreadmillVisual")
			setInstSubtreeVisible(treadVis, isMine or ownerOnTread, false)

			-- Show "+X/Step" floating Treadmill badge cleanly for plot owner only (Image 2)
			local treadAnchor = plotModel:FindFirstChild("TreadmillStandAnchor")
			local stepBadge = if treadAnchor then treadAnchor:FindFirstChild("TreadmillStepBadge") else nil
			if stepBadge and stepBadge:IsA("BillboardGui") then
				stepBadge.Enabled = isMine
				local valLbl = stepBadge:FindFirstChild("ValueLabel")
				if valLbl and valLbl:IsA("TextLabel") and isMine then
					local stepVal = tonumber(localPlayer:GetAttribute("StepGainPerPulse")) or 1
					valLbl.Text = "👟 +" .. FormatUtil.Number(stepVal) .. "/Step"
				end
			end

			-- #3 Pen & Treadmill Upgrade Boards + Other Players' Cash Collector Pads hidden & non-interactive!
			for _, boardName in ipairs({
				"PenUpgradeBoard", "PenUpgradeBoard_Post", "PenUpgradeBoard_WoodBase",
				"TreadmillUpgradeBoard", "TreadmillUpgradeBoard_Post", "TreadmillUpgradeBoard_WoodBase",
				"CashCollectorPad", "CashCollectorPad_Plinth", "CashCollectorPad_NeonRim", "CashCollectorPad_Halo",
				"CashCollectorPad_Corner_1", "CashCollectorPad_Corner_2", "CashCollectorPad_Corner_3", "CashCollectorPad_Corner_4",
				"CashCollectorPad_CornerGlow_1", "CashCollectorPad_CornerGlow_2", "CashCollectorPad_CornerGlow_3", "CashCollectorPad_CornerGlow_4",
			}) do
				setInstSubtreeVisible(plotModel:FindFirstChild(boardName), isMine, isMine)
			end

			-- #5 Floating Owner Headshot + @username above Cage (BillboardGui always faces camera from every angle!)
			local paddock = plotModel:FindFirstChild("OpenPaddockFloor")
			if paddock and paddock:IsA("BasePart") then
				local badgeAnchor = plotModel:FindFirstChild("OwnerCageBadgeAnchor")
				if not badgeAnchor then
					local p = Instance.new("Part")
					p.Name = "OwnerCageBadgeAnchor"
					p.Size = Vector3.new(1, 1, 1)
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					p.Transparency = 1
					p.CFrame = CFrame.new(paddock.Position + Vector3.new(0, 12.5, 0))
					p.Parent = plotModel

					local bb = Instance.new("BillboardGui")
					bb.Name = "OwnerBadgeGui"
					bb.Size = UDim2.fromOffset(172, 124)
					bb.AlwaysOnTop = false
					bb.Active = false
					bb.MaxDistance = 320
					bb.Parent = p

					local avatarImg = Instance.new("ImageLabel")
					avatarImg.Name = "AvatarHeadshot"
					avatarImg.Size = UDim2.fromOffset(82, 82)
					avatarImg.AnchorPoint = Vector2.new(0.5, 0)
					avatarImg.Position = UDim2.new(0.5, 0, 0, 2)
					avatarImg.BackgroundTransparency = 1
					avatarImg.Parent = bb

					local nameLbl = Instance.new("TextLabel")
					nameLbl.Name = "UsernameLabel"
					nameLbl.Size = UDim2.new(1, -4, 0, 32)
					nameLbl.Position = UDim2.fromOffset(2, 88)
					nameLbl.BackgroundTransparency = 1
					nameLbl.TextColor3 = Color3.new(1, 1, 1)
					nameLbl.Font = Enum.Font.FredokaOne
					nameLbl.TextScaled = true
					nameLbl.Parent = bb
					local st = Instance.new("UIStroke")
					st.Thickness = 2.8
					st.Color = Color3.fromRGB(10, 12, 16)
					st.Parent = nameLbl

					badgeAnchor = p
				end

				local bb = badgeAnchor:FindFirstChild("OwnerBadgeGui") :: BillboardGui?
				if bb then
					if ownerId > 0 then
						local pIdxStr = tostring(plotModel:GetAttribute("PlotIndex") or "")
						local pSync = currentPlotsPayload and currentPlotsPayload[pIdxStr]
						local uname = tostring(plotModel:GetAttribute("OwnerUsername") or "")
						if uname == "" and ownerPlr then
							uname = ownerPlr.Name
						elseif uname == "" and pSync and type(pSync.ownerUsername) == "string" and pSync.ownerUsername ~= "" then
							uname = pSync.ownerUsername
						elseif uname == "" and pSync and type(pSync.ownerName) == "string" then
							uname = pSync.ownerName
						end
						if uname == "" then
							uname = "Player_" .. tostring(ownerId)
						end
						local avatarImg = bb:FindFirstChild("AvatarHeadshot") :: ImageLabel?
						local nameLbl = bb:FindFirstChild("UsernameLabel") :: TextLabel?
						if avatarImg then
							avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", ownerId)
						end
						if nameLbl then
							nameLbl.Text = "@" .. uname
						end
						bb.Enabled = true
					else
						bb.Enabled = false
					end
				end
			end
		end
	end
end

local function bindPlayerPrivacySignals(p: Player)
	p:GetAttributeChangedSignal("OnTreadmill"):Connect(updatePlotPrivacyVisuals)
	if p == localPlayer then
		p:GetAttributeChangedSignal("StepGainPerPulse"):Connect(updatePlotPrivacyVisuals)
	end
end
for _, p in ipairs(Players:GetPlayers()) do
	bindPlayerPrivacySignals(p)
end
Players.PlayerAdded:Connect(bindPlayerPrivacySignals)
Players.PlayerRemoving:Connect(function()
	task.defer(updatePlotPrivacyVisuals)
end)

task.spawn(function()
	local gw = Workspace:WaitForChild("GameWorld", 12)
	local hub = if gw then gw:WaitForChild("SanctuaryHub", 12) else nil
	local plotsFolder = if hub then hub:WaitForChild("Plots", 12) else nil
	if plotsFolder then
		for _, plotModel in ipairs(plotsFolder:GetChildren()) do
			plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(updatePlotPrivacyVisuals)
			plotModel:GetAttributeChangedSignal("AppliedTreadTier"):Connect(function()
				task.defer(updatePlotPrivacyVisuals)
			end)
			plotModel.ChildAdded:Connect(function(ch)
				if ch.Name == "TreadmillVisual" or string.find(ch.Name, "UpgradeBoard") or string.find(ch.Name, "CashCollectorPad") then
					task.defer(updatePlotPrivacyVisuals)
				end
			end)
		end
		updatePlotPrivacyVisuals()
	end
end)

-- ============================================================================
-- TIERED CINEMATIC HATCH REVEAL (#4, #6, #7 + Biome/Rarity VFX)
-- ============================================================================
Remotes.Get("CrateHatchReveal").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local plotsFolder = if hub then hub:FindFirstChild("Plots") else nil
	local plotModel = if plotsFolder then plotsFolder:FindFirstChild("Plot_" .. tostring(data.plotIndex or 1)) else nil
	local paddock = if plotModel then plotModel:FindFirstChild("OpenPaddockFloor") else nil
	if not paddock or not paddock:IsA("BasePart") then return end

	if type(data.animalUid) == "string" then
		delayedAnimalUids[data.animalUid] = true
	end

	local sc = tonumber(data.sizeScale) or GameConfig.ComputeCrateScale(tostring(data.rarity or "Common"))
	local slotIdx = tonumber(data.placedSlot) or 1
	local localPos = computePenCrateSlotLocalPos(slotIdx, data.localX, data.localZ, paddock.Size.Y * 0.5)
	local baseCF = paddock.CFrame * CFrame.new(localPos)

	local openerUid = tonumber(data.openerUserId)
	local openerPlayer = if openerUid then Players:GetPlayerByUserId(openerUid) else localPlayer
	local isLocalOpener = (openerUid == nil or openerUid == localPlayer.UserId)

	CinematicVFX.PlayCrateHatchSequence({
		baseCF = baseCF,
		rarity = tostring(data.rarity or "Common"),
		biomeId = tostring(data.biomeId or "PineWoods"),
		sizeScale = sc,
		speciesId = tostring(data.speciesId or "RustyFox"),
		mutation = tostring(data.mutation or "None"),
		sizeRatio = tonumber(data.sizeRatio) or 1.0,
		weightKg = tonumber(data.weightKg) or 5.0,
		oddsDenom = tonumber(data.oddsDenom),
		openerPlayer = openerPlayer,
		isLocalOpener = isLocalOpener,
		lowVFX = (currentSettings.lowVFX == true),
		playerGui = localPlayer:FindFirstChildOfClass("PlayerGui"),
		onComplete = function()
			if type(data.animalUid) == "string" then
				delayedAnimalUids[data.animalUid] = nil
				rebuildEntities(false)
			end
		end,
	})
end)

-- ============================================================================
-- INTERACTIVE PEN PLACEMENT GHOST + SPACE VALIDATOR FOR CRATES & PETS (#8)
-- ============================================================================
local placementGhost: Part? = nil
local placementRayParams = RaycastParams.new()
placementRayParams.FilterType = Enum.RaycastFilterType.Include

local function destroyPlacementGhost()
	if placementGhost then
		placementGhost:Destroy()
		placementGhost = nil
	end
end

local function evaluatePenPlacement(): (boolean, number, number, Vector3?, BasePart?)
	local hType = tostring(localPlayer:GetAttribute("HeldItemType") or "")
	if hType ~= "Crate" and hType ~= "Pet" then
		return false, 0, 0, nil, nil
	end
	local gw = Workspace:FindFirstChild("GameWorld")
	local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
	local plotsFolder = if hub then hub:FindFirstChild("Plots") else nil
	if not plotsFolder then return false, 0, 0, nil, nil end

	local myPaddock: BasePart? = nil
	local myPlotIdx = 0
	for _, pm in ipairs(plotsFolder:GetChildren()) do
		if pm:IsA("Model") and pm:GetAttribute("OwnerUserId") == localPlayer.UserId then
			local pd = pm:FindFirstChild("OpenPaddockFloor")
			if pd and pd:IsA("BasePart") then
				myPaddock = pd
				myPlotIdx = tonumber(pm:GetAttribute("PlotIndex")) or 0
				break
			end
		end
	end
	if not myPaddock then
		return false, 0, 0, nil, nil
	end

	local cam = Workspace.CurrentCamera
	if not cam then return false, 0, 0, nil, nil end
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
	placementRayParams.FilterDescendantsInstances = { myPaddock }
	local res = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 220, placementRayParams)
	if not res or res.Instance ~= myPaddock then
		return false, 0, 0, nil, myPaddock
	end

	local rel = myPaddock.CFrame:PointToObjectSpace(res.Position)
	local lx = math.clamp(rel.X, -22.5, 22.5)
	local lz = math.clamp(rel.Z, -14.5, 14.5)
	local valid = true

	if hType == "Crate" then
		local newScale = tonumber(localPlayer:GetAttribute("HeldItemScale")) or 1.0
		local cnt = 0
		for _, cr in ipairs(activePlacedCrates) do
			if cr.plotIndex == myPlotIdx then
				cnt += 1
				local reqDist = 2.8 + (newScale + cr.sizeScale) * 2.1
				local dx = lx - cr.localX
				local dz = lz - cr.localZ
				if math.sqrt(dx * dx + dz * dz) < reqDist then
					valid = false
					break
				end
			end
		end
		if cnt >= GameConfig.PEN.MAX_PLACED_CRATES then
			valid = false
		end
	end

	local snapWorld = (myPaddock.CFrame * CFrame.new(lx, myPaddock.Size.Y * 0.5 + 0.1, lz)).Position
	return valid, lx, lz, snapWorld, myPaddock
end

UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
		local hType = tostring(localPlayer:GetAttribute("HeldItemType") or "")
		if hType ~= "Crate" and hType ~= "Pet" then return end
		local heldId = tostring(localPlayer:GetAttribute("HeldItemId") or "")
		if heldId == "" then return end
		local valid, lx, lz, snapPos = evaluatePenPlacement()
		if not snapPos then return end
		if hType == "Crate" then
			if not valid then
				localPlayer:SetAttribute("ClientToastSeq", (tonumber(localPlayer:GetAttribute("ClientToastSeq")) or 0) + 1)
				localPlayer:SetAttribute("ClientToastText", "Need more space between crates in your Pen!")
				return
			end
			Remotes.Get("PlaceCrateInPen"):FireServer(heldId, lx, lz)
			localPlayer:SetAttribute("ClearHeldSlotRequest", not (localPlayer:GetAttribute("ClearHeldSlotRequest") == true))
		elseif hType == "Pet" then
			Remotes.Get("PlacePetInPen"):FireServer(heldId, lx, lz)
			localPlayer:SetAttribute("ClearHeldSlotRequest", not (localPlayer:GetAttribute("ClearHeldSlotRequest") == true))
		end
	end
end)

Remotes.Get("AllPlotsSync").OnClientEvent:Connect(function(payload)
	currentPlotsPayload = payload or {}
	rebuildEntities(false)
	updatePlotPrivacyVisuals()
end)

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and type(profile.settings) == "table" then
		local changed = (currentSettings.hideOtherAnimals ~= profile.settings.hideOtherAnimals)
			or (currentSettings.hideOwnAnimals ~= profile.settings.hideOwnAnimals)
			or (currentSettings.lowVFX ~= profile.settings.lowVFX)
		currentSettings = profile.settings
		if changed then
			rebuildEntities(true)
		end
	end
end)

Workspace:GetAttributeChangedSignal("TitanicZooActive"):Connect(function()
	rebuildEntities(true)
end)

local activeCrateBaseCF: { [Model]: CFrame } = {}
local timerAccum = 0

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	timerAccum += dt
	local refreshTimers = timerAccum >= 0.35
	if refreshTimers then
		timerAccum = 0
	end

	-- Update Pen Placement Ghost Disc when holding a Crate or Pet in hand
	local hType = tostring(localPlayer:GetAttribute("HeldItemType") or "")
	if hType == "Crate" or hType == "Pet" then
		local valid, _, _, snapWorld = evaluatePenPlacement()
		if snapWorld then
			if not placementGhost then
				local g = Instance.new("Part")
				g.Name = "PenPlacementGhostRing"
				g.Shape = Enum.PartType.Cylinder
				g.Material = Enum.Material.Neon
				g.Transparency = 0.45
				g.Anchored = true
				g.CanCollide = false
				g.CanQuery = false
				g.CanTouch = false
				g.CastShadow = false
				g.Parent = Workspace
				placementGhost = g
			end
			local sc = if hType == "Crate" then (tonumber(localPlayer:GetAttribute("HeldItemScale")) or 1.0) else 0.75
			local diam = 5.4 * sc + 1.2
			local pg = placementGhost :: Part
			pg.Size = Vector3.new(0.25, diam, diam)
			pg.Color = if valid then Color3.fromRGB(72, 255, 118) else Color3.fromRGB(255, 68, 68)
			pg.CFrame = CFrame.new(snapWorld + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi * 0.5)
		else
			destroyPlacementGhost()
		end
	elseif placementGhost then
		destroyPlacementGhost()
	end

	-- Update Placed Crates inside Pens (hatch countdown + gradual Steal-an-Egg growth + egg wiggle)
	if #activePlacedCrates > 0 then
		local nowUnix = math.floor(Workspace:GetServerTimeNow())
		for _, cr in ipairs(activePlacedCrates) do
			if cr.model and cr.model.Parent then
				local rem = math.max(0, cr.unlockAt - nowUnix)
				local prog = if cr.hatchDuration > 0 then math.clamp(1 - (rem / cr.hatchDuration), 0, 1) else 1
				local targetRelScale = 0.72 + prog * 0.34
				if math.abs(targetRelScale - cr.lastRelScale) >= 0.015 then
					cr.lastRelScale = targetRelScale
					pcall(function()
						cr.model:ScaleTo(targetRelScale)
					end)
				end
				if refreshTimers then
					local instantNow = isClientInstantUnbox(cr.isOwn)
					if rem > 0 and instantNow then
						cr.statusLabel.Text = "⚡ INSTANT UNBOX! [E]"
						cr.statusLabel.TextColor3 = Color3.fromRGB(56, 224, 255)
						if cr.prompt then
							cr.prompt.ActionText = "⚡ Instant Unbox!"
						end
					elseif rem > 0 then
						cr.statusLabel.Text = "⏳ Hatch: " .. FormatUtil.Time(rem)
						cr.statusLabel.TextColor3 = Color3.fromRGB(255, 224, 96)
						if cr.prompt then
							cr.prompt.ActionText = "Hatching (" .. FormatUtil.Time(rem) .. ")"
						end
					else
						cr.statusLabel.Text = "✨ READY! Click / [E]"
						cr.statusLabel.TextColor3 = Color3.fromRGB(108, 255, 132)
						if cr.prompt then
							cr.prompt.ActionText = "Hatch / Open Crate"
						end
					end
				end

				if not currentSettings.lowVFX then
					if rem <= 0 then
						local jump = math.abs(math.sin(now * 6.5 + cr.phase)) * 0.45
						local wob = math.sin(now * 14 + cr.phase) * 0.11
						cr.model:PivotTo(cr.baseCF * CFrame.new(0, jump, 0) * CFrame.Angles(wob, 0, wob * 0.7))
					else
						local pulse = (now + cr.phase) % 2.6
						if pulse < 0.35 then
							local wob = math.sin(pulse * 26) * 0.08
							cr.model:PivotTo(cr.baseCF * CFrame.Angles(0, 0, wob))
						else
							cr.model:PivotTo(cr.baseCF)
						end
					end
				end
			end
		end
	end

	-- Subtle periodic struggle animation on nearby wild buried crates (when graphics quality is not Low)
	if (currentSettings :: any).graphicsQuality ~= "Low" and not currentSettings.lowVFX then
		local gw = Workspace:FindFirstChild("GameWorld")
		local cratesFolder = if gw then gw:FindFirstChild("ActiveCrates") else nil
		if cratesFolder then
			local cam = Workspace.CurrentCamera
			local camPos = if cam then cam.CFrame.Position else Vector3.zero
			for _, cr in ipairs(cratesFolder:GetChildren()) do
				if cr:IsA("Model") and cr.PrimaryPart then
					if not activeCrateBaseCF[cr] then
						activeCrateBaseCF[cr] = cr:GetPivot()
					end
					local baseCF = activeCrateBaseCF[cr]
					if (baseCF.Position - camPos).Magnitude < 130 then
						local cycle = (now + math.abs(baseCF.Position.X) * 0.13) % 3.2
						if cycle < 0.45 then
							local wob = math.sin(cycle * 28) * 0.12
							cr:PivotTo(baseCF * CFrame.Angles(wob, 0, wob * 0.8))
						else
							cr:PivotTo(baseCF)
						end
					end
				end
			end
			for m in pairs(activeCrateBaseCF) do
				if not m.Parent then
					activeCrateBaseCF[m] = nil
				end
			end
		end
	end

	if #activeEntities == 0 then return end

	if #rainbowParts > 0 then
		local hueCol = Color3.fromHSV((now * 0.35) % 1, 0.85, 1)
		for _, p in ipairs(rainbowParts) do
			if p.Parent then
				p.Color = hueCol
			end
		end
	end

	for _, ent in ipairs(activeEntities) do
		if ent.model and ent.model.Parent then
			local delta = ent.targetPos - ent.pos
			local horiz = Vector3.new(delta.X, 0, delta.Z)
			local dist = horiz.Magnitude

			local isVoxelRig = (ent.model:GetAttribute("VoxelRig") == true)
			local isMoving = false
			local hopY = 0
			if now >= ent.waitUntil and dist > 0.6 then
				isMoving = true
				local step = math.min(dist, ent.speed * dt)
				local dir = horiz.Unit
				ent.pos += dir * step
				ent.yaw = math.atan2(-dir.X, -dir.Z)
				hopY = if isVoxelRig then 0 else math.abs(math.sin(now * 9 + ent.phase)) * 0.55
			elseif dist <= 0.6 then
				ent.waitUntil = now + math.random(10, 28) / 10
				ent.targetPos = randomLocalPaddockPos(ent.topY)
			else
				hopY = if isVoxelRig then 0 else math.abs(math.sin(now * 3 + ent.phase)) * 0.05
			end

			if isVoxelRig then
				VoxelPets.StepRig(ent.model, if isMoving then "Walk" else "Idle", now, ent.phase)
			end

			local worldCF = computeEntityGroundCFrame(ent.paddockCF, ent.pos.X, ent.topY, ent.pos.Z, hopY, ent.yaw, ent.footBotRel)
			if ent.isScrambled and not currentSettings.lowVFX then
				worldCF = worldCF * CFrame.new(math.sin(now * 38 + ent.phase) * 0.08, 0, math.cos(now * 43) * 0.08)
			end
			ent.model:PivotTo(worldCF)
			if #ent.orbitParts > 0 and not currentSettings.lowVFX then
				local basePiv = worldCF
				for _, orb in ipairs(ent.orbitParts) do
					if orb.part.Parent then
						local a = orb.phase + now * 2.2
						local bob = math.sin(now * 3.4 + orb.phase) * 0.22
						orb.part.CFrame = basePiv * CFrame.new(math.cos(a) * orb.radius, orb.y + bob, math.sin(a) * orb.radius) * CFrame.Angles(now * 1.4, a, 0)
					end
				end
			end
		end
	end
end)

-- Animate Hub VoxelFantasyShowcase Pedestal Pets & Bind Interactive Pose Switcher
do
	local SHOWCASE_CYCLE: { VoxelPets.AnimMode } = { "Idle", "Walk", "Fly" }
	local NEXT_POSE_LABEL = { "Auto", "Idle", "Walk", "Fly" }
	local boundPrompts: { [Instance]: boolean } = {}

	local function cycleShowcasePose(pedestal: Instance)
		local petModel = pedestal:FindFirstChildWhichIsA("Model")
		if not petModel then return end
		local cur = tostring(petModel:GetAttribute("ShowcaseAnimMode") or "Auto")
		local idx = table.find(NEXT_POSE_LABEL, cur) or 1
		local nxt = NEXT_POSE_LABEL[(idx % #NEXT_POSE_LABEL) + 1]
		petModel:SetAttribute("ShowcaseAnimMode", nxt)
		local prompt = pedestal:FindFirstChild("ShowcasePosePrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Pose: " .. nxt .. " ([E] Switch)"
		end
	end

	RunService.RenderStepped:Connect(function()
		local gw = Workspace:FindFirstChild("GameWorld")
		local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
		local showcase = if hub then hub:FindFirstChild("VoxelFantasyShowcase") else nil
		if not showcase then return end

		local now = os.clock()
		for i, ch in ipairs(showcase:GetChildren()) do
			if string.sub(ch.Name, 1, 9) == "Pedestal_" then
				local prompt = ch:FindFirstChild("ShowcasePosePrompt", true)
				if prompt and prompt:IsA("ProximityPrompt") and not boundPrompts[prompt] then
					boundPrompts[prompt] = true
					prompt.Triggered:Connect(function()
						cycleShowcasePose(ch)
					end)
				end
				local cd = ch:FindFirstChild("ShowcasePoseClick", true)
				if cd and cd:IsA("ClickDetector") and not boundPrompts[cd] then
					boundPrompts[cd] = true
					cd.MouseClick:Connect(function()
						cycleShowcasePose(ch)
					end)
				end

				local petModel = ch:FindFirstChildWhichIsA("Model")
				if petModel and petModel:GetAttribute("VoxelRig") == true then
					local modeAttr = tostring(petModel:GetAttribute("ShowcaseAnimMode") or "Auto")
					local animMode: VoxelPets.AnimMode
					if modeAttr == "Idle" or modeAttr == "Walk" or modeAttr == "Fly" then
						animMode = modeAttr :: VoxelPets.AnimMode
					else
						local slot = (math.floor((now + i * 1.5) / 5) % #SHOWCASE_CYCLE) + 1
						animMode = SHOWCASE_CYCLE[slot]
					end
					VoxelPets.StepRig(petModel, animMode, now, i * 1.3)
				end
			end
		end
	end)
end
