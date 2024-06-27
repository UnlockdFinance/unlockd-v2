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
deploy-sep-wrapper-polytrade :; forge script script/sepolia/DeployPolytrade.s.sol:DeployPolytradeScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv 

deploy-sep-nft :; forge script script/sepolia/DeployFakeNFT.s.sol:DeployFakeNftsScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv
execute-sep :; forge script script/sepolia/Execute.s.sol:ExecuteScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv

## POLYGON MUMBAI
deploy-amoy-aclmanager :; forge script script/amoy/DeployAclManager.s.sol:DeployACLManagerScript --fork-url ${RPC_AMOY} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-amoy-periphery :; forge script script/amoy/DeployPeriphery.s.sol:DeployPeripheryScript --fork-url ${RPC_AMOY} --broadcast --private-key ${PRIVATE_KEY}  -vvvv
deploy-amoy-protocol :; forge script script/amoy/DeployProtocol.s.sol:DeployProtocolScript --fork-url ${RPC_AMOY} --broadcast --private-key ${PRIVATE_KEY}  -vvvv
deploy-amoy-base-wallet :; forge script script/amoy/DeployBaseWallet.s.sol:DeployBaseWalletScript --fork-url ${RPC_AMOY} --broadcast --private-key ${PRIVATE_KEY} -vvvv 
deploy-amoy-modules :; forge script script/amoy/DeployModules.s.sol:DeployModulesScript --fork-url ${RPC_AMOY} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-amoy-allow :; forge script script/amoy/DeployAllowNFT.s.sol:DeployAllowNFTScript --fork-url ${RPC_AMOY} --broadcast --private-key ${PRIVATE_KEY} -vvvv

