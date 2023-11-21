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

  function test_mathUtils_calculateLinearInterest() public {
    uint256 interest = MathUtils.calculateLinearInterest(10, uint40(block.timestamp - 1000));
    assertEq(1000000000000000000000000000, interest);
  }

  function test_mathUtils_calculateCompoundedInterest() public {
    uint256 interest = MathUtils.calculateCompoundedInterest(
      10,
      uint40(block.timestamp - 1000),
      block.timestamp
    );
    assertEq(1000000000000000000000000000, interest);
  }

  function test_mathUtils_maxOf() public {
    uint256 expected = MathUtils.maxOf(2, 5);
    assertEq(expected, 5);
  }

  function test_mathUtils_minOf() public {
    uint256 expected = MathUtils.minOf(2, 5);
    assertEq(expected, 2);
  }
}
