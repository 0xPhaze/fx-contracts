// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxERC721ChildTunnelUDS} from "./FxERC721ChildTunnelUDS.sol";
import {LibEnumerableSet, UintSet} from "./lib/LibEnumerableSet.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD = keccak256("diamond.storage.fx.erc721.enumerable.child");

function s() pure returns (FxERC721EnumerableChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_ENUMERABLE_CHILD;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721EnumerableChildDS {
    mapping(address => UintSet) ownedIds;
}

contract FxERC721EnumerableChildTunnelUDS is FxERC721ChildTunnelUDS {
    using LibEnumerableSet for UintSet;

    constructor(address fxChild) FxERC721ChildTunnelUDS(fxChild) {}

    /* ------------- init ------------- */

    function init() public virtual override initializer {
        __Ownable_init();
    }

    /* ------------- public ------------- */

    function getOwnedIds(address user) public view returns (uint256[] memory) {
        return s().ownedIds[user].values();
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address to, uint256 id) internal override {
        s().ownedIds[to].add(id);
    }

    function _afterIdDeregistered(address from, uint256 id) internal override {
        s().ownedIds[from].remove(id);
    }
}
