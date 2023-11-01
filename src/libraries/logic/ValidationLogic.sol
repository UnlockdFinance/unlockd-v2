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
import {console} from 'forge-std/console.sol';

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

  struct ValidateBorrowLocalVars {
    uint256 currentLtv;
    uint256 currentLiquidationThreshold;
    uint256 amountOfCollateralNeeded;
    uint256 userCollateralBalance;
    uint256 userBorrowBalance;
    uint256 availableLiquidity;
    uint256 healthFactor;
    bool isActive;
    bool isFrozen;
    bool borrowingEnabled;
    bool stableRateBorrowingEnabled;
    bool nftIsActive;
    bool nftIsFrozen;
    address loanReserveAsset;
    address loanBorrower;
  }

  function validateHealtyLoan(
    address user,
    uint256 amount,
    address reserveOracle,
    DataTypes.Loan memory loan,
    DataTypes.ReserveData memory reserve,
    DataTypes.SignLoanConfig memory loanConfig
  ) internal view {
    ValidateBorrowLocalVars memory vars;

    (
      vars.userCollateralBalance,
      vars.userBorrowBalance,
      vars.healthFactor,
      vars.currentLtv,
      vars.currentLiquidationThreshold
    ) = GenericLogic.calculateLoanData(loan.loanId, user, reserveOracle, reserve, loanConfig);

    // This is the total assets needed
    if (loanConfig.totalAssets > 0) {
      if (vars.currentLtv > 9999) {
        revert Errors.InvalidCurrentLtv();
      }
      if (vars.currentLiquidationThreshold > 9999) {
        revert Errors.InvalidCurrentLiquidationThreshold();
      }

      if (vars.userCollateralBalance == 0) revert Errors.InvalidUserCollateralBalance();

      if (loan.state != DataTypes.LoanState.ACTIVE) {
        revert Errors.LoanNotActive();
      }
      // ........................ DEBUG MODE ....................................
      // console.log('-----------------------------------------------');
      // console.log('Total Collateral Balance : ', vars.userCollateralBalance);
      // console.log('User Borrow Balance      : ', vars.userBorrowBalance);
      // console.log('HF                       : ', vars.healthFactor);
      // console.log('LTV                      : ', vars.currentLtv);
      // console.log('LIQUIDATION              ; ', GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      // console.log('AMOUNT REPAY             ; ', amount);
      // console.log('-----------------------------------------------');

      if (vars.healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
        revert Errors.UnhealtyLoan();
      }

      //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
      //LTV is calculated in percentage
      vars.amountOfCollateralNeeded = (vars.userBorrowBalance + amount).percentDiv(vars.currentLtv);

      if (vars.amountOfCollateralNeeded > vars.userCollateralBalance) {
        revert Errors.LowCollateral();
      }
    }
  }

  function validateAuctionLoan(
    address user,
    uint256 amount,
    address reserveOracle,
    DataTypes.Loan memory loan,
    DataTypes.ReserveData memory reserve,
    DataTypes.SignLoanConfig memory loanConfig
  ) internal view returns (uint256 userPendingDebt) {
    console.log('ENTRA AQUI?');
    (uint256 userCollateralBalance, uint256 userTotalDebt, uint256 healthFactor) = GenericLogic
      .calculateLoanDataRepay(loan.loanId, amount, user, reserveOracle, reserve, loanConfig);

    // This is the total assets needed
    if (loanConfig.totalAssets > 0) {
      if (loanConfig.aggLtv > 9999) {
        revert Errors.InvalidCurrentLtv();
      }
      if (loanConfig.aggLiquidationThreshold > 9999) {
        revert Errors.InvalidCurrentLiquidationThreshold();
      }

      if (userCollateralBalance == 0) revert Errors.InvalidUserCollateralBalance();

      // ........................ DEBUG MODE ....................................
      console.log('> ----------------------------------------------- <');
      console.log('Total Collateral Balance : ', userCollateralBalance);
      console.log('userTotalDebt            : ', userTotalDebt);
      console.log('HF                       : ', healthFactor);
      console.log('LTV                      : ', loanConfig.aggLtv);
      console.log('LIQUIDATION              ; ', GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      console.log('AMOUNT REPAY             ; ', amount);
      console.log('-----------------------------------------------');

      if (healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
        revert Errors.UnhealtyLoan();
      }
    } else {
      // If is the last asset we check if the amount it's equal to the current debt
      if (userTotalDebt > 0 && userTotalDebt != amount) revert Errors.UnhealtyLoan();
    }
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
    // Validate owner

    // Check if the starting time is not in the past

    Errors.verifyNotExpiredTimestamp(orderTimeframeEndtime, block.timestamp);

    // Check if it is a biddable order
    if (loanTotalAssets != totalAssets + 1) revert Errors.NotEqualTotalAssets();

    // if (loanState != DataTypes.LoanState.ACTIVE) {
    //   revert Errors.LoanNotActive();
    // }
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
    // if (loanState == DataTypes.LoanState.FREEZE) {
    //   revert Errors.LoanNotActive();
    // }

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
    // if (loanState == DataTypes.LoanState.FREEZE) {
    //   revert Errors.LoanNotActive();
    // }
  }

  function validateHealthyHealthFactor(uint256 hf) internal pure {
    if (hf <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      revert Errors.UnhealtyLoan();
    }
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
    // Check the current status

    // if (loanState != DataTypes.LoanState.ACTIVE) {
    //   revert Errors.LoanNotActive();
    // }
    // Finalized auction can't be cancelled

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

  struct ValidateBidLiquidationOrderParams {
    address reserveOracle;
    uint256 endTime;
    DataTypes.Loan loan;
    DataTypes.ReserveData reserve;
    DataTypes.SignLoanConfig loanConfig;
  }

  function validateBidLiquidationOrder(
    ValidateBidLiquidationOrderParams memory params
  ) internal view {
    (, , uint256 hf) = GenericLogic.calculateLoanDataRepay(
      params.loan.loanId,
      0,
      params.loan.owner,
      params.reserveOracle,
      params.reserve,
      params.loanConfig
    );

    if (hf > GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      revert Errors.HealtyLoan();
    }
  }
}
