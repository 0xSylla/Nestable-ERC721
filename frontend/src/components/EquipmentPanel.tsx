'use client'

import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { SLOT_LIST, GEAR_TYPES, RARITIES, decodeTokenId, RARITY_COLOR, RARITY_BG } from '../lib/constants'
import { ADDRESSES, slotRegistryAbi, gearNFTAbi } from '../lib/contracts'

interface Props { charId: bigint; onGearChanged?: () => void }

export function EquipmentPanel({ charId, onGearChanged }: Props) {
  const { address } = useAccount()
  const queryClient = useQueryClient()

  // Read gearId in every slot
  const slotReads = SLOT_LIST.map((slot) =>
    // eslint-disable-next-line react-hooks/rules-of-hooks
    useReadContract({
      address: ADDRESSES.slotRegistry,
      abi: slotRegistryAbi,
      functionName: 'getSlot',
      args: [charId, slot.key],
    })
  )

  const { writeContractAsync, isPending } = useWriteContract()
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()
  const [actionSlot, setActionSlot] = useState<string | null>(null)

  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash: txHash,
    onSuccess: () => {
      // Invalidate all slot reads + inventory balances after tx confirms
      queryClient.invalidateQueries()
      setTxHash(undefined)
      setActionSlot(null)
      onGearChanged?.()
    },
  } as Parameters<typeof useWaitForTransactionReceipt>[0])

  const handleUnequip = async (slotKey: `0x${string}`, slotLabel: string) => {
    if (!address) return
    setActionSlot(slotLabel)
    try {
      const hash = await writeContractAsync({
        address: ADDRESSES.slotRegistry,
        abi: slotRegistryAbi,
        functionName: 'unequipSlot',
        args: [charId, slotKey],
      })
      setTxHash(hash)
    } catch (e: any) {
      console.error('Unequip failed:', e?.shortMessage ?? e)
      setActionSlot(null)
    }
  }

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <h2 className="font-semibold text-sm text-gray-300 uppercase tracking-wider mb-4">
        Equipment Slots
      </h2>

      <div className="flex flex-col gap-3">
        {SLOT_LIST.map((slot, i) => {
          const gearId = slotReads[i].data as bigint | undefined
          const isEmpty = !gearId || gearId === 0n
          const isBusy  = isPending && actionSlot === slot.label

          return (
            <SlotRow
              key={slot.label}
              slot={slot}
              gearId={isEmpty ? null : gearId!}
              isLoading={slotReads[i].isLoading}
              isBusy={isBusy || (isConfirming && actionSlot === slot.label)}
              onUnequip={() => handleUnequip(slot.key, slot.label)}
            />
          )
        })}
      </div>

      <p className="mt-4 text-xs text-gray-500">
        To equip: select an item from your inventory on the right.
      </p>
    </div>
  )
}

// ─── SlotRow ──────────────────────────────────────────────────────────────────

function SlotRow({
  slot,
  gearId,
  isLoading,
  isBusy,
  onUnequip,
}: {
  slot: typeof SLOT_LIST[number]
  gearId: bigint | null
  isLoading: boolean
  isBusy: boolean
  onUnequip: () => void
}) {
  const { data: gear } = useReadContract({
    address: ADDRESSES.gearNFT,
    abi: gearNFTAbi,
    functionName: 'getGear',
    args: gearId ? [gearId] : undefined,
    query: { enabled: !!gearId },
  })

  const isEmpty = gearId === null

  let rarityClass = ''
  if (gear && !isEmpty) {
    const { rarity } = decodeTokenId(Number(gearId!))
    rarityClass = RARITY_COLOR[rarity]
  }

  return (
    <div
      className={`flex items-center gap-3 rounded-lg border p-3 transition-colors
        ${isEmpty ? 'border-gray-700 bg-gray-800/50' : 'border-gray-600 bg-gray-800'}`}
    >
      {/* Slot icon */}
      <div className="w-9 h-9 flex items-center justify-center text-xl rounded-md bg-gray-700 shrink-0">
        {slot.icon}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className="text-xs text-gray-500 uppercase tracking-wide">{slot.label}</p>
        {isLoading ? (
          <div className="h-4 w-24 rounded bg-gray-700 animate-pulse mt-1" />
        ) : isEmpty ? (
          <p className="text-sm text-gray-500 italic">Empty</p>
        ) : gear ? (
          <div>
            <p className={`text-sm font-medium truncate ${rarityClass.split(' ')[0]}`}>
              {gear.name}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">
              ⚔️ {gear.attack.toString()}  🛡️ {gear.defense.toString()}
            </p>
          </div>
        ) : null}
      </div>

      {/* Unequip button */}
      {!isEmpty && (
        <button
          onClick={onUnequip}
          disabled={isBusy}
          className="shrink-0 px-3 py-1.5 rounded-md text-xs font-medium
                     bg-red-900/50 text-red-300 border border-red-800
                     hover:bg-red-800/60 disabled:opacity-50 disabled:cursor-not-allowed
                     transition-colors"
        >
          {isBusy ? '…' : 'Unequip'}
        </button>
      )}
    </div>
  )
}
