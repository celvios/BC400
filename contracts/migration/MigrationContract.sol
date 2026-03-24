// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IMigration } from "../interfaces/IMigration.sol";

/**
 * @title MigrationContract
 * @notice Allows holders of the old BSC token to swap 1:1 for the new token.
 *
 * @dev Flow:
 *  1. Admin deploys this contract with old+new token addresses and a deadline
 *  2. Admin deposits new tokens into this contract
 *  3. Admin marks this contract as tax-exempt on the new token
 *  4. Users call migrate(amount) or migrateAll() to swap old→new 1:1
 *  5. After deadline, admin can recover any unclaimed tokens
 *
 * @dev Security:
 *  - ReentrancyGuard on all state-changing functions
 *  - Checks-Effects-Interactions pattern throughout
 *  - SafeERC20 for all token transfers
 *  - This contract MUST be set as taxExempt on the new token to prevent
 *    tax being applied when sending new tokens to users
 */
contract MigrationContract is IMigration, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============================================================
    //                        STATE
    // ============================================================

    /// @notice The old token that users send in
    IERC20 public immutable oldToken;

    /// @notice The new token that users receive
    IERC20 public immutable newToken;

    /// @notice The admin who can toggle migration and recover tokens
    address public admin;

    /// @notice The deadline after which migration ends and recovery is allowed
    uint256 public immutable deadline;

    /// @notice Whether migration is currently active
    bool public active;

    /// @notice Total amount of tokens migrated
    uint256 public totalMigrated;

    /// @notice Per-user migration tracking
    mapping(address => uint256) public userMigrated;

    // ============================================================
    //                        ERRORS
    // ============================================================

    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Thrown when caller is not the admin
    error NotAdmin();

    // ============================================================
    //                      MODIFIERS
    // ============================================================

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    // ============================================================
    //                     CONSTRUCTOR
    // ============================================================

    /**
     * @notice Deploy the migration contract.
     * @param _oldToken The old token address (users send this in).
     * @param _newToken The new token address (users receive this).
     * @param _migrationDurationDays Duration in days (e.g., 90).
     * @param _admin The admin address.
     * @dev After deployment:
     *      1. Transfer new tokens to this contract
     *      2. Call setTaxExempt(address(this), true) on the new token
     *      3. Call setActive(true) to start migration
     */
    constructor(
        address _oldToken,
        address _newToken,
        uint256 _migrationDurationDays,
        address _admin
    ) {
        if (_oldToken == address(0)) revert ZeroAddress();
        if (_newToken == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();

        oldToken = IERC20(_oldToken);
        newToken = IERC20(_newToken);
        admin = _admin;
        deadline = block.timestamp + (_migrationDurationDays * 1 days);
        active = false; // Must be explicitly activated after funding
    }

    // ============================================================
    //                     MIGRATION
    // ============================================================

    /**
     * @inheritdoc IMigration
     * @dev Flow:
     *  1. Check migration is active and before deadline
     *  2. Check this contract has enough new tokens
     *  3. Transfer old tokens FROM user TO this contract
     *  4. Transfer new tokens FROM this contract TO user
     */
    function migrate(uint256 amount) external nonReentrant {
        if (!active) revert MigrationNotActive();
        if (block.timestamp > deadline) revert MigrationDeadlinePassed();
        if (amount == 0) revert ZeroAmount();
        if (newToken.balanceOf(address(this)) < amount) revert InsufficientNewTokenBalance();

        // Effects
        totalMigrated += amount;
        userMigrated[msg.sender] += amount;

        // Interactions — Checks-Effects-Interactions
        oldToken.safeTransferFrom(msg.sender, address(this), amount);
        newToken.safeTransfer(msg.sender, amount);

        emit Migrated(msg.sender, amount, block.timestamp);
    }

    /// @inheritdoc IMigration
    function migrateAll() external nonReentrant {
        uint256 balance = oldToken.balanceOf(msg.sender);
        if (balance == 0) revert ZeroAmount();
        if (!active) revert MigrationNotActive();
        if (block.timestamp > deadline) revert MigrationDeadlinePassed();
        if (newToken.balanceOf(address(this)) < balance) revert InsufficientNewTokenBalance();

        // Effects
        totalMigrated += balance;
        userMigrated[msg.sender] += balance;

        // Interactions
        oldToken.safeTransferFrom(msg.sender, address(this), balance);
        newToken.safeTransfer(msg.sender, balance);

        emit Migrated(msg.sender, balance, block.timestamp);
    }

    // ============================================================
    //                     ADMIN
    // ============================================================

    /// @inheritdoc IMigration
    function setActive(bool _active) external onlyAdmin {
        active = _active;
    }

    /**
     * @inheritdoc IMigration
     * @dev Can only recover tokens after the migration deadline has passed.
     *      This prevents admin from pulling new tokens while migration is live.
     */
    function recoverTokens(address token, uint256 amount) external onlyAdmin {
        if (block.timestamp <= deadline) revert MigrationDeadlineNotReached();
        IERC20(token).safeTransfer(admin, amount);
        emit TokensRecovered(token, amount);
    }

    /**
     * @notice Transfer admin rights to a new address.
     * @param _newAdmin The new admin address.
     */
    function transferAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert ZeroAddress();
        admin = _newAdmin;
    }

    // ============================================================
    //                     VIEWS
    // ============================================================

    /// @inheritdoc IMigration
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }
}
