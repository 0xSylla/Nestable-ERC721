// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../../src/Interfaces/IERC6551Account.sol";

/**
 * @dev Permissive mock TBA used in tests.
 *      Accepts all ERC1155 deposits and allows any caller to execute().
 *      This lets SlotRegistry tests focus on slot logic rather than TBA access control.
 *      CharacterTBA's own access control is tested separately.
 */
contract MockTBA is IERC6551Executable, IERC1155Receiver, ERC165 {
    receive() external payable {}

    // ─── IERC6551Executable ───────────────────────────────────────────────────

    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 /*operation*/
    )
        external
        payable
        override
        returns (bytes memory result)
    {
        bool success;
        (success, result) = to.call{value: value}(data);
        require(success, "MockTBA: call failed");
    }

    // ─── IERC1155Receiver ─────────────────────────────────────────────────────

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    // ─── ERC165 ───────────────────────────────────────────────────────────────

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(IERC1155Receiver).interfaceId || id == type(IERC6551Executable).interfaceId
            || super.supportsInterface(id);
    }
}
