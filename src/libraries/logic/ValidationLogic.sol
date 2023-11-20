// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {IAllowedControllers} from '@unlockd-wallet/src/interfaces/IAllowedControllers.sol';

import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';

import {GenericLogic} from './GenericLogic.sol';
import {OrderLogic} from './OrderLogic.sol';

import {Errors} from '../helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

import {IInterestRate} from '../../interfaces/tokens/IInterestRate.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';

// import {console} from 'forge-std/console.sol';

/**
 * @title ValidationLogic library
 * @author Unlockd
 * @notice Implements functions to validate the different actions of the protocol
 */
library ValidationLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function validateLockAsset(
    bytes32 assetId,
    address owner,
    address allowedController,
    address protocolOwner,
    DataTypes.Asset memory asset
  ) internal view {
    if (IERC721(asset.collection).ownerOf(asset.tokenId) != owner) {
      revert Errors.NotAssetOwner();
    }

    if (IAllowedControllers(allowedController).isAllowedCollection(asset.collection) == false) {
      revert Errors.CollectionNotAllowed();
    }
    // Check if is not already locked
    if (IProtocolOwner(protocolOwner).isAssetLocked(assetId) == true) {
      revert Errors.AssetLocked();
    }
  }

  function validateOwnerAsset(address owner, address collection, uint256 tokenId) internal view {
    if (IERC721(collection).ownerOf(tokenId) != owner) {
      revert Errors.NotAssetOwner();
    }
  }

  struct ValidateLoanStateParams {
    address user;
    uint256 amount;
    uint256 price;
    address reserveOracle;
    DataTypes.ReserveData reserve;
    DataTypes.SignLoanConfig loanConfig;
  }

  function validateFutureLoanState(
    ValidateLoanStateParams memory params
  ) internal view returns (uint256 userPendingDebt) {
    // We always need to define the LTV and the Liquidation threshold
    if (params.loanConfig.aggLtv == 0 || params.loanConfig.aggLtv > 9999) {
      revert Errors.InvalidCurrentLtv();
    }
    if (
      params.loanConfig.aggLiquidationThreshold == 0 ||
      params.loanConfig.aggLiquidationThreshold > 9999
    ) {
      revert Errors.InvalidCurrentLiquidationThreshold();
    }

    // We calculate the current debt and the HF
    (uint256 userCollateralBalance, uint256 userTotalDebt, uint256 healthFactor) = GenericLogic
      .calculateFutureLoanData(
        params.loanConfig.loanId,
        params.amount,
        params.price,
        params.user,
        params.reserveOracle,
        params.reserve,
        params.loanConfig
      );

    // ........................ DEBUG MODE ....................................
    // console.log('> validateFutureLoanState ----------------------------------------------- <');
    // console.log('Total Collateral Balance : ', userCollateralBalance);
    // console.log('userTotalDebt            : ', userTotalDebt);
    // console.log('HF                       : ', healthFactor);
    // console.log('LTV                      : ', params.loanConfig.aggLtv);
    // console.log('LIQUIDATION              ; ', GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    // console.log('AMOUNT REPAY             ; ', params.amount);
    // console.log('-----------------------------------------------');

    if (healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      revert Errors.UnhealtyLoan();
    }

    if (params.loanConfig.totalAssets == 0 && userTotalDebt > params.amount) {
      revert Errors.UnhealtyLoan();
    }
    return userTotalDebt;
  }

  function validateFutureHasUnhealtyLoanState(
    ValidateLoanStateParams memory params
  ) internal view returns (uint256 userPendingDebt) {
    // We always need to define the LTV and the Liquidation threshold
    if (params.loanConfig.aggLtv == 0 || params.loanConfig.aggLtv > 9999) {
      revert Errors.InvalidCurrentLtv();
    }
    if (
      params.loanConfig.aggLiquidationThreshold == 0 ||
      params.loanConfig.aggLiquidationThreshold > 9999
    ) {
      revert Errors.InvalidCurrentLiquidationThreshold();
    }

    // We calculate the current debt and the HF
    (uint256 userCollateralBalance, uint256 userTotalDebt, uint256 healthFactor) = GenericLogic
      .calculateFutureLoanData(
        params.loanConfig.loanId,
        params.amount,
        params.price,
        params.user,
        params.reserveOracle,
        params.reserve,
        params.loanConfig
      );

    // ........................ DEBUG MODE ....................................
    // console.log(
    //   '> validateFutureUnhealtyLoanState ----------------------------------------------- <'
    // );
    // console.log('Total Collateral Balance : ', userCollateralBalance);
    // console.log('userTotalDebt            : ', userTotalDebt);
    // console.log('HF                       : ', healthFactor);
    // console.log('LTV                      : ', params.loanConfig.aggLtv);
    // console.log('LIQUIDATION              ; ', GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    // console.log('AMOUNT REPAY             ; ', params.amount);
    // console.log('-----------------------------------------------');

    if (healthFactor > GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      revert Errors.HealtyLoan();
    }
    if (params.loanConfig.totalAssets == 0 && userTotalDebt < params.amount) {
      revert Errors.HealtyLoan();
    }
    return userTotalDebt;
  }

  function validateRepay(
    bytes32 loanId,
    address user,
    uint256 amount,
    address reserveOracle,
    DataTypes.ReserveData memory reserve
  ) internal view {
    // Check allowance to perform the payment to the UToken
    uint256 loanDebtInBaseCurrency = GenericLogic.calculateLoanDebt(
      loanId,
      user,
      reserveOracle,
      reserve
    );

    if (amount > loanDebtInBaseCurrency) {
      revert Errors.AmountExceedsDebt();
    }
  }

  ///////////////////////////////////////////////////////
  // Validation Market Orders
  ///////////////////////////////////////////////////////

  function validateOrderBid(
    uint256 totalAssets,
    DataTypes.OrderType orderType,
    uint40 orderTimeframeEndtime,
    uint88 loanTotalAssets,
    DataTypes.LoanState loanState
  ) internal view {
    if (
      orderType == DataTypes.OrderType.TYPE_FIXED_PRICE ||
      orderType == DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION
    ) {
      revert Errors.OrderNotAllowed();
    }

    // Check if the starting time is not in the past
    Errors.verifyNotExpiredTimestamp(orderTimeframeEndtime, block.timestamp);

    // Check if it is a biddable order
    if (loanTotalAssets != totalAssets + 1) revert Errors.NotEqualTotalAssets();
  }

  function validateBuyNow(
    uint256 totalAssets,
    DataTypes.Order memory order,
    uint88 loanTotalAssets,
    DataTypes.LoanState loanState
  ) internal view {
    if (
      order.orderType == DataTypes.OrderType.TYPE_AUCTION ||
      order.orderType == DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION
    ) {
      revert Errors.OrderNotAllowed();
    }
    if (loanTotalAssets != totalAssets + 1) revert Errors.NotEqualTotalAssets();
    if (order.owner == address(0)) revert Errors.InvalidOrderOwner();

    if (order.orderType == DataTypes.OrderType.TYPE_FIXED_PRICE_AND_AUCTION) {
      // Check time only for typefixed price
      Errors.verifyNotExpiredTimestamp(order.timeframe.endTime, block.timestamp);
    }
  }

  function validateOrderClaim(
    uint256 totalAssets,
    DataTypes.Order memory order,
    uint88 loanTotalAssets,
    DataTypes.LoanState loanState
  ) internal view {
    if (
      order.orderType == DataTypes.OrderType.TYPE_FIXED_PRICE ||
      order.orderType == DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION
    ) {
      revert Errors.OrderNotAllowed();
    }
    if (order.owner == address(0)) revert Errors.InvalidOrderOwner();
    if (order.bid.buyer == address(0)) revert Errors.InvalidOrderBuyer();

    // Check if is auction over
    Errors.verifyExpiredTimestamp(order.timeframe.endTime, block.timestamp);

    if (loanTotalAssets != totalAssets + 1) revert Errors.NotEqualTotalAssets();
  }

  struct ValidateCreateOrderMarketParams {
    DataTypes.OrderType orderType;
    uint256 endAmount;
    uint256 startAmount;
    uint256 endTime;
    uint256 startTime;
    uint256 debtToSell;
    uint256 currentTimestamp;
  }

  function validateCreateOrderMarket(ValidateCreateOrderMarketParams memory params) internal pure {
    // Check order not liquidation
    if (params.orderType == DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION) {
      revert Errors.OrderNotAllowed();
    }
    if (
      params.orderType == DataTypes.OrderType.TYPE_FIXED_PRICE ||
      params.orderType == DataTypes.OrderType.TYPE_FIXED_PRICE_AND_AUCTION
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
      params.orderType == DataTypes.OrderType.TYPE_AUCTION ||
      params.orderType == DataTypes.OrderType.TYPE_FIXED_PRICE_AND_AUCTION
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
    DataTypes.LoanState loanState,
    address orderOwner,
    DataTypes.OrderType orderType,
    uint40 orderTimeframeEndTime
  ) internal view {
    // Only ORDER OWNER
    if (msgSender != orderOwner) {
      revert Errors.NotEqualOrderOwner();
    }

    if (
      orderType == DataTypes.OrderType.TYPE_FIXED_PRICE_AND_AUCTION ||
      orderType == DataTypes.OrderType.TYPE_AUCTION
    ) {
      // Check time only for typefixed price
      Errors.verifyNotExpiredTimestamp(orderTimeframeEndTime, block.timestamp);
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
    if (loan.totalAssets != totalAssets + 1) revert Errors.NotEqualTotalAssets();
    if (order.orderType != DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION)
      revert Errors.OrderNotAllowed();

    Errors.verifyNotExpiredTimestamp(order.timeframe.endTime, block.timestamp);
    if (totalAmount == 0) revert Errors.InvalidTotalAmount();
    if (totalAmount < minBid) revert Errors.InvalidParams();
  }
}
