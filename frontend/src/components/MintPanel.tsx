'use client'

import { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ADDRESSES, characterNFTAbi, gearNFTAbi } from '../lib/contracts'
import { GEAR_TYPES, RARITIES, computeTokenId, RARITY_COLOR, RARITY_BG, type GearType, type Rarity } from '../lib/constants'

export default function MintPanel({ onMinted }: { onMinted?: () => void }) {
  const { address } = useAccount()

  // ─── Character Mint ───────────────────────────────────────────────────────
  const [charAmount, setCharAmount] = useState(1)
  const {
    writeContract: writeCharMint,
    data: charTxHash,
    isPending: charPending,
    error: charError,
  } = useWriteContract()

  const { isLoading: charConfirming, isSuccess: charSuccess } = useWaitForTransactionReceipt({
    hash: charTxHash,
  })

  function mintCharacters() {
    writeCharMint({
      address: ADDRESSES.characterNFT,
      abi: characterNFTAbi,
      functionName: 'batchMint',
      args: [0n, BigInt(charAmount)],
      value: 0n, // free stage
    })
  }

  // ─── Gear Mint ────────────────────────────────────────────────────────────
  const [selectedGearType, setSelectedGearType] = useState<GearType>('MOON')
  const [selectedRarity, setSelectedRarity] = useState<Rarity>('COMMON')
  const [gearAmount, setGearAmount] = useState(1)
  const {
    writeContract: writeGearMint,
    data: gearTxHash,
    isPending: gearPending,
    error: gearError,
  } = useWriteContract()

  const { isLoading: gearConfirming, isSuccess: gearSuccess } = useWaitForTransactionReceipt({
    hash: gearTxHash,
  })

  function mintGear() {
    if (!address) return
    const tokenId = computeTokenId(selectedGearType, selectedRarity)
    writeGearMint({
      address: ADDRESSES.gearNFT,
      abi: gearNFTAbi,
      functionName: 'mint',
      args: [address, BigInt(tokenId), BigInt(gearAmount)],
    })
  }

  // Refresh parent when character mint succeeds
  if (charSuccess && onMinted) {
    setTimeout(onMinted, 500)
  }

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-6 mb-8">
      <h2 className="text-lg font-bold mb-4 text-gray-200">Tester Mint Panel</h2>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* ─── Character Mint ─────────────────────────────────────────────── */}
        <div className="rounded-lg border border-gray-700 bg-gray-800/50 p-4">
          <h3 className="font-semibold text-sm text-gray-300 mb-3">Mint Characters</h3>
          <p className="text-xs text-gray-500 mb-3">Free public mint (stage 0). Max 5 per wallet.</p>

          <div className="flex items-center gap-2 mb-3">
            <label className="text-xs text-gray-400">Amount:</label>
            <input
              type="number"
              min={1}
              max={5}
              value={charAmount}
              onChange={(e) => setCharAmount(Math.max(1, Math.min(5, Number(e.target.value))))}
              className="w-16 bg-gray-700 border border-gray-600 rounded px-2 py-1 text-sm text-white"
            />
          </div>

          <button
            onClick={mintCharacters}
            disabled={charPending || charConfirming}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:bg-gray-600 disabled:cursor-not-allowed
                       text-white text-sm font-medium rounded-lg px-4 py-2 transition-colors"
          >
            {charPending ? 'Confirm in wallet...' : charConfirming ? 'Minting...' : `Mint ${charAmount} Character${charAmount > 1 ? 's' : ''}`}
          </button>

          {charSuccess && <p className="text-xs text-green-400 mt-2">Characters minted!</p>}
          {charError && <p className="text-xs text-red-400 mt-2">{charError.message.slice(0, 100)}</p>}
        </div>

        {/* ─── Gear Mint ─────────────────────────────────────────────────── */}
        <div className="rounded-lg border border-gray-700 bg-gray-800/50 p-4">
          <h3 className="font-semibold text-sm text-gray-300 mb-3">Mint Gear</h3>
          <p className="text-xs text-gray-500 mb-3">Owner-only. Mints gear to your wallet.</p>

          <div className="flex items-center gap-2 mb-2">
            <label className="text-xs text-gray-400">Type:</label>
            <div className="flex gap-1">
              {GEAR_TYPES.map((gt) => (
                <button
                  key={gt}
                  onClick={() => setSelectedGearType(gt)}
                  className={`text-xs px-2 py-1 rounded border transition-colors ${
                    selectedGearType === gt
                      ? 'border-indigo-500 bg-indigo-600/30 text-white'
                      : 'border-gray-600 bg-gray-700 text-gray-400 hover:border-gray-500'
                  }`}
                >
                  {gt === 'MOON' ? '🌙' : '🧑‍🚀'} {gt}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-2 mb-2">
            <label className="text-xs text-gray-400">Rarity:</label>
            <div className="flex gap-1 flex-wrap">
              {RARITIES.map((r) => (
                <button
                  key={r}
                  onClick={() => setSelectedRarity(r)}
                  className={`text-xs px-2 py-1 rounded border transition-colors ${
                    selectedRarity === r
                      ? `${RARITY_COLOR[r]} ${RARITY_BG[r]}`
                      : 'border-gray-600 bg-gray-700 text-gray-400 hover:border-gray-500'
                  }`}
                >
                  {r}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-2 mb-1">
            <label className="text-xs text-gray-400">Amount:</label>
            <input
              type="number"
              min={1}
              max={10}
              value={gearAmount}
              onChange={(e) => setGearAmount(Math.max(1, Math.min(10, Number(e.target.value))))}
              className="w-16 bg-gray-700 border border-gray-600 rounded px-2 py-1 text-sm text-white"
            />
          </div>

          <p className="text-xs text-gray-500 mb-3">
            Token ID: <span className="text-gray-300 font-mono">{computeTokenId(selectedGearType, selectedRarity)}</span>
          </p>

          <button
            onClick={mintGear}
            disabled={gearPending || gearConfirming}
            className="w-full bg-emerald-600 hover:bg-emerald-500 disabled:bg-gray-600 disabled:cursor-not-allowed
                       text-white text-sm font-medium rounded-lg px-4 py-2 transition-colors"
          >
            {gearPending ? 'Confirm in wallet...' : gearConfirming ? 'Minting...' : `Mint ${gearAmount} ${selectedRarity} ${selectedGearType}`}
          </button>

          {gearSuccess && <p className="text-xs text-green-400 mt-2">Gear minted!</p>}
          {gearError && <p className="text-xs text-red-400 mt-2">{gearError.message.slice(0, 100)}</p>}
        </div>
      </div>
    </div>
  )
}
