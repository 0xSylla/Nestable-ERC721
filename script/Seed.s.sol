// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GearNFT}               from "../src/GearNFT.sol";
import {NestableCharacterNFT}  from "../src/CharacterNFT.sol";

/**
 * @notice Seeds test data after deployment: defines gear, mints copies, airdrops characters.
 *
 * Required env vars:
 *   PRIVATE_KEY     — deployer/owner private key (same as Deploy.s.sol)
 *   GEAR_NFT        — deployed GearNFT address
 *   CHARACTER_NFT   — deployed CharacterNFT address
 *   PLAYER          — address to receive characters + gear (e.g. Anvil account #1)
 *
 * Usage:
 *   export GEAR_NFT=0x... CHARACTER_NFT=0x... PLAYER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
 *   forge script script/Seed.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract Seed is Script {

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address player      = vm.envAddress("PLAYER");

        GearNFT gearNFT               = GearNFT(vm.envAddress("GEAR_NFT"));
        NestableCharacterNFT charNFT  = NestableCharacterNFT(vm.envAddress("CHARACTER_NFT"));

        vm.startBroadcast(deployerKey);

        // ── 1. Airdrop 3 characters to the player ────────────────────────────
        address[] memory recipients = new address[](1);
        recipients[0] = player;
        charNFT.batchAirdrop(recipients, 3);
        console.log("Airdropped 3 characters to", player);

        // ── 2. Define all 20 gear types (4 types x 5 rarities) ───────────────
        _defineAllGear(gearNFT);

        // ── 3. Mint gear copies to the player ────────────────────────────────
        //       3x of each COMMON, 2x UNCOMMON, 1x RARE, 1x EPIC, 1x LEGENDARY
        uint256[5] memory amounts = [uint256(3), 2, 1, 1, 1];

        for (uint8 rarity = 0; rarity < 5; rarity++) {
            for (uint8 gearType = 0; gearType < 4; gearType++) {
                uint256 tokenId = (uint256(rarity) + 1) * 1000 + (uint256(gearType) + 1);
                gearNFT.mint(player, tokenId, amounts[rarity]);
            }
        }
        console.log("Minted gear to player");

        vm.stopBroadcast();

        console.log("\n=== Seed Complete ===");
        console.log("Player:     ", player);
        console.log("Characters: 3 (token IDs 1, 2, 3)");
        console.log("Gear:       all 20 types minted (3x common, 2x uncommon, 1x rare/epic/legendary)");
    }

    function _defineAllGear(GearNFT gearNFT) internal {
        string[4] memory typeNames   = ["Helmet", "Armor", "Boots", "Sword"];
        string[5] memory rarityNames = ["Iron", "Steel", "Mithril", "Dragon", "Legendary"];

        // Base stats per rarity: [attack_base, defense_base]
        uint256[5] memory atkBase = [uint256(5),  10, 20, 35, 50];
        uint256[5] memory defBase = [uint256(10), 15, 25, 40, 60];

        // Multiplier per gear type: HELMET(0,1), ARMOR(0,1.5), BOOTS(0.5,0.5), WEAPON(1.5,0)
        // Using integers x10 to avoid floats:
        uint256[4] memory atkMult = [uint256(0),  0,  5,  15]; // /10
        uint256[4] memory defMult = [uint256(10), 15, 5,  0];  // /10

        for (uint8 rarity = 0; rarity < 5; rarity++) {
            for (uint8 gearType = 0; gearType < 4; gearType++) {
                string memory name = string.concat(rarityNames[rarity], " ", typeNames[gearType]);
                uint256 atk = atkBase[rarity] * atkMult[gearType] / 10;
                uint256 def = defBase[rarity] * defMult[gearType] / 10;
                uint256 supply = 100 / (rarity + 1); // 100, 50, 33, 25, 20

                gearNFT.defineGear(
                    name,
                    GearNFT.GearType(gearType),
                    GearNFT.Rarity(rarity),
                    supply,
                    string.concat("ipfs://placeholder/", name, "-color"),
                    string.concat("ipfs://placeholder/", name, "-bw"),
                    atk,
                    def
                );
            }
        }
        console.log("Defined 20 gear types (4 types x 5 rarities)");
    }
}
