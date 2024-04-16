# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes --via-ir
test   :; forge test -vvv

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

# Deploys

## ETHEREUM MAINNET
deploy-mainnet-aclmanager :; forge script script/mainnet/DeployAclManager.s.sol:DeployACLManagerScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY} -vvvv --slow
deploy-mainnet-wallet :; forge script script/mainnet/DeployWallet.s.sol:DeployWalletScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY} -vvvv --slow 
deploy-mainnet-periphery :; forge script script/mainnet/DeployPeriphery.s.sol:DeployPeripheryScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY}  -vvvv --slow
deploy-mainnet-protocol :; forge script script/mainnet/DeployProtocol.s.sol:DeployProtocolScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY}  -vvvv  --slow
deploy-mainnet-modules :; forge script script/mainnet/DeployModules.s.sol:DeployModulesScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY} -vvvv --slow
deploy-mainnet-allow :; forge script script/mainnet/DeployAllowNFT.s.sol:DeployAllowNFTScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY} -vvvv --slow
deploy-mainnet-helper :; forge script script/mainnet/DeployUtilsHelper.s.sol:DeployUtilsHelperScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY} -vvvv --slow
deploy-mainnet-base-wallet :; forge script script/mainnet/DeployBaseWallet.s.sol:DeployBaseWalletScript --fork-url ${RPC_MAINNET} --broadcast --private-key ${PRIVATE_KEY} -vvvv --slow 

## ETHEREUM SEPOLIA
deploy-sep-aclmanager :; forge script script/sepolia/DeployAclManager.s.sol:DeployACLManagerScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-sep-wallet :; forge script script/sepolia/DeployWallet.s.sol:DeployWalletScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv 
deploy-sep-periphery :; forge script script/sepolia/DeployPeriphery.s.sol:DeployPeripheryScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY}  -vvvv
deploy-sep-protocol :; forge script script/sepolia/DeployProtocol.s.sol:DeployProtocolScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY}  -vvvv
deploy-sep-modules :; forge script script/sepolia/DeployModules.s.sol:DeployModulesScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-sep-allow :; forge script script/sepolia/DeployAllowNFT.s.sol:DeployAllowNFTScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-sep-base-wallet :; forge script script/sepolia/DeployBaseWallet.s.sol:DeployBaseWalletScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv 

deploy-sep-nft :; forge script script/sepolia/DeployFakeNFT.s.sol:DeployFakeNftsScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA} -vvvv
execute-sep :; forge script script/sepolia/Execute.s.sol:ExecuteScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv

## POLYGON MUMBAI
deploy-mum-aclmanager :; forge script script/mumbai/DeployAclManager.s.sol:DeployACLManagerScript --fork-url ${RPC_MUMBAI} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-mum-wallet :; forge script script/mumbai/DeployWallet.s.sol:DeployWalletScript --fork-url ${RPC_MUMBAI} --broadcast --private-key ${PRIVATE_KEY} -vvvv 
deploy-mum-periphery :; forge script script/mumbai/DeployPeriphery.s.sol:DeployPeripheryScript --fork-url ${RPC_MUMBAI} --broadcast --private-key ${PRIVATE_KEY}  -vvvv
deploy-mum-protocol :; forge script script/mumbai/DeployProtocol.s.sol:DeployProtocolScript --fork-url ${RPC_MUMBAI} --broadcast --private-key ${PRIVATE_KEY}  -vvvv
deploy-mum-modules :; forge script script/mumbai/DeployModules.s.sol:DeployModulesScript --fork-url ${RPC_MUMBAI} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-mum-allow :; forge script script/mumbai/DeployAllowNFT.s.sol:DeployAllowNFTScript --fork-url ${RPC_MUMBAI} --broadcast --private-key ${PRIVATE_KEY} -vvvv

