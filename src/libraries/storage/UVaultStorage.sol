// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {DataTypes} from '../../types/DataTypes.sol';

/**
 * @title UVaultStorage
 * @author Unlockd
 * @notice Storage for the Vault
 */
contract UVaultStorage {
  /////////////////////////////////////////
  //  Configurations
  /////////////////////////////////////////
  address internal _sharesTokenImp;

  /////////////////////////////////////////
  //  Data
  /////////////////////////////////////////
  // UnderlyingAsset -> Reserve
  mapping(address => DataTypes.ReserveData) public reserves;
  // UnderlyingAsset -> Reserve
  mapping(address => DataTypes.MarketBalance) public balances;

  /////////////////////////////////////////
  //  Borrow Balances
  /////////////////////////////////////////

  mapping(address => mapping(bytes32 => uint256)) internal borrowScaledBalanceByLoanId;
  mapping(address => mapping(address => uint256)) internal borrowScaledBalanceByUser;
}
