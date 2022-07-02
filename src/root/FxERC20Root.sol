// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/AccessControl.sol";

// import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
// import {FxBaseRootTunnel} from "../../../lib/fx-portal/contracts/tunnel/FxBaseRootTunnel.sol";

// abstract contract FxERC20Root is FxBaseRootTunnel, ERC20, AccessControl {
//     event FxWithdrawERC20(address indexed to, uint256 amount);
//     event FxDepositERC20(address indexed from, address indexed to, uint256 amount);

//     bytes32 private constant BRIDGE_AUTHORITY = keccak256("BRIDGE_AUTHORITY");

//     // constructor(address _checkpointManager, address _fxRoot) FxBaseRootTunnel(_checkpointManager, _fxRoot) {}

//     /* ------------- External ------------- */

//     function deposit(uint256 amount) external payable {
//         _deposit(msg.sender, msg.sender, amount);
//     }

//     function deposit(address to, uint256 amount) external payable {
//         _deposit(msg.sender, to, amount);
//     }

//     /* ------------- Restricted ------------- */

//     function depositFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) external payable onlyRole(BRIDGE_AUTHORITY) {
//         _deposit(from, to, amount);
//     }

//     function mintChild(address user, uint256 amount) external payable onlyRole(BRIDGE_AUTHORITY) {
//         _sendMessageToChild(abi.encode(user, amount));

//         emit FxDepositERC20(msg.sender, msg.sender, amount);
//     }

//     /* ------------- Internal ------------- */

//     function _deposit(
//         address from,
//         address to,
//         uint256 amount
//     ) internal {
//         _burn(from, amount);

//         _sendMessageToChild(abi.encode(to, amount));

//         emit FxDepositERC20(from, to, amount);
//     }

//     function _processMessageFromChild(bytes memory data) internal override {
//         (address to, uint256 amount) = abi.decode(data, (address, uint256));

//         _mint(to, amount);

//         emit FxWithdrawERC20(to, amount);
//     }
// }
