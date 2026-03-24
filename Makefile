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
	configure-peers-amoy configure-peers-all test test-gas coverage
