// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { MigrationContract } from "../../contracts/migration/MigrationContract.sol";
import { IMigration } from "../../contracts/interfaces/IMigration.sol";

/// @dev Simple mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MigrationTest is Test {
    MigrationContract public migration;
    MockERC20 public oldToken;
    MockERC20 public newToken;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant MIGRATION_DAYS = 90;
    uint256 constant SUPPLY = 1_000_000_000 ether;

    function setUp() public {
        oldToken = new MockERC20("Old Token", "OLD");
        newToken = new MockERC20("New Token", "NEW");

        migration = new MigrationContract(
            address(oldToken),
            address(newToken),
            MIGRATION_DAYS,
            admin
        );

        // Fund migration contract with new tokens
        newToken.mint(address(migration), SUPPLY);

        // Give alice and bob old tokens
        oldToken.mint(alice, 10_000 ether);
        oldToken.mint(bob, 5_000 ether);

        // Activate migration
        vm.prank(admin);
        migration.setActive(true);
    }

    // ============================================================
    //                    DEPLOYMENT
    // ============================================================

    function test_deploy_setsState() public view {
        assertEq(address(migration.oldToken()), address(oldToken));
        assertEq(address(migration.newToken()), address(newToken));
        assertEq(migration.admin(), admin);
        assertTrue(migration.active());
        assertEq(migration.deadline(), block.timestamp + (MIGRATION_DAYS * 1 days));
    }

    function test_deploy_revertsOnZeroOldToken() public {
        vm.expectRevert();
        new MigrationContract(address(0), address(newToken), MIGRATION_DAYS, admin);
    }

    function test_deploy_revertsOnZeroNewToken() public {
        vm.expectRevert();
        new MigrationContract(address(oldToken), address(0), MIGRATION_DAYS, admin);
    }

    function test_deploy_revertsOnZeroAdmin() public {
        vm.expectRevert();
        new MigrationContract(address(oldToken), address(newToken), MIGRATION_DAYS, address(0));
    }

    // ============================================================
    //                    MIGRATE
    // ============================================================

    function test_migrate_swapsOneToOne() public {
        uint256 amount = 1000 ether;

        vm.startPrank(alice);
        oldToken.approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();

        assertEq(oldToken.balanceOf(alice), 10_000 ether - amount);
        assertEq(newToken.balanceOf(alice), amount);
        assertEq(oldToken.balanceOf(address(migration)), amount);
        assertEq(migration.totalMigrated(), amount);
        assertEq(migration.userMigrated(alice), amount);
    }

    function test_migrate_emitsEvent() public {
        uint256 amount = 500 ether;

        vm.startPrank(alice);
        oldToken.approve(address(migration), amount);

        vm.expectEmit(true, false, false, true);
        emit IMigration.Migrated(alice, amount, block.timestamp);

        migration.migrate(amount);
        vm.stopPrank();
    }

    function test_migrate_multipleUsers() public {
        vm.startPrank(alice);
        oldToken.approve(address(migration), 3000 ether);
        migration.migrate(3000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        oldToken.approve(address(migration), 2000 ether);
        migration.migrate(2000 ether);
        vm.stopPrank();

        assertEq(newToken.balanceOf(alice), 3000 ether);
        assertEq(newToken.balanceOf(bob), 2000 ether);
        assertEq(migration.totalMigrated(), 5000 ether);
    }

    function test_migrate_multipleTimes() public {
        vm.startPrank(alice);
        oldToken.approve(address(migration), 10_000 ether);

        migration.migrate(1000 ether);
        migration.migrate(2000 ether);

        vm.stopPrank();

        assertEq(newToken.balanceOf(alice), 3000 ether);
        assertEq(migration.userMigrated(alice), 3000 ether);
    }

    // ============================================================
    //                    MIGRATE ALL
    // ============================================================

    function test_migrateAll_swapsEntireBalance() public {
        vm.startPrank(alice);
        oldToken.approve(address(migration), type(uint256).max);
        migration.migrateAll();
        vm.stopPrank();

        assertEq(oldToken.balanceOf(alice), 0);
        assertEq(newToken.balanceOf(alice), 10_000 ether);
        assertEq(migration.totalMigrated(), 10_000 ether);
    }

    // ============================================================
    //                    REVERTS
    // ============================================================

    function test_migrate_revertsWhenNotActive() public {
        vm.prank(admin);
        migration.setActive(false);

        vm.startPrank(alice);
        oldToken.approve(address(migration), 1000 ether);
        vm.expectRevert(IMigration.MigrationNotActive.selector);
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    function test_migrate_revertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(IMigration.ZeroAmount.selector);
        migration.migrate(0);
    }

    function test_migrateAll_revertsOnZeroBalance() public {
        address carol = makeAddr("carol");
        vm.prank(carol);
        vm.expectRevert(IMigration.ZeroAmount.selector);
        migration.migrateAll();
    }

    function test_migrate_revertsAfterDeadline() public {
        // Warp past deadline
        vm.warp(block.timestamp + (MIGRATION_DAYS * 1 days) + 1);

        vm.startPrank(alice);
        oldToken.approve(address(migration), 1000 ether);
        vm.expectRevert(IMigration.MigrationDeadlinePassed.selector);
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    function test_migrate_revertsOnInsufficientNewTokens() public {
        // Deploy a fresh migration with no new tokens
        MigrationContract emptyMigration = new MigrationContract(
            address(oldToken), address(newToken), MIGRATION_DAYS, admin
        );
        vm.prank(admin);
        emptyMigration.setActive(true);

        vm.startPrank(alice);
        oldToken.approve(address(emptyMigration), 1000 ether);
        vm.expectRevert(IMigration.InsufficientNewTokenBalance.selector);
        emptyMigration.migrate(1000 ether);
        vm.stopPrank();
    }

    // ============================================================
    //                    ADMIN
    // ============================================================

    function test_setActive_onlyAdmin() public {
        vm.prank(alice);
        vm.expectRevert(MigrationContract.NotAdmin.selector);
        migration.setActive(false);
    }

    function test_setActive_adminCanToggle() public {
        vm.prank(admin);
        migration.setActive(false);
        assertFalse(migration.active());

        vm.prank(admin);
        migration.setActive(true);
        assertTrue(migration.active());
    }

    function test_recoverTokens_revertsBeforeDeadline() public {
        vm.prank(admin);
        vm.expectRevert(IMigration.MigrationDeadlineNotReached.selector);
        migration.recoverTokens(address(newToken), 1000 ether);
    }

    function test_recoverTokens_afterDeadline() public {
        // Warp past deadline
        vm.warp(block.timestamp + (MIGRATION_DAYS * 1 days) + 1);

        uint256 remaining = newToken.balanceOf(address(migration));

        vm.prank(admin);
        migration.recoverTokens(address(newToken), remaining);

        assertEq(newToken.balanceOf(admin), remaining);
        assertEq(newToken.balanceOf(address(migration)), 0);
    }

    function test_recoverTokens_emitsEvent() public {
        vm.warp(block.timestamp + (MIGRATION_DAYS * 1 days) + 1);

        vm.expectEmit(true, false, false, true);
        emit IMigration.TokensRecovered(address(newToken), 1000 ether);

        vm.prank(admin);
        migration.recoverTokens(address(newToken), 1000 ether);
    }

    function test_recoverTokens_canRecoverOldTokens() public {
        // First, some users migrate
        vm.startPrank(alice);
        oldToken.approve(address(migration), 5000 ether);
        migration.migrate(5000 ether);
        vm.stopPrank();

        // Warp past deadline
        vm.warp(block.timestamp + (MIGRATION_DAYS * 1 days) + 1);

        // Admin recovers the old tokens
        uint256 oldBalance = oldToken.balanceOf(address(migration));
        vm.prank(admin);
        migration.recoverTokens(address(oldToken), oldBalance);

        assertEq(oldToken.balanceOf(admin), oldBalance);
    }

    function test_recoverTokens_onlyAdmin() public {
        vm.warp(block.timestamp + (MIGRATION_DAYS * 1 days) + 1);

        vm.prank(alice);
        vm.expectRevert(MigrationContract.NotAdmin.selector);
        migration.recoverTokens(address(newToken), 1000 ether);
    }

    function test_transferAdmin() public {
        vm.prank(admin);
        migration.transferAdmin(alice);

        assertEq(migration.admin(), alice);

        // Old admin can no longer act
        vm.prank(admin);
        vm.expectRevert(MigrationContract.NotAdmin.selector);
        migration.setActive(false);

        // New admin can act
        vm.prank(alice);
        migration.setActive(false);
        assertFalse(migration.active());
    }

    function test_transferAdmin_revertsOnZero() public {
        vm.prank(admin);
        vm.expectRevert(MigrationContract.ZeroAddress.selector);
        migration.transferAdmin(address(0));
    }

    // ============================================================
    //                    VIEWS
    // ============================================================

    function test_getTimeRemaining_beforeDeadline() public view {
        uint256 remaining = migration.getTimeRemaining();
        assertEq(remaining, MIGRATION_DAYS * 1 days);
    }

    function test_getTimeRemaining_afterDeadline() public {
        vm.warp(block.timestamp + (MIGRATION_DAYS * 1 days) + 1);
        assertEq(migration.getTimeRemaining(), 0);
    }

    // ============================================================
    //                    FUZZ
    // ============================================================

    function testFuzz_migrate_amount(uint256 amount) public {
        amount = bound(amount, 1, 10_000 ether);

        vm.startPrank(alice);
        oldToken.approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();

        assertEq(newToken.balanceOf(alice), amount);
        assertEq(migration.userMigrated(alice), amount);
    }
}
