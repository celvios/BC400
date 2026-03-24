// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title 04_SetupMultisig
 * @notice Deploys a TimelockController for governance.
 *
 * @dev The Gnosis Safe must be deployed externally (via Safe UI or SDK).
 *      This script deploys only the TimelockController, pointing to the
 *      Gnosis Safe as both proposer and executor.
 *
 * @dev Environment variables required:
 *   DEPLOYER_PRIVATE_KEY    — deployer wallet
 *   MULTISIG_ADDRESS        — pre-deployed Gnosis Safe address
 *   TIMELOCK_DELAY_SECONDS  — minimum timelock delay (e.g., 172800 = 2 days)
 *
 * @dev Usage:
 *   forge script script/04_SetupMultisig.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract SetupMultisig is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        uint256 timelockDelay = vm.envUint("TIMELOCK_DELAY_SECONDS");

        require(multisig != address(0), "MULTISIG_ADDRESS not set");
        require(timelockDelay > 0, "TIMELOCK_DELAY_SECONDS must be > 0");

        console.log("=== Timelock Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Multisig:", multisig);
        console.log("Timelock Delay:", timelockDelay, "seconds");

        vm.startBroadcast(deployerKey);

        // Configure proposers and executors
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;

        address[] memory executors = new address[](1);
        executors[0] = multisig;

        // Deploy TimelockController
        // admin = address(0) makes it self-administered (no extra admin)
        TimelockController timelock = new TimelockController(
            timelockDelay,
            proposers,
            executors,
            address(0) // no additional admin
        );

        console.log("TimelockController deployed at:", address(timelock));

        vm.stopBroadcast();

        // Write deployment record
        string memory json = string(abi.encodePacked(
            '{"timelock":"', vm.toString(address(timelock)),
            '","multisig":"', vm.toString(multisig),
            '","delay":', vm.toString(timelockDelay),
            ',"chainId":', vm.toString(block.chainid),
            '}'
        ));

        string memory path = string(abi.encodePacked(
            "deployments/", vm.toString(block.chainid), "/governance.json"
        ));
        vm.writeFile(path, json);
        console.log("Deployment record saved to:", path);
    }
}
