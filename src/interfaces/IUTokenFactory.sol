// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../types/DataTypes.sol';
import {Constants} from '../libraries/helpers/Constants.sol';

interface IUTokenFactory {
  struct CreateMarketParams {
    address interestRateAddress;
    address strategyAddress;
    uint16 reserveFactor;
    address underlyingAsset;
    Constants.ReserveType reserveType;
    uint8 decimals;
    string tokenName;
    string tokenSymbol;
  }

  //////////////////////////////////
  // ONLY ADMIN

  function createMarket(CreateMarketParams calldata params) external;

  //////////////////////////////////
  // PUBLIC

  function supply(address underlyingAsset, uint256 amount, address onBehalf) external;

  function withdraw(address underlyingAsset, uint256 amount, address onBehalf) external;

  //////////////////////////////////
  // ONLY PROTOCOL

  function borrow(
    address underlyingAsset,
    bytes32 loanId,
    uint256 amount,
    address to,
    address onBehalfOf
  ) external;

  function repay(
    address underlyingAsset,
    bytes32 loanId,
    uint256 amount,
    address from,
    address onBehalfOf
  ) external;

  function updateState(address underlyingAsset) external;

  // EMERGENCY
  function updateReserveState(
    address underlyingAsset,
    Constants.ReserveState reserveState
  ) external;

  //////////////////////////////////
  // GETTERS
  function validateReserveType(
    Constants.ReserveType currentReserveType,
    Constants.ReserveType reserveType
  ) external view returns (bool);

  function getReserveData(
    address underlyingAsset
  ) external view returns (DataTypes.ReserveData memory);

  function getTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256);

  function getDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256);

  function getBalances(
    address underlyingAsset
  ) external view returns (DataTypes.MarketBalance memory);

  function totalSupply(address underlyingAsset) external view returns (uint256);

  function totalAvailableSupply(address underlyingAsset) external view returns (uint256);

  function totalSupplyNotInvested(address underlyingAsset) external view returns (uint256);
}
