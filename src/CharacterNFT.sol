// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseNFT, BaseNFTParams} from "./Base/BaseNFTNativePaymentToken.sol";

/**
 * @title NestableCharacterNFT
 * @notice ERC721 character NFT. Each token automatically gets a Token Bound Account
 *         (TBA) deployed via ERC-6551 on first equip through the SlotRegistry.
 *
 * Slot management, gear enforcement, and TBA deployment are handled entirely by
 * SlotRegistry — this contract is a plain ERC721 with minting/airdrop/royalty logic
 * inherited from BaseNFT.
 */
contract NestableCharacterNFT is BaseNFT {
    constructor(BaseNFTParams.InitParams memory _params) BaseNFT(_params) {}
}
