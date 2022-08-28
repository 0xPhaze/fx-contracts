// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseChildTunnelUDS} from "./base/FxBaseChildTunnelUDS.sol";
import {REGISTER_SIG, DEREGISTER_SIG} from "./FxERC721RootTunnelUDS.sol";

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

error Disabled();
error InvalidRootOwner();
error InvalidSignature();

/// @title ERC721 FxChildTunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC721ChildTunnelUDS is FxBaseChildTunnelUDS {
    event StateDesync(address oldOwner, address newOwner, uint256 id);

    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

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

        if (sig == REGISTER_SIG) {
            (address to, uint256[] memory ids) = abi.decode(data, (address, uint256[]));

            _registerIds(to, ids);
        } else if (sig == DEREGISTER_SIG) {
            uint256[] memory ids = abi.decode(data, (uint256[]));

            _deregisterIds(ids);
        } else {
            revert InvalidSignature();
        }
    }

    // function _sendToRoot(address from, uint256[] calldata ids) internal virtual {
    //     for (uint256 i; i < ids.length; ++i) {
    //         uint256 id = ids[i];
    //         address rootOwner = s().rootOwnerOf[id];

    //         if (from != rootOwner) revert InvalidRootOwner();

    //         delete s().rootOwnerOf[id];

    //         _afterIdDeregistered(from, id);
    //     }

    //     _sendMessageToRoot(abi.encode(MINT_SIG, abi.encode(ids)));
    // }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address to, uint256 id) internal virtual {}

    function _afterIdDeregistered(address from, uint256 id) internal virtual {}

    /* ------------- internal ------------- */

    function _registerIds(address to, uint256[] memory ids) internal {
        uint256 idsLength = ids.length;

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = s().ownerOf[id];

            // this should not happen, because deregistering on L1 should
            // send message to burn first, or require proof of burn on L2
            if (rootOwner != address(0)) {
                emit StateDesync(rootOwner, to, id);

                delete s().ownerOf[id];

                _afterIdDeregistered(rootOwner, id);
            }

            s().ownerOf[id] = to;

            _afterIdRegistered(to, id);
        }
    }

    function _deregisterIds(uint256[] memory ids) internal {
        uint256 idsLength = ids.length;

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = s().ownerOf[id];

            // should not happen
            if (rootOwner == address(0)) {
                emit StateDesync(address(0), address(0), id);
            } else {
                delete s().ownerOf[id];

                _afterIdDeregistered(rootOwner, id);
            }
        }
    }
}
