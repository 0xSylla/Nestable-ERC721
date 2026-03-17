// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./Interfaces/IERC6551Account.sol";

/**
 * @title CharacterTBA
 * @notice Restricted ERC-6551 Token Bound Account for character NFTs.
 *
 * Each character token gets one TBA deployed by the canonical ERC-6551 registry.
 * The TBA holds all gear (ERC1155) for that character.
 *
 * Restriction: ERC1155 gear transfers in/out are EXCLUSIVELY controlled by the
 * SlotRegistry. The character owner retains full control over everything else
 * (ETH, other NFTs, arbitrary contract calls).
 *
 * This is a shared implementation contract. Each character's TBA is a minimal
 * proxy (EIP-1167) pointing here; the token data (chainId, tokenContract, tokenId)
 * is embedded in the proxy bytecode and read via `token()`.
 */
contract CharacterTBA is IERC6551Account, IERC6551Executable, IERC1155Receiver {
    // ─── Immutables ───────────────────────────────────────────────────────────

    /// @notice The GearNFT contract — the only ERC1155 this TBA accepts
    address public immutable gearContract;

    // ─── State ───────────────────────────────────────────────────────────────

    /// @notice The SlotRegistry — set once via initialize(), locked forever after
    address public slotRegistry;

    bool private _initialized;

    /// @notice Increments on every executed transaction (required by ERC-6551)
    uint256 internal _state;

    // ─── Constructor ─────────────────────────────────────────────────────────

    /// @param gearContract_ The GearNFT address. SlotRegistry is set later via initialize().
    constructor(address gearContract_) {
        gearContract = gearContract_;
    }

    /**
     * @notice Set the SlotRegistry address. Can only be called once.
     * @dev Call this immediately after deploying SlotRegistry.
     *      Deployment order:
     *        1. Deploy CharacterTBA(gearContract)
     *        2. Deploy SlotRegistry(..., tbaImpl = address(CharacterTBA), ...)
     *        3. CharacterTBA.initialize(slotRegistryAddress)
     */
    function initialize(address slotRegistry_) external {
        require(!_initialized, "Already initialized");
        require(slotRegistry_ != address(0), "Invalid address");
        slotRegistry = slotRegistry_;
        _initialized = true;
    }

    receive() external payable override {}

    // ─── ERC-6551 ─────────────────────────────────────────────────────────────

    /**
     * @notice Returns the token that owns this TBA.
     * @dev Reads token data from the EIP-1167 proxy bytecode at offset 0x4d.
     *      This is the canonical ERC-6551 method — no storage reads required.
     */
    function token() public view override returns (uint256 chainId, address tokenContract, uint256 tokenId) {
        bytes memory footer = new bytes(0x60);
        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }
        return abi.decode(footer, (uint256, address, uint256));
    }

    function state() external view override returns (uint256) {
        return _state;
    }

    function isValidSigner(address signer, bytes calldata) external view override returns (bytes4) {
        if (signer == _owner()) return IERC6551Account.isValidSigner.selector;
        return bytes4(0);
    }

    /**
     * @notice Execute an arbitrary call from this TBA.
     *
     * Authorization rules:
     *   - Calls to `gearContract`: only SlotRegistry may initiate (slot enforcement)
     *   - All other calls: character owner may initiate (standard TBA behavior)
     *
     * @param operation Must be 0 (CALL). DELEGATECALL/CREATE not supported.
     */
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        payable
        override
        returns (bytes memory result)
    {
        require(operation == 0, "Only CALL supported");

        if (to == gearContract) {
            require(msg.sender == slotRegistry, "Use SlotRegistry to manage gear");
        } else {
            require(msg.sender == _owner(), "Not authorized");
        }

        _state++;

        bool success;
        (success, result) = to.call{value: value}(data);
        require(success, "Execution failed");
    }

    // ─── ERC1155Receiver ─────────────────────────────────────────────────────

    /**
     * @notice Accept incoming ERC1155 gear only when sent through the SlotRegistry.
     * @dev `msg.sender` = GearNFT (the contract calling this callback)
     *      `operator`   = SlotRegistry (who called safeTransferFrom on GearNFT)
     */
    function onERC1155Received(address operator, address, uint256, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        require(msg.sender == gearContract, "Unknown token contract");
        require(operator == slotRegistry, "Only registry can deposit gear");
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        require(msg.sender == gearContract, "Unknown token contract");
        require(operator == slotRegistry, "Only registry can deposit gear");
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    // ─── ERC165 ──────────────────────────────────────────────────────────────

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC6551Account).interfaceId || interfaceId == type(IERC6551Executable).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    // ─── Internal ────────────────────────────────────────────────────────────

    function _owner() internal view returns (address) {
        (, address tokenContract, uint256 tokenId) = token();
        return IERC721(tokenContract).ownerOf(tokenId);
    }
}
