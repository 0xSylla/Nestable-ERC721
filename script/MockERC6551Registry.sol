// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC6551Registry}  from "../src/Interfaces/IERC6551Registry.sol";

// ─── Minimal ERC-6551 Registry (local testing only) ──────────────────────────
//
// The canonical registry (0x000000006551c19487814612e58FE06813775758) is NOT
// pre-deployed on a blank Anvil instance. Two options:
//
//   A) Fork a live chain:
//      anvil --fork-url $RPC_URL
//      → canonical registry is already there, no mock needed.
//
//   B) Deploy this mock, then pass its address to Deploy.s.sol:
//      forge script script/MockERC6551Registry.sol --rpc-url http://127.0.0.1:8545 --broadcast
//      export ERC6551_REGISTRY=<printed address>
//      forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
//
// DO NOT use in production. This mock skips the CREATE2 prefix check.

contract MockERC6551Registry is IERC6551Registry {

    // salt+chainId+tokenContract+tokenId → deployed account
    mapping(bytes32 => address) private _accounts;

    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external override returns (address account) {
        bytes32 key = _key(implementation, salt, chainId, tokenContract, tokenId);
        if (_accounts[key] != address(0)) return _accounts[key];

        // Deploy a minimal EIP-1167 proxy pointing to `implementation`,
        // with the ERC-6551 footer (chainId, tokenContract, tokenId) appended.
        bytes memory bytecode = _proxyBytecode(implementation, chainId, tokenContract, tokenId);
        assembly {
            account := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(account != address(0), "CREATE2 failed");

        _accounts[key] = account;
        emit ERC6551AccountCreated(account, implementation, salt, chainId, tokenContract, tokenId);
    }

    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view override returns (address) {
        return _accounts[_key(implementation, salt, chainId, tokenContract, tokenId)];
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _key(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(implementation, salt, chainId, tokenContract, tokenId));
    }

    /// @dev Produces the ERC-6551 EIP-1167 proxy bytecode with the standard footer.
    ///      Layout matches the offset CharacterTBA.token() reads at 0x4d.
    function _proxyBytecode(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            hex"3d60ad80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3",
            abi.encode(chainId, tokenContract, tokenId)
        );
    }
}

// ─── Deploy script ────────────────────────────────────────────────────────────

contract DeployMockRegistry is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MockERC6551Registry reg = new MockERC6551Registry();
        console.log("MockERC6551Registry:", address(reg));
        console.log("Export: export ERC6551_REGISTRY=%s", vm.toString(address(reg)));

        vm.stopBroadcast();
    }
}
