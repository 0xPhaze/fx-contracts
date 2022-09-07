// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {FxBaseRootTunnelUDS} from "./base/FxBaseRootTunnelUDS.sol";
import {MINT_ERC20_SIG} from "./FxERC20RootUDS.sol";

error TransferFailed();
error InvalidSignature();

abstract contract FxERC20RootTunnelUDS is FxBaseRootTunnelUDS, ERC20UDS {
    address public immutable token;

    constructor(
        address token_,
        address checkpointManager,
        address fxRoot
    ) FxBaseRootTunnelUDS(checkpointManager, fxRoot) {
        token = token_;
    }

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- external ------------- */

    /// @dev this assumes a standard ERC20
    /// that throws or returns false on failed transfers
    function lock(address to, uint256 amount) external virtual {
        if (!ERC20UDS(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        _sendMessageToChild(abi.encode(MINT_ERC20_SIG, abi.encode(to, amount)));
    }

    function unlock(bytes calldata proofData) external virtual {
        bytes memory message = _validateAndExtractMessage(proofData);

        (bytes32 sig, bytes memory args) = abi.decode(message, (bytes32, bytes));
        (address to, uint256 amount) = abi.decode(args, (address, uint256));

        if (sig != MINT_ERC20_SIG) revert InvalidSignature();

        if (!ERC20UDS(token).transfer(to, amount)) revert TransferFailed();
    }
}
