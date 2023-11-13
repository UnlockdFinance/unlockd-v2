// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../test-utils/base/Base.sol';

contract BuyNowLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_buyNow_calculations_wrong_uToken() internal {}

  function test_buyNow_calculations_marketprice_lower() internal {}
}
