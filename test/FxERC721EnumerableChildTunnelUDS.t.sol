// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/extensions/FxERC721EnumerableChildTunnelUDS.sol";
import {REGISTER_SIG, DEREGISTER_SIG} from "../src/FxERC721ChildTunnelUDS.sol";

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "futils/futils.sol";

contract MockFxERC721EnumerableChild is UUPSUpgrade, FxERC721EnumerableChildTunnelUDS {
    constructor(address fxChild) FxERC721EnumerableChildTunnelUDS(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function _authorizeTunnelController() internal override {}
}

error NonexistentToken();
error TransferFromIncorrectOwner();

contract TestFxERC721ChildTunnelUDS is Test {
    using futils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    MockFxERC721EnumerableChild tunnel;

    function setUp() public {
        MockFxERC721EnumerableChild logic = new MockFxERC721EnumerableChild(bob);

        tunnel = MockFxERC721EnumerableChild(address(new ERC1967Proxy(address(logic), "")));

        tunnel.setFxRootTunnel(bob);
    }

    /* ------------- processMessageFromRoot() ------------- */

    function test_processMessageFromRoot() public {
        uint256[] memory ids = [42, 1337, 33, 88].toMemory();
        uint256[] memory burnIds = [88, 1337].toMemory();

        bytes memory mintMessage = abi.encode(REGISTER_SIG, abi.encode(alice, ids));
        bytes memory burnMessage = abi.encode(DEREGISTER_SIG, abi.encode(burnIds));

        // mint
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, mintMessage);

        assertEq(tunnel.ownerOf(42), alice);
        assertEq(tunnel.ownerOf(33), alice);
        assertEq(tunnel.ownerOf(88), alice);
        assertEq(tunnel.ownerOf(1337), alice);

        assertEq(tunnel.getOwnedIds(alice), ids);

        // burn
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, burnMessage);

        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, burnMessage);

        assertEq(tunnel.ownerOf(42), alice);
        assertEq(tunnel.ownerOf(33), alice);

        assertEq(tunnel.ownerOf(88), address(0));
        assertEq(tunnel.ownerOf(1337), address(0));

        assertEq(tunnel.getOwnedIds(alice), ids.exclusion(burnIds));

        // re-mint
        vm.prank(bob);
        tunnel.processMessageFromRoot(1, bob, mintMessage);

        assertEq(tunnel.ownerOf(42), alice);
        assertEq(tunnel.ownerOf(33), alice);
        assertEq(tunnel.ownerOf(88), alice);
        assertEq(tunnel.ownerOf(1337), alice);
    }

    event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

    function test_processMessageFromRoot_desync() public {
        // bytes memory mintMessage = abi.encode(REGISTER_SIG, abi.encode(alice, [42].toMemory()));
        // bytes memory burnMessage = abi.encode(DEREGISTER_SIG, abi.encode([42].toMemory()));
        // // burn de-sync
        // vm.expectEmit(false, false, false, true);
        // emit StateDesync(address(0), address(0), 42);
        // vm.prank(bob);
        // tunnel.processMessageFromRoot(1, bob, burnMessage);
        // // mint
        // vm.prank(bob);
        // tunnel.processMessageFromRoot(1, bob, mintMessage);
        // // re-mint de-sync
        // vm.expectEmit(false, false, false, true);
        // emit StateDesync(alice, alice, 42);
        // vm.prank(bob);
        // tunnel.processMessageFromRoot(1, bob, mintMessage);
        // assertEq(tunnel.rootOwnerOf(42), alice);
        // assertEq(tunnel.ownerOf(42), alice);
    }
}
