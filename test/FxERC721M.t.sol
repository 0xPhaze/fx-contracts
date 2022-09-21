// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/FxERC721Child.sol" as FxERC721Child;
import "../src/base/FxBaseRootTunnel.sol" as FxBaseRoot;
import "../src/base/FxBaseChildTunnel.sol" as FxBaseChild;

import "ERC721M/ERC721M.sol" as ERC721MErrors;

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {MockFxERC721EnumerableChild, MockFxERC721MRoot} from "./mocks/MockFxERC721.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestERC721M is Test {
    using futils for *;

    address bob = makeAddr("bob");
    address self = address(this);
    address alice = makeAddr("alice");

    address tunnel;

    MockFxERC721MRoot token;
    MockFxERC721EnumerableChild child;

    function setUp() public {
        tunnel = address(new MockFxTunnel());

        address logicToken = address(new MockFxERC721MRoot(address(0), tunnel));
        address logicChild = address(new MockFxERC721EnumerableChild(tunnel));

        token = MockFxERC721MRoot(address(new ERC1967Proxy(logicToken, "")));
        child = MockFxERC721EnumerableChild(address(new ERC1967Proxy(logicChild, "")));

        token.setFxChildTunnel(address(child));
        child.setFxRootTunnel(address(token));

        vm.label(address(this), "self");
        vm.label(address(token), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
    }

    /* ------------- helpers ------------- */

    function assertIdsRegisteredWithChild(address to, uint256[] memory ids) internal {
        uint256[] memory idsUnique = ids.unique();

        uint256 userBalance = child.erc721BalanceOf(to);

        assertEq(userBalance, idsUnique.length);
        assertTrue(idsUnique.isSubset(child.getOwnedIds(to)));

        for (uint256 i; i < userBalance; i++) {
            assertTrue(idsUnique.includes(child.tokenOfOwnerByIndex(to, i)));
        }

        for (uint256 i; i < ids.length; i++) {
            assertEq(child.ownerOf(ids[i]), to);
        }
    }

    /* ------------- lock() ------------- */

    function test_lockUnlock() public {
        token.mint(self, 1);
        token.mint(self, 3);
        token.mint(self, 2);

        uint256[] memory ids = [3, 1, 4].toMemory();

        token.lockFrom(self, ids);

        assertEq(token.balanceOf(self), 6);
        assertEq(token.numMinted(self), 6);

        assertEq(token.ownerOf(1), address(token));
        assertEq(token.ownerOf(2), address(self));
        assertEq(token.ownerOf(3), address(token));
        assertEq(token.ownerOf(4), address(token));
        assertEq(token.ownerOf(5), address(self));

        assertEq(token.trueOwnerOf(1), self);
        assertEq(token.trueOwnerOf(2), self);
        assertEq(token.trueOwnerOf(3), self);
        assertEq(token.trueOwnerOf(4), self);
        assertEq(token.trueOwnerOf(5), self);

        assertIdsRegisteredWithChild(self, ids);

        token.unlockFrom(self, ids);

        assertEq(token.balanceOf(self), 6);
        assertEq(token.numMinted(self), 6);

        assertEq(token.ownerOf(1), address(self));
        assertEq(token.ownerOf(2), address(self));
        assertEq(token.ownerOf(3), address(self));
        assertEq(token.ownerOf(4), address(self));
        assertEq(token.ownerOf(5), address(self));

        assertEq(child.erc721BalanceOf(self), 0);
    }

    function test_lockUnlock_revert() public {
        token.mint(alice, 1);
        token.mint(self, 1);

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.lockFrom(alice, [1].toMemory());

        vm.expectRevert(ERC721MErrors.IncorrectOwner.selector);
        token.lockFrom(self, [1].toMemory());

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.lockFrom(alice, [1].toMemory());

        vm.prank(alice);
        token.lockFrom(alice, [1].toMemory());

        vm.expectRevert(ERC721MErrors.IncorrectOwner.selector);
        token.unlockFrom(self, [1].toMemory());

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.unlockFrom(alice, [1].toMemory());

        vm.expectRevert(ERC721MErrors.IncorrectOwner.selector);
        token.lockFrom(self, [2, 2].toMemory());

        token.lockFrom(self, [2].toMemory());

        vm.expectRevert(ERC721MErrors.TokenIdUnlocked.selector);
        token.unlockFrom(self, [2, 2].toMemory());
    }

    function test_mintAndlock() public {
        token.mintAndLock(self, 5);

        assertEq(token.balanceOf(self), 5);
        assertEq(token.numMinted(self), 5);

        assertIdsRegisteredWithChild(self, 1.range(6));

        for (uint256 i; i < 5; ++i) assertEq(token.ownerOf(i + 1), address(token));
        for (uint256 i; i < 5; ++i) assertEq(token.trueOwnerOf(i + 1), self);

        uint256[] memory ids = 1.range(1 + 5);

        token.unlockFrom(self, ids);

        assertIdsRegisteredWithChild(self, new uint256[](0));

        for (uint256 i; i < 5; ++i) assertEq(token.ownerOf(i + 1), self);
        for (uint256 i; i < 5; ++i) assertEq(token.trueOwnerOf(i + 1), self);
    }

    /* ------------- fuzz ------------- */

    function test_lock(
        uint256 quantityA,
        uint256 quantityT,
        uint256 quantityB,
        uint256 quantityL,
        uint256 seed
    ) public {
        random.seed(seed);

        quantityA = bound(quantityA, 1, 100);
        quantityB = bound(quantityB, 1, 100);
        quantityT = bound(quantityT, 1, 100);

        token.mint(alice, quantityA);
        token.mint(bob, quantityB);
        token.mint(self, quantityT);

        uint256[] memory ids = (1 + quantityA).range(1 + quantityA + quantityB);

        quantityL = bound(quantityL, 0, ids.length);

        uint256[] memory unlockIds = ids.randomSubset(quantityL);
        uint256[] memory lockedIds = ids.exclusion(unlockIds);

        vm.prank(bob);
        token.lockFrom(bob, ids);

        assertEq(token.getOwnedIds(bob), ids);
        assertIdsRegisteredWithChild(bob, ids);

        // unlock `unlockIds`
        vm.prank(bob);
        token.unlockFrom(bob, unlockIds);

        for (uint256 i; i < unlockIds.length; ++i) assertEq(token.ownerOf(unlockIds[i]), bob);
        for (uint256 i; i < lockedIds.length; ++i) assertEq(token.ownerOf(lockedIds[i]), address(token));

        assertEq(token.getOwnedIds(bob), ids);
        assertIdsRegisteredWithChild(bob, ids.exclusion(unlockIds));

        // unlock remaining locked ids
        vm.prank(bob);
        token.unlockFrom(bob, lockedIds);

        for (uint256 i; i < quantityA; ++i) assertEq(token.ownerOf(1 + i), alice);
        for (uint256 i; i < quantityB; ++i) assertEq(token.ownerOf(1 + quantityA + i), bob);
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), self);

        assertEq(token.balanceOf(bob), quantityB);
        assertIdsRegisteredWithChild(bob, new uint256[](0));

        assertEq(token.getOwnedIds(alice), (1).range(1 + quantityA));
        assertEq(token.getOwnedIds(bob), (1 + quantityA).range(1 + quantityA + quantityB));
        assertEq(token.getOwnedIds(self), (1 + quantityA + quantityB).range(1 + quantityA + quantityB + quantityT));
    }

    function test_mintAndLock(
        uint256 quantityA,
        uint256 quantityB,
        uint256 quantityT,
        uint256 quantityL,
        uint256 seed
    ) public {
        random.seed(seed);

        quantityA = bound(quantityA, 1, 100);
        quantityB = bound(quantityB, 1, 100);
        quantityT = bound(quantityT, 1, 100);

        token.mint(alice, quantityA);
        token.mintAndLock(bob, quantityB);
        token.mint(self, quantityT);

        uint256[] memory ids = (1 + quantityA).range(1 + quantityA + quantityB);

        quantityL = bound(quantityL, 0, ids.length);

        uint256[] memory unlockIds = ids.randomSubset(quantityL);
        uint256[] memory lockedIds = ids.exclusion(unlockIds);

        assertEq(token.getOwnedIds(bob), ids);
        assertIdsRegisteredWithChild(bob, ids);

        vm.prank(bob);
        token.unlockFrom(bob, unlockIds);

        for (uint256 i; i < unlockIds.length; ++i) assertEq(token.ownerOf(unlockIds[i]), bob);
        for (uint256 i; i < lockedIds.length; ++i) assertEq(token.ownerOf(lockedIds[i]), address(token));

        for (uint256 i; i < quantityA; ++i) assertEq(token.ownerOf(1 + i), alice);
        for (uint256 i; i < quantityB; ++i) assertEq(token.trueOwnerOf(1 + quantityA + i), bob);
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), self);

        assertEq(token.getOwnedIds(bob), ids);
        assertIdsRegisteredWithChild(bob, ids.exclusion(unlockIds));

        vm.prank(bob);
        token.unlockFrom(bob, lockedIds);

        for (uint256 i; i < quantityA; ++i) assertEq(token.ownerOf(1 + i), alice);
        for (uint256 i; i < quantityB; ++i) assertEq(token.ownerOf(1 + quantityA + i), bob);
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), self);

        assertEq(token.balanceOf(bob), quantityB);
        assertIdsRegisteredWithChild(bob, new uint256[](0));

        assertEq(token.getOwnedIds(alice), (1).range(1 + quantityA));
        assertEq(token.getOwnedIds(bob), (1 + quantityA).range(1 + quantityA + quantityB));
        assertEq(token.getOwnedIds(self), (1 + quantityA + quantityB).range(1 + quantityA + quantityB + quantityT));
    }

    function test_transferFrom(
        uint256 quantityA,
        uint256 quantityB,
        uint256 quantityT,
        uint256 quantityL,
        uint256 n,
        uint256 seed
    ) public {
        random.seed(seed);

        n = bound(n, 1, 100);

        test_mintAndLock(quantityA, quantityB, quantityT, quantityL, seed);

        quantityA = bound(quantityA, 1, 100);
        quantityB = bound(quantityB, 1, 100);
        quantityT = bound(quantityT, 1, 100);

        uint256 sum = quantityT + quantityA + quantityB;

        address[] memory owners = new address[](sum);

        for (uint256 i; i < quantityA; ++i) owners[i] = alice;
        for (uint256 i; i < quantityB; ++i) owners[quantityA + i] = bob;
        for (uint256 i; i < quantityT; ++i) owners[quantityA + quantityB + i] = self;

        for (uint256 i; i < n; ++i) {
            uint256 id = random.next(sum);

            address oldOwner = owners[id];
            address newOwner = random.nextAddress();

            vm.prank(oldOwner);
            token.transferFrom(oldOwner, newOwner, 1 + id);

            owners[id] = newOwner;

            uint256[] memory foundIds = owners.filterIndices(newOwner);
            for (uint256 j; j < foundIds.length; j++) ++foundIds[j];

            assertEq(foundIds, token.getOwnedIds(newOwner));
        }
    }
}
