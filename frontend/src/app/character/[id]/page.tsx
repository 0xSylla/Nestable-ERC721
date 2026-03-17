'use client'

import { useState } from 'react'
import { useAccount } from 'wagmi'
import Link from 'next/link'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { EquipmentPanel } from '../../../components/EquipmentPanel'
import { InventoryPanel } from '../../../components/InventoryPanel'
import { RENDERER_URL } from '../../../lib/contracts'

export default function CharacterPage({ params }: { params: { id: string } }) {
  const { id } = params
  const charId = BigInt(id)
  const { isConnected } = useAccount()
  const [imageKey, setImageKey] = useState(0)

  const refreshImage = () => setImageKey((k) => k + 1)

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/" className="text-gray-400 hover:text-white transition-colors text-sm">
            ← Characters
          </Link>
          <h1 className="text-xl font-bold">Character #{id}</h1>
        </div>
        <ConnectButton />
      </header>

      {!isConnected ? (
        <div className="flex flex-col items-center justify-center gap-4 py-24">
          <p className="text-gray-400">Connect your wallet to manage gear.</p>
          <ConnectButton />
        </div>
      ) : (
        <main className="max-w-6xl mx-auto px-6 py-8 grid grid-cols-1 lg:grid-cols-[340px_1fr] gap-8">
          {/* Left: Character portrait + equipped slots */}
          <div className="flex flex-col gap-6">
            <CharacterPortrait charId={charId} imageKey={imageKey} />
            <EquipmentPanel charId={charId} onGearChanged={refreshImage} />
          </div>

          {/* Right: Gear inventory */}
          <InventoryPanel charId={charId} onGearChanged={refreshImage} />
        </main>
      )}
    </div>
  )
}

// ─── Portrait ─────────────────────────────────────────────────────────────────

function CharacterPortrait({ charId, imageKey }: { charId: bigint; imageKey: number }) {
  const imageUrl = RENDERER_URL ? `${RENDERER_URL}/character/${charId}/image?v=${imageKey}` : null

  return (
    <div className="rounded-xl overflow-hidden border border-gray-800 bg-gray-900">
      <div className="aspect-square relative">
        {imageUrl ? (
          // Using img instead of next/image to support dynamic renderer URL at runtime
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={imageUrl}
            alt={`Character #${charId}`}
            className="w-full h-full object-cover"
            onError={(e) => {
              ;(e.target as HTMLImageElement).style.display = 'none'
            }}
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-7xl bg-gray-800">
            🧙
          </div>
        )}
        {/* Refresh hint */}
        <div className="absolute top-2 right-2 bg-black/60 rounded px-2 py-1 text-xs text-gray-400">
          Image updates on equip
        </div>
      </div>
      <div className="px-4 py-3">
        <p className="text-sm text-gray-400">
          Character image is rendered live by compositing equipped gear layers.
          Equipped gear appears in grayscale on the character.
        </p>
      </div>
    </div>
  )
}
