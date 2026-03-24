import * as dotenv from "dotenv";
dotenv.config();

/**
 * @notice Chain configuration interface.
 * @dev All values loaded from environment variables — never hardcoded.
 */
export interface ChainConfig {
    chainId: number;
    name: string;
    rpcUrl: string;
    explorerUrl: string;
    nativeToken: string;
    layerZeroEid: number;
    layerZeroEndpoint: string;
}

/**
 * @notice Validates that a required environment variable is set.
 * @param key The environment variable name
 * @returns The value
 * @throws If the variable is not set
 */
function requireEnv(key: string): string {
    const value = process.env[key];
    if (!value) {
        throw new Error(`Missing required environment variable: ${key}`);
    }
    return value;
}

/**
 * @notice Returns a numeric environment variable.
 * @param key The environment variable name
 * @returns The parsed integer
 */
function requireEnvInt(key: string): number {
    const raw = requireEnv(key);
    const parsed = parseInt(raw, 10);
    if (isNaN(parsed)) {
        throw new Error(`Environment variable ${key} is not a valid integer: ${raw}`);
    }
    return parsed;
}

/**
 * @notice All supported chain configurations.
 * @dev Values sourced from .env — see .env.example for required variables.
 */
export const chains: Record<string, ChainConfig> = {
    bsc: {
        chainId: requireEnvInt("BSC_CHAIN_ID"),
        name: "BNB Chain",
        rpcUrl: requireEnv("BSC_RPC_URL"),
        explorerUrl: requireEnv("BSC_EXPLORER_URL"),
        nativeToken: "BNB",
        layerZeroEid: requireEnvInt("BSC_LZ_EID"),
        layerZeroEndpoint: requireEnv("BSC_LZ_ENDPOINT"),
    },
    ethereum: {
        chainId: requireEnvInt("ETH_CHAIN_ID"),
        name: "Ethereum",
        rpcUrl: requireEnv("ETH_RPC_URL"),
        explorerUrl: requireEnv("ETH_EXPLORER_URL"),
        nativeToken: "ETH",
        layerZeroEid: requireEnvInt("ETH_LZ_EID"),
        layerZeroEndpoint: requireEnv("ETH_LZ_ENDPOINT"),
    },
    base: {
        chainId: requireEnvInt("BASE_CHAIN_ID"),
        name: "Base",
        rpcUrl: requireEnv("BASE_RPC_URL"),
        explorerUrl: requireEnv("BASE_EXPLORER_URL"),
        nativeToken: "ETH",
        layerZeroEid: requireEnvInt("BASE_LZ_EID"),
        layerZeroEndpoint: requireEnv("BASE_LZ_ENDPOINT"),
    },
    sonic: {
        chainId: requireEnvInt("SONIC_CHAIN_ID"),
        name: "Sonic",
        rpcUrl: requireEnv("SONIC_RPC_URL"),
        explorerUrl: requireEnv("SONIC_EXPLORER_URL"),
        nativeToken: "S",
        layerZeroEid: requireEnvInt("SONIC_LZ_EID"),
        layerZeroEndpoint: requireEnv("SONIC_LZ_ENDPOINT"),
    },
    polygon: {
        chainId: requireEnvInt("POLYGON_CHAIN_ID"),
        name: "Polygon",
        rpcUrl: requireEnv("POLYGON_RPC_URL"),
        explorerUrl: requireEnv("POLYGON_EXPLORER_URL"),
        nativeToken: "POL",
        layerZeroEid: requireEnvInt("POLYGON_LZ_EID"),
        layerZeroEndpoint: requireEnv("POLYGON_LZ_ENDPOINT"),
    },
};

/// @notice The canonical chain where tax and LP liquidity live
export const CANONICAL_CHAIN = "bsc";

/// @notice All chain keys for iteration
export const ALL_CHAINS = Object.keys(chains);
