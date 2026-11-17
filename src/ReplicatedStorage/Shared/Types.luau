--!strict
-- Types.luau
-- Shared type definitions for Wild Rescue: Poacher Run (StealStealan)

export type AnimalRarity =
	"Common"
	| "Uncommon"
	| "Rare"
	| "Epic"
	| "Legendary"
	| "Mythic"
	| "Cosmic"
	| "Secret"
	| "Eternal"
	| "Divine"
	| "Infinity"
	| "Astral"
	| "Omega"
	| "Singularity"
	| "Primordial"

export type AnimalMutation =
	"None"
	| "Albino"
	| "Silver"
	| "Bloom"
	| "Golden"
	| "Fractured"
	| "Diamond"
	| "SpiritBloom"
	| "Parasite"
	| "Neon"
	| "Scrambled"
	| "Monstrous"
	| "Rainbow"
	| "Celestial"
export type GraphicsQuality = "Low" | "Medium" | "High"

export type ItemOriginSource = "Wild" | "Hatch" | "Merge" | "Admin"

export type AnimalInstance = {
	uid: string,
	speciesId: string,
	sizeRatio: number,
	weightKg: number,
	mutation: AnimalMutation,
	locked: boolean,
	acquiredAt: number,
	serialNonce: number?,
	mintedByUserId: number?,
	originSource: ItemOriginSource?,
	parentUids: { string }?,
}

export type CrateInstance = {
	uid: string,
	biomeId: string,
	rarity: AnimalRarity,
	speciesId: string,
	unlockAt: number,
	hatchDuration: number?,
	placedSlot: number?,
	sizeScale: number?,
	localX: number?,
	localZ: number?,
	customSizeRatio: number?,
	customMutation: AnimalMutation?,
	serialNonce: number?,
	mintedByUserId: number?,
	originSource: ItemOriginSource?,
	parentUids: { string }?,
}

export type InventoryCrate = {
	uid: string,
	biomeId: string,
	rarity: AnimalRarity,
	speciesId: string,
	sizeScale: number,
	hatchDuration: number,
	acquiredAt: number,
	customSizeRatio: number?,
	customMutation: AnimalMutation?,
	serialNonce: number?,
	mintedByUserId: number?,
	originSource: ItemOriginSource?,
	parentUids: { string }?,
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
	graphicsQuality: GraphicsQuality,
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
	crateInventory: { [string]: InventoryCrate },
	pendingCrates: { [string]: CrateInstance },
	discoveredIndex: { [string]: IndexEntry },
	zoneIndexBonusesClaimed: { [string]: boolean },

	dailyReward: {
		lastClaimTime: number,
		streak: number,
	},
	afkRewards: {
		elapsedSeconds: number,
		claimedTiers: { [string]: boolean },
	}?,
	settings: PlayerSettings,
	analyticsMeta: {
		firstJoinTime: number,
		totalPlaytimeSeconds: number,
		onboardingStep: number,
	},
	saveVersion: number?,
	itemSerialCounter: number?,
	consumedUids: { string }?,
	sessionLock: {
		jobId: string,
		timestamp: number,
	}?,
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
	maxRarity: AnimalRarity,
	bannerAssetId: string?,
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
	rarity: string?,
	cost: number,
	robuxPrice: number?,
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
	speedMultiplier: number,
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
