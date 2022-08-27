// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import "futils/futils.sol";

import "../src/base/FxBaseChildTunnelUDS.sol";

contract MockFxBaseChildTunnel is UUPSUpgrade, FxBaseChildTunnelUDS {
    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}

    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata
    ) internal override {}

    function sendMessageToRoot(bytes calldata message) external {
        _sendMessageToRoot(message);
    }
}

contract TestFxBaseChildTunnel is Test {
    using futils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    MockFxBaseChildTunnel proxy;
    MockFxBaseChildTunnel logic;

    function setUp() public {
        logic = new MockFxBaseChildTunnel(bob);

        proxy = MockFxBaseChildTunnel(address(new ERC1967Proxy(address(logic), "")));

        proxy.setFxRootTunnel(alice);
    }

    /* ------------- setUp() ------------- */

    function test_setUp() public {
        assertEq(DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL, keccak256("diamond.storage.fx.base.child.tunnel"));
    }

    /* ------------- sendMessageToRoot() ------------- */

    event MessageSent(bytes message);

    function test_sendMessageToRoot(bytes memory message) public {
        vm.expectEmit(false, false, false, true, address(proxy));
        emit MessageSent(message);

        proxy.sendMessageToRoot(message);
    }

    /* ------------- processMessageFromRoot() ------------- */

    function test_processMessageFromRoot() public {
        vm.prank(bob);
        proxy.processMessageFromRoot(0, alice, "");
    }

    function test_processMessageFromRoot_fail_CallerNotFxChild() public {
        vm.expectRevert(CallerNotFxChild.selector);
        proxy.processMessageFromRoot(0, tester, "");
    }

    function test_processMessageFromRoot_fail_InvalidRootSender() public {
        vm.prank(bob);
        vm.expectRevert(InvalidRootSender.selector);
        proxy.processMessageFromRoot(0, tester, "");
    }
}
