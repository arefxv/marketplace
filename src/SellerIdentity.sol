// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721URIStorage} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {Errors} from "./Errors.sol";
import {IERC721} from "@openzeppelin-contracts/interfaces/IERC721.sol";
import {AccessControl, IAccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

contract SellerIdentity is ERC721URIStorage, Ownable, AccessControl, Errors {
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => bool) private s_isVerifiedSeller;

    constructor() ERC721("Verified Seller Token", "VST") Ownable(msg.sender) {
        _grantRole(ADMIN_ROLE, owner());
    }

    function grantAdminRole(address to) external onlyOwner {
        _grantRole(ADMIN_ROLE, to);
    }

    function mintSBT(address seller, string memory sellerInfoURI) external onlyRole(ADMIN_ROLE) {
        if (s_isVerifiedSeller[seller]) {
            revert SellerIdentity__SellerAlreadyVerified();
        }
        uint256 tokenId = uint256(uint160(seller));
        _mint(seller, tokenId);
        _setTokenURI(tokenId, sellerInfoURI);
        s_isVerifiedSeller[seller] = true;
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0)) {
            revert SellerIdentity__SBTsAreNonTransferable();
        }
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function isSellerVerified(address seller) external view returns (bool) {
        return s_isVerifiedSeller[seller];
    }
}
