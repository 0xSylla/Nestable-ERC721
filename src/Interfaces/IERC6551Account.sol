// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Core ERC-6551 token bound account interface (EIP-6551)
interface IERC6551Account {
    receive() external payable;

    /// @notice Returns the token that owns this account
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);

    /// @notice Returns a value that MUST change every time the account executes a transaction
    function state() external view returns (uint256);

    /// @notice Returns the ERC-6551 magic value if `signer` is authorized to act on behalf of this account
    function isValidSigner(address signer, bytes calldata context) external view returns (bytes4 magicValue);
}

/// @notice ERC-6551 execution interface
interface IERC6551Executable {
    /// @param operation 0 = CALL, 1 = DELEGATECALL, 2 = CREATE, 3 = CREATE2
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        payable
        returns (bytes memory result);
}
