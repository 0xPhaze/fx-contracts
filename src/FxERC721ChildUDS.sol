// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS, s as erc721DS} from "UDS/tokens/ERC721UDS.sol";

import {FxBaseChildTunnelUDS} from "./fx-portal/FxBaseChildTunnelUDS.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_FX_ERC721_CHILD = keccak256("diamond.storage.fx.erc721.child");

function s() pure returns (FxERC721ChildDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_FX_ERC721_CHILD;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

struct FxERC721ChildDS {
    // L1 owner; not really used other than for display
    mapping(uint256 => address) rootOwnerOf;
}

// ------------- error

error Disabled();
error CallerNotOwner();
error InvalidSignature();

abstract contract FxERC721ChildUDS is ERC721UDS, FxBaseChildTunnelUDS {
    bytes32 constant REGISTER_SIG = keccak256("registerIds(address,uint256[])");
    bytes32 constant DEREGISTER_SIG = keccak256("deregisterIds(uint256[])");

    event StateDesync(address oldOwner, address newOwner, uint256 id);

    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    /* ------------- init ------------- */

    function init() public virtual override initializer {
        __Ownable_init();
    }

    /* ------------- virtual ------------- */

    function tokenURI(uint256 id) public view virtual override returns (string memory);

    /* ------------- internal ------------- */

    // @note doesn't need to validate sender, since this already happens in FxBase
    function _processMessageFromRoot(
        uint256,
        address,
        bytes calldata message
    ) internal virtual override {
        (bytes32 sig, bytes memory data) = abi.decode(message, (bytes32, bytes));

        if (sig == REGISTER_SIG) {
            (address to, uint256[] memory ids) = abi.decode(data, (address, uint256[]));

            mintIds(to, ids);
        } else if (sig == DEREGISTER_SIG) {
            uint256[] memory ids = abi.decode(data, (uint256[]));

            burnIds(ids);
        } else revert InvalidSignature();
    }

    // @note does not validate owner
    function _sendToRoot(address from, uint256[] calldata ids) internal virtual {
        for (uint256 i; i < ids.length; ++i) {
            if (from != ownerOf(ids[i])) revert CallerNotOwner();

            _burn(ids[i]);
        }

        _sendMessageToRoot(abi.encode(REGISTER_SIG, abi.encode(ids)));
    }

    /* ------------- private ------------- */

    function mintIds(address to, uint256[] memory ids) private {
        uint256 length = ids.length;

        for (uint256 i; i < length; ++i) {
            uint256 id = ids[i];
            address owner = erc721DS().ownerOf[id];

            // this should normally never happen,
            // because unstaking on L1 should
            // send message to burn first
            // or require proof of burn on L2
            if (owner != address(0)) {
                emit StateDesync(owner, to, id);

                _burn(id); // burn from current owner
            }

            _mint(to, id);

            s().rootOwnerOf[id] = to;
        }
    }

    function burnIds(uint256[] memory ids) private {
        uint256 length = ids.length;

        for (uint256 i; i < length; ++i) {
            uint256 id = ids[i];
            address owner = erc721DS().ownerOf[ids[i]];

            // triggering burn event over bridge
            // should normally never happen
            if (owner == address(0)) {
                emit StateDesync(address(0), address(0), id);
            } else {
                _burn(id);
            }

            s().rootOwnerOf[id] = address(0);
        }
    }
}
