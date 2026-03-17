// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {GearNFT} from "../../src/GearNFT.sol";
import {NestableCharacterNFT} from "../../src/CharacterNFT.sol";
import {CharacterTBA} from "../../src/CharacterTBA.sol";
import {SlotRegistry} from "../../src/SlotRegistry.sol";
import {MintStageRegistry} from "../../src/Registry/MintStageRegistry.sol";
import {BaseNFTParams} from "../../src/Base/BaseNFTNativePaymentToken.sol";

import {MockERC6551Registry} from "../mocks/MockERC6551Registry.sol";
import {MockTBA} from "../mocks/MockTBA.sol";

contract SlotRegistryTest is Test {
    // ─── Contracts ────────────────────────────────────────────────────────────

    GearNFT internal gearNFT;
    NestableCharacterNFT internal characterNFT;
    CharacterTBA internal charTBAImpl;
    MockERC6551Registry internal mockRegistry;
    SlotRegistry internal slotRegistry;
    MintStageRegistry internal mintRegistry;

    // ─── Actors ───────────────────────────────────────────────────────────────

    address internal owner = makeAddr("owner");
    address internal player1 = makeAddr("player1");
    address internal player2 = makeAddr("player2");
    address internal other = makeAddr("other");

    // ─── Slot keys ────────────────────────────────────────────────────────────

    bytes32 constant MOON_SLOT = keccak256("MOON");
    bytes32 constant PASSENGER_SLOT = keccak256("PASSENGER");

    // ─── Gear token IDs: (rarity+1)*1000 + (gearType+1) ────────────────────
    // GearType: MOON=0, PASSENGER=1

    uint256 constant COMMON_MOON = 1001;
    uint256 constant COMMON_PASSENGER = 1002;
    uint256 constant RARE_MOON = 3001;

    // ─── Character token IDs ──────────────────────────────────────────────────

    uint256 constant CHAR_1 = 0;
    uint256 constant CHAR_2 = 1;

    // ─── setUp ────────────────────────────────────────────────────────────────

    function setUp() public {
        gearNFT = new GearNFT(owner);
        mintRegistry = new MintStageRegistry(owner);

        characterNFT = new NestableCharacterNFT(
            BaseNFTParams.InitParams({
                collectionName: "Test Character",
                collectionSymbol: "CHAR",
                collectionOwner: owner,
                collectionMaxSupply: 10_000,
                baseURI: "https://api.test.com/character/",
                royaltyReceiver: owner,
                royaltyFeeBps: 500,
                mintStageRegistry: address(mintRegistry)
            })
        );

        mockRegistry = new MockERC6551Registry();
        charTBAImpl = new CharacterTBA(address(gearNFT));

        // SlotRegistry constructor seeds MOON (gearTypeIndex=0) and PASSENGER (gearTypeIndex=1)
        slotRegistry = new SlotRegistry(
            owner, address(mockRegistry), address(charTBAImpl), address(characterNFT), address(gearNFT)
        );

        charTBAImpl.initialize(address(slotRegistry));

        // Mint characters
        address[] memory p1 = new address[](1);
        p1[0] = player1;
        address[] memory p2 = new address[](1);
        p2[0] = player2;

        vm.startPrank(owner);
        characterNFT.batchAirdrop(p1, 1); // player1 owns CHAR_1
        characterNFT.batchAirdrop(p2, 1); // player2 owns CHAR_2
        vm.stopPrank();

        // Define gear
        vm.startPrank(owner);
        gearNFT.defineGear(
            "Common Moon", GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, 50, "ipfs://c/moon", "ipfs://bw/moon", 10, 5
        );
        gearNFT.defineGear(
            "Common Passenger",
            GearNFT.GearType.PASSENGER,
            GearNFT.Rarity.COMMON,
            50,
            "ipfs://c/pass",
            "ipfs://bw/pass",
            5,
            10
        );
        gearNFT.defineGear(
            "Rare Moon", GearNFT.GearType.MOON, GearNFT.Rarity.RARE, 10, "ipfs://c/rmoon", "ipfs://bw/rmoon", 40, 0
        );
        vm.stopPrank();

        // Mint gear to players
        vm.startPrank(owner);
        gearNFT.mint(player1, COMMON_MOON, 2);
        gearNFT.mint(player1, COMMON_PASSENGER, 2);
        gearNFT.mint(player2, COMMON_MOON, 1);
        gearNFT.mint(player2, RARE_MOON, 1);
        vm.stopPrank();

        // Approve SlotRegistry
        vm.prank(player1);
        gearNFT.setApprovalForAll(address(slotRegistry), true);
        vm.prank(player2);
        gearNFT.setApprovalForAll(address(slotRegistry), true);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    function _equip(address player, uint256 charId, bytes32 slot, uint256 gearId) internal {
        vm.prank(player);
        slotRegistry.equipToSlot(charId, slot, gearId);
    }

    function _unequip(address player, uint256 charId, bytes32 slot) internal {
        vm.prank(player);
        slotRegistry.unequipSlot(charId, slot);
    }

    function _getTBA(uint256 charId) internal view returns (address) {
        return slotRegistry.getTBA(charId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getTBA
    // ═══════════════════════════════════════════════════════════════════════════

    function test_getTBA_returnsZeroBeforeFirstEquip() public view {
        assertEq(_getTBA(CHAR_1), address(0));
    }

    function test_getTBA_returnsAddressAfterEquip() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        assertTrue(_getTBA(CHAR_1) != address(0));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getSlotConfig
    // ═══════════════════════════════════════════════════════════════════════════

    function test_getSlotConfig_defaultSlotsAreTyped() public view {
        (bool exists, bool typed, uint8 gearTypeIndex) = slotRegistry.getSlotConfig(MOON_SLOT);
        assertTrue(exists);
        assertTrue(typed);
        assertEq(gearTypeIndex, 0); // MOON

        (exists, typed, gearTypeIndex) = slotRegistry.getSlotConfig(PASSENGER_SLOT);
        assertTrue(exists);
        assertTrue(typed);
        assertEq(gearTypeIndex, 1); // PASSENGER
    }

    function test_getSlotConfig_nonexistentSlotReturnsFalse() public view {
        (bool exists,,) = slotRegistry.getSlotConfig(keccak256("RING"));
        assertFalse(exists);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // equipToSlot — happy path
    // ═══════════════════════════════════════════════════════════════════════════

    function test_equip_transfersGearToTBA() public {
        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 2);
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);

        address tba = _getTBA(CHAR_1);
        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 1);
        assertEq(gearNFT.balanceOf(tba, COMMON_MOON), 1);
    }

    function test_equip_updatesSlotState() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.getSlot(CHAR_1, MOON_SLOT), COMMON_MOON);
    }

    function test_equip_deploysNewTBA() public {
        assertEq(_getTBA(CHAR_1), address(0));
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        assertTrue(_getTBA(CHAR_1) != address(0));
    }

    function test_equip_reusesExistingTBA() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        address tba1 = _getTBA(CHAR_1);

        _equip(player1, CHAR_1, PASSENGER_SLOT, COMMON_PASSENGER);
        address tba2 = _getTBA(CHAR_1);

        assertEq(tba1, tba2);
    }

    function test_equip_incrementsGearEquippedCount() public {
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 0);

        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 1);

        _equip(player2, CHAR_2, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 2);
    }

    function test_equip_addsOccupant() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        uint256[] memory occ = slotRegistry.getSlotOccupants(MOON_SLOT);
        assertEq(occ.length, 1);
        assertEq(occ[0], CHAR_1);
    }

    function test_equip_emitsEvents() public {
        vm.expectEmit(true, true, true, true);
        emit SlotRegistry.SlotEquipped(CHAR_1, MOON_SLOT, COMMON_MOON);

        vm.expectEmit(true, false, false, false);
        emit SlotRegistry.MetadataUpdate(CHAR_1);

        vm.expectEmit(true, false, false, false);
        emit SlotRegistry.GearMetadataUpdate(COMMON_MOON);

        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
    }

    function test_equip_bothSlotsOnSameCharacter() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player1, CHAR_1, PASSENGER_SLOT, COMMON_PASSENGER);

        assertEq(slotRegistry.getSlot(CHAR_1, MOON_SLOT), COMMON_MOON);
        assertEq(slotRegistry.getSlot(CHAR_1, PASSENGER_SLOT), COMMON_PASSENGER);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // equipToSlot — reverts
    // ═══════════════════════════════════════════════════════════════════════════

    function test_equip_reverts_notCharacterOwner() public {
        vm.prank(other);
        vm.expectRevert("Not character owner");
        slotRegistry.equipToSlot(CHAR_1, MOON_SLOT, COMMON_MOON);
    }

    function test_equip_reverts_invalidSlot() public {
        vm.prank(player1);
        vm.expectRevert("Slot invalid");
        slotRegistry.equipToSlot(CHAR_1, keccak256("RING"), COMMON_MOON);
    }

    function test_equip_reverts_slotOccupied() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        vm.prank(player1);
        vm.expectRevert("Slot occupied");
        slotRegistry.equipToSlot(CHAR_1, MOON_SLOT, COMMON_MOON);
    }

    function test_equip_reverts_wrongGearType_passengerInMoonSlot() public {
        vm.prank(player1);
        vm.expectRevert("Wrong gear type for slot");
        slotRegistry.equipToSlot(CHAR_1, MOON_SLOT, COMMON_PASSENGER);
    }

    function test_equip_reverts_wrongGearType_moonInPassengerSlot() public {
        vm.prank(player1);
        vm.expectRevert("Wrong gear type for slot");
        slotRegistry.equipToSlot(CHAR_1, PASSENGER_SLOT, COMMON_MOON);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // unequipSlot — happy path
    // ═══════════════════════════════════════════════════════════════════════════

    function test_unequip_returnsGearToOwner() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        address tba = _getTBA(CHAR_1);

        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 1);
        assertEq(gearNFT.balanceOf(tba, COMMON_MOON), 1);

        _unequip(player1, CHAR_1, MOON_SLOT);

        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 2);
        assertEq(gearNFT.balanceOf(tba, COMMON_MOON), 0);
    }

    function test_unequip_clearsSlotState() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _unequip(player1, CHAR_1, MOON_SLOT);
        assertEq(slotRegistry.getSlot(CHAR_1, MOON_SLOT), 0);
    }

    function test_unequip_decrementsGearEquippedCount() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player2, CHAR_2, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 2);

        _unequip(player1, CHAR_1, MOON_SLOT);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 1);

        _unequip(player2, CHAR_2, MOON_SLOT);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 0);
    }

    function test_unequip_removesOccupant() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player2, CHAR_2, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.getSlotOccupants(MOON_SLOT).length, 2);

        _unequip(player1, CHAR_1, MOON_SLOT);
        uint256[] memory occ = slotRegistry.getSlotOccupants(MOON_SLOT);
        assertEq(occ.length, 1);
        assertEq(occ[0], CHAR_2);
    }

    function test_unequip_emitsEvents() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);

        vm.expectEmit(true, true, false, true);
        emit SlotRegistry.SlotUnequipped(CHAR_1, MOON_SLOT, COMMON_MOON);

        vm.expectEmit(true, false, false, false);
        emit SlotRegistry.MetadataUpdate(CHAR_1);

        vm.expectEmit(true, false, false, false);
        emit SlotRegistry.GearMetadataUpdate(COMMON_MOON);

        _unequip(player1, CHAR_1, MOON_SLOT);
    }

    function test_unequip_allowsReequip() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _unequip(player1, CHAR_1, MOON_SLOT);

        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.getSlot(CHAR_1, MOON_SLOT), COMMON_MOON);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // unequipSlot — reverts
    // ═══════════════════════════════════════════════════════════════════════════

    function test_unequip_reverts_notCharacterOwner() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        vm.prank(other);
        vm.expectRevert("Not character owner");
        slotRegistry.unequipSlot(CHAR_1, MOON_SLOT);
    }

    function test_unequip_reverts_emptySlot() public {
        vm.prank(player1);
        vm.expectRevert("Empty slot");
        slotRegistry.unequipSlot(CHAR_1, MOON_SLOT);
    }

    function test_unequip_reverts_invalidSlot() public {
        vm.prank(player1);
        vm.expectRevert("Slot invalid");
        slotRegistry.unequipSlot(CHAR_1, keccak256("RING"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // addSlot
    // ═══════════════════════════════════════════════════════════════════════════

    function test_addSlot_typed() public {
        bytes32 ring = keccak256("RING");
        vm.prank(owner);
        slotRegistry.addSlot(ring, true, 0); // typed to MOON index

        (bool exists, bool typed, uint8 idx) = slotRegistry.getSlotConfig(ring);
        assertTrue(exists);
        assertTrue(typed);
        assertEq(idx, 0);
    }

    function test_addSlot_untyped_acceptsAnyGear() public {
        bytes32 misc = keccak256("MISC");
        vm.prank(owner);
        slotRegistry.addSlot(misc, false, 0);

        vm.prank(owner);
        gearNFT.mint(player1, RARE_MOON, 1);

        vm.prank(player1);
        slotRegistry.equipToSlot(CHAR_1, misc, RARE_MOON);
        assertEq(slotRegistry.getSlot(CHAR_1, misc), RARE_MOON);
    }

    function test_addSlot_emitsEvent() public {
        bytes32 ring = keccak256("RING");
        vm.expectEmit(true, false, false, false);
        emit SlotRegistry.SlotCreated(ring);
        vm.prank(owner);
        slotRegistry.addSlot(ring, false, 0);
    }

    function test_addSlot_reverts_duplicate() public {
        vm.prank(owner);
        vm.expectRevert("Slot exists");
        slotRegistry.addSlot(MOON_SLOT, true, 0);
    }

    function test_addSlot_reverts_notOwner() public {
        vm.prank(other);
        vm.expectRevert();
        slotRegistry.addSlot(keccak256("RING"), false, 0);
    }

    function test_addSlot_reverts_maxSlotsReached() public {
        // 2 slots already exist (MOON, PASSENGER), MAX_SLOTS = 10
        vm.startPrank(owner);
        for (uint256 i = 3; i <= 10; i++) {
            slotRegistry.addSlot(bytes32(i), false, 0);
        }
        vm.expectRevert("Too many slots");
        slotRegistry.addSlot(bytes32(uint256(11)), false, 0);
        vm.stopPrank();
    }

    function test_addSlot_incrementsSlotCount() public {
        assertEq(slotRegistry.slotCount(), 2);
        vm.prank(owner);
        slotRegistry.addSlot(keccak256("RING"), false, 0);
        assertEq(slotRegistry.slotCount(), 3);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // removeSlot
    // ═══════════════════════════════════════════════════════════════════════════

    function test_removeSlot_emptySlot() public {
        vm.expectEmit(true, false, false, false);
        emit SlotRegistry.SlotRemoved(MOON_SLOT);
        vm.prank(owner);
        slotRegistry.removeSlot(MOON_SLOT);

        (bool exists,,) = slotRegistry.getSlotConfig(MOON_SLOT);
        assertFalse(exists);
    }

    function test_removeSlot_forceUnequipsSingleCharacter() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 1);

        vm.prank(owner);
        slotRegistry.removeSlot(MOON_SLOT);

        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 2);
        (bool exists,,) = slotRegistry.getSlotConfig(MOON_SLOT);
        assertFalse(exists);
    }

    function test_removeSlot_forceUnequipsMultipleCharacters() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player2, CHAR_2, MOON_SLOT, COMMON_MOON);

        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 2);
        assertEq(slotRegistry.getSlotOccupants(MOON_SLOT).length, 2);

        vm.prank(owner);
        slotRegistry.removeSlot(MOON_SLOT);

        assertEq(gearNFT.balanceOf(player1, COMMON_MOON), 2);
        assertEq(gearNFT.balanceOf(player2, COMMON_MOON), 1);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 0);
        (bool exists,,) = slotRegistry.getSlotConfig(MOON_SLOT);
        assertFalse(exists);
    }

    function test_removeSlot_decrementsSlotCount() public {
        assertEq(slotRegistry.slotCount(), 2);
        vm.prank(owner);
        slotRegistry.removeSlot(MOON_SLOT);
        assertEq(slotRegistry.slotCount(), 1);
    }

    function test_removeSlot_reverts_notOwner() public {
        vm.prank(other);
        vm.expectRevert();
        slotRegistry.removeSlot(MOON_SLOT);
    }

    function test_removeSlot_reverts_slotNotFound() public {
        vm.prank(owner);
        vm.expectRevert("Slot not found");
        slotRegistry.removeSlot(keccak256("NONEXISTENT"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // gearEquippedCount — cross-scenario
    // ═══════════════════════════════════════════════════════════════════════════

    function test_gearEquippedCount_multipleGearTypes() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player1, CHAR_1, PASSENGER_SLOT, COMMON_PASSENGER);

        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 1);
        assertEq(slotRegistry.gearEquippedCount(COMMON_PASSENGER), 1);

        _unequip(player1, CHAR_1, PASSENGER_SLOT);

        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 1);
        assertEq(slotRegistry.gearEquippedCount(COMMON_PASSENGER), 0);
    }

    function test_gearEquippedCount_sameGearOnDifferentCharacters() public {
        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player2, CHAR_2, MOON_SLOT, COMMON_MOON);
        assertEq(slotRegistry.gearEquippedCount(COMMON_MOON), 2);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getSlotOccupants — swap-and-pop integrity
    // ═══════════════════════════════════════════════════════════════════════════

    function test_occupants_swapAndPop_removesMiddle() public {
        address[] memory p3 = new address[](1);
        p3[0] = other;
        vm.prank(owner);
        characterNFT.batchAirdrop(p3, 1); // CHAR_3 = tokenId 3

        vm.prank(owner);
        gearNFT.mint(other, COMMON_MOON, 1);
        vm.prank(other);
        gearNFT.setApprovalForAll(address(slotRegistry), true);

        _equip(player1, CHAR_1, MOON_SLOT, COMMON_MOON);
        _equip(player2, CHAR_2, MOON_SLOT, COMMON_MOON);
        _equip(other, 2, MOON_SLOT, COMMON_MOON);

        assertEq(slotRegistry.getSlotOccupants(MOON_SLOT).length, 3);

        _unequip(player2, CHAR_2, MOON_SLOT);

        uint256[] memory occ = slotRegistry.getSlotOccupants(MOON_SLOT);
        assertEq(occ.length, 2);

        bool hasChar1 = (occ[0] == CHAR_1 || occ[1] == CHAR_1);
        bool hasChar3 = (occ[0] == 2 || occ[1] == 2);
        assertTrue(hasChar1, "CHAR_1 missing after swap-and-pop");
        assertTrue(hasChar3, "CHAR_3 missing after swap-and-pop");
    }
}
