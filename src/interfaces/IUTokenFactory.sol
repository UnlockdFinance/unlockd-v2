// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../types/DataTypes.sol';
import {Constants} from '../libraries/helpers/Constants.sol';

interface IUTokenFactory {
  //////////////////////////////////
  // EVENS

  event MarketCreated(
    address indexed underlyingAsset,
    address indexed interestRate,
    address indexed strategy,
    address sharesToken
  );

  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  event Deposit(
    address indexed user,
    address indexed onBehalfOf,
    address indexed underlyingAsset,
    uint256 amount
  );
  event Withdraw(
    address indexed user,
    address indexed to,
    address indexed underlyingAsset,
    uint256 amount
  );

  event Borrow(
    address indexed iniciator,
    address indexed onBehalfOf,
    address indexed underlyingAsset,
    uint256 amount,
    bytes32 loanId,
    uint256 borrowRate
  );

  event Repay(
    address indexed iniciator,
    address indexed onBehalfOf,
    address indexed underlyingAsset,
    uint256 amount,
    bytes32 loanId,
    uint256 borrowRate
  );

  event UpdateReserveState(address indexed underlyingAsset, uint256 newState);

  event DisableReserveStrategy(address indexed underlyingAsset);

  event UpdateReserveStrategy(address indexed underlyingAsset, address indexed newStrategy);
  /**
   * @dev Emitted when the pause is triggered.
   */
  event Paused();

  /**
   * @dev Emitted when the pause is lifted.
   */
  event Unpaused();

  //////////////////////////////////
  // STRUCTS

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

  function deposit(address underlyingAsset, uint256 amount, address onBehalf) external;

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

  function getScaledToken(address underlyingAsset) external view returns (address);

  function validateReserveType(
    Constants.ReserveType currentReserveType,
    Constants.ReserveType reserveType
  ) external view returns (bool);

  function getReserveData(
    address underlyingAsset
  ) external view returns (DataTypes.ReserveData memory);

  function getScaledTotalDebtMarket(address underlyingAsset) external view returns (uint256);

  function getTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256);

  function getScaledTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256);

  function getDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256);

  function getScaledDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256);

  //////////// GET /////////////////////

  function getBalances(
    address underlyingAsset
  ) external view returns (DataTypes.MarketBalance memory);

  function getBalanceByUser(address underlyingAsset, address user) external view returns (uint256);

  function getScaledBalanceByUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256);

  function totalSupply(address underlyingAsset) external view returns (uint256);

  function totalAvailableSupply(address underlyingAsset) external view returns (uint256);

  function totalSupplyNotInvested(address underlyingAsset) external view returns (uint256);
}
