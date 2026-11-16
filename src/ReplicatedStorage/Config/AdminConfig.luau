--!strict
-- AdminConfig.luau
-- Server-verified Admin RBAC ranks and "Admin Abuse" live event presets

local AdminConfig = {
	-- Rank 3 = Owner / SuperAdmin, Rank 2 = Admin / Event Host, Rank 1 = Moderator
	-- Note: game.CreatorId and Studio local playtesters (UserId <= 0) automatically get Rank 3.
	ROLE_USER_IDS = {
		[5208525988] = 3, -- Owner account detected in Studio context
	} :: { [number]: number },

	ADMIN_ABUSE_EVENTS = {
		CrateRain = {
			id = "CrateRain",
			title = "ADMIN ABUSE: MYTHIC CRATE RAIN!",
			description = "Rare, Epic, Legendary & Mythic animal crates are raining across all biomes!",
			durationSeconds = 90,
			color = Color3.fromRGB(255, 196, 46),
		},
		MutationParty100x = {
			id = "MutationParty100x",
			title = "ADMIN ABUSE: 100x RAINBOW & CELESTIAL LUCK!",
			description = "Mutation luck & Titanic size chances are boosted 100x server-wide!",
			durationSeconds = 120,
			color = Color3.fromRGB(224, 92, 255),
		},
		GoldenFever = {
			id = "GoldenFever",
			title = "ADMIN ABUSE: 25x GOLDEN CASH & SPEED FEVER!",
			description = "All Zoo Pen Income & Treadmill Speed gains are multiplied by 25x!",
			durationSeconds = 120,
			color = Color3.fromRGB(84, 255, 152),
		},
		TitanicZoo = {
			id = "TitanicZoo",
			title = "ADMIN ABUSE: TITANIC ZOO MODE!",
			description = "Every animal roaming in your sanctuary temporarily grows GIANT!",
			durationSeconds = 90,
			color = Color3.fromRGB(68, 192, 255),
		},
		ZeroResistance = {
			id = "ZeroResistance",
			title = "ADMIN ABUSE: 1-SECOND INSTANT LASSO PULL!",
			description = "Crate resistance is reduced to near zero — yank anything instantly!",
			durationSeconds = 90,
			color = Color3.fromRGB(0, 245, 212),
		},
		PoacherStampede = {
			id = "PoacherStampede",
			title = "ADMIN ABUSE: HYPER POACHER STAMPEDE!",
			description = "Boss Poachers are giant and 2.5x faster — 5x cash bonus on rescue!",
			durationSeconds = 90,
			color = Color3.fromRGB(255, 72, 92),
		},
	},
}

return AdminConfig
