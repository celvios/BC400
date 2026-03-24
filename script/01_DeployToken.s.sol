// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Token } from "../contracts/token/Token.sol";
import { Create2Utils } from "../contracts/utils/Create2Utils.sol";

/**
 * @title 01_DeployToken
 * @notice Deploys Token implementation + ERC1967Proxy on any chain.
 *
 * @dev Environment variables required:
 *   DEPLOYER_PRIVATE_KEY  — deployer wallet
 *   LZ_ENDPOINT           — LayerZero EndpointV2 address for this chain
 *   TOKEN_ADMIN            — initial admin (receives all roles + supply)
 *   TAX_WALLET             — wallet that receives tax
 *   TOKEN_NAME             — token name
 *   TOKEN_SYMBOL           — token symbol
 *   TOKEN_SUPPLY           — total supply (in wei)
 *   INITIAL_TAX_BPS        — initial tax bps (e.g., 200 for 2%)
 *
 * @dev Usage:
 *   forge script script/01_DeployToken.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployToken is Script {
    function run() external {
        // ── Load environment ──
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        address tokenAdmin = vm.envAddress("TOKEN_ADMIN");
        address taxWallet = vm.envAddress("TAX_WALLET");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");
        uint256 totalSupply = vm.envUint("TOKEN_SUPPLY");
        uint256 initialTaxBps = vm.envUint("INITIAL_TAX_BPS");

        // ── Validate ──
        require(lzEndpoint != address(0), "LZ_ENDPOINT not set");
        require(tokenAdmin != address(0), "TOKEN_ADMIN not set");
        require(taxWallet != address(0), "TAX_WALLET not set");
        require(totalSupply > 0, "TOKEN_SUPPLY must be > 0");
        require(lzEndpoint.code.length > 0, "LZ endpoint not deployed on this chain");

        console.log("=== Token Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("LZ Endpoint:", lzEndpoint);
        console.log("Admin:", tokenAdmin);
        console.log("Tax Wallet:", taxWallet);

        vm.startBroadcast(deployerKey);

        // 1. Deploy implementation
        Token impl = new Token(lzEndpoint);
        console.log("Implementation deployed at:", address(impl));

        // 2. Encode initializer
        bytes memory initData = abi.encodeCall(
            Token.initialize,
            (tokenAdmin, taxWallet, tokenName, tokenSymbol, totalSupply, initialTaxBps)
        );

        // 3. Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        Token token = Token(address(proxy));

        console.log("Proxy deployed at:", address(proxy));
        console.log("Token name:", token.name());
        console.log("Total supply:", token.totalSupply());
        console.log("Admin balance:", token.balanceOf(tokenAdmin));

        vm.stopBroadcast();

        // 4. Write deployment record
        string memory json = string(abi.encodePacked(
            '{"implementation":"', vm.toString(address(impl)),
            '","proxy":"', vm.toString(address(proxy)),
            '","chainId":', vm.toString(block.chainid),
            ',"timestamp":', vm.toString(block.timestamp),
            '}'
        ));

        string memory path = string(abi.encodePacked(
            "deployments/", vm.toString(block.chainid), "/token.json"
        ));
        vm.writeFile(path, json);
        console.log("Deployment record saved to:", path);
    }
}
