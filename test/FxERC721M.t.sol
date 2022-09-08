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
    address alice = makeAddr("alice");
    address tester = address(this);

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

        vm.label(address(token), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
        vm.label(address(this), "tester");
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
        token.mint(tester, 1);
        token.mint(tester, 3);
        token.mint(tester, 2);

        uint256[] memory ids = [3, 1, 4].toMemory();

        token.lockFrom(tester, ids);

        assertEq(token.balanceOf(tester), 6);
        assertEq(token.numMinted(tester), 6);

        assertEq(token.ownerOf(1), address(token));
        assertEq(token.ownerOf(2), address(tester));
        assertEq(token.ownerOf(3), address(token));
        assertEq(token.ownerOf(4), address(token));
        assertEq(token.ownerOf(5), address(tester));

        assertEq(token.trueOwnerOf(1), tester);
        assertEq(token.trueOwnerOf(2), tester);
        assertEq(token.trueOwnerOf(3), tester);
        assertEq(token.trueOwnerOf(4), tester);
        assertEq(token.trueOwnerOf(5), tester);

        assertIdsRegisteredWithChild(tester, ids);

        token.unlockFrom(tester, ids);

        assertEq(token.balanceOf(tester), 6);
        assertEq(token.numMinted(tester), 6);

        assertEq(token.ownerOf(1), address(tester));
        assertEq(token.ownerOf(2), address(tester));
        assertEq(token.ownerOf(3), address(tester));
        assertEq(token.ownerOf(4), address(tester));
        assertEq(token.ownerOf(5), address(tester));

        assertEq(child.erc721BalanceOf(tester), 0);
    }

    function test_lockUnlock_revert() public {
        token.mint(alice, 1);
        token.mint(tester, 1);

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.lockFrom(alice, [1].toMemory());

        vm.expectRevert(ERC721MErrors.IncorrectOwner.selector);
        token.lockFrom(tester, [1].toMemory());

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.lockFrom(alice, [1].toMemory());

        vm.prank(alice);
        token.lockFrom(alice, [1].toMemory());

        vm.expectRevert(ERC721MErrors.IncorrectOwner.selector);
        token.unlockFrom(tester, [1].toMemory());

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.unlockFrom(alice, [1].toMemory());

        vm.expectRevert(ERC721MErrors.IncorrectOwner.selector);
        token.lockFrom(tester, [2, 2].toMemory());

        token.lockFrom(tester, [2].toMemory());

        vm.expectRevert(ERC721MErrors.TokenIdUnlocked.selector);
        token.unlockFrom(tester, [2, 2].toMemory());
    }

    function test_mintAndlock() public {
        token.mintAndLock(tester, 5);

        assertEq(token.balanceOf(tester), 5);
        assertEq(token.numMinted(tester), 5);

        assertIdsRegisteredWithChild(tester, 1.range(6));

        for (uint256 i; i < 5; ++i) assertEq(token.ownerOf(i + 1), address(token));
        for (uint256 i; i < 5; ++i) assertEq(token.trueOwnerOf(i + 1), tester);

        uint256[] memory ids = 1.range(1 + 5);

        token.unlockFrom(tester, ids);

        assertIdsRegisteredWithChild(tester, new uint256[](0));

        for (uint256 i; i < 5; ++i) assertEq(token.ownerOf(i + 1), tester);
        for (uint256 i; i < 5; ++i) assertEq(token.trueOwnerOf(i + 1), tester);
    }

    /* ------------- mint() ------------- */

    function test_mint() public {
        token.mint(alice, 1);

        assertEq(token.balanceOf(alice), 1);
        assertEq(token.numMinted(alice), 1);
        assertEq(token.ownerOf(1), alice);
    }

    function test_mintFive() public {
        token.mint(alice, 5);

        assertEq(token.balanceOf(alice), 5);
        assertEq(token.numMinted(alice), 5);
        for (uint256 i; i < 5; i++) assertEq(token.ownerOf(1), alice);
    }

    function test_mint_revert_MintToZeroAddress() public {
        vm.expectRevert(ERC721MErrors.MintToZeroAddress.selector);
        token.mint(address(0), 1);
    }

    /* ------------- approve() ------------- */

    function test_approve() public {
        token.mint(tester, 1);

        token.approve(alice, 1);

        assertEq(token.getApproved(1), alice);
    }

    function test_approve_revert_NonexistentToken() public {
        vm.expectRevert(ERC721MErrors.NonexistentToken.selector);
        token.approve(alice, 1);
    }

    function test_approve_revert_CallerNotOwnerNorApproved() public {
        token.mint(bob, 1);

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.approve(alice, 1);
    }

    function test_setApprovalForAll() public {
        token.setApprovalForAll(alice, true);

        assertTrue(token.isApprovedForAll(tester, alice));
    }

    /* ------------- transfer() ------------- */

    function test_transferFrom() public {
        token.mint(bob, 1);

        vm.prank(bob);
        token.approve(tester, 1);

        token.transferFrom(bob, alice, 1);

        assertEq(token.getApproved(1), address(0));
        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferFromSelf() public {
        token.mint(tester, 1);

        token.transferFrom(tester, alice, 1);

        assertEq(token.getApproved(1), address(0));
        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(tester), 0);
    }

    function test_transferFromApproveAll() public {
        token.mint(bob, 1);

        vm.prank(bob);
        token.setApprovalForAll(tester, true);

        token.transferFrom(bob, alice, 1);

        assertEq(token.getApproved(1), address(0));
        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferFrom_revert_NonexistentToken() public {
        vm.expectRevert(ERC721MErrors.NonexistentToken.selector);
        token.transferFrom(bob, alice, 1);
    }

    function test_transferFrom_revert_TransferFromIncorrectOwner() public {
        token.mint(alice, 1);

        vm.expectRevert(ERC721MErrors.TransferFromIncorrectOwner.selector);
        token.transferFrom(bob, alice, 1);
    }

    function test_transferFrom_revert_TransferToZeroAddress() public {
        token.mint(tester, 1);

        vm.expectRevert(ERC721MErrors.TransferToZeroAddress.selector);
        token.transferFrom(tester, address(0), 1);
    }

    function test_transferFrom_revert_CallerNotOwnerNorApproved() public {
        token.mint(bob, 1);

        vm.expectRevert(ERC721MErrors.CallerNotOwnerNorApproved.selector);
        token.transferFrom(bob, alice, 1);
    }

    /* ------------- fuzz ------------- */

    function test_mint(
        uint256 quantityA,
        uint256 quantityT,
        uint256 quantityB
    ) public {
        quantityA = bound(quantityA, 1, 100);
        quantityB = bound(quantityB, 1, 100);
        quantityT = bound(quantityT, 1, 100);

        token.mint(alice, quantityA);
        token.mint(bob, quantityB);
        token.mint(tester, quantityT);

        for (uint256 i; i < quantityA; ++i) assertEq(token.ownerOf(1 + i), alice);
        for (uint256 i; i < quantityB; ++i) assertEq(token.ownerOf(1 + quantityA + i), bob);
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), tester);

        assertEq(token.balanceOf(bob), quantityB);
        assertEq(token.balanceOf(alice), quantityA);
        assertEq(token.balanceOf(tester), quantityT);

        assertEq(token.numMinted(bob), quantityB);
        assertEq(token.numMinted(alice), quantityA);
        assertEq(token.numMinted(tester), quantityT);

        assertEq(token.getOwnedIds(alice), (1).range(1 + quantityA));
        assertEq(token.getOwnedIds(bob), (1 + quantityA).range(1 + quantityA + quantityB));
        assertEq(token.getOwnedIds(tester), (1 + quantityA + quantityB).range(1 + quantityA + quantityB + quantityT));
    }

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
        token.mint(tester, quantityT);

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
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), tester);

        assertEq(token.balanceOf(bob), quantityB);
        assertIdsRegisteredWithChild(bob, new uint256[](0));

        assertEq(token.getOwnedIds(alice), (1).range(1 + quantityA));
        assertEq(token.getOwnedIds(bob), (1 + quantityA).range(1 + quantityA + quantityB));
        assertEq(token.getOwnedIds(tester), (1 + quantityA + quantityB).range(1 + quantityA + quantityB + quantityT));
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
        token.mint(tester, quantityT);

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
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), tester);

        assertEq(token.getOwnedIds(bob), ids);
        assertIdsRegisteredWithChild(bob, ids.exclusion(unlockIds));

        vm.prank(bob);
        token.unlockFrom(bob, lockedIds);

        for (uint256 i; i < quantityA; ++i) assertEq(token.ownerOf(1 + i), alice);
        for (uint256 i; i < quantityB; ++i) assertEq(token.ownerOf(1 + quantityA + i), bob);
        for (uint256 i; i < quantityT; ++i) assertEq(token.ownerOf(1 + quantityA + quantityB + i), tester);

        assertEq(token.balanceOf(bob), quantityB);
        assertIdsRegisteredWithChild(bob, new uint256[](0));

        assertEq(token.getOwnedIds(alice), (1).range(1 + quantityA));
        assertEq(token.getOwnedIds(bob), (1 + quantityA).range(1 + quantityA + quantityB));
        assertEq(token.getOwnedIds(tester), (1 + quantityA + quantityB).range(1 + quantityA + quantityB + quantityT));
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
        for (uint256 i; i < quantityT; ++i) owners[quantityA + quantityB + i] = tester;

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
