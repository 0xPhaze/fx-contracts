// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";

// import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
// import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
// import "../src/fx-portal/FxERC721EnumerableChildTunnelUDS.sol";

// import "futils/futils.sol";

// contract MockFxERC721EnumerableChild is UUPSUpgrade, FxERC721EnumerableChildTunnelUDS {
//     constructor(address fxChild) FxERC721EnumerableChildTunnelUDS(fxChild) {
//         init();
//     }
// }

// error NonexistentToken();
// error TransferFromIncorrectOwner();

// contract TestFxERC721ChildTunnelUDS is Test {
//     using futils for *;

//     address bob = address(0xb0b);
//     address alice = address(0xbabe);
//     address tester = address(this);

//     MockFxERC721EnumerableChild proxy;

//     function setUp() public {
//         MockFxERC721EnumerableChild logic = new MockFxERC721EnumerableChild(bob);

//         bytes memory initData = abi.encodePacked(FxERC721EnumerableChildTunnelUDS.init.selector);

//         proxy = MockFxERC721EnumerableChild(address(new ERC1967Proxy(address(logic), initData)));

//         proxy.setFxRootTunnel(bob);
//     }

//     /* ------------- processMessageFromRoot() ------------- */

//     bytes32 constant REGISTER_SIG = keccak256("registerIdsWithChild(address,uint256[])");
//     bytes32 constant DEREGISTER_SIG = keccak256("deregisterIdsWithChild(uint256[])");

//     function test_processMessageFromRoot() public {
//         bytes memory mintMessage = abi.encode(REGISTER_SIG, abi.encode(alice, [42].toMemory()));
//         bytes memory burnMessage = abi.encode(DEREGISTER_SIG, abi.encode([42].toMemory()));

//         // mint
//         vm.prank(bob);
//         proxy.processMessageFromRoot(1, bob, mintMessage);

//         assertEq(proxy.rootOwnerOf(42), alice);
//         assertEq(proxy.ownerOf(42), alice);

//         // burn
//         vm.prank(bob);
//         proxy.processMessageFromRoot(1, bob, burnMessage);

//         assertEq(proxy.rootOwnerOf(42), address(0));

//         vm.expectRevert(NonexistentToken.selector);
//         proxy.ownerOf(42);

//         // re-mint
//         vm.prank(bob);
//         proxy.processMessageFromRoot(1, bob, mintMessage);

//         assertEq(proxy.rootOwnerOf(42), alice);
//         assertEq(proxy.ownerOf(42), alice);
//     }

//     event StateDesync(address oldOwner, address newOwner, uint256 tokenId);

//     function test_processMessageFromRoot_desync() public {
//         bytes memory mintMessage = abi.encode(REGISTER_SIG, abi.encode(alice, [42].toMemory()));
//         bytes memory burnMessage = abi.encode(DEREGISTER_SIG, abi.encode([42].toMemory()));

//         // burn de-sync
//         vm.expectEmit(false, false, false, true);
//         emit StateDesync(address(0), address(0), 42);

//         vm.prank(bob);
//         proxy.processMessageFromRoot(1, bob, burnMessage);

//         // mint
//         vm.prank(bob);
//         proxy.processMessageFromRoot(1, bob, mintMessage);

//         // re-mint de-sync
//         vm.expectEmit(false, false, false, true);
//         emit StateDesync(alice, alice, 42);

//         vm.prank(bob);
//         proxy.processMessageFromRoot(1, bob, mintMessage);

//         assertEq(proxy.rootOwnerOf(42), alice);
//         assertEq(proxy.ownerOf(42), alice);
//     }
// }
