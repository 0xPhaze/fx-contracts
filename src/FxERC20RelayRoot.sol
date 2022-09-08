// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {MINT_ERC20_SIG} from "./FxERC20UDSRoot.sol";
import {FxBaseRootTunnel} from "./base/FxBaseRootTunnel.sol";

error TransferFailed();
error InvalidSignature();

/// @title ERC20 Root Tunnel
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC20RelayRoot is FxBaseRootTunnel {
    address public immutable token;

    constructor(
        address token_,
        address checkpointManager,
        address fxRoot
    ) FxBaseRootTunnel(checkpointManager, fxRoot) {
        token = token_;
    }

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- internal ------------- */

    function _mintERC20TokensWithChild(address to, uint256 amount) internal virtual {
        _sendMessageToChild(abi.encode(MINT_ERC20_SIG, abi.encode(to, amount)));
    }

    /* ------------- external ------------- */

    /// @dev this assumes a standard ERC20
    /// that throws or returns false on failed transfers
    function lock(address to, uint256 amount) external virtual {
        if (!ERC20UDS(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        _mintERC20TokensWithChild(to, amount);
    }

    function unlock(bytes calldata proofData) external virtual {
        bytes memory message = _validateAndExtractMessage(proofData);

        (bytes32 sig, bytes memory args) = abi.decode(message, (bytes32, bytes));
        (address to, uint256 amount) = abi.decode(args, (address, uint256));

        if (sig != MINT_ERC20_SIG) revert InvalidSignature();

        if (!ERC20UDS(token).transfer(to, amount)) revert TransferFailed();
    }
}
