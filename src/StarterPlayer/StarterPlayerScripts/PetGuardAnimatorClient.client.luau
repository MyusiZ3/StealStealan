--!strict
-- PetGuardAnimatorClient.client.luau
-- Drives smooth 60 FPS procedural Motor6D animations (Idle/Walk/Chase/Attack)
-- for all rigged Biome Pet Guards & Bosses inside Workspace.GameWorld.ActivePoachers.
-- Streaming-safe: keeps tracking models when PrimaryPart streams out and re-acquires on stream-in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VoxelPetGuardBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VoxelPetGuardBuilder"))

type GuardAnimEntry = {
	model: Model,
	phase: number,
	lastAttackSeq: number,
	attackStartedAt: number,
}

local ATTACK_DURATION = 0.65
local MAX_ANIMATE_DIST = 340

local trackedGuards: { [Model]: GuardAnimEntry } = {}

local function registerGuard(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	if trackedGuards[inst] then
		return
	end

	local seq = tonumber(inst:GetAttribute("GuardAttackSeq")) or 0
	trackedGuards[inst] = {
		model = inst,
		phase = math.random() * math.pi * 2,
		lastAttackSeq = seq,
		attackStartedAt = -10,
	}
end

local function unregisterGuard(inst: Instance)
	if inst:IsA("Model") then
		trackedGuards[inst] = nil
	end
end

local function bindFolder(folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		registerGuard(child)
	end
	folder.ChildAdded:Connect(registerGuard)
	folder.ChildRemoved:Connect(unregisterGuard)
end

task.spawn(function()
	local gw = Workspace:WaitForChild("GameWorld")
	local existing = gw:FindFirstChild("ActivePoachers")
	if existing then
		bindFolder(existing)
	end
	gw.ChildAdded:Connect(function(child)
		if child.Name == "ActivePoachers" then
			bindFolder(child)
		end
	end)
end)

RunService.RenderStepped:Connect(function(dt: number)
	local stepDt = math.min(dt, 0.05)
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.new()
	local blendAlpha = math.min(1, stepDt * 14)

	for model, entry in pairs(trackedGuards) do
		if not model.Parent then
			trackedGuards[model] = nil
			continue
		end
		if model:GetAttribute("VoxelGuardRig") ~= true then
			continue
		end

		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		if (root.Position - camPos).Magnitude > MAX_ANIMATE_DIST then
			continue
		end

		local seq = tonumber(model:GetAttribute("GuardAttackSeq")) or 0
		if seq > entry.lastAttackSeq then
			entry.lastAttackSeq = seq
			entry.attackStartedAt = now
		end

		local scale = tonumber(model:GetAttribute("GuardScale")) or 1.0
		local moveSpeed = tonumber(model:GetAttribute("GuardMoveSpeed")) or 0
		local rawState = tostring(model:GetAttribute("GuardAnimState") or "Walk")

		local mode: VoxelPetGuardBuilder.GuardAnimMode
		local attackProgress: number? = nil
		local attackElapsed = now - entry.attackStartedAt
		if attackElapsed >= 0 and attackElapsed < ATTACK_DURATION then
			mode = "Attack"
			attackProgress = math.clamp(attackElapsed / ATTACK_DURATION, 0, 1)
			entry.phase += stepDt * 3.0
		elseif rawState == "Chase" then
			mode = "Chase"
			local freq = math.clamp(moveSpeed / math.max(1.0, scale * 1.9), 5.8, 12.8)
			entry.phase += stepDt * freq
		elseif rawState == "Idle" then
			mode = "Idle"
			local freq = 2.0 / math.sqrt(math.max(0.5, scale))
			entry.phase += stepDt * freq
		else
			mode = "Walk"
			local freq = math.clamp(moveSpeed / math.max(1.0, scale * 2.2), 3.2, 8.8)
			entry.phase += stepDt * freq
		end

		VoxelPetGuardBuilder.StepRig(model, mode, entry.phase, blendAlpha, attackProgress)
	end
end)
