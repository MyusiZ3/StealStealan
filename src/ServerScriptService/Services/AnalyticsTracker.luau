--!strict
-- AnalyticsTracker.luau
-- Centralized Roblox AnalyticsService instrumentation (Onboarding Funnel, Economy, & Custom Retention Events)

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local AnalyticsTracker = {}

local isLiveServer = not RunService:IsStudio()

function AnalyticsTracker.LogOnboardingStep(player: Player, step: number, stepName: string)
	if not isLiveServer then return end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

function AnalyticsTracker.LogEconomy(
	player: Player,
	isSource: boolean,
	currencyName: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string?
)
	if not isLiveServer or amount <= 0 then return end
	pcall(function()
		local flow = if isSource
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flow, currencyName, amount, endingBalance, transactionType, itemSku or "")
	end)
end

function AnalyticsTracker.LogCustom(player: Player, eventName: string, value: number?)
	if not isLiveServer then return end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

return AnalyticsTracker
