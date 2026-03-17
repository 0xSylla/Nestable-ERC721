// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockERC6551Registry} from "../test/mocks/MockERC6551Registry.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    // Canonical ERC-6551 registry — same address on Ethereum, Base, Optimism, Arbitrum, etc.
    address public constant CANONICAL_ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
}

contract HelperConfig is CodeConstants, Script {

    struct NetworkConfig {
        address erc6551Registry;
        string  charName;
        string  charSymbol;
        uint256 charMaxSupply;
        string  baseURI;
        uint96  royaltyBps;
        address account;
    }

    mapping(uint256 chainId => NetworkConfig) private s_networkConfigs;

    constructor() {
        s_networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
        s_networkConfigs[BASE_CHAIN_ID] = getBaseConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            return s_networkConfigs[chainId];
        }
    }

    function setConfig(uint256 chainId, NetworkConfig memory config) public {
        s_networkConfigs[chainId] = config;
    }

    // ─── Chain Configs ──────────────────────────────────────────────────────

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            erc6551Registry: CANONICAL_ERC6551_REGISTRY,
            charName:        "PAULDIRAC",
            charSymbol:      "DIRAC",
            charMaxSupply:   100,
            baseURI:         "ipfs://YOUR_PRODUCTION_CID/",
            royaltyBps:      500,
            account:         address(0) // set via PRIVATE_KEY env var
        });
    }

    function getBaseConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            erc6551Registry: CANONICAL_ERC6551_REGISTRY,
            charName:        "PAULDIRAC",
            charSymbol:      "DIRAC",
            charMaxSupply:   100,
            baseURI:         "ipfs://YOUR_PRODUCTION_CID/",
            royaltyBps:      500,
            account:         address(0)
        });
    }

    function getOrCreateAnvilConfig() internal returns (NetworkConfig memory) {
        // If already configured, return existing
        if (s_networkConfigs[LOCAL_CHAIN_ID].erc6551Registry != address(0)) {
            return s_networkConfigs[LOCAL_CHAIN_ID];
        }

        // Deploy mock ERC-6551 registry for local testing
        vm.startBroadcast();
        MockERC6551Registry mockRegistry = new MockERC6551Registry();
        vm.stopBroadcast();

        NetworkConfig memory config = NetworkConfig({
            erc6551Registry: address(mockRegistry),
            charName:        "PAULDIRAC",
            charSymbol:      "DIRAC",
            charMaxSupply:   3,
            baseURI:         "ipfs://bafybeiftk2gwspghu6hmq4gfbkbzerbzpt5advld4cyz75ep55fxpeggcu/",
            royaltyBps:      500,
            account:         0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 // Anvil default #0
        });

        s_networkConfigs[LOCAL_CHAIN_ID] = config;
        return config;
    }
}
