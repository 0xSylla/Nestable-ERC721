// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/Interfaces/IERC6551Registry.sol";
import "./MockTBA.sol";

/**
 * @dev Mock ERC-6551 registry for tests.
 *      Deploys a MockTBA per unique (salt, chainId, tokenContract, tokenId) tuple.
 *      The `implementation` param is accepted but ignored — MockTBA is always used.
 */
contract MockERC6551Registry is IERC6551Registry {
    mapping(bytes32 => address) private _accounts;

    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external override returns (address account) {
        bytes32 key = _key(salt, chainId, tokenContract, tokenId);
        if (_accounts[key] != address(0)) return _accounts[key];

        MockTBA tba = new MockTBA();
        account = address(tba);
        _accounts[key] = account;

        emit ERC6551AccountCreated(account, implementation, salt, chainId, tokenContract, tokenId);
    }

    function account(
        address, /*implementation*/
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    )
        external
        view
        override
        returns (address)
    {
        return _accounts[_key(salt, chainId, tokenContract, tokenId)];
    }

    function _key(bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(salt, chainId, tokenContract, tokenId));
    }
}
