// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

/**
 * @dev include SUPPORT_ROLE access control
 */
contract WCNFTAccessControl is AccessControl {
    bytes32 public constant SUPPORT_ROLE = keccak256("SUPPORT");
}

/**
 * @dev collect common elements for multiple contracts.
 *  Includes SUPPORT_ROLE access control and ERC2981 on chain royalty info.
 */
contract WCNFTToken is WCNFTAccessControl, Ownable, ERC2981 {
    constructor() {
        // set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SUPPORT_ROLE, msg.sender);
    }

    /***************************************************************************
     * Royalties
     */

    /**
     * @dev See {ERC2981-_setDefaultRoyalty}.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyRole(SUPPORT_ROLE)
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev See {ERC2981-_deleteDefaultRoyalty}.
     */
    function deleteDefaultRoyalty() external onlyRole(SUPPORT_ROLE) {
        _deleteDefaultRoyalty();
    }

    /**
     * @dev See {ERC2981-_setTokenRoyalty}.
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) 
        external 
        onlyRole(SUPPORT_ROLE) 
    {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev See {ERC2981-_resetTokenRoyalty}.
     */
    function resetTokenRoyalty(uint256 tokenId)
        external
        onlyRole(SUPPORT_ROLE)
    {
        _resetTokenRoyalty(tokenId);
    }

    /***************************************************************************
     * Overrides
     */

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
