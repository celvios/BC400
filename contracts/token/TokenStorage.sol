// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title TokenStorage
 * @notice Storage layout for the upgradeable Token contract.
 * @dev CRITICAL: Never reorder, remove, or change the type of existing storage variables.
 *      Always add new variables at the END, before the __gap.
 *      Reduce __gap size by the number of new slots added.
 *
 * Storage Layout:
 * ---------------------------------------------------------------
 * Slot  | Variable                  | Type
 * ---------------------------------------------------------------
 * 0     | taxWallet                 | address (20 bytes)
 * 0     | taxEnabled                | bool (1 byte, packed with taxWallet)
 * 1     | totalTaxCollected         | uint256
 * 2     | taxBps                    | uint256
 * 3+    | taxExempt mapping         | mapping(address => bool)
 * 4-53  | __gap                     | uint256[50]
 * ---------------------------------------------------------------
 */
abstract contract TokenStorage {
    /// @notice 2% tax in basis points (can be updated by TAX_MANAGER_ROLE)
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Maximum tax rate: 10% hard cap — cannot be exceeded even by admin
    uint256 public constant MAX_TAX_BPS = 1_000;

    /// @notice Wallet that receives the tax from every taxable transfer
    address public taxWallet;

    /// @notice Whether tax collection is currently enabled
    bool public taxEnabled;

    /// @notice Running total of all tax collected (for transparency/analytics)
    uint256 public totalTaxCollected;

    /// @notice Current tax rate in basis points (e.g., 200 = 2%)
    uint256 public taxBps;

    /// @notice Addresses exempt from paying tax (LZ endpoint, migration, LPs, etc.)
    mapping(address => bool) public taxExempt;

    /**
     * @dev Reserved storage gap for future upgrades.
     * @dev When adding new storage variables:
     *      1. Add them ABOVE this gap
     *      2. Reduce the gap size by the number of slots consumed
     *      3. Run the OZ upgrade safety checker before committing
     */
    uint256[50] private __gap;
}
