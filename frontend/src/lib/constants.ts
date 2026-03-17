import { keccak256, toBytes } from 'viem'

// ─── Slot keys (must match SlotRegistry constructor) ──────────────────────────

export const SLOTS = {
  MOON:      keccak256(toBytes('MOON')),
  PASSENGER: keccak256(toBytes('PASSENGER')),
} as const

export const SLOT_LIST = [
  { key: SLOTS.MOON,      label: 'Moon',      icon: '🌙', gearTypeIndex: 0 },
  { key: SLOTS.PASSENGER,  label: 'Passenger', icon: '🧑‍🚀', gearTypeIndex: 1 },
] as const

// ─── Gear token IDs — tokenId = (rarity+1)*1000 + (gearType+1) ───────────────

export const GEAR_TYPES = ['MOON', 'PASSENGER'] as const
export const RARITIES   = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY'] as const

export type GearType = typeof GEAR_TYPES[number]
export type Rarity   = typeof RARITIES[number]

export function computeTokenId(gearType: GearType, rarity: Rarity): number {
  const rarityIdx  = RARITIES.indexOf(rarity)
  const gearIdx    = GEAR_TYPES.indexOf(gearType)
  return (rarityIdx + 1) * 1000 + (gearIdx + 1)
}

/** All 20 possible token IDs */
export const ALL_GEAR_IDS: number[] = RARITIES.flatMap((rarity) =>
  GEAR_TYPES.map((gearType) => computeTokenId(gearType, rarity))
)

export function decodeTokenId(tokenId: number): { gearType: GearType; rarity: Rarity } {
  const rarityIdx = Math.floor(tokenId / 1000) - 1
  const gearIdx   = (tokenId % 1000) - 1
  return { gearType: GEAR_TYPES[gearIdx], rarity: RARITIES[rarityIdx] }
}

// ─── Rarity colours ───────────────────────────────────────────────────────────

export const RARITY_COLOR: Record<Rarity, string> = {
  COMMON:    'text-gray-400  border-gray-400',
  UNCOMMON:  'text-green-400 border-green-400',
  RARE:      'text-blue-400  border-blue-400',
  EPIC:      'text-purple-400 border-purple-400',
  LEGENDARY: 'text-yellow-400 border-yellow-400',
}

export const RARITY_BG: Record<Rarity, string> = {
  COMMON:    'bg-gray-800',
  UNCOMMON:  'bg-green-950',
  RARE:      'bg-blue-950',
  EPIC:      'bg-purple-950',
  LEGENDARY: 'bg-yellow-950',
}
