// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IInterestRate} from '../../interfaces/tokens/IInterestRate.sol';

import {DelegateCall} from '../utils/DelegateCall.sol';
import {MathUtils} from '../math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {Errors} from '../helpers/Errors.sol';
import {DataTypes, Constants} from '../../types/DataTypes.sol';
import {IStrategy} from '../../interfaces/IStrategy.sol';
import {ScaledToken} from '../tokens/ScaledToken.sol';

// import {console} from 'forge-std/console.sol';

/**
 * @title ReserveLogic library
 * @author Unlockd
 * @notice Implements the logic to update the reserves state
 */
library ReserveLogic {
  using WadRayMath for uint256;
  using WadRayMath for uint128;
  using PercentageMath for uint256;
  using SafeCast for uint256;
  using SafeERC20 for IERC20;
  using DelegateCall for address;
  using ReserveLogic for DataTypes.ReserveData;

  // See `IPool` for descriptions
  event ReserveDataUpdated(
    address indexed underlyingAsset,
    uint256 liquidityRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @notice Returns the ongoing normalized income for the reserve.
   * @dev A value of 1e27 means there is no income. As time passes, the income is accrued
   * @dev A value of 2*1e27 means for each unit of asset one unit of income has been accrued
   * @param reserve The reserve object
   * @return The normalized income, expressed in ray
   */
  function getNormalizedIncome(
    DataTypes.ReserveData storage reserve
  ) internal view returns (uint256) {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == block.timestamp) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.liquidityIndex;
    } else {
      return
        MathUtils.calculateLinearInterest(reserve.currentLiquidityRate, timestamp).rayMul(
          reserve.liquidityIndex
        );
    }
  }

  /**
   * @notice Returns the ongoing normalized variable debt for the reserve.
   * @dev A value of 1e27 means there is no debt. As time passes, the debt is accrued
   * @dev A value of 2*1e27 means that for each unit of debt, one unit worth of interest has been accumulated
   * @param reserve The reserve object
   * @return The normalized variable debt, expressed in ray
   */
  function getNormalizedDebt(
    DataTypes.ReserveData storage reserve
  ) internal view returns (uint256) {
    uint40 timestamp = reserve.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == block.timestamp) {
      //if the index was updated in the same block, no need to perform any calculation
      return reserve.variableBorrowIndex;
    } else {
      return
        MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, timestamp).rayMul(
          reserve.variableBorrowIndex
        );
    }
  }

  /**
   * @notice Updates the liquidity cumulative index and the variable borrow index.
   */
  function updateState(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balance
  ) internal {
    // If time didn't pass since last stored timestamp, skip state update
    //solium-disable-next-line
    if (reserve.lastUpdateTimestamp == uint40(block.timestamp)) {
      return;
    }

    _updateIndexes(reserve, balance);
    _updateBalances(reserve, balance);

    //solium-disable-next-line
    reserve.lastUpdateTimestamp = uint40(block.timestamp);
  }

  function _updateBalances(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balance
  ) internal {
    // We calculate the current value based on the current scaled
    uint256 totalBalance = balance.totalSupplyScaledNotInvested;
    balance.totalSupplyAssets = totalBalance.rayMul(reserve.getNormalizedIncome()).toUint128();

    if (reserve.strategyAddress != address(0)) {
      balance.totalSupplyAssets += IStrategy(reserve.strategyAddress)
        .balanceOf(address(this))
        .toUint128();
    }
  }

  /**
   * @notice Accumulates a predefined amount of asset to the reserve as a fixed, instantaneous income. Used for example
   * to accumulate the flashloan fee to the reserve, and spread it between all the suppliers.
   * @param reserve The reserve object
   * @param totalLiquidity The total liquidity available in the reserve
   * @param amount The amount to accumulate
   * @return The next liquidity index of the reserve
   */
  function cumulateToLiquidityIndex(
    DataTypes.ReserveData storage reserve,
    uint256 totalLiquidity,
    uint256 amount
  ) internal returns (uint256) {
    //next liquidity index is calculated this way: `((amount / totalLiquidity) + 1) * liquidityIndex`
    //division `amount / totalLiquidity` done in ray for precision
    uint256 result = (amount.wadToRay().rayDiv(totalLiquidity.wadToRay()) + WadRayMath.RAY).rayMul(
      reserve.liquidityIndex
    );
    reserve.liquidityIndex = result.toUint128();
    return result;
  }

  /**
   * @notice Initializes a reserve.
   */
  function init(
    DataTypes.ReserveData storage reserve,
    address underlyingAsset,
    Constants.ReserveType reserveType,
    address scaledTokenAddress,
    address interestRateAddress,
    address strategyAddress,
    uint16 reserveFactor
  ) internal {
    reserve.liquidityIndex = uint128(WadRayMath.RAY);
    reserve.variableBorrowIndex = uint128(WadRayMath.RAY);
    reserve.reserveFactor = reserveFactor;
    reserve.scaledTokenAddress = scaledTokenAddress;
    reserve.interestRateAddress = interestRateAddress;
    reserve.strategyAddress = strategyAddress;
    reserve.underlyingAsset = underlyingAsset;
    reserve.decimals = ScaledToken(scaledTokenAddress).decimals();
    reserve.reserveType = reserveType;
    reserve.reserveState = Constants.ReserveState.STOPPED;
    reserve.lastUpdateTimestamp = uint40(block.timestamp);
  }

  struct UpdateInterestRatesLocalVars {
    uint256 nextLiquidityRate;
    uint256 nextVariableRate;
    uint256 totalVariableDebt;
  }

  /**
   * @notice Updates the reserve current stable borrow rate, the current variable borrow rate and the current liquidity rate.
   * @param reserve The reserve reserve to be updated
   * @param totalBorrowScaled total borrowed scaled
   * @param totalSupplyAssets total balance
   * @param liquidityAdded The amount of liquidity added to the protocol (supply or repay) in the previous action
   * @param liquidityTaken The amount of liquidity taken from the protocol (redeem or borrow)
   */
  function updateInterestRates(
    DataTypes.ReserveData storage reserve,
    uint128 totalBorrowScaled,
    uint128 totalSupplyAssets,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    UpdateInterestRatesLocalVars memory vars;

    vars.totalVariableDebt = totalBorrowScaled.rayMul(reserve.variableBorrowIndex);

    // We calculate the interest rate of all the amount include the current deposited on the strategy
    (vars.nextLiquidityRate, vars.nextVariableRate) = IInterestRate(reserve.interestRateAddress)
      .calculateInterestRates(
        IInterestRate.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalVariableDebt: vars.totalVariableDebt, // Need to be the real not the scaled
          reserveFactor: reserve.reserveFactor,
          totalSupplyAssets: totalSupplyAssets // Need to be the real not the scaled
        })
      );

    reserve.currentLiquidityRate = vars.nextLiquidityRate.toUint128();
    reserve.currentVariableBorrowRate = vars.nextVariableRate.toUint128();

    emit ReserveDataUpdated(
      reserve.underlyingAsset,
      vars.nextLiquidityRate,
      vars.nextVariableRate,
      reserve.liquidityIndex,
      reserve.variableBorrowIndex
    );
  }

  struct AccrueToTreasuryLocalVars {
    uint256 prevTotalStableDebt;
    uint256 prevTotalVariableDebt;
    uint256 currTotalVariableDebt;
    uint256 cumulatedStableInterest;
    uint256 totalDebtAccrued;
    uint256 amountToMint;
  }

  /**
   * @notice Updates the reserve indexes and the timestamp of the update.
   */
  function _updateIndexes(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balance
  ) internal {
    // Only cumulating on the supply side if there is any income being produced
    // The case of Reserve Factor 100% is not a problem (currentLiquidityRate == 0),
    // as liquidity index should not be updated
    if (reserve.currentLiquidityRate != 0) {
      uint256 cumulatedLiquidityInterest = MathUtils.calculateLinearInterest(
        reserve.currentLiquidityRate,
        reserve.lastUpdateTimestamp
      );
      reserve.liquidityIndex = cumulatedLiquidityInterest
        .rayMul(reserve.liquidityIndex)
        .toUint128();
    }

    if (balance.totalBorrowScaled != 0) {
      uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(
        reserve.currentVariableBorrowRate,
        reserve.lastUpdateTimestamp
      );
      reserve.variableBorrowIndex = cumulatedVariableBorrowInterest
        .rayMul(reserve.variableBorrowIndex)
        .toUint128();
    }
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // DEBT
  /////////////////////////////////////////////////////////////////////////////////////////////////
  function increaseDebt(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balances,
    uint256 amount
  ) internal returns (uint256) {
    uint256 amountScaled = amount.rayDiv(reserve.variableBorrowIndex);
    if (amountScaled == 0) {
      revert Errors.InvalidAmount();
    }
    balances.totalBorrowScaled += amountScaled.toUint128();
    // Updates general balances
    return amountScaled;
  }

  function decreaseDebt(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balances,
    uint256 amount
  ) internal returns (uint256) {
    uint256 amountScaled = amount.rayDiv(reserve.variableBorrowIndex);
    if (amountScaled == 0) {
      revert Errors.InvalidAmount();
    }
    // Updates general balances
    balances.totalBorrowScaled -= amountScaled.toUint128();

    return amountScaled;
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // SHARES
  /////////////////////////////////////////////////////////////////////////////////////////////////

  function mintScaled(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balances,
    address user,
    uint256 amount
  ) internal {
    IERC20(reserve.underlyingAsset).safeTransferFrom(user, address(this), amount);
    // MINT SHARES TO THE USER
    uint256 scaledAmount = ScaledToken(reserve.scaledTokenAddress).mint(
      user,
      amount,
      reserve.liquidityIndex
    );
    // calculate the new amounts
    balances.totalSupplyAssets += amount.toUint128();
    balances.totalSupplyScaled += scaledAmount.toUint128();
    balances.totalSupplyScaledNotInvested += scaledAmount.toUint128();
  }

  function burnScaled(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balances,
    address user,
    uint256 amount
  ) internal {
    // Check shares
    uint256 scaledAmount = ScaledToken(reserve.scaledTokenAddress).burn(
      user,
      amount,
      reserve.liquidityIndex
    );

    balances.totalSupplyAssets -= amount.toUint128();
    balances.totalSupplyScaled -= scaledAmount.toUint128();
    balances.totalSupplyScaledNotInvested -= scaledAmount.toUint128();
    // Transfer the amount to the user
    IERC20(reserve.underlyingAsset).safeTransfer(user, amount);
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // INVEST ON ESTRATEGY
  /////////////////////////////////////////////////////////////////////////////////////////////////

  function strategyInvest(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balances,
    uint256 amount
  ) internal {
    // If there is no strategy just ignore
    if (reserve.strategyAddress == address(0)) return;
    uint256 totalSupplyScaledNotInvested = balances.totalSupplyScaledNotInvested;
    uint256 totalSupplyNotInvested = totalSupplyScaledNotInvested.rayMul(
      reserve.getNormalizedIncome()
    );
    uint256 amountToInvest = IStrategy(reserve.strategyAddress).calculateAmountToSupply(
      totalSupplyNotInvested,
      address(this),
      amount
    );

    if (amountToInvest > 0) {
      IStrategy.StrategyConfig memory config = IStrategy(reserve.strategyAddress).getConfig();
      reserve.strategyAddress.functionDelegateCall(
        abi.encodeWithSelector(
          IStrategy.supply.selector,
          config.vault,
          config.asset,
          address(this),
          amountToInvest,
          IStrategy(reserve.strategyAddress).getConfig()
        )
      );

      balances.totalSupplyScaledNotInvested -= amountToInvest
        .rayDiv(reserve.liquidityIndex)
        .toUint128();
    }
  }

  function strategyWithdraw(
    DataTypes.ReserveData storage reserve,
    DataTypes.MarketBalance storage balances,
    uint256 amount
  ) internal {
    if (reserve.strategyAddress == address(0)) return;
    uint256 totalSupplyScaledNotInvested = balances.totalSupplyScaledNotInvested;
    uint256 totalSupplyNotInvested = totalSupplyScaledNotInvested.rayMul(
      reserve.getNormalizedIncome()
    );

    uint256 amountNeed = IStrategy(reserve.strategyAddress).calculateAmountToWithdraw(
      totalSupplyNotInvested,
      address(this),
      amount
    );

    if (amountNeed > 0) {
      IStrategy.StrategyConfig memory config = IStrategy(reserve.strategyAddress).getConfig();
      bytes memory returnData = reserve.strategyAddress.functionDelegateCall(
        abi.encodeWithSelector(IStrategy.withdraw.selector, config.vault, address(this), amountNeed)
      );

      // Because of the slippage we need to ensure the exact withdraw
      uint256 amountWithdrawed = abi.decode(returnData, (uint256));

      balances.totalSupplyScaledNotInvested += amountWithdrawed
        .rayDiv(reserve.liquidityIndex)
        .toUint128();
    }
  }
}
