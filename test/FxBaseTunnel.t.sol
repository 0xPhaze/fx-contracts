// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/base/FxBaseRootTunnel.sol" as BaseRoot;
import "../src/base/FxBaseChildTunnel.sol" as BaseChild;

import {MockFxTunnel, MockFxBaseChildTunnel, MockFxBaseRootTunnel} from "./mocks/MockFxTunnel.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestFxBaseTunnel is Test {
    using futils for *;

    event MessageSent(bytes message);
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address tester = address(this);

    address tunnel;

    MockFxBaseRootTunnel root;
    MockFxBaseChildTunnel child;

    function setUp() public {
        tunnel = address(new MockFxTunnel());

        address logicRoot = address(new MockFxBaseRootTunnel(address(0), tunnel));
        address logicChild = address(new MockFxBaseChildTunnel(tunnel));

        root = MockFxBaseRootTunnel(address(new ERC1967Proxy(logicRoot, "")));
        child = MockFxBaseChildTunnel(address(new ERC1967Proxy(logicChild, "")));

        vm.label(address(root), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
        vm.label(address(this), "tester");
    }

    /* ------------- setUp() ------------- */

    function test_setUp() public {
        assertEq(BaseRoot.DIAMOND_STORAGE_FX_BASE_ROOT_TUNNEL, keccak256("diamond.storage.fx.base.root.tunnel"));
        assertEq(BaseChild.DIAMOND_STORAGE_FX_BASE_CHILD_TUNNEL, keccak256("diamond.storage.fx.base.child.tunnel"));
    }

    /* ------------- sendMessageToChild() ------------- */

    function test_sendMessageToChild(bytes calldata message) public {
        root.setFxChildTunnel(address(child));
        child.setFxRootTunnel(address(root));

        vm.expectEmit(true, true, true, true, address(child));
        emit MessageReceived(0, address(root), message);

        root.sendMessageToChild(message);
    }

    /// fxRoot is unset in child
    function test_sendMessageToChild_revert_InvalidRootSender(bytes calldata message) public {
        root.setFxChildTunnel(address(child));

        vm.expectRevert(BaseChild.InvalidRootSender.selector);

        root.sendMessageToChild(message);
    }

    /// fxChild is unset in root
    function test_sendMessageToChild_revert_FxChildUnset() public {
        vm.expectRevert(BaseRoot.FxChildUnset.selector);

        root.sendMessageToChild("abc");
    }

    /* ------------- sendMessageToRoot() ------------- */

    function test_sendMessageToRoot(bytes calldata message) public {
        child.setFxRootTunnel(address(root));

        vm.expectEmit(true, true, true, true, address(child));

        emit MessageSent(message);

        child.sendMessageToRoot(message);
    }

    /* ------------- processMessageFromRoot() ------------- */

    /// test direct call; `rootMessageSender != fxRoot`
    function test_processMessageFromRoot_revert_CallerNotFxChild(
        address msgSender,
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) public {
        vm.prank(msgSender);
        vm.assume(msgSender != tunnel);
        vm.expectRevert(BaseChild.CallerNotFxChild.selector);

        child.processMessageFromRoot(stateId, rootMessageSender, data);
    }

    /// test direct call; `rootMessageSender != fxRoot`
    function test_processMessageFromRoot_revert_InvalidRootSender(
        address fxRoot,
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) public {
        child.setFxRootTunnel(address(fxRoot));

        vm.prank(tunnel);
        vm.assume(fxRoot != rootMessageSender);
        vm.expectRevert(BaseChild.InvalidRootSender.selector);

        child.processMessageFromRoot(stateId, rootMessageSender, data);
    }

    // TODO: add tests for inclusion proof
}
