/**
 * Format a token balance from bigint (18 decimals) to human-readable string.
 */
export function formatTokenAmount(amount: bigint | undefined, decimals: number = 18): string {
  if (amount === undefined) return '0.00';
  
  const divisor = BigInt(10 ** decimals);
  const whole = amount / divisor;
  const fraction = amount % divisor;
  
  // Show up to 4 decimal places
  const fractionStr = fraction.toString().padStart(decimals, '0').slice(0, 4);
  const wholeStr = whole.toLocaleString();
  
  return `${wholeStr}.${fractionStr}`;
}

/**
 * Format a large number with commas.
 */
export function formatNumber(num: number | string): string {
  return Number(num).toLocaleString();
}

/**
 * Truncate an address to 0x1234...5678 format.
 */
export function truncateAddress(address: string): string {
  if (!address || address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Format ETH/BNB amounts (gas fees) to readable string.
 */
export function formatNativeAmount(amount: bigint, symbol: string = 'ETH'): string {
  const eth = Number(amount) / 1e18;
  if (eth < 0.0001) return `<0.0001 ${symbol}`;
  return `${eth.toFixed(4)} ${symbol}`;
}

/**
 * Parse a string input to bigint token amount (18 decimals).
 */
export function parseTokenInput(input: string, decimals: number = 18): bigint {
  if (!input || input === '.' || input === '') return BigInt(0);
  
  const [whole, fraction = ''] = input.split('.');
  const paddedFraction = fraction.padEnd(decimals, '0').slice(0, decimals);
  const combined = `${whole || '0'}${paddedFraction}`;
  
  return BigInt(combined);
}
