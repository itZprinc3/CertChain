# ============================================================
# Makefile — Blockchain Certificate System
# Same pattern as Cyfrin Updraft foundry-fund-me-f23
# ============================================================

-include .env

.PHONY: all clean remove install update build test snapshot format anvil

# ---- Default target ----
all: clean remove install update build

# ---- Dependencies ----
install:
	forge install foundry-rs/forge-std 
	forge install Cyfrin/foundry-devops 

update:
	forge update

# ---- Build ----
build:; forge build

clean:; forge clean

remove:; rm -rf lib

# ---- Testing ----
test:
	forge test

test-v:
	forge test -vvv

test-unit:
	forge test --match-path test/unit/*.t.sol -vvv

test-integration:
	forge test --match-path test/integration/*.t.sol -vvv

test-gas:
	forge test --gas-report

snapshot:
	forge snapshot

format:; forge fmt

# ---- Local Chain ----
anvil:
	anvil

# ---- Deploy ----
NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --account $(ACCOUNT) --sender $(SENDER) --broadcast

# If targeting Sepolia, override NETWORK_ARGS
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	forge script script/DeployCertificateManager.s.sol:DeployCertificateManager $(NETWORK_ARGS)

# ---- Interactions (like FundFundMe / WithdrawFundMe) ----
issue:
	forge script script/Interactions.s.sol:IssueCertificate $(NETWORK_ARGS)

authorize:
	forge script script/Interactions.s.sol:AuthorizeIssuer $(NETWORK_ARGS)

# ---- Shortcut: Deploy to Sepolia ----
deploy-sepolia:
	forge script script/DeployCertificateManager.s.sol:DeployCertificateManager \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--sender $(SENDER) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

# ---- Frontend ----
serve:
	cd frontend && python3 -m http.server 8080
