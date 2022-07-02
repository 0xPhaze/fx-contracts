// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS, s as erc721DS} from "UDS/ERC721UDS.sol";

import {FxBaseChildTunnelUDS} from "./FxBaseChildTunnelUDS.sol";

/* ============== Storage ============== */

// keccak256("diamond.storage.fx.erc721.synced.child") == 0x54a9435ed8ff7445b0fc5cfbaa4f67735a38576eb93327b3e9fe71c92b49e148
bytes32 constant DIAMOND_STORAGE_FX_ERC721_SYNCED_CHILD = 0x54a9435ed8ff7445b0fc5cfbaa4f67735a38576eb93327b3e9fe71c92b49e148;

struct FxBaseChildTunnelDS {
    // L1 owner; not really used other than for displaying in UI
    mapping(uint256 => address) rootOwnerOf;
}

function s() pure returns (FxBaseChildTunnelDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_FX_ERC721_SYNCED_CHILD
    }
}

/* ============== Error ============== */

error Disabled();
error CallerNotRootOwnerNorDelegate();

error TransferFromIncorrectOwner();
error TransferToZeroAddress();

/* ============== FxERC721SyncedChildUDS ============== */

abstract contract FxERC721SyncedChildUDS is ERC721UDS, FxBaseChildTunnelUDS {
    event FxUnlockERC721Batch(address indexed from, uint256[] tokenIds);
    event FxLockERC721Batch(address indexed to, uint256[] tokenIds);
    event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

    /* ------------- View ------------- */

    function rootOwnerOf(uint256 tokenId) external view returns (address) {
        return s().rootOwnerOf[tokenId];
    }

    /* ------------- Public ------------- */

    function delegateOwnership(address to, uint256 id) public {
        address owner = erc721DS().owners[id];

        bool isRootOwnerOrDelegate = (
            msg.sender == owner ||
            msg.sender == s().rootOwnerOf[id]
            ); //prettier-ignore

        if (!isRootOwnerOrDelegate) revert CallerNotRootOwnerNorDelegate();

        unchecked {
            erc721DS().balances[owner]--;
            erc721DS().balances[to]++;
        }

        erc721DS().owners[id] = to;

        delete erc721DS().getApproved[id];

        emit Transfer(owner, to, id);
    }

    function approve(address, uint256) public pure override {
        revert Disabled();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert Disabled();
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override {
        revert Disabled();
    }

    function safeTransferFrom(
        address,
        address,
        uint256
    ) public pure override {
        revert Disabled();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure override {
        revert Disabled();
    }

    function permit(
        address,
        address,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) public pure override {
        revert Disabled();
    }

    /* ------------- Internal ------------- */

    function _processMessageFromRoot(
        uint256, /* stateId */
        address, /* sender */
        bytes calldata data
    ) internal override {
        (bool mint, address to, uint256[] memory tokenIds) = abi.decode(
            data,
            (bool, address, uint256[])
        );

        address owner;
        uint256 tokenId;
        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            tokenId = tokenIds[i];
            owner = erc721DS().owners[tokenIds[i]];

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

    function sendToRoot(uint256[] calldata tokenIds) external {
        address owner;
        uint256 tokenId;

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenId = tokenIds[i];

            owner = ownerOf(tokenId);
            _burn(tokenId);
        }

        _sendMessageToRoot(abi.encode(tokenIds));
    }
}
