// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxBaseRootTunnel} from "./base/FxBaseRootTunnel.sol";

bytes32 constant REGISTER_ERC721_IDS_SIG = keccak256("registerERC721IdsWithChild(address,uint256[])");
bytes32 constant DEREGISTER_ERC721_IDS_SIG = keccak256("deregisterERC721IdsWithChild(uint256[])");

/// @title ERC721 FxRootTunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC721Root is FxBaseRootTunnel {
    constructor(address checkpointManager, address fxRoot) FxBaseRootTunnel(checkpointManager, fxRoot) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- internal ------------- */

    function _registerERC721IdsWithChild(address to, uint256[] calldata ids) internal virtual {
        _sendMessageToChild(abi.encode(REGISTER_ERC721_IDS_SIG, abi.encode(to, ids)));
    }

    function _registerERC721IdsWithChildMem(address to, uint256[] memory ids) internal virtual {
        _sendMessageToChild(abi.encode(REGISTER_ERC721_IDS_SIG, abi.encode(to, ids)));
    }
}
