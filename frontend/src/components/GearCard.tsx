'use client'

import { useReadContracts } from 'wagmi'
import { ADDRESSES, gearNFTAbi, slotRegistryAbi } from '../lib/contracts'
import { SLOT_LIST, decodeTokenId, RARITY_COLOR, RARITY_BG } from '../lib/constants'

interface Props {
  gearId:        number
  walletBalance: bigint
  charId:        bigint
  isApproved:    boolean
  isPending:     boolean
  onEquip:       () => void
}

export function GearCard({ gearId, walletBalance, charId, isApproved, isPending, onEquip }: Props) {
  const { gearType, rarity } = decodeTokenId(gearId)
  const slotForGear = SLOT_LIST.find((s) => s.gearTypeIndex === SLOT_LIST.findIndex((sl) => sl.label.toUpperCase() === gearType))

  // Batch: getGear + gearEquippedCount + getSlot (is this char's slot already filled?)
  const matchingSlot = SLOT_LIST.find(
    (s) => s.gearTypeIndex === (gearId % 1000) - 1
  )

  const { data } = useReadContracts({
    contracts: [
      {
        address: ADDRESSES.gearNFT,
        abi: gearNFTAbi,
        functionName: 'getGear',
        args: [BigInt(gearId)],
      },
      {
        address: ADDRESSES.slotRegistry,
        abi: slotRegistryAbi,
        functionName: 'gearEquippedCount',
        args: [BigInt(gearId)],
      },
      // Check if the character's matching slot is already occupied
      ...(matchingSlot
        ? [{
            address: ADDRESSES.slotRegistry,
            abi: slotRegistryAbi,
            functionName: 'getSlot',
            args: [charId, matchingSlot.key],
          } as const]
        : []),
    ],
  })

  const gear            = data?.[0]?.result as any
  const equippedCount   = data?.[1]?.result as bigint | undefined
  const slotCurrentGear = data?.[2]?.result as bigint | undefined

  const isEquippedGlobally = (equippedCount ?? 0n) > 0n
  const slotOccupied       = slotCurrentGear !== undefined && slotCurrentGear !== 0n
  const canEquip           = isApproved && !slotOccupied && walletBalance > 0n

  const rarityColorClass = RARITY_COLOR[rarity]
  const rarityBgClass    = RARITY_BG[rarity]

  // Resolve IPFS URI for display
  const imageURI = gear
    ? isEquippedGlobally
      ? resolveIPFS(gear.bwURI)    // B&W if any copy equipped
      : resolveIPFS(gear.colorURI) // full colour otherwise
    : null

  return (
    <div
      className={`relative rounded-xl border overflow-hidden flex flex-col
        ${rarityColorClass.split(' ')[1]}
        ${rarityBgClass}
        transition-all`}
    >
      {/* Image */}
      <div className="aspect-square relative bg-gray-800">
        {imageURI ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={imageURI}
            alt={gear?.name ?? `Gear #${gearId}`}
            className={`w-full h-full object-cover transition-all duration-300
              ${isEquippedGlobally ? 'grayscale brightness-75' : ''}`}
            onError={(e) => { ;(e.target as HTMLImageElement).style.display = 'none' }}
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-3xl">
            {SLOT_LIST.find((s) => s.gearTypeIndex === (gearId % 1000) - 1)?.icon ?? '📦'}
          </div>
        )}

        {/* Equipped badge */}
        {isEquippedGlobally && (
          <div className="absolute top-1.5 left-1.5 bg-black/70 rounded px-1.5 py-0.5 text-[10px] font-medium text-gray-300">
            EQUIPPED
          </div>
        )}

        {/* Balance badge */}
        {walletBalance > 1n && (
          <div className="absolute top-1.5 right-1.5 bg-black/70 rounded px-1.5 py-0.5 text-[10px] text-white font-bold">
            ×{walletBalance.toString()}
          </div>
        )}
      </div>

      {/* Info */}
      <div className="p-2.5 flex flex-col gap-1.5 flex-1">
        {gear ? (
          <>
            <p className={`text-xs font-bold truncate ${rarityColorClass.split(' ')[0]}`}>
              {gear.name}
            </p>
            <p className="text-[10px] text-gray-500 uppercase tracking-wide">
              {rarity} {gearType}
            </p>
            <div className="flex gap-2 text-[11px] text-gray-300 mt-0.5">
              <span>⚔️ {gear.attack.toString()}</span>
              <span>🛡️ {gear.defense.toString()}</span>
            </div>
          </>
        ) : (
          <div className="h-10 animate-pulse">
            <div className="h-3 w-3/4 bg-gray-700 rounded mb-1" />
            <div className="h-3 w-1/2 bg-gray-700 rounded" />
          </div>
        )}

        {/* Equip button */}
        <button
          onClick={onEquip}
          disabled={!canEquip || isPending}
          title={
            !isApproved    ? 'Approve SlotRegistry first'  :
            slotOccupied   ? 'This slot is already filled — unequip first' :
            walletBalance === 0n ? 'No copies in your wallet' : ''
          }
          className={`mt-auto w-full py-1.5 rounded-md text-xs font-semibold transition-all
            ${canEquip && !isPending
              ? 'bg-indigo-600 hover:bg-indigo-500 text-white cursor-pointer'
              : 'bg-gray-700 text-gray-500 cursor-not-allowed opacity-60'
            }`}
        >
          {isPending        ? 'Equipping…'      :
           slotOccupied     ? 'Slot occupied'   :
           !isApproved      ? 'Need approval'   :
                              'Equip'}
        </button>
      </div>
    </div>
  )
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function resolveIPFS(uri: string): string {
  if (!uri) return ''
  if (uri.startsWith('ipfs://')) return uri.replace('ipfs://', 'https://ipfs.io/ipfs/')
  return uri
}
