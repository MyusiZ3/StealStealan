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
		DoubleCash = {
			id = "DoubleCash",
			order = 1,
			icon = "💵",
			shortLabel = "2x Cash",
			title = "2x CASH RUSH!",
			description = "2x Zoo Pen Income & Rescue Cash!",
			durationSeconds = 180,
			color = Color3.fromRGB(46, 213, 115),
		},
		DoubleSpeed = {
			id = "DoubleSpeed",
			order = 2,
			icon = "👟",
			shortLabel = "2x Speed",
			title = "2x SPEED SURGE!",
			description = "2x Treadmill Speed Gain!",
			durationSeconds = 180,
			color = Color3.fromRGB(56, 189, 248),
		},
		SuperLuck5x = {
			id = "SuperLuck5x",
			order = 3,
			icon = "🍀",
			shortLabel = "5x Crate Luck",
			title = "5x CRATE LUCK!",
			description = "5x Rare Crate Spawn Luck in All Biomes!",
			durationSeconds = 180,
			color = Color3.fromRGB(163, 230, 53),
		},
		InstantUnboxParty = {
			id = "InstantUnboxParty",
			order = 4,
			icon = "⚡",
			shortLabel = "Instant Unbox",
			title = "INSTANT UNBOX PARTY!",
			description = "0s Hatch Wait Time on All Sanctuary Pens!",
			durationSeconds = 120,
			color = Color3.fromRGB(250, 204, 21),
		},
		CrateRain = {
			id = "CrateRain",
			order = 5,
			icon = "📦",
			shortLabel = "Crate Rain",
			title = "ADMIN CRATE RAIN!",
			description = "25 Rare-to-Primordial Crates + 2x Crate Luck!",
			durationSeconds = 90,
			color = Color3.fromRGB(0, 224, 255),
		},
		MutationParty100x = {
			id = "MutationParty100x",
			order = 6,
			icon = "🌈",
			shortLabel = "100x Mutation",
			title = "100x MUTATION PARTY!",
			description = "100x Mutation Luck & Giant Hatches!",
			durationSeconds = 120,
			color = Color3.fromRGB(224, 92, 255),
		},
		GoldenFever = {
			id = "GoldenFever",
			order = 7,
			icon = "👑",
			shortLabel = "25x Golden Fever",
			title = "25x GOLDEN FEVER!",
			description = "25x Cash & 25x Speed Across the Server!",
			durationSeconds = 120,
			color = Color3.fromRGB(255, 206, 52),
		},
		TitanicZoo = {
			id = "TitanicZoo",
			order = 8,
			icon = "🦖",
			shortLabel = "Titanic Zoo",
			title = "TITANIC ZOO ABUSE!",
			description = "All Roaming Pets Grow Colossal + 2.5x Hatch Size!",
			durationSeconds = 90,
			color = Color3.fromRGB(255, 118, 64),
		},
		ZeroResistance = {
			id = "ZeroResistance",
			order = 9,
			icon = "🧲",
			shortLabel = "Easy Catch",
			title = "ZERO RESISTANCE ABUSE!",
			description = "1-Tap Instant Lasso Extraction Across All Biomes!",
			durationSeconds = 90,
			color = Color3.fromRGB(84, 245, 148),
		},
		PoacherStampede = {
			id = "PoacherStampede",
			order = 10,
			icon = "🚨",
			shortLabel = "Stampede 5x Cash",
			title = "POACHER STAMPEDE!",
			description = "2.5x Faster Poachers + 5x Cash Bonus!",
			durationSeconds = 75,
			color = Color3.fromRGB(255, 68, 68),
		},
	},
}

return AdminConfig
