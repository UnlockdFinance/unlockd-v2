// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../test-utils/base/Base.sol';

contract WadRayMathTest is Base {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant HALF_WAD = 0.5e18;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant HALF_RAY = 0.5e27;

  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_wadRayMath_ray() internal {}

  function test_wadRayMath_wad() internal {}

  function test_wadRayMath_halfRay() internal {}

  function test_wadRayMath_halfWad() internal {}

  function test_wadRayMath_wadMul() internal {}

  function test_wadRayMath_wadDiv() internal {}

  function test_wadRayMath_rayMul() internal {}

  function test_wadRayMath_rayDiv() internal {}

  function test_wadRayMath_rayToWad() internal {}

  function test_wadRayMath_wadToRay() internal {}
}
