// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GearNFT} from "../../src/GearNFT.sol";

contract GearNFTTest is Test {
    GearNFT internal gearNFT;

    address internal owner = makeAddr("owner");
    address internal player = makeAddr("player");
    address internal other = makeAddr("other");

    // Expected deterministic token IDs: (rarity+1)*1000 + (gearType+1)
    // GearType: MOON=0, PASSENGER=1
    uint256 constant ID_COMMON_MOON = 1001;
    uint256 constant ID_COMMON_PASSENGER = 1002;
    uint256 constant ID_UNCOMMON_MOON = 2001;
    uint256 constant ID_RARE_MOON = 3001;
    uint256 constant ID_EPIC_MOON = 4001;
    uint256 constant ID_LEGENDARY_MOON = 5001;
    uint256 constant ID_LEGENDARY_PASSENGER = 5002;

    function setUp() public {
        gearNFT = new GearNFT(owner);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    function _defineMoon(GearNFT.Rarity rarity, uint256 supply, uint256 attack, uint256 defense)
        internal
        returns (uint256 tokenId)
    {
        vm.prank(owner);
        tokenId = gearNFT.defineGear(
            "Test Moon", GearNFT.GearType.MOON, rarity, supply, "ipfs://color/moon", "ipfs://bw/moon", attack, defense
        );
    }

    function _defineCommonMoon() internal returns (uint256) {
        return _defineMoon(GearNFT.Rarity.COMMON, 100, 10, 5);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getTokenId — deterministic ID formula
    // ═══════════════════════════════════════════════════════════════════════════

    function test_getTokenId_allCombinations() public view {
        assertEq(gearNFT.getTokenId(GearNFT.GearType.MOON, GearNFT.Rarity.COMMON), ID_COMMON_MOON);
        assertEq(gearNFT.getTokenId(GearNFT.GearType.PASSENGER, GearNFT.Rarity.COMMON), ID_COMMON_PASSENGER);
        assertEq(gearNFT.getTokenId(GearNFT.GearType.MOON, GearNFT.Rarity.UNCOMMON), ID_UNCOMMON_MOON);
        assertEq(gearNFT.getTokenId(GearNFT.GearType.MOON, GearNFT.Rarity.RARE), ID_RARE_MOON);
        assertEq(gearNFT.getTokenId(GearNFT.GearType.MOON, GearNFT.Rarity.EPIC), ID_EPIC_MOON);
        assertEq(gearNFT.getTokenId(GearNFT.GearType.MOON, GearNFT.Rarity.LEGENDARY), ID_LEGENDARY_MOON);
        assertEq(gearNFT.getTokenId(GearNFT.GearType.PASSENGER, GearNFT.Rarity.LEGENDARY), ID_LEGENDARY_PASSENGER);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // defineGear
    // ═══════════════════════════════════════════════════════════════════════════

    function test_defineGear_returnsCorrectTokenId() public {
        uint256 id = _defineCommonMoon();
        assertEq(id, ID_COMMON_MOON);
    }

    function test_defineGear_storesAllFields() public {
        uint256 id = _defineCommonMoon();
        GearNFT.GearDefinition memory def = gearNFT.getGear(id);

        assertEq(def.name, "Test Moon");
        assertEq(uint8(def.gearType), uint8(GearNFT.GearType.MOON));
        assertEq(uint8(def.rarity), uint8(GearNFT.Rarity.COMMON));
        assertEq(def.maxSupply, 100);
        assertEq(def.minted, 0);
        assertEq(def.attack, 10);
        assertEq(def.defense, 5);
    }

    function test_defineGear_storesURIs() public {
        uint256 id = _defineCommonMoon();
        (string memory colorURI, string memory bwURI) = gearNFT.getURIs(id);
        assertEq(colorURI, "ipfs://color/moon");
        assertEq(bwURI, "ipfs://bw/moon");
    }

    function test_defineGear_emitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit GearNFT.GearDefined(ID_COMMON_MOON, GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, "Test Moon", 100, 10, 5);
        _defineCommonMoon();
    }

    function test_defineGear_allGearTypes() public {
        vm.startPrank(owner);
        gearNFT.defineGear("Moon", GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, 10, "c", "b", 10, 5);
        gearNFT.defineGear("Passenger", GearNFT.GearType.PASSENGER, GearNFT.Rarity.COMMON, 10, "c", "b", 5, 10);
        vm.stopPrank();

        assertEq(gearNFT.getGear(ID_COMMON_MOON).name, "Moon");
        assertEq(gearNFT.getGear(ID_COMMON_PASSENGER).name, "Passenger");
    }

    function test_defineGear_allRarities() public {
        vm.startPrank(owner);
        gearNFT.defineGear("C", GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, 10, "c", "b", 5, 0);
        gearNFT.defineGear("U", GearNFT.GearType.MOON, GearNFT.Rarity.UNCOMMON, 10, "c", "b", 10, 0);
        gearNFT.defineGear("R", GearNFT.GearType.MOON, GearNFT.Rarity.RARE, 10, "c", "b", 15, 0);
        gearNFT.defineGear("E", GearNFT.GearType.MOON, GearNFT.Rarity.EPIC, 10, "c", "b", 20, 0);
        gearNFT.defineGear("L", GearNFT.GearType.MOON, GearNFT.Rarity.LEGENDARY, 10, "c", "b", 30, 0);
        vm.stopPrank();

        assertEq(gearNFT.getGear(ID_COMMON_MOON).attack, 5);
        assertEq(gearNFT.getGear(ID_UNCOMMON_MOON).attack, 10);
        assertEq(gearNFT.getGear(ID_RARE_MOON).attack, 15);
        assertEq(gearNFT.getGear(ID_EPIC_MOON).attack, 20);
        assertEq(gearNFT.getGear(ID_LEGENDARY_MOON).attack, 30);
    }

    function test_defineGear_reverts_duplicate() public {
        _defineCommonMoon();
        vm.prank(owner);
        vm.expectRevert("Already defined");
        gearNFT.defineGear("Copy", GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, 50, "x", "y", 1, 1);
    }

    function test_defineGear_reverts_notOwner() public {
        vm.prank(player);
        vm.expectRevert();
        gearNFT.defineGear("Moon", GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, 100, "x", "y", 10, 5);
    }

    function test_defineGear_reverts_zeroSupply() public {
        vm.prank(owner);
        vm.expectRevert("Supply must be > 0");
        gearNFT.defineGear("Moon", GearNFT.GearType.MOON, GearNFT.Rarity.COMMON, 0, "x", "y", 10, 5);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // mint
    // ═══════════════════════════════════════════════════════════════════════════

    function test_mint_happyPath() public {
        uint256 id = _defineCommonMoon();
        vm.prank(owner);
        gearNFT.mint(player, id, 5);

        assertEq(gearNFT.balanceOf(player, id), 5);
        assertEq(gearNFT.totalMinted(id), 5);
        assertEq(gearNFT.remainingSupply(id), 95);
    }

    function test_mint_emitsEvent() public {
        uint256 id = _defineCommonMoon();
        vm.expectEmit(true, true, false, true);
        emit GearNFT.GearMinted(id, player, 3);
        vm.prank(owner);
        gearNFT.mint(player, id, 3);
    }

    function test_mint_multipleRecipients() public {
        uint256 id = _defineCommonMoon();
        vm.startPrank(owner);
        gearNFT.mint(player, id, 60);
        gearNFT.mint(other, id, 40);
        vm.stopPrank();

        assertEq(gearNFT.balanceOf(player, id), 60);
        assertEq(gearNFT.balanceOf(other, id), 40);
        assertEq(gearNFT.totalMinted(id), 100);
        assertEq(gearNFT.remainingSupply(id), 0);
    }

    function test_mint_reverts_notDefined() public {
        vm.prank(owner);
        vm.expectRevert("Gear not defined");
        gearNFT.mint(player, ID_COMMON_MOON, 1);
    }

    function test_mint_reverts_exceedsMaxSupply() public {
        uint256 id = _defineCommonMoon(); // maxSupply = 100
        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        gearNFT.mint(player, id, 101);
    }

    function test_mint_reverts_exceedsOnSecondMint() public {
        uint256 id = _defineCommonMoon();
        vm.startPrank(owner);
        gearNFT.mint(player, id, 90);
        vm.expectRevert("Exceeds max supply");
        gearNFT.mint(player, id, 11); // 90 + 11 > 100
        vm.stopPrank();
    }

    function test_mint_reverts_notOwner() public {
        uint256 id = _defineCommonMoon();
        vm.prank(player);
        vm.expectRevert();
        gearNFT.mint(player, id, 1);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // uri / view functions
    // ═══════════════════════════════════════════════════════════════════════════

    function test_uri_returnsColorURI() public {
        uint256 id = _defineCommonMoon();
        assertEq(gearNFT.uri(id), "ipfs://color/moon");
    }

    function test_getStats_returnsCorrectValues() public {
        uint256 id = _defineCommonMoon(); // attack=10, defense=5
        (uint256 attack, uint256 defense) = gearNFT.getStats(id);
        assertEq(attack, 10);
        assertEq(defense, 5);
    }

    function test_getGear_undefinedReturnsZero() public view {
        GearNFT.GearDefinition memory def = gearNFT.getGear(ID_COMMON_MOON);
        assertEq(def.maxSupply, 0);
        assertEq(def.attack, 0);
    }

    function test_remainingSupply_decreasesOnMint() public {
        uint256 id = _defineCommonMoon();
        assertEq(gearNFT.remainingSupply(id), 100);
        vm.prank(owner);
        gearNFT.mint(player, id, 30);
        assertEq(gearNFT.remainingSupply(id), 70);
    }
}
