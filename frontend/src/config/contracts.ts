// Contract addresses per chain — all from environment variables
// NEVER hardcode addresses

export interface ContractAddresses {
  token: `0x${string}`;
  migration?: `0x${string}`; // Only on BSC
}

export const CONTRACTS: Record<number, ContractAddresses> = {
  // ── Mainnet ──
  56: {
    token: (process.env.NEXT_PUBLIC_BSC_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
    migration: (process.env.NEXT_PUBLIC_BSC_MIGRATION || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  1: {
    token: (process.env.NEXT_PUBLIC_ETH_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  8453: {
    token: (process.env.NEXT_PUBLIC_BASE_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  146: {
    token: (process.env.NEXT_PUBLIC_SONIC_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  137: {
    token: (process.env.NEXT_PUBLIC_POLYGON_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  // ── Testnet ──
  97: {
    token: (process.env.NEXT_PUBLIC_BSC_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
    migration: (process.env.NEXT_PUBLIC_BSC_MIGRATION || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  11155111: {
    token: (process.env.NEXT_PUBLIC_ETH_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  84532: {
    token: (process.env.NEXT_PUBLIC_BASE_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  80002: {
    token: (process.env.NEXT_PUBLIC_POLYGON_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
  57054: {
    token: (process.env.NEXT_PUBLIC_SONIC_TOKEN || '0x0000000000000000000000000000000000000000') as `0x${string}`,
  },
};

// Old token address on BSC (for migration)
export const OLD_TOKEN_ADDRESS = (process.env.NEXT_PUBLIC_OLD_TOKEN || '0x61Fc93c7C070B32B1b1479B86056d8Ec1D7125BD') as `0x${string}`;

// Token metadata
export const TOKEN_NAME = 'Bitcoin Cultivator 400';
export const TOKEN_SYMBOL = 'BC400';
export const TOKEN_DECIMALS = 18;

// Chain display info
export const CHAIN_INFO: Record<number, { name: string; symbol: string; color: string; dotClass: string; explorerUrl: string }> = {
  // Mainnet
  56:   { name: 'BNB Chain',  symbol: 'BNB', color: '#F0B90B', dotClass: 'chain-dot-bsc',      explorerUrl: 'https://bscscan.com' },
  1:    { name: 'Ethereum',   symbol: 'ETH', color: '#627EEA', dotClass: 'chain-dot-ethereum', explorerUrl: 'https://etherscan.io' },
  8453: { name: 'Base',       symbol: 'ETH', color: '#0052FF', dotClass: 'chain-dot-base',     explorerUrl: 'https://basescan.org' },
  146:  { name: 'Sonic',      symbol: 'S',   color: '#00D4FF', dotClass: 'chain-dot-sonic',    explorerUrl: 'https://sonicscan.org' },
  137:  { name: 'Polygon',    symbol: 'POL', color: '#8247E5', dotClass: 'chain-dot-polygon',  explorerUrl: 'https://polygonscan.com' },
  // Testnet
  97:       { name: 'BSC Testnet',   symbol: 'tBNB', color: '#F0B90B', dotClass: 'chain-dot-bsc',      explorerUrl: 'https://testnet.bscscan.com' },
  11155111: { name: 'Sepolia',       symbol: 'ETH',  color: '#627EEA', dotClass: 'chain-dot-ethereum', explorerUrl: 'https://sepolia.etherscan.io' },
  84532:    { name: 'Base Sepolia',  symbol: 'ETH',  color: '#0052FF', dotClass: 'chain-dot-base',     explorerUrl: 'https://sepolia.basescan.org' },
  80002:    { name: 'Amoy',          symbol: 'POL',  color: '#8247E5', dotClass: 'chain-dot-polygon',  explorerUrl: 'https://amoy.polygonscan.com' },
  57054:    { name: 'Sonic Blaze',   symbol: 'S',    color: '#00D4FF', dotClass: 'chain-dot-sonic',    explorerUrl: 'https://testnet.sonicscan.org' },
};

const useTestnets = process.env.NEXT_PUBLIC_USE_TESTNETS === 'true';
export const SUPPORTED_CHAIN_IDS = useTestnets
  ? [97, 11155111, 84532, 80002, 57054] as const
  : [56, 1, 8453, 146, 137] as const;

