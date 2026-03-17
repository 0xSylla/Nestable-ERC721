import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { hardhat, sepolia, base } from 'wagmi/chains'

export const config = getDefaultConfig({
  appName: 'Nestable Character NFT',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? 'demo',
  chains: [hardhat, sepolia, base],
  ssr: true,
})
