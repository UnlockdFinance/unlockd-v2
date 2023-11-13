// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';
import {MathUtils} from '../../../src/libraries/math/MathUtils.sol';

contract MathUtilsTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_mathUtils_calculateLinearInterest() internal {}

  function test_mathUtils_calculateCompoundedInterest() internal {}

  function test_mathUtils_maxOf() public {
    uint256 expected = MathUtils.maxOf(2, 5);
    assertEq(expected, 5);
  }

  function test_mathUtils_minOf() public {
    uint256 expected = MathUtils.minOf(2, 5);
    assertEq(expected, 2);
  }
}
