// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {FxERC20UDSRoot} from "../../src/FxERC20UDSRoot.sol";
import {FxERC20UDSChild} from "../../src/FxERC20UDSChild.sol";
import {FxERC20RelayRoot} from "../../src/FxERC20RelayRoot.sol";

contract MockFxERC20UDSChild is UUPSUpgrade, FxERC20UDSChild {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC20UDSChild(fxChild) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC20UDSRoot is UUPSUpgrade, FxERC20UDSRoot {
    constructor(address checkpointManager, address fxRoot) FxERC20UDSRoot(checkpointManager, fxRoot) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    function mintERC20TokensWithChild(address to, uint256 amount) public {
        _mintERC20TokensWithChild(to, amount);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC20RelayRoot is UUPSUpgrade, FxERC20RelayRoot {
    constructor(
        address token,
        address checkpointManager,
        address fxRoot
    ) FxERC20RelayRoot(token, checkpointManager, fxRoot) {}

    function mintERC20TokensWithChild(address to, uint256 amount) public {
        _mintERC20TokensWithChild(to, amount);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}
