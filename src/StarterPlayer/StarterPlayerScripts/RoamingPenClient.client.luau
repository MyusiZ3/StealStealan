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
local FormatUtil = require(ReplicatedStorage.Modules.FormatUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

type RoamingEntity = {
	uid: string,
	plotIndex: number,
	model: Model,
	isRainbow: boolean,
	pos: Vector3,
	targetPos: Vector3,
	yaw: number,
	speed: number,
	waitUntil: number,
	phase: number,
	paddockCF: CFrame,
}

type PlacedCrateVisual = {
	uid: string,
	plotIndex: number,
	model: Model,
	baseCF: CFrame,
	localX: number,
	localZ: number,
	sizeScale: number,
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

local function randomLocalPaddockPos(): Vector3
	return Vector3.new(math.random(-20, 20), 0.35, math.random(-13, 13))
end

-- Deterministic 6x5 grid across the 52x36 OpenPaddockFloor supporting up to 30 hatching crates neatly
local function computePenCrateSlotLocalPos(slotIndex: number, localX: number?, localZ: number?): Vector3
	if type(localX) == "number" and type(localZ) == "number" then
		return Vector3.new(math.clamp(localX, -22.5, 22.5), 0.25, math.clamp(localZ, -14.5, 14.5))
	end
	local idx0 = math.clamp(slotIndex - 1, 0, GameConfig.PEN.MAX_PLACED_CRATES - 1)
	local col = idx0 % 6
	local row = math.floor(idx0 / 6)
	local x = -20 + col * 8.0
	local z = -10 + row * 6.0
	return Vector3.new(x, 0.25, z)
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

				-- 1. Diff/Preserve Roaming Animals inside Paddock (Equip Best NEVER resets existing pets!)
				if not shouldHideAnimals and type(plotData.roamingAnimals) == "table" then
					for idx, animal in ipairs(plotData.roamingAnimals) do
						if not delayedAnimalUids[animal.uid] then
							wantedAnimalUids[animal.uid] = true
							local existing = activeEntitiesByUid[animal.uid]
							if existing and existing.model and existing.model.Parent and existing.plotIndex == plotData.plotIndex then
								existing.paddockCF = paddockCF
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

								local startLocal = randomLocalPaddockPos()
								model:PivotTo(paddockCF * CFrame.new(startLocal))
								model.Parent = entitiesRoot

								if animal.mutation == "Rainbow" then
									for _, d in ipairs(model:GetDescendants()) do
										if d:IsA("BasePart") and d.Name ~= "Eye" then
											table.insert(rainbowParts, d)
										end
									end
								end

								local newEnt: RoamingEntity = {
									uid = animal.uid,
									plotIndex = plotData.plotIndex,
									model = model,
									isRainbow = (animal.mutation == "Rainbow"),
									pos = startLocal,
									targetPos = randomLocalPaddockPos(),
									yaw = math.random() * math.pi * 2,
									speed = math.random(4, 7),
									waitUntil = os.clock() + (idx * 0.2),
									phase = idx * 0.9,
									paddockCF = paddockCF,
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
							local crateModel = AnimalVisualBuilder.BuildCrateModel(crate.rarity, crate.biomeId, sc, {
								isBuried = false,
								canCollide = false,
								showBeacon = false,
							})
							crateModel.Name = string.format("PenCrate_%d_%s", slotIdx, string.sub(crate.uid, 1, 6))

							local localPos = computePenCrateSlotLocalPos(slotIdx, crate.localX, crate.localZ)
							local yaw = ((slotIdx * 37) % 360) * math.pi / 180
							local baseCF = paddockCF * CFrame.new(localPos) * CFrame.Angles(0, yaw, 0)
							crateModel:PivotTo(baseCF)

							local cRoot = crateModel.PrimaryPart :: BasePart
							cRoot.CanQuery = true

							local rarityCol = GameConfig.RARITY_COLORS[crate.rarity] or Color3.new(1, 1, 1)
							local bb = Instance.new("BillboardGui")
							bb.Size = UDim2.fromOffset(182, 50)
							bb.StudsOffset = Vector3.new(0, 3.6 * sc + 1.4, 0)
							bb.MaxDistance = 75
							bb.Parent = cRoot

							-- Clean floating text with UIStroke (NO dark rectangular background!)
							local topLbl = Instance.new("TextLabel")
							topLbl.Size = UDim2.new(1, -4, 0.48, 0)
							topLbl.Position = UDim2.fromOffset(2, 2)
							topLbl.BackgroundTransparency = 1
							topLbl.Text = string.format("[%s] %s", string.upper(crate.rarity), crate.biomeId)
							topLbl.TextColor3 = rarityCol
							topLbl.Font = Enum.Font.FredokaOne
							topLbl.TextScaled = true
							topLbl.Parent = bb
							local topSt = Instance.new("UIStroke")
							topSt.Thickness = 2.5
							topSt.Color = Color3.fromRGB(10, 12, 16)
							topSt.Parent = topLbl

							local rem = math.max(0, (crate.unlockAt or 0) - nowUnix)
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
								unlockAt = crate.unlockAt or nowUnix,
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
		end
	end
end

local function bindPlayerPrivacySignals(p: Player)
	p:GetAttributeChangedSignal("OnTreadmill"):Connect(updatePlotPrivacyVisuals)
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
	local localPos = computePenCrateSlotLocalPos(slotIdx, data.localX, data.localZ)
	local baseCF = paddock.CFrame * CFrame.new(localPos)

	local revealCrate = AnimalVisualBuilder.BuildCrateModel((data.rarity or "Common") :: any, tostring(data.biomeId or "PineWoods"), sc, {
		isBuried = false,
		canCollide = false,
		showBeacon = false,
	})
	revealCrate.Name = "ClientHatchAnimCrate"
	revealCrate:PivotTo(baseCF)
	revealCrate.Parent = Workspace

	local rarityCol = GameConfig.RARITY_COLORS[data.rarity] or Color3.fromRGB(255, 224, 96)

	task.spawn(function()
		-- Phase 1 (0.85s): Accelerating wobble & pulse anticipation
		local startT = os.clock()
		while os.clock() - startT < 0.85 do
			local el = os.clock() - startT
			local alpha = el / 0.85
			local freq = 16 + alpha * 38
			local amp = 0.08 + alpha * 0.24
			local hop = math.abs(math.sin(el * 12)) * (0.35 + alpha * 0.75)
			local tilt = math.sin(el * freq) * amp
			revealCrate:PivotTo(baseCF * CFrame.new(0, hop, 0) * CFrame.Angles(tilt, alpha * 2.5, -tilt * 0.8))
			pcall(function()
				revealCrate:ScaleTo(1 + math.sin(el * 20) * 0.08)
			end)
			RunService.RenderStepped:Wait()
		end

		-- Phase 2: Burst sphere glow + destroy crate!
		local burst = Instance.new("Part")
		burst.Name = "HatchPopBurst"
		burst.Shape = Enum.PartType.Ball
		burst.Size = Vector3.new(2 * sc, 2 * sc, 2 * sc)
		burst.CFrame = baseCF * CFrame.new(0, 1.5, 0)
		burst.Color = rarityCol
		burst.Material = Enum.Material.Neon
		burst.Anchored = true
		burst.CanCollide = false
		burst.CanQuery = false
		burst.Transparency = 0.15
		burst.Parent = Workspace
		TweenService:Create(burst, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(12 * sc, 12 * sc, 12 * sc),
			Transparency = 1,
		}):Play()
		task.delay(0.48, function()
			if burst.Parent then burst:Destroy() end
		end)

		if revealCrate.Parent then
			revealCrate:Destroy()
		end

		-- Phase 3 (0.72s): Bouncy hatched animal leaps out of crate right into player's hands/inventory!
		local petScale = math.clamp((tonumber(data.sizeRatio) or 1.0) * 0.72, 0.7, 1.45)
		local animPet = AnimalVisualBuilder.BuildAnimalModel(tostring(data.speciesId or "RustyFox"), petScale, (data.mutation or "None") :: any, false)
		animPet.Name = "ClientHatchLeapAnimal"
		local originPos = (baseCF * CFrame.new(0, 1.6, 0)).Position
		animPet:PivotTo(CFrame.new(originPos))
		animPet.Parent = Workspace

		local leapStart = os.clock()
		local leapDur = 0.72
		while os.clock() - leapStart < leapDur do
			local a = math.clamp((os.clock() - leapStart) / leapDur, 0, 1)
			local char = localPlayer.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local targetPos = if root and root:IsA("BasePart") then (root.Position + Vector3.new(0, 0.5, 0)) else (originPos + Vector3.new(0, 5, 0))
			-- Bouncy double arc + overshoot bounce like Steal/Break an Egg!
			local arcY = math.sin(a * math.pi) * 8.5 + math.abs(math.sin(a * math.pi * 2.5)) * (1 - a) * 2.2
			local curPos = originPos:Lerp(targetPos, a * a * (3 - 2 * a)) + Vector3.new(0, arcY, 0)
			local lookTarget = Vector3.new(targetPos.X, curPos.Y, targetPos.Z)
			local lookCF = if (lookTarget - curPos).Magnitude > 0.1 then CFrame.lookAt(curPos, lookTarget) else CFrame.new(curPos)
			animPet:PivotTo(lookCF * CFrame.Angles(0, a * math.pi * 2, 0))
			-- Squash & stretch scale bounce
			local scPulse = if a < 0.25 then (0.35 + (a / 0.25) * 0.95)
				elseif a < 0.75 then (1.3 - ((a - 0.25) / 0.5) * 0.25)
				else math.max(0.25, 1.05 - ((a - 0.75) / 0.25) * 0.8)
			pcall(function()
				animPet:ScaleTo(scPulse)
			end)
			RunService.RenderStepped:Wait()
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

	local snapWorld = (myPaddock.CFrame * CFrame.new(lx, 0.35, lz)).Position
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

	-- Update Placed Crates inside Pens (hatch countdown + egg-like wiggle animation)
	if #activePlacedCrates > 0 then
		local nowUnix = os.time()
		for _, cr in ipairs(activePlacedCrates) do
			if cr.model and cr.model.Parent then
				local rem = math.max(0, cr.unlockAt - nowUnix)
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
				ent.targetPos = randomLocalPaddockPos()
			else
				hopY = math.sin(now * 3 + ent.phase) * 0.08
			end

			local worldCF = ent.paddockCF * CFrame.new(ent.pos.X, 0.35 + hopY, ent.pos.Z) * CFrame.Angles(0, ent.yaw, 0)
			ent.model:PivotTo(worldCF)
		end
	end
end)
