// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/FxERC721sChild.sol" as FxERC721sChild;
import "../src/base/FxBaseRootTunnel.sol" as FxBaseRoot;
import "../src/base/FxBaseChildTunnel.sol" as FxBaseChild;

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {MockFxERC721sEnumerableChild, MockFxERC721sRoot} from "./mocks/MockFxERC721.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestFxERC721s is Test {
    using futils for *;

    event MessageSent(bytes message);
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    address bob = makeAddr("bob");
    address self = address(this);
    address alice = makeAddr("alice");

    address tunnel;

    MockFxERC721sRoot root;
    MockFxERC721sEnumerableChild child;

    function setUp() public {
        tunnel = address(new MockFxTunnel());

        address logicRoot = address(new MockFxERC721sRoot(address(0), tunnel));
        address logicChild = address(new MockFxERC721sEnumerableChild(tunnel));

        root = MockFxERC721sRoot(address(new ERC1967Proxy(logicRoot, "")));
        child = MockFxERC721sEnumerableChild(address(new ERC1967Proxy(logicChild, "")));

        root.setFxChildTunnel(address(child));
        child.setFxRootTunnel(address(root));

        vm.label(address(this), "self");
        vm.label(address(root), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
    }

    /* ------------- helpers ------------- */

    function assertIdsRegisteredWithChild(
        address collection,
        address to,
        uint256[] memory ids
    ) internal {
        uint256[] memory idsUnique = ids.unique();

        if (to == address(0)) {
            for (uint256 i; i < idsUnique.length; i++) {
                assertEq(child.ownerOf(collection, idsUnique[i]), address(0));
            }

            return;
        }

        uint256 userBalance = child.erc721BalanceOf(collection, to);

        assertEq(userBalance, idsUnique.length);
        assertTrue(idsUnique.isSubset(child.getOwnedIds(collection, to)));

        for (uint256 i; i < userBalance; i++) {
            assertTrue(idsUnique.includes(child.tokenOfOwnerByIndex(collection, to, i)));
        }

        for (uint256 i; i < idsUnique.length; i++) {
            assertEq(child.ownerOf(collection, idsUnique[i]), to);
        }
    }

    /* ------------- registerERC721IdsWithChild() ------------- */

    event StateResync(address oldOwner, address newOwner, uint256 id);

    /// journey test
    function test_register() public {
        address collection = address(0x123);

        root.registerERC721IdsWithChild(collection, self, [1, 5, 17].toMemory());

        assertIdsRegisteredWithChild(collection, self, [1, 5, 17].toMemory());

        root.registerERC721IdsWithChild(collection, self, [5].toMemory());

        assertIdsRegisteredWithChild(collection, self, [1, 5, 17].toMemory());

        root.registerERC721IdsWithChild(collection, self, [8, 21].toMemory());

        assertIdsRegisteredWithChild(collection, self, [1, 5, 17, 8, 21].toMemory());

        root.registerERC721IdsWithChild(collection, address(0), [22].toMemory());

        assertIdsRegisteredWithChild(collection, self, [1, 5, 17, 8, 21].toMemory());

        root.registerERC721IdsWithChild(collection, alice, [4].toMemory());

        assertIdsRegisteredWithChild(collection, alice, [4].toMemory());

        root.registerERC721IdsWithChild(collection, address(0), [4].toMemory());

        assertIdsRegisteredWithChild(collection, alice, new uint256[](0));

        root.registerERC721IdsWithChild(collection, alice, [17, 21].toMemory());

        assertIdsRegisteredWithChild(collection, alice, [17, 21].toMemory());
        assertIdsRegisteredWithChild(collection, self, [5, 1, 8].toMemory());

        root.registerERC721IdsWithChild(collection, address(0), [1, 8].toMemory());

        assertIdsRegisteredWithChild(collection, self, [5].toMemory());

        root.registerERC721IdsWithChild(collection, address(0), [21, 5, 17].toMemory());

        assertIdsRegisteredWithChild(collection, alice, new uint256[](0));
        assertIdsRegisteredWithChild(collection, self, new uint256[](0));

        root.registerERC721IdsWithChild(collection, self, [8, 26].toMemory());

        assertIdsRegisteredWithChild(collection, self, [8, 26].toMemory());

        root.registerERC721IdsWithChild(collection, self, [0, 1].toMemory());

        assertIdsRegisteredWithChild(collection, self, [1, 0, 8, 26].toMemory());

        root.registerERC721IdsWithChild(collection, address(0), [1, 0, 8, 26].toMemory());

        assertIdsRegisteredWithChild(collection, self, new uint256[](0));
    }

    /// register ids
    function test_registerIdsWithChild(
        address collection,
        address to,
        uint256[] calldata ids
    ) public {
        root.registerERC721IdsWithChild(collection, to, ids);

        assertIdsRegisteredWithChild(collection, to, ids);
    }

    /// register ids, multiple collections and users
    function test_registerIdsWithChild(
        address collection1,
        address collection2,
        address to1,
        address to2,
        uint256[] calldata ids1,
        uint256[] calldata ids2
    ) public {
        root.registerERC721IdsWithChild(collection1, to1, ids1);
        root.registerERC721IdsWithChild(collection2, to2, ids2);

        if (collection1 == collection2) {
            if (to1 == to2) {
                assertIdsRegisteredWithChild(collection1, to1, ids1.union(ids2).unique());
            } else {
                assertIdsRegisteredWithChild(collection1, to1, ids1.exclude(ids2));
                assertIdsRegisteredWithChild(collection2, to2, ids2);
            }
        } else {
            assertIdsRegisteredWithChild(collection1, to1, ids1);
            assertIdsRegisteredWithChild(collection2, to2, ids2);
        }
    }

    /// first register ids, then deregister some
    function test_deregisterIdsWithChild(
        address collection,
        address to,
        uint256[] calldata registerIds,
        uint256[] calldata deregisterIds
    ) public {
        test_registerIdsWithChild(collection, to, registerIds);

        root.registerERC721IdsWithChild(collection, address(0), deregisterIds);

        uint256[] memory idsRegisteredWithChild = registerIds.unique().exclude(deregisterIds);

        if (to == address(0)) {
            return assertIdsRegisteredWithChild(collection, address(0), idsRegisteredWithChild);
        }

        uint256 userBalance = child.erc721BalanceOf(collection, to);

        assertTrue(idsRegisteredWithChild.isSubset(child.getOwnedIds(collection, to)));
        assertEq(userBalance, idsRegisteredWithChild.length);

        for (uint256 i; i < userBalance; i++) {
            assertTrue(idsRegisteredWithChild.includes(child.tokenOfOwnerByIndex(collection, to, i)));
        }

        for (uint256 i; i < idsRegisteredWithChild.length; i++) {
            assertEq(child.ownerOf(collection, idsRegisteredWithChild[i]), to);
        }

        for (uint256 i; i < deregisterIds.length; i++) {
            assertEq(child.ownerOf(collection, deregisterIds[i]), address(0));
        }
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
        vm.expectRevert(FxBaseChild.CallerNotFxChild.selector);

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
        vm.expectRevert(FxBaseChild.InvalidRootSender.selector);

        child.processMessageFromRoot(stateId, rootMessageSender, data);
    }

    /// test direct call; invalid selector
    function test_processMessageFromRoot_revert_InvalidSelector(bytes4 selector, bytes calldata data) public {
        vm.assume(selector != FxERC721sChild.REGISTER_ERC721s_IDS_SELECTOR);

        vm.prank(tunnel);
        vm.expectRevert(FxERC721sChild.InvalidSelector.selector);

        child.processMessageFromRoot(0, address(root), abi.encodeWithSelector(selector, data));
    }
}
