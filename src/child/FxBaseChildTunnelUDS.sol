// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {InitializableUDS} from "UDS/InitializableUDS.sol";

/* ------------- Storage ------------- */

// keccak256("diamond.storage.fx.base.child.tunnel") == 0x78fb77475679055b561a920ad9c59687e010e1c25efff4790e95ce6af61a09c9
bytes32 constant DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL = 0x78fb77475679055b561a920ad9c59687e010e1c25efff4790e95ce6af61a09c9;

struct FxBaseChildTunnelDS {
    address fxRootTunnel;
}

function s() pure returns (FxBaseChildTunnelDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL
    }
}

/* ------------- Error ------------- */

error CallerNotFxChild();
error InvalidRootSender();

/* ------------- FxBaseChildTunnelUDS ------------- */

abstract contract FxBaseChildTunnelUDS is InitializableUDS, OwnableUDS {
    event MessageSent(bytes message);

    address private immutable fxChild;

    /* ------------- Init ------------- */

    constructor(address fxChild_) {
        fxChild = fxChild_;
    }

    /* ------------- Restricted ------------- */

    function processMessageFromRoot(
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) external {
        if (msg.sender != fxChild) revert CallerNotFxChild();
        if (rootMessageSender != s().fxRootTunnel) revert InvalidRootSender();

        _processMessageFromRoot(stateId, rootMessageSender, data);
    }

    /* ------------- Owner ------------- */

    function setFxRootTunnel(address _fxRootTunnel) external onlyOwner {
        s().fxRootTunnel = _fxRootTunnel;
    }

    /* ------------- Internal ------------- */

    function _sendMessageToRoot(bytes memory message) internal {
        emit MessageSent(message);
    }

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes calldata message
    ) internal virtual;
}
