--!strict
-- Types.luau
-- Shared type definitions for Wild Rescue: Poacher Run (StealStealan)

export type AnimalRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type AnimalTrait = "Normal" | "Chubby" | "Zoomer" | "Magnet" | "Shiny"
export type EvolutionTier = number -- 1=Normal, 2=Golden, 3=Rainbow, 4=Galactic

export type AnimalInstance = {
	uid: string,
	speciesId: string,
	tier: EvolutionTier,
	trait: AnimalTrait,
	level: number,
	acquiredAt: number,
}

export type CrateInstance = {
	uid: string,
	biomeId: string,
	rarity: AnimalRarity,
	speciesId: string,
	unlockAt: number,
	stallIndex: number,
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

	equippedLasso: string,
	ownedLassos: { [string]: boolean },

	equippedVehicle: string,
	ownedVehicles: { [string]: boolean },

	unlockedStalls: number,
	activeStallAnimals: { [string]: string },
	pendingCrates: { [string]: CrateInstance },
	inventoryAnimals: { [string]: AnimalInstance },
	discoveredCodex: { [string]: boolean },

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
	speedPenalty: number, -- 0.0 = none, 0.4 = 40% slower without terrain vehicle
	bossName: string,
	bossSpeed: number,
	poacherSpeed: number,
	crateBaseResistance: number,
	recommendedSpeed: number,
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
	id: string,
	name: string,
	biomeId: string,
	rarity: AnimalRarity,
	baseIncomePerSec: number,
	mountSpeedBonus: number,
	bodyColor: Color3,
	secondaryColor: Color3,
	eyeColor: Color3,
	scale: number,
}

return {}
