// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseRootTunnelUDS} from "./FxBaseRootTunnelUDS.sol";

error Disabled();
error InvalidSignature();

/// @title ERC721 FxTunnel
/// @author phaze (https://github.com/0xPhaze)
abstract contract FxERC721RootTunnelUDS is FxBaseRootTunnelUDS {
    bytes32 constant REGISTER_SIG = keccak256("registerIds(address,uint256[])");
    bytes32 constant DEREGISTER_SIG = keccak256("deregisterIds(uint256[])");

    constructor(address checkpointManager, address fxRoot) FxBaseRootTunnelUDS(checkpointManager, fxRoot) {}

    /* ------------- init ------------- */

    function init() public virtual override initializer {
        __Ownable_init();
    }

    /* ------------- internal ------------- */

    function _registerWithChild(address to, uint256[] memory ids) internal virtual {
        _sendMessageToChild(abi.encode(REGISTER_SIG, abi.encode(to, ids)));
    }

    function _deregisterWithChild(uint256[] calldata ids) internal virtual {
        _sendMessageToChild(abi.encode(DEREGISTER_SIG, abi.encode(ids)));
    }
}
