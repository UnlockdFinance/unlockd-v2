// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Constants} from '../../libraries/helpers/Constants.sol';

interface IManagerModule {
  ////////////////////////////////////
  // SAFE ERC721
  event SetSafeERC721(address indexed safeERC721);

  function setSafeERC721(address safeERC721) external;

  function getSafeERC721() external view returns (address);

  ////////////////////////////////////
  // RESERVE ORACLE
  event SetReserveOracle(address indexed oracle);

  function setReserveOracle(address oracle) external;

  function getReserveOracle() external returns (address);

  ////////////////////////////////////
  // SIGNER
  event SetSigner(address indexed signer);

  function setSigner(address signer) external;

  function getSigner() external view returns (address);

  ////////////////////////////////////
  // WALLET REGISTRY
  event SetWalletRegistry(address indexed walletRegistry);

  function setWalletRegistry(address walletRegistry) external;

  function getWalletRegistry() external view returns (address);

  ////////////////////////////////////
  // ALLOWED CONTROLLERS

  event SetAllowedControllers(address indexed allowedControllers);

  function setAllowedControllers(address allowedControllers) external;

  function getAllowedController() external view returns (address);

  ////////////////////////////////////
  // ALLOWED CONTROLLERS

  event AllowCollectionReserveType(address indexed collection, uint256 indexed reserveType);

  function allowCollectionReserveType(
    address collection,
    Constants.ReserveType reserveType
  ) external;

  function getCollectionReserveType(
    address collection
  ) external view returns (Constants.ReserveType);

  ////////////////////////////////////
  // UTokenFactory
  event SetUTokenFactory(address indexed uToken);

  function setUTokenFactory(address uTokenFactory) external;

  function getUTokenFactory() external view returns (address);

  ////////////////////////////////////
  // Adapters

  event ActivateMarketAdapter(address indexed market);

  event DisableMarketAdapter(address indexed market);

  function addMarketAdapters(address adapter, bool active) external;

  function isMarketAdapterActive(address adapter) external view returns (uint256);

  ////////////////////////////////////
  // EMERGENCY

  event EmergencyFreezeLoan(bytes32 loanId);

  function emergencyFreezeLoan(bytes32 loanId) external;

  event EmergencyActivateLoan(bytes32 loanId);

  function emergencyActivateLoan(bytes32 loanId) external;

  event EmergencyBlockLoan(bytes32 loanId);

  function emergencyBlockLoan(bytes32 loanId) external;

  event EmergencyUpdateEndTimeAuction(bytes32 orderId, uint40 newEndTime);

  function emergencyUpdateEndTimeAuction(bytes32 orderId, uint40 newEndTime) external;
}
