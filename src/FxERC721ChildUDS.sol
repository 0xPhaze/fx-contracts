// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS, s as erc721DS} from "UDS/tokens/ERC721UDS.sol";

import {FxBaseChildTunnelUDS} from "./fx-portal/FxBaseChildTunnelUDS.sol";

// ------------- storage

// keccak256("diamond.storage.fx.erc721.child") == 0xd27a8eb27deabdc64caf45238ddcae36cb801813141fe6660d7723da1fb1287b
bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD = 0xd27a8eb27deabdc64caf45238ddcae36cb801813141fe6660d7723da1fb1287b;

struct FxERC721ChildDS {
    mapping(uint256 => address) rootOwnerOf; // L1 owner; not really used other than for displaying in UI
}

function s() pure returns (FxERC721ChildDS storage diamondStorage) {
    assembly { diamondStorage.slot := DIAMOND_STORAGE_FX_ERC721_CHILD } // prettier-ignore
}

// ------------- error

error Disabled();
error CallerNotOwner();
error InvalidSignature();

abstract contract FxERC721ChildUDS is ERC721UDS, FxBaseChildTunnelUDS {
    bytes32 constant MINT_SIG = keccak256("mint(address,uint256[])");
    bytes32 constant BURN_SIG = keccak256("burn(uint256[])");

    event StateDesync(address oldOwner, address newOwner, uint256 id);

    /* ------------- internal ------------- */

    // @note doesn't need to validate sender, since this already happens in FxBase
    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal virtual override {
        (bytes32 sig, bytes memory data) = abi.decode(message, (bytes32, bytes));

        if (sig == MINT_SIG) {
            (address to, uint256[] memory ids) = abi.decode(data, (address, uint256[]));

            mintIds(to, ids);
        } else if (sig == BURN_SIG) {
            uint256[] memory ids = abi.decode(data, (uint256[]));

            burnIds(ids);
        } else revert InvalidSignature();
    }

    /* ------------- private ------------- */

    function mintIds(address to, uint256[] memory ids) private {
        uint256 length = ids.length;

        for (uint256 i; i < length; ++i) {
            uint256 id = ids[i];
            address owner = erc721DS().ownerOf[id];

            // this should normally never happen,
            // because unstaking on L1 should
            // send message to burn first
            // or require proof of burn on L2
            if (owner != address(0)) {
                emit StateDesync(owner, to, id);

                _burn(id); // burn from current owner
            }

            _mint(to, id);

            s().rootOwnerOf[id] = to;
        }
    }

    function burnIds(uint256[] memory ids) private {
        uint256 length = ids.length;

        for (uint256 i; i < length; ++i) {
            uint256 id = ids[i];
            address owner = erc721DS().ownerOf[ids[i]];

            // triggering burn event over bridge
            // should normally never happen
            if (owner == address(0)) {
                emit StateDesync(address(0), address(0), id);
            } else {
                _burn(id);
            }

            s().rootOwnerOf[id] = address(0);
        }
    }

    // @note not validated
    function _sendToRoot(uint256[] calldata ids) internal {
        for (uint256 i; i < ids.length; ++i) {
            // if (msg.sender != ownerOf(ids[i])) revert CallerNotOwner();

            // address owner = erc721DS().ownerOf[ids[i]];
            _burn(ids[i]);
        }

        _sendMessageToRoot(abi.encode(MINT_SIG, abi.encode(ids)));
    }
}
