// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import { Token } from "../contracts/token/Token.sol";

/**
 * @title 03_ConfigureLayerZero
 * @notice Sets LZ peers on the local chain's token for cross-chain OFT bridging.
 *
 * @dev Must run AFTER token is deployed on ALL chains.
 * @dev Run this script once per chain.
 *
 * @dev Environment variables required:
 *   DEPLOYER_PRIVATE_KEY — deployer/admin wallet
 *   TOKEN_PROXY          — this chain's token proxy address
 *   PEER_EIDS            — comma-separated LZ endpoint IDs (e.g., "30101,30184,30109,30332")
 *   PEER_ADDRESSES       — comma-separated peer token addresses (same order as PEER_EIDS)
 *
 * @dev Usage:
 *   forge script script/03_ConfigureLayerZero.s.sol --rpc-url $RPC_URL --broadcast
 */
contract ConfigureLayerZero is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address tokenProxy = vm.envAddress("TOKEN_PROXY");

        // Parse comma-separated EIDs and addresses
        string memory eidsStr = vm.envString("PEER_EIDS");
        string memory addrsStr = vm.envString("PEER_ADDRESSES");

        console.log("=== LayerZero Peer Configuration ===");
        console.log("Token:", tokenProxy);
        console.log("Chain ID:", block.chainid);

        Token token = Token(tokenProxy);

        vm.startBroadcast(deployerKey);

        // Parse and set each peer
        // Format: PEER_EIDS=30101,30184,30109  PEER_ADDRESSES=0x...,0x...,0x...
        uint32[] memory eids = _parseEids(eidsStr);
        address[] memory addrs = _parseAddresses(addrsStr);

        require(eids.length == addrs.length, "EIDs and addresses count mismatch");
        require(eids.length > 0, "No peers to configure");

        for (uint256 i = 0; i < eids.length; i++) {
            bytes32 peer = bytes32(uint256(uint160(addrs[i])));

            // Idempotent — skip if already set
            if (token.peers(eids[i]) == peer) {
                console.log("Peer already set for EID", eids[i]);
                continue;
            }

            token.setPeer(eids[i], peer);
            console.log("Set peer for EID", eids[i], "->", addrs[i]);
        }

        vm.stopBroadcast();
        console.log("LayerZero peer configuration complete");
    }

    function _parseEids(string memory csv) internal pure returns (uint32[] memory) {
        // Count commas to determine array size
        bytes memory b = bytes(csv);
        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }

        uint32[] memory eids = new uint32[](count);
        uint256 idx = 0;
        uint256 start = 0;

        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == ",") {
                // Extract substring and parse
                bytes memory segment = new bytes(i - start);
                for (uint256 j = start; j < i; j++) {
                    segment[j - start] = b[j];
                }
                eids[idx] = uint32(_parseUint(string(segment)));
                idx++;
                start = i + 1;
            }
        }

        return eids;
    }

    function _parseAddresses(string memory csv) internal pure returns (address[] memory) {
        bytes memory b = bytes(csv);
        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }

        address[] memory addrs = new address[](count);
        uint256 idx = 0;
        uint256 start = 0;

        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == ",") {
                bytes memory segment = new bytes(i - start);
                for (uint256 j = start; j < i; j++) {
                    segment[j - start] = b[j];
                }
                addrs[idx] = _parseAddress(string(segment));
                idx++;
                start = i + 1;
            }
        }

        return addrs;
    }

    function _parseUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid digit");
            result = result * 10 + (uint256(uint8(b[i])) - 48);
        }
        return result;
    }

    function _parseAddress(string memory s) internal pure returns (address) {
        bytes memory b = bytes(s);
        uint256 start = 0;
        if (b.length >= 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X")) {
            start = 2;
        }
        require(b.length - start == 40, "Invalid address length");

        uint160 addr = 0;
        for (uint256 i = start; i < b.length; i++) {
            uint8 digit;
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                digit = uint8(b[i]) - 48;
            } else if (b[i] >= 0x61 && b[i] <= 0x66) {
                digit = uint8(b[i]) - 87;
            } else if (b[i] >= 0x41 && b[i] <= 0x46) {
                digit = uint8(b[i]) - 55;
            } else {
                revert("Invalid hex character");
            }
            addr = addr * 16 + uint160(digit);
        }
        return address(addr);
    }
}
