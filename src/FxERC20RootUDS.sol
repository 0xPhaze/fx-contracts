// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {FxBaseRootTunnelUDS} from "./fx-portal/FxBaseRootTunnelUDS.sol";

error InvalidSignature();

abstract contract FxERC20RootUDS is FxBaseRootTunnelUDS, ERC20UDS {
    bytes32 constant MINT_SIG = keccak256("mint(address,uint256)");

    constructor(address checkpointManager, address fxRoot) FxBaseRootTunnelUDS(checkpointManager, fxRoot) {}

    /* ------------- external ------------- */

    function lock(address to, uint256 amount) external virtual {
        _burn(msg.sender, amount);

        _sendMessageToChild(abi.encode(MINT_SIG, to, amount));
    }

    function unlock(bytes calldata proofData) external virtual {
        bytes memory message = _validateAndExtractMessage(proofData);

        (bytes32 sig, address to, uint256 amount) = abi.decode(message, (bytes32, address, uint256));

        if (sig != MINT_SIG) revert InvalidSignature();

        _mint(to, amount);
    }
}
