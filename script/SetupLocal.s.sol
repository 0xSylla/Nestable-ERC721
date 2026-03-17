// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GearNFT} from "../src/GearNFT.sol";
import {MintStageRegistry} from "../src/Registry/MintStageRegistry.sol";

/**
 * @notice Post-deploy setup for local Anvil testing.
 *         Defines gear, creates a free public mint stage, and mints characters + gear.
 *
 *   forge script script/SetupLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 *
 * Requires env vars: PRIVATE_KEY, CHARACTER_NFT, GEAR_NFT, MINT_REGISTRY
 */
contract SetupLocal is Script {
    // ─── IPFS CIDs ──────────────────────────────────────────────────────────────
    // Passenger gear (gearType=1): color + bw in same folder
    string constant PASSENGER_BASE = "ipfs://bafybeicu4j3nk7kluze5ug4rucnrk663x7ipumk6f4hm5oa4zpii4tnzum/";
    // Planet/Moon gear (gearType=0): color + bw in same folder
    string constant PLANET_BASE = "ipfs://bafybeiehx2hlwzwpozl7nahnojxq6s6xtd3uo25mno2bbygw3tj2mhqbja/";

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address characterNFTAddr = vm.envAddress("CHARACTER_NFT");
        address gearNFTAddr = vm.envAddress("GEAR_NFT");
        address mintRegistryAddr = vm.envAddress("MINT_REGISTRY");

        GearNFT gearNFT = GearNFT(gearNFTAddr);
        MintStageRegistry registry = MintStageRegistry(mintRegistryAddr);

        vm.startBroadcast(deployerKey);

        // ─── 1. Define Gear ─────────────────────────────────────────────────────
        // GearType: MOON=0, PASSENGER=1
        // Rarity:   COMMON=0, UNCOMMON=1, RARE=2, EPIC=3, LEGENDARY=4
        // tokenId = (rarity+1)*1000 + (gearType+1)

        // Planet images: 0.png..3.png → 4 rarities of MOON (COMMON..EPIC)
        // Planet B&W:    0_bw.png..3_bw.png
        _defineGear(
            gearNFT,
            "Common Moon",
            GearNFT.GearType.MOON,
            GearNFT.Rarity.COMMON,
            100,
            string.concat(PLANET_BASE, "0.png"),
            string.concat(PLANET_BASE, "0_bw.png"),
            10,
            5
        );
        _defineGear(
            gearNFT,
            "Uncommon Moon",
            GearNFT.GearType.MOON,
            GearNFT.Rarity.UNCOMMON,
            50,
            string.concat(PLANET_BASE, "1.png"),
            string.concat(PLANET_BASE, "1_bw.png"),
            20,
            10
        );
        _defineGear(
            gearNFT,
            "Rare Moon",
            GearNFT.GearType.MOON,
            GearNFT.Rarity.RARE,
            25,
            string.concat(PLANET_BASE, "2.png"),
            string.concat(PLANET_BASE, "2_bw.png"),
            35,
            20
        );
        _defineGear(
            gearNFT,
            "Epic Moon",
            GearNFT.GearType.MOON,
            GearNFT.Rarity.EPIC,
            10,
            string.concat(PLANET_BASE, "3.png"),
            string.concat(PLANET_BASE, "3_bw.png"),
            50,
            30
        );

        // Passenger images: 0.png..4.png → 5 rarities of PASSENGER (COMMON..LEGENDARY)
        // Passenger B&W:    0_bw.png..4_bw.png
        _defineGear(
            gearNFT,
            "Common Passenger",
            GearNFT.GearType.PASSENGER,
            GearNFT.Rarity.COMMON,
            100,
            string.concat(PASSENGER_BASE, "0.png"),
            string.concat(PASSENGER_BASE, "0_bw.png"),
            5,
            10
        );
        _defineGear(
            gearNFT,
            "Uncommon Passenger",
            GearNFT.GearType.PASSENGER,
            GearNFT.Rarity.UNCOMMON,
            50,
            string.concat(PASSENGER_BASE, "1.png"),
            string.concat(PASSENGER_BASE, "1_bw.png"),
            10,
            20
        );
        _defineGear(
            gearNFT,
            "Rare Passenger",
            GearNFT.GearType.PASSENGER,
            GearNFT.Rarity.RARE,
            25,
            string.concat(PASSENGER_BASE, "2.png"),
            string.concat(PASSENGER_BASE, "2_bw.png"),
            20,
            35
        );
        _defineGear(
            gearNFT,
            "Epic Passenger",
            GearNFT.GearType.PASSENGER,
            GearNFT.Rarity.EPIC,
            10,
            string.concat(PASSENGER_BASE, "3.png"),
            string.concat(PASSENGER_BASE, "3_bw.png"),
            30,
            50
        );
        _defineGear(
            gearNFT,
            "Legendary Passenger",
            GearNFT.GearType.PASSENGER,
            GearNFT.Rarity.LEGENDARY,
            5,
            string.concat(PASSENGER_BASE, "4.png"),
            string.concat(PASSENGER_BASE, "4_bw.png"),
            50,
            70
        );

        console.log("Defined 9 gear types");

        // ─── 2. Mint gear to deployer for testing ───────────────────────────────
        // Mint 2 copies of each defined gear
        uint256[9] memory gearIds = [
            uint256(1001),
            2001,
            3001,
            4001, // MOON: COMMON..EPIC
            1002,
            2002,
            3002,
            4002,
            5002 // PASSENGER: COMMON..LEGENDARY
        ];
        for (uint256 i = 0; i < gearIds.length; i++) {
            gearNFT.mint(deployer, gearIds[i], 2);
        }
        console.log("Minted 2 copies of each gear to deployer");

        // ─── 3. Create a free public mint stage ─────────────────────────────────
        // name, price, maxSupply, maxPerWallet, requiresAllowlist, startTime, endTime, isActive, isGTD
        registry.addStage(
            "Free Public Mint", // name
            0, // price (free)
            3, // maxSupply (all 3 characters)
            3, // maxPerWallet
            false, // requiresAllowlist
            0, // startTime (immediate)
            0, // endTime (no end)
            true, // isActive
            false // isGTD
        );
        console.log("Created free public mint stage (stageId=0)");

        // ─── 4. Mint some characters ────────────────────────────────────────────
        // batchMint on the CharacterNFT (stageId=0, amount=3)
        (bool ok,) = characterNFTAddr.call(abi.encodeWithSignature("batchMint(uint256,uint256)", 0, 3));
        require(ok, "Character mint failed");
        console.log("Minted 3 characters to deployer");

        vm.stopBroadcast();

        console.log("\n=== Setup Complete ===");
        console.log("Deployer has: 3 characters, 2 copies each of 9 gear types");
        console.log("Public mint stage is active (stageId=0, free, 7 remaining)");
    }

    function _defineGear(
        GearNFT gearNFT,
        string memory name,
        GearNFT.GearType gearType,
        GearNFT.Rarity rarity,
        uint256 maxSupply,
        string memory colorURI,
        string memory bwURI,
        uint256 attack,
        uint256 defense
    ) internal {
        gearNFT.defineGear(name, gearType, rarity, maxSupply, colorURI, bwURI, attack, defense);
    }
}
