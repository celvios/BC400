// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title Create2Utils
 * @notice Utility library for computing deterministic CREATE2 addresses.
 * @dev Uses the Arachnid Deterministic Deployment Proxy (0x4e59b44847b379578588920cA78FbF26c0B4956C).
 */
library Create2Utils {
    /// @notice Arachnid's deterministic deployment proxy — available on all EVM chains
    address internal constant ARACHNID_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /**
     * @notice Compute the CREATE2 address for a deployment via the Arachnid proxy.
     * @param salt The salt used for deployment.
     * @param creationCode The full creation code (bytecode + constructor args).
     * @return The deterministic address.
     */
    function computeAddress(bytes32 salt, bytes memory creationCode) internal pure returns (address) {
        return computeAddress(salt, creationCode, ARACHNID_PROXY);
    }

    /**
     * @notice Compute the CREATE2 address for any deployer.
     * @param salt The salt.
     * @param creationCode The full creation code (bytecode + constructor args).
     * @param deployer The deployer address.
     * @return The deterministic address.
     */
    function computeAddress(bytes32 salt, bytes memory creationCode, address deployer) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(creationCode)))))
        );
    }
}
