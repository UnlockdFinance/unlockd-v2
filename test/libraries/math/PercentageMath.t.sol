// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';
import {PercentageMath} from '../../../src/libraries/math/PercentageMath.sol';

contract PercentageMathTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_percentageMath_percentMul() public {
    uint256 expected = PercentageMath.percentMul(1000000, 1000);
    assertEq(expected, 100000);
  }

  function test_percentageMath_percentDiv() public {
    uint256 expected = PercentageMath.percentDiv(1000000, 1000);
    assertEq(expected, 10000000);
  }
}
