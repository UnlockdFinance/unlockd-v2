// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/**
 * @title IInterestRate interface
 * @dev Interface for the calculation of the interest rates
 * @author Unlockd
 */
interface IInterestRate {
  struct CalculateInterestRatesParams {
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalVariableDebt;
    uint256 totalSupplyAssets;
    uint256 reserveFactor;
  }

  /**
   * @dev Get the variable borrow rate
   * @return the base variable borrow rate
   *
   */
  function baseVariableBorrowRate() external view returns (uint256);

  /**
   * @dev Get the maximum variable borrow rate
   * @return the maximum variable borrow rate
   *
   */
  function getMaxVariableBorrowRate() external view returns (uint256);

  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param params params needed to calculate the interest rate
   */
  function calculateInterestRates(
    CalculateInterestRatesParams memory params
  ) external view returns (uint256, uint256);

  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param availableLiquidity The available liquidity for the reserve
   * @param totalVariableDebt The total borrowed from the reserve at a variable rate
   * @param reserveFactor The reserve portion of the interest that goes to the treasury of the market
   *
   */
  function calculateInterestRates(
    uint256 availableLiquidity,
    uint256 totalVariableDebt,
    uint256 reserveFactor
  ) external view returns (uint256 currentLiquidityRate, uint256 currentVariableBorrowRate);
}
