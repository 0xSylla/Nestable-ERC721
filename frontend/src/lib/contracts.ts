import { Address } from 'viem'

// ─── Addresses — set via .env.local ──────────────────────────────────────────

export const ADDRESSES = {
  characterNFT:  process.env.NEXT_PUBLIC_CHARACTER_NFT_ADDRESS  as Address,
  gearNFT:       process.env.NEXT_PUBLIC_GEAR_NFT_ADDRESS       as Address,
  slotRegistry:  process.env.NEXT_PUBLIC_SLOT_REGISTRY_ADDRESS  as Address,
}

export const RENDERER_URL = process.env.NEXT_PUBLIC_RENDERER_URL ?? 'http://localhost:3000'

// ─── ABIs ─────────────────────────────────────────────────────────────────────

export const characterNFTAbi = [
  // ERC721
  {
    name: 'ownerOf',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'balanceOf',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'tokenURI',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'string' }],
  },
  {
    name: 'i_maxSupply',
    type: 'function', stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  // Mint
  {
    name: 'batchMint',
    type: 'function', stateMutability: 'payable',
    inputs: [
      { name: 'stageId', type: 'uint256' },
      { name: 'amount',  type: 'uint256' },
    ],
    outputs: [],
  },
  // Transfer event — used to enumerate owned tokens
  {
    name: 'Transfer',
    type: 'event',
    inputs: [
      { name: 'from',    type: 'address', indexed: true },
      { name: 'to',      type: 'address', indexed: true },
      { name: 'tokenId', type: 'uint256', indexed: true },
    ],
  },
] as const

export const gearNFTAbi = [
  {
    name: 'balanceOf',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }, { name: 'id', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'balanceOfBatch',
    type: 'function', stateMutability: 'view',
    inputs: [
      { name: 'accounts', type: 'address[]' },
      { name: 'ids',      type: 'uint256[]' },
    ],
    outputs: [{ type: 'uint256[]' }],
  },
  {
    name: 'getGear',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{
      type: 'tuple',
      components: [
        { name: 'name',      type: 'string'  },
        { name: 'gearType',  type: 'uint8'   },
        { name: 'rarity',    type: 'uint8'   },
        { name: 'maxSupply', type: 'uint256' },
        { name: 'minted',    type: 'uint256' },
        { name: 'colorURI',  type: 'string'  },
        { name: 'bwURI',     type: 'string'  },
        { name: 'attack',    type: 'uint256' },
        { name: 'defense',   type: 'uint256' },
      ],
    }],
  },
  {
    name: 'isApprovedForAll',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }, { name: 'operator', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'setApprovalForAll',
    type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'operator', type: 'address' }, { name: 'approved', type: 'bool' }],
    outputs: [],
  },
  // Admin mint (onlyOwner)
  {
    name: 'mint',
    type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'to',      type: 'address' },
      { name: 'tokenId', type: 'uint256' },
      { name: 'amount',  type: 'uint256' },
    ],
    outputs: [],
  },
] as const

export const slotRegistryAbi = [
  {
    name: 'equipToSlot',
    type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'charId', type: 'uint256' },
      { name: 'slot',   type: 'bytes32' },
      { name: 'gearId', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'unequipSlot',
    type: 'function', stateMutability: 'nonpayable',
    inputs: [
      { name: 'charId', type: 'uint256' },
      { name: 'slot',   type: 'bytes32' },
    ],
    outputs: [],
  },
  {
    name: 'getSlot',
    type: 'function', stateMutability: 'view',
    inputs: [
      { name: 'charId', type: 'uint256' },
      { name: 'slot',   type: 'bytes32' },
    ],
    outputs: [{ name: 'gearId', type: 'uint256' }],
  },
  {
    name: 'gearEquippedCount',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'gearId', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getSlotConfig',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'slot', type: 'bytes32' }],
    outputs: [
      { name: 'exists',        type: 'bool'  },
      { name: 'typed',         type: 'bool'  },
      { name: 'gearTypeIndex', type: 'uint8' },
    ],
  },
  {
    name: 'getTBA',
    type: 'function', stateMutability: 'view',
    inputs: [{ name: 'charId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  // Events — for invalidating cache
  {
    name: 'SlotEquipped',
    type: 'event',
    inputs: [
      { name: 'charId', type: 'uint256', indexed: true },
      { name: 'slot',   type: 'bytes32', indexed: true },
      { name: 'gearId', type: 'uint256', indexed: true },
    ],
  },
  {
    name: 'SlotUnequipped',
    type: 'event',
    inputs: [
      { name: 'charId', type: 'uint256', indexed: true },
      { name: 'slot',   type: 'bytes32', indexed: true },
      { name: 'gearId', type: 'uint256', indexed: false },
    ],
  },
] as const
