// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {FxBaseRootTunnel} from "../../src/base/FxBaseRootTunnel.sol";
import {FxBaseChildTunnel} from "../../src/base/FxBaseChildTunnel.sol";

contract MockFxTunnel {
    function sendMessageToChild(address child, bytes memory message) public {
        (bool success, bytes memory reason) = child.call(
            abi.encodeWithSelector(FxBaseChildTunnel.processMessageFromRoot.selector, 0, msg.sender, message)
        );
        assembly {
            if iszero(success) {
                revert(add(reason, 0x20), mload(reason))
            }
        }
    }
}

contract MockFxBaseChildTunnel is UUPSUpgrade, FxBaseChildTunnel {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxBaseChildTunnel(fxChild) {}

    function _processMessageFromRoot(
        uint256 stateId,
        address rootMessageSender,
        bytes calldata message
    ) internal override {
        emit MessageReceived(stateId, rootMessageSender, message);
    }

    function sendMessageToRoot(bytes calldata message) external {
        _sendMessageToRoot(message);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxBaseRootTunnel is UUPSUpgrade, FxBaseRootTunnel {
    constructor(address checkpointManager, address fxRoot) FxBaseRootTunnel(checkpointManager, fxRoot) {}

    function sendMessageToChild(bytes calldata message) external {
        _sendMessageToChild(message);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}
