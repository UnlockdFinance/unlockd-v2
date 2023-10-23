// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IInterestRate} from '../../interfaces/tokens/IInterestRate.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {WadRayMath} from '../../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../../libraries/math/PercentageMath.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';

/**
 * @title InterestRate contract
 * @notice Implements the calculation of the interest rates depending on the reserve state
 * @dev The model of interest rate is based on 2 slopes, one before the `OPTIMAL_UTILIZATION_RATE`
 * point of utilization and another from that one to 100%
 * @author Unlockd
 *
 */
contract InterestRate is IInterestRate {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  address public immutable _aclManager;

  modifier onlyAdmin() {
    if (IACLManager(_aclManager).isUTokenAdmin(msg.sender) == false) {
      revert Errors.UTokenAccessDenied();
    }
    _;
  }

  /**
   * @dev this constant represents the utilization rate at which the pool aims to obtain most competitive borrow rates.
   * Expressed in ray
   *
   */
  uint256 public OPTIMAL_UTILIZATION_RATE;

  /**
   * @dev This constant represents the excess utilization rate above the optimal. It's always equal to
   * 1-optimal utilization rate. Added as a constant here for gas optimizations.
   * Expressed in ray
   *
   */

  uint256 public EXCESS_UTILIZATION_RATE;

  // Base variable borrow rate when Utilization rate = 0. Expressed in ray
  uint256 internal _baseVariableBorrowRate;

  // Slope of the variable interest curve when utilization rate > 0 and <= OPTIMAL_UTILIZATION_RATE. Expressed in ray
  uint256 internal _variableRateSlope1;

  // Slope of the variable interest curve when utilization rate > OPTIMAL_UTILIZATION_RATE. Expressed in ray
  uint256 internal _variableRateSlope2;

  constructor(
    address aclManager,
    uint256 optimalUtilizationRate_,
    uint256 baseVariableBorrowRate_,
    uint256 variableRateSlope1_,
    uint256 variableRateSlope2_
  ) {
    _aclManager = aclManager;
    OPTIMAL_UTILIZATION_RATE = optimalUtilizationRate_;
    EXCESS_UTILIZATION_RATE = WadRayMath.ray() - (optimalUtilizationRate_);
    _baseVariableBorrowRate = baseVariableBorrowRate_;
    _variableRateSlope1 = variableRateSlope1_;
    _variableRateSlope2 = variableRateSlope2_;
  }

  function variableRateSlope1() external view returns (uint256) {
    return _variableRateSlope1;
  }

  function variableRateSlope2() external view returns (uint256) {
    return _variableRateSlope2;
  }

  /**
   * @dev Get the variable borrow rate
   * @return the base variable borrow rate
   *
   */
  function baseVariableBorrowRate() external view override returns (uint256) {
    return _baseVariableBorrowRate;
  }

  /**
   * @dev Get the maximum variable borrow rate
   * @return the maximum variable borrow rate
   *
   */
  function getMaxVariableBorrowRate() external view override returns (uint256) {
    return _baseVariableBorrowRate + (_variableRateSlope1) + (_variableRateSlope2);
  }

  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param uToken The uToken address
   * @param liquidityAdded The liquidity added during the operation
   * @param liquidityTaken The liquidity taken during the operation
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param reserveFactor The reserve portion of the interest that goes to the treasury of the market
   * @return The liquidity rate, the stable borrow rate and the variable borrow rate
   *
   */
  function calculateInterestRates(
    address uToken,
    uint256 liquidityAdded,
    uint256 liquidityTaken,
    uint256 totalVariableDebt,
    uint256 reserveFactor
  ) external view override returns (uint256, uint256) {
    //avoid stack too deep
    uint256 availableLiquidity = IUToken(uToken).totalSupply() +
      (liquidityAdded) -
      (liquidityTaken);
    return calculateInterestRates(availableLiquidity, totalVariableDebt, reserveFactor);
  }

  struct CalcInterestRatesLocalVars {
    uint256 totalDebt;
    uint256 currentVariableBorrowRate;
    uint256 currentLiquidityRate;
    uint256 utilizationRate;
  }

  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations.
   * NOTE This function is kept for compatibility with the previous DefaultInterestRateStrategy interface.
   * New protocol implementation uses the new calculateInterestRates() interface
   * @param availableLiquidity The liquidity available in the corresponding uToken
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param reserveFactor The reserve portion of the interest that goes to the treasury of the market
   * @return currentLiquidityRate The liquidity rate
   * @return currentVariableBorrowRate The variable borrow rate
   *
   */
  function calculateInterestRates(
    uint256 availableLiquidity,
    uint256 totalVariableDebt,
    uint256 reserveFactor
  ) public view override returns (uint256 currentLiquidityRate, uint256 currentVariableBorrowRate) {
    uint256 utilizationRate = totalVariableDebt == 0
      ? 0
      : totalVariableDebt.rayDiv(availableLiquidity + (totalVariableDebt));

    if (utilizationRate > OPTIMAL_UTILIZATION_RATE) {
      uint256 excessUtilizationRateRatio;
      unchecked {
        excessUtilizationRateRatio =
          utilizationRate -
          (OPTIMAL_UTILIZATION_RATE).rayDiv(EXCESS_UTILIZATION_RATE);
      }
      currentVariableBorrowRate =
        _baseVariableBorrowRate +
        (_variableRateSlope1) +
        (_variableRateSlope2.rayMul(excessUtilizationRateRatio));
    } else {
      currentVariableBorrowRate =
        _baseVariableBorrowRate +
        (utilizationRate.rayMul(_variableRateSlope1).rayDiv(OPTIMAL_UTILIZATION_RATE));
    }

    currentLiquidityRate = _getOverallBorrowRate(totalVariableDebt, currentVariableBorrowRate)
      .rayMul(utilizationRate)
      .percentMul(PercentageMath.PERCENTAGE_FACTOR - (reserveFactor));
  }

  /**
   * @dev Calculates the overall borrow rate as the weighted average between the total variable debt and total stable debt
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param currentVariableBorrowRate The current variable borrow rate of the reserve
   * @return overallBorrowRate The weighted averaged borrow rate
   *
   */
  function _getOverallBorrowRate(
    uint256 totalVariableDebt,
    uint256 currentVariableBorrowRate
  ) internal pure returns (uint256 overallBorrowRate) {
    if (totalVariableDebt == 0) return 0;

    uint256 weightedVariableRate = totalVariableDebt.wadToRay().rayMul(currentVariableBorrowRate);

    overallBorrowRate = weightedVariableRate.rayDiv(totalVariableDebt.wadToRay());
  }

  function configInterestRate(
    uint256 optimalUtilizationRate_,
    uint256 baseVariableBorrowRate_,
    uint256 variableRateSlope1_,
    uint256 variableRateSlope2_
  ) public onlyAdmin {
    OPTIMAL_UTILIZATION_RATE = optimalUtilizationRate_;
    EXCESS_UTILIZATION_RATE = WadRayMath.ray() - (optimalUtilizationRate_);
    _baseVariableBorrowRate = baseVariableBorrowRate_;
    _variableRateSlope1 = variableRateSlope1_;
    _variableRateSlope2 = variableRateSlope2_;
  }
}
