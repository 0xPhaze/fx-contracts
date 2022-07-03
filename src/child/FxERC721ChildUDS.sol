// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS, s as erc721DS} from "UDS/ERC721UDS.sol";

import {FxBaseChildTunnelUDS} from "./FxBaseChildTunnelUDS.sol";

/* ------------- Storage ------------- */

// keccak256("diamond.storage.fx.erc721.child") == 0xd27a8eb27deabdc64caf45238ddcae36cb801813141fe6660d7723da1fb1287b
bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD = 0xd27a8eb27deabdc64caf45238ddcae36cb801813141fe6660d7723da1fb1287b;

struct FxERC721ChildDS {
    // L1 owner; not really used other than for displaying in UI
    mapping(uint256 => address) rootOwnerOf;
}

function s() pure returns (FxERC721ChildDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_FX_ERC721_CHILD
    }
}

/* ------------- Error ------------- */

error Disabled();
error CallerNotOwner();

/* ------------- FxERC721ChildUDS ------------- */

abstract contract FxERC721ChildUDS is ERC721UDS, FxBaseChildTunnelUDS {
    event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

    /* ------------- Internal ------------- */

    // @note doesn't need to validate sender, since this already happens in FxBase
    function _processMessageFromRoot(
        uint256, /* stateId */
        address, /* sender */
        bytes calldata data
    ) internal virtual override {
        (bool mint, address to, uint256[] memory tokenIds) = abi.decode(
            data,
            (bool, address, uint256[])
        );

        address owner;
        uint256 tokenId;
        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            tokenId = tokenIds[i];
            owner = erc721DS().ownerOf[tokenIds[i]];

            if (mint) {
                if (owner != address(0)) {
                    // this should normally never happen, because unstaking on L1 should set owner to 0 first
                    emit StateDesync(owner, to, tokenId);

                    _burn(tokenId); // burn from current owner
                }

                _mint(to, tokenId);

                s().rootOwnerOf[tokenId] = to;
            } else {
                if (owner != address(0)) {
                    _burn(tokenId);
                } else {
                    // should never happen
                    emit StateDesync(address(0), to, tokenId);
                }

                s().rootOwnerOf[tokenId] = address(0);
            }
        }
    }

    // @note not validated
    function _sendToRoot(uint256[] calldata tokenIds) internal {
        for (uint256 i; i < tokenIds.length; ++i) {
            // if (msg.sender != ownerOf(tokenIds[i])) revert CallerNotOwner();

            // address owner = erc721DS().ownerOf[tokenIds[i]];
            _burn(tokenIds[i]);
        }

        _sendMessageToRoot(abi.encode(tokenIds));
    }
}
