// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Token } from "../contracts/token/Token.sol";

/**
 * @title 01_DeployToken_CREATE2
 * @notice Deploys Token impl + proxy via the Arachnid CREATE2 factory
 *         to produce the SAME address on every chain.
 */
contract DeployTokenCREATE2 is Script {
    address constant FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        bytes32 salt = vm.envBytes32("CREATE2_SALT");

        // Build impl creation code
        bytes memory implCode = abi.encodePacked(
            type(Token).creationCode,
            abi.encode(vm.envAddress("LZ_ENDPOINT"))
        );

        // Predict impl address
        address implAddr = _predict(salt, implCode);

        // Build proxy creation code
        bytes memory initData = abi.encodeCall(
            Token.initialize,
            (
                vm.envAddress("TOKEN_ADMIN"),
                vm.envAddress("TAX_WALLET"),
                vm.envString("TOKEN_NAME"),
                vm.envString("TOKEN_SYMBOL"),
                vm.envUint("TOKEN_SUPPLY"),
                vm.envUint("INITIAL_TAX_BPS")
            )
        );
        bytes memory proxyCode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implAddr, initData)
        );
        bytes32 proxySalt = keccak256(abi.encodePacked(salt, "PROXY"));
        address proxyAddr = _predict(proxySalt, proxyCode);

        console.log("=== CREATE2 Deployment ===");
        console.log("Chain:", block.chainid);
        console.log("Predicted Impl:", implAddr);
        console.log("Predicted Proxy:", proxyAddr);

        vm.startBroadcast(deployerKey);

        // Deploy impl (skip if already deployed)
        if (implAddr.code.length == 0) {
            (bool ok, ) = FACTORY.call(abi.encodePacked(salt, implCode));
            require(ok && implAddr.code.length > 0, "Impl deploy failed");
            console.log("Impl deployed");
        } else {
            console.log("Impl already exists");
        }

        // Deploy proxy (skip if already deployed)
        if (proxyAddr.code.length == 0) {
            (bool ok2, ) = FACTORY.call(abi.encodePacked(proxySalt, proxyCode));
            require(ok2 && proxyAddr.code.length > 0, "Proxy deploy failed");
            console.log("Proxy deployed");
        } else {
            console.log("Proxy already exists");
        }

        vm.stopBroadcast();

        // Verify
        Token t = Token(proxyAddr);
        console.log("Name:", t.name());
        console.log("Supply:", t.totalSupply());

        // Save
        string memory json = string(abi.encodePacked(
            '{"implementation":"', vm.toString(implAddr),
            '","proxy":"', vm.toString(proxyAddr),
            '","chainId":', vm.toString(block.chainid),
            '}'
        ));
        vm.writeFile(
            string(abi.encodePacked("deployments/", vm.toString(block.chainid), "/token.json")),
            json
        );
        console.log("Saved");
    }

    function _predict(bytes32 s, bytes memory code) internal pure returns (address) {
        return address(uint160(uint256(keccak256(
            abi.encodePacked(bytes1(0xff), FACTORY, s, keccak256(code))
        ))));
    }
}
