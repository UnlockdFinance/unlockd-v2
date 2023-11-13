// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../test-utils/base/Base.sol';

contract MathUtilsTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_mathUtils_calculateLinearInterest() internal {}

  function test_mathUtils_calculateCompoundedInterest() internal {}

  function test_mathUtils_maxOf() internal {}

  function test_mathUtils_minOf() internal {}
}
