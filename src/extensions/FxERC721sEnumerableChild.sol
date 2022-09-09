// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxERC721sChild} from "../FxERC721sChild.sol";
import {LibEnumerableSet, Uint256Set} from "UDS/lib/LibEnumerableSet.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD = keccak256("diamond.storage.fx.erc721s.enumerable.child");

function s() pure returns (FxERC721EnumerableChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721EnumerableChildDS {
    mapping(address => mapping(address => Uint256Set)) ownedIds;
}

abstract contract FxERC721sEnumerableChild is FxERC721sChild {
    using LibEnumerableSet for Uint256Set;

    constructor(address fxChild) FxERC721sChild(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- public ------------- */

    function getOwnedIds(address collection, address user) public view virtual returns (uint256[] memory) {
        return s().ownedIds[collection][user].values();
    }

    function erc721BalanceOf(address collection, address user) public view virtual returns (uint256) {
        return s().ownedIds[collection][user].length();
    }

    function userOwnsId(
        address collection,
        address user,
        uint256 id
    ) public view virtual returns (bool) {
        return s().ownedIds[collection][user].includes(id);
    }

    function tokenOfOwnerByIndex(
        address collection,
        address user,
        uint256 index
    ) public view virtual returns (uint256) {
        return s().ownedIds[collection][user].at(index);
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(
        address collection,
        address from,
        address to,
        uint256 id
    ) internal virtual override {
        if (from != address(0)) s().ownedIds[collection][from].remove(id);
        if (to != address(0)) s().ownedIds[collection][to].add(id);
    }
}
