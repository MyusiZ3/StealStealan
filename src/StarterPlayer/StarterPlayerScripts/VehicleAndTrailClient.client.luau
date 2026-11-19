--!strict
-- VehicleAndTrailClient.client.luau
-- Manages Speed Multiplier Trail VFX, Drivable Land Vehicle Visuals, Rideable Animal Mounts,
-- Right-Hand Held Pet/Vehicle/Lasso Previews, & Exact Styled Towed Crate Spring Physics.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AnimalVisualBuilder = require(ReplicatedStorage.Modules.AnimalVisualBuilder)
local VoxelPets = require(ReplicatedStorage.Modules.VoxelPets)
local LassoConfig = require(ReplicatedStorage.Config.LassoConfig)
local TrailConfig = require(ReplicatedStorage.Config.TrailConfig)
local VehicleConfig = require(ReplicatedStorage.Config.VehicleConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer

local equippedLassoId = "RopeLasso"
local equippedTrailId = "BreezeTrail"
local equippedVehicleId = "StarterATV"
local isRidingVehicle = false
local lowVFXEnabled = false
local defaultHipHeight = 2.0

local activeTrail: Trail? = nil
local activeTrailCore: Trail? = nil
local activeAuraEmitter: ParticleEmitter? = nil
local activeSparkEmitter: ParticleEmitter? = nil
local activeTrailLight: PointLight? = nil
local activeVehicleModel: Model? = nil
local vehicleBotRel = -2.5
local activeMountModel: Model? = nil
local mountBotRel = 0
local activeHeldModel: Model? = nil
local activeSitTrack: AnimationTrack? = nil
local activeHoldTrack: AnimationTrack? = nil
local cachedHoldAnimator: Animator? = nil
local heldRebuildQueued = false
local towedCrateVisuals: { Model } = {}
local lastTowSig = ""

local R15_SIT_ANIM = "rbxassetid://2506281703"
local R6_SIT_ANIM = "rbxassetid://178130996"
local R15_HOLD_ANIM = "rbxassetid://507768375"
local R6_HOLD_ANIM = "rbxassetid://182393478"

local function findTrailDef(id: string)
	for _, t in ipairs(TrailConfig) do
		if t.id == id then return t end
	end
	return TrailConfig[1]
end

local function findVehicleDef(id: string)
	for _, v in ipairs(VehicleConfig) do
		if v.id == id then return v end
	end
	return VehicleConfig[1]
end

local function findLassoDef(id: string)
	for _, l in ipairs(LassoConfig) do
		if l.id == id then return l end
	end
	return LassoConfig[1]
end

local function clearTrailFX()
	if activeTrail then activeTrail:Destroy(); activeTrail = nil end
	if activeTrailCore then activeTrailCore:Destroy(); activeTrailCore = nil end
	if activeAuraEmitter then activeAuraEmitter:Destroy(); activeAuraEmitter = nil end
	if activeSparkEmitter then activeSparkEmitter:Destroy(); activeSparkEmitter = nil end
	if activeTrailLight then activeTrailLight:Destroy(); activeTrailLight = nil end
end

local function applyTrailToCharacter(char: Model)
	clearTrailFX()
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") then return end

	local a0 = root:FindFirstChild("TrailAttach0") :: Attachment?
	if not a0 then
		a0 = Instance.new("Attachment")
		a0.Name = "TrailAttach0"
		a0.Position = Vector3.new(0, 1.35, 0.65)
		a0.Parent = root
	end
	local a1 = root:FindFirstChild("TrailAttach1") :: Attachment?
	if not a1 then
		a1 = Instance.new("Attachment")
		a1.Name = "TrailAttach1"
		a1.Position = Vector3.new(0, -1.35, 0.65)
		a1.Parent = root
	end
	local ac0 = root:FindFirstChild("TrailCoreA0") :: Attachment?
	if not ac0 then
		ac0 = Instance.new("Attachment")
		ac0.Name = "TrailCoreA0"
		ac0.Position = Vector3.new(0, 0.55, 0.65)
		ac0.Parent = root
	end
	local ac1 = root:FindFirstChild("TrailCoreA1") :: Attachment?
	if not ac1 then
		ac1 = Instance.new("Attachment")
		ac1.Name = "TrailCoreA1"
		ac1.Position = Vector3.new(0, -0.55, 0.65)
		ac1.Parent = root
	end

	local def = findTrailDef(equippedTrailId)
	local trail = Instance.new("Trail")
	trail.Name = "RangerSpeedTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5 + math.min(0.65, def.tier * 0.06)
	trail.MinLength = 0.08
	trail.LightEmission = 0.25
	trail.Color = ColorSequence.new(def.colorPrimary, def.colorSecondary)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = root
	activeTrail = trail

	if def.tier >= 3 then
		local core = Instance.new("Trail")
		core.Name = "RangerTrailCore"
		core.Attachment0 = ac0
		core.Attachment1 = ac1
		core.Lifetime = trail.Lifetime * 0.72
		core.MinLength = 0.08
		core.LightEmission = 0.25
		core.Color = ColorSequence.new(Color3.new(1, 1, 1), def.colorPrimary)
		core.WidthScale = NumberSequence.new(1, 0)
		core.Parent = root
		activeTrailCore = core
	end

	-- Per-Trail Unique Body Aura Particle VFX
	if not lowVFXEnabled then
		local auraParent = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "TrailAuraEmitter"
		aura.Color = ColorSequence.new(def.colorPrimary, def.colorSecondary)
		aura.LightEmission = 0.22
		aura.Lifetime = NumberRange.new(0.45, 0.85 + def.tier * 0.05)
		aura.Rate = 6 + def.tier * 2.5
		aura.Speed = NumberRange.new(1.5, 4.0 + def.tier * 0.4)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Drag = 2.0
		aura.RotSpeed = NumberRange.new(-140, 140)
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18 + def.tier * 0.03),
			NumberSequenceKeypoint.new(0.5, 0.32 + def.tier * 0.04),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		if def.id == "BreezeTrail" then
			aura.EmissionDirection = Enum.NormalId.Back
			aura.SpreadAngle = Vector2.new(35, 35)
		elseif def.id == "LeafTrail" then
			aura.Acceleration = Vector3.new(0, -6, 0)
			aura.Rate = 12
		elseif def.id == "CrimsonTrail" or def.id == "SparkTrail" then
			aura.Acceleration = Vector3.new(0, 12, 0)
			aura.Speed = NumberRange.new(3, 8)
		elseif def.id == "FrostTrail" then
			aura.Acceleration = Vector3.new(0, -4, 0)
			aura.Rate = 18
		elseif def.id == "VoltTrail" or def.id == "PlasmaTrail" then
			aura.Speed = NumberRange.new(5, 11)
			aura.Lifetime = NumberRange.new(0.2, 0.45)
		elseif def.tier >= 9 then
			aura.Rate = 26
			aura.Acceleration = Vector3.new(0, 8, 0)
		end
		aura.Parent = auraParent
		activeAuraEmitter = aura

		if def.tier >= 5 then
			local lt = Instance.new("PointLight")
			lt.Name = "TrailBodyGlow"
			lt.Color = def.colorPrimary
			lt.Range = 7
			lt.Brightness = 0.28
			lt.Shadows = false
			lt.Parent = root
			activeTrailLight = lt
		end
	end
end

local function captureDefaultHipHeight(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		if hum.RigType == Enum.HumanoidRigType.R15 then
			defaultHipHeight = if hum.HipHeight > 0.5 then hum.HipHeight else 2.2
		else
			defaultHipHeight = 0
		end
		localPlayer:SetAttribute("StandingHipHeight", defaultHipHeight)
	end
end

local function setSitAnimation(active: boolean)
	if activeSitTrack then
		pcall(function()
			activeSitTrack:Stop(0.12)
			activeSitTrack:Destroy()
		end)
		activeSitTrack = nil
	end
	if not active then
		return
	end
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not hum then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = if hum.RigType == Enum.HumanoidRigType.R15 then R15_SIT_ANIM else R6_SIT_ANIM
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	anim:Destroy()
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = true
		track:Play(0.15)
		activeSitTrack = track
	end
end

local function setHoldAnimation(active: boolean)
	if not active then
		if activeHoldTrack and activeHoldTrack.IsPlaying then
			pcall(function()
				activeHoldTrack:Stop(0.1)
			end)
		end
		return
	end
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not hum then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	if activeHoldTrack and cachedHoldAnimator == animator then
		if not activeHoldTrack.IsPlaying then
			pcall(function()
				activeHoldTrack:Play(0.12)
			end)
		end
		return
	end
	if activeHoldTrack then
		pcall(function()
			activeHoldTrack:Stop(0.05)
			activeHoldTrack:Destroy()
		end)
		activeHoldTrack = nil
	end
	cachedHoldAnimator = animator
	local anim = Instance.new("Animation")
	anim.AnimationId = if hum.RigType == Enum.HumanoidRigType.R15 then R15_HOLD_ANIM else R6_HOLD_ANIM
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	anim:Destroy()
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.12)
		activeHoldTrack = track
	end
end

local function clearHeldVisual()
	if activeHeldModel then
		activeHeldModel:Destroy()
		activeHeldModel = nil
	end
	if #towedCrateVisuals == 0 then
		setHoldAnimation(false)
	end
end

local function attachModelToRightHand(model: Model, localHandOffset: CFrame)
	local char = localPlayer.Character
	if not char then
		model:Destroy()
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:WaitForChild("RightHand", 1)
	if not hand or not hand:IsA("BasePart") then
		model:Destroy()
		return
	end
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		model:Destroy()
		return
	end
	model.PrimaryPart = primary

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = d
				w.Parent = primary
			end
		end
	end

	-- Center model bounding-box cleanly in front of hand (fixes off-pivot assets like vehicles)
	local bbCF = model:GetBoundingBox()
	local pivToCenter = model:GetPivot():ToObjectSpace(bbCF)
	model:PivotTo(hand.CFrame * localHandOffset * pivToCenter:Inverse())

	local gripWeld = Instance.new("WeldConstraint")
	gripWeld.Name = "HeldItemGripWeld"
	gripWeld.Part0 = hand
	gripWeld.Part1 = primary
	gripWeld.Parent = primary

	model.Name = "ClientHeldItemModel"
	model.Parent = char
	activeHeldModel = model
	setHoldAnimation(true)
end

local function rebuildHeldVisual()
	clearHeldVisual()

	local mountedUid = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "")
	local onTreadmill = localPlayer:GetAttribute("OnTreadmill") == true
	-- Stop holding item in hand once player mounts pet, rides vehicle, runs on treadmill, or carries crate overhead
	if isRidingVehicle or mountedUid ~= "" or onTreadmill or #towedCrateVisuals > 0 then
		return
	end

	local hType = tostring(localPlayer:GetAttribute("HeldItemType") or "")
	if hType == "" then
		return
	end

	if hType == "Pet" then
		local speciesId = tostring(localPlayer:GetAttribute("HeldItemSpecies") or "RustyFox")
		local mutation = tostring(localPlayer:GetAttribute("HeldItemMutation") or "None") :: any
		local m = AnimalVisualBuilder.BuildAnimalModel(speciesId, 0.36, mutation, true)
		attachModelToRightHand(m, CFrame.new(0, 0.35, -0.55) * CFrame.Angles(0, math.rad(165), 0))
	elseif hType == "Crate" then
		local biomeId = tostring(localPlayer:GetAttribute("HeldItemBiome") or "PineWoods")
		local rarity = tostring(localPlayer:GetAttribute("HeldItemRarity") or "Common") :: any
		local scale = tonumber(localPlayer:GetAttribute("HeldItemScale")) or 1.0
		local isMerged = localPlayer:GetAttribute("HeldItemMerged") == true
		local m = AnimalVisualBuilder.BuildCrateModel(rarity, biomeId, math.clamp(scale * 0.34, 0.24, 0.62), {
			isBuried = false,
			canCollide = false,
			showBeacon = false,
		})
		if isMerged and m.PrimaryPart then
			local hl = Instance.new("Highlight")
			hl.Name = "MergeHandHighlight"
			hl.Adornee = m
			hl.FillColor = Color3.fromRGB(92, 232, 255)
			hl.FillTransparency = 0.78
			hl.OutlineColor = Color3.fromRGB(255, 224, 92)
			hl.OutlineTransparency = 0.1
			hl.Parent = m

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(148, 30)
			bb.StudsOffset = Vector3.new(0, 1.9, 0)
			bb.AlwaysOnTop = false
			bb.Parent = m.PrimaryPart
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = "⚡ MERGE CRATE"
			lbl.TextColor3 = Color3.fromRGB(118, 240, 255)
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.Parent = bb
			local st = Instance.new("UIStroke")
			st.Thickness = 2
			st.Color = Color3.fromRGB(12, 16, 24)
			st.Parent = lbl
		end
		attachModelToRightHand(m, CFrame.new(0, 0.42, -0.55))
	elseif hType == "Vehicle" then
		local vehId = tostring(localPlayer:GetAttribute("HeldItemId") or equippedVehicleId)
		local m = AnimalVisualBuilder.BuildVehicleModel(findVehicleDef(vehId), 0.30)
		attachModelToRightHand(m, CFrame.new(0, 0.52, -0.45) * CFrame.Angles(0, math.rad(110), 0))
	elseif hType == "Lasso" then
		local lassoId = tostring(localPlayer:GetAttribute("HeldItemId") or equippedLassoId)
		local lDef = findLassoDef(lassoId)
		local m = AnimalVisualBuilder.BuildLassoModel(lDef.beamColor, 0.90)
		attachModelToRightHand(m, CFrame.new(0, -0.05, -0.45))
	end
end

local function scheduleHeldRebuild()
	if heldRebuildQueued then return end
	heldRebuildQueued = true
	task.defer(function()
		heldRebuildQueued = false
		rebuildHeldVisual()
	end)
end

local function restoreStandingState()
	setSitAnimation(false)
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local onTread = localPlayer:GetAttribute("OnTreadmill") == true
	if hum then
		hum.HipHeight = defaultHipHeight
	end
	if not onTread and root and root:IsA("BasePart") then
		root.CFrame = root.CFrame + Vector3.new(0, 0.8, 0)
	end
	if hum and not onTread then
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end
end

local function buildVehicleVisual(): Model
	local def = findVehicleDef(equippedVehicleId)
	local m = AnimalVisualBuilder.BuildVehicleModel(def, 1.0)
	m.Name = "ActiveRangerVehicle"
	local botRel = AnimalVisualBuilder.GetModelVerticalBounds(m)
	vehicleBotRel = botRel
	m.Parent = Workspace
	return m
end

local function rebuildMountVisual()
	if activeMountModel then
		activeMountModel:Destroy()
		activeMountModel = nil
	end
	local uid = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "")
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if uid == "" then
		if not isRidingVehicle then
			restoreStandingState()
		end
		rebuildHeldVisual()
		return
	end

	clearHeldVisual()
	local speciesId = tostring(localPlayer:GetAttribute("MountedAnimalId") or "Capybara")
	local mutation = tostring(localPlayer:GetAttribute("MountedAnimalMutation") or "Normal")
	local sizeRatio = tonumber(localPlayer:GetAttribute("MountedAnimalSize")) or 1.0
	local vpMod = VoxelPets.GetSpeciesModule(speciesId)
	local isColossus = (vpMod ~= nil and vpMod.Archetype == "CataclysmColossus")
	local mountScale = if isColossus
		then math.clamp(sizeRatio * 1.25, 1.05, 1.85)
		else math.clamp(sizeRatio * 0.82, 0.80, 1.45)
	local keepRig = VoxelPets.IsVoxelRigSpecies(speciesId)
	local m = AnimalVisualBuilder.BuildAnimalModel(speciesId, mountScale, mutation :: any, not keepRig)
	m.Name = "MountedAnimal"
	mountBotRel = AnimalVisualBuilder.GetModelVerticalBounds(m)
	m.Parent = Workspace
	activeMountModel = m

	if hum then
		hum.HipHeight = if isColossus
			then math.max(defaultHipHeight + 1.2, 2.65 * mountScale)
			else math.max(defaultHipHeight + 0.55, 2.05 * mountScale - 0.55)
	end
	setSitAnimation(true)
end

local function setRidingVehicle(state: boolean)
	local wasRiding = isRidingVehicle
	isRidingVehicle = state
	localPlayer:SetAttribute("IsRidingVehicle", state)
	if state and tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") ~= "" then
		Remotes.Get("MountAnimal"):FireServer("")
		if activeMountModel then
			activeMountModel:Destroy()
			activeMountModel = nil
		end
	end
	Remotes.Get("SetMovementState"):FireServer("IsRidingVehicle", state)

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil

	if activeVehicleModel then
		activeVehicleModel:Destroy()
		activeVehicleModel = nil
	end
	if state then
		clearHeldVisual()
		if hum then
			hum.HipHeight = defaultHipHeight + 0.35
		end
		setSitAnimation(true)
		activeVehicleModel = buildVehicleVisual()
	elseif wasRiding and tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") == "" then
		restoreStandingState()
		rebuildHeldVisual()
	else
		rebuildHeldVisual()
	end
end

local function rebuildTowedCrateVisuals()
	local rawJson = tostring(localPlayer:GetAttribute("TowedCratesJson") or "[]")
	local count = tonumber(localPlayer:GetAttribute("TowedCrateCount")) or 0
	local sig = rawJson .. "|" .. tostring(count)
	if sig == lastTowSig then
		return
	end
	lastTowSig = sig

	for _, m in ipairs(towedCrateVisuals) do
		if m then m:Destroy() end
	end
	table.clear(towedCrateVisuals)

	local parsed: { { b: string?, r: string?, s: number? } } = {}
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(rawJson)
	end)
	if ok and type(decoded) == "table" then
		parsed = decoded
	end

	local targetCount = math.max(#parsed, count)
	for i = 1, targetCount do
		local entry = parsed[i]
		local biomeId = if entry and entry.b then tostring(entry.b) else "PineWoods"
		local rarity = (if entry and entry.r then tostring(entry.r) else "Common") :: any
		local scale = if entry and type(entry.s) == "number" then entry.s else 1.0

		local m = AnimalVisualBuilder.BuildCrateModel(rarity, biomeId, math.clamp(scale * 0.52, 0.38, 0.88), {
			isBuried = false,
			canCollide = false,
			showBeacon = false,
		})
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			end
		end
		m.Name = "ClientCarriedCrate_" .. i
		m.Parent = Workspace
		table.insert(towedCrateVisuals, m)
	end

	if targetCount > 0 and localPlayer:GetAttribute("OnTreadmill") ~= true then
		clearHeldVisual()
		setHoldAnimation(true)
	elseif not activeHeldModel then
		setHoldAnimation(false)
		scheduleHeldRebuild()
	end
end

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) ~= "table" then return end
	if type(profile.settings) == "table" then
		local nextLow = profile.settings.lowVFX == true
		if nextLow ~= lowVFXEnabled then
			lowVFXEnabled = nextLow
			if localPlayer.Character then
				applyTrailToCharacter(localPlayer.Character)
			end
		end
	end
	if profile.equippedLasso and profile.equippedLasso ~= equippedLassoId then
		equippedLassoId = profile.equippedLasso
		scheduleHeldRebuild()
	end
	if profile.equippedTrail ~= equippedTrailId then
		equippedTrailId = profile.equippedTrail
		if localPlayer.Character then
			applyTrailToCharacter(localPlayer.Character)
		end
	end
	if profile.equippedVehicle ~= equippedVehicleId then
		equippedVehicleId = profile.equippedVehicle
		if isRidingVehicle then
			setRidingVehicle(true)
		else
			scheduleHeldRebuild()
		end
	end
end)

Remotes.Get("SpawnVehicle").OnClientEvent:Connect(function(forceState)
	setRidingVehicle(if type(forceState) == "boolean" then forceState else not isRidingVehicle)
end)

localPlayer.AttributeChanged:Connect(function(attrName)
	if attrName == "TowedCrateCount" or attrName == "TowedCratesJson" then
		rebuildTowedCrateVisuals()
	elseif attrName == "ToggleVehicleRequest" then
		setRidingVehicle(not isRidingVehicle)
	elseif attrName == "HeldItemType" or attrName == "HeldItemId" or attrName == "HeldItemSpecies" or attrName == "HeldItemMutation" or attrName == "HeldItemBiome" or attrName == "HeldItemRarity" or attrName == "HeldItemScale" or attrName == "HeldItemMerged" or attrName == "OnTreadmill" then
		scheduleHeldRebuild()
		if attrName == "OnTreadmill" then
			if localPlayer:GetAttribute("OnTreadmill") == true then
				setHoldAnimation(false)
			elseif #towedCrateVisuals > 0 then
				setHoldAnimation(true)
			end
		end
	elseif attrName == "MountedAnimalUid" or attrName == "MountedAnimalId" or attrName == "MountedAnimalMutation" or attrName == "MountedAnimalSize" then
		if tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") ~= "" and isRidingVehicle then
			isRidingVehicle = false
			if activeVehicleModel then
				activeVehicleModel:Destroy()
				activeVehicleModel = nil
			end
		end
		rebuildMountVisual()
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.V then
		setRidingVehicle(not isRidingVehicle)
	end
end)

localPlayer.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	captureDefaultHipHeight(char)
	applyTrailToCharacter(char)
	if isRidingVehicle then
		setRidingVehicle(true)
	elseif tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") ~= "" then
		rebuildMountVisual()
	else
		rebuildHeldVisual()
	end
end)
if localPlayer.Character then
	captureDefaultHipHeight(localPlayer.Character)
	applyTrailToCharacter(localPlayer.Character)
	if tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") ~= "" then
		rebuildMountVisual()
	else
		rebuildHeldVisual()
	end
end

local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.IgnoreWater = true

local function findJoint(char: Model, r15Name: string, r6Name: string): any
	for _, d in ipairs(char:GetDescendants()) do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and (d.Name == r15Name or d.Name == r6Name) then
			return d
		end
	end
	return nil
end

RunService.RenderStepped:Connect(function(_dt: number)
	local char = localPlayer.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not root or not root:IsA("BasePart") then return end

	local function resolveGroundAndLook(): (number, Vector3)
		local ignore: { Instance } = { char }
		if activeVehicleModel then table.insert(ignore, activeVehicleModel) end
		if activeMountModel then table.insert(ignore, activeMountModel) end
		for _, cm in ipairs(towedCrateVisuals) do table.insert(ignore, cm) end
		groundRayParams.FilterDescendantsInstances = ignore

		local res = Workspace:Raycast(root.Position + Vector3.new(0, 2.0, 0), Vector3.new(0, -18, 0), groundRayParams)
		local fallbackFloorY = root.Position.Y - ((if hum then hum.HipHeight else defaultHipHeight) + root.Size.Y * 0.5)
		local groundY = if res then res.Position.Y else fallbackFloorY
		local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flatLook.Magnitude < 0.05 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end
		return groundY, flatLook
	end

	if activeMountModel and activeMountModel.PrimaryPart then
		local now = os.clock()
		local vel = root.AssemblyLinearVelocity
		local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local isVoxelRig = (activeMountModel:GetAttribute("VoxelRig") == true)
		if isVoxelRig then
			VoxelPets.StepRig(activeMountModel, if horizSpeed > 2 then "Ride" else "Idle", now, 0)
		end
		local hopY = if isVoxelRig
			then (if horizSpeed > 2 then math.abs(math.sin(now * 11)) * 0.08 else 0)
			elseif horizSpeed > 2 then math.abs(math.sin(now * 11)) * 0.55
			else math.abs(math.sin(now * 3)) * 0.05
		local pitch = if isVoxelRig then 0 elseif horizSpeed > 2 then math.sin(now * 11) * 0.1 else 0
		local groundY, flatLook = resolveGroundAndLook()
		local footGroundPos = Vector3.new(root.Position.X, groundY + hopY - mountBotRel, root.Position.Z)
		activeMountModel:PivotTo(CFrame.lookAt(footGroundPos, footGroundPos + flatLook) * CFrame.Angles(pitch, 0, 0))
	end

	if isRidingVehicle and activeVehicleModel then
		-- Raycast directly under character to keep tires planted 0.00 studs flush on the ground!
		local groundY, flatLook = resolveGroundAndLook()
		local wheelGroundPos = Vector3.new(root.Position.X, groundY - vehicleBotRel, root.Position.Z)
		activeVehicleModel:PivotTo(CFrame.lookAt(wheelGroundPos, wheelGroundPos + flatLook))
	end

	-- Position grabbed crates OVERHEAD above player's raised hands
	local isTread = localPlayer:GetAttribute("OnTreadmill") == true
	if not isTread then
		for i, crateM in ipairs(towedCrateVisuals) do
			local sway = math.sin(os.clock() * 6.5) * 0.04
			crateM:PivotTo(root.CFrame * CFrame.new(0, 3.65 + (i - 1) * 2.15, -0.25) * CFrame.Angles(0, 0, sway))
		end
	else
		for i, crateM in ipairs(towedCrateVisuals) do
			crateM:PivotTo(root.CFrame * CFrame.new(0, 3.85 + (i - 1) * 2.15, -0.35))
		end
	end
end)

-- Apply shoulder/arm procedural poses on Stepped (runs before physics solver on Motor6D & R15 AnimationConstraint!)
RunService.Stepped:Connect(function()
	local char = localPlayer.Character
	if not char then return end
	local isTread = localPlayer:GetAttribute("OnTreadmill") == true
	local isPulling = localPlayer:GetAttribute("ClientPullingCrate") == true
	local mountedUid = tostring(localPlayer:GetAttribute("MountedAnimalUid") or "")
	local carryingOverhead = (#towedCrateVisuals > 0) and not isTread

	if isTread or isRidingVehicle or mountedUid ~= "" then
		return
	end

	local rSh = findJoint(char, "RightShoulder", "Right Shoulder")
	local lSh = findJoint(char, "LeftShoulder", "Left Shoulder")
	local rElb = findJoint(char, "RightElbow", "RightElbow")
	local lElb = findJoint(char, "LeftElbow", "LeftElbow")

	if isPulling then
		local tug = math.sin(os.clock() * 14) * 0.28
		if rSh then rSh.Transform = CFrame.Angles(math.rad(82) + tug, 0, math.rad(-14)) end
		if lSh then lSh.Transform = CFrame.Angles(math.rad(78) - tug, 0, math.rad(14)) end
		if rElb then rElb.Transform = CFrame.Angles(math.rad(35) - tug * 0.5, 0, 0) end
		if lElb then lElb.Transform = CFrame.Angles(math.rad(35) + tug * 0.5, 0, 0) end
	elseif carryingOverhead then
		if rSh then rSh.Transform = CFrame.Angles(math.rad(165), 0, math.rad(-12)) end
		if lSh then lSh.Transform = CFrame.Angles(math.rad(165), 0, math.rad(12)) end
		if rElb then rElb.Transform = CFrame.Angles(math.rad(20), 0, 0) end
		if lElb then lElb.Transform = CFrame.Angles(math.rad(20), 0, 0) end
	elseif activeHeldModel then
		if rSh then rSh.Transform = CFrame.Angles(math.rad(72), 0, math.rad(-6)) end
		if rElb then rElb.Transform = CFrame.Angles(math.rad(22), 0, 0) end
	end
end)
