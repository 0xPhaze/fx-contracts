// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {FxBaseChildTunnelUDS} from "./base/FxBaseChildTunnelUDS.sol";

error InvalidSignature();

abstract contract FxERC20ChildUDS is FxBaseChildTunnelUDS, ERC20UDS {
    bytes32 constant MINT_SIG = keccak256("mint(address,uint256)");

    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    /* ------------- external ------------- */

    function lock(address to, uint256 amount) external virtual {
        _burn(msg.sender, amount);

        _sendMessageToRoot(abi.encode(MINT_SIG, to, amount));
    }

    /* ------------- internal ------------- */

    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal override {
        (bytes32 sig, address to, uint256 amount) = abi.decode(message, (bytes32, address, uint256));

        if (sig != MINT_SIG) revert InvalidSignature();

        _mint(to, amount);
    }
}
