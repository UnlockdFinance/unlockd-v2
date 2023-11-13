// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';

contract ReserveOracleTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_reserveOracle_addAggregators() internal {}

  function test_reserveOracle_addAggregator() internal {}

  function test_reserveOracle_removeAggregator() internal {}

  function test_reserveOracle_getAggregator() internal {}

  function test_reserveOracle_getAssetPrice() internal {}

  function test_reserveOracle_getLatestTimestamp() internal {}
}
