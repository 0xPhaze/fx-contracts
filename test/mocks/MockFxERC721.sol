// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {FxERC721Root} from "../../src/FxERC721Root.sol";
import {FxERC721Child} from "../../src/FxERC721Child.sol";
import {FxERC721MRoot} from "../../src/extensions/FxERC721MRoot.sol";
import {FxERC721EnumerableChild} from "../../src/extensions/FxERC721EnumerableChild.sol";

contract MockFxERC721EnumerableChild is UUPSUpgrade, FxERC721EnumerableChild {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC721EnumerableChild(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC721Child is UUPSUpgrade, FxERC721Child {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC721Child(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC721Root is UUPSUpgrade, FxERC721Root {
    constructor(address checkpointManager, address fxRoot) FxERC721Root(checkpointManager, fxRoot) {}

    function registerERC721IdsWithChild(address to, uint256[] calldata ids) public {
        _registerERC721IdsWithChild(to, ids);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC721MRoot is UUPSUpgrade, FxERC721MRoot {
    constructor(address checkpointManager, address fxRoot) FxERC721MRoot("", "", checkpointManager, fxRoot) {}

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }

    function mintAndLock(address to, uint256 quantity) public {
        _mintLockedAndTransmit(to, quantity);
    }

    function lockFrom(address from, uint256[] calldata ids) public {
        _lockAndTransmit(from, ids);
    }

    function unlockFrom(address from, uint256[] calldata ids) public {
        _unlockAndTransmit(from, ids);
    }

    function tokenURI(uint256) external view override returns (string memory uri) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}
