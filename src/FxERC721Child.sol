// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseChildTunnel} from "./base/FxBaseChildTunnel.sol";
import {REGISTER_ERC721_IDS_SIG} from "./FxERC721Root.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD_TUNNEL = keccak256("diamond.storage.fx.erc721.child.tunnel");

function s() pure returns (FxERC721ChildRegistryDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_CHILD_TUNNEL;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721ChildRegistryDS {
    mapping(uint256 => address) ownerOf;
}

// ------------- error

error InvalidSignature();

/// @title ERC721 FxChildTunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC721Child is FxBaseChildTunnel {
    event StateResync(address oldOwner, address newOwner, uint256 id);

    constructor(address fxChild) FxBaseChildTunnel(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- view ------------- */

    function ownerOf(uint256 id) public view virtual returns (address) {
        return s().ownerOf[id];
    }

    /* ------------- internal ------------- */

    // @note doesn't need to validate sender, since this already happens in FxBase
    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal virtual override {
        bytes4 sig = bytes4(message[:4]);

        if (sig != REGISTER_ERC721_IDS_SIG) revert InvalidSignature();

        address to = address(uint160(uint256(bytes32(message[4:36]))));

        uint256[] calldata ids;
        assembly {
            // skip 4 bytes sig + 32 bytes address to
            let idsLenOffset := add(add(message.offset, 0x04), calldataload(add(message.offset, 0x24)))
            ids.length := calldataload(idsLenOffset)
            ids.offset := add(idsLenOffset, 0x20)
        }

        _registerIds(to, ids);
    }

    function _registerIds(address to, uint256[] calldata ids) internal virtual {
        uint256 length = ids.length;

        for (uint256 i; i < length; ++i) {
            _registerId(to, ids[i]);
        }
    }

    function _registerId(address to, uint256 id) internal virtual {
        address from = s().ownerOf[id];

        // Should normally not happen unless re-syncing.
        if (from == to) {
            emit StateResync(from, to, id);

            return;
        }
        // Registering id, but it is already owned by someone else..
        // This should not happen, because deregistering on L1 should
        // send message to burn first, or require proof of burn on L2.
        // Though could happen if an explicit re-sync is triggered.
        if (from != address(0) && to != address(0)) {
            emit StateResync(from, to, id);
        }

        s().ownerOf[id] = to;

        _afterIdRegistered(from, to, id);
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(
        address from,
        address to,
        uint256 id
    ) internal virtual {}
}
