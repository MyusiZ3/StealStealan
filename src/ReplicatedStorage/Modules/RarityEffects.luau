--!strict
-- RarityEffects.luau
-- Shared animated Cosmic+ (Cosmic..Primordial) text gradients, sunburst thumbnail backdrops,
-- and client-side wild crate BillboardGui effect binding.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

local RarityEffects = {}

RarityEffects.SUNBURST_ASSET_ID = "rbxassetid://72726912988616"

type TrackedSunburst = {
	img: ImageLabel,
	grad: UIGradient?,
	strokeGrad: UIGradient?,
	speedDeg: number,
	isPrimordial: boolean,
}

type TrackedText = {
	label: TextLabel,
	grad: UIGradient,
	stroke: UIStroke?,
	isPrimordial: boolean,
	speed: number,
}

local trackedSunbursts: { TrackedSunburst } = {}
local trackedTexts: { TrackedText } = {}
local loopStarted = false
local worldBound = false

local function startSharedLoop()
	if loopStarted then
		return
	end
	loopStarted = true
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		for i = #trackedSunbursts, 1, -1 do
			local item = trackedSunbursts[i]
			if not item.img.Parent then
				table.remove(trackedSunbursts, i)
			else
				item.img.Rotation = (item.img.Rotation + dt * item.speedDeg) % 360
				if item.grad then
					local wave = math.sin(t * 2.2) * 0.25
					item.grad.Offset = Vector2.new(wave, 0)
				end
				if item.strokeGrad then
					item.strokeGrad.Rotation = (t * 75) % 360
				end
				if item.isPrimordial then
					local h = (t * 0.18) % 1
					item.img.ImageColor3 = Color3.fromHSV(h, 0.72, 1)
				end
			end
		end

		for i = #trackedTexts, 1, -1 do
			local item = trackedTexts[i]
			if not item.label.Parent then
				table.remove(trackedTexts, i)
			else
				local sweep = math.sin(t * item.speed) * 0.55
				item.grad.Offset = Vector2.new(sweep, 0)
				if item.isPrimordial then
					local h = (t * 0.22) % 1
					local c1 = Color3.fromHSV(h, 0.82, 1)
					local c2 = Color3.fromHSV((h + 0.25) % 1, 0.65, 1)
					item.grad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, c1),
						ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, c2),
					})
				end
			end
		end
	end)
end

function RarityEffects.GetRarityPalette(rarity: string): {
	primary: Color3,
	secondary: Color3,
	deep: Color3,
	isCosmicPlus: boolean,
	isPrimordial: boolean,
}
	local primary = (GameConfig.RARITY_COLORS :: any)[rarity] or Color3.fromRGB(168, 182, 172)
	local secondary = (GameConfig.RARITY_SECONDARY_COLORS :: any)[rarity] or primary:Lerp(Color3.new(1, 1, 1), 0.38)
	local deep = primary:Lerp(Color3.fromRGB(14, 16, 36), 0.68)
	local tier = GameConfig.GetRarityTier(rarity)
	return {
		primary = primary,
		secondary = secondary,
		deep = deep,
		isCosmicPlus = tier >= GameConfig.COSMIC_TIER_THRESHOLD,
		isPrimordial = rarity == "Primordial",
	}
end

local function clearChildrenNamed(parent: Instance, name: string)
	for _, ch in ipairs(parent:GetChildren()) do
		if ch.Name == name then
			ch:Destroy()
		end
	end
end

function RarityEffects.ApplyTextEffect(label: TextLabel, rarity: string)
	clearChildrenNamed(label, "CosmicTextGradient")
	local pal = RarityEffects.GetRarityPalette(rarity)
	local existingStroke = label:FindFirstChildOfClass("UIStroke")

	if not pal.isCosmicPlus then
		label.TextColor3 = pal.primary
		if existingStroke then
			existingStroke.Color = Color3.fromRGB(16, 20, 28)
		end
		return
	end

	startSharedLoop()
	label.TextColor3 = Color3.new(1, 1, 1)

	local grad = Instance.new("UIGradient")
	grad.Name = "CosmicTextGradient"
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, pal.primary),
		ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1.0, pal.secondary),
	})
	grad.Rotation = 18
	grad.Parent = label

	if existingStroke then
		existingStroke.Color = pal.primary:Lerp(Color3.fromRGB(12, 12, 28), 0.45)
	end

	local tier = GameConfig.GetRarityTier(rarity)
	table.insert(trackedTexts, {
		label = label,
		grad = grad,
		stroke = existingStroke,
		isPrimordial = pal.isPrimordial,
		speed = 2.0 + math.max(0, tier - 6) * 0.25,
	})
end

function RarityEffects.ApplyThumbnailBackdrop(frame: GuiObject, rarity: string, isDiscovered: boolean, mutation: string?)
	clearChildrenNamed(frame, "CosmicBackdropGroup")
	clearChildrenNamed(frame, "CosmicBgGradient")
	local existingStroke = frame:FindFirstChildOfClass("UIStroke")
	if existingStroke then
		clearChildrenNamed(existingStroke, "CosmicStrokeGrad")
	end

	local pal = RarityEffects.GetRarityPalette(rarity)
	local tier = GameConfig.GetRarityTier(rarity)
	local mutInfo = if mutation and mutation ~= "None" then (GameConfig.MUTATIONS :: any)[mutation] else nil

	if not pal.isCosmicPlus then
		if isDiscovered then
			local baseCol = if mutInfo then mutInfo.color else pal.primary
			frame.BackgroundColor3 = baseCol:Lerp(Color3.fromRGB(238, 245, 255), 0.52)
			if existingStroke then
				existingStroke.Color = Color3.fromRGB(16, 22, 32)
				existingStroke.Thickness = 2
			end
		elseif tier >= 5 then
			-- Legendary / Mythic undiscovered silhouette glow
			local holder = Instance.new("Frame")
			holder.Name = "CosmicBackdropGroup"
			holder.Size = UDim2.fromScale(1, 1)
			holder.BackgroundColor3 = pal.deep
			holder.BorderSizePixel = 0
			holder.ClipsDescendants = true
			holder.ZIndex = math.max(1, frame.ZIndex)
			holder.Parent = frame
			local hc = Instance.new("UICorner")
			hc.CornerRadius = UDim.new(0, 8)
			hc.Parent = holder

			local bgGrad = Instance.new("UIGradient")
			bgGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, pal.primary:Lerp(Color3.new(1, 1, 1), 0.35)),
				ColorSequenceKeypoint.new(1, pal.primary:Lerp(Color3.fromRGB(58, 42, 16), 0.35)),
			})
			bgGrad.Rotation = 90
			bgGrad.Parent = holder

			local rays = Instance.new("ImageLabel")
			rays.Name = "Rays"
			rays.AnchorPoint = Vector2.new(0.5, 0.5)
			rays.Position = UDim2.fromScale(0.5, 0.5)
			rays.Size = UDim2.fromScale(1.75, 1.75)
			rays.BackgroundTransparency = 1
			rays.Image = RarityEffects.SUNBURST_ASSET_ID
			rays.ImageColor3 = pal.secondary
			rays.ImageTransparency = 0.45
			rays.ZIndex = holder.ZIndex + 1
			rays.Parent = holder

			frame.BackgroundColor3 = pal.primary
			if existingStroke then
				existingStroke.Color = Color3.fromRGB(22, 26, 36)
				existingStroke.Thickness = 2
			end
		else
			frame.BackgroundColor3 = Color3.fromRGB(58, 66, 84)
			if existingStroke then
				existingStroke.Color = Color3.fromRGB(22, 26, 36)
				existingStroke.Thickness = 2
			end
		end
		return
	end

	-- Cosmic+ (Cosmic..Primordial): deep cosmic nebula + animated rotating sunburst on BOTH discovered & ??? tiles
	startSharedLoop()
	frame.BackgroundColor3 = pal.deep

	local holder = Instance.new("Frame")
	holder.Name = "CosmicBackdropGroup"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.ZIndex = math.max(1, frame.ZIndex)
	holder.Parent = frame

	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 8)
	hc.Parent = holder

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, pal.deep),
		ColorSequenceKeypoint.new(0.55, pal.primary:Lerp(pal.deep, 0.35)),
		ColorSequenceKeypoint.new(1.0, pal.secondary:Lerp(Color3.fromRGB(16, 20, 46), 0.35)),
	})
	bgGrad.Rotation = 135
	bgGrad.Parent = holder

	local rays = Instance.new("ImageLabel")
	rays.Name = "SunburstRays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.85, 1.85)
	rays.BackgroundTransparency = 1
	rays.Image = RarityEffects.SUNBURST_ASSET_ID
	rays.ImageColor3 = pal.secondary:Lerp(Color3.new(1, 1, 1), 0.35)
	rays.ImageTransparency = if isDiscovered then 0.22 else 0.16
	rays.ZIndex = holder.ZIndex + 1
	rays.Parent = holder

	local rayGrad = Instance.new("UIGradient")
	rayGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, pal.primary),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1.0, pal.secondary),
	})
	rayGrad.Parent = rays

	-- Top soft vignette highlight
	local sheen = Instance.new("Frame")
	sheen.Size = UDim2.new(1, 0, 0.42, 0)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0.84
	sheen.BorderSizePixel = 0
	sheen.ZIndex = holder.ZIndex + 2
	sheen.Parent = holder
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = sheen

	local strokeGrad: UIGradient? = nil
	if existingStroke then
		existingStroke.Color = Color3.new(1, 1, 1)
		existingStroke.Thickness = if tier >= 11 then 3 else 2.5
		local sg = Instance.new("UIGradient")
		sg.Name = "CosmicStrokeGrad"
		sg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, pal.primary),
			ColorSequenceKeypoint.new(0.5, pal.secondary:Lerp(Color3.new(1, 1, 1), 0.5)),
			ColorSequenceKeypoint.new(1.0, pal.primary),
		})
		sg.Parent = existingStroke
		strokeGrad = sg
	end

	table.insert(trackedSunbursts, {
		img = rays,
		grad = rayGrad,
		strokeGrad = strokeGrad,
		speedDeg = 14 + math.max(0, tier - 6) * 3.5,
		isPrimordial = pal.isPrimordial,
	})
end

local function inspectWildBillboard(inst: Instance)
	if inst:IsA("BillboardGui") then
		local rarity = inst:GetAttribute("CosmicRarity")
		if typeof(rarity) == "string" and GameConfig.IsCosmicOrAbove(rarity) then
			for _, child in ipairs(inst:GetDescendants()) do
				if child:IsA("TextLabel") and (child.Name == "RarityLabel" or child.Name == "CrateTitleLabel") then
					RarityEffects.ApplyTextEffect(child, rarity)
				end
			end
		end
	end
end

function RarityEffects.BindWorldCrateEffects()
	if worldBound then
		return
	end
	worldBound = true
	task.spawn(function()
		local gw = workspace:WaitForChild("GameWorld", 15)
		if not gw then
			return
		end
		local cratesFolder = gw:WaitForChild("ActiveCrates", 15)
		if not cratesFolder then
			return
		end
		for _, desc in ipairs(cratesFolder:GetDescendants()) do
			inspectWildBillboard(desc)
		end
		cratesFolder.DescendantAdded:Connect(function(desc)
			task.defer(function()
				inspectWildBillboard(desc)
			end)
		end)
	end)
end

return RarityEffects
