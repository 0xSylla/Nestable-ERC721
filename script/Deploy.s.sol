// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {GearNFT} from "../src/GearNFT.sol";
import {NestableCharacterNFT} from "../src/CharacterNFT.sol";
import {CharacterTBA} from "../src/CharacterTBA.sol";
import {SlotRegistry} from "../src/SlotRegistry.sol";
import {MintStageRegistry} from "../src/Registry/MintStageRegistry.sol";
import {BaseNFTParams} from "../src/Base/BaseNFTNativePaymentToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @notice Unified deployment script for the Nestable Character NFT system.
 *         Uses HelperConfig for chain-specific parameters.
 *         On Anvil: auto-deploys MockERC6551Registry.
 *         On live networks: uses the canonical ERC-6551 registry.
 *
 *   anvil && forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 *   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY
 */
contract Deploy is Script {
    function run()
        external
        returns (GearNFT, NestableCharacterNFT, MintStageRegistry, CharacterTBA, SlotRegistry, HelperConfig)
    {
        return deployContracts();
    }

    function deployContracts()
        public
        returns (GearNFT, NestableCharacterNFT, MintStageRegistry, CharacterTBA, SlotRegistry, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:          ", deployer);
        console.log("ERC-6551 Registry: ", config.erc6551Registry);
        console.log("Chain ID:          ", block.chainid);

        vm.startBroadcast(deployerKey);

        // 1. GearNFT
        GearNFT gearNFT = new GearNFT(deployer);
        console.log("GearNFT:           ", address(gearNFT));

        // 2. MintStageRegistry
        MintStageRegistry mintRegistry = new MintStageRegistry(deployer);
        console.log("MintStageRegistry: ", address(mintRegistry));

        // 3. CharacterNFT
        NestableCharacterNFT characterNFT = new NestableCharacterNFT(
            BaseNFTParams.InitParams({
                collectionName: config.charName,
                collectionSymbol: config.charSymbol,
                collectionOwner: deployer,
                collectionMaxSupply: config.charMaxSupply,
                baseURI: config.baseURI,
                royaltyReceiver: deployer,
                royaltyFeeBps: config.royaltyBps,
                mintStageRegistry: address(mintRegistry)
            })
        );
        console.log("CharacterNFT:      ", address(characterNFT));

        // 4. Bind registry
        mintRegistry.bindCollection(address(characterNFT));
        console.log("MintStageRegistry bound to CharacterNFT");

        // 5. CharacterTBA implementation
        CharacterTBA characterTBA = new CharacterTBA(address(gearNFT));
        console.log("CharacterTBA impl: ", address(characterTBA));

        // 6. SlotRegistry
        SlotRegistry slotRegistry = new SlotRegistry(
            deployer, config.erc6551Registry, address(characterTBA), address(characterNFT), address(gearNFT)
        );
        console.log("SlotRegistry:      ", address(slotRegistry));

        // 7. Wire CharacterTBA -> SlotRegistry (one-time, irreversible)
        characterTBA.initialize(address(slotRegistry));
        console.log("CharacterTBA initialized with SlotRegistry");

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("GearNFT:           ", address(gearNFT));
        console.log("MintStageRegistry: ", address(mintRegistry));
        console.log("CharacterNFT:      ", address(characterNFT));
        console.log("CharacterTBA impl: ", address(characterTBA));
        console.log("SlotRegistry:      ", address(slotRegistry));

        return (gearNFT, characterNFT, mintRegistry, characterTBA, slotRegistry, helperConfig);
    }
}
