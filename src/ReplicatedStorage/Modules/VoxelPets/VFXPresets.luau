--!strict
-- VFXPresets.luau
-- Anti-glare Trail, ParticleEmitter, and Mutation VFX builders (zero PointLights, LightEmission <= 0.22).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local VFXPresets = {}

local function createTrailPair(
	part: BasePart,
	a0Pos: Vector3,
	a1Pos: Vector3,
	colA: Color3,
	colB: Color3,
	lifetime: number,
	trailName: string
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
	tr.Color = ColorSequence.new(colA, colB)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
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
	trailName: string
)
	local span = Vector3.new(0, halfSpanY * s, 0)
	createTrailPair(wingTipL, offsetL * s + span, offsetL * s - span, colA, colB, lifetime, trailName)
	createTrailPair(wingTipR, offsetR * s + span, offsetR * s - span, colA, colB, lifetime, trailName)
end

function VFXPresets.AttachTailTrail(
	tailTip: BasePart,
	s: number,
	topOffset: Vector3,
	botOffset: Vector3,
	colA: Color3,
	colB: Color3,
	lifetime: number,
	trailName: string
)
	createTrailPair(tailTip, topOffset * s, botOffset * s, colA, colB, lifetime, trailName)
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
