// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice ERC-6551 registry interface (EIP-6551)
/// @dev Canonical registry deployed at 0x000000006551c19487814612e58FE06813775758 on most chains
interface IERC6551Registry {
    event ERC6551AccountCreated(
        address account,
        address indexed implementation,
        bytes32 salt,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    /// @notice Deploy a TBA for a token. Returns the existing address if already deployed.
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account);

    /// @notice Compute the deterministic TBA address without deploying.
    function account(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId)
        external
        view
        returns (address account);
}
