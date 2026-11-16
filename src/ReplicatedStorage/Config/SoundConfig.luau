--!strict
-- SoundConfig.luau
-- SoundGroups, Creator Store APM BGM loops, and gameplay SFX IDs

local SoundConfig = {
	GROUPS = {
		BGM = "BGMGroup",
		SFX = "SFXGroup",
	},

	BGM = {
		Hub = "rbxassetid://1838933509",  -- Little Friends OL (Playful hub loop)
		Wild = "rbxassetid://1844217603", -- Just Content (Upbeat adventure loop)
		Boss = "rbxassetid://9039901622", -- Cool & Collected (Tense pursuit pulse)
	},

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
