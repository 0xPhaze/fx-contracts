// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseChildTunnel} from "./base/FxBaseChildTunnel.sol";
import {REGISTER_ERC721s_IDS_SELECTOR} from "./FxERC721sRoot.sol";

// ------------- storage

/// @dev diamond storage slot `keccak256("diamond.storage.fx.erc721s.child.tunnel")`
bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD_TUNNEL =
    0xb178638442ca9f98d83bc4e366023dce03b56d59a03060ae222d07c9b9c35c7d;

function s() pure returns (FxERC721sChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_CHILD_TUNNEL;
    assembly {
        diamondStorage.slot := slot
    }
}

struct FxERC721sChildDS {
    mapping(address => mapping(uint256 => address)) ownerOf;
}

// ------------- error

error InvalidSelector();

/// @title ERC721 FxChildTunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC721sChild is FxBaseChildTunnel {
    event Transfer(address indexed collection, address indexed from, address indexed to, uint256 id);
    event StateResync(address oldOwner, address newOwner, uint256 id);

    constructor(address fxChild) FxBaseChildTunnel(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- view ------------- */

    function ownerOf(address collection, uint256 id) public view virtual returns (address) {
        return s().ownerOf[collection][id];
    }

    /* ------------- internal ------------- */

    // @note doesn't need to validate sender, since this already happens in FxBase
    function _processMessageFromRoot(uint256, address, bytes calldata message) internal virtual override {
        bytes4 selector = bytes4(message[:4]);

        if (selector != REGISTER_ERC721s_IDS_SELECTOR) revert InvalidSelector();

        address collection = address(uint160(uint256(bytes32(message[4:36]))));
        address to = address(uint160(uint256(bytes32(message[36:68]))));

        uint256[] calldata ids;
        assembly {
            // Skip 4 bytes selector + 32 bytes address collection + 32 bytes address to
            let idsLenOffset := add(add(message.offset, 0x04), calldataload(add(message.offset, 0x44)))
            ids.length := calldataload(idsLenOffset)
            ids.offset := add(idsLenOffset, 0x20)
        }

        _registerIds(collection, to, ids);
    }

    function _registerIds(address collection, address to, uint256[] calldata ids) internal virtual {
        uint256 length = ids.length;

        for (uint256 i; i < length; ++i) {
            _registerId(collection, to, ids[i]);
        }
    }

    function _registerId(address collection, address to, uint256 id) internal virtual {
        address from = s().ownerOf[collection][id];

        // Should normally not happen unless re-syncing.
        if (from == to) {
            emit StateResync(from, to, id);
        } else {
            // Registering id, but it is already owned by someone else..
            // This should not happen, because deregistering on L1 should
            // send message to burn first, or require proof of burn on L2.
            // Though could happen if an explicit re-sync is triggered.
            if (from != address(0) && to != address(0)) {
                emit StateResync(from, to, id);
            }

            s().ownerOf[collection][id] = to;

            emit Transfer(collection, from, to, id);

            _afterIdRegistered(collection, from, to, id);
        }
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address collection, address from, address to, uint256 id) internal virtual {}
}
