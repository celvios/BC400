# CLAUDE_CODE_PROMPT.md
## Multi-Chain Token System — Master Build Prompt

---

## 📌 Before You Begin

1. Read `PERSONALITY.md` fully before writing a single line of code
2. Re-read `PERSONALITY.md` at the start of every new session
3. This is a **production mainnet system** — treat every decision accordingly
4. When uncertain, stop and reason explicitly before proceeding

---

## 🧭 Project Summary

Build a complete multi-chain token system consisting of:

- A new upgradeable ERC-20 token with 2% tax, deployed to 5 EVM chains at the **same contract address** using CREATE2 deterministic deployment
- Cross-chain bridging powered by **LayerZero V2 OFT standard**
- **Unified liquidity** on a single canonical chain (BSC/PancakeSwap)
- A **migration system** allowing holders of the old BSC token to swap 1:1 to the new token
- A **frontend portal** for migration and bridging
- Full **security architecture** with Gnosis Safe multisig and Timelock

---

## 📁 Repository Structure

```
/
├── PERSONALITY.md                  ← Behavior constitution (re-read always)
├── CLAUDE_CODE_PROMPT.md           ← This file
├── README.md                       ← Project overview
│
├── contracts/
│   ├── token/
│   │   ├── Token.sol               ← Main token contract
│   │   └── TokenStorage.sol        ← Storage layout (upgradeable safety)
│   ├── migration/
│   │   └── MigrationContract.sol   ← Old → new token swap
│   ├── interfaces/
│   │   ├── IToken.sol
│   │   └── IMigration.sol
│   └── mocks/
│       ├── MockLayerZeroEndpoint.sol
│       └── MockOldToken.sol
│
├── scripts/
│   ├── deploy/
│   │   ├── 01_deploy_token.ts
│   │   ├── 02_deploy_migration.ts
│   │   ├── 03_configure_layerzero.ts
│   │   ├── 04_setup_multisig.ts
│   │   └── 05_transfer_ownership.ts
│   └── utils/
│       ├── verify.ts
│       ├── computeCreate2Address.ts
│       └── fundContracts.ts
│
├── config/
│   ├── chains.ts                   ← Chain IDs, RPCs, explorers
│   ├── contracts.ts                ← Deployed addresses per chain
│   ├── layerzero.ts                ← LZ endpoints, EIDs
│   └── deployment.ts               ← Salt, deployer config
│
├── test/
│   ├── unit/
│   │   ├── Token.t.sol
│   │   ├── Tax.t.sol
│   │   ├── Migration.t.sol
│   │   └── Upgrade.t.sol
│   ├── integration/
│   │   ├── CrossChain.t.sol
│   │   └── FullFlow.t.sol
│   └── fuzz/
│       └── TaxFuzz.t.sol
│
├── deployments/
│   ├── testnet/
│   └── mainnet/
│
├── frontend/
│   ├── src/
│   │   ├── app/                    ← Next.js 14 app router
│   │   │   ├── page.tsx            ← Home / migrate
│   │   │   ├── bridge/page.tsx     ← Bridge UI
│   │   │   └── dashboard/page.tsx  ← Token dashboard
│   │   ├── components/
│   │   ├── hooks/                  ← Custom wagmi hooks
│   │   ├── config/                 ← Chain + contract config
│   │   ├── lib/                    ← Utilities, formatters
│   │   └── types/
│   ├── public/
│   └── .env.example
│
├── .env.example                    ← Template — never commit real .env
├── foundry.toml
├── package.json
└── tsconfig.json
```

---

## 📋 Smart Contracts Specification

### Contract 1: `Token.sol`

**Inherits:**
- `OFTUpgradeable` (LayerZero V2)
- `UUPSUpgradeable` (OpenZeppelin)
- `AccessControlUpgradeable` (OpenZeppelin)
- `ReentrancyGuardUpgradeable` (OpenZeppelin)
- `PausableUpgradeable` (OpenZeppelin)

**Storage Layout (TokenStorage.sol — never reorder):**
```solidity
// Slot 0
uint256 public constant TAX_BPS = 200;
uint256 public constant BPS_DENOMINATOR = 10000;
uint256 public constant MAX_TAX_BPS = 1000; // 10% hard cap

// Storage vars (in order, never change)
address public taxWallet;
bool public taxEnabled;
mapping(address => bool) public taxExempt;
uint256 public totalTaxCollected;
// gap for future storage
uint256[50] private __gap;
```

**Roles:**
```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");
```

**Functions to implement:**
```
initialize(address lzEndpoint, address admin, address _taxWallet, string name, string symbol)
_transfer(address from, address to, uint256 amount)  ← override with tax logic
setTaxWallet(address wallet)                          ← TAX_MANAGER_ROLE
setTaxEnabled(bool enabled)                           ← TAX_MANAGER_ROLE
setTaxExempt(address account, bool exempt)            ← ADMIN_ROLE
pause()                                               ← PAUSER_ROLE
unpause()                                             ← PAUSER_ROLE
_authorizeUpgrade(address)                            ← UPGRADER_ROLE only
```

**Events:**
```solidity
event TaxCollected(address indexed from, address indexed to, uint256 amount);
event TaxWalletUpdated(address indexed oldWallet, address indexed newWallet);
event TaxExemptUpdated(address indexed account, bool exempt);
event TaxEnabledUpdated(bool enabled);
```

**Custom Errors:**
```solidity
error ZeroAddress();
error TaxTooHigh(uint256 provided, uint256 max);
error NotAuthorized();
error ContractPaused();
```

**Tax Logic Rules:**
- Tax ONLY applies on BSC (canonical chain) for regular transfers
- Tax NEVER applies when: `taxExempt[from]` OR `taxExempt[to]`
- LayerZero endpoint and OFT adapter addresses MUST be in the tax exempt list
- Migration contract MUST be in the tax exempt list
- LP addresses MUST be in the tax exempt list
- Tax is sent to `taxWallet` synchronously in the same transfer
- If `taxWallet` is zero address, revert — never silently burn tax

---

### Contract 2: `MigrationContract.sol`

**Purpose:** Allow holders of the old BSC token to swap 1:1 for the new token.

**Constructor parameters (from env, never hardcoded):**
```solidity
constructor(
    address _oldToken,
    address _newToken,
    uint256 _migrationDurationDays,  // e.g. 90
    address _admin
)
```

**Functions:**
```
migrate(uint256 amount)              ← public, swaps old for new 1:1
migrateAll()                         ← convenience: migrates full balance
setActive(bool _active)              ← admin only
recoverTokens(address token, uint256 amount) ← admin only, post-deadline
getTimeRemaining() returns (uint256) ← seconds until deadline
```

**Events:**
```solidity
event Migrated(address indexed user, uint256 amount, uint256 timestamp);
event MigrationClosed(uint256 timestamp, uint256 unclaimedAmount);
event TokensRecovered(address indexed token, uint256 amount);
```

**Custom Errors:**
```solidity
error MigrationNotActive();
error MigrationDeadlinePassed();
error MigrationDeadlineNotReached();
error InsufficientNewTokenBalance();
error ZeroAmount();
```

---

## 🔧 Configuration System

### `config/chains.ts`
```typescript
// ALL values from environment variables
// This file defines the shape — values come from .env
export interface ChainConfig {
  chainId: number;
  name: string;
  rpcUrl: string;
  explorerUrl: string;
  nativeToken: string;
  layerZeroEid: number;
}

export const chains: Record<string, ChainConfig> = {
  bsc: {
    chainId: parseInt(process.env.BSC_CHAIN_ID!),
    name: "BNB Chain",
    rpcUrl: process.env.BSC_RPC_URL!,
    explorerUrl: process.env.BSC_EXPLORER_URL!,
    nativeToken: "BNB",
    layerZeroEid: parseInt(process.env.BSC_LZ_EID!),
  },
  // ethereum, base, sonic, polygon — same pattern
};
```

### `config/layerzero.ts`
```typescript
// LayerZero V2 endpoint addresses
// Source: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
export const LZ_ENDPOINTS: Record<string, string> = {
  bsc:      process.env.BSC_LZ_ENDPOINT!,
  ethereum: process.env.ETH_LZ_ENDPOINT!,
  base:     process.env.BASE_LZ_ENDPOINT!,
  sonic:    process.env.SONIC_LZ_ENDPOINT!,
  polygon:  process.env.POLYGON_LZ_ENDPOINT!,
};
```

### `.env.example` (committed — no real values)
```bash
# ============================================================
# DEPLOYMENT
# ============================================================
DEPLOYER_PRIVATE_KEY=
CREATE2_SALT=

# ============================================================
# BSC
# ============================================================
BSC_CHAIN_ID=56
BSC_RPC_URL=
BSC_EXPLORER_URL=https://bscscan.com
BSC_LZ_ENDPOINT=
BSC_LZ_EID=30102
BSC_TAX_WALLET=
BSC_OLD_TOKEN_ADDRESS=0x61Fc93c7C070B32B1b1479B86056d8Ec1D7125BD

# ============================================================
# ETHEREUM
# ============================================================
ETH_CHAIN_ID=1
ETH_RPC_URL=
ETH_EXPLORER_URL=https://etherscan.io
ETH_LZ_ENDPOINT=
ETH_LZ_EID=30101

# ============================================================
# BASE
# ============================================================
BASE_CHAIN_ID=8453
BASE_RPC_URL=
BASE_EXPLORER_URL=https://basescan.org
BASE_LZ_ENDPOINT=
BASE_LZ_EID=30184

# ============================================================
# SONIC
# ============================================================
SONIC_CHAIN_ID=
SONIC_RPC_URL=
SONIC_EXPLORER_URL=
SONIC_LZ_ENDPOINT=
SONIC_LZ_EID=

# ============================================================
# POLYGON
# ============================================================
POLYGON_CHAIN_ID=137
POLYGON_RPC_URL=
POLYGON_EXPLORER_URL=https://polygonscan.com
POLYGON_LZ_ENDPOINT=
POLYGON_LZ_EID=30109

# ============================================================
# MULTISIG & SECURITY
# ============================================================
MULTISIG_SIGNER_1=
MULTISIG_SIGNER_2=
MULTISIG_SIGNER_3=
MULTISIG_THRESHOLD=2
TIMELOCK_DELAY_SECONDS=172800

# ============================================================
# MIGRATION
# ============================================================
MIGRATION_DURATION_DAYS=90

# ============================================================
# FRONTEND
# ============================================================
NEXT_PUBLIC_BSC_RPC_URL=
NEXT_PUBLIC_ETH_RPC_URL=
NEXT_PUBLIC_BASE_RPC_URL=
NEXT_PUBLIC_SONIC_RPC_URL=
NEXT_PUBLIC_POLYGON_RPC_URL=
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=
```

---

## 🚀 Deployment Scripts Specification

### Script 1: `01_deploy_token.ts`

**Flow:**
1. Load config from environment (validate all required vars are set)
2. Compute expected CREATE2 address using `computeCreate2Address` util
3. Check if contract already deployed at that address (idempotent)
4. Deploy via Arachnid Deterministic Proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`)
5. Verify address matches expected
6. Save deployment record to `/deployments/{network}/token.json`
7. Output: `{ chain, address, txHash, blockNumber, timestamp, salt }`

**Must validate before deploying:**
- Correct chain ID
- LZ endpoint exists at configured address
- Deployer has sufficient gas
- Salt will produce same address as all other chains

### Script 2: `02_deploy_migration.ts`
- Deploy only on BSC
- Requires new token already deployed
- Requires old token address from env
- Saves deployment record

### Script 3: `03_configure_layerzero.ts`
- Must run AFTER token deployed on ALL 5 chains
- Loads all deployed addresses from deployment records
- Sets peers: for each chain, call `setPeer` with all other chain addresses
- Verifies each setPeer call succeeded
- Idempotent — checks if peer already set before calling

### Script 4: `04_setup_multisig.ts`
- Deploys Gnosis Safe on each chain with configured signers and threshold
- Deploys TimelockController pointing to Gnosis Safe as proposer/executor
- Saves both addresses to deployment records

### Script 5: `05_transfer_ownership.ts`
- Transfers all roles from deployer to Timelock
- Revokes deployer's roles
- Final state: deployer has NO roles on any contract
- Verifies ownership transfer succeeded before completing

---

## 🖥️ Frontend

> ⚠️ Frontend is fully specified in its own dedicated prompt file.
> Read `FRONTEND_PROMPT.md` before beginning Phase 6.
> All frontend work is governed by that file alongside `PERSONALITY.md`.

---

## 🧪 Testing Specification

### Unit Tests (Foundry)

**`test/unit/Token.t.sol`**
```
testTransferWithTax()
testTransferExemptFromAddress()
testTransferExemptToAddress()
testTransferWhenTaxDisabled()
testTransferWhenPaused()
testSetTaxWallet()
testSetTaxWalletZeroAddressReverts()
testSetTaxExempt()
testTaxBpsCannotExceedMax()
testOnlyAdminCanSetExempt()
testOnlyTaxManagerCanSetWallet()
```

**`test/unit/Migration.t.sol`**
```
testMigrateFullAmount()
testMigratePartialAmount()
testMigrateAll()
testMigrateAfterDeadlineReverts()
testMigrateWhenInactiveReverts()
testMigrateZeroAmountReverts()
testRecoverTokensBeforeDeadlineReverts()
testRecoverTokensAfterDeadline()
testOnlyAdminCanRecover()
```

**`test/unit/Upgrade.t.sol`**
```
testUpgradeSucceedsWithUpgraderRole()
testUpgradeRevertsWithoutRole()
testStoragePreservedAfterUpgrade()
testUpgradeThroughTimelock()
```

**`test/fuzz/TaxFuzz.t.sol`**
```
testFuzz_TaxCalculationNeverExceedsAmount(uint256 amount)
testFuzz_TaxCalculationAlwaysRoundsDown(uint256 amount)
testFuzz_TaxCollectedMatchesDifference(uint256 amount)
```

### Integration Tests

**`test/integration/CrossChain.t.sol`**
- Fork BSC + Base testnets
- Test full bridge flow: Base → BSC and BSC → Base
- Test bridge with LayerZero fee payment
- Test bridge reverts on insufficient fee

---

## 📦 Build Order

Follow this exact order. Do not skip steps. Do not move to the next step until the current one has passing tests.

```
Phase 1: Foundation
├── 1.1  Set up Foundry project structure
├── 1.2  Install dependencies (OZ, LayerZero V2 OFT)
├── 1.3  Create config system (chains, layerzero, deployment)
├── 1.4  Create .env.example
└── 1.5  Create TokenStorage.sol (storage layout)

Phase 2: Core Contracts
├── 2.1  Token.sol (base implementation, no tax yet)
├── 2.2  Tax logic (with full test coverage)
├── 2.3  LayerZero OFT integration
├── 2.4  Access control + roles
├── 2.5  Pause functionality
└── 2.6  Full unit test suite passing

Phase 3: Migration
├── 3.1  MigrationContract.sol
├── 3.2  Migration unit tests
└── 3.3  Migration integration test (fork)

Phase 4: Deployment Infrastructure
├── 4.1  computeCreate2Address utility
├── 4.2  Deployment script 01 (token)
├── 4.3  Deployment script 02 (migration)
├── 4.4  Deployment script 03 (LayerZero config)
├── 4.5  Deployment script 04 (multisig + timelock)
└── 4.6  Deployment script 05 (transfer ownership)

Phase 5: Testnet Deployment
├── 5.1  Deploy to BSC Testnet
├── 5.2  Deploy to Sepolia
├── 5.3  Deploy to Base Sepolia
├── 5.4  Deploy to Polygon Amoy
├── 5.5  Configure LayerZero peers
└── 5.6  Run end-to-end cross-chain test

Phase 6: Frontend  ← See FRONTEND_PROMPT.md for full specification
├── 6.1  Next.js 14 project setup
├── 6.2  wagmi + RainbowKit configuration (all 5 chains)
├── 6.3  Environment validation
├── 6.4  Contract ABIs and typed hooks
├── 6.5  Migration page (full state machine)
├── 6.6  Bridge page (full state machine)
├── 6.7  Dashboard page
└── 6.8  Mobile responsive QA

Phase 7: Pre-Mainnet
├── 7.1  Full test suite passing (forge test --gas-report)
├── 7.2  Coverage check (forge coverage)
├── 7.3  All contracts verified on testnets
├── 7.4  Security checklist review
└── 7.5  Client review and sign-off
```

---

## ✅ Quality Gates

You must not proceed past a phase until these gates are met:

| Gate | Requirement |
|---|---|
| Contracts | `forge test` — all passing, zero failures |
| Coverage | `forge coverage` — 95%+ line coverage |
| No hardcoding | Grep for hardcoded addresses/values — zero results |
| Types | TypeScript strict — zero `any` types |
| Env validation | App throws on missing env vars |
| Idempotency | Deploy scripts safe to run twice |
| Explorer verification | All contracts verified, source code visible |

---

## 🔗 Key References

Always verify addresses and EIDs from official sources:

- LayerZero V2 Deployed Contracts: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
- LayerZero V2 OFT Quickstart: https://docs.layerzero.network/v2/developers/evm/oft/quickstart
- OpenZeppelin UUPS: https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable
- OpenZeppelin Upgrades Hardhat Plugin: https://docs.openzeppelin.com/upgrades-plugins/1.x/
- Arachnid CREATE2 Proxy: https://github.com/Arachnid/deterministic-deployment-proxy
- Gnosis Safe Deployments: https://github.com/safe-global/safe-deployments
- PancakeSwap V2 Router: https://docs.pancakeswap.finance/developers/smart-contracts/pancakeswap-exchange/v2-contracts

---

## ⚠️ Critical Warnings

1. **The old token address is `0x61Fc93c7C070B32B1b1479B86056d8Ec1D7125BD`** — never deploy the migration contract without double-checking this is correct and verified on BscScan

2. **Sonic LayerZero support** — verify Sonic is officially supported by LayerZero V2 before deploying. Check the deployed contracts page. If not supported, flag this immediately rather than using an unverified endpoint.

3. **CREATE2 salt** — choose the salt once, commit it to config, never change it. A different salt = a different address = broken same-address guarantee.

4. **Storage layout** — if you ever modify `TokenStorage.sol`, run OpenZeppelin's upgrade safety checker before committing. Storage collisions will silently corrupt state.

5. **Tax on bridge transactions** — the LayerZero `_debit` and `_credit` functions MUST be tax-exempt. Tax on bridge txs will break the OFT mechanics and permanently lock funds.

---

*Re-read `PERSONALITY.md` now if you haven't in the last 30 minutes.*
