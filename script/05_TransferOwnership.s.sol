// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import { Token } from "../contracts/token/Token.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title 05_TransferOwnership
 * @notice Transfers all roles from deployer to the TimelockController,
 *         then revokes all deployer roles.
 *
 * @dev Final state: deployer has NO roles on any contract.
 *
 * @dev Environment variables required:
 *   DEPLOYER_PRIVATE_KEY — deployer wallet
 *   TOKEN_PROXY          — token proxy address
 *   TIMELOCK_ADDRESS     — timelock controller address (from script 04)
 *
 * @dev Usage:
 *   forge script script/05_TransferOwnership.s.sol --rpc-url $RPC_URL --broadcast
 */
contract TransferOwnership is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenProxy = vm.envAddress("TOKEN_PROXY");
        address timelock = vm.envAddress("TIMELOCK_ADDRESS");

        require(tokenProxy != address(0), "TOKEN_PROXY not set");
        require(timelock != address(0), "TIMELOCK_ADDRESS not set");

        Token token = Token(tokenProxy);
        address deployer = vm.addr(deployerKey);

        console.log("=== Ownership Transfer ===");
        console.log("Chain ID:", block.chainid);
        console.log("Token:", tokenProxy);
        console.log("Timelock:", timelock);
        console.log("Deployer:", deployer);

        // Roles to transfer
        bytes32 defaultAdmin = token.DEFAULT_ADMIN_ROLE();
        bytes32 adminRole = token.ADMIN_ROLE();
        bytes32 upgraderRole = token.UPGRADER_ROLE();
        bytes32 pauserRole = token.PAUSER_ROLE();
        bytes32 taxManagerRole = token.TAX_MANAGER_ROLE();

        vm.startBroadcast(deployerKey);

        // 1. Grant all roles to timelock
        token.grantRole(defaultAdmin, timelock);
        token.grantRole(adminRole, timelock);
        token.grantRole(upgraderRole, timelock);
        token.grantRole(pauserRole, timelock);
        token.grantRole(taxManagerRole, timelock);
        console.log("All roles granted to timelock");

        // 2. Set LZ delegate to timelock
        token.setDelegate(timelock);
        console.log("LZ delegate set to timelock");

        // 3. Revoke all roles from deployer
        // IMPORTANT: Revoke DEFAULT_ADMIN_ROLE last, because it's needed to revoke others
        token.revokeRole(adminRole, deployer);
        token.revokeRole(upgraderRole, deployer);
        token.revokeRole(pauserRole, deployer);
        token.revokeRole(taxManagerRole, deployer);
        token.revokeRole(defaultAdmin, deployer);
        console.log("All roles revoked from deployer");

        vm.stopBroadcast();

        // 4. Verify
        require(!token.hasRole(defaultAdmin, deployer), "Deployer still has DEFAULT_ADMIN_ROLE");
        require(!token.hasRole(adminRole, deployer), "Deployer still has ADMIN_ROLE");
        require(!token.hasRole(upgraderRole, deployer), "Deployer still has UPGRADER_ROLE");
        require(!token.hasRole(pauserRole, deployer), "Deployer still has PAUSER_ROLE");
        require(!token.hasRole(taxManagerRole, deployer), "Deployer still has TAX_MANAGER_ROLE");

        require(token.hasRole(defaultAdmin, timelock), "Timelock missing DEFAULT_ADMIN_ROLE");
        require(token.hasRole(adminRole, timelock), "Timelock missing ADMIN_ROLE");

        console.log("=== Verification Passed ===");
        console.log("Deployer has 0 roles. Timelock has all roles.");
    }
}
