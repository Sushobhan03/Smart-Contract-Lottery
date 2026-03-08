-include .env

.PHONY: all test deploy

ANVIL_PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo " make deploy [ARGS=...]"

build:; forge build

install:; forge install Cyfrin/foundry-devops@0.1.0 --no-git && forge install smartcontractkit/chainlink-brownie-contracts@1.1.0 --no-git && forge install foundry-rs/forge-std@v1.7.0 --no-git && forge install transmissions11/solmate@v6 --no-git

test:; forge test 

test-sepolia:; @forge test --fork-url $(SEPOLIA_RPC_URL)

coverage:; forge coverage

NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --private-key $(ANVIL_PRIVATE_KEY) --broadcast

# if --network sepolia is used, then use sepolia stuff, otherwise anvil stuff
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv
endif

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy: 
	@forge script script/DeployLottery.s.sol:DeployLottery $(NETWORK_ARGS)

createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

registerUpkeep:
	@forge script script/Interactions.s.sol:RegisterUpkeep $(NETWORK_ARGS)

enterLottery:
	@forge script script/Interactions.s.sol:EnterLottery $(NETWORK_ARGS)