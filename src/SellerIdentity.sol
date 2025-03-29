// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721URIStorage} from "@openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {Errors} from "./Errors.sol";
import {IERC721} from "@openzeppelin-contracts/interfaces/IERC721.sol";
import {AccessControl, IAccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/**
 * @title SellerIdentity
 * @author ArefXV https://github.com/arefxv
 * @dev This contract allows the minting of non-transferable Seller Identity Tokens (SBTs)
 *      for verifying sellers on the platform. It extends the ERC721 standard with the URI storage 
 *      capability and adds roles management via AccessControl
 */
contract SellerIdentity is ERC721URIStorage, Ownable, AccessControl, Errors {
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => bool) private s_isVerifiedSeller;

    /**
     * @dev Constructor that initializes the contract with the name "Verified Seller Token" and symbol "VST"
     *      The owner is granted the ADMIN_ROLE
     */
    constructor() ERC721("Verified Seller Token", "VST") Ownable(msg.sender) {
        _grantRole(ADMIN_ROLE, owner());
    }

    /**
     * @dev Grants the ADMIN_ROLE to a specified address
     * @param to The address to which the admin role will be granted
     * @notice Only the contract owner can grant this role
     */
    function grantAdminRole(address to) external onlyOwner {
        _grantRole(ADMIN_ROLE, to);
    }

    /**
     * @dev Mints a Seller Identity Token (SBT) to a specified seller address and associates it with a seller info URI
     *      Only an address with the ADMIN_ROLE can mint SBTs
     * @param seller The address of the seller to whom the token will be minted
     * @param sellerInfoURI The URI containing the seller's information
     */
    function mintSBT(address seller, string memory sellerInfoURI) external onlyRole(ADMIN_ROLE) {
        if (s_isVerifiedSeller[seller]) {
            revert SellerIdentity__SellerAlreadyVerified();
        }
        uint256 tokenId = uint256(uint160(seller));
        _mint(seller, tokenId);
        _setTokenURI(tokenId, sellerInfoURI);
        s_isVerifiedSeller[seller] = true;
    }

    /**
     * @dev Internal function to update the ownership of the token. This function is overridden to prevent 
     *      the transfer of Seller Identity Tokens (SBTs)
     * @param to The address to which the token would be transferred
     * @param tokenId The token ID being updated
     * @param auth The authorization address
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0)) {
            revert SellerIdentity__SBTsAreNonTransferable();
        }
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Checks if a given address supports a particular interface
     * @param interfaceId The interface identifier
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns whether a given seller address has been verified
     * @param seller The address of the seller
     */
    function isSellerVerified(address seller) external view returns (bool) {
        return s_isVerifiedSeller[seller];
    }
}
