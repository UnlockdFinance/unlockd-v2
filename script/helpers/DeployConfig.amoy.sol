// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library DeployConfig {
  // We need to check the ids becuase there is some issues on the diferent networks
  uint256 public constant CHAINID = 80002;
  // ************************ TOKENS ************************
  // https://testnets.opensea.io/  to wrap
  address public constant WETH = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;
  // https://staging.aave.com/faucet/?marketName=proto_mumbai_v3 to mint
  address public constant USDC = 0x52D800ca262522580CeBAD275395ca6e7598C014;

  address public constant MAXAPY = 0x0000000000000000000000000000000000000000;
  // ************************ RESERVOIR ************************
  // @dev location addresses https://github.com/reservoirprotocol/indexer/blob/main/packages/sdk/src/router/v6/addresses.ts
  address public constant RESERVOIR_ROUTER = 0x1aed60a97192157fda7fb26267a439d523d09c5e;
  address public constant RESERVOIR_ETH = 0x0000000000000000000000000000000000000000;

  // ************************ APP ************************
  address public constant DEPLOYER = 0x96A18D883F8C93A1ac8bd7c2388e5c56F72Ba8c6;
  address public constant SIGNER = 0x83C9e37f1F74eCf1C61d96F440F7C1dD2Ca3f9D3; // This address need to come from DEFENDER

  // ************************ GNOSIS SAFE ************************
  // SEPOLIA https://github.com/search?q=repo%3Asafe-global%2Fsafe-deployments%2011155111&type=code
  address public constant GNOSIS_SAFE_PROXY_FACTORY = 0x0000000000000000000000000000000000000000;
  address public constant GNOSIS_SAFE_TEMPLATE = 0x0000000000000000000000000000000000000000;
  address public constant COMPATIBILITY_FALLBACK_HANDLER =
    0x0000000000000000000000000000000000000000;

  // Sepolia doesnt' have CRYPTO PUNK
  address public constant CRYPTOPUNK = 0x0000000000000000000000000000000000000000;
}