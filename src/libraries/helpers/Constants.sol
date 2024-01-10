// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library Constants {
  ////////////////////////////////////////////
  // Reentrancy Guard for modules
  ////////////////////////////////////////////
  uint256 internal constant REENTRANCYLOCK__UNLOCKED = 0;
  uint256 internal constant REENTRANCYLOCK__LOCKED = 2;

  ////////////////////////////////////////////
  // Modules Configuration
  ////////////////////////////////////////////

  uint256 internal constant MAX_EXTERNAL_SINGLE_PROXY_MODULEID = 499_999;
  uint256 internal constant MAX_EXTERNAL_MODULEID = 999_999;

  ////////////////////////////////////////////
  // List Modules
  ////////////////////////////////////////////

  // Public single-proxy modules
  uint256 internal constant MODULEID__INSTALLER = 1;
  uint256 internal constant MODULEID__MANAGER = 2;
  uint256 internal constant MODULEID__ACTION = 3;
  uint256 internal constant MODULEID__AUCTION = 4;
  uint256 internal constant MODULEID__MARKET = 5;
  uint256 internal constant MODULEID__BUYNOW = 6;
  uint256 internal constant MODULEID__SELLNOW = 7;

  ////////////////////////////////////////////
  // RESERVE STATE
  ////////////////////////////////////////////

  enum ReserveState {
    STOPPED, // No supply, No borrow
    FREEZED, // No supply, No withdraw , No borrow, No repay
    ACTIVE // All OK
  }

  ////////////////////////////////////////////
  // LOAN STATE
  ////////////////////////////////////////////

  enum LoanState {
    BLOCKED,
    ACTIVE,
    FREEZE
  }

  ////////////////////////////////////////////
  // GRUP RESERVE TYPE
  ////////////////////////////////////////////

  enum ReserveType {
    DISABLED, // Disabled collection
    ALL, // All the assets with the exception SPECIAL
    STABLE, // For the stable coins
    COMMON, // Common coins WETH etc ...
    SPECIAL // Only if the collection is also isolated to one asset token
  }

  ////////////////////////////////////////////
  // ORDER TYPE
  ////////////////////////////////////////////

  enum OrderType {
    TYPE_LIQUIDATION_AUCTION,
    //Auction with BIDs
    TYPE_AUCTION,
    // Fixed price only buynow function
    TYPE_FIXED_PRICE,
    // Fixed price and auction with bids
    TYPE_FIXED_PRICE_AND_AUCTION
  }
}
