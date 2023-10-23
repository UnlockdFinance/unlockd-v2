// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IManagerModule {
  // Updated by Protocol Admin
  event SetReserveOracle(address indexed oracle);
  event SetSigner(address indexed signer);
  event SetWalletRegistry(address indexed walletRegistry);
  event SetAllowedControllers(address indexed allowedControllers);

  // Updated by governance
  event ActivateUToken(address indexed uToken);
  event DisableUToken(address indexed uToken);
  event ActivateMarketAdapter(address indexed market);
  event DisableMarketAdapter(address indexed market);
  event ActivateSigner(address indexed signer);

  function getReserveOracle() external returns (address);

  function setReserveOracle(address oracle) external;

  function setSigner(address signer) external;

  function setWalletRegistry(address walletRegistry) external;

  function addUToken(address uToken, bool active) external;

  function addMarketAdapters(address adapter, bool active) external;
}
