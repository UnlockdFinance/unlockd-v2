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
deploy-sep-aclmanager :; forge script script/sepolia/DeployAclManager.s.sol:DeployACLManagerScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv
deploy-sep-wallet :; forge script script/sepolia/DeployWallet.s.sol:DeployWalletScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv 
deploy-sep-protocol :; forge script script/sepolia/DeployProtocol.s.sol:DeployProtocolScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --gas-estimate-multiplier 200 -vvvv
deploy-sep-modules :; forge script script/sepolia/DeployModules.s.sol:DeployModulesScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA} -vvvv
deploy-sep-allow :; forge script script/sepolia/DeployAllowNFT.s.sol:DeployAllowNFTScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} -vvvv

# Helpers
deploy-sep-maxapy :; forge script script/sepolia/DeployMaxApy.s.sol:DeployMaxApyScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA} -vvvv

deploy-sep-nft :; forge script script/sepolia/DeployFakeNFT.s.sol:DeployFakeNftsScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA} -vvvv
deploy-sep-fake-utoken :; forge script script/sepolia/DeployFakeUToken.s.sol:DeployFakeUTokenScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA} -vvvv
deploy-sep-fake-sign :; forge script script/sepolia/DeployFakeSigner.s.sol:DeployFakeSignerScript --fork-url ${RPC_SEPOLIA} --broadcast --private-key ${PRIVATE_KEY} --verify --etherscan-api-key ${ETHERSCAN_API_KEY_SEPOLIA} -vvvv
