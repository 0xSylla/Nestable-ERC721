-include .env

.PHONY: all clean build test snapshot format anvil deploy-anvil deploy-sepolia setup-anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: clean build test

# Build & compile
build:; forge build
clean:; forge clean
test:; forge test
snapshot:; forge snapshot
format:; forge fmt

# Local node
anvil:; anvil --host 127.0.0.1 --port 8545

# Deploy to Anvil (local) — auto-deploys MockERC6551Registry via HelperConfig
deploy-anvil:
	@forge script script/Deploy.s.sol:Deploy \
		--rpc-url http://localhost:8545 \
		--private-key $(DEFAULT_ANVIL_KEY) \
		--broadcast

# Post-deploy setup on Anvil (define gear, create mint stage, mint test tokens)
setup-anvil:
	@forge script script/SetupLocal.s.sol:SetupLocal \
		--rpc-url http://localhost:8545 \
		--private-key $(DEFAULT_ANVIL_KEY) \
		--broadcast

# Deploy to Sepolia
deploy-sepolia:
	@forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account defaultKey \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_KEY) \
		-vvvv

# Install dependencies
install:
	forge install OpenZeppelin/openzeppelin-contracts --no-commit
	forge install chiru-labs/ERC721A --no-commit
	forge install limitbreak/creator-token-standards --no-commit
	forge install foundry-rs/forge-std --no-commit
