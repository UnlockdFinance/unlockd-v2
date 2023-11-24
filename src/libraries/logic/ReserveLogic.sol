// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {IDebtToken} from '../../interfaces/tokens/IDebtToken.sol';
import {IInterestRate} from '../../interfaces/tokens/IInterestRate.sol';
import {MathUtils} from '../math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {Errors} from '../helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

/**
 * @title ReserveLogic library
 * @author Unlockd
 * @notice Implements the logic to update the reserves state
 */
library ReserveLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using ReserveLogic for DataTypes.ReserveData;

  /**
   * @dev Emitted when the state of a reserve is updated
   * @param asset The address of the underlying asset of the reserve
   * @param liquidityRate The new liquidity rate
   * @param variableBorrowRate The new variable borrow rate
   * @param liquidityIndex The new liquidity index
   * @param variableBorrowIndex The new variable borrow index
   *
   */
  event ReserveDataUpdated(
    address indexed asset,
    uint256 liquidityRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @dev Returns the ongoing normalized income for the reserve
   * A value of 1e27 means there is no income. As time passes, the income is accrued
   * A value of 2*1e27 means for each unit of asset one unit of income has been accrued
   * @param reserve The reserve object
   * @return the normalized income. expressed in ray
   *
   */
  function getNormalizedIncome(
    DataTypes.ReserveData storage reserve
  ) internal view returns (uint256) {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == uint40(block.timestamp)) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.liquidityIndex;
    }

    return
      MathUtils.calculateLinearInterest(reserve.currentLiquidityRate, timestamp).rayMul(
        reserve.liquidityIndex
      );
  }

  /**
   * @dev Returns the ongoing normalized variable debt for the reserve
   * A value of 1e27 means there is no debt. As time passes, the income is accrued
   * A value of 2*1e27 means that for each unit of debt, one unit worth of interest has been accumulated
   * @param reserve The reserve object
   * @return The normalized variable debt. expressed in ray
   *
   */
  function getNormalizedDebt(
    DataTypes.ReserveData storage reserve
  ) internal view returns (uint256) {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == uint40(block.timestamp)) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.variableBorrowIndex;
    }

    return
      MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, timestamp).rayMul(
        reserve.variableBorrowIndex
      );
  }

  /**
   * @dev Updates the liquidity cumulative index and the variable borrow index.
   * @param reserve the reserve object
   *
   */
  function updateState(DataTypes.ReserveData storage reserve) internal returns (uint256, uint256) {
    uint256 scaledVariableDebt = IDebtToken(reserve.debtTokenAddress).scaledTotalSupply();

    uint256 previousVariableBorrowIndex = reserve.variableBorrowIndex;
    uint256 previousLiquidityIndex = reserve.liquidityIndex;
    uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;

    (uint256 newLiquidityIndex, uint256 newVariableBorrowIndex) = _updateIndexes(
      reserve,
      scaledVariableDebt,
      previousLiquidityIndex,
      previousVariableBorrowIndex,
      lastUpdatedTimestamp
    );

    return (
      _calculateAmountToMintToTreasury( // amountToMint
        reserve,
        scaledVariableDebt,
        previousVariableBorrowIndex,
        newVariableBorrowIndex,
        lastUpdatedTimestamp
      ),
      newLiquidityIndex
    );
  }

  /**
   * @dev Initializes a reserve
   * @param reserve The reserve object
   *
   */
  function init(
    DataTypes.ReserveData storage reserve,
    address underlyingAsset,
    address interestRateAddress,
    address debtTokenAddress,
    uint8 decimals,
    uint16 reserveFactor
  ) internal {
    reserve.uToken = address(this);
    reserve.underlyingAsset = underlyingAsset;
    reserve.debtTokenAddress = debtTokenAddress;
    reserve.liquidityIndex = uint128(WadRayMath.ray());
    reserve.variableBorrowIndex = uint128(WadRayMath.ray());
    reserve.interestRateAddress = interestRateAddress;
    reserve.decimals = decimals;
    reserve.reserveFactor = reserveFactor;
  }

  struct UpdateInterestRatesLocalVars {
    uint256 availableLiquidity;
    uint256 newLiquidityRate;
    uint256 newVariableRate;
    uint256 totalVariableDebt;
  }

  /**
   * @dev Updates the reserve current stable borrow rate, the current variable borrow rate and the current liquidity rate
   * @param reserve The address of the reserve to be updated
   * @param liquidityAdded The amount of liquidity added to the protocol (deposit or repay) in the previous action
   * @param liquidityTaken The amount of liquidity taken from the protocol (withdraw or borrow)
   *
   */
  function updateInterestRates(
    DataTypes.ReserveData storage reserve,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    UpdateInterestRatesLocalVars memory vars;

    vars.totalVariableDebt = IDebtToken(reserve.debtTokenAddress).scaledTotalSupply().rayMul(
      reserve.variableBorrowIndex
    );

    (vars.newLiquidityRate, vars.newVariableRate) = IInterestRate(reserve.interestRateAddress)
      .calculateInterestRates(
        address(this),
        liquidityAdded,
        liquidityTaken,
        vars.totalVariableDebt,
        reserve.reserveFactor
      );

    if (vars.newLiquidityRate > type(uint128).max) {
      revert Errors.LiquidityRateOverflow();
    }
    if (vars.newVariableRate > type(uint128).max) {
      revert Errors.BorrorRateOverflow();
    }

    reserve.currentLiquidityRate = uint128(vars.newLiquidityRate);
    reserve.currentVariableBorrowRate = uint128(vars.newVariableRate);

    emit ReserveDataUpdated(
      reserve.underlyingAsset,
      vars.newLiquidityRate,
      vars.newVariableRate,
      reserve.liquidityIndex,
      reserve.variableBorrowIndex
    );
  }

  struct MintToTreasuryLocalVars {
    uint256 currentVariableDebt;
    uint256 previousVariableDebt;
    uint256 totalDebtAccrued;
    uint256 amountToMint;
    // uint256 reserveFactor;
  }

  /**
   * @dev Mints part of the repaid interest to the reserve treasury as a function of the reserveFactor for the
   * specific asset.
   * @param reserve The reserve reserve to be updated
   * @param scaledVariableDebt The current scaled total variable debt
   * @param previousVariableBorrowIndex The variable borrow index before the last accumulation of the interest
   * @param newVariableBorrowIndex The variable borrow index after the last accumulation of the interest
   *
   */
  function _calculateAmountToMintToTreasury(
    DataTypes.ReserveData storage reserve,
    uint256 scaledVariableDebt,
    uint256 previousVariableBorrowIndex,
    uint256 newVariableBorrowIndex,
    uint40 timestamp
  ) internal view returns (uint256) {
    MintToTreasuryLocalVars memory vars;

    if (reserve.reserveFactor == 0) {
      return 0;
    }

    //calculate the last principal variable debt
    vars.previousVariableDebt = scaledVariableDebt.rayMul(previousVariableBorrowIndex);

    //calculate the new total supply after accumulation of the index
    vars.currentVariableDebt = scaledVariableDebt.rayMul(newVariableBorrowIndex);

    //debt accrued is the sum of the current debt minus the sum of the debt at the last update
    vars.totalDebtAccrued = vars.currentVariableDebt - (vars.previousVariableDebt);

    return vars.totalDebtAccrued.percentMul(reserve.reserveFactor);
  }

  /**
   * @dev Updates the reserve indexes and the timestamp of the update
   * @param reserve The reserve reserve to be updated
   * @param scaledVariableDebt The scaled variable debt
   * @param liquidityIndex The last stored liquidity index
   * @param variableBorrowIndex The last stored variable borrow index
   *
   */
  function _updateIndexes(
    DataTypes.ReserveData storage reserve,
    uint256 scaledVariableDebt,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex,
    uint40 timestamp
  ) internal returns (uint256, uint256) {
    uint256 currentLiquidityRate = reserve.currentLiquidityRate;

    uint256 newLiquidityIndex = liquidityIndex;
    uint256 newVariableBorrowIndex = variableBorrowIndex;

    // Only cumulating on the supply side if there is any income being produced
    // The case of Reserve Factor 100% is not a problem (currentLiquidityRate == 0),
    // as liquidity index should not be updated
    if (currentLiquidityRate != 0) {
      uint256 cumulatedLiquidityInterest = MathUtils.calculateLinearInterest(
        currentLiquidityRate,
        timestamp
      );
      newLiquidityIndex = cumulatedLiquidityInterest.rayMul(liquidityIndex);
      if (newLiquidityIndex > type(uint128).max) {
        revert Errors.LiquidityIndexOverflow();
      }

      reserve.liquidityIndex = uint128(newLiquidityIndex);

      //as the liquidity rate might come only from stable rate loans, we need to ensure
      //that there is actual variable debt before accumulating
      if (scaledVariableDebt != 0) {
        uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(
          reserve.currentVariableBorrowRate,
          timestamp
        );
        newVariableBorrowIndex = cumulatedVariableBorrowInterest.rayMul(variableBorrowIndex);
        if (newVariableBorrowIndex > type(uint128).max) {
          revert Errors.BorrowIndexOverflow();
        }

        reserve.variableBorrowIndex = uint128(newVariableBorrowIndex);
      }
    }

    //solium-disable-next-line
    reserve.lastUpdateTimestamp = uint40(block.timestamp);
    return (newLiquidityIndex, newVariableBorrowIndex);
  }
}
