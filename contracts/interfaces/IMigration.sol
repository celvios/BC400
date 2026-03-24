// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IMigration
 * @notice Interface for the migration contract that swaps old tokens for new ones 1:1.
 */
interface IMigration {
    // ============================================================
    //                          ERRORS
    // ============================================================

    /// @notice Thrown when migration is not currently active
    error MigrationNotActive();

    /// @notice Thrown when the migration deadline has passed
    error MigrationDeadlinePassed();

    /// @notice Thrown when trying to recover tokens before the deadline
    error MigrationDeadlineNotReached();

    /// @notice Thrown when migration contract has insufficient new tokens
    error InsufficientNewTokenBalance();

    /// @notice Thrown when attempting to migrate zero tokens
    error ZeroAmount();

    // ============================================================
    //                          EVENTS
    // ============================================================

    /// @notice Emitted when a user migrates their tokens
    /// @param user The address that performed the migration
    /// @param amount The number of tokens migrated
    /// @param timestamp When the migration occurred
    event Migrated(address indexed user, uint256 amount, uint256 timestamp);

    /// @notice Emitted when migration is closed by admin
    /// @param timestamp When migration was closed
    /// @param unclaimedAmount Remaining unclaimed new tokens
    event MigrationClosed(uint256 timestamp, uint256 unclaimedAmount);

    /// @notice Emitted when tokens are recovered after deadline
    /// @param token The token address recovered
    /// @param amount The amount recovered
    event TokensRecovered(address indexed token, uint256 amount);

    // ============================================================
    //                        FUNCTIONS
    // ============================================================

    /// @notice Migrate a specific amount of old tokens to new tokens 1:1
    /// @param amount The amount of old tokens to migrate
    function migrate(uint256 amount) external;

    /// @notice Migrate the caller's entire old token balance
    function migrateAll() external;

    /// @notice Enable or disable migration
    /// @param _active Whether migration should be active
    function setActive(bool _active) external;

    /// @notice Recover tokens sent to this contract after the migration deadline
    /// @param token The token address to recover
    /// @param amount The amount to recover
    function recoverTokens(address token, uint256 amount) external;

    /// @notice Get the time remaining until the migration deadline
    /// @return seconds The number of seconds remaining (0 if deadline passed)
    function getTimeRemaining() external view returns (uint256);
}
