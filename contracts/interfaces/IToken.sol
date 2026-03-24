// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IToken
 * @notice Interface for the multi-chain token with tax functionality.
 */
interface IToken is IERC20 {
    // ============================================================
    //                          ERRORS
    // ============================================================

    /// @notice Thrown when a zero address is provided where one is not allowed
    error ZeroAddress();

    /// @notice Thrown when the tax BPS exceeds the maximum allowed
    /// @param provided The tax BPS that was attempted
    /// @param max The maximum allowed tax BPS
    error TaxTooHigh(uint256 provided, uint256 max);

    /// @notice Thrown when caller lacks required role
    error NotAuthorized();

    /// @notice Thrown when operation attempted while contract is paused
    error ContractPaused();

    // ============================================================
    //                          EVENTS
    // ============================================================

    /// @notice Emitted when tax is collected during a transfer
    /// @param from The sender of the transfer
    /// @param to The recipient of the transfer
    /// @param amount The tax amount collected
    event TaxCollected(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when the tax wallet is updated
    /// @param oldWallet The previous tax wallet address
    /// @param newWallet The new tax wallet address
    event TaxWalletUpdated(address indexed oldWallet, address indexed newWallet);

    /// @notice Emitted when a tax exemption is updated
    /// @param account The account whose exemption changed
    /// @param exempt Whether the account is now exempt
    event TaxExemptUpdated(address indexed account, bool exempt);

    /// @notice Emitted when tax collection is enabled or disabled
    /// @param enabled Whether tax is now enabled
    event TaxEnabledUpdated(bool enabled);

    /// @notice Emitted when the tax rate is updated
    /// @param oldBps The previous tax rate in BPS
    /// @param newBps The new tax rate in BPS
    event TaxBpsUpdated(uint256 oldBps, uint256 newBps);

    // ============================================================
    //                        FUNCTIONS
    // ============================================================

    /// @notice Set the wallet that receives tax
    /// @param wallet The new tax wallet address
    function setTaxWallet(address wallet) external;

    /// @notice Enable or disable tax collection
    /// @param enabled Whether to enable tax
    function setTaxEnabled(bool enabled) external;

    /// @notice Set tax exemption for an account
    /// @param account The account to update
    /// @param exempt Whether the account should be exempt
    function setTaxExempt(address account, bool exempt) external;

    /// @notice Set the tax rate in basis points
    /// @param bps The new tax rate (must not exceed MAX_TAX_BPS)
    function setTaxBps(uint256 bps) external;

    /// @notice Pause all token transfers
    function pause() external;

    /// @notice Unpause token transfers
    function unpause() external;
}
