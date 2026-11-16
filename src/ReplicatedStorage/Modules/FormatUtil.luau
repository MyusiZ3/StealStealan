--!strict
-- FormatUtil.luau
-- Compact number formatting (K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc) and parser for Admin inputs

local FormatUtil = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local SUFFIX_MAP: { [string]: number } = {}
for i, suf in ipairs(SUFFIXES) do
	if suf ~= "" then
		SUFFIX_MAP[string.lower(suf)] = 10 ^ ((i - 1) * 3)
	end
end

function FormatUtil.Number(value: number): string
	if value ~= value then
		return "0"
	end
	if value == math.huge then
		return "INF"
	end
	local neg = value < 0
	local absVal = math.abs(value)
	if absVal < 1000 then
		return (if neg then "-" else "") .. tostring(math.floor(absVal + 0.5))
	end
	local tier = math.floor(math.log10(absVal) / 3)
	tier = math.clamp(tier, 1, #SUFFIXES - 1)
	local scaled = absVal / (10 ^ (tier * 3))
	local str: string
	if scaled >= 100 then
		str = string.format("%.0f%s", scaled, SUFFIXES[tier + 1])
	elseif scaled >= 10 then
		str = string.format("%.1f%s", scaled, SUFFIXES[tier + 1])
	else
		str = string.format("%.2f%s", scaled, SUFFIXES[tier + 1])
	end
	return if neg then "-" .. str else str
end

function FormatUtil.ParseCompactNumber(raw: string): number?
	local trimmed = string.gsub(raw, "%s+", "")
	local direct = tonumber(trimmed)
	if direct then
		return direct
	end
	local numPart, suffixPart = string.match(trimmed, "^([%d%.]+)([A-Za-z]+)$")
	if not numPart or not suffixPart then
		return nil
	end
	local base = tonumber(numPart)
	local mult = SUFFIX_MAP[string.lower(suffixPart)]
	if base and mult then
		return base * mult
	end
	return nil
end

function FormatUtil.Time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local hrs = math.floor(s / 3600)
	local mins = math.floor((s % 3600) / 60)
	local rem = s % 60
	if hrs > 0 then
		return string.format("%dh %02dm", hrs, mins)
	elseif mins > 0 then
		return string.format("%dm %02ds", mins, rem)
	end
	return string.format("%ds", rem)
end

return FormatUtil
