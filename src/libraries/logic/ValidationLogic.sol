// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {IAllowedControllers} from '@unlockd-wallet/src/interfaces/IAllowedControllers.sol';
import {Constants} from '../helpers/Constants.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {ReserveConfiguration} from '../configuration/ReserveConfiguration.sol';
import {GenericLogic} from './GenericLogic.sol';
import {OrderLogic} from './OrderLogic.sol';

import {Errors} from '../helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

import {IInterestRate} from '../../interfaces/tokens/IInterestRate.sol';

/**
 * @title ValidationLogic library
 * @author Unlockd
 * @notice Implements functions to validate the different actions of the protocol
 */
library ValidationLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  struct ValidateLoanStateParams {
    uint256 amount;
    uint256 price;
    address reserveOracle;
    address uTokenVault;
    DataTypes.ReserveData reserve;
    DataTypes.SignLoanConfig loanConfig;
  }

  function validateFutureLoanState(ValidateLoanStateParams memory params) internal view {
    // We always need to define the LTV and the Liquidation threshold
    if (params.loanConfig.aggLtv == 0 || params.loanConfig.aggLtv > 9999) {
      revert Errors.InvalidCurrentLtv();
    }
    if (
      params.loanConfig.aggLiquidationThreshold == 0 ||
      params.loanConfig.aggLiquidationThreshold > 9999 ||
      params.loanConfig.aggLtv > params.loanConfig.aggLiquidationThreshold
    ) {
      revert Errors.InvalidCurrentLiquidationThreshold();
    }
    uint256 currentDebt = GenericLogic.calculateLoanDebt(
      params.loanConfig.loanId,
      params.uTokenVault,
      params.reserve.underlyingAsset
    );

    uint256 updatedDebt = currentDebt < params.amount ? 0 : currentDebt - params.amount;

    // We calculate the current debt and the HF
    uint256 healthFactor = GenericLogic.calculateHealthFactorFromBalances(
      params.loanConfig.totalAssets == 0 ? params.price : params.loanConfig.aggLoanPrice,
      updatedDebt,
      params.loanConfig.aggLiquidationThreshold
    );

    if (healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      revert Errors.UnhealtyLoan();
    }

    if (params.loanConfig.totalAssets == 0 && updatedDebt > 0) {
      revert Errors.UnhealtyLoan();
    }
  }

  function validateFutureUnhealtyLoanState(ValidateLoanStateParams memory params) internal view {
    // We always need to define the LTV and the Liquidation threshold
    if (params.loanConfig.aggLtv == 0 || params.loanConfig.aggLtv > 9999) {
      revert Errors.InvalidCurrentLtv();
    }
    if (
      params.loanConfig.aggLiquidationThreshold == 0 ||
      params.loanConfig.aggLiquidationThreshold > 9999 ||
      params.loanConfig.aggLtv > params.loanConfig.aggLiquidationThreshold
    ) {
      revert Errors.InvalidCurrentLiquidationThreshold();
    }

    uint256 currentDebt = GenericLogic.calculateLoanDebt(
      params.loanConfig.loanId,
      params.uTokenVault,
      params.reserve.underlyingAsset
    );

    uint256 updatedDebt = currentDebt < params.amount ? 0 : currentDebt - params.amount;

    uint256 healthFactor = GenericLogic.calculateHealthFactorFromBalances(
      params.loanConfig.totalAssets == 0 ? params.price : params.loanConfig.aggLoanPrice,
      updatedDebt,
      params.loanConfig.aggLiquidationThreshold
    );

    if (healthFactor > GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      revert Errors.HealtyLoan();
    }

    if (params.loanConfig.totalAssets == 0 && updatedDebt == 0) {
      revert Errors.HealtyLoan();
    }
  }

  function validateRepay(
    bytes32 loanId,
    address uTokenVault,
    uint256 amount,
    DataTypes.ReserveData memory reserve
  ) internal view {
    // Check allowance to perform the payment to the UToken
    uint256 loanDebt = GenericLogic.calculateLoanDebt(loanId, uTokenVault, reserve.underlyingAsset);

    if (amount > loanDebt) {
      revert Errors.AmountExceedsDebt();
    }
  }

  ///////////////////////////////////////////////////////
  // Validation Market Orders
  ///////////////////////////////////////////////////////

  function validateOrderBid(
    Constants.OrderType orderType,
    uint40 orderTimeframeEndtime,
    uint256 totalAssets,
    uint88 loanTotalAssets,
    Constants.LoanState loanState
  ) internal view {
    if (
      orderType == Constants.OrderType.TYPE_FIXED_PRICE ||
      orderType == Constants.OrderType.TYPE_LIQUIDATION_AUCTION
    ) {
      revert Errors.OrderNotAllowed();
    }
    if (loanState == Constants.LoanState.BLOCKED) {
      revert Errors.LoanBlocked();
    }
    // Check if the starting time is not in the past
    Errors.verifyNotExpiredTimestamp(orderTimeframeEndtime, block.timestamp);

    // Check if it is a biddable order
    if (loanTotalAssets != totalAssets + 1) revert Errors.LoanNotUpdated();
  }

  function validateBuyNow(
    uint256 totalAssets,
    DataTypes.Order memory order,
    uint88 loanTotalAssets,
    Constants.LoanState loanState
  ) internal view {
    if (
      order.orderType == Constants.OrderType.TYPE_AUCTION ||
      order.orderType == Constants.OrderType.TYPE_LIQUIDATION_AUCTION
    ) {
      revert Errors.OrderNotAllowed();
    }
    if (loanTotalAssets != totalAssets + 1) revert Errors.LoanNotUpdated();
    if (order.owner == address(0)) revert Errors.InvalidOrderOwner();
    if (loanState == Constants.LoanState.BLOCKED) {
      revert Errors.LoanBlocked();
    }
    if (order.orderType == Constants.OrderType.TYPE_FIXED_PRICE_AND_AUCTION) {
      // Check time only for typefixed price
      Errors.verifyNotExpiredTimestamp(order.timeframe.endTime, block.timestamp);
    }
  }

  function validateOrderClaim(
    uint256 totalAssets,
    DataTypes.Order memory order,
    uint88 loanTotalAssets,
    Constants.LoanState loanState
  ) internal view {
    if (
      order.orderType == Constants.OrderType.TYPE_FIXED_PRICE ||
      order.orderType == Constants.OrderType.TYPE_LIQUIDATION_AUCTION
    ) {
      revert Errors.OrderNotAllowed();
    }
    if (order.owner == address(0)) revert Errors.InvalidOrderOwner();
    if (order.bid.buyer == address(0)) revert Errors.InvalidOrderBuyer();

    // Check if is auction over
    Errors.verifyExpiredTimestamp(order.timeframe.endTime, block.timestamp);
    if (loanState == Constants.LoanState.BLOCKED) {
      revert Errors.LoanBlocked();
    }
    if (loanTotalAssets != totalAssets + 1) revert Errors.LoanNotUpdated();
  }

  struct ValidateCreateOrderMarketParams {
    Constants.OrderType orderType;
    Constants.LoanState loanState;
    uint256 endAmount;
    uint256 startAmount;
    uint256 endTime;
    uint256 startTime;
    uint256 debtToSell;
    uint256 currentTimestamp;
  }

  function validateCreateOrderMarket(ValidateCreateOrderMarketParams memory params) internal pure {
    if (params.loanState != Constants.LoanState.ACTIVE) {
      revert Errors.LoanNotActive();
    }
    // Check order not liquidation
    if (params.orderType == Constants.OrderType.TYPE_LIQUIDATION_AUCTION) {
      revert Errors.OrderNotAllowed();
    }
    if (
      params.orderType == Constants.OrderType.TYPE_FIXED_PRICE ||
      params.orderType == Constants.OrderType.TYPE_FIXED_PRICE_AND_AUCTION
    ) {
      if (params.endAmount == 0) {
        revert Errors.InvalidEndAmount();
      }
      if (params.startAmount == 0) {
        revert Errors.InvalidStartAmount();
      }
      if (params.startAmount > params.endAmount) {
        revert Errors.InvalidParams();
      }
    }

    if (
      params.orderType == Constants.OrderType.TYPE_AUCTION ||
      params.orderType == Constants.OrderType.TYPE_FIXED_PRICE_AND_AUCTION
    ) {
      if (params.startTime == 0) {
        revert Errors.InvalidEndTime();
      }
      if (params.endTime == 0) {
        revert Errors.InvalidStartTime();
      }
      if (params.startTime > params.endTime || params.currentTimestamp > params.endTime) {
        revert Errors.InvalidParams();
      }
    }

    // Validate value percentage
    if (params.debtToSell > PercentageMath.ONE_HUNDRED_PERCENT) {
      revert Errors.InvalidParams();
    }
  }

  function validateCancelOrderMarket(
    address msgSender,
    Constants.LoanState loanState,
    address orderOwner,
    Constants.OrderType orderType,
    uint40 orderTimeframeEndTime,
    DataTypes.Bid memory bidData
  ) internal view {
    // Only ORDER OWNER
    if (msgSender != orderOwner) {
      revert Errors.NotEqualOrderOwner();
    }

    if (loanState == Constants.LoanState.BLOCKED) {
      revert Errors.LoanBlocked();
    }

    if (
      orderType == Constants.OrderType.TYPE_FIXED_PRICE_AND_AUCTION ||
      orderType == Constants.OrderType.TYPE_AUCTION
    ) {
      // If it's expired and has buyer
      if (orderTimeframeEndTime < block.timestamp && bidData.buyer != address(0)) {
        revert Errors.TimestampExpired();
      }
    }
  }

  ///////////////////////////////////////////////////////
  // Validation Liquidation Order
  ///////////////////////////////////////////////////////

  function validateBid(
    uint256 totalAmount,
    uint256 totalAssets,
    uint256 minBid,
    DataTypes.Order memory order,
    DataTypes.Loan memory loan
  ) internal view {
    if (loan.totalAssets != totalAssets + 1) revert Errors.LoanNotUpdated();
    if (order.orderType != Constants.OrderType.TYPE_LIQUIDATION_AUCTION)
      revert Errors.OrderNotAllowed();

    Errors.verifyNotExpiredTimestamp(order.timeframe.endTime, block.timestamp);
    if (totalAmount == 0) revert Errors.InvalidTotalAmount();
    if (totalAmount < minBid) revert Errors.InvalidBidAmount();
  }

  ///////////////////////////////////////////////////////
  // Validation Vault
  ///////////////////////////////////////////////////////

  function validateVaultDeposit(
    DataTypes.ReserveData storage reserve,
    uint256 amount
  ) internal view {
    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    (, uint256 depositCap, uint256 minCap) = reserve.config.getCaps();

    if (depositCap != 0) {
      uint256 decimals = reserve.config.getDecimals();
      uint256 depositCap_ = depositCap + 10 ** decimals;

      if (amount <= minCap || amount > depositCap_) {
        revert Errors.InvalidDepositCap();
      }
    }

    (bool isActive, bool isFrozen, ) = reserve.config.getFlags();

    if (!isActive) revert Errors.PoolNotActive();
    if (isFrozen) revert Errors.PoolFrozen();
  }

  function validateVaultWithdraw(DataTypes.ReserveData memory reserve) internal pure {
    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    (bool isActive, , bool isPaused) = reserve.config.getFlags();

    if (!isActive) revert Errors.PoolNotActive();
    if (isPaused) revert Errors.PoolPaused();
  }

  function validateVaultRepay(DataTypes.ReserveData memory reserve) internal pure {
    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    (bool isActive, , bool isPaused) = reserve.config.getFlags();

    if (!isActive) revert Errors.PoolNotActive();
    if (isPaused) revert Errors.PoolPaused();
  }

  function validateVaultBorrow(DataTypes.ReserveData memory reserve, uint256 amount) internal pure {
    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    (uint256 borrowCap, , uint256 minCap) = reserve.config.getCaps();

    if (borrowCap != 0) {
      uint256 decimals = reserve.config.getDecimals();
      uint256 borrowCap_ = borrowCap * 10 ** decimals;

      if (amount <= minCap || amount > borrowCap_) {
        revert Errors.InvalidBorrowCap();
      }
    }

    (bool isActive, , bool isPaused) = reserve.config.getFlags();

    if (!isActive) revert Errors.PoolNotActive();
    if (isPaused) revert Errors.PoolPaused();
  }
}
