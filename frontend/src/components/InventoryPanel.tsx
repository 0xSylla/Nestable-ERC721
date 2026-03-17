'use client'

import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import {
  ALL_GEAR_IDS,
  SLOT_LIST,
  decodeTokenId,
  RARITY_COLOR,
  RARITY_BG,
} from '../lib/constants'
import { ADDRESSES, gearNFTAbi, slotRegistryAbi } from '../lib/contracts'
import { GearCard } from './GearCard'

interface Props { charId: bigint; onGearChanged?: () => void }

export function InventoryPanel({ charId, onGearChanged }: Props) {
  const { address } = useAccount()
  const queryClient = useQueryClient()

  // Batch-read balances for all 20 possible gear IDs in one call
  const { data: balances, isLoading: balancesLoading } = useReadContract({
    address: ADDRESSES.gearNFT,
    abi: gearNFTAbi,
    functionName: 'balanceOfBatch',
    args: [
      ALL_GEAR_IDS.map(() => address as `0x${string}`),
      ALL_GEAR_IDS.map(BigInt),
    ],
    query: { enabled: !!address },
  })

  // Check approval
  const { data: isApproved, refetch: refetchApproval } = useReadContract({
    address: ADDRESSES.gearNFT,
    abi: gearNFTAbi,
    functionName: 'isApprovedForAll',
    args: [address as `0x${string}`, ADDRESSES.slotRegistry],
    query: { enabled: !!address },
  })

  const { writeContractAsync, isPending } = useWriteContract()
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()
  const [pendingGearId, setPendingGearId] = useState<number | null>(null)

  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash: txHash,
    onSuccess: () => {
      queryClient.invalidateQueries()
      refetchApproval()
      setTxHash(undefined)
      setPendingGearId(null)
      onGearChanged?.()
    },
  } as Parameters<typeof useWaitForTransactionReceipt>[0])

  // Items the player holds (balance > 0)
  const ownedItems = ALL_GEAR_IDS.filter((id, i) => {
    const bal = balances?.[i]
    return bal !== undefined && bal > 0n
  })

  // Approve SlotRegistry to move gear
  const handleApprove = async () => {
    try {
      const hash = await writeContractAsync({
        address: ADDRESSES.gearNFT,
        abi: gearNFTAbi,
        functionName: 'setApprovalForAll',
        args: [ADDRESSES.slotRegistry, true],
      })
      setTxHash(hash)
    } catch (e: any) {
      console.error('Approval failed:', e?.shortMessage ?? e)
    }
  }

  // Equip gear into the matching slot
  const handleEquip = async (gearId: number) => {
    const { gearTypeIndex } = getSlotForGear(gearId)
    const slot = SLOT_LIST[gearTypeIndex]
    if (!slot) return

    setPendingGearId(gearId)
    try {
      const hash = await writeContractAsync({
        address: ADDRESSES.slotRegistry,
        abi: slotRegistryAbi,
        functionName: 'equipToSlot',
        args: [charId, slot.key, BigInt(gearId)],
      })
      setTxHash(hash)
    } catch (e: any) {
      console.error('Equip failed:', e?.shortMessage ?? e)
      setPendingGearId(null)
    }
  }

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-semibold text-sm text-gray-300 uppercase tracking-wider">
          Your Gear Inventory
        </h2>

        {/* Approval banner */}
        {!isApproved && (
          <button
            onClick={handleApprove}
            disabled={isPending || isConfirming}
            className="px-3 py-1.5 rounded-md text-xs font-medium
                       bg-yellow-900/60 text-yellow-300 border border-yellow-700
                       hover:bg-yellow-800/60 disabled:opacity-50 transition-colors"
          >
            {isPending || isConfirming ? 'Approving…' : 'Approve SlotRegistry'}
          </button>
        )}
      </div>

      {!isApproved && (
        <div className="mb-4 rounded-lg bg-yellow-950/40 border border-yellow-900 px-4 py-3 text-sm text-yellow-300">
          ⚠️ You need to approve SlotRegistry to move your gear before equipping.
        </div>
      )}

      {balancesLoading ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="aspect-square rounded-xl bg-gray-800 animate-pulse" />
          ))}
        </div>
      ) : ownedItems.length === 0 ? (
        <p className="text-gray-500 text-sm italic py-8 text-center">
          No gear in your wallet. Ask the contract owner to mint some.
        </p>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {ownedItems.map((gearId, i) => {
            const balance = balances?.[ALL_GEAR_IDS.indexOf(gearId)] ?? 0n
            return (
              <GearCard
                key={gearId}
                gearId={gearId}
                walletBalance={balance}
                charId={charId}
                isApproved={!!isApproved}
                isPending={pendingGearId === gearId && (isPending || isConfirming)}
                onEquip={() => handleEquip(gearId)}
              />
            )
          })}
        </div>
      )}
    </div>
  )
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getSlotForGear(gearId: number) {
  const gearTypeIndex = (gearId % 1000) - 1 // 0=HELMET 1=ARMOR 2=BOOTS 3=WEAPON
  return { gearTypeIndex, slot: SLOT_LIST[gearTypeIndex] }
}
