// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library DeployConfig {
  // We need to check the ids becuase there is some issues on the diferent networks
  uint256 public constant CHAINID = 1;
  // ************************ TOKENS ************************
  // https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  // https://etherscan.io/token/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  address public constant MAXAPY = 0x0000000000000000000000000000000000000000;
  // ************************ RESERVOIR ************************
  // @dev location addresses https://github.com/reservoirprotocol/indexer/blob/main/packages/sdk/src/router/v6/addresses.ts
  address public constant RESERVOIR_ROUTER = 0xC2c862322E9c97D6244a3506655DA95F05246Fd8;
  address public constant RESERVOIR_ETH = 0x0000000000000000000000000000000000000000;

  // ************************ APP ************************
  address public constant DEPLOYER = 0x879a14507653AD96C5c3727DbE8C88C14057772B;
  address public constant SIGNER = 0x89cD4b49AC82D9b3F879a8dc3E21373559Ac3Fb3; // This address need to come from DEFENDER

  // ************************ GNOSIS SAFE ************************
  // SEPOLIA https://github.com/search?q=repo%3Asafe-global%2Fsafe-deployments%2011155111&type=code
  address public constant GNOSIS_SAFE_PROXY_FACTORY = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
  address public constant GNOSIS_SAFE_TEMPLATE = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
  address public constant COMPATIBILITY_FALLBACK_HANDLER =
    0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

  // Sepolia doesnt' have CRYPTO PUNK
  address public constant CRYPTOPUNK = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
}
