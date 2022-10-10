// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {FxBaseChildTunnel} from "./base/FxBaseChildTunnel.sol";
import {MINT_ERC20_SELECTOR} from "./FxERC20UDSRoot.sol";

error InvalidSelector();

/// @title ERC20 Child
/// @author phaze (https://github.com/0xPhaze/fx-contracts)
abstract contract FxERC20UDSChild is FxBaseChildTunnel, ERC20UDS {
    constructor(address fxChild) FxBaseChildTunnel(fxChild) {}

    /* ------------- virtual ------------- */

    function _authorizeTunnelController() internal virtual override;

    /* ------------- external ------------- */

    function lock(address to, uint256 amount) external virtual {
        _burn(msg.sender, amount);

        _sendMessageToRoot(abi.encodeWithSelector(MINT_ERC20_SELECTOR, to, amount));
    }

    /* ------------- internal ------------- */

    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal override {
        bytes4 selector = bytes4(message);

        (address to, uint256 amount) = abi.decode(message[4:], (address, uint256));

        if (selector != MINT_ERC20_SELECTOR) revert InvalidSelector();

        _mint(to, amount);
    }
}
