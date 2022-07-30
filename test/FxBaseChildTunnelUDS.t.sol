// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";

// import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";
// import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";

// import "ArrayUtils/ArrayUtils.sol";

// import "../child/FxBaseChildTunnelUDS.sol";

// contract MockFxBaseChildTunnel is UUPSUpgradeV(1), FxBaseChildTunnelUDS {
//     constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

//     function _authorizeUpgrade() internal override {}

//     function _processMessageFromRoot(
//         uint256,
//         address,
//         bytes calldata
//     ) internal override {}
// }

// error Disabled();
// error NonexistentToken();

// contract TestFxBaseChildTunnel is Test {
//     using ArrayUtils for *;

//     address bob = address(0xb0b);
//     address alice = address(0xbabe);
//     address tester = address(this);

//     MockFxBaseChildTunnel proxy;
//     MockFxBaseChildTunnel logic;

//     function setUp() public {
//         logic = new MockFxBaseChildTunnel(bob);
//         proxy = MockFxBaseChildTunnel(
//             address(new ERC1967Proxy(address(logic), ""))
//         );
//     }

//     /* ------------- processMessageFromRoot() ------------- */

//     function test_processMessageFromRoot() public {
//         vm.expectRevert(CallerNotFxChild.selector);
//         proxy.processMessageFromRoot(0, tester, "");

//         vm.prank(bob);
//         vm.expectRevert(InvalidRootSender.selector);
//         proxy.processMessageFromRoot(0, tester, "");

//         proxy.setFxRootTunnel(alice);

//         vm.prank(bob);
//         proxy.processMessageFromRoot(0, alice, "");
//     }
// }
