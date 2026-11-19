--!strict
-- VFXPresets.luau
-- Anti-glare Trail, ParticleEmitter, and Mutation VFX builders (zero PointLights, LightEmission <= 0.22).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local VFXPresets = {}

export type VFXStudioAuraParts = {
	root: BasePart,
	torso: BasePart,
	head: BasePart?,
	wingTipL: BasePart?,
	wingTipR: BasePart?,
}

export type VFXStudioAuraConfig = {
	primaryColor: Color3,
	secondaryColor: Color3,
	accentColor: Color3,
	flareColor: Color3?,
	sigilRadiusScale: number?,
	haloScale: number?,
	crownOffset: Vector3?,
	wingDustOffsetL: Vector3?,
	wingDustOffsetR: Vector3?,
	outerSigilTex: string?,
	innerSigilTex: string?,
}

local function createTrailPair(
	part: BasePart,
	a0Pos: Vector3,
	a1Pos: Vector3,
	colA: Color3,
	colB: Color3,
	lifetime: number,
	trailName: string,
	textureId: string?
)
	local a0 = Instance.new("Attachment")
	a0.Position = a0Pos
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = a1Pos
	a1.Parent = part

	local tr = Instance.new("Trail")
	tr.Name = trailName
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = lifetime
	tr.MinLength = 0.12
	tr.LightEmission = 0.22
	tr.FaceCamera = true
	if textureId and textureId ~= "" then
		tr.Texture = textureId
		tr.TextureMode = Enum.TextureMode.Stretch
	end
	tr.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.0),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	tr.Color = ColorSequence.new(colA, colB)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr:SetAttribute("VFXStudioAura", true)
	tr.Parent = part
end

function VFXPresets.AttachWingTrails(
	wingTipL: BasePart,
	wingTipR: BasePart,
	s: number,
	offsetL: Vector3,
	offsetR: Vector3,
	halfSpanY: number,
	colA: Color3,
	colB: Color3,
	lifetime: number,
	trailName: string,
	textureId: string?
)
	local span = Vector3.new(0, halfSpanY * s, 0)
	createTrailPair(wingTipL, offsetL * s + span, offsetL * s - span, colA, colB, lifetime, trailName, textureId)
	createTrailPair(wingTipR, offsetR * s + span, offsetR * s - span, colA, colB, lifetime, trailName, textureId)
end

function VFXPresets.AttachTailTrail(
	tailTip: BasePart,
	s: number,
	topOffset: Vector3,
	botOffset: Vector3,
	colA: Color3,
	colB: Color3,
	lifetime: number,
	trailName: string,
	textureId: string?
)
	createTrailPair(tailTip, topOffset * s, botOffset * s, colA, colB, lifetime, trailName, textureId)
end

function VFXPresets.AttachVFXStudioAura(parts: VFXStudioAuraParts, s: number, cfg: VFXStudioAuraConfig)
	local flareCol = cfg.flareColor or cfg.accentColor
	local rScale = s * (cfg.sigilRadiusScale or 1.0)
	local hScale = s * (cfg.haloScale or 1.0)
	local rootFloorY = -parts.root.Size.Y * 0.5

	-- Layer 1: Horizontal Ground Magic Sigils (VFXStudio_GroundAura on parts.root)
	local groundAtt = Instance.new("Attachment")
	groundAtt.Name = "VFXStudio_GroundAura"
	groundAtt.Position = Vector3.new(0, rootFloorY + 0.05 * s, 0)
	groundAtt.Parent = parts.root

	local sigilOuter = Instance.new("ParticleEmitter")
	sigilOuter.Name = "SigilOuter"
	sigilOuter.Texture = cfg.outerSigilTex or "rbxassetid://16618677089"
	sigilOuter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	sigilOuter.EmissionDirection = Enum.NormalId.Top
	sigilOuter.LockedToPart = true
	sigilOuter.Speed = NumberRange.new(0.012, 0.012)
	sigilOuter.SpreadAngle = Vector2.zero
	sigilOuter.Rate = 1.25
	sigilOuter.Lifetime = NumberRange.new(2.4, 2.4)
	sigilOuter.RotSpeed = NumberRange.new(20, 20)
	sigilOuter.LightEmission = 0.72
	sigilOuter.LightInfluence = 0.15
	sigilOuter.ZOffset = -0.02
	sigilOuter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.primaryColor),
		ColorSequenceKeypoint.new(0.5, cfg.secondaryColor),
		ColorSequenceKeypoint.new(1, cfg.accentColor),
	})
	sigilOuter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.8 * rScale),
		NumberSequenceKeypoint.new(0.5, 4.4 * rScale),
		NumberSequenceKeypoint.new(1, 4.0 * rScale),
	})
	sigilOuter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.22),
		NumberSequenceKeypoint.new(0.8, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	sigilOuter:SetAttribute("VFXStudioAura", true)
	sigilOuter.Parent = groundAtt

	local sigilInner = Instance.new("ParticleEmitter")
	sigilInner.Name = "SigilInner"
	sigilInner.Texture = cfg.innerSigilTex or "rbxassetid://93858335764593"
	sigilInner.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	sigilInner.EmissionDirection = Enum.NormalId.Top
	sigilInner.LockedToPart = true
	sigilInner.Speed = NumberRange.new(0.012, 0.012)
	sigilInner.SpreadAngle = Vector2.zero
	sigilInner.Rate = 1.25
	sigilInner.Lifetime = NumberRange.new(2.4, 2.4)
	sigilInner.RotSpeed = NumberRange.new(-32, -32)
	sigilInner.ZOffset = 0.04
	sigilInner.LightEmission = 0.78
	sigilInner.LightInfluence = 0.10
	sigilInner.Color = ColorSequence.new(flareCol, cfg.primaryColor)
	sigilInner.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5 * rScale),
		NumberSequenceKeypoint.new(0.5, 2.85 * rScale),
		NumberSequenceKeypoint.new(1, 2.6 * rScale),
	})
	sigilInner.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.18),
		NumberSequenceKeypoint.new(0.8, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	sigilInner:SetAttribute("VFXStudioAura", true)
	sigilInner.Parent = groundAtt

	-- Layer 2: 360 Cylindrical Scrolling Floor Aura Ring
	local ringR = 1.85 * rScale
	local ringY = rootFloorY + 0.36 * s
	local ringAttL = Instance.new("Attachment")
	ringAttL.Name = "VFXStudio_RingAttL"
	ringAttL.Position = Vector3.new(-ringR, ringY, 0)
	ringAttL.Axis = Vector3.new(0, 0, -1)
	ringAttL.SecondaryAxis = Vector3.new(0, 1, 0)
	ringAttL.Parent = parts.root

	local ringAttR = Instance.new("Attachment")
	ringAttR.Name = "VFXStudio_RingAttR"
	ringAttR.Position = Vector3.new(ringR, ringY, 0)
	ringAttR.Axis = Vector3.new(0, 0, -1)
	ringAttR.SecondaryAxis = Vector3.new(0, 1, 0)
	ringAttR.Parent = parts.root

	local beamColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.primaryColor),
		ColorSequenceKeypoint.new(0.5, cfg.secondaryColor),
		ColorSequenceKeypoint.new(1, cfg.primaryColor),
	})
	for _, bSpec in ipairs({
		{ name = "FloorAuraBeamFront", curve = ringR * 1.333, speed = 0.75 },
		{ name = "FloorAuraBeamBack", curve = -ringR * 1.333, speed = -0.75 },
	}) do
		local beam = Instance.new("Beam")
		beam.Name = bSpec.name
		beam.Attachment0 = ringAttL
		beam.Attachment1 = ringAttR
		beam.CurveSize0 = bSpec.curve
		beam.CurveSize1 = bSpec.curve
		beam.TextureSpeed = bSpec.speed
		beam.Texture = "rbxassetid://81622479142639"
		beam.TextureLength = 2
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.Segments = 24
		beam.FaceCamera = false
		beam.Width0 = 0.72 * s
		beam.Width1 = 0.72 * s
		beam.LightEmission = 0.68
		beam.LightInfluence = 0.15
		beam.Color = beamColor
		beam.Transparency = NumberSequence.new(0.36)
		beam:SetAttribute("VFXStudioAura", true)
		beam.Parent = parts.root
	end

	-- Layer 3: Volumetric Core Glow & Rising Flipbook Wisps (VFXStudio_BodyAura on parts.torso)
	local bodyAtt = Instance.new("Attachment")
	bodyAtt.Name = "VFXStudio_BodyAura"
	bodyAtt.Position = Vector3.new(0, 0.15 * s, 0)
	bodyAtt.Parent = parts.torso

	local coreHalo = Instance.new("ParticleEmitter")
	coreHalo.Name = "CoreHaloGlow"
	coreHalo.Texture = "rbxassetid://1360388830"
	coreHalo.LockedToPart = true
	coreHalo.ZOffset = -0.65 * s
	coreHalo.Rate = 3
	coreHalo.Lifetime = NumberRange.new(1.5, 1.9)
	coreHalo.Speed = NumberRange.new(0.05, 0.15)
	coreHalo.SpreadAngle = Vector2.new(180, 180)
	coreHalo.LightEmission = 0.55
	coreHalo.Color = ColorSequence.new(cfg.primaryColor, cfg.secondaryColor)
	coreHalo.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.4 * hScale),
		NumberSequenceKeypoint.new(0.5, 3.1 * hScale),
		NumberSequenceKeypoint.new(1, 2.5 * hScale),
	})
	coreHalo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.68),
		NumberSequenceKeypoint.new(0.7, 0.70),
		NumberSequenceKeypoint.new(1, 1),
	})
	coreHalo:SetAttribute("VFXStudioAura", true)
	coreHalo.Parent = bodyAtt

	local risingFlip = Instance.new("ParticleEmitter")
	risingFlip.Name = "RisingAuraFlipbook"
	risingFlip.Texture = "rbxassetid://17612127081"
	risingFlip.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	risingFlip.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	risingFlip.FlipbookFramerate = NumberRange.new(12, 16)
	risingFlip.Orientation = Enum.ParticleOrientation.VelocityParallel
	risingFlip.EmissionDirection = Enum.NormalId.Top
	risingFlip.Rate = 9
	risingFlip.Lifetime = NumberRange.new(0.85, 1.25)
	risingFlip.Speed = NumberRange.new(1.5 * hScale, 2.7 * hScale)
	risingFlip.SpreadAngle = Vector2.new(32, 32)
	risingFlip.Acceleration = Vector3.new(0, 1.6 * hScale, 0)
	risingFlip.LightEmission = 0.65
	risingFlip.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.primaryColor),
		ColorSequenceKeypoint.new(0.55, cfg.secondaryColor),
		ColorSequenceKeypoint.new(1, cfg.accentColor),
	})
	risingFlip.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75 * hScale),
		NumberSequenceKeypoint.new(0.45, 1.65 * hScale),
		NumberSequenceKeypoint.new(1, 0.25 * hScale),
	})
	risingFlip.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.25, 0.30),
		NumberSequenceKeypoint.new(0.75, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	})
	risingFlip:SetAttribute("VFXStudioAura", true)
	risingFlip.Parent = bodyAtt

	local squiggly = Instance.new("ParticleEmitter")
	squiggly.Name = "SquigglyWispFlipbook"
	squiggly.Texture = "rbxassetid://136218893343214"
	squiggly.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
	squiggly.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	squiggly.Rate = 7
	squiggly.Lifetime = NumberRange.new(0.8, 1.2)
	squiggly.Speed = NumberRange.new(0.9 * s, 1.9 * s)
	squiggly.SpreadAngle = Vector2.new(115, 115)
	squiggly.Acceleration = Vector3.new(0, 2.2 * s, 0)
	squiggly.RotSpeed = NumberRange.new(-35, 35)
	squiggly.LightEmission = 0.72
	squiggly.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.accentColor),
		ColorSequenceKeypoint.new(0.5, cfg.primaryColor),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	squiggly.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55 * s),
		NumberSequenceKeypoint.new(0.5, 1.35 * s),
		NumberSequenceKeypoint.new(1, 0.15 * s),
	})
	squiggly.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(0.25, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	squiggly:SetAttribute("VFXStudioAura", true)
	squiggly.Parent = bodyAtt

	local faeStars = Instance.new("ParticleEmitter")
	faeStars.Name = "FaeStarsFlipbook"
	faeStars.Texture = "rbxassetid://14032952906"
	faeStars.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	faeStars.Rate = 10
	faeStars.Lifetime = NumberRange.new(1.1, 1.7)
	faeStars.Speed = NumberRange.new(1.1 * s, 2.5 * s)
	faeStars.SpreadAngle = Vector2.new(180, 180)
	faeStars.RotSpeed = NumberRange.new(-55, 55)
	faeStars.Drag = 1.8
	faeStars.Acceleration = Vector3.new(0, 0.9 * s, 0)
	faeStars.LightEmission = 0.82
	faeStars.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, flareCol),
		ColorSequenceKeypoint.new(0.5, cfg.accentColor),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	faeStars.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14 * s),
		NumberSequenceKeypoint.new(0.45, 0.48 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	faeStars.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.3, 0.06),
		NumberSequenceKeypoint.new(1, 1),
	})
	faeStars:SetAttribute("VFXStudioAura", true)
	faeStars.Parent = bodyAtt

	-- Layer 4: Crown Antler Star Flares & Lacewing Shimmer
	if parts.head then
		local crownAtt = Instance.new("Attachment")
		crownAtt.Name = "VFXStudio_CrownAura"
		crownAtt.Position = (cfg.crownOffset or Vector3.new(0, 0.42, 0.38)) * s
		crownAtt.Parent = parts.head

		local crownFlare = Instance.new("ParticleEmitter")
		crownFlare.Name = "CrownStarFlares"
		crownFlare.Texture = "rbxassetid://14032952906"
		crownFlare.Rate = 5
		crownFlare.Lifetime = NumberRange.new(0.9, 1.4)
		crownFlare.Speed = NumberRange.new(0.35 * hScale, 0.95 * hScale)
		crownFlare.SpreadAngle = Vector2.new(180, 180)
		crownFlare.RotSpeed = NumberRange.new(-50, 50)
		crownFlare.LightEmission = 0.85
		crownFlare.Color = ColorSequence.new(flareCol, cfg.accentColor)
		crownFlare.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08 * hScale),
			NumberSequenceKeypoint.new(0.4, 0.38 * hScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		crownFlare.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.35, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		crownFlare:SetAttribute("VFXStudioAura", true)
		crownFlare.Parent = crownAtt
	end

	for _, wSpec in ipairs({
		{
			part = parts.wingTipL,
			offset = cfg.wingDustOffsetL or Vector3.new(-0.45, 0.9, 0.65),
			name = "VFXStudio_WingDustL",
		},
		{
			part = parts.wingTipR,
			offset = cfg.wingDustOffsetR or Vector3.new(0.45, 0.9, 0.65),
			name = "VFXStudio_WingDustR",
		},
	}) do
		if wSpec.part then
			local wingAtt = Instance.new("Attachment")
			wingAtt.Name = wSpec.name
			wingAtt.Position = wSpec.offset * s
			wingAtt.Parent = wSpec.part

			local dust = Instance.new("ParticleEmitter")
			dust.Name = "WingSparkleDust"
			dust.Texture = "rbxassetid://14032952906"
			dust.Rate = 5
			dust.Lifetime = NumberRange.new(0.7, 1.1)
			dust.Speed = NumberRange.new(0.4 * hScale, 1.1 * hScale)
			dust.SpreadAngle = Vector2.new(180, 180)
			dust.RotSpeed = NumberRange.new(-45, 45)
			dust.LightEmission = 0.80
			dust.Color = ColorSequence.new(cfg.primaryColor, flareCol)
			dust.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.10 * hScale),
				NumberSequenceKeypoint.new(0.45, 0.34 * hScale),
				NumberSequenceKeypoint.new(1, 0),
			})
			dust.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.22),
				NumberSequenceKeypoint.new(0.4, 0.08),
				NumberSequenceKeypoint.new(1, 1),
			})
			dust:SetAttribute("VFXStudioAura", true)
			dust.Parent = wingAtt
		end
	end
end

function VFXPresets.AttachBodyAura(
	torso: BasePart,
	s: number,
	unscaledOffset: Vector3,
	emitterName: string,
	colors: { Color3 },
	rate: number,
	peakSize: number
)
	local c0 = colors[1] or Color3.new(1, 1, 1)
	local c1 = colors[2] or c0
	local c2 = colors[3] or c1

	local vfxAtt = Instance.new("Attachment")
	vfxAtt.Position = unscaledOffset * s
	vfxAtt.Parent = torso

	local pe = Instance.new("ParticleEmitter")
	pe.Name = emitterName
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(1.0, 2.0)
	pe.Speed = NumberRange.new(0.8, 2.4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.22
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c0),
		ColorSequenceKeypoint.new(0.5, c1),
		ColorSequenceKeypoint.new(1, c2),
	})
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.20 * s),
		NumberSequenceKeypoint.new(0.5, peakSize * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Parent = vfxAtt
end

function VFXPresets.AttachMutationVFX(model: Model, s: number, mutation: Types.AnimalMutation)
	if mutation == "None" then
		return
	end
	local mutInfo = (GameConfig.MUTATIONS :: any)[mutation]
	local mutCol = (mutInfo and mutInfo.color) or Color3.new(1, 1, 1)
	local root = model.PrimaryPart
	if root then
		local mpe = Instance.new("ParticleEmitter")
		mpe.Name = "MutationVFX"
		mpe.Rate = 6
		mpe.Lifetime = NumberRange.new(0.8, 1.4)
		mpe.Speed = NumberRange.new(1.2, 2.8)
		mpe.SpreadAngle = Vector2.new(360, 360)
		mpe.LightEmission = 0.20
		mpe.Color = ColorSequence.new(mutCol, Color3.new(1, 1, 1))
		mpe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28 * s),
			NumberSequenceKeypoint.new(1, 0),
		})
		mpe.Parent = root
	end
	local hl = Instance.new("Highlight")
	hl.Name = "MutationHighlight"
	hl.Adornee = model
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.FillColor = mutCol
	hl.FillTransparency = 0.90
	hl.OutlineColor = mutCol
	hl.OutlineTransparency = 0.40
	hl.Parent = model
end

return VFXPresets
