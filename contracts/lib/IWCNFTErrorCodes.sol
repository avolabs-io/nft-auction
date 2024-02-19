// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/**
 * @dev custom error codes common to many contracts are predefined here
 */
interface IWCNFTErrorCodes {
    /// Exceeds maximum tokens per transaction
    error ExceedsMaximumTokensPerTransaction();

    /// Exceeds maximum supply
    error ExceedsMaximumSupply();

    /// Exceeds maximum reserve supply
    error ExceedsReserveSupply();

    /// Attempted access to inactive public sale
    error PublicSaleIsNotActive();

    /// Failed withdrawal from contract
    error WithdrawFailed();

    /// The wrong ETH value has been sent with a transaction
    error WrongETHValueSent();

    /// The zero address 0x00..000 has been provided as an argument
    error ZeroAddressProvided();

    /// A zero quantity cannot be requested here
    error ZeroQuantityRequested();
}
