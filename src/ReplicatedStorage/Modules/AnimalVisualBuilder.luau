--!strict
-- AnimalVisualBuilder.luau
-- Builds stylized blocky/cute 3D animal models & buried crates with dynamic sizeRatio & mutation VFX

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Shared.Types)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local AnimalConfig = require(script.Parent.Parent.Config.AnimalConfig)

local AnimalVisualBuilder = {}

local function makeBox(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function resolveMutationStyle(spec: Types.AnimalSpeciesDefinition, mutation: Types.AnimalMutation): (Color3, Color3, Enum.Material, number)
	if mutation == "Albino" then
		return Color3.fromRGB(248, 250, 255), Color3.fromRGB(232, 236, 244), Enum.Material.SmoothPlastic, 0
	elseif mutation == "Golden" then
		return Color3.fromRGB(255, 206, 54), Color3.fromRGB(235, 168, 28), Enum.Material.Metal, 0
	elseif mutation == "Diamond" then
		return Color3.fromRGB(116, 232, 255), Color3.fromRGB(198, 248, 255), Enum.Material.Ice, 0.18
	elseif mutation == "Neon" then
		return spec.bodyColor, Color3.fromRGB(84, 255, 188), Enum.Material.Neon, 0
	elseif mutation == "Rainbow" then
		return Color3.fromRGB(255, 118, 214), Color3.fromRGB(92, 245, 255), Enum.Material.SmoothPlastic, 0
	elseif mutation == "Celestial" then
		return Color3.fromRGB(72, 34, 138), Color3.fromRGB(255, 218, 96), Enum.Material.Neon, 0
	end
	return spec.bodyColor, spec.secondaryColor, Enum.Material.SmoothPlastic, 0
end

function AnimalVisualBuilder.BuildAnimalModel(speciesId: string, sizeRatio: number, mutation: Types.AnimalMutation, lowVFX: boolean?): Model
	local spec = AnimalConfig.GetById(speciesId) or AnimalConfig.ALL[1]
	local primaryCol, secondaryCol, mat, transparency = resolveMutationStyle(spec, mutation)
	local s = math.clamp(sizeRatio, 0.5, 6.0)

	local model = Instance.new("Model")
	model.Name = "Animal_" .. spec.id
	model:SetAttribute("SpeciesId", spec.id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("SizeRatio", s)

	-- Root pivot at bottom center
	local root = makeBox("Root", Vector3.new(2.2 * s, 1.5 * s, 2.8 * s), CFrame.new(0, 1.3 * s, 0), primaryCol, mat, model)
	root.Transparency = transparency
	model.PrimaryPart = root

	-- 4 Blocky Legs
	local legOffsets = {
		Vector3.new(-0.7 * s, 0.45 * s, -0.9 * s),
		Vector3.new(0.7 * s, 0.45 * s, -0.9 * s),
		Vector3.new(-0.7 * s, 0.45 * s, 0.9 * s),
		Vector3.new(0.7 * s, 0.45 * s, 0.9 * s),
	}
	for idx, off in ipairs(legOffsets) do
		local leg = makeBox("Leg_" .. idx, Vector3.new(0.55 * s, 0.9 * s, 0.55 * s), CFrame.new(off), secondaryCol, mat, model)
		leg.Transparency = transparency
	end

	-- Head & Snout (facing -Z forward)
	local headSize = if spec.shapeStyle == "Bear" then Vector3.new(2.0 * s, 1.8 * s, 1.8 * s) else Vector3.new(1.7 * s, 1.5 * s, 1.6 * s)
	local head = makeBox("Head", headSize, CFrame.new(0, 2.15 * s, -1.45 * s), primaryCol, mat, model)
	head.Transparency = transparency

	local snoutColor = if spec.shapeStyle == "Bird" then Color3.fromRGB(255, 186, 48) else secondaryCol
	local snoutSize = if spec.shapeStyle == "Bird" then Vector3.new(0.6 * s, 0.45 * s, 0.9 * s) else Vector3.new(1.0 * s, 0.65 * s, 0.7 * s)
	local snout = makeBox("Snout", snoutSize, CFrame.new(0, 1.9 * s, -2.35 * s), snoutColor, mat, model)
	snout.Transparency = transparency

	-- Cute Eyes
	for _, ex in { -0.45 * s, 0.45 * s } do
		makeBox("Eye", Vector3.new(0.28 * s, 0.34 * s, 0.2 * s), CFrame.new(ex, 2.35 * s, -2.26 * s), spec.eyeColor, Enum.Material.Neon, model)
	end

	-- Silhouette Details (Ears, Antlers, Wings, or Tail)
	if spec.shapeStyle == "Canine" or spec.shapeStyle == "Feline" or spec.shapeStyle == "Critter" then
		for _, ex in { -0.58 * s, 0.58 * s } do
			local ear = makeBox("Ear", Vector3.new(0.4 * s, 0.65 * s, 0.35 * s), CFrame.new(ex, 3.15 * s, -1.3 * s), secondaryCol, mat, model)
			ear.Transparency = transparency
		end
		local tail = makeBox("Tail", Vector3.new(0.55 * s, 0.55 * s, 1.2 * s), CFrame.new(0, 1.6 * s, 1.8 * s) * CFrame.Angles(math.rad(25), 0, 0), secondaryCol, mat, model)
		tail.Transparency = transparency
	elseif spec.shapeStyle == "Hooved" then
		for _, ex in { -0.6 * s, 0.6 * s } do
			makeBox("Horn", Vector3.new(0.26 * s, 0.95 * s, 0.26 * s), CFrame.new(ex, 3.25 * s, -1.2 * s) * CFrame.Angles(0, 0, math.rad(if ex < 0 then 14 else -14)), secondaryCol, Enum.Material.SmoothPlastic, model)
		end
	elseif spec.shapeStyle == "Bird" then
		for _, wx in { -1.3 * s, 1.3 * s } do
			local wing = makeBox("Wing", Vector3.new(0.45 * s, 1.1 * s, 1.8 * s), CFrame.new(wx, 1.45 * s, 0), secondaryCol, mat, model)
			wing.Transparency = transparency
		end
	elseif spec.shapeStyle == "Reptile" then
		local tail = makeBox("Tail", Vector3.new(0.8 * s, 0.55 * s, 1.9 * s), CFrame.new(0, 1.0 * s, 2.1 * s), secondaryCol, mat, model)
		tail.Transparency = transparency
		for sp = -0.5, 0.7, 0.6 do
			makeBox("Ridge", Vector3.new(0.35 * s, 0.4 * s, 0.4 * s), CFrame.new(0, 2.15 * s, sp * s), secondaryCol, mat, model)
		end
	end

	-- Mutation Sparkle / Celestial VFX
	if not lowVFX and (mutation == "Golden" or mutation == "Diamond" or mutation == "Rainbow" or mutation == "Celestial") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "MutationVFX"
		emitter.Rate = if mutation == "Celestial" then 14 else 7
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1.5, 3.5)
		emitter.Size = NumberSequence.new(0.35 * s, 0)
		local mutInfo = GameConfig.MUTATIONS[mutation]
		emitter.Color = ColorSequence.new(mutInfo.color)
		emitter.Parent = root
	end

	return model
end

function AnimalVisualBuilder.BuildBuriedCrate(rarity: Types.AnimalRarity, biomeId: string): Model
	local rarityColor = GameConfig.RARITY_COLORS[rarity] or Color3.fromRGB(168, 182, 172)
	local ca = ReplicatedStorage:FindFirstChild("CuratedAssets")
	local heroSrc = if ca then ca:FindFirstChild("Hero_PoacherCrate") else nil

	local crateModel = Instance.new("Model")
	crateModel.Name = "BuriedCrate_" .. rarity

	local basePart: Part
	if heroSrc and heroSrc:IsA("Model") then
		local clone = heroSrc:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.Color = d.Color:Lerp(rarityColor, 0.38)
			elseif d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		clone:PivotTo(CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(18), math.rad(12), math.rad(-14)))
		clone.Parent = crateModel
		basePart = Instance.new("Part")
		basePart.Name = "CrateRoot"
		basePart.Size = Vector3.new(5.5, 5.5, 5.5)
		basePart.Transparency = 1
		basePart.Anchored = true
		basePart.CanCollide = true
		basePart.CFrame = CFrame.new(0, 1.8, 0)
		basePart.Parent = crateModel
		crateModel.PrimaryPart = basePart
	else
		basePart = makeBox("CrateRoot", Vector3.new(5, 5, 5), CFrame.new(0, 1.8, 0) * CFrame.Angles(math.rad(18), 0, math.rad(-12)), rarityColor, Enum.Material.Wood, crateModel)
		basePart.CanCollide = true
		basePart.CanQuery = true
		crateModel.PrimaryPart = basePart
	end

	-- Top Iron Tow Ring (where Lasso Beam attaches)
	local ring = makeBox("TowRing", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.6, 0), rarityColor, Enum.Material.Neon, crateModel)
	ring.Shape = Enum.PartType.Ball

	-- Beacon Light Beam for Rare / Epic / Legendary / Mythic
	if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" then
		local beacon = makeBox("RarityBeacon", Vector3.new(1.4, 34, 1.4), CFrame.new(0, 19, 0), rarityColor, Enum.Material.Neon, crateModel)
		beacon.Transparency = 0.72
	end

	return crateModel
end

return AnimalVisualBuilder
