/**
 * Nestable Character NFT — Off-chain Metadata Renderer
 *
 * Serves dynamic metadata for CharacterNFT and GearNFT.
 *
 * CharacterNFT rendering uses a **layer manifest** per token:
 *   {
 *     "layers": [
 *       { "uri": "ipfs://CID/background.png", "z": 0 },
 *       { "uri": "ipfs://CID/body.png",       "z": 10 },
 *       { "slot": "PASSENGER",                 "z": 25 },
 *       { "uri": "ipfs://CID/jacket.png",      "z": 30 },
 *       { "slot": "MOON",                      "z": 45 }
 *     ]
 *   }
 *
 * Static layers have a "uri". Gear slots have a "slot" name.
 * When gear is equipped in a slot, its colorURI is inserted at that z-index.
 * All layers are composited bottom-to-top by z-order.
 *
 * Setup:
 *   npm install express ethers sharp node-fetch dotenv
 *   cp .env.example .env
 *   node renderer/index.js
 */

import "dotenv/config";
import express  from "express";
import { ethers }  from "ethers";
import sharp    from "sharp";
import fetch    from "node-fetch";
import { readFile } from "fs/promises";
import { resolve } from "path";

// ─── Config ──────────────────────────────────────────────────────────────────

const {
    RPC_URL,
    CHARACTER_NFT_ADDRESS,
    GEAR_NFT_ADDRESS,
    SLOT_REGISTRY_ADDRESS,
    PORT = "3000",
    RENDERER_BASE_URL,
    // Base URI for layer manifests: ipfs://CID/ or http://localhost:3000/manifest/
    CHARACTER_MANIFEST_URI,
    // Legacy: flat base image URI (used as fallback if no manifest found)
    CHARACTER_BASE_IMAGE_URI,
} = process.env;

const baseUrl = RENDERER_BASE_URL || `http://localhost:${PORT}`;

if (!RPC_URL || !CHARACTER_NFT_ADDRESS || !GEAR_NFT_ADDRESS || !SLOT_REGISTRY_ADDRESS) {
    console.error("Missing required env vars. Check .env.");
    process.exit(1);
}

const provider = new ethers.JsonRpcProvider(RPC_URL);

// ─── Minimal ABIs ────────────────────────────────────────────────────────────

const slotRegistryABI = [
    "function getSlot(uint256 charId, bytes32 slot) view returns (uint256)",
    "function gearEquippedCount(uint256 gearId) view returns (uint256)",
];

const gearNFTABI = [
    "function getGear(uint256 tokenId) view returns (tuple(string name, uint8 gearType, uint8 rarity, uint256 maxSupply, uint256 minted, string colorURI, string bwURI, uint256 attack, uint256 defense))",
];

const slotRegistry = new ethers.Contract(SLOT_REGISTRY_ADDRESS, slotRegistryABI, provider);
const gearNFT      = new ethers.Contract(GEAR_NFT_ADDRESS,      gearNFTABI,      provider);

// ─── Known slots ─────────────────────────────────────────────────────────────

const SLOT_KEYS = {
    MOON:      ethers.keccak256(ethers.toUtf8Bytes("MOON")),
    PASSENGER: ethers.keccak256(ethers.toUtf8Bytes("PASSENGER")),
};

const RARITY_NAMES = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"];
const GEAR_NAMES   = ["MOON", "PASSENGER"];

// ─── Image helpers ───────────────────────────────────────────────────────────

async function fetchBuffer(uri) {
    const url = uri.startsWith("ipfs://")
        ? uri.replace("ipfs://", "https://ipfs.io/ipfs/")
        : uri;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to fetch: ${url} (${res.status})`);
    return Buffer.from(await res.arrayBuffer());
}

async function fetchJSON(uri) {
    const url = uri.startsWith("ipfs://")
        ? uri.replace("ipfs://", "https://ipfs.io/ipfs/")
        : uri;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Failed to fetch manifest: ${url} (${res.status})`);
    return res.json();
}

/**
 * Fetch the layer manifest for a character.
 * Tries CHARACTER_MANIFEST_URI first, falls back to a single-layer flat image.
 */
async function getManifest(tokenId) {
    if (CHARACTER_MANIFEST_URI) {
        try {
            return await fetchJSON(`${CHARACTER_MANIFEST_URI}${tokenId}.json`);
        } catch (e) {
            console.warn(`Manifest fetch failed for token ${tokenId}, falling back to flat image:`, e.message);
        }
    }

    // Fallback: wrap the flat base image as a single-layer manifest
    if (CHARACTER_BASE_IMAGE_URI) {
        return {
            layers: [
                { uri: `${CHARACTER_BASE_IMAGE_URI}${tokenId}.png`, z: 0 },
                { slot: "MOON", z: 10 },
                { slot: "PASSENGER", z: 20 },
            ],
        };
    }

    throw new Error("No CHARACTER_MANIFEST_URI or CHARACTER_BASE_IMAGE_URI configured");
}

/**
 * Read equipped gear for all known slots.
 * Returns a map: slotName -> { gearId, gear }
 */
async function getEquippedGear(charId) {
    const equipped = {};
    await Promise.all(
        Object.entries(SLOT_KEYS).map(async ([slotName, slotKey]) => {
            const gearId = await slotRegistry.getSlot(charId, slotKey);
            if (gearId > 0n) {
                const gear = await gearNFT.getGear(gearId);
                equipped[slotName] = { gearId, gear };
            }
        })
    );
    return equipped;
}

/**
 * Composite a character from its layer manifest + equipped gear.
 *
 * 1. Resolve each layer: static layers use their URI, slot layers use equipped gear's colorURI
 * 2. Sort by z-index (ascending = bottom to top)
 * 3. Composite onto a transparent canvas
 */
async function compositeFromManifest(manifest, equippedGear) {
    // Build the resolved layer list: { uri, z }
    const resolvedLayers = [];

    for (const layer of manifest.layers) {
        if (layer.uri) {
            // Static layer
            resolvedLayers.push({ uri: layer.uri, z: layer.z });
        } else if (layer.slot) {
            // Gear slot — only add if something is equipped
            const gear = equippedGear[layer.slot];
            if (gear) {
                resolvedLayers.push({ uri: gear.gear.colorURI, z: layer.z });
            }
        }
    }

    if (resolvedLayers.length === 0) {
        throw new Error("No layers to composite");
    }

    // Sort by z-index (lowest = bottom)
    resolvedLayers.sort((a, b) => a.z - b.z);

    // Fetch the bottom layer to get canvas dimensions
    const bottomBuffer = await fetchBuffer(resolvedLayers[0].uri);
    const { width, height } = await sharp(bottomBuffer).metadata();

    if (resolvedLayers.length === 1) {
        return await sharp(bottomBuffer).png().toBuffer();
    }

    // Fetch and resize all overlay layers in parallel
    const overlays = await Promise.all(
        resolvedLayers.slice(1).map(async (layer) => {
            const raw = await fetchBuffer(layer.uri);
            const resized = await sharp(raw)
                .resize(width, height, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } })
                .png()
                .toBuffer();
            return { input: resized, blend: "over" };
        })
    );

    return await sharp(bottomBuffer)
        .resize(width, height) // ensure base is exact size
        .composite(overlays)
        .png()
        .toBuffer();
}

// ─── Routes ──────────────────────────────────────────────────────────────────

const app = express();

/**
 * GET /character/:tokenId
 * Returns ERC721 metadata JSON. Image points to /character/:tokenId/image.
 */
app.get("/character/:tokenId", async (req, res) => {
    try {
        const tokenId = BigInt(req.params.tokenId);
        const equippedGear = await getEquippedGear(tokenId);

        const traits = [
            { trait_type: "Token ID", value: tokenId.toString() },
        ];

        for (const [slotName, { gearId, gear }] of Object.entries(equippedGear)) {
            traits.push({ trait_type: `Equipped ${slotName}`, value: gear.name });
            traits.push({ trait_type: `${slotName} Attack`,   value: Number(gear.attack) });
            traits.push({ trait_type: `${slotName} Defense`,  value: Number(gear.defense) });
        }

        res.setHeader("Cache-Control", "no-store");
        res.json({
            name:        `Character #${tokenId}`,
            description: "A Nestable Character NFT. Equip gear to power up.",
            image:       `${baseUrl}/character/${tokenId}/image`,
            attributes:  traits,
        });
    } catch (err) {
        console.error(`/character/${req.params.tokenId}:`, err);
        res.status(500).json({ error: err.message });
    }
});

/**
 * GET /character/:tokenId/image
 * Returns the composite PNG built from the layer manifest + equipped gear.
 */
app.get("/character/:tokenId/image", async (req, res) => {
    try {
        const tokenId = BigInt(req.params.tokenId);

        const [manifest, equippedGear] = await Promise.all([
            getManifest(tokenId),
            getEquippedGear(tokenId),
        ]);

        const imageBuffer = await compositeFromManifest(manifest, equippedGear);

        res.setHeader("Content-Type", "image/png");
        res.setHeader("Cache-Control", "no-store");
        res.send(imageBuffer);
    } catch (err) {
        console.error(`/character/${req.params.tokenId}/image:`, err);
        res.status(500).json({ error: err.message });
    }
});

/**
 * GET /gear/:tokenId
 * Returns ERC1155 metadata JSON.
 * Image: colorURI when unequipped, bwURI when equipped.
 */
app.get("/gear/:tokenId", async (req, res) => {
    try {
        const tokenId = BigInt(req.params.tokenId);

        const [gear, equippedCount] = await Promise.all([
            gearNFT.getGear(tokenId),
            slotRegistry.gearEquippedCount(tokenId),
        ]);

        if (!gear || gear.maxSupply === 0n) {
            return res.status(404).json({ error: "Gear not defined" });
        }

        const isEquipped = equippedCount > 0n;
        const imageURI = isEquipped ? gear.bwURI : gear.colorURI;
        const imageURL = imageURI.startsWith("ipfs://")
            ? imageURI.replace("ipfs://", "https://ipfs.io/ipfs/")
            : imageURI;

        const rarityIndex  = Number(tokenId / 1000n) - 1;
        const gearIndex    = Number(tokenId % 1000n) - 1;
        const rarityName   = RARITY_NAMES[rarityIndex] ?? "UNKNOWN";
        const gearTypeName = GEAR_NAMES[gearIndex]    ?? "UNKNOWN";

        res.setHeader("Cache-Control", "public, max-age=30");
        res.json({
            name:        gear.name,
            description: `${rarityName} ${gearTypeName}. Attack: ${gear.attack}, Defense: ${gear.defense}.`,
            image:       imageURL,
            attributes: [
                { trait_type: "Type",            value: gearTypeName },
                { trait_type: "Rarity",          value: rarityName },
                { trait_type: "Attack",          value: Number(gear.attack),    display_type: "number" },
                { trait_type: "Defense",         value: Number(gear.defense),   display_type: "number" },
                { trait_type: "Equipped",        value: isEquipped ? "Yes" : "No" },
                { trait_type: "Copies Equipped", value: Number(equippedCount),  display_type: "number" },
            ],
        });
    } catch (err) {
        console.error(`/gear/${req.params.tokenId}:`, err);
        res.status(500).json({ error: err.message });
    }
});

/**
 * GET /manifest/:tokenId
 * Serves local manifest files for development (from renderer/manifests/).
 */
app.get("/manifest/:tokenId", async (req, res) => {
    try {
        const filePath = resolve("manifests", `${req.params.tokenId}.json`);
        const data = await readFile(filePath, "utf-8");
        res.setHeader("Content-Type", "application/json");
        res.send(data);
    } catch (err) {
        res.status(404).json({ error: `Manifest not found for token ${req.params.tokenId}` });
    }
});

// ─── Start ───────────────────────────────────────────────────────────────────

app.listen(Number(PORT), () => {
    console.log(`Renderer listening on http://localhost:${PORT}`);
    console.log(`  /character/:id       → metadata JSON`);
    console.log(`  /character/:id/image → composite PNG`);
    console.log(`  /gear/:id            → gear metadata JSON`);
    console.log(`  /manifest/:id        → local manifest (dev only)`);
    console.log(`  Manifest URI: ${CHARACTER_MANIFEST_URI || "(fallback to flat image)"}`);
});
