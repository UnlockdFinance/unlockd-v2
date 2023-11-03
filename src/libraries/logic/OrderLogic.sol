// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {GenericLogic, Errors} from './GenericLogic.sol';
import {PercentageMath} from '../math/PercentageMath.sol';

import {console} from 'forge-std/console.sol';

library OrderLogic {
  using SafeERC20 for IERC20;
  using PercentageMath for uint256;

  event OrderCreated(
    address indexed owner,
    bytes32 indexed orderId,
    bytes32 indexed loanId,
    DataTypes.OrderType orderType
  );

  struct ParamsCreateOrder {
    DataTypes.OrderType orderType;
    address owner;
    bytes32 orderId;
    bytes32 loanId;
    bytes32 assetId;
    uint128 startAmount;
    uint128 endAmount;
    uint128 debtToSell;
    uint40 startTime;
    uint40 endTime;
  }

  /**
   * @dev generate unique loanId, because the nonce is x address and is incremental it should be unique.
   * */
  function generateId(bytes32 assetId, bytes32 loanId) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(loanId, assetId));
  }

  /**
   * @dev creates a new order
   */
  function createOrder(DataTypes.Order storage order, ParamsCreateOrder memory params) internal {
    unchecked {
      order.orderId = params.orderId;
      order.owner = params.owner;
      order.orderType = params.orderType;
      order.offer = DataTypes.OfferItem({
        loanId: params.loanId,
        assetId: params.assetId,
        startAmount: params.startAmount,
        endAmount: params.endAmount,
        // debToSell is the % of the final bid or payed that is going to repay debt.
        debtToSell: params.debtToSell
      });

      order.timeframe = DataTypes.Timeframe({startTime: params.startTime, endTime: params.endTime});
    }
    emit OrderCreated(params.owner, params.orderId, params.loanId, params.orderType);
  }

  struct BorrowByBidderParams {
    bytes32 loanId;
    address owner;
    address uToken;
    uint256 amountOfDebt;
    uint256 assetPrice;
    uint256 assetLtv;
  }

  function borrowByBidder(BorrowByBidderParams memory params) internal {
    uint256 maxAmountToBorrow = GenericLogic.calculateAvailableBorrows(
      params.assetPrice,
      0,
      params.assetLtv
    );
    if (params.amountOfDebt >= maxAmountToBorrow) {
      revert Errors.AmountExceedsDebt();
    }

    IUToken(params.uToken).borrowOnBelhalf(
      params.loanId,
      params.amountOfDebt,
      address(this),
      params.owner
    );
  }

  struct RefundBidderParams {
    bytes32 loanId;
    address owner;
    address uToken;
    address underlyingAsset;
    address reserveOracle;
    uint256 amountToPay;
    uint256 amountOfDebt;
    DataTypes.ReserveData reserve;
  }

  function refundBidder(RefundBidderParams memory params) internal {
    uint256 totalAmount = params.amountToPay + params.amountOfDebt;
    // Check if there is a loan asociated

    if (params.loanId != 0) {
      uint256 currentDebt = GenericLogic.calculateLoanDebt(
        params.loanId,
        params.owner,
        params.reserveOracle,
        params.reserve
      );
      // Check if this loan has currentDebt
      if (currentDebt > 0) {
        // We remove the current debt
        totalAmount = totalAmount - currentDebt;
        IERC20(params.underlyingAsset).approve(params.uToken, currentDebt);
        // Repay the debt
        IUToken(params.uToken).repayOnBelhalf(
          params.loanId,
          currentDebt,
          address(this),
          params.owner
        );
      }
    }
    // Return the amount to the first bidder
    IERC20(params.underlyingAsset).safeTransfer(
      params.owner,
      // We return the amount payed minus the interest of the debt
      totalAmount
    );
  }

  struct RepayOwnerDebtParams {
    address owner;
    address uToken;
    address underlyingAsset;
    bytes32 loanId;
    uint256 minBid;
  }

  function repayOwnerDebt(RepayOwnerDebtParams memory params) internal {
    // Check if there is a loan asociated
    // We repay the total debt
    IERC20(params.underlyingAsset).approve(params.uToken, params.minBid);
    // Repay the debt
    IUToken(params.uToken).repayOnBelhalf(
      params.loanId,
      params.minBid,
      address(this),
      params.owner
    );
  }

  function getMaxDebtOrDefault(
    bytes32 loanId,
    address user,
    address reserveOracle,
    uint256 defaultAmount,
    uint256 totalCollateral,
    uint256 ltv,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256 maxDebtOrDefault) {
    uint256 totalDebt = GenericLogic.calculateLoanDebt(loanId, user, reserveOracle, reserveData);

    if (totalDebt == 0) return defaultAmount;

    uint256 minAmountNeeded = GenericLogic.calculateAmountToArriveToLTV(
      totalCollateral,
      totalDebt,
      ltv
    );
    console.log('Amount NEEDED', minAmountNeeded);
    maxDebtOrDefault = minAmountNeeded > defaultAmount ? minAmountNeeded : defaultAmount;
  }

  function getMinDebtOrDefault(
    bytes32 loanId,
    address user,
    address reserveOracle,
    uint256 defaultAmount,
    uint256 totalCollateral,
    uint256 ltv,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256 minDebtOrDefault) {
    uint256 totalDebt = GenericLogic.calculateLoanDebt(loanId, user, reserveOracle, reserveData);
    if (totalDebt < defaultAmount) return totalDebt;

    uint256 minAmountNeeded = GenericLogic.calculateAmountToArriveToLTV(
      totalCollateral,
      totalDebt,
      ltv
    );

    minDebtOrDefault = minAmountNeeded < defaultAmount ? minAmountNeeded : defaultAmount;
  }

  /**
   * @dev Calculate the mind bid based on the configuration of the order and the bids
   * 0 bids then debt or startAmoun
   * 1 > bids then debt or lastBid + 1%
   * */
  function getMinBid(
    DataTypes.Order memory order,
    address reserveOracle,
    uint256 totalCollateral,
    uint256 ltv,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256) {
    if (order.countBids == 0) {
      return
        getMaxDebtOrDefault(
          order.offer.loanId,
          order.owner,
          reserveOracle,
          order.offer.startAmount,
          totalCollateral,
          ltv,
          reserveData
        );
    }
    uint256 lastBid = order.bid.amountOfDebt + order.bid.amountToPay;
    return
      getMaxDebtOrDefault(
        order.offer.loanId,
        order.owner,
        reserveOracle,
        calculateMinBid(lastBid, order.countBids),
        totalCollateral,
        ltv,
        reserveData
      );
  }

  function calculateMinBid(
    uint256 lastBid,
    uint256 countBids
  ) internal view returns (uint256 minBid) {
    minBid = countBids == 1
      ? lastBid + lastBid.percentMul(GenericLogic.FIRST_BID_INCREMENT) // At least 2.5% more than the last bid
      : lastBid + lastBid.percentMul(GenericLogic.NEXT_BID_INCREMENT); // At least %1 more than the last bid
  }

  struct RepayDebtToSellParams {
    address reserveOracle;
    address underlyingAsset;
    address uToken;
    uint256 totalAmount;
    uint256 aggLoanPrice;
    uint256 aggLtv;
  }

  function repayDebtToSell(
    DataTypes.Order memory order,
    RepayDebtToSellParams memory params,
    DataTypes.ReserveData memory reserveData
  ) internal returns (uint256) {
    uint256 debtToSell = getMaxDebtOrDefault(
      order.offer.loanId,
      order.owner,
      params.reserveOracle,
      // Calculate the % of the owner want to repay the debt
      order.offer.debtToSell > 0 ? params.totalAmount.percentMul(order.offer.debtToSell) : 0,
      params.aggLoanPrice,
      params.aggLtv,
      reserveData
    );

    if (debtToSell > 0) {
      // Repay the debt
      IERC20(params.underlyingAsset).approve(params.uToken, debtToSell);
      IUToken(params.uToken).repayOnBelhalf(
        order.offer.loanId,
        debtToSell,
        address(this),
        order.owner
      );
      // We remove from the total amount the debt repayed
      return params.totalAmount - debtToSell;
    }
    return params.totalAmount;
  }
}
