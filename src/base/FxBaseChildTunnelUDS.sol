// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL = keccak256("diamond.storage.fx.base.child.tunnel");

function s() pure returns (FxBaseChildTunnelDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL;
    assembly { diamondStorage.slot := slot } // prettier-ignore
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

    /* ------------- init ------------- */

    function init() public virtual initializer {
        __Ownable_init();
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
