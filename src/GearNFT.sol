// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GearNFT
 * @notice Single ERC1155 contract for all equippable gear.
 *
 * Token IDs are deterministic: tokenId = (rarity + 1) * 1000 + (gearType + 1)
 *
 *   COMMON    (1xxx): #1001 HELMET, #1002 ARMOR, #1003 BOOTS, #1004 WEAPON
 *   UNCOMMON  (2xxx): #2001 HELMET, #2002 ARMOR, #2003 BOOTS, #2004 WEAPON
 *   RARE      (3xxx): #3001 HELMET, #3002 ARMOR, #3003 BOOTS, #3004 WEAPON
 *   EPIC      (4xxx): #4001 HELMET, #4002 ARMOR, #4003 BOOTS, #4004 WEAPON
 *   LEGENDARY (5xxx): #5001 HELMET, #5002 ARMOR, #5003 BOOTS, #5004 WEAPON
 *
 * Each token ID has:
 *   - colorURI  : full-colour image (shown when unequipped, used as the ERC1155 `uri()`)
 *   - bwURI     : grayscale image   (shown when equipped — fetched by the metadata renderer)
 *   - attack    : attack stat
 *   - defense   : defense stat
 *
 * The `equipped` status and the decision to serve colorURI vs bwURI are handled
 * by the off-chain metadata renderer, which queries SlotRegistry.gearEquippedCount().
 *
 * Workflow:
 *   1. Owner calls defineGear() to register a gear type + rarity combination.
 *   2. Owner calls mint() to distribute copies to players.
 *   3. Player calls setApprovalForAll(slotRegistryAddress, true) on this contract.
 *   4. Player calls equipToSlot() on SlotRegistry — gear is transferred to the character TBA.
 */
contract GearNFT is ERC1155, Ownable {

    // GearType values map to the ones-digit of the token ID (1-4)
    //enum GearType { HELMET, ARMOR, BOOTS, WEAPON }
    enum GearType { MOON, PASSENGER }
    // Rarity values map to the thousands-digit of the token ID (1-5)
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

    struct GearDefinition {
        string   name;
        GearType gearType;
        Rarity   rarity;
        uint256  maxSupply;
        uint256  minted;
        /// @dev Full-colour image URI (unequipped state, returned by uri())
        string   colorURI;
        /// @dev Grayscale image URI (equipped state, served by the off-chain renderer)
        string   bwURI;
        uint256  attack;
        uint256  defense;
    }

    /// @dev tokenId => definition. maxSupply == 0 means not yet defined.
    mapping(uint256 => GearDefinition) private _gear;

    event GearDefined(
        uint256 indexed tokenId,
        GearType gearType,
        Rarity   rarity,
        string   name,
        uint256  maxSupply,
        uint256  attack,
        uint256  defense
    );
    event GearMinted(uint256 indexed tokenId, address indexed to, uint256 amount);

    constructor(address owner_) ERC1155("") Ownable(owner_) {}

    // ─── Admin ────────────────────────────────────────────────────────────────

    /**
     * @notice Register a gear type + rarity combination.
     *         The token ID is computed deterministically — no duplicate definitions allowed.
     * @param name       Human-readable name, e.g. "Dragon Helmet"
     * @param gearType   The slot category (HELMET / ARMOR / BOOTS / WEAPON)
     * @param rarity     Rarity tier (COMMON → LEGENDARY)
     * @param maxSupply_ Maximum number of copies that can ever be minted
     * @param colorURI_  Metadata URI — full-colour image (unequipped)
     * @param bwURI_     Metadata URI — grayscale image (equipped)
     * @param attack_    Attack stat for this gear
     * @param defense_   Defense stat for this gear
     * @return tokenId   The deterministic token ID for this combination
     */
    function defineGear(
        string   calldata name,
        GearType gearType,
        Rarity   rarity,
        uint256  maxSupply_,
        string   calldata colorURI_,
        string   calldata bwURI_,
        uint256  attack_,
        uint256  defense_
    ) external onlyOwner returns (uint256 tokenId) {
        require(maxSupply_ > 0, "Supply must be > 0");
        tokenId = _computeTokenId(gearType, rarity);
        require(_gear[tokenId].maxSupply == 0, "Already defined");
        _gear[tokenId] = GearDefinition({
            name:      name,
            gearType:  gearType,
            rarity:    rarity,
            maxSupply: maxSupply_,
            minted:    0,
            colorURI:  colorURI_,
            bwURI:     bwURI_,
            attack:    attack_,
            defense:   defense_
        });
        emit GearDefined(tokenId, gearType, rarity, name, maxSupply_, attack_, defense_);
    }

    /**
     * @notice Mint copies of an existing gear type to a recipient.
     */
    function mint(address to, uint256 tokenId, uint256 amount) external onlyOwner {
        GearDefinition storage g = _gear[tokenId];
        require(g.maxSupply > 0, "Gear not defined");
        require(g.minted + amount <= g.maxSupply, "Exceeds max supply");
        g.minted += amount;
        _mint(to, tokenId, amount, "");
        emit GearMinted(tokenId, to, amount);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    /// @notice Standard ERC1155 URI — always returns the full-colour version.
    ///         The off-chain renderer decides whether to serve colorURI or bwURI
    ///         based on SlotRegistry.gearEquippedCount(tokenId).
    function uri(uint256 tokenId) public view override returns (string memory) {
        return _gear[tokenId].colorURI;
    }

    function getGear(uint256 tokenId) external view returns (GearDefinition memory) {
        return _gear[tokenId];
    }

    /// @notice Returns both image URIs. Used by the off-chain metadata renderer.
    function getURIs(uint256 tokenId) external view returns (string memory colorURI, string memory bwURI) {
        GearDefinition storage g = _gear[tokenId];
        return (g.colorURI, g.bwURI);
    }

    /// @notice Returns the combat stats. Used by the off-chain metadata renderer.
    function getStats(uint256 tokenId) external view returns (uint256 attack, uint256 defense) {
        GearDefinition storage g = _gear[tokenId];
        return (g.attack, g.defense);
    }

    function totalMinted(uint256 tokenId) external view returns (uint256) {
        return _gear[tokenId].minted;
    }

    function remainingSupply(uint256 tokenId) external view returns (uint256) {
        GearDefinition storage g = _gear[tokenId];
        return g.maxSupply - g.minted;
    }

    /**
     * @notice Compute the token ID for a given gear type + rarity combination.
     *         Useful off-chain (e.g. to call mint() directly by known ID).
     */
    function getTokenId(GearType gearType, Rarity rarity) external pure returns (uint256) {
        return _computeTokenId(gearType, rarity);
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    /// tokenId = (rarity + 1) * 1000 + (gearType + 1)
    function _computeTokenId(GearType gearType, Rarity rarity) internal pure returns (uint256) {
        return (uint256(rarity) + 1) * 1000 + (uint256(gearType) + 1);
    }
}
