// Contract addresses per chain — all from environment variables
// NEVER hardcode addresses

export interface ContractAddresses {
  token: `0x${string}`;
  migration?: `0x${string}`; // Only on BSC
}

export const CONTRACTS: Record<number, ContractAddresses> = {
  // BSC
  56: {
    token: (process.env.NEXT_PUBLIC_BSC_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
    migration: (process.env.NEXT_PUBLIC_BSC_MIGRATION || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  // Ethereum
  1: {
    token: (process.env.NEXT_PUBLIC_ETH_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  // Base
  8453: {
    token: (process.env.NEXT_PUBLIC_BASE_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  // Sonic
  146: {
    token: (process.env.NEXT_PUBLIC_SONIC_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  // Polygon
  137: {
    token: (process.env.NEXT_PUBLIC_POLYGON_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
};

// Old token address on BSC (for migration)
export const OLD_TOKEN_ADDRESS = (process.env.NEXT_PUBLIC_OLD_TOKEN || '0x61Fc93c7C070B32B1b1479B86056d8Ec1D7125BD') as `0x${string}`;

// Token metadata
export const TOKEN_NAME = 'Bitcoin Cultivator 400';
export const TOKEN_SYMBOL = 'BC400';
export const TOKEN_DECIMALS = 18;

// Chain display info
export const CHAIN_INFO: Record<number, { name: string; symbol: string; color: string; dotClass: string }> = {
  56:   { name: 'BNB Chain',  symbol: 'BNB', color: '#F0B90B', dotClass: 'chain-dot-bsc' },
  1:    { name: 'Ethereum',   symbol: 'ETH', color: '#627EEA', dotClass: 'chain-dot-ethereum' },
  8453: { name: 'Base',       symbol: 'ETH', color: '#0052FF', dotClass: 'chain-dot-base' },
  146:  { name: 'Sonic',      symbol: 'S',   color: '#00D4FF', dotClass: 'chain-dot-sonic' },
  137:  { name: 'Polygon',    symbol: 'POL', color: '#8247E5', dotClass: 'chain-dot-polygon' },
};

export const SUPPORTED_CHAIN_IDS = [56, 1, 8453, 146, 137] as const;
