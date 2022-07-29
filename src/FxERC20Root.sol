// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {FxBaseRootTunnel} from "./fx-portal/tunnel/FxBaseRootTunnel.sol";

// @note not UDS (FxBaseRoot)
abstract contract FxERC20Root is FxBaseRootTunnel, ERC20UDS {
    // constructor(address _checkpointManager, address _fxRoot) FxBaseRootTunnel(_checkpointManager, _fxRoot) {}

    /* ------------- public ------------- */

    function deposit(address to, uint256 amount) public {
        _burn(msg.sender, amount);

        _sendMessageToChild(abi.encode(to, amount));
    }

    /* ------------- internal ------------- */

    function _processMessageFromChild(bytes memory data) internal override {
        (address to, uint256 amount) = abi.decode(data, (address, uint256));

        _mint(to, amount);
    }
}
