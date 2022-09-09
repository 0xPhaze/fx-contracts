// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/FxERC721Child.sol" as FxERC721Child;
import "../src/base/FxBaseRootTunnel.sol" as FxBaseRoot;
import "../src/base/FxBaseChildTunnel.sol" as FxBaseChild;

import {MockFxTunnel} from "./mocks/MockFxTunnel.sol";
import {MockFxERC721EnumerableChild, MockFxERC721Root} from "./mocks/MockFxERC721.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "futils/futils.sol";

contract TestFxERC721 is Test {
    using futils for *;

    event MessageSent(bytes message);
    event MessageReceived(uint256 stateId, address rootMessageSender, bytes message);

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address tester = address(this);

    address tunnel;

    MockFxERC721Root root;
    MockFxERC721EnumerableChild child;

    function setUp() public {
        tunnel = address(new MockFxTunnel());

        address logicRoot = address(new MockFxERC721Root(address(0), tunnel));
        address logicChild = address(new MockFxERC721EnumerableChild(tunnel));

        root = MockFxERC721Root(address(new ERC1967Proxy(logicRoot, "")));
        child = MockFxERC721EnumerableChild(address(new ERC1967Proxy(logicChild, "")));

        root.setFxChildTunnel(address(child));
        child.setFxRootTunnel(address(root));

        vm.label(address(root), "Root");
        vm.label(address(child), "Child");
        vm.label(address(tunnel), "Tunnel");
        vm.label(address(this), "tester");
    }

    /* ------------- helpers ------------- */

    function assertIdsRegisteredWithChild(address to, uint256[] memory ids) internal {
        uint256[] memory idsUnique = ids.unique();

        if (to == address(0)) {
            for (uint256 i; i < idsUnique.length; i++) {
                assertEq(child.ownerOf(idsUnique[i]), address(0));
            }

            return;
        }

        uint256 userBalance = child.erc721BalanceOf(to);

        assertEq(userBalance, idsUnique.length);
        assertTrue(idsUnique.isSubset(child.getOwnedIds(to)));

        for (uint256 i; i < userBalance; i++) {
            assertTrue(idsUnique.includes(child.tokenOfOwnerByIndex(to, i)));
        }

        for (uint256 i; i < idsUnique.length; i++) {
            assertEq(child.ownerOf(idsUnique[i]), to);
        }
    }

    /* ------------- registerERC721IdsWithChild() ------------- */

    event StateResync(address oldOwner, address newOwner, uint256 id);

    /// timeline test
    function test_register() public {
        root.registerERC721IdsWithChild(tester, [1, 5, 17].toMemory());

        assertIdsRegisteredWithChild(tester, [1, 5, 17].toMemory());

        root.registerERC721IdsWithChild(tester, [5].toMemory());

        assertIdsRegisteredWithChild(tester, [1, 5, 17].toMemory());

        root.registerERC721IdsWithChild(tester, [8, 21].toMemory());

        assertIdsRegisteredWithChild(tester, [1, 5, 17, 8, 21].toMemory());

        root.registerERC721IdsWithChild(address(0), [22].toMemory());

        assertIdsRegisteredWithChild(tester, [1, 5, 17, 8, 21].toMemory());

        root.registerERC721IdsWithChild(alice, [4].toMemory());

        assertIdsRegisteredWithChild(alice, [4].toMemory());

        root.registerERC721IdsWithChild(address(0), [4].toMemory());

        assertIdsRegisteredWithChild(alice, new uint256[](0));

        root.registerERC721IdsWithChild(alice, [17, 21].toMemory());

        assertIdsRegisteredWithChild(alice, [17, 21].toMemory());
        assertIdsRegisteredWithChild(tester, [5, 1, 8].toMemory());

        root.registerERC721IdsWithChild(address(0), [1, 8].toMemory());

        assertIdsRegisteredWithChild(tester, [5].toMemory());

        root.registerERC721IdsWithChild(address(0), [21, 5, 17].toMemory());

        assertIdsRegisteredWithChild(alice, new uint256[](0));
        assertIdsRegisteredWithChild(tester, new uint256[](0));

        root.registerERC721IdsWithChild(tester, [8, 26].toMemory());

        assertIdsRegisteredWithChild(tester, [8, 26].toMemory());

        root.registerERC721IdsWithChild(tester, [0, 1].toMemory());

        assertIdsRegisteredWithChild(tester, [1, 0, 8, 26].toMemory());

        root.registerERC721IdsWithChild(address(0), [1, 0, 8, 26].toMemory());

        assertIdsRegisteredWithChild(tester, new uint256[](0));
    }

    /// fuzz test; register ids
    function test_registerIdsWithChild(address to, uint256[] calldata ids) public {
        root.registerERC721IdsWithChild(to, ids);

        assertIdsRegisteredWithChild(to, ids);
    }

    // /// fuzz test; first register ids, then deregister some
    function test_deregisterIdsWithChild(
        address to,
        uint256[] calldata registerIds,
        uint256[] calldata deregisterIds
    ) public {
        test_registerIdsWithChild(to, registerIds);

        root.registerERC721IdsWithChild(address(0), deregisterIds);

        uint256[] memory idsRegisteredWithChild = registerIds.unique().exclude(deregisterIds);

        if (to == address(0)) {
            return assertIdsRegisteredWithChild(address(0), idsRegisteredWithChild);
        }

        uint256 userBalance = child.erc721BalanceOf(to);

        assertTrue(idsRegisteredWithChild.isSubset(child.getOwnedIds(to)));
        assertEq(userBalance, idsRegisteredWithChild.length);

        for (uint256 i; i < userBalance; i++) {
            assertTrue(idsRegisteredWithChild.includes(child.tokenOfOwnerByIndex(to, i)));
        }

        for (uint256 i; i < idsRegisteredWithChild.length; i++) {
            assertEq(child.ownerOf(idsRegisteredWithChild[i]), to);
        }

        for (uint256 i; i < deregisterIds.length; i++) {
            assertEq(child.ownerOf(deregisterIds[i]), address(0));
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

    /// test direct call; invalid sig
    function test_processMessageFromRoot_revert_InvalidSignature(bytes32 sig, bytes calldata data) public {
        vm.assume(sig != FxERC721Child.REGISTER_ERC721_IDS_SIG);

        vm.prank(tunnel);
        vm.expectRevert(FxERC721Child.InvalidSignature.selector);

        child.processMessageFromRoot(0, address(root), abi.encode(sig, abi.encode(data)));
    }
}
