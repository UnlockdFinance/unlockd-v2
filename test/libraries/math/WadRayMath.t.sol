// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';

import {WadRayMath} from '../../../src/libraries/math/WadRayMath.sol';

contract WadRayMathTest is Base {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant HALF_WAD = 0.5e18;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant HALF_RAY = 0.5e27;

  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_wadRayMath() internal {
    assertEq(WadRayMath.ray(), RAY);
    assertEq(WadRayMath.wad(), WAD);
    assertEq(WadRayMath.halfRay(), HALF_RAY);
    assertEq(WadRayMath.halfWad(), HALF_WAD);
  }

  function test_wadRayMath_wadMul() internal {
    uint256 mul = WadRayMath.wadMul(1 ** 27, 2);
    assertEq(mul, 2 ** 27);
  }

  function test_wadRayMath_wadDiv() internal {
    uint256 div = WadRayMath.wadDiv(10 ** 27, 2);
    assertEq(div, 5 ** 27);
  }

  function test_wadRayMath_rayMul() internal {
    uint256 mul = WadRayMath.rayMul(1 ** 18, 2);
    assertEq(mul, 2 ** 18);
  }

  function test_wadRayMath_rayDiv() internal {
    uint256 div = WadRayMath.rayDiv(10 ** 18, 2);
    assertEq(div, 5 ** 18);
  }

  function test_wadRayMath_rayToWad() internal {
    uint256 result = WadRayMath.rayToWad(2 ** 27);
    assertEq(result, 2 ** 18);
  }

  function test_wadRayMath_wadToRay() internal {
    uint256 result = WadRayMath.rayToWad(2 ** 18);
    assertEq(result, 2 ** 27);
  }
}
