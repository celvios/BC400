# ============================================================
# BC400 Deployment Makefile
# ============================================================
# Usage: Copy .env.testnet → .env, fill in values, then run:
#   make deploy-bsc-testnet
#   make deploy-sepolia
#   make deploy-base-sepolia
#   make deploy-amoy
#   make configure-peers-all
# ============================================================

include .env

# ── Shared flags ──
FORGE := forge script
BROADCAST := --broadcast --slow
VERIFY_BSC := --verify --etherscan-api-key $(BSCSCAN_API_KEY)
VERIFY_ETH := --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
VERIFY_BASE := --verify --etherscan-api-key $(BASESCAN_API_KEY)
VERIFY_POLY := --verify --etherscan-api-key $(POLYGONSCAN_API_KEY)

# ============================================================
# STEP 1: Deploy Token on each chain
# ============================================================

deploy-bsc-testnet:
	@echo "=== Deploying Token to BSC Testnet ==="
	LZ_ENDPOINT=$(BSC_TESTNET_LZ_ENDPOINT) \
	TOKEN_ADMIN=$(TOKEN_ADMIN) \
	TAX_WALLET=$(TAX_WALLET) \
	$(FORGE) script/01_DeployToken.s.sol --rpc-url $(BSC_TESTNET_RPC_URL) $(BROADCAST)

deploy-sepolia:
	@echo "=== Deploying Token to Sepolia ==="
	LZ_ENDPOINT=$(SEPOLIA_LZ_ENDPOINT) \
	TOKEN_ADMIN=$(TOKEN_ADMIN) \
	TAX_WALLET=$(TOKEN_ADMIN) \
	$(FORGE) script/01_DeployToken.s.sol --rpc-url $(SEPOLIA_RPC_URL) $(BROADCAST)

deploy-base-sepolia:
	@echo "=== Deploying Token to Base Sepolia ==="
	LZ_ENDPOINT=$(BASE_SEPOLIA_LZ_ENDPOINT) \
	TOKEN_ADMIN=$(TOKEN_ADMIN) \
	TAX_WALLET=$(TOKEN_ADMIN) \
	$(FORGE) script/01_DeployToken.s.sol --rpc-url $(BASE_SEPOLIA_RPC_URL) $(BROADCAST)

deploy-amoy:
	@echo "=== Deploying Token to Polygon Amoy ==="
	LZ_ENDPOINT=$(AMOY_LZ_ENDPOINT) \
	TOKEN_ADMIN=$(TOKEN_ADMIN) \
	TAX_WALLET=$(TOKEN_ADMIN) \
	$(FORGE) script/01_DeployToken.s.sol --rpc-url $(AMOY_RPC_URL) $(BROADCAST)

deploy-all: deploy-bsc-testnet deploy-sepolia deploy-base-sepolia deploy-amoy
	@echo "=== All chains deployed ==="

# ============================================================
# STEP 2: Deploy Migration (BSC only)
# ============================================================

deploy-migration-bsc:
	@echo "=== Deploying Migration on BSC Testnet ==="
	OLD_TOKEN_ADDRESS=$(OLD_TOKEN_ADDRESS) \
	NEW_TOKEN_PROXY=$(BSC_TOKEN_PROXY) \
	MIGRATION_ADMIN=$(TOKEN_ADMIN) \
	MIGRATION_FUND_AMOUNT=$(TOKEN_SUPPLY) \
	$(FORGE) script/02_DeployMigration.s.sol --rpc-url $(BSC_TESTNET_RPC_URL) $(BROADCAST)

# ============================================================
# STEP 3: Configure LZ Peers (run per chain)
# ============================================================
# After deploying on all chains, fill in these proxy addresses:

BSC_TOKEN_PROXY ?=
SEPOLIA_TOKEN_PROXY ?=
BASE_TOKEN_PROXY ?=
AMOY_TOKEN_PROXY ?=

configure-peers-bsc:
	@echo "=== Configuring LZ peers on BSC Testnet ==="
	TOKEN_PROXY=$(BSC_TOKEN_PROXY) \
	PEER_EIDS="$(SEPOLIA_LZ_EID),$(BASE_SEPOLIA_LZ_EID),$(AMOY_LZ_EID)" \
	PEER_ADDRESSES="$(SEPOLIA_TOKEN_PROXY),$(BASE_TOKEN_PROXY),$(AMOY_TOKEN_PROXY)" \
	$(FORGE) script/03_ConfigureLayerZero.s.sol --rpc-url $(BSC_TESTNET_RPC_URL) $(BROADCAST)

configure-peers-sepolia:
	@echo "=== Configuring LZ peers on Sepolia ==="
	TOKEN_PROXY=$(SEPOLIA_TOKEN_PROXY) \
	PEER_EIDS="$(BSC_TESTNET_LZ_EID),$(BASE_SEPOLIA_LZ_EID),$(AMOY_LZ_EID)" \
	PEER_ADDRESSES="$(BSC_TOKEN_PROXY),$(BASE_TOKEN_PROXY),$(AMOY_TOKEN_PROXY)" \
	$(FORGE) script/03_ConfigureLayerZero.s.sol --rpc-url $(SEPOLIA_RPC_URL) $(BROADCAST)

configure-peers-base:
	@echo "=== Configuring LZ peers on Base Sepolia ==="
	TOKEN_PROXY=$(BASE_TOKEN_PROXY) \
	PEER_EIDS="$(BSC_TESTNET_LZ_EID),$(SEPOLIA_LZ_EID),$(AMOY_LZ_EID)" \
	PEER_ADDRESSES="$(BSC_TOKEN_PROXY),$(SEPOLIA_TOKEN_PROXY),$(AMOY_TOKEN_PROXY)" \
	$(FORGE) script/03_ConfigureLayerZero.s.sol --rpc-url $(BASE_SEPOLIA_RPC_URL) $(BROADCAST)

configure-peers-amoy:
	@echo "=== Configuring LZ peers on Polygon Amoy ==="
	TOKEN_PROXY=$(AMOY_TOKEN_PROXY) \
	PEER_EIDS="$(BSC_TESTNET_LZ_EID),$(SEPOLIA_LZ_EID),$(BASE_SEPOLIA_LZ_EID)" \
	PEER_ADDRESSES="$(BSC_TOKEN_PROXY),$(SEPOLIA_TOKEN_PROXY),$(BASE_TOKEN_PROXY)" \
	$(FORGE) script/03_ConfigureLayerZero.s.sol --rpc-url $(AMOY_RPC_URL) $(BROADCAST)

configure-peers-all: configure-peers-bsc configure-peers-sepolia configure-peers-base configure-peers-amoy
	@echo "=== All peers configured ==="

# ============================================================
# STEP 4: Upgrade Token implementation (whitelist/blacklist)
# ============================================================
# TOKEN_PROXY is the same address on all chains (CREATE2 deployment).

TOKEN_PROXY_TESTNET := 0x4A2770Deb58bD1e2115eA51659391508ee70Eba4

upgrade-bsc-testnet:
	@echo "=== Upgrading Token on BSC Testnet ==="
	TOKEN_PROXY=$(TOKEN_PROXY_TESTNET) \
	LZ_ENDPOINT=$(BSC_TESTNET_LZ_ENDPOINT) \
	$(FORGE) script/06_UpgradeToken.s.sol --rpc-url $(BSC_TESTNET_RPC_URL) $(BROADCAST) $(VERIFY_BSC)

upgrade-sepolia:
	@echo "=== Upgrading Token on Sepolia ==="
	TOKEN_PROXY=$(TOKEN_PROXY_TESTNET) \
	LZ_ENDPOINT=$(SEPOLIA_LZ_ENDPOINT) \
	$(FORGE) script/06_UpgradeToken.s.sol --rpc-url $(SEPOLIA_RPC_URL) $(BROADCAST) $(VERIFY_ETH)

upgrade-base-sepolia:
	@echo "=== Upgrading Token on Base Sepolia ==="
	TOKEN_PROXY=$(TOKEN_PROXY_TESTNET) \
	LZ_ENDPOINT=$(BASE_SEPOLIA_LZ_ENDPOINT) \
	$(FORGE) script/06_UpgradeToken.s.sol --rpc-url $(BASE_SEPOLIA_RPC_URL) $(BROADCAST) $(VERIFY_BASE)

upgrade-amoy:
	@echo "=== Upgrading Token on Polygon Amoy ==="
	TOKEN_PROXY=$(TOKEN_PROXY_TESTNET) \
	LZ_ENDPOINT=$(AMOY_LZ_ENDPOINT) \
	$(FORGE) script/06_UpgradeToken.s.sol --rpc-url $(AMOY_RPC_URL) $(BROADCAST) $(VERIFY_POLY)

upgrade-all-testnet: upgrade-bsc-testnet upgrade-sepolia upgrade-base-sepolia upgrade-amoy
	@echo "=== All testnet chains upgraded ==="

# ============================================================
# STEP 5: Verify contracts on explorers (run after upgrade)
# ============================================================
# These submit the implementation source to each block explorer so the
# client can see and call all functions from the "Write Contract" tab.
# The proxy is auto-linked because it follows EIP-1967.
#
# Usage:
#   make verify-bsc-testnet
#   make verify-all-testnet
#
# Requires API keys in .env:
#   BSCSCAN_API_KEY, ETHERSCAN_API_KEY, BASESCAN_API_KEY, POLYGONSCAN_API_KEY

# Implementation addresses from deployments/ (same per chain since CREATE2)
IMPL_BSC_TESTNET   := 0x87D8EEFfD2529982BE74ac6eDD851BcFcacCFC44
IMPL_SEPOLIA       := 0x08F64E3Bdc99061c96CA2b3bE575593B2fc63F91
IMPL_BASE_SEPOLIA  := 0x88C455437AE4C975d6FcD4099b34c23Da082A642
IMPL_AMOY          := 0x224b8917073cBF42E32329546E3040B3260bAA06

verify-bsc-testnet:
	@echo "=== Verifying implementation on BSC Testnet ==="
	forge verify-contract \
		--chain 97 \
		--etherscan-api-key $(BSCSCAN_API_KEY) \
		--watch \
		$(IMPL_BSC_TESTNET) \
		contracts/token/Token.sol:Token

verify-sepolia:
	@echo "=== Verifying implementation on Sepolia ==="
	forge verify-contract \
		--chain 11155111 \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--watch \
		$(IMPL_SEPOLIA) \
		contracts/token/Token.sol:Token

verify-base-sepolia:
	@echo "=== Verifying implementation on Base Sepolia ==="
	forge verify-contract \
		--chain 84532 \
		--etherscan-api-key $(BASESCAN_API_KEY) \
		--watch \
		$(IMPL_BASE_SEPOLIA) \
		contracts/token/Token.sol:Token

verify-amoy:
	@echo "=== Verifying implementation on Polygon Amoy ==="
	forge verify-contract \
		--chain 80002 \
		--etherscan-api-key $(POLYGONSCAN_API_KEY) \
		--watch \
		$(IMPL_AMOY) \
		contracts/token/Token.sol:Token

verify-all-testnet: verify-bsc-testnet verify-sepolia verify-base-sepolia verify-amoy
	@echo "=== All testnet implementations verified ==="

# ============================================================
# TEST
# ============================================================

test:
	forge test -vv

test-gas:
	forge test --gas-report

coverage:
	forge coverage

.PHONY: deploy-bsc-testnet deploy-sepolia deploy-base-sepolia deploy-amoy deploy-all \
	deploy-migration-bsc configure-peers-bsc configure-peers-sepolia configure-peers-base \
	configure-peers-amoy configure-peers-all \
	upgrade-bsc-testnet upgrade-sepolia upgrade-base-sepolia upgrade-amoy upgrade-all-testnet \
	verify-bsc-testnet verify-sepolia verify-base-sepolia verify-amoy verify-all-testnet \
	test test-gas coverage
