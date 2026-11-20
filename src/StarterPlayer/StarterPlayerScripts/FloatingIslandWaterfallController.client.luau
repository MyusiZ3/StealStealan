--!strict
-- FloatingIslandWaterfallController.client.luau
-- Centralized 60 FPS animation controller for all Voxel Floating Islands & Dynamic Waterfalls.
-- Drives continuous downward/forward reusable water segments, falling droplets, splash ripple rings,
-- swaying hanging roots/vines, breathing foliage, hovering detached rocks, and TweenService lantern glow.
-- Streaming & Culling safe: skips islands outside camera radius or temporarily culled/streamed out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

type WaterSegEntry = {
	part: BasePart,
	isForward: boolean,
	lx: number,
	ly: number,
	lz: number,
	startVal: number,
	endVal: number,
	speed: number,
	phase: number,
	baseTrans: number,
}

type DropletEntry = {
	part: BasePart,
	lx: number,
	lz: number,
	startY: number,
	endY: number,
	outArcZ: number,
	speed: number,
	phase: number,
	baseTrans: number,
}

type RippleEntry = {
	part: BasePart,
	baseCF: CFrame,
	baseSX: number,
	baseSY: number,
	baseSZ: number,
	phase: number,
	speed: number,
}

type VineEntry = {
	part: BasePart,
	px: number,
	py: number,
	pz: number,
	halfLen: number,
	phase: number,
	amp: number,
}

type LeafEntry = {
	part: BasePart,
	baseLocalCF: CFrame,
	phase: number,
}

type FloatRockEntry = {
	part: BasePart,
	baseLocalCF: CFrame,
	phase: number,
	bobAmp: number,
}

type IslandAnimState = {
	model: Model,
	dirty: boolean,
	waterSegs: { WaterSegEntry },
	droplets: { DropletEntry },
	ripples: { RippleEntry },
	vines: { VineEntry },
	leaves: { LeafEntry },
	floatRocks: { FloatRockEntry },
	tweens: { Tween },
	tweenedLights: { [PointLight]: boolean },
}

local MAX_ANIMATE_DIST = 680

local trackedIslands: { [Model]: IslandAnimState } = {}
local activeTweensByLight: { [PointLight]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function smoothEdgeEnvelope(p: number): number
	if p < 0.14 then
		return math.clamp(p / 0.14, 0, 1)
	elseif p > 0.82 then
		return math.clamp((1 - p) / 0.18, 0, 1)
	end
	return 1
end

local function rebuildEntryCaches(state: IslandAnimState)
	table.clear(state.waterSegs)
	table.clear(state.droplets)
	table.clear(state.ripples)
	table.clear(state.vines)
	table.clear(state.leaves)
	table.clear(state.floatRocks)

	for _, desc in ipairs(state.model:GetDescendants()) do
		if desc:IsA("BasePart") then
			local flowAxis = desc:GetAttribute("FlowAxis")
			if flowAxis == "Down" or flowAxis == "Forward" then
				table.insert(state.waterSegs, {
					part = desc,
					isForward = (flowAxis == "Forward"),
					lx = tonumber(desc:GetAttribute("LocalX")) or 0,
					ly = tonumber(desc:GetAttribute("LocalY")) or 0,
					lz = tonumber(desc:GetAttribute("LocalZ")) or 0,
					startVal = tonumber(desc:GetAttribute("StartVal")) or 0,
					endVal = tonumber(desc:GetAttribute("EndVal")) or -40,
					speed = tonumber(desc:GetAttribute("Speed")) or 0.42,
					phase = tonumber(desc:GetAttribute("Phase")) or 0,
					baseTrans = tonumber(desc:GetAttribute("BaseTransparency")) or 0.30,
				})
			else
				local animKind = desc:GetAttribute("AnimKind")
				if animKind == "Droplet" then
					table.insert(state.droplets, {
						part = desc,
						lx = tonumber(desc:GetAttribute("LocalX")) or 0,
						lz = tonumber(desc:GetAttribute("LocalZ")) or 0,
						startY = tonumber(desc:GetAttribute("StartY")) or 0.8,
						endY = tonumber(desc:GetAttribute("EndY")) or -42,
						outArcZ = tonumber(desc:GetAttribute("OutArcZ")) or -1.4,
						speed = tonumber(desc:GetAttribute("Speed")) or 0.5,
						phase = tonumber(desc:GetAttribute("Phase")) or 0,
						baseTrans = tonumber(desc:GetAttribute("BaseTransparency")) or 0.2,
					})
				elseif animKind == "RippleRing" then
					local bcf = desc:GetAttribute("BaseLocalCF")
					if typeof(bcf) == "CFrame" then
						table.insert(state.ripples, {
							part = desc,
							baseCF = bcf,
							baseSX = tonumber(desc:GetAttribute("BaseSizeX")) or desc.Size.X,
							baseSY = tonumber(desc:GetAttribute("BaseSizeY")) or desc.Size.Y,
							baseSZ = tonumber(desc:GetAttribute("BaseSizeZ")) or desc.Size.Z,
							phase = tonumber(desc:GetAttribute("Phase")) or 0,
							speed = tonumber(desc:GetAttribute("Speed")) or 0.55,
						})
					end
				elseif animKind == "VineSway" then
					table.insert(state.vines, {
						part = desc,
						px = tonumber(desc:GetAttribute("PivotX")) or 0,
						py = tonumber(desc:GetAttribute("PivotY")) or 0,
						pz = tonumber(desc:GetAttribute("PivotZ")) or 0,
						halfLen = tonumber(desc:GetAttribute("HalfLen")) or 2.5,
						phase = tonumber(desc:GetAttribute("Phase")) or 0,
						amp = tonumber(desc:GetAttribute("Amp")) or 0.08,
					})
				elseif animKind == "LeafSway" then
					local bcf = desc:GetAttribute("BaseLocalCF")
					if typeof(bcf) == "CFrame" then
						table.insert(state.leaves, {
							part = desc,
							baseLocalCF = bcf,
							phase = tonumber(desc:GetAttribute("Phase")) or 0,
						})
					end
				elseif animKind == "FloatBob" then
					local bcf = desc:GetAttribute("BaseLocalCF")
					if typeof(bcf) == "CFrame" then
						table.insert(state.floatRocks, {
							part = desc,
							baseLocalCF = bcf,
							phase = tonumber(desc:GetAttribute("Phase")) or 0,
							bobAmp = tonumber(desc:GetAttribute("BobAmp")) or 0.65,
						})
					end
				end
			end
		elseif desc:IsA("PointLight") and desc:GetAttribute("AnimKind") == "LanternPulse" then
			if not activeTweensByLight[desc] then
				local baseBr = tonumber(desc:GetAttribute("BaseBrightness")) or 1.65
				local ph = tonumber(desc:GetAttribute("Phase")) or 0
				desc.Brightness = baseBr * 0.86
				local tw = TweenService:Create(
					desc,
					TweenInfo.new(1.75 + (ph % 0.5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Brightness = baseBr * 1.24 }
				)
				tw:Play()
				activeTweensByLight[desc] = tw
				state.tweenedLights[desc] = true
				table.insert(state.tweens, tw)
			end
		end
	end

	state.dirty = false
end

local function registerIsland(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	if inst:GetAttribute("HasAnimatedWaterfall") ~= true and inst:GetAttribute("HasEnvironmentalAnim") ~= true then
		return
	end
	if trackedIslands[inst] then
		trackedIslands[inst].dirty = true
		return
	end

	local state: IslandAnimState = {
		model = inst,
		dirty = true,
		waterSegs = {},
		droplets = {},
		ripples = {},
		vines = {},
		leaves = {},
		floatRocks = {},
		tweens = {},
		tweenedLights = {},
	}
	trackedIslands[inst] = state

	inst.DescendantAdded:Connect(function()
		if trackedIslands[inst] then
			trackedIslands[inst].dirty = true
		end
	end)
	inst.DescendantRemoving:Connect(function()
		if trackedIslands[inst] then
			trackedIslands[inst].dirty = true
		end
	end)
	inst.Destroying:Connect(function()
		local st = trackedIslands[inst]
		if st then
			for _, tw in ipairs(st.tweens) do
				pcall(function() tw:Cancel() end)
			end
			trackedIslands[inst] = nil
		end
	end)
end

local boundContainers: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function bindSkyContainer(container: Instance)
	if boundContainers[container] then
		return
	end
	boundContainers[container] = true
	for _, ch in ipairs(container:GetChildren()) do
		registerIsland(ch)
	end
	container.ChildAdded:Connect(registerIsland)
end

local function bindBiomeFolder(biomeFolder: Instance)
	if boundContainers[biomeFolder] then
		return
	end
	boundContainers[biomeFolder] = true
	local decor = biomeFolder:FindFirstChild("CuratedDecor")
	if decor then
		bindSkyContainer(decor)
	end
	biomeFolder.ChildAdded:Connect(function(ch)
		if ch.Name == "CuratedDecor" then
			bindSkyContainer(ch)
		end
	end)
end

local function bindBiomeContainer(biomesFolder: Instance)
	if boundContainers[biomesFolder] then
		return
	end
	boundContainers[biomesFolder] = true
	for _, ch in ipairs(biomesFolder:GetChildren()) do
		if ch:IsA("Folder") or ch:IsA("Model") then
			bindBiomeFolder(ch)
		end
	end
	biomesFolder.ChildAdded:Connect(function(ch)
		if ch:IsA("Folder") or ch:IsA("Model") then
			bindBiomeFolder(ch)
		end
	end)
end

task.spawn(function()
	local gw = Workspace:WaitForChild("GameWorld", 15)
	if gw then
		local sky = gw:FindFirstChild("SkyIslands") or gw:WaitForChild("SkyIslands", 10)
		if sky then
			bindSkyContainer(sky)
		end
		local biomes = gw:FindFirstChild("Biomes")
		if biomes then
			bindBiomeContainer(biomes)
		end
		gw.ChildAdded:Connect(function(ch)
			if ch.Name == "SkyIslands" then
				bindSkyContainer(ch)
			elseif ch.Name == "Biomes" then
				bindBiomeContainer(ch)
			end
		end)
	end

	-- Also support any root-level FloatingIsland_Waterfall
	for _, ch in ipairs(Workspace:GetChildren()) do
		registerIsland(ch)
	end
	Workspace.ChildAdded:Connect(registerIsland)
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.new()

	for model, state in pairs(trackedIslands) do
		if model.Parent == nil then
			for _, tw in ipairs(state.tweens) do
				pcall(function() tw:Cancel() end)
			end
			trackedIslands[model] = nil
			continue
		end

		if not model:IsDescendantOf(Workspace) then
			continue
		end

		local anchor = model.PrimaryPart
		if not anchor then
			continue
		end

		if (anchor.Position - camPos).Magnitude > MAX_ANIMATE_DIST then
			continue
		end

		if state.dirty then
			rebuildEntryCaches(state)
		end

		local originCF = anchor.CFrame
		local s = tonumber(model:GetAttribute("IslandScale")) or 1.0

		-- 1. Continuous Downward & Forward Waterfall Segments (recycled seamlessly with end-fades)
		for _, ws in ipairs(state.waterSegs) do
			if ws.part.Parent then
				local p = (now * ws.speed + ws.phase) % 1
				local curVal = ws.startVal + (ws.endVal - ws.startVal) * p
				local alpha = smoothEdgeEnvelope(p)
				local shimmer = 0.04 * math.sin(now * 6.5 + ws.phase * 14.0)
				ws.part.Transparency = math.clamp(1 - (1 - ws.baseTrans) * alpha + shimmer, 0.02, 1)
				if ws.isForward then
					ws.part.CFrame = originCF * CFrame.new(ws.lx * s, ws.ly * s, curVal * s)
				else
					ws.part.CFrame = originCF * CFrame.new(ws.lx * s, curVal * s, ws.lz * s)
				end
			end
		end

		-- 2. Independent Falling Blocky Water Fragments / Droplets
		for _, dr in ipairs(state.droplets) do
			if dr.part.Parent then
				local p = (now * dr.speed + dr.phase) % 1
				local fallP = p ^ 1.32
				local curY = dr.startY + (dr.endY - dr.startY) * fallP
				local curZ = dr.lz + dr.outArcZ * math.sin(p * math.pi * 0.72)
				local alpha = smoothEdgeEnvelope(p)
				dr.part.Transparency = math.clamp(1 - (1 - dr.baseTrans) * alpha, 0, 1)
				dr.part.CFrame = originCF * CFrame.new(dr.lx * s, curY * s, curZ * s) * CFrame.Angles(p * 4.2, p * 3.1, 0)
			end
		end

		-- 3. Bottom Water Splash Ripples
		for _, rp in ipairs(state.ripples) do
			if rp.part.Parent then
				local p = (now * rp.speed + rp.phase) % 1
				local scaleMul = 0.55 + p * 1.25
				rp.part.Size = Vector3.new(rp.baseSX * scaleMul, rp.baseSY, rp.baseSZ * scaleMul)
				local baseRot = rp.baseCF - rp.baseCF.Position
				rp.part.CFrame = originCF * CFrame.new(rp.baseCF.Position * s) * baseRot
				rp.part.Transparency = math.clamp(0.32 + p * 0.66, 0.2, 1)
			end
		end

		-- 4. Gently Swaying Hanging Roots & Vines (pivoted cleanly from top attachment)
		for _, vn in ipairs(state.vines) do
			if vn.part.Parent then
				local pivotCF = originCF * CFrame.new(vn.px * s, vn.py * s, vn.pz * s)
				local rx = math.sin(now * 1.35 + vn.phase) * vn.amp
				local rz = math.cos(now * 1.05 + vn.phase) * vn.amp * 0.75
				vn.part.CFrame = pivotCF * CFrame.Angles(rx, 0, rz) * CFrame.new(0, -vn.halfLen * s, 0)
			end
		end

		-- 5. Subtle Tree Foliage Breeze Sway
		for _, lf in ipairs(state.leaves) do
			if lf.part.Parent then
				local baseRot = lf.baseLocalCF - lf.baseLocalCF.Position
				local rx = math.sin(now * 1.55 + lf.phase) * 0.032
				local rz = math.cos(now * 1.25 + lf.phase) * 0.028
				lf.part.CFrame = originCF * CFrame.new(lf.baseLocalCF.Position * s) * baseRot * CFrame.Angles(rx, 0, rz)
			end
		end

		-- 6. Levitating Detached Floating Rocks
		for _, rk in ipairs(state.floatRocks) do
			if rk.part.Parent then
				local bobY = math.sin(now * 1.2 + rk.phase) * rk.bobAmp
				local baseRot = rk.baseLocalCF - rk.baseLocalCF.Position
				local yaw = math.sin(now * 0.42 + rk.phase) * 0.08
				rk.part.CFrame = originCF * CFrame.new((rk.baseLocalCF.Position + Vector3.new(0, bobY, 0)) * s) * baseRot * CFrame.Angles(0, yaw, 0)
			end
		end
	end
end)
