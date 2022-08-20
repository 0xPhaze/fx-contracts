// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721M} from "ERC721M/ERC721M.sol";
import {FxERC721RootTunnelUDS} from "../FxERC721RootTunnelUDS.sol";

error Disabled();
error InvalidSignature();

/// @title ERC721M FxPortal extension
/// @author phaze (https://github.com/0xPhaze/ERC721M)
abstract contract FxERC721MRootUDS is FxERC721RootTunnelUDS, ERC721M {
    constructor(address checkpointManager, address fxRoot) FxERC721RootTunnelUDS(checkpointManager, fxRoot) {}

    /* ------------- virtual ------------- */

    function tokenURI(uint256 id) external view virtual override returns (string memory);

    function _authorizeTunnelController() internal virtual override;

    /* ------------- internal ------------- */

    function _mintLockedAndTransmit(address to, uint256 quantity) internal virtual {
        uint256 startId = _nextTokenId();

        _mintAndLock(to, quantity, true);

        uint256[] memory ids = new uint256[](quantity);

        unchecked {
            for (uint256 i; i < quantity; ++i) ids[i] = startId + i;
        }

        _registerERC721IdsWithChild(address(this), to, ids);
    }

    function _lockAndTransmit(address from, uint256[] calldata ids) internal virtual {
        unchecked {
            for (uint256 i; i < ids.length; ++i) _lock(from, ids[i]);
        }

        _registerERC721IdsWithChild(address(this), from, ids);
    }

    // @notice using `_unlockAndTransmit` is simple and easy
    // this assumes L1 state as the single source of truth
    // messages are always pushed L1 -> L2 without knowing state on L2
    // this means that NFTs should not be allowed to be traded/sold on L2
    function _unlockAndTransmit(address from, uint256[] calldata ids) internal virtual {
        unchecked {
            for (uint256 i; i < ids.length; ++i) _unlock(from, ids[i]);
        }

        _deregisterERC721IdsWithChild(address(this), ids);
    }

    // bytes32 constant MINT_SIG = keccak256("mint(address,uint256[])");

    // // @notice using `_unlockWithProof` is the 'correct' way for transmitting messages L2 -> L1
    // // validate ERC721 burn on L2 first, then unlock on L1 with tx inclusion proof
    // // NFTs can be traded/sold on L2 if adapted to transfer to a new owner
    // function _unlockWithProof(bytes calldata proofData) internal virtual {
    //     bytes memory message = _validateAndExtractMessage(proofData);

    //     (bytes32 sig, bytes memory data) = abi.decode(message, (bytes32, bytes));

    //     if (sig != MINT_SIG) revert InvalidSignature();

    //     (address from, uint256[] memory ids) = abi.decode(data, (address, uint256[]));

    //     uint256 idsLength = ids.length;

    //     unchecked {
    //         for (uint256 i; i < idsLength; ++i) _unlock(from, ids[i]);
    //     }
    // }
}
