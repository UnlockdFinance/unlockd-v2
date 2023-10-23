// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {WadRayMath} from './WadRayMath.sol';
import {FixedPointMathLib} from '@solady/utils/FixedPointMathLib.sol';

library MathUtils {
  using WadRayMath for uint256;

  /// @dev Ignoring leap years
  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  /**
   * @dev Function to calculate the interest accumulated using a linear interest rate formula
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return interest The interest rate linearly accumulated during the timeDelta, in ray
   *
   */

  function calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256 interest) {
    //solium-disable-next-line
    uint256 timeDifference = block.timestamp - (uint256(lastUpdateTimestamp));

    interest =
      FixedPointMathLib.mulDiv(rate, timeDifference, SECONDS_PER_YEAR) +
      (WadRayMath.ray());
  }

  /**
   * @dev Function to calculate the interest using a compounded interest rate formula
   * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
   *
   *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
   *
   * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great gas cost reductions
   * The whitepaper contains reference to the approximation and a table showing the margin of error per different time periods
   *
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return compoundedInterest The interest rate compounded during the timeDelta, in ray
   *
   */
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256 compoundedInterest) {
    //solium-disable-next-line
    uint256 exp = currentTimestamp - (uint256(lastUpdateTimestamp));

    if (exp == 0) {
      return WadRayMath.ray();
    }

    uint256 expMinusOne;
    uint256 expMinusTwo;
    uint256 ratePerSecond;

    unchecked {
      expMinusOne = exp - 1;
      expMinusTwo = exp > 2 ? exp - 2 : 0;

      ratePerSecond = rate / SECONDS_PER_YEAR;
    }

    uint256 basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
    uint256 basePowerThree = basePowerTwo.rayMul(ratePerSecond);

    uint256 secondTerm = (exp * (expMinusOne) * (basePowerTwo)) >> 1;
    uint256 thirdTerm = (exp * (expMinusOne) * (expMinusTwo) * (basePowerThree)) / 6;

    compoundedInterest = WadRayMath.ray() + (ratePerSecond * (exp)) + (secondTerm) + (thirdTerm);
  }

  /**
   * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
   * @param rate The interest rate (in ray)
   * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
   *
   */
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
  }

  /**
   * @dev max between two numbers
   * @param x number one
   * @param y number two
   */
  function maxOf(uint256 x, uint256 y) internal pure returns (uint256 max) {
    assembly {
      max := xor(x, mul(xor(x, y), gt(y, x)))
    }
  }

  /**
   * @dev min between two numbers
   * @param x number one
   * @param y number two
   */
  function minOf(uint256 x, uint256 y) internal pure returns (uint256 min) {
    /// @solidity memory-safe-assembly
    assembly {
      min := xor(x, mul(xor(x, y), lt(y, x)))
    }
  }
}
