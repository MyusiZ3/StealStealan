--!strict
-- AdminConfig.luau (SERVER-ONLY)
-- Server-verified Admin RBAC accounts (dual UserId + Username check), Titles, & Live Events.
-- Placed in ServerScriptService so clients can NEVER inspect or tamper with allowlists.

export type StaticAdminEntry = {
	userId: number,
	username: string,
	rank: number,
	title: "Owner" | "Admin",
}

local AdminConfig = {
	-- Rank 3 = Owner (Superadmin), Rank 2 = Admin
	-- Every account entry requires BOTH UserId AND exact Username match (case-insensitive) in live servers!
	ROOT_OWNERS = {
		{ userId = 5208525988, username = "Archenciel32", rank = 3, title = "Owner" },
	} :: { StaticAdminEntry },

	STATIC_ADMINS = {
		-- Add static Admins as: { userId = 123456789, username = "SomeUsername", rank = 2, title = "Admin" },
	} :: { StaticAdminEntry },

	TITLES = {
		Owner = {
			id = "Owner",
			rank = 3,
			badgeText = "👑 OWNER",
			chatPrefix = "[OWNER]",
			color = Color3.fromRGB(255, 198, 56),
			strokeColor = Color3.fromRGB(92, 18, 22),
		},
		Admin = {
			id = "Admin",
			rank = 2,
			badgeText = "🛡️ ADMIN",
			chatPrefix = "[ADMIN]",
			color = Color3.fromRGB(255, 78, 128),
			strokeColor = Color3.fromRGB(28, 12, 36),
		},
	},

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
