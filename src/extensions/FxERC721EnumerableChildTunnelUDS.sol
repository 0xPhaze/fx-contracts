// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxERC721ChildTunnelUDS} from "../FxERC721ChildTunnelUDS.sol";
import {LibEnumerableSet, Uint256Set} from "UDS/lib/LibEnumerableSet.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD = keccak256("diamond.storage.fx.erc721.enumerable.child");

function s() pure returns (FxERC721EnumerableChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721EnumerableChildDS {
    mapping(address => Uint256Set) ownedIds;
}

abstract contract FxERC721EnumerableChildTunnelUDS is FxERC721ChildTunnelUDS {
    using LibEnumerableSet for Uint256Set;

    constructor(address fxChild) FxERC721ChildTunnelUDS(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- public ------------- */

    function getOwnedIds(address user) public view virtual returns (uint256[] memory) {
        return s().ownedIds[user].values();
    }

    function balanceOf(address user) public view virtual returns (uint256) {
        return s().ownedIds[user].length();
    }

    function tokenOfOwnerByIndex(address user, uint256 id) public view virtual returns (uint256) {
        return s().ownedIds[user].at(id);
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address to, uint256 id) internal virtual override {
        s().ownedIds[to].add(id);
    }

    function _afterIdDeregistered(address from, uint256 id) internal virtual override {
        s().ownedIds[from].remove(id);
    }
}
