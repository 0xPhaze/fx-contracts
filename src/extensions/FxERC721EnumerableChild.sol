// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxERC721Child} from "../FxERC721Child.sol";
import {LibEnumerableSet} from "UDS/lib/LibEnumerableSet.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD = keccak256("diamond.storage.fx.erc721.enumerable.child");

function s() pure returns (FxERC721EnumerableChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD;
    assembly {
        diamondStorage.slot := slot
    }
}

struct FxERC721EnumerableChildDS {
    mapping(address => LibEnumerableSet.Uint256Set) ownedIds;
}

abstract contract FxERC721EnumerableChild is FxERC721Child {
    using LibEnumerableSet for LibEnumerableSet.Uint256Set;

    constructor(address fxChild) FxERC721Child(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- public ------------- */

    function getOwnedIds(address user) public view virtual returns (uint256[] memory) {
        return s().ownedIds[user].values();
    }

    function erc721BalanceOf(address user) public view virtual returns (uint256) {
        return s().ownedIds[user].length();
    }

    function userOwnsId(address user, uint256 id) public view virtual returns (bool) {
        return s().ownedIds[user].includes(id);
    }

    function tokenOfOwnerByIndex(address user, uint256 index) public view virtual returns (uint256) {
        return s().ownedIds[user].at(index);
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address from, address to, uint256 id) internal virtual override {
        if (from != address(0)) s().ownedIds[from].remove(id);
        if (to != address(0)) s().ownedIds[to].add(id);
    }
}
