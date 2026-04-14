// DEX configuration per chain for buying BC400
// Router addresses use environment variables with known fallbacks

export interface PaymentToken {
  symbol: string;
  name: string;
  address: `0x${string}` | null; // null = native token
  decimals: number;
  isNative: boolean;
}

export interface ChainDexConfig {
  routerAddress: `0x${string}`;
  wethAddress: `0x${string}`; // Wrapped native token
  dexName: string;
  paymentTokens: PaymentToken[];
}

const DEX_CONFIGS: Record<number, ChainDexConfig> = {
  // ── Mainnet ──────────────────────────────────────────────────
  56: {
    routerAddress: (process.env.NEXT_PUBLIC_BSC_ROUTER   || '0x10ED43C718714eb63d5aA57B78B54704E256024E') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_BSC_WETH     || '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c') as `0x${string}`,
    dexName: 'PancakeSwap V2',
    paymentTokens: [
      { symbol: 'BNB',  name: 'BNB',       address: null,                                       decimals: 18, isNative: true  },
      { symbol: 'USDT', name: 'Tether USD', address: '0x55d398326f99059fF775485246999027B3197955', decimals: 18, isNative: false },
      { symbol: 'USDC', name: 'USD Coin',   address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', decimals: 18, isNative: false },
    ],
  },
  1: {
    routerAddress: (process.env.NEXT_PUBLIC_ETH_ROUTER   || '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_ETH_WETH     || '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2') as `0x${string}`,
    dexName: 'Uniswap V2',
    paymentTokens: [
      { symbol: 'ETH',  name: 'Ethereum',   address: null,                                       decimals: 18, isNative: true  },
      { symbol: 'USDT', name: 'Tether USD', address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', decimals: 6,  isNative: false },
      { symbol: 'USDC', name: 'USD Coin',   address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', decimals: 6,  isNative: false },
    ],
  },
  8453: {
    routerAddress: (process.env.NEXT_PUBLIC_BASE_ROUTER  || '0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_BASE_WETH    || '0x4200000000000000000000000000000000000006') as `0x${string}`,
    dexName: 'Uniswap V2',
    paymentTokens: [
      { symbol: 'ETH',  name: 'Ethereum', address: null,                                         decimals: 18, isNative: true  },
      { symbol: 'USDC', name: 'USD Coin', address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',  decimals: 6,  isNative: false },
    ],
  },
  146: {
    routerAddress: (process.env.NEXT_PUBLIC_SONIC_ROUTER || '0x0000000000000000000000000000000000000001') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_SONIC_WETH   || '0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38') as `0x${string}`,
    dexName: 'SonicDEX',
    paymentTokens: [
      { symbol: 'S', name: 'Sonic', address: null, decimals: 18, isNative: true },
    ],
  },
  137: {
    routerAddress: (process.env.NEXT_PUBLIC_POLYGON_ROUTER || '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_POLYGON_WETH   || '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270') as `0x${string}`,
    dexName: 'QuickSwap',
    paymentTokens: [
      { symbol: 'POL',  name: 'Polygon',    address: null,                                       decimals: 18, isNative: true  },
      { symbol: 'USDC', name: 'USD Coin',   address: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', decimals: 6,  isNative: false },
      { symbol: 'USDT', name: 'Tether USD', address: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', decimals: 6,  isNative: false },
    ],
  },

  // ── Testnet ───────────────────────────────────────────────────
  97: {
    routerAddress: (process.env.NEXT_PUBLIC_BSC_ROUTER   || '0xD99D1c33F9fC3444f8101754aBC46c52416550D1') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_BSC_WETH     || '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd') as `0x${string}`,
    dexName: 'PancakeSwap (Testnet)',
    paymentTokens: [
      { symbol: 'tBNB', name: 'Test BNB', address: null, decimals: 18, isNative: true },
    ],
  },
  11155111: {
    routerAddress: (process.env.NEXT_PUBLIC_ETH_ROUTER   || '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_ETH_WETH     || '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9') as `0x${string}`,
    dexName: 'Uniswap V2 (Sepolia)',
    paymentTokens: [
      { symbol: 'ETH', name: 'Sepolia ETH', address: null, decimals: 18, isNative: true },
    ],
  },
  84532: {
    routerAddress: (process.env.NEXT_PUBLIC_BASE_ROUTER  || '0x1689E7B1F10000AE47eBfE339a4f69dECd19F602') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_BASE_WETH    || '0x4200000000000000000000000000000000000006') as `0x${string}`,
    dexName: 'Uniswap V2 (Base Sepolia)',
    paymentTokens: [
      { symbol: 'ETH', name: 'Base Sepolia ETH', address: null, decimals: 18, isNative: true },
    ],
  },
  80002: {
    routerAddress: (process.env.NEXT_PUBLIC_POLYGON_ROUTER || '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_POLYGON_WETH   || '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270') as `0x${string}`,
    dexName: 'QuickSwap (Amoy)',
    paymentTokens: [
      { symbol: 'POL', name: 'Polygon Amoy', address: null, decimals: 18, isNative: true },
    ],
  },
  57054: {
    routerAddress: (process.env.NEXT_PUBLIC_SONIC_ROUTER || '0x0000000000000000000000000000000000000001') as `0x${string}`,
    wethAddress:   (process.env.NEXT_PUBLIC_SONIC_WETH   || '0x0000000000000000000000000000000000000001') as `0x${string}`,
    dexName: 'SonicDEX (Blaze)',
    paymentTokens: [
      { symbol: 'S', name: 'Sonic Blaze', address: null, decimals: 18, isNative: true },
    ],
  },
};

export function getDexConfig(chainId: number): ChainDexConfig | undefined {
  return DEX_CONFIGS[chainId];
}
