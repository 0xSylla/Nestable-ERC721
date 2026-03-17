// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./Interfaces/IERC6551Registry.sol";
import "./Interfaces/IERC6551Account.sol";

/**
 * @title SlotRegistry
 * @notice On-chain slot enforcement layer for the ERC-6551 character system.
 *
 * Replaces ModularSlots. Gear lives in each character's TBA (Token Bound Account),
 * but can only enter/exit through this contract — enforced by CharacterTBA.execute().
 *
 * Deployment order:
 *   1. Deploy GearNFT
 *   2. Deploy CharacterNFT
 *   3. Deploy CharacterTBA(gearContract)          ← no slotRegistry yet
 *   4. Deploy SlotRegistry(..., tbaImpl=CharacterTBA, ...)
 *   5. CharacterTBA.initialize(slotRegistryAddress) ← locked forever after
 *
 * Player flow:
 *   1. Player calls GearNFT.setApprovalForAll(slotRegistryAddress, true)
 *   2. Player calls SlotRegistry.equipToSlot(charId, slot, gearId)
 *   3. Player calls SlotRegistry.unequipSlot(charId, slot)
 */
contract SlotRegistry is Ownable, ReentrancyGuard {
    // ─── Types ────────────────────────────────────────────────────────────────

    struct EquippedItem {
        uint256 tokenId; // gearId currently in this slot (0 = empty)
    }

    struct SlotConfig {
        bool exists;
        /// @dev When true, only gear whose tokenId encodes this gearTypeIndex can be equipped.
        ///      gearTypeIndex is decoded as: (gearId % 1000) - 1
        ///      (HELMET=0, ARMOR=1, BOOTS=2, WEAPON=3 — matches GearNFT.GearType enum)
        bool typed;
        uint8 gearTypeIndex;
    }

    // ─── Immutables ───────────────────────────────────────────────────────────

    IERC6551Registry public immutable erc6551Registry;
    address public immutable tbaImplementation;
    address public immutable characterNFT;
    address public immutable gearContract;

    /// @dev Salt used for all TBA deployments — one TBA per character
    bytes32 public constant TBA_SALT = bytes32(0);

    // ─── Slot State ───────────────────────────────────────────────────────────

    uint256 public constant MAX_SLOTS = 10;
    uint256 public slotCount;

    mapping(bytes32 => SlotConfig) internal _slots;

    /// charId => slot => gearId (0 means empty)
    mapping(uint256 => mapping(bytes32 => uint256)) internal _slotItem;

    // Occupant tracking for removeSlot
    mapping(bytes32 => uint256[]) internal _slotOccupants;
    mapping(bytes32 => mapping(uint256 => uint256)) internal _slotOccupantIndex; // 1-based

    bytes32[] private _slotKeys;

    /// @dev gearId => number of copies currently equipped across all characters + slots
    mapping(uint256 => uint256) public gearEquippedCount;

    // ─── Events ───────────────────────────────────────────────────────────────

    event SlotCreated(bytes32 indexed slot);
    event SlotRemoved(bytes32 indexed slot);
    event SlotEquipped(uint256 indexed charId, bytes32 indexed slot, uint256 indexed gearId);
    event SlotUnequipped(uint256 indexed charId, bytes32 indexed slot, uint256 gearId);
    event TBADeployed(uint256 indexed charId, address tba);

    // ERC-4906 — tells marketplaces (OpenSea etc.) to re-fetch metadata immediately
    event MetadataUpdate(uint256 indexed _tokenId);

    // ERC1155 standard — tells indexers to re-fetch gear metadata
    event GearMetadataUpdate(uint256 indexed gearId);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(
        address owner_,
        address erc6551Registry_,
        address tbaImplementation_,
        address characterNFT_,
        address gearContract_
    ) Ownable(owner_) {
        erc6551Registry = IERC6551Registry(erc6551Registry_);
        tbaImplementation = tbaImplementation_;
        characterNFT = characterNFT_;
        gearContract = gearContract_;

        _addSlot(keccak256("MOON"), true, 0);
        _addSlot(keccak256("PASSENGER"), true, 1);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    /// @notice Returns the deterministic TBA address for a character (may not be deployed yet).
    function getTBA(uint256 charId) public view returns (address) {
        return erc6551Registry.account(tbaImplementation, TBA_SALT, block.chainid, characterNFT, charId);
    }

    /// @notice Returns the gearId equipped in a slot (0 = empty).
    function getSlot(uint256 charId, bytes32 slot) external view returns (uint256 gearId) {
        return _slotItem[charId][slot];
    }

    /// @notice Returns all character IDs that currently have gear in this slot.
    function getSlotOccupants(bytes32 slot) external view returns (uint256[] memory) {
        return _slotOccupants[slot];
    }

    /// @notice Returns the type restriction config for a slot.
    function getSlotConfig(bytes32 slot) external view returns (bool exists, bool typed, uint8 gearTypeIndex) {
        SlotConfig storage cfg = _slots[slot];
        return (cfg.exists, cfg.typed, cfg.gearTypeIndex);
    }

    // ─── User: Equip / Unequip ────────────────────────────────────────────────

    /**
     * @notice Equip a gear item into a character's slot.
     * @dev Caller must have approved this contract on GearNFT first:
     *      GearNFT.setApprovalForAll(slotRegistryAddress, true)
     * @param charId  The character token ID
     * @param slot    Slot identifier, e.g. keccak256("WEAPON")
     * @param gearId  The GearNFT token ID to equip
     */
    function equipToSlot(uint256 charId, bytes32 slot, uint256 gearId) external nonReentrant {
        require(IERC721(characterNFT).ownerOf(charId) == msg.sender, "Not character owner");
        SlotConfig storage cfg = _slots[slot];
        require(cfg.exists, "Slot invalid");
        require(_slotItem[charId][slot] == 0, "Slot occupied");
        if (cfg.typed) {
            require(_decodeGearType(gearId) == cfg.gearTypeIndex, "Wrong gear type for slot");
        }

        // Deploy TBA if not yet created (idempotent — returns existing address if deployed)
        address tba = erc6551Registry.createAccount(tbaImplementation, TBA_SALT, block.chainid, characterNFT, charId);

        // EFFECTS
        _slotItem[charId][slot] = gearId;
        _addSlotOccupant(slot, charId);
        gearEquippedCount[gearId]++;

        // INTERACTION
        // SlotRegistry is the operator → CharacterTBA.onERC1155Received accepts
        IERC1155(gearContract).safeTransferFrom(msg.sender, tba, gearId, 1, "");

        emit SlotEquipped(charId, slot, gearId);
        emit MetadataUpdate(charId); // character image gains this gear layer
        emit GearMetadataUpdate(gearId); // gear image flips color → B&W
    }

    /**
     * @notice Unequip a gear item from a character's slot, returning it to the owner.
     * @param charId  The character token ID
     * @param slot    Slot identifier, e.g. keccak256("WEAPON")
     */
    function unequipSlot(uint256 charId, bytes32 slot) external nonReentrant {
        require(IERC721(characterNFT).ownerOf(charId) == msg.sender, "Not character owner");
        require(_slots[slot].exists, "Slot invalid");

        uint256 gearId = _slotItem[charId][slot];
        require(gearId != 0, "Empty slot");

        address tba = getTBA(charId);

        // EFFECTS
        delete _slotItem[charId][slot];
        _removeSlotOccupant(slot, charId);
        gearEquippedCount[gearId]--;

        // INTERACTION
        // Tell TBA to transfer gear back to owner.
        // CharacterTBA.execute() allows this because msg.sender == slotRegistry.
        bytes memory transferData =
            abi.encodeWithSelector(IERC1155.safeTransferFrom.selector, tba, msg.sender, gearId, 1, "");
        IERC6551Executable(tba).execute(gearContract, 0, transferData, 0);

        emit SlotUnequipped(charId, slot, gearId);
        emit MetadataUpdate(charId); // character image loses this gear layer
        emit GearMetadataUpdate(gearId); // gear image flips B&W → color
    }

    // ─── Owner: Slot Admin ─────────────────────────────────────────────────────

    /**
     * @notice Add a new slot.
     * @param slot           keccak256 identifier, e.g. keccak256("RING")
     * @param typed          If true, only gear matching gearTypeIndex can be equipped here
     * @param gearTypeIndex  0=HELMET 1=ARMOR 2=BOOTS 3=WEAPON (ignored when typed=false)
     */
    function addSlot(bytes32 slot, bool typed, uint8 gearTypeIndex) external onlyOwner {
        _addSlot(slot, typed, gearTypeIndex);
    }

    /**
     * @notice Force-unequip all characters in this slot then remove it.
     *         Gear is returned to each character's current owner automatically.
     */
    function removeSlot(bytes32 slot) external onlyOwner {
        uint256[] memory occupants = _slotOccupants[slot]; // snapshot before mutation

        for (uint256 i; i < occupants.length; i++) {
            uint256 charId = occupants[i];
            uint256 gearId = _slotItem[charId][slot];
            if (gearId == 0) continue;

            address tba = getTBA(charId);
            address charOwner = IERC721(characterNFT).ownerOf(charId);

            // EFFECTS
            delete _slotItem[charId][slot];
            gearEquippedCount[gearId]--;

            // INTERACTION
            bytes memory transferData =
                abi.encodeWithSelector(IERC1155.safeTransferFrom.selector, tba, charOwner, gearId, 1, "");
            IERC6551Executable(tba).execute(gearContract, 0, transferData, 0);

            emit SlotUnequipped(charId, slot, gearId);
            emit MetadataUpdate(charId);
            emit GearMetadataUpdate(gearId);
        }

        // Clear the occupants list for this slot in one go
        delete _slotOccupants[slot];

        _removeSlot(slot);

        for (uint256 i; i < _slotKeys.length; i++) {
            if (_slotKeys[i] == slot) {
                _slotKeys[i] = _slotKeys[_slotKeys.length - 1];
                _slotKeys.pop();
                break;
            }
        }
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _addSlot(bytes32 slot, bool typed, uint8 gearTypeIndex) internal {
        require(!_slots[slot].exists, "Slot exists");
        require(slotCount < MAX_SLOTS, "Too many slots");
        _slots[slot] = SlotConfig({exists: true, typed: typed, gearTypeIndex: gearTypeIndex});
        slotCount++;
        _slotKeys.push(slot);
        emit SlotCreated(slot);
    }

    /// @dev Decodes the gear type index encoded in a GearNFT token ID.
    ///      tokenId = (rarity + 1) * 1000 + (gearType + 1)  →  gearType = (tokenId % 1000) - 1
    function _decodeGearType(uint256 gearId) internal pure returns (uint8) {
        uint256 remainder = gearId % 1000;
        require(remainder >= 1, "Invalid gearId");
        return uint8(remainder - 1);
    }

    function _removeSlot(bytes32 slot) internal {
        require(_slots[slot].exists, "Slot not found");
        delete _slots[slot];
        slotCount--;
        emit SlotRemoved(slot);
    }

    function _addSlotOccupant(bytes32 slot, uint256 charId) internal {
        _slotOccupants[slot].push(charId);
        _slotOccupantIndex[slot][charId] = _slotOccupants[slot].length; // 1-based
    }

    function _removeSlotOccupant(bytes32 slot, uint256 charId) internal {
        uint256 idx = _slotOccupantIndex[slot][charId];
        if (idx == 0) return;

        uint256 arrayIndex = idx - 1;
        uint256[] storage arr = _slotOccupants[slot];
        uint256 last = arr[arr.length - 1];

        arr[arrayIndex] = last;
        _slotOccupantIndex[slot][last] = idx;
        arr.pop();

        delete _slotOccupantIndex[slot][charId];
    }
}
