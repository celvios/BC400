// Minimal Token ABI — only the functions needed by the frontend
export const TOKEN_ABI = [
  // ERC-20 standard
  { type: 'function', name: 'name', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
  { type: 'function', name: 'symbol', inputs: [], outputs: [{ type: 'string' }], stateMutability: 'view' },
  { type: 'function', name: 'decimals', inputs: [], outputs: [{ type: 'uint8' }], stateMutability: 'view' },
  { type: 'function', name: 'totalSupply', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'balanceOf', inputs: [{ name: 'account', type: 'address' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'allowance', inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'approve', inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ type: 'bool' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'transfer', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ type: 'bool' }], stateMutability: 'nonpayable' },

  // Tax
  { type: 'function', name: 'taxBps', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'taxEnabled', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'totalTaxCollected', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },

  // Admin — Access Control
  { type: 'function', name: 'ADMIN_ROLE', inputs: [], outputs: [{ type: 'bytes32' }], stateMutability: 'view' },
  { type: 'function', name: 'DEFAULT_ADMIN_ROLE', inputs: [], outputs: [{ type: 'bytes32' }], stateMutability: 'view' },
  { type: 'function', name: 'hasRole', inputs: [{ name: 'role', type: 'bytes32' }, { name: 'account', type: 'address' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },

  // Admin — Whitelist / Blacklist / Launch
  { type: 'function', name: 'whitelisted', inputs: [{ name: 'account', type: 'address' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'blacklisted', inputs: [{ name: 'account', type: 'address' }], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'whitelistEnabled', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'launchTime', inputs: [], outputs: [{ type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'isWhitelistActive', inputs: [], outputs: [{ type: 'bool' }], stateMutability: 'view' },
  { type: 'function', name: 'setWhitelisted', inputs: [{ name: 'account', type: 'address' }, { name: '_whitelisted', type: 'bool' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'setBlacklisted', inputs: [{ name: 'account', type: 'address' }, { name: '_blacklisted', type: 'bool' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'setWhitelistEnabled', inputs: [{ name: 'enabled', type: 'bool' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'launch', inputs: [], outputs: [], stateMutability: 'nonpayable' },

  // Admin — Events
  { type: 'event', name: 'WhitelistUpdated', inputs: [{ name: 'account', type: 'address', indexed: true }, { name: 'whitelisted', type: 'bool', indexed: false }] },
  { type: 'event', name: 'BlacklistUpdated', inputs: [{ name: 'account', type: 'address', indexed: true }, { name: 'blacklisted', type: 'bool', indexed: false }] },
  { type: 'event', name: 'Launched', inputs: [{ name: 'launchTime', type: 'uint256', indexed: false }] },

  // OFT / Bridge
  {
    type: 'function', name: 'quoteSend',
    inputs: [
      {
        name: '_sendParam', type: 'tuple',
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ]
      },
      { name: '_payInLzToken', type: 'bool' }
    ],
    outputs: [
      {
        name: '', type: 'tuple',
        components: [
          { name: 'nativeFee', type: 'uint256' },
          { name: 'lzTokenFee', type: 'uint256' },
        ]
      }
    ],
    stateMutability: 'view',
  },
  {
    type: 'function', name: 'send',
    inputs: [
      {
        name: '_sendParam', type: 'tuple',
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ]
      },
      {
        name: '_fee', type: 'tuple',
        components: [
          { name: 'nativeFee', type: 'uint256' },
          { name: 'lzTokenFee', type: 'uint256' },
        ]
      },
      { name: '_refundAddress', type: 'address' },
    ],
    outputs: [
      {
        name: '', type: 'tuple',
        components: [
          { name: 'guid', type: 'bytes32' },
          { name: 'nonce', type: 'uint64' },
          {
            name: 'fee', type: 'tuple',
            components: [
              { name: 'nativeFee', type: 'uint256' },
              { name: 'lzTokenFee', type: 'uint256' },
            ]
          },
        ]
      }
    ],
    stateMutability: 'payable',
  },
] as const;
