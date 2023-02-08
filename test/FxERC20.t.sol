// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {MockFxERC20UDSChild, MockFxERC20UDSRoot, MockFxERC20RelayRoot} from "./mocks/MockFxERC20.sol";
import {MINT_ERC20_SELECTOR} from "src/FxERC20UDSRoot.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

interface MintFn {
    function mintERC20Tokens(address, uint256) external;
}

contract TestFxERC20 is Test {
    using futils for *;

    address bob = makeAddr("bob");
    address self = address(this);
    address alice = makeAddr("alice");

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

        vm.label(address(this), "self");
        vm.label(address(root), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
    }

    function test_setUp() public {
        assertEq(MINT_ERC20_SELECTOR, MintFn.mintERC20Tokens.selector);
    }

    /* ------------- lock() ------------- */

    function test_lock(uint256 amountIn, uint256 amountOut) public {
        amountOut = bound(amountOut, 0, amountIn);

        root.mint(self, amountIn);
        root.lock(self, amountOut);

        assertEq(root.balanceOf(self), amountIn - amountOut);
        assertEq(child.balanceOf(self), amountOut);
    }

    function test_lock_revert_arithmeticError() public {
        root.mint(self, 100e18);

        vm.expectRevert(stdError.arithmeticError);

        root.lock(self, 200e18);
    }
}

contract TestFxERC20Relay is Test {
    using futils for *;

    address bob = makeAddr("bob");
    address self = address(this);
    address alice = makeAddr("alice");

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

        vm.label(address(this), "self");
        vm.label(address(relay), "Relay");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
    }

    /* ------------- lock() ------------- */

    function test_lock(uint256 amountIn, uint256 amountOut) public {
        amountOut = bound(amountOut, 0, amountIn);

        token.mint(self, amountIn);
        relay.lock(self, amountOut);

        assertEq(token.balanceOf(self), amountIn - amountOut);
        assertEq(child.balanceOf(self), amountOut);
    }

    function test_lock_revert_arithmeticError() public {
        token.mint(self, 100e18);

        vm.expectRevert(stdError.arithmeticError);

        relay.lock(self, 200e18);
    }
}
