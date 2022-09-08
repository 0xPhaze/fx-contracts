// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

abstract contract FxBaseChildTunnel {
    event MessageSent(bytes message);

    address private immutable fxChild;

    constructor(address fxChild_) {
        fxChild = fxChild_;
    }

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual;

    /* ------------- view ------------- */

    function fxRootTunnel() public view returns (address) {
        return s().fxRootTunnel;
    }

    /* ------------- restricted ------------- */

    function setFxRootTunnel(address fxRootTunnel_) external {
        _authorizeTunnelController();

        s().fxRootTunnel = fxRootTunnel_;
    }

    function processMessageFromRoot(
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) external {
        if (msg.sender != fxChild) revert CallerNotFxChild();
        if (rootMessageSender == address(0) || rootMessageSender != s().fxRootTunnel) revert InvalidRootSender();

        _processMessageFromRoot(stateId, rootMessageSender, data);
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
