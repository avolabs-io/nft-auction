// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @dev Utility contract for managing multiple allow lists under by the same
 * 4-parameter merkle root.
 *
 * Two keys are used to nest each allow list mint count.
 */
contract MerkleFourParams {
    bytes32 public merkleRoot; // merkle root governing all allow lists

    /**
     * @dev store the allow list mints per address, per two keys
     *  we map: (address => (key1 => (key2 => minted)))
     */
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        private _allowListMinted;

    bool internal _allowListActive = false;

    /**************************************************************************
     * CUSTOM ERRORS
     */

    /// Attempted access while allow list is active
    error AllowListIsActive();

    /// Attempted access to inactive presale
    error AllowListIsNotActive();

    /// Exceeds allow list quota
    error ExceedsAllowListQuota();

    /// Merkle proof and user do not resolve to merkleRoot
    error NotOnAllowList();

    /**************************************************************************
     * EVENTS
     */

    /**
     * @dev emitted when an account has claimed some tokens
     * @param account address of the claimer
     * @param key1 first key to the allow list
     * @param key2 second key to the allow list
     * @param amount number of tokens claimed in this transaction 
     */
    event Claimed(
        address indexed account,
        uint256 indexed key1,
        uint256 indexed key2,
        uint256 amount
    );

    /**
     * @dev emitted when the merkle root changes
     * @param merkleRoot new merkle root
     */
    event MerkleRootChanged(bytes32 merkleRoot);

    /**
     * @dev reverts when allow list is not active
     */
    modifier isAllowListActive() virtual {
        if (!_allowListActive) revert AllowListIsNotActive();
        _;
    }

    /**
     * @dev throws when number of tokens exceeds total token quota, for a
     *  given 2-key combination.
     * @param to user address to query
     * @param numberOfTokens check if this many tokens are available
     * @param tokenQuota the user's initial token allowance
     * @param key1 first key to the allow list
     * @param key2 second key to the allow list
     */
    modifier tokensAvailable(
        address to,
        uint256 numberOfTokens,
        uint256 tokenQuota,
        uint256 key1,
        uint256 key2
    ) virtual {
        uint256 claimed = _allowListMinted[to][key1][key2];
        if (claimed + numberOfTokens > tokenQuota) {
            revert ExceedsAllowListQuota();
        }
        _;
    }

    /**
     * @dev throws when parameters sent by claimer are incorrect
     * @param claimer the claimer's address
     * @param tokenQuota initial token allowance for claimer
     * @param key1 first key to the allow list
     * @param key2 second key to the allow list
     * @param proof merkle proof
     */
    modifier ableToClaim(
        address claimer,
        uint256 tokenQuota,
        uint256 key1,
        uint256 key2,
        bytes32[] memory proof
    ) virtual {
        if (!onAllowList(claimer, tokenQuota, key1, key2, proof)) {
            revert NotOnAllowList();
        }
        _;
    }

    /**
     * @dev sets the state of the allow list
     */
    function _setAllowListActive(bool allowListActive_) internal virtual {
        _allowListActive = allowListActive_;
    }

    /**
     * @dev sets the merkle root
     */
    function _setAllowList(bytes32 merkleRoot_) internal virtual {
        merkleRoot = merkleRoot_;

        emit MerkleRootChanged(merkleRoot);
    }

    /**
     * @dev gets the number of tokens minted by an address for given keys
     * @param from the address to query
     * @param key1 first key to the allow list
     * @param key2 second key to the allow list
     * @return minted the number of items minted by the address
     */
    function getAllowListMinted(
        address from,
        uint256 key1,
        uint256 key2
    ) public view virtual returns (uint256) {
        return _allowListMinted[from][key1][key2];
    }

    /**
     * @dev adds the number of tokens to an address's total for given keys
     * @param to the address to increment mints against
     * @param key1 first key to the allow list
     * @param key2 second key to the allow list
     * @param numberOfTokens the number of mints to increment
     */
    function _setAllowListMinted(
        address to,
        uint256 key1,
        uint256 key2,
        uint256 numberOfTokens
    ) internal virtual {
        _allowListMinted[to][key1][key2] += numberOfTokens;

        emit Claimed(to, key1, key2, numberOfTokens);
    }

    /**
     * @dev checks if the claimer has a valid proof
     * @param claimer the claimer's address
     * @param tokenQuota initial allow list quota for claimer
     * @param key1 first key to the allow list
     * @param key2 second key to the allow list
     * @return valid true if the claimer has a valid proof for these arguments
     */
    function onAllowList(
        address claimer,
        uint256 tokenQuota,
        uint256 key1,
        uint256 key2,
        bytes32[] memory proof
    ) public view returns (bool) {
        bytes32 leaf = keccak256(
            abi.encodePacked(claimer, tokenQuota, key1, key2)
        );
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }
}
