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
        (bytes32 sig, bytes memory data) = abi.decode(message, (bytes32, bytes));

        if (sig == REGISTER_ERC721_IDS_SIG) {
            (address to, uint256[] memory ids) = abi.decode(data, (address, uint256[]));

            _registerIds(to, ids);
        } else if (!_processSignature(sig, data)) {
            revert InvalidSignature();
        }
    }

    function _processSignature(bytes32, bytes memory) internal virtual returns (bool) {
        return false;
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(
        address from,
        address to,
        uint256 id
    ) internal virtual {}

    /* ------------- private ------------- */

    function _registerIds(address to, uint256[] memory ids) internal virtual {
        uint256 idsLength = ids.length;

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = s().ownerOf[id];

            // "Double burn". Should normally not happen.
            if (rootOwner == address(0) && to == address(0)) {
                emit StateResync(address(0), address(0), id);
                continue;
            }
            // Registering id, but it is already owned by someone else..
            // This should not happen, because deregistering on L1 should
            // send message to burn first, or require proof of burn on L2.
            // Though could happen if an explicit re-sync is triggered.
            else if (rootOwner != address(0) && to != address(0)) {
                emit StateResync(rootOwner, to, id);
            }

            s().ownerOf[id] = to;

            _afterIdRegistered(rootOwner, to, id);
        }
    }
}
