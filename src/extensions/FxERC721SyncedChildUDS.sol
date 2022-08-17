// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
// import {FxERC721ChildTunnelUDS, s as tunnelDS} from "../FxERC721ChildTunnelUDS.sol";

// // ------------- error

// error Disabled();
// error CallerNotOwner();
// error InvalidSignature();

// abstract contract FxERC721SyncedChildUDS is FxERC721ChildTunnelUDS, ERC721UDS {
//     constructor(address fxChild) FxERC721ChildTunnelUDS(fxChild) {}

//     /* ------------- virtual ------------- */

//     function tokenURI(uint256 id) public view virtual override returns (string memory);

//     /* ------------- public ------------- */

//     function ownerOf(uint256 id) public view override returns (address) {
//         return tunnelDS().rootOwnerOf[id];
//     }

//     // TODO won't work
//     function delegateOwnership(address to, uint256 id) public {
//         ERC721UDS.transferFrom(msg.sender, to, id);
//     }

//     function approve(address, uint256) public pure override {
//         revert Disabled();
//     }

//     function setApprovalForAll(address, bool) public pure override {
//         revert Disabled();
//     }

//     function transferFrom(
//         address,
//         address,
//         uint256
//     ) public pure override {
//         revert Disabled();
//     }

//     function safeTransferFrom(
//         address,
//         address,
//         uint256
//     ) public pure override {
//         revert Disabled();
//     }

//     function safeTransferFrom(
//         address,
//         address,
//         uint256,
//         bytes calldata
//     ) public pure override {
//         revert Disabled();
//     }

//     function permit(
//         address,
//         address,
//         uint256,
//         uint8,
//         bytes32,
//         bytes32
//     ) public pure override {
//         revert Disabled();
//     }
// }
