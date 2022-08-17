// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseChildTunnelUDS} from "./FxBaseChildTunnelUDS.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD_REGISTRY = keccak256("diamond.storage.fx.erc721.child.registry");

function s() pure returns (FxERC721ChildRegistryDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_CHILD_REGISTRY;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721ChildRegistryDS {
    mapping(uint256 => address) rootOwnerOf;
}

// ------------- error

error Disabled();
error InvalidRootOwner();
error InvalidSignature();

contract FxERC721ChildTunnelUDS is FxBaseChildTunnelUDS {
    bytes32 constant REGISTER_SIG = keccak256("register(address,uint256[])");
    bytes32 constant DEREGISTER_SIG = keccak256("deregister(uint256[])");

    event StateDesync(address oldOwner, address newOwner, uint256 id);

    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    /* ------------- init ------------- */

    function init() public virtual override initializer {
        __Ownable_init();
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

            registerIds(to, ids);
        } else if (sig == DEREGISTER_SIG) {
            uint256[] memory ids = abi.decode(data, (uint256[]));

            deregisterIds(ids);
        } else {
            revert InvalidSignature();
        }
    }

    function _sendToRoot(address from, uint256[] calldata ids) internal virtual {
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            address rootOwner = s().rootOwnerOf[id];

            if (from != rootOwner) revert InvalidRootOwner();

            delete s().rootOwnerOf[id];

            _afterIdDeregistered(from, id);
        }

        _sendMessageToRoot(abi.encode(REGISTER_SIG, abi.encode(ids)));
    }

    /* ------------- hooks ------------- */

    function _afterIdRegistered(address to, uint256 id) internal virtual {}

    function _afterIdDeregistered(address from, uint256 id) internal virtual {}

    /* ------------- private ------------- */

    function registerIds(address to, uint256[] memory ids) private {
        uint256 idsLength = ids.length;

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = s().rootOwnerOf[id];

            // this should not happen, because deregistering on L1 should
            // send message to burn first, or require proof of burn on L2
            if (rootOwner != address(0)) {
                emit StateDesync(rootOwner, to, id);

                delete s().rootOwnerOf[id];

                _afterIdDeregistered(rootOwner, id);
            }

            s().rootOwnerOf[id] = to;

            _afterIdRegistered(to, id);
        }
    }

    function deregisterIds(uint256[] memory ids) private {
        uint256 idsLength = ids.length;

        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];
            address rootOwner = s().rootOwnerOf[id];

            // should not happen
            if (rootOwner == address(0)) {
                emit StateDesync(address(0), address(0), id);
            } else {
                s().rootOwnerOf[id] = address(0);

                _afterIdDeregistered(rootOwner, id);
            }
        }
    }
}
