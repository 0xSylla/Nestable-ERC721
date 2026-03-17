# Designing Composable NFT Systems: Architecture Lessons from Building Nestable Character NFTs

*How I designed a modular smart contract system where ERC-721 characters equip ERC-1155 gear through Token Bound Accounts — and what I learned about system design along the way.*

---

Most NFT projects are static. You mint a JPEG, it sits in your wallet, and that's it. But what if your NFT could *own* other NFTs? What if equipping a sword to your character changed its on-chain image in real time — and marketplaces like OpenSea reflected that change instantly?

That's what I built. And in this article, I'll walk through the architecture decisions, trade-offs, and patterns that made it work — not just the "what," but the "why."

If you're a Solidity developer thinking about system design beyond single-contract projects, this is for you.

---

## The Problem Space

I wanted to build an NFT character system where:

1. Characters (ERC-721) can equip gear items (ERC-1155)
2. Equipped gear is *actually held* by the character on-chain — not just mapped in a database
3. The character's image updates dynamically based on what's equipped
4. Gear renders at specific visual layers (a passenger sits *behind* the jacket but *in front of* the rocket)
5. Marketplaces see changes immediately without manual refresh

This touches five different ERC standards, three off-chain services, and a lot of contract-to-contract interaction. Getting the architecture right mattered more than getting any single contract right.

---

## Principle 1: Separate Concerns Into Single-Purpose Contracts

The biggest mistake I see in NFT projects is putting everything into one monolithic contract. Minting logic, metadata, royalties, game mechanics — all crammed into 800 lines of Solidity. It's impossible to test, impossible to upgrade, and impossible to reason about.

Here's how I split the system:

```
CharacterNFT    — minting + ownership (what it IS)
GearNFT         — gear definitions + supply (what EXISTS)
SlotRegistry    — equip/unequip rules (what HAPPENS)
CharacterTBA    — asset custody (where gear LIVES)
MintStageRegistry — mint phases + allowlists (who can MINT)
```

Each contract has exactly one job. The `CharacterNFT` doesn't know about slots. The `SlotRegistry` doesn't know about mint stages. The `GearNFT` doesn't know about characters at all.

**Why this matters:** When I needed to add a new mint stage type (GTD vs FCFS allowlists), I only touched `MintStageRegistry`. Zero changes to the NFT contract. Zero risk of breaking equip logic.

### The MintStageRegistry Pattern

Most projects embed minting logic directly in the NFT contract:

```solidity
// The typical approach — everything in one contract
contract MyNFT is ERC721 {
    uint256 public price;
    uint256 public maxPerWallet;
    mapping(address => uint256) public minted;
    bool public isActive;

    function mint(uint256 amount) external payable {
        require(isActive, "Not active");
        require(minted[msg.sender] + amount <= maxPerWallet);
        require(msg.value >= price * amount);
        // ... mint logic
    }
}
```

This works for simple drops, but falls apart when you need multiple stages (OG list, whitelist, public), different prices per stage, time windows, or supply caps per stage.

Instead, I decoupled it:

```solidity
// The NFT contract delegates ALL stage logic to the registry
function batchMint(uint256 stageId, uint256 amount) external payable {
    if (_totalMinted() + amount > i_maxSupply) revert ExceedsMaxSupply();

    // One call validates: stage active? time window? allowlisted? quota? supply?
    uint256 totalCost = i_registry.validateAndRecordMint(stageId, msg.sender, amount);

    if (msg.value < totalCost) revert InsufficientEther();
    _mint(msg.sender, amount);
}
```

The registry is bound to the collection 1:1 — it can never be repointed. But all the complex stage logic lives in its own contract, with its own tests, its own storage, and its own admin functions.

**A critical invariant:** The sum of all stage `maxSupply` values can never exceed the collection's total supply. The registry enforces this by reading `i_maxSupply` from the bound collection on every `addStage` and `updateStage` call. Cross-contract invariants like this are easy to miss but essential to get right.

---

## Principle 2: Use ERC-6551 for Real Asset Ownership

The core insight of this project: when a character "equips" gear, the gear should actually *move* to an account owned by the character token.

ERC-6551 (Token Bound Accounts) gives every NFT its own smart contract wallet. The wallet's address is deterministic — derived from the token contract, token ID, chain ID, and a salt. No deployment needed until the first interaction.

```solidity
// SlotRegistry.equipToSlot — the core equip flow
function equipToSlot(uint256 charId, bytes32 slot, uint256 gearId) external nonReentrant {
    require(IERC721(characterNFT).ownerOf(charId) == msg.sender, "Not character owner");

    // Deploy TBA if it doesn't exist yet (idempotent)
    address tba = erc6551Registry.createAccount(
        tbaImplementation, TBA_SALT, block.chainid, characterNFT, charId
    );

    // Transfer gear FROM player TO character's TBA
    IERC1155(gearContract).safeTransferFrom(msg.sender, tba, gearId, 1, "");
}
```

**Why not just use a mapping?** I could have done `mapping(uint256 charId => mapping(bytes32 slot => uint256 gearId))` and called it a day. But then the gear would still *physically* sit in the player's wallet. Block explorers would show it. Marketplaces would list it. The player could transfer it while it's "equipped."

With TBAs, equipped gear literally moves to the character's wallet. If you look up Character #42 on Etherscan, you'll see its TBA holding all its equipped items. This is *real* composability, not database composability.

### The Initialization Lock Pattern

There's a subtle chicken-and-egg problem: CharacterTBA needs to know the SlotRegistry address (to authorize gear transfers), but SlotRegistry needs the CharacterTBA address (as the implementation for TBA proxies).

The solution is a two-phase setup with a permanent lock:

```solidity
contract CharacterTBA {
    address public slotRegistry;
    bool private _initialized;

    constructor(address gearContract_) {
        // Set at deployment time — no slot registry yet
        gearContract = gearContract_;
    }

    function initialize(address slotRegistry_) external {
        require(!_initialized, "Already initialized");
        slotRegistry = slotRegistry_;
        _initialized = true;  // Can never be called again
    }

    function execute(address to, uint256 value, bytes calldata data, uint8)
        external payable returns (bytes memory)
    {
        // ONLY SlotRegistry can make the TBA execute calls
        require(msg.sender == slotRegistry, "Only SlotRegistry");
        // ...
    }
}
```

Deploy order: GearNFT → CharacterTBA(gearNFT) → SlotRegistry(characterTBA) → CharacterTBA.initialize(slotRegistry).

After `initialize()`, the TBA is permanently locked to that SlotRegistry. Every TBA proxy (one per character) delegates to this implementation, so they're all locked too. This means gear can *only* enter and exit through the SlotRegistry's equip/unequip functions.

---

## Principle 3: Encode Semantics Into Token IDs

GearNFT uses a deterministic token ID formula instead of a sequential counter:

```
tokenId = (rarity + 1) * 1000 + (gearType + 1)

COMMON MOON      = 1001    COMMON PASSENGER  = 1002
UNCOMMON MOON    = 2001    UNCOMMON PASSENGER = 2002
RARE MOON        = 3001    RARE PASSENGER     = 3002
EPIC MOON        = 4001    EPIC PASSENGER     = 4002
LEGENDARY MOON   = 5001    LEGENDARY PASSENGER = 5002
```

Any contract or off-chain service can decode a token ID back to its type and rarity without calling the contract:

```solidity
function _decodeGearType(uint256 gearId) internal pure returns (uint8) {
    return uint8((gearId % 1000) - 1);  // 0 = MOON, 1 = PASSENGER
}
```

The SlotRegistry uses this to enforce type restrictions. A MOON slot (gearTypeIndex=0) only accepts gear where `gearId % 1000 == 1`. No lookup table. No external calls. Pure math.

**Trade-off:** This limits you to 999 gear types and assumes the encoding scheme never changes. For a game with a fixed taxonomy, this is fine. For an open-ended system where anyone can define new types, you'd want a registry pattern instead.

---

## Principle 4: Design the Off-Chain Layer as a First-Class Citizen

Smart contracts define *state*. But NFTs need *images*. The metadata renderer is just as architecturally important as the contracts.

### The Layer Manifest Pattern

The naive approach: store one flat PNG per character on IPFS. When gear is equipped, re-render the image off-chain and update the URI.

The problem: gear needs to render *between* character layers. A passenger should appear behind the character's jacket but in front of the rocket. A flat base image makes this impossible.

My solution: each character has a **layer manifest** — a JSON file on IPFS that defines a z-ordered stack of transparent PNGs with gear slots inserted at specific positions:

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
  ]
}
```

The renderer:
1. Fetches the manifest from IPFS
2. Reads equipped gear from the SlotRegistry contract
3. For each `slot` layer, substitutes the gear's `colorURI` if something is equipped
4. Composites all layers bottom-to-top using Sharp
5. Returns a PNG

Static layers are immutable on IPFS. Dynamic layers (gear) change based on on-chain state. The manifest is the bridge between the two.

### The Dual-Image Pattern for Gear

Each gear definition stores two image URIs:

- `colorURI` — full-colour image (shown when unequipped, composited onto the character when equipped)
- `bwURI` — grayscale image (shown in the gear's *own* metadata when equipped)

When a player equips a sword, two things change visually:
1. The **character's** image gains a color sword layer
2. The **sword's** marketplace listing switches to grayscale — signaling "this item is in use"

The renderer decides which to serve by querying `SlotRegistry.gearEquippedCount(gearId)`. If > 0, serve the B&W version.

### Marketplace Integration via ERC-4906

The final piece: telling marketplaces to re-fetch metadata. ERC-4906 defines a `MetadataUpdate(uint256 tokenId)` event. When the SlotRegistry emits this on equip/unequip, OpenSea and other marketplaces know to refresh that token's image.

```solidity
// Emitted in both equipToSlot and unequipSlot
emit MetadataUpdate(charId);       // Character image changed
emit GearMetadataUpdate(gearId);   // Gear image changed (color <-> B&W)
```

No manual refresh. No waiting. The image updates propagate automatically.

---

## Principle 5: Make Deployment Reproducible and Chain-Aware

I used the **HelperConfig pattern** to handle multi-chain deployment without hardcoding addresses:

```solidity
contract HelperConfig is Script {
    struct NetworkConfig {
        address erc6551Registry;
        string  charName;
        uint256 charMaxSupply;
        // ...
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();  // Deploy mocks automatically
        } else {
            return s_networkConfigs[chainId]; // Use real addresses
        }
    }
}
```

On Anvil (local), it auto-deploys a `MockERC6551Registry`. On Sepolia or Base, it uses the canonical registry at `0x000000006551c19487814612e58FE06813775758`.

The deploy script doesn't know or care which chain it's on:

```solidity
HelperConfig helperConfig = new HelperConfig();
NetworkConfig memory config = helperConfig.getConfig();
// Deploy everything using config.erc6551Registry, config.charMaxSupply, etc.
```

Same script, same command, any chain.

---

## What I'd Do Differently

**Gas optimization on occupant tracking.** The SlotRegistry tracks which characters occupy each slot using a dynamic array with swap-and-pop deletion. This is O(1) for removal but costs gas for storage. For a system with thousands of equipped characters, an enumerable set or off-chain indexing might be better.

**On-chain layer manifests.** Currently, manifests live on IPFS and the renderer fetches them via HTTP. A `LayerRegistry` contract could store manifests on-chain, making the system fully decentralized. The trade-off is gas cost for storage vs. IPFS dependency.

**Upgradeable SlotRegistry.** The CharacterTBA's initialization lock is great for security but means the SlotRegistry can never be replaced. A proxy pattern with a timelock would give the option to upgrade while preserving trust.

---

## Key Takeaways

1. **Separate concerns ruthlessly.** Every contract should have one job. Cross-contract interaction is better than monolithic complexity.

2. **Use standards as building blocks.** ERC-6551 (TBAs) + ERC-1155 (multi-token) + ERC-4906 (metadata updates) compose into something more powerful than any custom solution.

3. **Encode meaning into IDs.** Deterministic token IDs that encode type and rarity eliminate lookup tables and external calls.

4. **Design off-chain systems with the same rigor as on-chain.** The layer manifest pattern and dual-image system required as much architectural thought as the smart contracts.

5. **Make invariants explicit and enforced.** Supply caps, type restrictions, initialization locks — these aren't nice-to-haves, they're the load-bearing walls of the system.

---

*The full source code is available on [GitHub](https://github.com/your-username/Nestable-Character-NFT). Built with Foundry, 63 tests passing across unit and integration suites.*

*If you're building composable NFT systems and want to discuss architecture, find me on [Twitter/X](https://twitter.com/your-handle).*
