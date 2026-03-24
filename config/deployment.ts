import * as dotenv from "dotenv";
dotenv.config();

/**
 * @notice Deployment configuration for CREATE2 deterministic deployments.
 * @dev All values from environment variables — see .env.example.
 */
export interface DeploymentConfig {
    /** Private key for the deployer wallet */
    deployerPrivateKey: string;
    /** Salt for CREATE2 deterministic deployment — NEVER change after first deploy */
    create2Salt: string;
    /** Arachnid Deterministic Deployment Proxy — same on all EVM chains */
    create2Factory: string;
}

/**
 * @notice Arachnid Deterministic Deployment Proxy address.
 * @dev Source: https://github.com/Arachnid/deterministic-deployment-proxy
 * @dev This is the same address on ALL EVM chains.
 */
export const ARACHNID_CREATE2_FACTORY = "0x4e59b44847b379578588920cA78FbF26c0B4956C";

/**
 * @notice Loads and validates the deployment configuration.
 * @returns The validated deployment config
 * @throws If required variables are missing
 */
export function getDeploymentConfig(): DeploymentConfig {
    const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;
    if (!deployerPrivateKey) {
        throw new Error("Missing DEPLOYER_PRIVATE_KEY in environment");
    }

    const create2Salt = process.env.CREATE2_SALT;
    if (!create2Salt) {
        throw new Error("Missing CREATE2_SALT in environment — choose a salt once and never change it");
    }

    return {
        deployerPrivateKey,
        create2Salt,
        create2Factory: ARACHNID_CREATE2_FACTORY,
    };
}
