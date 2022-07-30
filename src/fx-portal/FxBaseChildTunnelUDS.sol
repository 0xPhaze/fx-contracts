// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";

// ------------- storage

// keccak256("diamond.storage.fx.base.child.tunnel") == 0x78fb77475679055b561a920ad9c59687e010e1c25efff4790e95ce6af61a09c9
bytes32 constant DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL = 0x78fb77475679055b561a920ad9c59687e010e1c25efff4790e95ce6af61a09c9;

function s() pure returns (FxBaseChildTunnelDS storage diamondStorage) {
    assembly { diamondStorage.slot := DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL } // prettier-ignore
}

struct FxBaseChildTunnelDS {
    address fxRootTunnel;
}

// ------------- error

error CallerNotFxChild();
error InvalidRootSender();

abstract contract FxBaseChildTunnelUDS is OwnableUDS {
    event MessageSent(bytes message);

    address private immutable fxChild;

    constructor(address fxChild_) {
        fxChild = fxChild_;
    }

    /* ------------- restricted ------------- */

    function processMessageFromRoot(
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) external {
        if (msg.sender != fxChild) revert CallerNotFxChild();
        if (rootMessageSender != s().fxRootTunnel) revert InvalidRootSender();

        _processMessageFromRoot(stateId, rootMessageSender, data);
    }

    /* ------------- owner ------------- */

    function setFxRootTunnel(address _fxRootTunnel) external onlyOwner {
        s().fxRootTunnel = _fxRootTunnel;
    }

    /* ------------- internal ------------- */

    function _sendMessageToRoot(bytes memory message) internal {
        emit MessageSent(message);
    }

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes calldata message
    ) internal virtual;
}
