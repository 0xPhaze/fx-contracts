// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS, s as erc721DS} from "UDS/ERC721UDS.sol";

import {FxBaseChildTunnelUDS} from "./FxBaseChildTunnelUDS.sol";

/* ------------- Storage ------------- */

// // keccak256("diamond.storage.fx.erc721.child") == 0xd27a8eb27deabdc64caf45238ddcae36cb801813141fe6660d7723da1fb1287b
// bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD = 0xd27a8eb27deabdc64caf45238ddcae36cb801813141fe6660d7723da1fb1287b;

// struct FxBaseChildTunnelDS {
//     // L1 owner; not really used other than for displaying in UI
//     mapping(uint256 => address) rootOwnerOf;
// }

// function ds() pure returns (FxBaseChildTunnelDS storage diamondStorage) {
//     assembly {
//         diamondStorage.slot := DIAMOND_STORAGE_FX_ERC721_CHILD
//     }
// }

/* ------------- Error ------------- */

error Disabled();
error CallerNotOwner();

/* ------------- FxERC721ChildUDS ------------- */

abstract contract FxERC721ChildUDS is ERC721UDS, FxBaseChildTunnelUDS {
    event FxUnlockERC721Batch(address indexed from, uint256[] tokenIds);
    event FxLockERC721Batch(address indexed to, uint256[] tokenIds);
    event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

    /* ------------- Internal ------------- */

    function _processMessageFromRoot(
        uint256, /* stateId */
        address, /* sender */
        bytes calldata data
    ) internal override {
        (address to, uint256[] memory tokenIds) = abi.decode(
            data,
            (address, uint256[])
        );

        address owner;
        uint256 tokenId;
        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            tokenId = tokenIds[i];
            owner = ownerOf(tokenIds[i]);

            if (owner != address(0)) {
                // this should normally never happen, because unstaking on L1 should set owner to 0 first
                emit StateDesync(owner, to, tokenId);
                _burn(tokenId); // burn from current owner
            }

            _mint(to, tokenId);
        }
    }

    function sendToRoot(uint256[] calldata tokenIds) external {
        for (uint256 i; i < tokenIds.length; ++i) {
            if (msg.sender != ownerOf(tokenIds[i])) revert CallerNotOwner();

            _burn(tokenIds[i]);
        }

        _sendMessageToRoot(abi.encode(tokenIds));
    }
}
