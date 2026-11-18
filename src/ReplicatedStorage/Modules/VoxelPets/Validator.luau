--!strict
-- Validator.luau
-- Geometric integrity checks for modular VoxelPets models:
-- 1) Connected silhouette (BFS across expanded world AABBs)
-- 2) Coplanar Z-fighting within same bone cluster (different-color faces sharing a plane)
-- 3) Ground sole alignment relative to model WorldPivot

local Validator = {}

export type InspectResult = {
	ok: boolean,
	partCount: number,
	motorCount: number,
	groundOffset: number,
	warnings: { string },
}

type WorldBox = {
	part: BasePart,
	cluster: string,
	minV: Vector3,
	maxV: Vector3,
	center: Vector3,
}

local function computeWorldAABB(part: BasePart): (Vector3, Vector3)
	local cf = part.CFrame
	local half = part.Size * 0.5
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local hx = math.abs(r00) * half.X + math.abs(r01) * half.Y + math.abs(r02) * half.Z
	local hy = math.abs(r10) * half.X + math.abs(r11) * half.Y + math.abs(r12) * half.Z
	local hz = math.abs(r20) * half.X + math.abs(r21) * half.Y + math.abs(r22) * half.Z
	local pos = cf.Position
	local ext = Vector3.new(hx, hy, hz)
	return pos - ext, pos + ext
end

local function isFlatBlock(part: BasePart): boolean
	if not part:IsA("Part") then
		return false
	end
	if part.Shape ~= Enum.PartType.Block then
		return false
	end
	if part:FindFirstChildOfClass("SpecialMesh") ~= nil then
		return false
	end
	return true
end

local function isAxisAligned(cf: CFrame): boolean
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local cols = {
		Vector3.new(r00, r10, r20),
		Vector3.new(r01, r11, r21),
		Vector3.new(r02, r12, r22),
	}
	for _, col in ipairs(cols) do
		local mx = math.max(math.abs(col.X), math.abs(col.Y), math.abs(col.Z))
		if mx < 0.999 then
			return false
		end
	end
	return true
end

local function boxesTouch(a: WorldBox, b: WorldBox, pad: number): boolean
	return (a.minV.X - pad) <= b.maxV.X
		and (a.maxV.X + pad) >= b.minV.X
		and (a.minV.Y - pad) <= b.maxV.Y
		and (a.maxV.Y + pad) >= b.minV.Y
		and (a.minV.Z - pad) <= b.maxV.Z
		and (a.maxV.Z + pad) >= b.minV.Z
end

local function colorsNearlyEqual(c1: Color3, c2: Color3): boolean
	return math.abs(c1.R - c2.R) < 0.015 and math.abs(c1.G - c2.G) < 0.015 and math.abs(c1.B - c2.B) < 0.015
end

local function overlap1D(minA: number, maxA: number, minB: number, maxB: number): number
	return math.min(maxA, maxB) - math.max(minA, minB)
end

function Validator.InspectModel(model: Model): InspectResult
	local s = tonumber(model:GetAttribute("SizeRatio")) or 1.0
	local warnings: { string } = {}
	local visibleParts: { BasePart } = {}
	local boxes: { WorldBox } = {}
	local boxesByCluster: { [string]: { WorldBox } } = {}
	local motorCount = 0
	local minY = math.huge

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Motor6D") then
			motorCount += 1
		elseif desc:IsA("BasePart") then
			if desc.Transparency < 0.95 then
				table.insert(visibleParts, desc)
				local minV, maxV = computeWorldAABB(desc)
				minY = math.min(minY, minV.Y)
				if not desc:GetAttribute("AllowFloating") then
					local cluster = tostring(desc:GetAttribute("BoneCluster") or "Root")
					local wb: WorldBox = {
						part = desc,
						cluster = cluster,
						minV = minV,
						maxV = maxV,
						center = desc.Position,
					}
					table.insert(boxes, wb)
					local list = boxesByCluster[cluster]
					if not list then
						list = {}
						boxesByCluster[cluster] = list
					end
					table.insert(list, wb)
				end
			end
		end
	end

	-- 1. Connected Silhouette Check (BFS from Torso)
	if #boxes > 0 then
		local torsoPart = model:FindFirstChild("Torso")
		local anchorPos = if torsoPart and torsoPart:IsA("BasePart") then torsoPart.Position else model:GetPivot().Position
		local seedIdx = 1
		local bestDist = math.huge
		for i, bx in ipairs(boxes) do
			local d = (bx.center - anchorPos).Magnitude
			if d < bestDist then
				bestDist = d
				seedIdx = i
			end
		end

		local visited: { [number]: boolean } = { [seedIdx] = true }
		local queue: { number } = { seedIdx }
		local pad = 0.08 * s
		local head = 1
		while head <= #queue do
			local curIdx = queue[head]
			head += 1
			local curBox = boxes[curIdx]
			for j = 1, #boxes do
				if not visited[j] and boxesTouch(curBox, boxes[j], pad) then
					visited[j] = true
					table.insert(queue, j)
				end
			end
		end

		for i, bx in ipairs(boxes) do
			if not visited[i] then
				table.insert(warnings, "Floating/disconnected voxel: " .. bx.part.Name)
			end
		end
	end

	-- 2. Coplanar Z-Fighting Check (within same rigid cluster)
	local minOverlap2D = 0.04 * s
	local maxPlaneDelta = 0.004 * s
	for _, list in pairs(boxesByCluster) do
		for i = 1, #list - 1 do
			local a = list[i]
			if isFlatBlock(a.part) and isAxisAligned(a.part.CFrame) then
				for j = i + 1, #list do
					local b = list[j]
					if isFlatBlock(b.part) and isAxisAligned(b.part.CFrame) and not colorsNearlyEqual(a.part.Color, b.part.Color) then
						local ox = overlap1D(a.minV.X, a.maxV.X, b.minV.X, b.maxV.X)
						local oy = overlap1D(a.minV.Y, a.maxV.Y, b.minV.Y, b.maxV.Y)
						local oz = overlap1D(a.minV.Z, a.maxV.Z, b.minV.Z, b.maxV.Z)
						local sameX = (oy > minOverlap2D and oz > minOverlap2D)
							and (math.abs(a.minV.X - b.minV.X) < maxPlaneDelta or math.abs(a.maxV.X - b.maxV.X) < maxPlaneDelta)
						local sameY = (ox > minOverlap2D and oz > minOverlap2D)
							and (math.abs(a.minV.Y - b.minV.Y) < maxPlaneDelta or math.abs(a.maxV.Y - b.maxV.Y) < maxPlaneDelta)
						local sameZ = (ox > minOverlap2D and oy > minOverlap2D)
							and (math.abs(a.minV.Z - b.minV.Z) < maxPlaneDelta or math.abs(a.maxV.Z - b.maxV.Z) < maxPlaneDelta)
						if sameX or sameY or sameZ then
							table.insert(warnings, string.format("Coplanar Z-fight risk: %s vs %s", a.part.Name, b.part.Name))
						end
					end
				end
			end
		end
	end

	-- 3. Ground Sole Alignment
	local pivotY = model:GetPivot().Position.Y
	local groundOffset = if minY < math.huge then (minY - pivotY) else 0
	if math.abs(groundOffset) > 0.08 * s then
		table.insert(warnings, string.format("Ground offset %.2f studs (expected ~0.00)", groundOffset))
	end

	return {
		ok = (#warnings == 0),
		partCount = #visibleParts,
		motorCount = motorCount,
		groundOffset = groundOffset,
		warnings = warnings,
	}
end

return Validator
