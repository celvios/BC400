import * as dotenv from "dotenv";
dotenv.config();

/**
 * @notice Deployed contract addresses per chain.
 * @dev Updated after each deployment — loaded from deployment records.
 * @dev Format: chain => { token, migration, multisig, timelock }
 */
export interface ContractAddresses {
    token: string;
    migration?: string; // Only on BSC (canonical chain)
    multisig?: string;
    timelock?: string;
}

/**
 * @notice Deployed contract addresses registry.
 * @dev Populated from deployment records in /deployments/{network}/
 * @dev In production, these are loaded from JSON files, not hardcoded.
 */
export const contracts: Record<string, ContractAddresses> = {
    bsc: {
        token: process.env.BSC_TOKEN_ADDRESS || "",
        migration: process.env.BSC_MIGRATION_ADDRESS || "",
        multisig: process.env.BSC_MULTISIG_ADDRESS || "",
        timelock: process.env.BSC_TIMELOCK_ADDRESS || "",
    },
    ethereum: {
        token: process.env.ETH_TOKEN_ADDRESS || "",
    },
    base: {
        token: process.env.BASE_TOKEN_ADDRESS || "",
    },
    sonic: {
        token: process.env.SONIC_TOKEN_ADDRESS || "",
    },
    polygon: {
        token: process.env.POLYGON_TOKEN_ADDRESS || "",
    },
};
