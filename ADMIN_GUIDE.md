# BC400 Admin Guide
## How to Manage the Token From the Block Explorer

---

## Prerequisites

Before calling any function you need:

1. **The admin wallet** — the one set as `TOKEN_ADMIN` during deployment. Only this wallet has permission.
2. **Gas tokens** — small amounts of tBNB, ETH, etc. on each testnet (free from faucets).
3. **The contract address** — same on every chain:

```
0x4A2770Deb58bD1e2115eA51659391508ee70Eba4
```

---

## Block Explorer Links

| Chain | Explorer Link |
|-------|--------------|
| BSC Testnet | https://testnet.bscscan.com/address/0x4A2770Deb58bD1e2115eA51659391508ee70Eba4 |
| Sepolia (Ethereum) | https://sepolia.etherscan.io/address/0x4A2770Deb58bD1e2115eA51659391508ee70Eba4 |
| Base Sepolia | https://sepolia.basescan.org/address/0x4A2770Deb58bD1e2115eA51659391508ee70Eba4 |
| Polygon Amoy | https://amoy.polygonscan.com/address/0x4A2770Deb58bD1e2115eA51659391508ee70Eba4 |

---

## How to Call a Function

1. Open the explorer link for the chain you want to manage
2. Click the **Contract** tab
3. To **check values** → click **Read as Proxy** (no wallet needed)
4. To **change something** → click **Write as Proxy** → click **Connect to Web3** → connect your admin wallet in MetaMask
5. Find the function in the list → expand it → fill in the value → click **Write** → confirm in MetaMask

> Note: Every chain is independent. You must switch your MetaMask to the correct network and call the function on that chain's explorer separately.

---

## Roles Quick Reference

The admin wallet has all roles by default. Each function requires a specific role.

| Role | Who needs it | What it controls |
|------|-------------|-----------------|
| `ADMIN_ROLE` | Main admin wallet | Whitelist, blacklist, launch, anti-whale, DEX settings |
| `TAX_MANAGER_ROLE` | Main admin wallet | Tax rate, buy/sell tax, tax wallet, enable/disable tax |
| `PAUSER_ROLE` | Main admin wallet | Emergency pause/unpause all transfers |
| `UPGRADER_ROLE` | Main admin wallet | Deploy new contract implementation (upgrades) |
| `DEFAULT_ADMIN_ROLE` | Main admin wallet | Grant/revoke all roles above to other wallets |

---

---

## Full Function Checklist

---

### SECTION 1 — Launch & Whitelist Window

---

#### `launch()`
**What it does:** Marks the token as live. Starts a 2-hour window where only whitelisted wallets can buy/sell/transfer. After 2 hours the whitelist window auto-lifts and trading opens to everyone.

**Required role:** `ADMIN_ROLE`

**⚠️ This is irreversible.** Call only after you have whitelisted all pre-sale wallets.

**How to call:**
- Write as Proxy → `launch` → no inputs needed → Write

---

#### `setWhitelisted(address account, bool _whitelisted)`
**What it does:** Adds or removes a wallet from the whitelist. Whitelisted wallets can trade during the 2-hour launch window. Has no effect after the window ends.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `account` — the wallet address (e.g. `0xABC...`)
- `_whitelisted` — `true` to add, `false` to remove

**Example — Add a wallet:**
```
account:       0xABC123...
_whitelisted:  true
```

**Example — Remove a wallet:**
```
account:       0xABC123...
_whitelisted:  false
```

**How to check:** Read as Proxy → `whitelisted` → enter address → Query → returns `true` or `false`

---

#### `setWhitelistEnabled(bool enabled)`
**What it does:** Manually force whitelist-only mode ON or OFF, independent of the 2-hour window. Useful if you want to extend or cut the whitelist window early.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `enabled` — `true` to lock trading to whitelist only, `false` to open to everyone

**How to check:** Read as Proxy → `whitelistEnabled` → returns `true` or `false`

---

#### `isWhitelistActive()` *(Read only)*
**What it does:** Returns `true` if the whitelist is currently active (either the 2-hour window is still running OR `whitelistEnabled` is manually set to true).

**How to check:** Read as Proxy → `isWhitelistActive` → returns `true` or `false`

---

#### `launchTime()` *(Read only)*
**What it does:** Returns the Unix timestamp of when `launch()` was called. Add 7200 (seconds) to calculate when the 2-hour window ends.

**How to check:** Read as Proxy → `launchTime` → returns a number (0 means not yet launched)

---

---

### SECTION 2 — Blacklist

---

#### `setBlacklisted(address account, bool _blacklisted)`
**What it does:** Permanently blocks a wallet from sending or receiving BC400. Blacklisted wallets cannot trade under any circumstance — even if they are whitelisted. Can be reversed by calling with `false`.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `account` — the wallet address to block
- `_blacklisted` — `true` to block, `false` to unblock

**Example — Block a sniper bot:**
```
account:       0xBAD000...
_blacklisted:  true
```

**How to check:** Read as Proxy → `blacklisted` → enter address → Query → returns `true` or `false`

---

---

### SECTION 3 — Tax Settings

> **Basis Points (BPS):** All tax values use basis points. 100 BPS = 1%. Maximum allowed is 1000 BPS = 10%.

---

#### `setTaxBps(uint256 bps)`
**What it does:** Sets the general transfer tax rate applied to all non-DEX transfers. This is in addition to buy/sell tax.

**Required role:** `TAX_MANAGER_ROLE`

**Max value:** 1000 (= 10%)

**Inputs:**
- `bps` — tax in basis points (e.g. `300` = 3%)

**How to check:** Read as Proxy → `taxBps`

---

#### `setBuyTaxBps(uint256 bps)`
**What it does:** Sets the tax applied when someone buys BC400 from a DEX pair.

**Required role:** `TAX_MANAGER_ROLE`

**Max value:** 1000 (= 10%)

**Inputs:**
- `bps` — e.g. `200` = 2% buy tax

**How to check:** Read as Proxy → `buyTaxBps`

---

#### `setSellTaxBps(uint256 bps)`
**What it does:** Sets the tax applied when someone sells BC400 on a DEX pair.

**Required role:** `TAX_MANAGER_ROLE`

**Max value:** 1000 (= 10%)

**Inputs:**
- `bps` — e.g. `500` = 5% sell tax

**How to check:** Read as Proxy → `sellTaxBps`

---

#### `setTaxEnabled(bool enabled)`
**What it does:** Turns all tax collection on or off globally. When disabled, no tax is deducted from any transfer — regardless of buy/sell/transfer BPS settings.

**Required role:** `TAX_MANAGER_ROLE`

**Inputs:**
- `enabled` — `true` to collect tax, `false` to disable

**How to check:** Read as Proxy → `taxEnabled`

---

#### `setTaxWallet(address wallet)`
**What it does:** Changes where collected tax is sent. All future tax goes to the new address immediately.

**Required role:** `TAX_MANAGER_ROLE`

**Inputs:**
- `wallet` — the new tax collection wallet address

**How to check:** Read as Proxy → `taxWallet`

---

#### `setTaxExempt(address account, bool exempt)`
**What it does:** Marks a wallet as tax-exempt — no tax is deducted from their transfers, buys, or sells.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `account` — wallet to exempt
- `exempt` — `true` to exempt, `false` to remove exemption

**Common uses:** Exempt the migration contract, the team wallet, or the liquidity pool deployer.

---

#### `totalTaxCollected()` *(Read only)*
**What it does:** Shows total BC400 tax collected across all transfers since deployment.

**How to check:** Read as Proxy → `totalTaxCollected` → divide by 10^18 for human-readable amount

---

---

### SECTION 4 — Anti-Whale

---

#### `setAntiWhale(bool enabled, uint256 _maxTransferBps)`
**What it does:** Limits the maximum amount any single transfer can move, expressed as a percentage of total supply. Prevents whale dumps.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `enabled` — `true` to activate the limit, `false` to disable
- `_maxTransferBps` — max transfer size as BPS of total supply
  - e.g. `200` = max 2% of total supply per transfer
  - e.g. `100` = max 1% per transfer
  - minimum `1`, maximum `10000`

**Example — Set 1% max transfer:**
```
enabled:          true
_maxTransferBps:  100
```

**How to check:** Read as Proxy → `antiWhaleEnabled` and `maxTransferBps`

---

---

### SECTION 5 — DEX & Auto-Swap

> Auto-swap: When the contract accumulates enough tax tokens, it automatically swaps them to BNB and sends to the tax wallet. This only works on BSC where the DEX router is set.

---

#### `setDexRouter(address router)`
**What it does:** Sets the DEX router address used for auto-swapping tax tokens to BNB. Only needed on BSC.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `router` — PancakeSwap V2 router address (`0x10ED43C718714eb63d5aA57B78B54704E256024E` on BSC mainnet)

**How to check:** Read as Proxy → `dexRouter`

---

#### `setDexPair(address pair, bool active)`
**What it does:** Registers a DEX liquidity pool address so the contract knows to apply buy/sell tax (instead of transfer tax) on trades through it.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `pair` — the LP pair contract address from PancakeSwap/Uniswap
- `active` — `true` to register, `false` to remove

**Must be called after creating the liquidity pool.** Without this, buys/sells use the general transfer tax instead of buy/sell tax.

---

#### `setSwapEnabled(bool enabled)`
**What it does:** Enables or disables the auto-swap feature (contract converting accumulated tax tokens to BNB automatically).

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `enabled` — `true` to enable auto-swap, `false` to disable

**How to check:** Read as Proxy → `swapEnabled`

---

#### `setSwapThreshold(uint256 threshold)`
**What it does:** Sets how many BC400 tokens must accumulate in the contract before auto-swap triggers. Expressed in full token units × 10^18.

**Required role:** `ADMIN_ROLE`

**Inputs:**
- `threshold` — amount in wei (e.g. `1000000000000000000000` = 1000 BC400)

**How to check:** Read as Proxy → `swapThreshold`

---

#### `triggerSwap()`
**What it does:** Manually forces the contract to swap all accumulated tax tokens to BNB right now, regardless of the threshold.

**Required role:** `ADMIN_ROLE`

**How to call:** Write as Proxy → `triggerSwap` → no inputs → Write

---

#### `withdrawStuckETH()`
**What it does:** Sends any BNB/ETH stuck in the contract to the tax wallet. Safety function in case auto-swap leaves residual BNB.

**Required role:** `ADMIN_ROLE`

**How to call:** Write as Proxy → `withdrawStuckETH` → no inputs → Write

---

---

### SECTION 6 — Emergency Controls

---

#### `pause()`
**What it does:** Freezes ALL token transfers on this chain immediately. No one can send, receive, buy, or sell BC400. Use in emergencies (exploit, migration, etc.).

**Required role:** `PAUSER_ROLE`

**How to call:** Write as Proxy → `pause` → Write

---

#### `unpause()`
**What it does:** Resumes all transfers after a pause.

**Required role:** `PAUSER_ROLE`

**How to call:** Write as Proxy → `unpause` → Write

---

---

### SECTION 7 — Role Management

---

#### `grantRole(bytes32 role, address account)`
**What it does:** Gives a role to another wallet. Use this to assign a separate tax manager, pauser, or second admin.

**Required role:** `DEFAULT_ADMIN_ROLE`

**Inputs:**
- `role` — the keccak256 hash of the role name (see table below)
- `account` — the wallet to grant the role to

**Role hashes:**
| Role | Hash to paste |
|------|--------------|
| `ADMIN_ROLE` | `0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775` |
| `TAX_MANAGER_ROLE` | `0x…` (read from contract: Read → `TAX_MANAGER_ROLE`) |
| `PAUSER_ROLE` | read from contract: Read → `PAUSER_ROLE` |
| `UPGRADER_ROLE` | read from contract: Read → `UPGRADER_ROLE` |

---

#### `revokeRole(bytes32 role, address account)`
**What it does:** Removes a role from a wallet. Use this if the tax manager or pauser wallet is compromised.

**Required role:** `DEFAULT_ADMIN_ROLE`

---

---

## Pre-Launch Checklist

Use this before calling `launch()`:

- [ ] Whitelist all pre-sale wallets via `setWhitelisted`
- [ ] Whitelist the migration contract address
- [ ] Whitelist the team/treasury wallet
- [ ] Set buy tax: `setBuyTaxBps` (e.g. 200 = 2%)
- [ ] Set sell tax: `setSellTaxBps` (e.g. 500 = 5%)
- [ ] Set tax wallet: `setTaxWallet` (where tax BNB goes)
- [ ] Set DEX router on BSC: `setDexRouter`
- [ ] Enable tax: `setTaxEnabled(true)`
- [ ] Enable auto-swap: `setSwapEnabled(true)`
- [ ] Set swap threshold: `setSwapThreshold`
- [ ] (Optional) Enable anti-whale: `setAntiWhale(true, 200)` for 2% max
- [ ] Verify all settings with Read as Proxy before proceeding
- [ ] Call `launch()` — **this is the point of no return**
- [ ] After creating the LP: call `setDexPair(pairAddress, true)`

---

## Post-Launch Checklist (After 2hr window)

- [ ] Confirm `isWhitelistActive()` returns `false`
- [ ] Check `totalTaxCollected()` to confirm tax is accumulating
- [ ] Monitor for bot wallets → blacklist as needed
- [ ] If large dumps occur → `setAntiWhale(true, 100)` to limit transfers to 1%
