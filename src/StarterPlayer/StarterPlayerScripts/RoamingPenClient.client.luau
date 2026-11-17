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
								local model = AnimalVisualBuilder.BuildAnimalModel(animal.speciesId, animal.sizeRatio, animal.mutation, currentSettings.lowVFX)
								model.Name = string.format("P%d_%s_%s", plotData.plotIndex, animal.speciesId, string.sub(animal.uid, 1, 6))

								local root = model.PrimaryPart :: BasePart
								local spec = AnimalConfig.GetById(animal.speciesId)
								local bb = Instance.new("BillboardGui")
								bb.Size = UDim2.fromOffset(170, 44)
								bb.StudsOffset = Vector3.new(0, 3.6 * animal.sizeRatio, 0)
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
							local statLbl = Instance.new("TextLabel")
							statLbl.Size = UDim2.new(1, -4, 0.48, 0)
							statLbl.Position = UDim2.new(0, 2, 0.50, 0)
							statLbl.BackgroundTransparency = 1
							statLbl.Text = if rem > 0 then ("⏳ Hatch: " .. FormatUtil.Time(rem)) else "✨ READY! Click / [E]"
							statLbl.TextColor3 = if rem > 0 then Color3.fromRGB(255, 224, 96) else Color3.fromRGB(108, 255, 132)
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
								p.ActionText = if rem > 0 then ("Hatching (" .. FormatUtil.Time(rem) .. ")") else "Hatch / Open Crate"
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
-- STEAL / BREAK AN EGG HATCH REVEAL ANIMATION (#4, #6, #7)
-- ============================================================================
local HATCH_SHARD_STYLES: { [string]: { mat: Enum.Material, c1: Color3, c2: Color3 } } = {
	PineWoods = { mat = Enum.Material.Wood, c1 = Color3.fromRGB(128, 86, 50), c2 = Color3.fromRGB(58, 132, 64) },
	MangroveSwamp = { mat = Enum.Material.WoodPlanks, c1 = Color3.fromRGB(98, 78, 46), c2 = Color3.fromRGB(72, 224, 158) },
	SavannaCamp = { mat = Enum.Material.DiamondPlate, c1 = Color3.fromRGB(68, 72, 82), c2 = Color3.fromRGB(224, 158, 52) },
	AlpinePeaks = { mat = Enum.Material.Ice, c1 = Color3.fromRGB(148, 222, 255), c2 = Color3.fromRGB(228, 246, 255) },
	VolcanicJungle = { mat = Enum.Material.Basalt, c1 = Color3.fromRGB(42, 34, 46), c2 = Color3.fromRGB(255, 86, 28) },
}

local function spawnMaterialShatter(originPos: Vector3, biomeId: string, rarityCol: Color3, scale: number)
	local style = HATCH_SHARD_STYLES[biomeId] or HATCH_SHARD_STYLES.PineWoods
	local shards: { { p: Part, vel: Vector3, rot: Vector3, baseSz: Vector3 } } = {}
	for i = 1, 16 do
		local ang = (i / 16) * math.pi * 2 + (math.random() - 0.5) * 0.35
		local spd = 11 + math.random() * 14
		local sh = Instance.new("Part")
		sh.Name = "HatchMaterialShard"
		local sx = (0.45 + math.random() * 0.55) * scale
		local sy = (0.28 + math.random() * 0.45) * scale
		local sz = (0.45 + math.random() * 0.55) * scale
		sh.Size = Vector3.new(sx, sy, sz)
		sh.CFrame = CFrame.new(originPos + Vector3.new(math.cos(ang) * 0.6, 0.8 * scale, math.sin(ang) * 0.6))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		if i % 3 == 0 then
			sh.Color = rarityCol
			sh.Material = Enum.Material.Neon
		else
			sh.Color = if i % 2 == 0 then style.c1 else style.c2
			sh.Material = style.mat
		end
		sh.TopSurface = Enum.SurfaceType.Studs
		sh.Anchored = true
		sh.CanCollide = false
		sh.CanQuery = false
		sh.CanTouch = false
		sh.Parent = Workspace
		table.insert(shards, {
			p = sh,
			vel = Vector3.new(math.cos(ang) * spd, 12 + math.random() * 12, math.sin(ang) * spd),
			rot = Vector3.new((math.random() - 0.5) * 14, (math.random() - 0.5) * 14, (math.random() - 0.5) * 14),
			baseSz = sh.Size,
		})
	end

	-- Sparkle particle cloud matching rarity & crate debris
	local emitHolder = Instance.new("Part")
	emitHolder.Size = Vector3.new(1, 1, 1)
	emitHolder.Position = originPos + Vector3.new(0, 1.2 * scale, 0)
	emitHolder.Transparency = 1
	emitHolder.Anchored = true
	emitHolder.CanCollide = false
	emitHolder.CanQuery = false
	emitHolder.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(rarityCol, Color3.new(1, 1, 1))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * scale), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.45, 0.8)
	pe.Speed = NumberRange.new(10, 22)
	pe.SpreadAngle = Vector2.new(85, 85)
	pe.Acceleration = Vector3.new(0, -18, 0)
	pe.LightEmission = 0.85
	pe.Rate = 0
	pe.Parent = emitHolder
	pe:Emit(28)

	task.spawn(function()
		local t0 = os.clock()
		local prev = t0
		while os.clock() - t0 < 0.72 do
			local nowC = os.clock()
			local dt = math.min(0.05, nowC - prev)
			prev = nowC
			local alpha = (nowC - t0) / 0.72
			for _, item in ipairs(shards) do
				item.vel += Vector3.new(0, -48 * dt, 0)
				local p = item.p
				local nextPos = p.Position + item.vel * dt
				if nextPos.Y < originPos.Y + 0.2 then
					nextPos = Vector3.new(nextPos.X, originPos.Y + 0.2, nextPos.Z)
					item.vel = Vector3.new(item.vel.X * 0.65, math.abs(item.vel.Y) * 0.38, item.vel.Z * 0.65)
				end
				p.CFrame = CFrame.new(nextPos) * (p.CFrame - p.CFrame.Position) * CFrame.Angles(item.rot.X * dt, item.rot.Y * dt, item.rot.Z * dt)
				p.Size = item.baseSz * math.max(0.05, 1 - alpha * 0.85)
				p.Transparency = math.clamp(alpha * 1.15 - 0.15, 0, 1)
			end
			RunService.RenderStepped:Wait()
		end
		for _, item in ipairs(shards) do
			if item.p.Parent then item.p:Destroy() end
		end
		if emitHolder.Parent then emitHolder:Destroy() end
	end)
end

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

	local speciesId = tostring(data.speciesId or "RustyFox")
	local spec = AnimalConfig.GetById(speciesId)
	local variantIdx = if spec then ((spec.indexNumber % 3) + 1) else 1
	local biomeId = tostring(data.biomeId or "PineWoods")

	local revealCrate = AnimalVisualBuilder.BuildCrateModel((data.rarity or "Common") :: any, biomeId, sc, {
		isBuried = false,
		canCollide = false,
		showBeacon = false,
		variant = variantIdx,
	})
	revealCrate.Name = "ClientHatchAnimCrate"
	revealCrate:PivotTo(baseCF)
	revealCrate.Parent = Workspace

	local rarityCol = GameConfig.RARITY_COLORS[data.rarity] or Color3.fromRGB(255, 224, 96)

	task.spawn(function()
		-- Phase 1 (0.72s): Accelerating wobble & pulse anticipation
		local startT = os.clock()
		while os.clock() - startT < 0.72 do
			local el = os.clock() - startT
			local alpha = el / 0.72
			local freq = 18 + alpha * 42
			local amp = 0.08 + alpha * 0.25
			local hop = math.abs(math.sin(el * 13)) * (0.35 + alpha * 0.85)
			local tilt = math.sin(el * freq) * amp
			revealCrate:PivotTo(baseCF * CFrame.new(0, hop, 0) * CFrame.Angles(tilt, alpha * 2.2, -tilt * 0.8))
			pcall(function()
				revealCrate:ScaleTo(1 + math.sin(el * 22) * 0.1)
			end)
			RunService.RenderStepped:Wait()
		end

		-- Phase 2: Material Shatter Debris + Expanding Sunburst Ring + Destroy Crate!
		spawnMaterialShatter(baseCF.Position, biomeId, rarityCol, sc)

		local ring = Instance.new("Part")
		ring.Name = "HatchShockRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.25, 2 * sc, 2 * sc)
		ring.CFrame = CFrame.new(baseCF.Position + Vector3.new(0, 1.2 * sc, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = rarityCol
		ring.Material = Enum.Material.Neon
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Transparency = 0.2
		ring.Parent = Workspace
		TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.15, 16 * sc, 16 * sc),
			Transparency = 1,
		}):Play()
		task.delay(0.48, function()
			if ring.Parent then ring:Destroy() end
		end)

		if revealCrate.Parent then
			revealCrate:Destroy()
		end

		-- Phase 3a (0.45s): Hatched Pet erupts big facing directly toward player/camera (Image 3 style!)
		local petScale = math.clamp((tonumber(data.sizeRatio) or 1.0) * 0.92, 0.85, 1.8)
		local animPet = AnimalVisualBuilder.BuildAnimalModel(speciesId, petScale, (data.mutation or "None") :: any, false)
		animPet.Name = "ClientHatchLeapAnimal"
		local originPos = (baseCF * CFrame.new(0, 1.8 * sc, 0)).Position
		animPet:PivotTo(CFrame.new(originPos))
		animPet.Parent = Workspace

		local pRoot = animPet.PrimaryPart
		if pRoot then
			local inc = AnimalConfig.ComputeIncomePerSec({
				uid = "",
				speciesId = speciesId,
				sizeRatio = tonumber(data.sizeRatio) or 1.0,
				weightKg = tonumber(data.weightKg) or 5.0,
				mutation = (data.mutation or "None") :: any,
				locked = false,
				acquiredAt = 0,
			})
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(195, 62)
			bb.StudsOffset = Vector3.new(0, 3.8 * petScale + 1.2, 0)
			bb.AlwaysOnTop = true
			bb.Parent = pRoot

			local topTxt = Instance.new("TextLabel")
			topTxt.Size = UDim2.fromScale(1, 0.54)
			topTxt.BackgroundTransparency = 1
			topTxt.Text = "$" .. FormatUtil.Number(inc) .. "/s"
			topTxt.TextColor3 = Color3.fromRGB(108, 255, 128)
			topTxt.Font = Enum.Font.FredokaOne
			topTxt.TextScaled = true
			topTxt.Parent = bb
			local ts = Instance.new("UIStroke")
			ts.Thickness = 2.8
			ts.Color = Color3.fromRGB(10, 12, 16)
			ts.Parent = topTxt

			local subTxt = Instance.new("TextLabel")
			subTxt.Size = UDim2.fromScale(1, 0.44)
			subTxt.Position = UDim2.fromScale(0, 0.54)
			subTxt.BackgroundTransparency = 1
			subTxt.Text = tostring(data.rarity or "Common")
			subTxt.TextColor3 = rarityCol
			subTxt.Font = Enum.Font.FredokaOne
			subTxt.TextScaled = true
			subTxt.Parent = bb
			local ss = Instance.new("UIStroke")
			ss.Thickness = 2.6
			ss.Color = Color3.fromRGB(10, 12, 16)
			ss.Parent = subTxt
		end

		local popStart = os.clock()
		local popDur = 0.45
		local hoverPos = originPos + Vector3.new(0, 4.2, 0)
		while os.clock() - popStart < popDur do
			local a = math.clamp((os.clock() - popStart) / popDur, 0, 1)
			local easeOut = 1 - math.pow(1 - a, 3)
			local char = localPlayer.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local cam = Workspace.CurrentCamera
			local viewerPos = if root and root:IsA("BasePart")
				then root.Position
				elseif cam then cam.CFrame.Position
				else (originPos + Vector3.new(0, 4, -12))
			local curPos = originPos:Lerp(hoverPos, easeOut)
			local lookPt = Vector3.new(viewerPos.X, curPos.Y, viewerPos.Z)
			local faceCF = if (lookPt - curPos).Magnitude > 0.1 then CFrame.lookAt(curPos, lookPt) else CFrame.new(curPos)
			animPet:PivotTo(faceCF)
			pcall(function()
				animPet:ScaleTo(0.35 + easeOut * 0.95)
			end)
			RunService.RenderStepped:Wait()
		end

		-- Phase 3b (0.50s): Swoops directly toward the player's body/inventory while facing the player!
		local leapStart = os.clock()
		local leapDur = 0.50
		while os.clock() - leapStart < leapDur do
			local a = math.clamp((os.clock() - leapStart) / leapDur, 0, 1)
			local char = localPlayer.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local targetPos = if root and root:IsA("BasePart") then (root.Position + Vector3.new(0, 0.5, 0)) else (originPos + Vector3.new(0, 5, 0))
			local arcY = math.sin(a * math.pi) * 4.5
			local curPos = hoverPos:Lerp(targetPos, a * a) + Vector3.new(0, arcY, 0)
			local lookTarget = Vector3.new(targetPos.X, curPos.Y, targetPos.Z)
			local lookCF = if (lookTarget - curPos).Magnitude > 0.1 then CFrame.lookAt(curPos, lookTarget) else CFrame.new(curPos)
			animPet:PivotTo(lookCF)
			pcall(function()
				animPet:ScaleTo(math.max(0.18, 1.3 - a * 1.12))
			end)
			RunService.RenderStepped:Wait()
		end

		-- Small collect flash on player chest when hatched pet enters!
		local charEnd = localPlayer.Character
		local rootEnd = if charEnd then charEnd:FindFirstChild("HumanoidRootPart") else nil
		if rootEnd and rootEnd:IsA("BasePart") then
			local flash = Instance.new("Part")
			flash.Shape = Enum.PartType.Ball
			flash.Size = Vector3.new(1.5, 1.5, 1.5)
			flash.CFrame = rootEnd.CFrame
			flash.Color = rarityCol
			flash.Material = Enum.Material.Neon
			flash.Anchored = true
			flash.CanCollide = false
			flash.CanQuery = false
			flash.Transparency = 0.25
			flash.Parent = Workspace
			TweenService:Create(flash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(5.5, 5.5, 5.5),
				Transparency = 1,
			}):Play()
			task.delay(0.3, function()
				if flash.Parent then flash:Destroy() end
			end)
		end

		if animPet.Parent then
			animPet:Destroy()
		end
		if type(data.animalUid) == "string" then
			delayedAnimalUids[data.animalUid] = nil
			rebuildEntities(false)
		end
	end)
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
					if rem > 0 then
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

			local hopY = 0
			if now >= ent.waitUntil and dist > 0.6 then
				local step = math.min(dist, ent.speed * dt)
				local dir = horiz.Unit
				ent.pos += dir * step
				ent.yaw = math.atan2(-dir.X, -dir.Z)
				hopY = math.abs(math.sin(now * 9 + ent.phase)) * 0.55
			elseif dist <= 0.6 then
				ent.waitUntil = now + math.random(10, 28) / 10
				ent.targetPos = randomLocalPaddockPos(ent.topY)
			else
				hopY = math.abs(math.sin(now * 3 + ent.phase)) * 0.05
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
