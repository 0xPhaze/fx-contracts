// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {MINT_ERC20_SIG} from "./FxERC20UDSRoot.sol";
import {FxBaseChildTunnel} from "./base/FxBaseChildTunnel.sol";

error InvalidSignature();

/// @title ERC20 Child
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC20UDSChild is FxBaseChildTunnel, ERC20UDS {
    constructor(address fxChild) FxBaseChildTunnel(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- external ------------- */

    function lock(address to, uint256 amount) external virtual {
        _burn(msg.sender, amount);

        _sendMessageToRoot(abi.encode(MINT_ERC20_SIG, abi.encode(to, amount)));
    }

    /* ------------- internal ------------- */

    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal override {
        (bytes32 sig, bytes memory args) = abi.decode(message, (bytes32, bytes));
        (address to, uint256 amount) = abi.decode(args, (address, uint256));

        if (sig != MINT_ERC20_SIG) revert InvalidSignature();

        _mint(to, amount);
    }
}