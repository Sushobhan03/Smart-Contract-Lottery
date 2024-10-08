-include .env

.PHONY: all test delpoy

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo " make deploy [ARGS=...]"

build:; forge build

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.2.0 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit

test:; forge test

test-sepolia:; @forge test --fork-url $(SEPOLIA_RPC_URL)

coverage:; forge coverage

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key ${DEFAULT_ANVIL_KEY} --broadcast

# if --network sepolia is used, then use sepolia stuff, otherwise anvil stuff

ifeq ($(findstring --network sepolia, $(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url ${SEPOLIA_RPC_URL} --private-key ${SEPOLIA_PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} --legacy -vvvv
endif

anvil:
	anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployLottery.s.sol:DeployLottery ${NETWORK_ARGS}

createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)