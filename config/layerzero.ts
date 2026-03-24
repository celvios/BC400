import * as dotenv from "dotenv";
dotenv.config();

/**
 * @notice LayerZero V2 endpoint addresses per chain.
 * @dev Source: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
 * @dev All major EVM chains use the same EndpointV2 address as of 2025.
 */
export const LZ_ENDPOINTS: Record<string, string> = {
    bsc: process.env.BSC_LZ_ENDPOINT!,
    ethereum: process.env.ETH_LZ_ENDPOINT!,
    base: process.env.BASE_LZ_ENDPOINT!,
    sonic: process.env.SONIC_LZ_ENDPOINT!,
    polygon: process.env.POLYGON_LZ_ENDPOINT!,
};

/**
 * @notice LayerZero V2 Endpoint IDs per chain (mainnet = 30xxx range).
 * @dev Source: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
 */
export const LZ_EIDS: Record<string, number> = {
    bsc: parseInt(process.env.BSC_LZ_EID || "30102"),
    ethereum: parseInt(process.env.ETH_LZ_EID || "30101"),
    base: parseInt(process.env.BASE_LZ_EID || "30184"),
    sonic: parseInt(process.env.SONIC_LZ_EID || "30332"),
    polygon: parseInt(process.env.POLYGON_LZ_EID || "30109"),
};

/**
 * @notice Validates that all LayerZero configuration is present.
 * @throws If any endpoint or EID is missing.
 */
export function validateLayerZeroConfig(): void {
    const requiredKeys = ["bsc", "ethereum", "base", "sonic", "polygon"];

    for (const key of requiredKeys) {
        if (!LZ_ENDPOINTS[key]) {
            throw new Error(`Missing LayerZero endpoint for chain: ${key}`);
        }
        if (!LZ_EIDS[key] || isNaN(LZ_EIDS[key])) {
            throw new Error(`Missing or invalid LayerZero EID for chain: ${key}`);
        }
    }
}
