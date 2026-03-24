// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import { MigrationContract } from "../contracts/migration/MigrationContract.sol";
import { Token } from "../contracts/token/Token.sol";

/**
 * @title 02_DeployMigration
 * @notice Deploys MigrationContract on BSC only.
 *
 * @dev Environment variables required:
 *   DEPLOYER_PRIVATE_KEY    — deployer wallet
 *   OLD_TOKEN_ADDRESS       — the old BSC token address
 *   NEW_TOKEN_PROXY         — the new token proxy address (from step 01)
 *   MIGRATION_ADMIN         — admin for the migration contract
 *   MIGRATION_DURATION_DAYS — deadline in days (e.g., 90)
 *   MIGRATION_FUND_AMOUNT   — amount of new tokens to deposit into migration contract
 *
 * @dev Usage:
 *   forge script script/02_DeployMigration.s.sol --rpc-url $BSC_RPC_URL --broadcast --verify
 *
 * @dev Post-deployment:
 *   1. Call token.setTaxExempt(migrationAddress, true) ← done automatically in this script
 *   2. Call migration.setActive(true) ← done automatically
 */
contract DeployMigration is Script {
    function run() external {
        // ── Load environment ──
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address oldToken = vm.envAddress("OLD_TOKEN_ADDRESS");
        address newTokenProxy = vm.envAddress("NEW_TOKEN_PROXY");
        address migAdmin = vm.envAddress("MIGRATION_ADMIN");
        uint256 durationDays = vm.envUint("MIGRATION_DURATION_DAYS");
        uint256 fundAmount = vm.envUint("MIGRATION_FUND_AMOUNT");

        // ── Validate ──
        require(oldToken != address(0), "OLD_TOKEN_ADDRESS not set");
        require(newTokenProxy != address(0), "NEW_TOKEN_PROXY not set");
        require(migAdmin != address(0), "MIGRATION_ADMIN not set");
        require(durationDays > 0, "MIGRATION_DURATION_DAYS must be > 0");

        console.log("=== Migration Deployment (BSC Only) ===");
        console.log("Old Token:", oldToken);
        console.log("New Token:", newTokenProxy);
        console.log("Duration:", durationDays, "days");

        vm.startBroadcast(deployerKey);

        // 1. Deploy migration contract
        MigrationContract migration = new MigrationContract(
            oldToken,
            newTokenProxy,
            durationDays,
            migAdmin
        );
        console.log("Migration deployed at:", address(migration));

        // 2. Set migration contract as tax-exempt on new token
        Token token = Token(newTokenProxy);
        token.setTaxExempt(address(migration), true);
        console.log("Migration set as tax-exempt on new token");

        // 3. Fund migration contract with new tokens (deployer must have them)
        if (fundAmount > 0) {
            token.transfer(address(migration), fundAmount);
            console.log("Funded migration with", fundAmount, "tokens");
        }

        // 4. Activate migration
        migration.setActive(true);
        console.log("Migration activated");

        vm.stopBroadcast();

        // 5. Write deployment record
        string memory json = string(abi.encodePacked(
            '{"address":"', vm.toString(address(migration)),
            '","oldToken":"', vm.toString(oldToken),
            '","newToken":"', vm.toString(newTokenProxy),
            '","deadline":', vm.toString(migration.deadline()),
            ',"chainId":', vm.toString(block.chainid),
            '}'
        ));

        string memory path = string(abi.encodePacked(
            "deployments/", vm.toString(block.chainid), "/migration.json"
        ));
        vm.writeFile(path, json);
        console.log("Deployment record saved to:", path);
    }
}
