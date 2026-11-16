--!strict
-- Types.luau
-- Shared type definitions for Wild Rescue: Poacher Run (StealStealan)

export type AnimalRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type AnimalMutation = "None" | "Albino" | "Golden" | "Diamond" | "Neon" | "Rainbow" | "Celestial"

export type AnimalInstance = {
	uid: string,
	speciesId: string,
	sizeRatio: number,
	weightKg: number,
	mutation: AnimalMutation,
	locked: boolean,
	acquiredAt: number,
}

export type CrateInstance = {
	uid: string,
	biomeId: string,
	rarity: AnimalRarity,
	speciesId: string,
	unlockAt: number,
}

export type IndexEntry = {
	count: number,
	maxSizeRatio: number,
	mutationsFound: { [string]: boolean },
	rewardClaimed: boolean,
}

export type PlayerSettings = {
	musicEnabled: boolean,
	musicVolume: number,
	sfxEnabled: boolean,
	sfxVolume: number,
	hideOtherAnimals: boolean,
	hideOwnAnimals: boolean,
	lowVFX: boolean,
}

export type PlayerProfileSchema = {
	schemaVersion: number,
	coins: number,
	gems: number,
	speedStat: number,
	rebirths: number,

	penCapacity: number,
	penUpgradeLevel: number,
	treadmillLevel: number,
	unclaimedPenCoins: number,

	equippedLasso: string,
	ownedLassos: { [string]: boolean },
	equippedTrail: string,
	ownedTrails: { [string]: boolean },
	equippedVehicle: string,
	ownedVehicles: { [string]: boolean },

	roamingAnimalUids: { string },
	inventoryAnimals: { [string]: AnimalInstance },
	pendingCrates: { [string]: CrateInstance },
	discoveredIndex: { [string]: IndexEntry },
	zoneIndexBonusesClaimed: { [string]: boolean },

	dailyReward: {
		lastClaimTime: number,
		streak: number,
	},
	settings: PlayerSettings,
	analyticsMeta: {
		firstJoinTime: number,
		totalPlaytimeSeconds: number,
		onboardingStep: number,
	},
}

export type BiomeDefinition = {
	id: string,
	order: number,
	name: string,
	subtitle: string,
	zStart: number,
	zEnd: number,
	groundColor: Color3,
	accentColor: Color3,
	cliffColor: Color3,
	materialName: Enum.Material,
	materialVariant: string,
	speedPenalty: number,
	bossName: string,
	bossSpeed: number,
	poacherSpeed: number,
	crateBaseResistance: number,
	recommendedSpeed: number,
	indexCount: number,
}

export type LassoDefinition = {
	id: string,
	tier: number,
	name: string,
	cost: number,
	pullPower: number,
	maxRange: number,
	sweetSpotWidth: number,
	beamColor: Color3,
	description: string,
}

export type TrailDefinition = {
	id: string,
	tier: number,
	name: string,
	cost: number,
	speedMultiplier: number,
	cashBonus: number,
	colorPrimary: Color3,
	colorSecondary: Color3,
	description: string,
}

export type VehicleDefinition = {
	id: string,
	tier: number,
	name: string,
	cost: number,
	baseSpeedBonus: number,
	towCapacity: number,
	ignoresTerrainPenalty: boolean,
	shieldHits: number,
	primaryColor: Color3,
	accentColor: Color3,
	description: string,
}

export type AnimalSpeciesDefinition = {
	indexNumber: number,
	id: string,
	name: string,
	biomeId: string,
	rarity: AnimalRarity,
	baseIncomePerSec: number,
	baseWeightKg: number,
	bodyColor: Color3,
	secondaryColor: Color3,
	eyeColor: Color3,
	shapeStyle: "Canine" | "Bear" | "Bird" | "Reptile" | "Hooved" | "Feline" | "Critter",
}

return {}
