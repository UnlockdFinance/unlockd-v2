// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library DeployConfig {
  // We need to check the ids becuase there is some issues on the diferent networks
  uint256 public constant CHAINID = 80001;
  // ************************ TOKENS ************************
  // https://testnets.opensea.io/  to wrap
  address public constant WETH = 0xa6fa4fb5f76172d178d61b04b0ecd319c5d1c0aa;
  // https://staging.aave.com/faucet/?marketName=proto_mumbai_v3 to mint
  address public constant USDC = 0x52d800ca262522580cebad275395ca6e7598c014;

  address public constant MAXAPY = 0x0000000000000000000000000000000000000000;
  // ************************ RESERVOIR ************************
  // @dev location addresses https://github.com/reservoirprotocol/indexer/blob/main/packages/sdk/src/router/v6/addresses.ts
  address public constant RESERVOIR_ROUTER = 0xc2c862322e9c97d6244a3506655da95f05246fd8;
  address public constant RESERVOIR_ETH = 0x0000000000000000000000000000000000000000;

  // ************************ APP ************************
  address public constant DEPLOYER = 0x96A18D883F8C93A1ac8bd7c2388e5c56F72Ba8c6;
  address public constant SIGNER = 0xDe637231FcEdF554e0B012ee01A2E9bf40b85183; // This address need to come from DEFENDER
  address public constant TREASURY = 0x7a9e9e6af96dD88a02df420FBe693ee69e7A6DE7;
  address public constant ADMIN = 0x7a9e9e6af96dD88a02df420FBe693ee69e7A6DE7;

  // ************************ GNOSIS SAFE ************************
  // SEPOLIA https://github.com/search?q=repo%3Asafe-global%2Fsafe-deployments%2011155111&type=code
  address public constant GNOSIS_SAFE_PROXY_FACTORY = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
  address public constant GNOSIS_SAFE_TEMPLATE = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
  address public constant COMPATIBILITY_FALLBACK_HANDLER =
    0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

  // Sepolia doesnt' have CRYPTO PUNK
  address public constant CRYPTOPUNK = 0x0000000000000000000000000000000000000000;
}
