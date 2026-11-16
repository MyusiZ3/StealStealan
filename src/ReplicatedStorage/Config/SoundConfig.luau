--!strict
-- SoundConfig.luau
-- SoundGroups and default Roblox audio IDs for BGM & SFX controls

local SoundConfig = {
	GROUPS = {
		BGM = "BGMGroup",
		SFX = "SFXGroup",
	},

	-- Default safe UI/gameplay sound asset IDs (can be swapped anytime)
	SFX = {
		LassoThrow = "rbxassetid://12222200",
		LassoPullTick = "rbxassetid://12221967",
		CratePop = "rbxassetid://12222216",
		CoinCollect = "rbxassetid://12221976",
		PoacherAlarm = "rbxassetid://138081500",
		MergeSuccess = "rbxassetid://12222253",
		ButtonClick = "rbxassetid://6895079853",
		PoacherCatch = "rbxassetid://12222058",
	},
}

return SoundConfig
