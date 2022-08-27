// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/FxERC721ChildTunnelUDS.sol";

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "futils/futils.sol";

contract MockFxERC721MChild is UUPSUpgrade, FxERC721ChildTunnelUDS {
    constructor(address fxChild) FxERC721ChildTunnelUDS(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

error NonexistentToken();
error TransferFromIncorrectOwner();

contract TestFxERC721SyncedChildUDS is Test {
    using futils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    MockFxERC721MChild tunnel;

    function setUp() public {
        MockFxERC721MChild logic = new MockFxERC721MChild(bob);

        tunnel = MockFxERC721MChild(address(new ERC1967Proxy(address(logic), "")));

        tunnel.setFxRootTunnel(bob);
    }

    /* ------------- processMessageFromRoot() ------------- */

    function test_processMessageFromRoot() public {
        bytes memory mintMessage = abi.encode(REGISTER_SIG, abi.encode(alice, [42].toMemory()));
        bytes memory burnMessage = abi.encode(DEREGISTER_SIG, abi.encode([42].toMemory()));

        // mint
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, mintMessage);

        assertEq(tunnel.ownerOf(42), alice);

        // burn
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, burnMessage);

        assertEq(tunnel.ownerOf(42), address(0));

        // re-mint
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, mintMessage);

        // assertEq(tunnel.rootOwnerOf(42), alice);
        assertEq(tunnel.ownerOf(42), alice);
    }

    event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

    function test_processMessageFromRoot_desync() public {
        bytes memory mintMessage = abi.encode(REGISTER_SIG, abi.encode(alice, [42].toMemory()));
        bytes memory burnMessage = abi.encode(DEREGISTER_SIG, abi.encode([42].toMemory()));

        // burn de-sync
        vm.expectEmit(false, false, false, true);
        emit StateDesync(address(0), address(0), 42);

        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, burnMessage);

        // mint
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, mintMessage);

        // re-mint de-sync
        vm.expectEmit(false, false, false, true);
        emit StateDesync(alice, alice, 42);

        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, mintMessage);

        // assertEq(tunnel.rootOwnerOf(42), alice);
        assertEq(tunnel.ownerOf(42), alice);
    }
}
