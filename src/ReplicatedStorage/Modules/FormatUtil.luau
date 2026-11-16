--!strict
-- FormatUtil.luau
-- Compact number and duration formatting helpers

local FormatUtil = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function FormatUtil.Number(value: number): string
	if value < 1000 then
		return tostring(math.floor(value + 0.5))
	end
	local tier = math.floor(math.log10(value) / 3)
	tier = math.clamp(tier, 1, #SUFFIXES - 1)
	local scaled = value / (10 ^ (tier * 3))
	if scaled >= 100 then
		return string.format("%.0f%s", scaled, SUFFIXES[tier + 1])
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, SUFFIXES[tier + 1])
	else
		return string.format("%.2f%s", scaled, SUFFIXES[tier + 1])
	end
end

function FormatUtil.Time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local mins = math.floor(s / 60)
	local rem = s % 60
	if mins > 0 then
		return string.format("%dm %02ds", mins, rem)
	end
	return string.format("%ds", rem)
end

return FormatUtil
