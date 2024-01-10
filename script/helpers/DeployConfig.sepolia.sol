// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library DeployConfig {
  // We need to check the ids becuase there is some issues on the diferent networks
  uint256 public constant CHAINID = 11155111;
  // ************************ TOKENS ************************
  // https://testnets.opensea.io/  to wrap
  address public constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
  // https://staging.aave.com/faucet/ to mint
  address public constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;

  address public constant MAXAPY = 0x8607F61246753Ff3189243Cc1768E8Cf453A4534;
  // ************************ RESERVOIR ************************
  // @dev location addresses https://github.com/reservoirprotocol/indexer/blob/main/packages/sdk/src/router/v6/addresses.ts
  address public constant RESERVOIR_ROUTER = 0x1aeD60A97192157fDA7fb26267A439d523d09c5e;
  address public constant RESERVOIR_ETH = 0x0000000000000000000000000000000000000000;

  // ************************ APP ************************
  address public constant DEPLOYER = 0x96A18D883F8C93A1ac8bd7c2388e5c56F72Ba8c6;
  address public constant SIGNER = 0xDe637231FcEdF554e0B012ee01A2E9bf40b85183; // This address need to come from DEFENDER
  address public constant TREASURY = 0x7a9e9e6af96dD88a02df420FBe693ee69e7A6DE7;
  address public constant ADMIN = 0x7a9e9e6af96dD88a02df420FBe693ee69e7A6DE7;

  // ************************ GNOSIS SAFE ************************
  // SEPOLIA https://github.com/search?q=repo%3Asafe-global%2Fsafe-deployments%2011155111&type=code
  address public constant GNOSIS_SAFE_PROXY_FACTORY = 0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC;
  address public constant GNOSIS_SAFE_TEMPLATE = 0x69f4D1788e39c87893C980c06EdF4b7f686e2938;
  address public constant COMPATIBILITY_FALLBACK_HANDLER =
    0x017062a1dE2FE6b99BE3d9d37841FeD19F573804;

  // Sepolia doesnt' have CRYPTO PUNK
  address public constant CRYPTOPUNK = 0x0000000000000000000000000000000000000000;
}
