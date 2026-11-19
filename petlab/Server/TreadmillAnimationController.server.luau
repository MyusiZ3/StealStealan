--!strict
-- TreadmillAnimationController.server.luau
-- Centralized animation controller for Workspace.TreadmillCollection (12 Voxel Treadmills).
-- Drives seamless running belt slats (LV 1-12), optional conveyor velocity on BeltBed,
-- and LV 8-12 SpecialEffects (orbital rings, floating orbs/fragments, halos, portals, pulsing core & chain sway).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type BeltSegmentEntry = {
	model: Model,
	startFrac: number,
	partOffsets: { { part: BasePart, relToPrimary: CFrame } },
}

type RingEntry = {
	centerY: number,
	centerZ: number,
	radius: number,
	tiltRad: number,
	spinSpeed: number,
	parts: { { part: BasePart, baseAngle: number } },
}

type BobPartEntry = {
	part: BasePart,
	baseLocalPos: Vector3,
	phase: number,
	isFragment: boolean,
}

type PortalEntry = {
	centerY: number,
	centerZ: number,
	rimParts: { { part: BasePart, baseAngle: number, radius: number } },
	core: BasePart?,
}

type ChainLinkEntry = {
	part: BasePart,
	baseLocalPos: Vector3,
	linkIdx: number,
	side: number,
}

type TreadmillRig = {
	model: Model,
	level: number,
	originCF: CFrame,
	beltStartZ: number,
	beltEndZ: number,
	beltY: number,
	beltSpeed: number,
	segments: { BeltSegmentEntry },
	rings: { RingEntry },
	bobs: { BobPartEntry },
	portal: PortalEntry?,
	primordialCore: { part: BasePart, baseSize: Vector3 }?,
	chains: { ChainLinkEntry },
	conns: { RBXScriptConnection },
}

local rigs: { [Model]: TreadmillRig } = {}

local function unregisterTreadmill(m: Model)
	local entry = rigs[m]
	if not entry then
		return
	end
	for _, c in ipairs(entry.conns) do
		c:Disconnect()
	end
	rigs[m] = nil
end

local function registerTreadmill(m: Model)
	if rigs[m] or not m:IsA("Model") then
		return
	end
	local lv = tonumber(m:GetAttribute("Level")) or 1
	local originCF = m:GetPivot()
	local invOrigin = originCF:Inverse()

	local runningBelt = m:FindFirstChild("RunningBelt")
	local beltBed = if runningBelt then runningBelt:FindFirstChild("BeltBed") else nil
	local beltStartZ = 4.7
	local beltEndZ = -5.8
	local beltY = 1.325
	if beltBed and beltBed:IsA("BasePart") then
		beltStartZ = tonumber(beltBed:GetAttribute("BeltStartZ")) or 4.7
		beltEndZ = tonumber(beltBed:GetAttribute("BeltEndZ")) or -5.8
		beltY = tonumber(beltBed:GetAttribute("BeltY")) or 1.325
		-- Subtle conveyor velocity along the belt (-Z local direction)
		local beltDirWorld = (originCF - originCF.Position) * Vector3.new(0, 0, -1)
		beltBed.AssemblyLinearVelocity = beltDirWorld * 6.0
	end

	local segments: { BeltSegmentEntry } = {}
	local segFolder = m:FindFirstChild("BeltSegments")
	if segFolder then
		for _, segModel in ipairs(segFolder:GetChildren()) do
			if segModel:IsA("Model") and segModel.PrimaryPart then
				local pCF = segModel.PrimaryPart.CFrame
				local invP = pCF:Inverse()
				local partOffsets = {}
				for _, d in ipairs(segModel:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						table.insert(partOffsets, {
							part = d,
							relToPrimary = invP * d.CFrame,
						})
					end
				end
				table.insert(segments, {
					model = segModel,
					startFrac = tonumber(segModel:GetAttribute("StartFrac")) or 0,
					partOffsets = partOffsets,
				})
			end
		end
	end

	local rings: { RingEntry } = {}
	local bobs: { BobPartEntry } = {}
	local portal: PortalEntry? = nil
	local primordialCore: { part: BasePart, baseSize: Vector3 }? = nil
	local chains: { ChainLinkEntry } = {}

	local sf = m:FindFirstChild("SpecialEffects")
	if sf and lv >= 8 then
		for _, child in ipairs(sf:GetChildren()) do
			if child:IsA("Model") and (string.find(child.Name, "Ring") or child.Name == "DivineHalo") then
				local cY = tonumber(child:GetAttribute("RingCenterY")) or 5.0
				local cZ = tonumber(child:GetAttribute("RingCenterZ")) or 4.8
				local rad = tonumber(child:GetAttribute("RingRadius")) or 3.5
				local tilt = math.rad(tonumber(child:GetAttribute("TiltDeg")) or 0)
				local spd = tonumber(child:GetAttribute("SpinSpeed")) or 1.0
				local rParts = {}
				for _, p in ipairs(child:GetChildren()) do
					if p:IsA("BasePart") then
						local localPos = (invOrigin * p.CFrame).Position
						local ang = math.atan2(localPos.Z - cZ, localPos.X)
						table.insert(rParts, { part = p, baseAngle = ang })
					end
				end
				table.insert(rings, {
					centerY = cY,
					centerZ = cZ,
					radius = rad,
					tiltRad = tilt,
					spinSpeed = spd,
					parts = rParts,
				})
			elseif child:IsA("BasePart") and (string.find(child.Name, "FloatingOrb") or string.find(child.Name, "FloatingFrag")) then
				local localPos = (invOrigin * child.CFrame).Position
				table.insert(bobs, {
					part = child,
					baseLocalPos = localPos,
					phase = tonumber(child:GetAttribute("Phase")) or 0,
					isFragment = string.find(child.Name, "FloatingFrag") ~= nil,
				})
			elseif child:IsA("Model") and child.Name == "SingularityPortal" then
				local cY = tonumber(child:GetAttribute("PortalCenterY")) or 6.9
				local cZ = tonumber(child:GetAttribute("PortalCenterZ")) or 5.0
				local rimParts = {}
				local corePart: BasePart? = nil
				for _, p in ipairs(child:GetChildren()) do
					if p:IsA("BasePart") then
						if p.Name == "BlackHoleCore" then
							corePart = p
						else
							local lp = (invOrigin * p.CFrame).Position
							local ang = math.atan2(lp.Y - cY, lp.X)
							local r = Vector2.new(lp.X, lp.Y - cY).Magnitude
							table.insert(rimParts, { part = p, baseAngle = ang, radius = r })
						end
					end
				end
				portal = {
					centerY = cY,
					centerZ = cZ,
					rimParts = rimParts,
					core = corePart,
				}
			elseif child:IsA("BasePart") and child.Name == "PrimordialCore" then
				primordialCore = {
					part = child,
					baseSize = child.Size,
				}
			elseif child:IsA("Model") and string.find(child.Name, "PrimordialChain") then
				local side = tonumber(child:GetAttribute("BaseSide")) or 1
				for _, p in ipairs(child:GetChildren()) do
					if p:IsA("BasePart") then
						local lp = (invOrigin * p.CFrame).Position
						table.insert(chains, {
							part = p,
							baseLocalPos = lp,
							linkIdx = tonumber(p:GetAttribute("LinkIdx")) or 0,
							side = side,
						})
					end
				end
			end
		end
	end

	local conns = {}
	table.insert(conns, m.AncestryChanged:Connect(function(_, newParent)
		if not newParent then
			unregisterTreadmill(m)
		end
	end))

	rigs[m] = {
		model = m,
		level = lv,
		originCF = originCF,
		beltStartZ = beltStartZ,
		beltEndZ = beltEndZ,
		beltY = beltY,
		beltSpeed = 0.35 + (lv - 1) * 0.04,
		segments = segments,
		rings = rings,
		bobs = bobs,
		portal = portal,
		primordialCore = primordialCore,
		chains = chains,
		conns = conns,
	}
end

local function bindCollection(folder: Instance)
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("Model") then
			registerTreadmill(ch)
		end
	end
	folder.ChildAdded:Connect(function(ch)
		if ch:IsA("Model") then
			task.defer(registerTreadmill, ch)
		end
	end)
	folder.ChildRemoved:Connect(function(ch)
		if ch:IsA("Model") then
			unregisterTreadmill(ch)
		end
	end)
end

local existing = Workspace:FindFirstChild("TreadmillCollection")
if existing then
	bindCollection(existing)
end
Workspace.ChildAdded:Connect(function(ch)
	if ch.Name == "TreadmillCollection" then
		bindCollection(ch)
	end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	for _, rig in pairs(rigs) do
		local spanZ = rig.beltStartZ - rig.beltEndZ
		local originCF = rig.originCF

		-- 1. Seamless Belt Segment Loop (LV 1-12)
		for _, seg in ipairs(rig.segments) do
			local frac = (seg.startFrac + elapsed * rig.beltSpeed) % 1
			local zLocal = rig.beltStartZ - frac * spanZ
			local primaryWorldCF = originCF * CFrame.new(0, rig.beltY, zLocal)
			for _, po in ipairs(seg.partOffsets) do
				po.part.CFrame = primaryWorldCF * po.relToPrimary
			end
		end

		-- 2. LV 8-12 SpecialEffects Animations
		if rig.level >= 8 then
			for _, ring in ipairs(rig.rings) do
				local centerCF = originCF * CFrame.new(0, ring.centerY, ring.centerZ) * CFrame.Angles(ring.tiltRad, 0, ring.tiltRad * 0.6)
				local spin = elapsed * ring.spinSpeed
				for _, rp in ipairs(ring.parts) do
					local ang = rp.baseAngle + spin
					local localPos = Vector3.new(math.cos(ang) * ring.radius, 0, math.sin(ang) * ring.radius)
					rp.part.CFrame = centerCF * CFrame.lookAt(localPos, Vector3.zero)
				end
			end

			for _, bob in ipairs(rig.bobs) do
				local yWave = math.sin(elapsed * 2.4 + bob.phase) * 0.35
				local rotY = elapsed * (if bob.isFragment then 1.8 else 1.2) + bob.phase
				bob.part.CFrame = originCF * CFrame.new(bob.baseLocalPos + Vector3.new(0, yWave, 0)) * CFrame.Angles(rotY * 0.4, rotY, 0)
			end

			if rig.portal then
				local prt = rig.portal
				local centerCF = originCF * CFrame.new(0, prt.centerY, prt.centerZ)
				local spin = elapsed * 2.2
				for _, rp in ipairs(prt.rimParts) do
					local ang = rp.baseAngle + spin
					local lp = Vector3.new(math.cos(ang) * rp.radius, math.sin(ang) * rp.radius, 0)
					rp.part.CFrame = centerCF * CFrame.new(lp) * CFrame.Angles(0, 0, ang)
				end
				if prt.core then
					prt.core.CFrame = centerCF * CFrame.Angles(0, 0, -elapsed * 1.5)
				end
			end

			if rig.primordialCore then
				local pulse = 1.0 + math.sin(elapsed * 4.5) * 0.16
				rig.primordialCore.part.Size = rig.primordialCore.baseSize * pulse
			end

			for _, link in ipairs(rig.chains) do
				local sway = math.sin(elapsed * 2.2 + link.linkIdx * 0.45) * 0.12 * link.side
				local rot = math.rad(if link.linkIdx % 2 == 0 then 25 else -25) + sway * 0.5
				link.part.CFrame = originCF * CFrame.new(link.baseLocalPos + Vector3.new(sway, 0, 0)) * CFrame.Angles(0, 0, rot)
			end
		end
	end
end)
