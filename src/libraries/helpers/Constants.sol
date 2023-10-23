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
}
