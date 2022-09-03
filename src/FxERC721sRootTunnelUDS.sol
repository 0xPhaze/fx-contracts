// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseRootTunnelUDS} from "./base/FxBaseRootTunnelUDS.sol";

bytes32 constant REGISTER_SIG = keccak256("registerERC721IdsWithChild(ddress,uint256[])");
bytes32 constant DEREGISTER_SIG = keccak256("deregisterERC721IdsWithChild(int256[])");

error Disabled();
error InvalidSignature();

/// @title ERC721 FxRootTunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC721sRootTunnelUDS is FxBaseRootTunnelUDS {
    constructor(address checkpointManager, address fxRoot) FxBaseRootTunnelUDS(checkpointManager, fxRoot) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- internal ------------- */

    function _registerERC721IdsWithChild(address to, uint256[] memory ids) internal virtual {
        _sendMessageToChild(abi.encode(REGISTER_SIG, abi.encode(to, ids)));
    }

    function _deregisterERC721IdsWithChild(uint256[] calldata ids) internal virtual {
        _sendMessageToChild(abi.encode(DEREGISTER_SIG, abi.encode(ids)));
    }
}
