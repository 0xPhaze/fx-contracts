// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseRootTunnelUDS} from "./base/FxBaseRootTunnelUDS.sol";

bytes32 constant REGISTER_SIG = keccak256("registerIdsWithChild(address,uint256[])");
bytes32 constant DEREGISTER_SIG = keccak256("deregisterIdsWithChild(uint256[])");

error Disabled();
error InvalidSignature();

/// @title ERC721 FxTunnel
/// @author phaze (https://github.com/0xPhaze)
abstract contract FxERC721RootTunnelUDS is FxBaseRootTunnelUDS {
    constructor(address checkpointManager, address fxRoot) FxBaseRootTunnelUDS(checkpointManager, fxRoot) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- internal ------------- */

    function _registerIdsWithChild(address to, uint256[] memory ids) internal virtual {
        _sendMessageToChild(abi.encode(REGISTER_SIG, abi.encode(to, ids)));
    }

    function _deregisterIdsWithChild(uint256[] calldata ids) internal virtual {
        _sendMessageToChild(abi.encode(DEREGISTER_SIG, abi.encode(ids)));
    }
}
