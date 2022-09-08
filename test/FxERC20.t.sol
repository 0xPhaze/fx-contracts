// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {MockFxERC20UDSChild, MockFxERC20UDSRoot, MockFxERC20RelayRoot} from "./mocks/MockFxERC20.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestFxERC20 is Test {
    using futils for *;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address tester = address(this);

    address tunnel;

    MockERC20 token;

    MockFxERC20UDSRoot root;
    MockFxERC20UDSChild child;

    function setUp() public {
        token = new MockERC20("", "", 18);
        tunnel = address(new MockFxTunnel());

        address logicRoot = address(new MockFxERC20UDSRoot(address(0), tunnel));
        address logicChild = address(new MockFxERC20UDSChild(tunnel));

        root = MockFxERC20UDSRoot(address(new ERC1967Proxy(logicRoot, "")));
        child = MockFxERC20UDSChild(address(new ERC1967Proxy(logicChild, "")));

        root.setFxChildTunnel(address(child));
        child.setFxRootTunnel(address(root));

        vm.label(address(root), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
        vm.label(address(this), "tester");
    }

    /* ------------- lock() ------------- */

    function test_lock(uint256 amountIn, uint256 amountOut) public {
        amountOut = bound(amountOut, 0, amountIn);

        root.mint(tester, amountIn);
        root.lock(tester, amountOut);

        assertEq(root.balanceOf(tester), amountIn - amountOut);
        assertEq(child.balanceOf(tester), amountOut);
    }

    function test_lock_revert_arithmeticError() public {
        root.mint(tester, 100e18);

        vm.expectRevert(stdError.arithmeticError);

        root.lock(tester, 200e18);
    }
}

contract TestFxERC20Relay is Test {
    using futils for *;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address tester = address(this);

    address tunnel;

    MockERC20 token;

    MockFxERC20UDSChild child;
    MockFxERC20RelayRoot relay;

    function setUp() public {
        token = new MockERC20("", "", 18);
        tunnel = address(new MockFxTunnel());

        address logicChild = address(new MockFxERC20UDSChild(tunnel));

        child = MockFxERC20UDSChild(address(new ERC1967Proxy(logicChild, "")));
        relay = new MockFxERC20RelayRoot(address(token), address(0), tunnel);

        child.setFxRootTunnel(address(relay));
        relay.setFxChildTunnel(address(child));

        token.approve(address(relay), type(uint256).max);

        vm.label(address(relay), "Relay");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
        vm.label(address(this), "tester");
    }

    /* ------------- lock() ------------- */

    function test_lock(uint256 amountIn, uint256 amountOut) public {
        amountOut = bound(amountOut, 0, amountIn);

        token.mint(tester, amountIn);
        relay.lock(tester, amountOut);

        assertEq(token.balanceOf(tester), amountIn - amountOut);
        assertEq(child.balanceOf(tester), amountOut);
    }

    function test_lock_revert_arithmeticError() public {
        token.mint(tester, 100e18);

        vm.expectRevert(stdError.arithmeticError);

        relay.lock(tester, 200e18);
    }
}
