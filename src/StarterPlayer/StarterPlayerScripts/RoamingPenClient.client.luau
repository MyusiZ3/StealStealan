--!strict
-- RoamingPenClient.client.luau
-- Spawns & animates free-roaming blocky animals inside each plot's Open-Pen Paddock (no stalls).
-- Supports random sizeRatio scaling, 7 mutation VFX, Rainbow hue cycling, and Hide Other / Hide Own toggles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

local currentPlotsPayload: any = {}
local currentSettings: Types.PlayerSettings = GameConfig.DEFAULT_SETTINGS
local activeEntities: { RoamingEntity } = {}
local rainbowParts: { BasePart } = {}

local function clearAllEntities()
	for _, ent in ipairs(activeEntities) do
		if ent.model then
			ent.model:Destroy()
		end
	end
	table.clear(activeEntities)
	table.clear(rainbowParts)
end

local function randomLocalPaddockPos(): Vector3
	return Vector3.new(math.random(-20, 20), 0.35, math.random(-13, 13))
end

local function rebuildEntities()
	clearAllEntities()

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

	for _, plotData in pairs(currentPlotsPayload) do
		local isOwn = (plotData.ownerUserId == localPlayer.UserId)
		local shouldHide = (isOwn and currentSettings.hideOwnAnimals) or ((not isOwn) and currentSettings.hideOtherAnimals)

		if not shouldHide and plotData.ownerUserId ~= 0 then
			local plotModel = plotsFolder:FindFirstChild("Plot_" .. tostring(plotData.plotIndex))
			local paddock = if plotModel then plotModel:FindFirstChild("OpenPaddockFloor") else nil
			if paddock and paddock:IsA("BasePart") then
				local paddockCF = paddock.CFrame
				for idx, animal in ipairs(plotData.roamingAnimals) do
					local model = AnimalVisualBuilder.BuildAnimalModel(animal.speciesId, animal.sizeRatio, animal.mutation, currentSettings.lowVFX)
					model.Name = string.format("P%d_%s_%s", plotData.plotIndex, animal.speciesId, string.sub(animal.uid, 1, 6))

					-- Add compact Billboard above animal
					local root = model.PrimaryPart :: BasePart
					local spec = AnimalConfig.GetById(animal.speciesId)
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromOffset(145, 42)
					bb.StudsOffset = Vector3.new(0, 3.6 * animal.sizeRatio, 0)
					bb.MaxDistance = 65
					bb.Parent = root

					local lbl = Instance.new("TextLabel")
					lbl.Size = UDim2.fromScale(1, 1)
					lbl.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
					lbl.BackgroundTransparency = 0.35
					local mutPrefix = if animal.mutation ~= "None" then ("[" .. animal.mutation .. "] ") else ""
					local inc = AnimalConfig.ComputeIncomePerSec(animal)
					lbl.Text = string.format("%s%s (%.2fx)\n$%s/s", mutPrefix, spec and spec.name or animal.speciesId, animal.sizeRatio, FormatUtil.Number(inc))
					lbl.TextColor3 = (GameConfig.MUTATIONS[animal.mutation] and GameConfig.MUTATIONS[animal.mutation].color) or Color3.new(1, 1, 1)
					lbl.Font = Enum.Font.FredokaOne
					lbl.TextScaled = true
					lbl.Parent = bb

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

					table.insert(activeEntities, {
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
					})
				end
			end
		end
	end
end

Remotes.Get("AllPlotsSync").OnClientEvent:Connect(function(payload)
	currentPlotsPayload = payload or {}
	rebuildEntities()
end)

Remotes.Get("ProfileSync").OnClientEvent:Connect(function(profile)
	if type(profile) == "table" and type(profile.settings) == "table" then
		local changed = (currentSettings.hideOtherAnimals ~= profile.settings.hideOtherAnimals)
			or (currentSettings.hideOwnAnimals ~= profile.settings.hideOwnAnimals)
			or (currentSettings.lowVFX ~= profile.settings.lowVFX)
		currentSettings = profile.settings
		if changed then
			rebuildEntities()
		end
	end
end)

local activeCrateBaseCF: { [Model]: CFrame } = {}

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()

	-- Subtle periodic struggle animation on nearby buried crates (when graphics quality is not Low)
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
				-- Idle breathing bounce
				hopY = math.sin(now * 3 + ent.phase) * 0.08
			end

			local worldCF = ent.paddockCF * CFrame.new(ent.pos.X, 0.35 + hopY, ent.pos.Z) * CFrame.Angles(0, ent.yaw, 0)
			ent.model:PivotTo(worldCF)
		end
	end
end)
