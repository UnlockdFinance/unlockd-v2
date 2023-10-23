// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

library Config {
  uint256 constant chainIdSepolia = 11155111;
  uint256 constant chainIdMainnet = 1;

  struct ChainConfig {
    uint256 chainId;
    string chainName;
    uint256 blockNumber;
    address weth;
    address reservoirRouter;
    address reservoirETH;
    address gnosisSafeProxyFactory;
    address gnosisSafeTemplate;
    address compativilityFallbackHandler;
    address cryptoPunk;
  }

  function getConfig(uint256 chainId) internal pure returns (ChainConfig memory) {
    // Mainnet
    if (chainId == chainIdMainnet)
      return
        ChainConfig({
          chainId: chainIdMainnet,
          chainName: 'mainnet',
          blockNumber: 17271292,
          weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
          reservoirRouter: 0xC2c862322E9c97D6244a3506655DA95F05246Fd8,
          reservoirETH: 0x0000000000000000000000000000000000000000,
          gnosisSafeProxyFactory: 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2,
          gnosisSafeTemplate: 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552,
          compativilityFallbackHandler: 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4,
          cryptoPunk: 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB
        });
    // SEPOLIA by DEFAULT
    return
      ChainConfig({
        chainId: chainIdSepolia,
        chainName: 'sepolia',
        blockNumber: 4470394,
        weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
        reservoirRouter: 0x1aeD60A97192157fDA7fb26267A439d523d09c5e,
        reservoirETH: 0x0000000000000000000000000000000000000000,
        gnosisSafeProxyFactory: 0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC,
        gnosisSafeTemplate: 0x69f4D1788e39c87893C980c06EdF4b7f686e2938,
        compativilityFallbackHandler: 0x017062a1dE2FE6b99BE3d9d37841FeD19F573804,
        cryptoPunk: 0x0000000000000000000000000000000000000000
      });
  }
}
