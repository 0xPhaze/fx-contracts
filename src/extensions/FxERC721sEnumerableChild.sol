// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxERC721sChild} from "../FxERC721sChild.sol";
import {LibEnumerableSet} from "UDS/lib/LibEnumerableSet.sol";

// ------------- storage

/// @dev diamond storage slot `keccak256("diamond.storage.fx.erc721s.enumerable.child")`
bytes32 constant DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD =
    0x8038bb3b2fd47e5eb6bca9376aba402e4709c051d175f2f753e357ba95ffc598;

function s() pure returns (FxERC721sEnumerableChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD;
    assembly {
        diamondStorage.slot := slot
    }
}

struct FxERC721sEnumerableChildDS {
    mapping(address => mapping(address => LibEnumerableSet.Uint256Set)) ownedIds;
}

abstract contract FxERC721sEnumerableChild is FxERC721sChild {
    using LibEnumerableSet for LibEnumerableSet.Uint256Set;

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

    function userOwnsId(address collection, address user, uint256 id) public view virtual returns (bool) {
        return s().ownedIds[collection][user].includes(id);
    }

    function tokenOfOwnerByIndex(address collection, address user, uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        return s().ownedIds[collection][user].at(index);
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address collection, address from, address to, uint256 id) internal virtual override {
        if (from != address(0)) s().ownedIds[collection][from].remove(id);
        if (to != address(0)) s().ownedIds[collection][to].add(id);
    }
}
