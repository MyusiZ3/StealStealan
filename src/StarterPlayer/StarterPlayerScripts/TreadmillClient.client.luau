--!strict
-- TreadmillClient.client.luau
-- Snaps character onto TreadmillStandAnchor when entering Treadmill zone,
-- plays looped Running animation + speed sparks, and lets player hop off by pressing Space / Jump.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local onTreadmill = false
local treadmillEnteredAt = 0
local snapCFrame: CFrame? = nil
local activeRunTrack: AnimationTrack? = nil
local hopOffGui: ScreenGui? = nil
local boostBadge: TextLabel? = nil
local activeBubble: TextButton? = nil
local nextBubbleAt = 0
local footSparkEmitter: ParticleEmitter? = nil
local savedAutoRotate = true
local standingHipHeight = 2.0

local R15_RUN_ANIM = "rbxassetid://507767714"
local R6_RUN_ANIM = "rbxassetid://180426354"

local exitTreadmillClient: (boolean) -> ()

local function destroyActiveBubble()
	if activeBubble then
		activeBubble:Destroy()
		activeBubble = nil
	end
end

local function isBoostActive(): boolean
	local endsAt = tonumber(localPlayer:GetAttribute("TreadmillBoostEndsAt")) or 0
	return endsAt > math.floor(Workspace:GetServerTimeNow())
end

local function ensureHopOffUI()
	if hopOffGui then return end
	local sg = Instance.new("ScreenGui")
	sg.Name = "TreadmillOverlay"
	sg.ResetOnSpawn = false
	sg.Enabled = false
	sg.Parent = playerGui

	local badge = Instance.new("TextLabel")
	badge.Name = "BoostBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0.14, 0)
	badge.Size = UDim2.fromOffset(310, 38)
	badge.BackgroundColor3 = Color3.fromRGB(16, 48, 72)
	badge.BackgroundTransparency = 0.15
	badge.Text = "⚡ x3 TREADMILL SPEED (15s)"
	badge.TextColor3 = Color3.fromRGB(88, 238, 255)
	badge.Font = Enum.Font.FredokaOne
	badge.TextScaled = true
	badge.Visible = false
	badge.Parent = sg
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 12)
	local bSt = Instance.new("UIStroke")
	bSt.Thickness = 2.5
	bSt.Color = Color3.fromRGB(255, 212, 64)
	bSt.Parent = badge
	boostBadge = badge

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(240, 40)
	btn.Position = UDim2.new(0.5, -120, 0.78, 0)
	btn.BackgroundColor3 = Color3.fromRGB(224, 58, 52)
	btn.Text = "JUMP / CLICK TO HOP OFF"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 15
	btn.Parent = sg
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(14, 15, 18)
	st.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if onTreadmill then
			exitTreadmillClient(true)
		end
	end)
	hopOffGui = sg
end

local function spawnSpeedBubble()
	if not onTreadmill then return end
	ensureHopOffUI()
	if not hopOffGui then return end
	destroyActiveBubble()

	local rx = 0.25 + math.random() * 0.50
	local b = Instance.new("TextButton")
	b.Name = "SpeedBoostBubble"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(rx, 0.58)
	b.Size = UDim2.fromOffset(118, 118)
	b.BackgroundColor3 = Color3.fromRGB(32, 198, 255)
	b.BackgroundTransparency = 0.08
	b.AutoButtonColor = true
	b.Text = "⚡ x3\nSPEED!\n(CLICK)"
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 19
	b.ZIndex = 20
	b.Parent = hopOffGui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)

	local st = Instance.new("UIStroke")
	st.Thickness = 3.5
	st.Color = Color3.fromRGB(255, 212, 62)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	local tst = Instance.new("UIStroke")
	tst.Thickness = 2.6
	tst.Color = Color3.fromRGB(10, 16, 28)
	tst.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	tst.Parent = b

	activeBubble = b
	TweenService:Create(b, TweenInfo.new(5.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(rx, 0.32),
	}):Play()

	local claimed = false
	b.MouseButton1Click:Connect(function()
		if claimed or not b.Parent then return end
		claimed = true
		Remotes.Get("TrainingTapOrb"):FireServer("BubbleBoost")
		TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(152, 152),
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		task.delay(0.2, function()
			if activeBubble == b then
				activeBubble = nil
			end
			if b.Parent then b:Destroy() end
		end)
	end)

	task.delay(5.5, function()
		if b.Parent and not claimed then
			if activeBubble == b then activeBubble = nil end
			b:Destroy()
		end
	end)
end

local function stopTreadmillAnim()
	destroyActiveBubble()
	if boostBadge then
		boostBadge.Visible = false
	end
	if activeRunTrack then
		pcall(function()
			activeRunTrack:Stop(0.15)
			activeRunTrack:Destroy()
		end)
		activeRunTrack = nil
	end
	if footSparkEmitter then
		footSparkEmitter.Enabled = false
		footSparkEmitter:Destroy()
		footSparkEmitter = nil
	end
	if hopOffGui then
		hopOffGui.Enabled = false
	end
end

exitTreadmillClient = function(notifyServer: boolean)
	if not onTreadmill and not snapCFrame then
		return
	end
	onTreadmill = false
	local exitCF = snapCFrame
	snapCFrame = nil
	stopTreadmillAnim()

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if hum then
		hum.AutoRotate = savedAutoRotate
	end
	if root and root:IsA("BasePart") then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if exitCF then
			-- Step cleanly behind the treadmill deck (+7.8 behind local look direction)
			root.CFrame = exitCF * CFrame.new(0, 0.5, 7.8)
		end
	end
	if notifyServer then
		Remotes.Get("TreadmillState"):FireServer(false)
	end
end

local function startTreadmillAnim()
	stopTreadmillAnim()
	ensureHopOffUI()
	if hopOffGui then
		hopOffGui.Enabled = true
	end

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not hum or not root or not root:IsA("BasePart") then return end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = if hum.RigType == Enum.HumanoidRigType.R15 then R15_RUN_ANIM else R6_RUN_ANIM
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	anim:Destroy()
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.1, 1, 2.2)
		activeRunTrack = track
	end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "TreadmillSparks"
	sparks.Rate = 18
	sparks.Lifetime = NumberRange.new(0.25, 0.45)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.Color = ColorSequence.new(Color3.fromRGB(64, 224, 255), Color3.fromRGB(255, 255, 255))
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.EmissionDirection = Enum.NormalId.Back
	sparks.Parent = root
	footSparkEmitter = sparks
end

Remotes.Get("TreadmillState").OnClientEvent:Connect(function(active: boolean, targetCF: CFrame?, beltSurfaceY: number?)
	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if active and targetCF then
		if onTreadmill then return end
		onTreadmill = true
		treadmillEnteredAt = os.clock()
		local finalCF = targetCF
		if hum and root and root:IsA("BasePart") then
			savedAutoRotate = hum.AutoRotate
			hum.AutoRotate = false
			-- Always use clean standing hipHeight so feet sit 0.00 studs flush on belt without up/down bounce
			local attrHip = tonumber(localPlayer:GetAttribute("StandingHipHeight"))
			local cleanHip = if attrHip and (attrHip > 0.4 or hum.RigType == Enum.HumanoidRigType.R6)
				then attrHip
				elseif localPlayer:GetAttribute("IsRidingVehicle") ~= true and tostring(localPlayer:GetAttribute("MountedAnimalUid") or "") == ""
				then hum.HipHeight
				else standingHipHeight
			standingHipHeight = cleanHip
			hum.HipHeight = cleanHip
			if type(beltSurfaceY) == "number" then
				local footOffset = if hum.RigType == Enum.HumanoidRigType.R6 then 3.0 else (cleanHip + root.Size.Y * 0.5)
				local rotOnly = targetCF - targetCF.Position
				finalCF = CFrame.new(targetCF.Position.X, beltSurfaceY + footOffset, targetCF.Position.Z) * rotOnly
			end
			-- Ensure any attached held/carried parts are completely massless & non-colliding
			for _, desc in ipairs(char:GetDescendants()) do
				if desc:IsA("BasePart") and (desc.Name == "ClientHeldItemModel" or string.find(desc.Name, "Crate") or desc:FindFirstAncestor("ClientHeldItemModel") or desc:FindFirstAncestor("ClientCarriedCrate")) then
					desc.CanCollide = false
					desc.CanTouch = false
					desc.CanQuery = false
					desc.Massless = true
				end
			end
		end
		snapCFrame = finalCF
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.CFrame = finalCF
			root.Anchored = true
		end
		if hum then
			hum:Move(Vector3.zero)
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end)
		end
		startTreadmillAnim()
		nextBubbleAt = os.clock() + math.random(15, 22)
	else
		exitTreadmillClient(false)
	end
end)

UserInputService.JumpRequest:Connect(function()
	if onTreadmill then
		exitTreadmillClient(true)
	end
end)

-- Client-side Voxel Treadmill Belt + LV 8-12 SpecialEffects Animator across visible SanctuaryHub Plots
type BeltRigCache = {
	model: Model,
	level: number,
	originCF: CFrame,
	beltStartZ: number,
	beltEndZ: number,
	beltY: number,
	beltSpeed: number,
	segments: { { startFrac: number, parts: { { part: BasePart, relToPrimary: CFrame } } } },
	rings: { { centerY: number, centerZ: number, radius: number, tiltRad: number, spinSpeed: number, parts: { { part: BasePart, baseAngle: number } } } },
	bobs: { { part: BasePart, baseLocalPos: Vector3, phase: number, isFragment: boolean } },
	portal: { centerY: number, centerZ: number, core: BasePart?, rimParts: { { part: BasePart, baseAngle: number, radius: number } } }?,
	primordialCore: { part: BasePart, baseSize: Vector3 }?,
	chains: { { part: BasePart, baseLocalPos: Vector3, linkIdx: number, side: number } },
}
local beltRigs: { [Model]: BeltRigCache } = {}

local function registerPlotTreadmillRig(tm: Model)
	if beltRigs[tm] or not tm:IsA("Model") then return end
	if tm:GetAttribute("VoxelTreadmill") ~= true then return end
	local sc = tonumber(tm:GetAttribute("TreadScale")) or 1.0
	local lv = tonumber(tm:GetAttribute("Level")) or 1
	local originCF = tm:GetPivot()
	local invOrigin = originCF:Inverse()

	local runningBelt = tm:FindFirstChild("RunningBelt")
	local beltBed = if runningBelt then runningBelt:FindFirstChild("BeltBed") else nil
	local beltStartZ = (if beltBed then tonumber(beltBed:GetAttribute("BeltStartZ")) else nil or 4.7) * sc
	local beltEndZ = (if beltBed then tonumber(beltBed:GetAttribute("BeltEndZ")) else nil or -5.8) * sc
	local beltY = (if beltBed then tonumber(beltBed:GetAttribute("BeltY")) else nil or 1.325) * sc

	local segments = {}
	local segFolder = tm:FindFirstChild("BeltSegments")
	if segFolder then
		for _, segModel in ipairs(segFolder:GetChildren()) do
			if segModel:IsA("Model") and segModel.PrimaryPart then
				local invP = segModel.PrimaryPart.CFrame:Inverse()
				local parts = {}
				for _, d in ipairs(segModel:GetDescendants()) do
					if d:IsA("BasePart") then
						table.insert(parts, { part = d, relToPrimary = invP * d.CFrame })
					end
				end
				table.insert(segments, {
					startFrac = tonumber(segModel:GetAttribute("StartFrac")) or 0,
					parts = parts,
				})
			end
		end
	end

	local rings, bobs, chains = {}, {}, {}
	local portal: any = nil
	local primordialCore: any = nil
	local sf = tm:FindFirstChild("SpecialEffects")
	if sf and lv >= 8 then
		for _, child in ipairs(sf:GetChildren()) do
			if child:IsA("Model") and (string.find(child.Name, "Ring") or child.Name == "DivineHalo") then
				local cY = (tonumber(child:GetAttribute("RingCenterY")) or 5.0) * sc
				local cZ = (tonumber(child:GetAttribute("RingCenterZ")) or 4.8) * sc
				local rad = (tonumber(child:GetAttribute("RingRadius")) or 3.5) * sc
				local tilt = math.rad(tonumber(child:GetAttribute("TiltDeg")) or 0)
				local spd = tonumber(child:GetAttribute("SpinSpeed")) or 1.0
				local rParts = {}
				for _, p in ipairs(child:GetChildren()) do
					if p:IsA("BasePart") then
						local lp = (invOrigin * p.CFrame).Position
						table.insert(rParts, { part = p, baseAngle = math.atan2(lp.Z - cZ, lp.X) })
					end
				end
				table.insert(rings, { centerY = cY, centerZ = cZ, radius = rad, tiltRad = tilt, spinSpeed = spd, parts = rParts })
			elseif child:IsA("BasePart") and (string.find(child.Name, "FloatingOrb") or string.find(child.Name, "FloatingFrag")) then
				table.insert(bobs, {
					part = child,
					baseLocalPos = (invOrigin * child.CFrame).Position,
					phase = tonumber(child:GetAttribute("Phase")) or 0,
					isFragment = string.find(child.Name, "FloatingFrag") ~= nil,
				})
			elseif child:IsA("Model") and child.Name == "SingularityPortal" then
				local cY = (tonumber(child:GetAttribute("PortalCenterY")) or 6.9) * sc
				local cZ = (tonumber(child:GetAttribute("PortalCenterZ")) or 5.0) * sc
				local rimParts = {}
				local corePart: BasePart? = nil
				for _, p in ipairs(child:GetChildren()) do
					if p:IsA("BasePart") then
						if p.Name == "BlackHoleCore" then
							corePart = p
						else
							local lp = (invOrigin * p.CFrame).Position
							table.insert(rimParts, { part = p, baseAngle = math.atan2(lp.Y - cY, lp.X), radius = Vector2.new(lp.X, lp.Y - cY).Magnitude })
						end
					end
				end
				portal = { centerY = cY, centerZ = cZ, core = corePart, rimParts = rimParts }
			elseif child:IsA("BasePart") and child.Name == "PrimordialCore" then
				primordialCore = { part = child, baseSize = child.Size }
			elseif child:IsA("Model") and string.find(child.Name, "PrimordialChain") then
				local side = tonumber(child:GetAttribute("BaseSide")) or 1
				for _, p in ipairs(child:GetChildren()) do
					if p:IsA("BasePart") then
						table.insert(chains, { part = p, baseLocalPos = (invOrigin * p.CFrame).Position, linkIdx = tonumber(p:GetAttribute("LinkIdx")) or 0, side = side })
					end
				end
			end
		end
	end

	beltRigs[tm] = {
		model = tm,
		level = lv,
		originCF = originCF,
		beltStartZ = beltStartZ,
		beltEndZ = beltEndZ,
		beltY = beltY,
		beltSpeed = 0.42 + (lv - 1) * 0.04,
		segments = segments,
		rings = rings,
		bobs = bobs,
		portal = portal,
		primordialCore = primordialCore,
		chains = chains,
	}
end

local rigScanAccum = 0
local animElapsed = 0

RunService.RenderStepped:Connect(function(dt: number)
	animElapsed += dt
	rigScanAccum += dt
	if rigScanAccum >= 0.8 then
		rigScanAccum = 0
		for tm in pairs(beltRigs) do
			if not tm.Parent then
				beltRigs[tm] = nil
			end
		end
		local gw = Workspace:FindFirstChild("GameWorld")
		local hub = if gw then gw:FindFirstChild("SanctuaryHub") else nil
		local plots = if hub then hub:FindFirstChild("Plots") else nil
		if plots then
			for _, plotM in ipairs(plots:GetChildren()) do
				local tm = plotM:FindFirstChild("TreadmillVisual")
				if tm and tm:IsA("Model") and not beltRigs[tm] then
					registerPlotTreadmillRig(tm)
				end
			end
		end
	end

	local boosted = isBoostActive()
	for tm, rig in pairs(beltRigs) do
		if tm.Parent and (not rig.model.PrimaryPart or rig.model.PrimaryPart.Transparency < 1) then
			local plotM = tm.Parent
			local ownerId = if plotM then tonumber(plotM:GetAttribute("OwnerUserId")) else 0
			local speedMult = if boosted and ownerId == localPlayer.UserId then 2.2 else 1.0
			local spanZ = rig.beltStartZ - rig.beltEndZ
			local originCF = rig.originCF
			for _, seg in ipairs(rig.segments) do
				local frac = (seg.startFrac + animElapsed * rig.beltSpeed * speedMult) % 1
				local zLocal = rig.beltStartZ - frac * spanZ
				local pWorld = originCF * CFrame.new(0, rig.beltY, zLocal)
				for _, po in ipairs(seg.parts) do
					po.part.CFrame = pWorld * po.relToPrimary
				end
			end
			if rig.level >= 8 then
				for _, ring in ipairs(rig.rings) do
					local centerCF = originCF * CFrame.new(0, ring.centerY, ring.centerZ) * CFrame.Angles(ring.tiltRad, 0, ring.tiltRad * 0.6)
					local spin = animElapsed * ring.spinSpeed
					for _, rp in ipairs(ring.parts) do
						local ang = rp.baseAngle + spin
						local lp = Vector3.new(math.cos(ang) * ring.radius, 0, math.sin(ang) * ring.radius)
						rp.part.CFrame = centerCF * CFrame.lookAt(lp, Vector3.zero)
					end
				end
				for _, bob in ipairs(rig.bobs) do
					local yWave = math.sin(animElapsed * 2.4 + bob.phase) * 0.30
					local rotY = animElapsed * (if bob.isFragment then 1.8 else 1.2) + bob.phase
					bob.part.CFrame = originCF * CFrame.new(bob.baseLocalPos + Vector3.new(0, yWave, 0)) * CFrame.Angles(rotY * 0.4, rotY, 0)
				end
				if rig.portal then
					local prt = rig.portal
					local centerCF = originCF * CFrame.new(0, prt.centerY, prt.centerZ)
					for _, rp in ipairs(prt.rimParts) do
						local ang = rp.baseAngle + animElapsed * 2.2
						rp.part.CFrame = centerCF * CFrame.new(math.cos(ang) * rp.radius, math.sin(ang) * rp.radius, 0) * CFrame.Angles(0, 0, ang)
					end
					if prt.core then
						prt.core.CFrame = centerCF * CFrame.Angles(0, 0, -animElapsed * 1.5)
					end
				end
				if rig.primordialCore then
					local pulse = 1.0 + math.sin(animElapsed * 4.5) * 0.16
					rig.primordialCore.part.Size = rig.primordialCore.baseSize * pulse
				end
				for _, link in ipairs(rig.chains) do
					local sway = math.sin(animElapsed * 2.2 + link.linkIdx * 0.45) * 0.10 * link.side
					local rot = math.rad(if link.linkIdx % 2 == 0 then 25 else -25) + sway * 0.5
					link.part.CFrame = originCF * CFrame.new(link.baseLocalPos + Vector3.new(sway, 0, 0)) * CFrame.Angles(0, 0, rot)
				end
			end
		end
	end

	if not onTreadmill or not snapCFrame then return end
	local nowClk = os.clock()
	if nowClk >= nextBubbleAt and not activeBubble then
		nextBubbleAt = nowClk + math.random(15, 22)
		spawnSpeedBubble()
	end
	if boostBadge then
		local endsAt = tonumber(localPlayer:GetAttribute("TreadmillBoostEndsAt")) or 0
		local rem = math.max(0, endsAt - math.floor(Workspace:GetServerTimeNow()))
		if rem > 0 then
			boostBadge.Visible = true
			boostBadge.Text = string.format("⚡ x3 TREADMILL SPEED (%ds)", rem)
		else
			boostBadge.Visible = false
		end
	end
	if activeRunTrack then
		activeRunTrack:AdjustSpeed(if boosted then 3.4 else 2.2)
	end

	local char = localPlayer.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if hum then
		hum.AutoRotate = false
		hum:Move(Vector3.zero)
	end
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.CFrame = snapCFrame
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end)

localPlayer.CharacterAdded:Connect(function(char)
	onTreadmill = false
	snapCFrame = nil
	stopTreadmillAnim()
	local hum = char:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		standingHipHeight = hum.HipHeight
	end
end)
if localPlayer.Character then
	local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		standingHipHeight = hum.HipHeight
	end
end
