// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseChildTunnelUDS} from "./base/FxBaseChildTunnelUDS.sol";
import {REGISTER_ERC721s_IDS_SIG, DEREGISTER_ERC721s_IDS_SIG} from "./FxERC721sRootTunnelUDS.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD_TUNNEL = keccak256("diamond.storage.fx.erc721s.child.tunnel");

function s() pure returns (FxERC721ChildRegistryDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_CHILD_TUNNEL;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721ChildRegistryDS {
    mapping(address => mapping(uint256 => address)) ownerOf;
}

// ------------- error

error Disabled();
error InvalidRootOwner();
error InvalidSignature();

/// @title ERC721 FxChildTunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC721sChildTunnelUDS is FxBaseChildTunnelUDS {
    event StateDesync(address oldOwner, address newOwner, uint256 id);

    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- public ------------- */

    function ownerOf(address collection, uint256 id) public view virtual returns (address) {
        return s().ownerOf[collection][id];
    }

    /* ------------- internal ------------- */

    // @note doesn't need to validate sender, since this already happens in FxBase
    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal virtual override {
        (bytes32 sig, bytes memory data) = abi.decode(message, (bytes32, bytes));

        if (sig == REGISTER_ERC721s_IDS_SIG) {
            (address collection, address to, uint256[] memory ids) = abi.decode(data, (address, address, uint256[]));

            registerIds(collection, to, ids);
        } else if (sig == DEREGISTER_ERC721s_IDS_SIG) {
            (address collection, uint256[] memory ids) = abi.decode(data, (address, uint256[]));

            deregisterIds(collection, ids);
        } else if (!_processSignature(sig, data)) {
            revert InvalidSignature();
        }
    }

    function _processSignature(bytes32, bytes memory) internal virtual returns (bool) {
        return false;
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(
        address collection,
        address to,
        uint256 id
    ) internal virtual {}

    function _afterIdDeregistered(
        address collection,
        address from,
        uint256 id
    ) internal virtual {}

    /* ------------- private ------------- */

    function registerIds(
        address collection,
        address to,
        uint256[] memory ids
    ) private {
        uint256 idsLength = ids.length;

        mapping(uint256 => address) storage ownerOf_ = s().ownerOf[collection];

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = ownerOf_[id];

            // this should not happen, because deregistering on L1 should
            // send message to burn first, or require proof of burn on L2
            if (rootOwner != address(0)) {
                emit StateDesync(rootOwner, to, id);

                delete ownerOf_[id];

                _afterIdDeregistered(collection, rootOwner, id);
            }

            ownerOf_[id] = to;

            _afterIdRegistered(collection, to, id);
        }
    }

    function deregisterIds(address collection, uint256[] memory ids) private {
        uint256 idsLength = ids.length;

        mapping(uint256 => address) storage ownerOf_ = s().ownerOf[collection];

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = ownerOf_[id];

            // should not happen
            if (rootOwner == address(0)) {
                emit StateDesync(address(0), address(0), id);
            } else {
                delete ownerOf_[id];

                _afterIdDeregistered(collection, rootOwner, id);
            }
        }
    }
}
