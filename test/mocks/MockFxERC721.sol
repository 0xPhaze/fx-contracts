// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import {FxERC721Root} from "../../src/FxERC721Root.sol";
import {FxERC721Child} from "../../src/FxERC721Child.sol";
import {FxERC721sRoot} from "../../src/FxERC721sRoot.sol";
import {FxERC721sChild} from "../../src/FxERC721sChild.sol";
import {FxERC721EnumerableChild} from "../../src/extensions/FxERC721EnumerableChild.sol";
import {FxERC721sEnumerableChild} from "../../src/extensions/FxERC721sEnumerableChild.sol";

contract MockFxERC721Child is UUPSUpgrade, FxERC721Child {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC721Child(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC721EnumerableChild is UUPSUpgrade, FxERC721EnumerableChild {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC721EnumerableChild(fxChild) {}

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

contract MockFxERC721sChild is UUPSUpgrade, FxERC721sChild {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC721sChild(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC721sEnumerableChild is UUPSUpgrade, FxERC721sEnumerableChild {
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    constructor(address fxChild) FxERC721sEnumerableChild(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

contract MockFxERC721sRoot is UUPSUpgrade, FxERC721sRoot {
    constructor(address checkpointManager, address fxRoot) FxERC721sRoot(checkpointManager, fxRoot) {}

    function registerERC721IdsWithChild(
        address collection,
        address to,
        uint256[] calldata ids
    ) public {
        _registerERC721IdsWithChild(collection, to, ids);
    }

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}
