# Nestable Character NFT

A composable NFT system where ERC-721 characters equip ERC-1155 gear through ERC-6551 Token Bound Accounts. Gear is rendered as layered image composites with configurable z-ordering, so equipped items appear between character layers — not just on top.

> Built with Foundry, Solidity 0.8.x, Next.js 14, and Sharp for real-time image compositing.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      Frontend (Next.js)                      │
│    Mint Panel  ·  Equipment Slots  ·  Gear Inventory         │
└──────────────────────┬───────────────────────────────────────┘
                       │ wagmi / viem
┌──────────────────────▼───────────────────────────────────────┐
│                    Smart Contracts (Solidity)                │
│                                                              │
│  CharacterNFT ◄──── MintStageRegistry                        │
│       │              (stages, allowlists, quotas)            │
│       │                                                      │
│       ▼                                                      │
│  ERC-6551 TBA ◄──── SlotRegistry                             │
│  (holds gear)        (equip/unequip, type enforcement)       │
│       │                                                      │
│       ▼                                                      │
│    GearNFT (ERC-1155)                                        │
│    colorURI + bwURI per gear definition                      │
└──────────────────────┬───────────────────────────────────────┘
                       │ ethers.js
┌──────────────────────▼───────────────────────────────────────┐
│               Metadata Renderer (Express + Sharp)            │
│                                                              │
│  Layer Manifest ──► Composite Engine ──► Dynamic PNG         │
│  (IPFS JSON)        (z-ordered layers    (served to          │
│                      + equipped gear)     marketplaces)      │
└──────────────────────────────────────────────────────────────┘
```

### How Equipping Works

1. Player calls `SlotRegistry.equipToSlot(charId, slot, gearId)`
2. SlotRegistry validates gear type matches slot, deploys TBA if needed
3. Gear (ERC-1155) transfers from player wallet to the character's TBA
4. `MetadataUpdate` event (ERC-4906) fires — marketplaces re-fetch the image
5. Renderer reads the layer manifest, inserts gear's color image at the slot's z-index, composites all layers into a single PNG

---

## Smart Contracts

| Contract | Description |
|----------|-------------|
| `CharacterNFT.sol` | ERC-721AC character collection with staged minting and owner airdrops |
| `GearNFT.sol` | ERC-1155 for all gear. Deterministic token IDs: `(rarity+1)*1000 + (gearType+1)` |
| `SlotRegistry.sol` | Equip/unequip enforcement with typed slots, occupant tracking, and force-unequip on slot removal |
| `CharacterTBA.sol` | ERC-6551 Token Bound Account — each character gets one. Locked to SlotRegistry after initialization |
| `MintStageRegistry.sol` | Decoupled mint stage manager. Supports GTD/FCFS allowlists, per-wallet quotas, pricing, and time windows |

### Key Design Decisions

- **Decoupled MintStageRegistry** — Bound 1:1 to a collection but deployed separately. Stage logic doesn't bloat the NFT contract. Supply invariant enforced: `sum(stage.maxSupply) <= collection.maxSupply`.

- **Deterministic Gear IDs** — No sequential counters. Token ID encodes type + rarity, enabling off-chain lookups without indexing events.

- **ERC-4906 MetadataUpdate** — Emitted on every equip/unequip so OpenSea and other marketplaces refresh the character image immediately.

- **Layer Manifest Rendering** — Characters aren't flat images. Each is defined as a z-ordered stack of transparent PNGs with gear slots inserted between layers. A passenger can render *under* the jacket but *over* the shirt.

---

## Layer Manifest System

Each character has a JSON manifest on IPFS that defines its visual composition:

```json
{
  "layers": [
    { "uri": "ipfs://CID/layers/0/background.png", "z": 0  },
    { "slot": "MOON",                               "z": 10 },
    { "uri": "ipfs://CID/layers/0/rockets.png",     "z": 20 },
    { "slot": "PASSENGER",                           "z": 30 },
    { "uri": "ipfs://CID/layers/0/body.png",         "z": 40 },
    { "uri": "ipfs://CID/layers/0/face.png",         "z": 50 },
    { "uri": "ipfs://CID/layers/0/items.png",        "z": 60 }
  ],
  "traits": {
    "Background": "The Starry Night",
    "Rockets": "Apollo 11",
    "Dirac Body": "Black Suit",
    "Dirac Face": "Stoned",
    "Dirac Items": "Laser Eyes"
  }
}
```

- **Static layers** (`uri`) are always rendered
- **Slot layers** (`slot`) are only rendered when gear is equipped — using the gear's `colorURI`
- All layers are composited bottom-to-top by z-index using Sharp
- Gear images auto-resize to match the character canvas

When gear is **equipped**, the GearNFT metadata switches from `colorURI` to `bwURI` (grayscale), signaling to players and marketplaces that the item is in use.

---

## Tech Stack

**Contracts:** Solidity 0.8.x · Foundry · OpenZeppelin · ERC721A · Creator Token Standards

**Renderer:** Node.js · Express · Sharp · ethers.js

**Frontend:** Next.js 14 · TypeScript · Wagmi 2 · RainbowKit · TailwindCSS

**Infrastructure:** IPFS · ERC-6551 · ERC-4906 · GitHub Actions CI

---

## Project Structure

```
├── src/
│   ├── CharacterNFT.sol
│   ├── GearNFT.sol
│   ├── CharacterTBA.sol
│   ├── SlotRegistry.sol
│   ├── Base/
│   │   └── BaseNFTNativePaymentToken.sol
│   ├── Registry/
│   │   └── MintStageRegistry.sol
│   └── Interfaces/
├── script/
│   ├── Deploy.s.sol              # Unified deploy (uses HelperConfig)
│   ├── HelperConfig.s.sol        # Multi-chain config (Anvil/Sepolia/Base)
│   └── SetupLocal.s.sol          # Post-deploy: define gear, mint stage, seed tokens
├── test/
│   ├── unit/                     # 63 passing tests
│   ├── integrations/
│   └── mocks/
├── renderer/                     # Off-chain metadata + image compositing
│   ├── index.js
│   └── manifests/                # Local dev layer manifests
├── frontend/                     # Next.js dApp
│   └── src/
│       ├── app/
│       ├── components/
│       └── lib/
├── scripts/                      # Python utilities
│   ├── generate_collection.py    # Generate N unique characters from layer variants
│   └── convert_bw.py             # Batch convert images to grayscale
├── Makefile
├── foundry.toml
└── .github/workflows/test.yml
```

---

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 18+
- Python 3.10+ (for asset generation scripts)

### Local Development

```bash
# 1. Install dependencies
make install
cd renderer && npm install
cd ../frontend && npm install

# 2. Start Anvil
make anvil

# 3. Deploy contracts (auto-deploys mock ERC-6551 registry)
make deploy-anvil

# 4. Setup test data (define gear, create free mint stage, mint tokens)
make setup-anvil

# 5. Start renderer (port 3000)
cd renderer && npm start

# 6. Start frontend (port 3001)
cd frontend && npm run dev
```

### Run Tests

```bash
make test
# 63 tests passing across GearNFT and SlotRegistry
```

### Generate a Collection

```bash
# Generate 100 unique characters from layer variants
python scripts/generate_collection.py output_folder 100

# Upload to IPFS, get CID, then update manifests
python scripts/generate_collection.py output_folder 100 --ipfs-cid YOUR_CID
```

---

## Deployment

The deploy script uses `HelperConfig` for multi-chain support:

| Chain | ERC-6551 Registry | Config |
|-------|-------------------|--------|
| Anvil (31337) | Auto-deployed MockERC6551Registry | 3 max supply, test CIDs |
| Sepolia (11155111) | Canonical `0x000000006551c19487814612e58FE06813775758` | Production config |
| Base (8453) | Canonical | Production config |

```bash
# Sepolia
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY

# Or via Makefile
make deploy-sepolia
```

---

## Security Considerations

- **Reentrancy Guards** on all state-mutating functions in SlotRegistry and MintStageRegistry
- **One-time initialization lock** on CharacterTBA — cannot be re-pointed after setup
- **Supply invariant** enforced across mint stages — `sum(stage.maxSupply) <= collection.i_maxSupply`
- **Typed slot enforcement** — gear type encoded in token ID, validated on-chain before equip
- **CEI pattern** (Checks-Effects-Interactions) followed in equip/unequip flows
- **Owner-only admin functions** — slot management, gear definition, minting

---

## License

MIT
