'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, usePublicClient } from 'wagmi'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { ADDRESSES, RENDERER_URL, characterNFTAbi } from '../lib/contracts'
import MintPanel from '../components/MintPanel'

export default function Home() {
  const { address, isConnected } = useAccount()
  const publicClient = usePublicClient()
  const [charIds, setCharIds] = useState<bigint[]>([])
  const [loading, setLoading] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)

  // Enumerate character tokens via Transfer events filtered by current owner
  useEffect(() => {
    if (!isConnected || !address || !publicClient || !ADDRESSES.characterNFT) return

    setLoading(true)
    ;(async () => {
      try {
        // Read max supply to know the token ID range
        const maxSupply = await publicClient.readContract({
          address: ADDRESSES.characterNFT,
          abi: characterNFTAbi,
          functionName: 'i_maxSupply',
        }) as bigint

        // Check ownership of each possible token ID (ERC721A starts at 0)
        const owned: bigint[] = []
        for (let id = 0n; id < maxSupply; id++) {
          try {
            const owner = await publicClient.readContract({
              address: ADDRESSES.characterNFT,
              abi: characterNFTAbi,
              functionName: 'ownerOf',
              args: [id],
            }) as string
            if (owner.toLowerCase() === address.toLowerCase()) owned.push(id)
          } catch {
            // Token not minted yet — stop scanning
            break
          }
        }
        setCharIds(owned.sort((a, b) => Number(a - b)))
      } catch (e) {
        console.error('Failed to fetch characters:', e)
      } finally {
        setLoading(false)
      }
    })()
  }, [isConnected, address, publicClient, refreshKey])

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
        <h1 className="text-xl font-bold tracking-wide">⚔️ Nestable Character NFT</h1>
        <ConnectButton />
      </header>

      <main className="max-w-5xl mx-auto px-6 py-10">
        {isConnected && (
          <MintPanel onMinted={() => setRefreshKey((k) => k + 1)} />
        )}

        {!isConnected ? (
          <div className="flex flex-col items-center justify-center gap-6 py-24">
            <p className="text-3xl font-bold">Equip. Evolve. Conquer.</p>
            <p className="text-gray-400 text-center max-w-md">
              Connect your wallet to view your characters and equip gear to power them up.
            </p>
            <ConnectButton />
          </div>
        ) : loading ? (
          <div className="text-center py-24 text-gray-400">Loading your characters…</div>
        ) : charIds.length === 0 ? (
          <div className="text-center py-24 text-gray-400">
            <p className="text-lg mb-2">You don't own any characters yet.</p>
            <p className="text-sm">Use the mint panel above to get started.</p>
          </div>
        ) : (
          <>
            <h2 className="text-lg font-semibold mb-6 text-gray-300">
              Your Characters ({charIds.length})
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
              {charIds.map((id) => (
                <CharacterCard key={id.toString()} charId={id} />
              ))}
            </div>
          </>
        )}
      </main>
    </div>
  )
}

// ─── CharacterCard ─────────────────────────────────────────────────────────────

function CharacterCard({ charId }: { charId: bigint }) {
  const imageUrl = RENDERER_URL
    ? `${RENDERER_URL}/character/${charId}/image`
    : null

  return (
    <Link
      href={`/character/${charId}`}
      className="group block rounded-xl border border-gray-800 bg-gray-900 overflow-hidden
                 hover:border-gray-600 hover:shadow-lg hover:shadow-black/40 transition-all"
    >
      <div className="aspect-square bg-gray-800 relative overflow-hidden">
        {imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={imageUrl}
            alt={`Character #${charId}`}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
            onError={(e) => {
              ;(e.target as HTMLImageElement).src = '/placeholder-character.png'
            }}
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-4xl">🧙</div>
        )}
      </div>
      <div className="p-3">
        <p className="font-semibold text-sm">Character #{charId.toString()}</p>
        <p className="text-xs text-gray-400 mt-0.5 group-hover:text-gray-300 transition-colors">
          View & equip →
        </p>
      </div>
    </Link>
  )
}
