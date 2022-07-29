// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";
import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";

import "ArrayUtils/ArrayUtils.sol";

import "../child/FxERC721ChildUDS.sol";

contract Logic is UUPSUpgradeV(1), FxERC721ChildUDS {
    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    function _authorizeUpgrade() internal override {}

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}

error NonexistentToken();
error TransferFromIncorrectOwner();

contract TestFxERC721SyncedChildUDS is Test {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    Logic proxy;
    Logic logic;

    function setUp() public {
        logic = new Logic(bob);
        proxy = Logic(address(new ERC1967Proxy(address(logic), "")));

        proxy.setFxRootTunnel(bob);
    }

    /* ------------- Disabled() ------------- */

    function test_disabled() public {
        vm.expectRevert(Disabled.selector);
        proxy.approve(alice, 15);

        vm.expectRevert(Disabled.selector);
        proxy.setApprovalForAll(alice, true);

        vm.expectRevert(Disabled.selector);
        proxy.transferFrom(alice, bob, 15);

        vm.expectRevert(Disabled.selector);
        proxy.safeTransferFrom(alice, bob, 15);

        vm.expectRevert(Disabled.selector);
        proxy.safeTransferFrom(alice, bob, 15, "");

        vm.expectRevert(Disabled.selector);
        proxy.permit(alice, bob, 15, 1, 0x0, 0x0);
    }

    /* ------------- processMessageFromRoot() ------------- */

    function test_processMessageFromRoot() public {
        // mint
        vm.prank(bob);
        proxy.processMessageFromRoot(
            uint256(1),
            bob,
            abi.encode(true, alice, [42].toMemory())
        );

        assertEq(proxy.rootOwnerOf(42), alice);
        assertEq(proxy.ownerOf(42), alice);

        // burn
        vm.prank(bob);
        proxy.processMessageFromRoot(
            uint256(1),
            bob,
            abi.encode(false, alice, [42].toMemory())
        );
        assertEq(proxy.rootOwnerOf(42), address(0));
        vm.expectRevert(NonexistentToken.selector);
        proxy.ownerOf(42);

        // re-mint
        vm.prank(bob);
        proxy.processMessageFromRoot(
            uint256(1),
            bob,
            abi.encode(true, alice, [42].toMemory())
        );
        assertEq(proxy.rootOwnerOf(42), alice);
        assertEq(proxy.ownerOf(42), alice);
    }

    event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

    function test_processMessageFromRoot_desync() public {
        // mint
        vm.prank(bob);
        proxy.processMessageFromRoot(
            uint256(1),
            bob,
            abi.encode(true, alice, [42].toMemory())
        );

        assertEq(proxy.rootOwnerOf(42), alice);
        assertEq(proxy.ownerOf(42), alice);

        // re-mint
        vm.expectEmit(false, false, false, true);
        emit StateDesync(alice, alice, 42);

        vm.prank(bob);
        proxy.processMessageFromRoot(
            uint256(1),
            bob,
            abi.encode(true, alice, [42].toMemory())
        );

        assertEq(proxy.rootOwnerOf(42), alice);
        assertEq(proxy.ownerOf(42), alice);
    }

    /* ------------- delegateOwnership() ------------- */

    function test_delegateOwnership() public {
        // mint for alice
        vm.prank(bob);
        proxy.processMessageFromRoot(
            uint256(1),
            bob,
            abi.encode(true, alice, [42].toMemory())
        );

        vm.expectRevert(CallerNotRootOwnerNorDelegate.selector);
        proxy.delegateOwnership(bob, 42);

        vm.prank(alice);
        proxy.delegateOwnership(bob, 42);

        assertEq(proxy.ownerOf(42), bob);

        vm.prank(bob);
        proxy.delegateOwnership(tester, 42);

        assertEq(proxy.ownerOf(42), tester);

        vm.prank(alice);
        proxy.delegateOwnership(bob, 42);
    }

    // /* ------------- transferOwnership() ------------- */

    // function test_transferOwnership() public {
    //     Logic(proxy).transferOwnership(alice);

    //     assertEq(proxy.owner(), alice);
    // }
}
