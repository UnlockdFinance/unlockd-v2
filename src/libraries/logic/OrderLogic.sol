// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';
import {GenericLogic, Errors} from './GenericLogic.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {Constants} from '../helpers/Constants.sol';
import {MathUtils} from '../math/MathUtils.sol';

library OrderLogic {
  using SafeERC20 for IERC20;
  using PercentageMath for uint256;

  event OrderCreated(
    address indexed owner,
    bytes32 indexed orderId,
    bytes32 indexed loanId,
    Constants.OrderType orderType
  );

  struct ParamsCreateOrder {
    Constants.OrderType orderType;
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
   * @param order
   * @param params struct with params
   *  struct ParamsCreateOrder {
   *    Constants.OrderType orderType;
   *    address owner;
   *    bytes32 orderId;
   *    bytes32 loanId;
   *    bytes32 assetId;
   *    uint128 startAmount;
   *    uint128 endAmount;
   *    uint128 debtToSell;
   *    uint40 startTime;
   *    uint40 endTime;
   *  }
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

  struct ParamsUpdateOrder {
    bytes32 loanId;
    bytes32 assetId;
    uint128 minBid;
    uint40 endTime;
  }

  /**
   * @dev Change the order type to LIQUIDATION_AUCTION
   * @param order order previously created
   * @param params data needed to migrate from one order type to other
   *  struct ParamsUpdateOrder {
   *     bytes32 loanId;
   *     bytes32 assetId;
   *     uint128 minBid;
   *     uint40 endTime;
   *  }
   */
  function updateToLiquidationOrder(
    DataTypes.Order storage order,
    ParamsUpdateOrder memory params
  ) internal {
    // Check if the Loan is Unhealty
    order.orderType = Constants.OrderType.TYPE_LIQUIDATION_AUCTION;
    // Overwrite offer
    order.offer = DataTypes.OfferItem({
      loanId: params.loanId,
      assetId: params.assetId,
      startAmount: params.minBid,
      endAmount: 0,
      // debToSell is the % of the final bid or payed that is going to repay debt.
      debtToSell: 1e4
    });

    order.timeframe = DataTypes.Timeframe({startTime: 0, endTime: params.endTime});
  }

  struct BorrowByBidderParams {
    bytes32 loanId;
    address owner;
    address to;
    address underlyingAsset;
    address uTokenVault;
    uint256 amountOfDebt;
    uint256 assetPrice;
    uint256 assetLtv;
  }

  /**
   * @dev Borrow function from bidder
   * @param params data needed to migrate from one order type to other
   *  struct BorrowByBidderParams {
   *    bytes32 loanId;
   *    address owner;
   *    address to;
   *    address underlyingAsset;
   *    address uTokenVault;
   *    uint256 amountOfDebt;
   *    uint256 assetPrice;
   *    uint256 assetLtv;
   *  }
   *
   */
  function borrowByBidder(BorrowByBidderParams memory params) internal {
    if (params.loanId == 0) revert Errors.InvalidLoanId();
    uint256 maxAmountToBorrow = GenericLogic.calculateAvailableBorrows(
      params.assetPrice,
      0,
      params.assetLtv
    );
    if (params.amountOfDebt >= maxAmountToBorrow) {
      revert Errors.AmountExceedsDebt();
    }
    // Borrow on the factory
    IUTokenVault(params.uTokenVault).borrow(
      params.underlyingAsset,
      params.loanId,
      params.amountOfDebt,
      params.to,
      params.owner
    );
  }

  struct RepayDebtParams {
    address owner;
    address from;
    address underlyingAsset;
    address uTokenVault;
    bytes32 loanId;
    uint256 amount;
  }

  /**
   * @dev Repay specified debt
   * @param params data needed to migrate from one order type to other
   *  struct RepayDebtParams {
   *    address owner;
   *    address from;
   *    address underlyingAsset;
   *    address uTokenVault;
   *    bytes32 loanId;
   *    uint256 amount;
   *  }
   *
   */
  function repayDebt(RepayDebtParams memory params) internal {
    // Check if there is a loan asociated
    // We repay the total debt
    IERC20(params.underlyingAsset).approve(params.uTokenVault, params.amount);
    // Repay the debt
    IUTokenVault(params.uTokenVault).repay(
      params.underlyingAsset,
      params.loanId,
      params.amount,
      params.from,
      params.owner
    );
  }

  struct RefundBidderParams {
    bytes32 loanId;
    address owner;
    address from;
    address underlyingAsset;
    address uTokenVault;
    address reserveOracle;
    uint256 amountToPay;
    uint256 amountOfDebt;
    DataTypes.ReserveData reserve;
  }

  /**
   * @dev Refund bidder amount
   * @param params data needed to migrate from one order type to other
   *  struct RefundBidderParams {
   *    bytes32 loanId;
   *    address owner;
   *    address from;
   *    address underlyingAsset;
   *    address uTokenVault;
   *    address reserveOracle;
   *    uint256 amountToPay;
   *    uint256 amountOfDebt;
   *    DataTypes.ReserveData reserve;
   *  }
   */
  function refundBidder(RefundBidderParams memory params) internal {
    uint256 totalAmount = params.amountToPay + params.amountOfDebt;
    // Check if there is a loan asociated

    if (params.amountOfDebt > 0 && params.loanId != 0) {
      uint256 currentDebt = GenericLogic.calculateLoanDebt(
        params.loanId,
        params.uTokenVault,
        params.reserve.underlyingAsset
      );
      // Check if this loan has currentDebt
      if (currentDebt > 0) {
        /**
          WARNING : If the debt exceeds the total bid amount, we attempt to repay as much as possible. 
          However, in the rare instance where the utilization rate is exceptionally high and borrowing 
          is significantly increased, the debt could surpass the full amount.

          That's why we calculate the total amount of debt that the user is capable of repaying. 
        **/
        uint256 supportedDebt = MathUtils.minOf(currentDebt, totalAmount);
        // We remove the current debt
        totalAmount = totalAmount - supportedDebt;

        repayDebt(
          RepayDebtParams({
            loanId: params.loanId,
            owner: params.owner,
            from: params.from,
            amount: supportedDebt,
            underlyingAsset: params.underlyingAsset,
            uTokenVault: params.uTokenVault
          })
        );
      }
    }

    if (totalAmount > 0) {
      // Return the amount to the first bidder
      IERC20(params.underlyingAsset).safeTransfer(
        params.owner,
        // We return the amount payed minus the interest of the debt
        totalAmount
      );
    }
  }

  /**
   * @dev Get the bigger amount between the amount needed to be healty or the amount provided
   * @param loanId Id from the loan
   * @param uTokenVault vault address
   * @param defaultAmount default amount to compare with the debt
   * @param totalCollateral total amount of collateral of the Loan provided
   * @param ltv ltv of the asset
   * @param reserveData reserve data
   * @return amount Max amount calculated
   */
  function getMaxDebtOrDefault(
    bytes32 loanId,
    address uTokenVault,
    uint256 defaultAmount,
    uint256 totalCollateral,
    uint256 ltv,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256) {
    uint256 totalDebt = GenericLogic.calculateLoanDebt(
      loanId,
      uTokenVault,
      reserveData.underlyingAsset
    );
    if (totalDebt == 0) return defaultAmount;
    uint256 minAmountNeeded = GenericLogic.calculateAmountToArriveToLTV(
      totalCollateral,
      totalDebt,
      ltv
    );

    return MathUtils.maxOf(minAmountNeeded, defaultAmount);
  }

  /**
   * @dev Get the lower amount between the amount needed to be healty or the amount provided
   * @param loanId Id from the loan
   * @param uTokenVault vault address
   * @param defaultAmount default amount to compare with the debt
   * @param totalCollateral total amount of collateral of the Loan provided
   * @param ltv ltv of the asset
   * @param reserveData reserve data
   * @return amount lower amount calculated
   */
  function getMinDebtOrDefault(
    bytes32 loanId,
    address uTokenVault,
    uint256 defaultAmount,
    uint256 totalCollateral,
    uint256 ltv,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256) {
    uint256 totalDebt = GenericLogic.calculateLoanDebt(
      loanId,
      uTokenVault,
      reserveData.underlyingAsset
    );
    if (totalDebt < defaultAmount) return totalDebt;

    uint256 minAmountNeeded = GenericLogic.calculateAmountToArriveToLTV(
      totalCollateral,
      totalDebt,
      ltv
    );
    return MathUtils.minOf(minAmountNeeded, defaultAmount);
  }

  /**
   * @dev Calculate the minimum bid based on the amount of debt to be healty or the startAmount
   * 0 bids then debt or startAmoun
   * 1 > bids then debt or lastBid + 1%
   * @param order current order
   * @param uTokenVault address of the vault
   * @param totalCollateral total collateral of the loan
   * @param ltv ltv of the loan
   * @return amount Calculation of the min bid
   * */
  function getMinBid(
    DataTypes.Order memory order,
    address uTokenVault,
    uint256 totalCollateral,
    uint256 ltv,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256) {
    if (order.countBids == 0) {
      return
        getMaxDebtOrDefault(
          order.offer.loanId,
          uTokenVault,
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
        uTokenVault,
        calculateMinBid(lastBid, order.countBids),
        totalCollateral,
        ltv,
        reserveData
      );
  }

  function calculateMinBid(
    uint256 lastBid,
    uint256 countBids
  ) internal pure returns (uint256 minBid) {
    minBid = countBids == 1
      ? lastBid + lastBid.percentMul(GenericLogic.FIRST_BID_INCREMENT) // At least 2.5% more than the last bid
      : lastBid + lastBid.percentMul(GenericLogic.NEXT_BID_INCREMENT); // At least %1 more than the last bid
  }

  struct RepayDebtToSellParams {
    address reserveOracle;
    address underlyingAsset;
    address uTokenVault;
    address from;
    uint256 totalAmount;
    uint256 aggLoanPrice;
    uint256 aggLtv;
  }

  function repayDebtToSell(
    DataTypes.Order memory order,
    RepayDebtToSellParams memory params,
    DataTypes.ReserveData memory reserveData
  ) internal returns (uint256 totalAmount) {
    uint256 totalDebt = GenericLogic.calculateLoanDebt(
      order.offer.loanId,
      params.uTokenVault,
      reserveData.underlyingAsset
    );
    totalAmount = params.totalAmount;

    if (totalDebt > 0 && order.offer.debtToSell > 0) {
      uint256 minAmountNeeded = GenericLogic.calculateAmountToArriveToLTV(
        params.aggLoanPrice,
        totalDebt,
        params.aggLtv
      );
      // We need to choose between the debt or the % selected by the user to repay.
      uint256 amounToRepay = MathUtils.maxOf(
        totalDebt.percentMul(order.offer.debtToSell),
        minAmountNeeded
      );
      if (amounToRepay > 0) {
        if (amounToRepay > totalAmount) {
          revert Errors.DebtExceedsAmount();
        }
        // Repay the debt
        repayDebt(
          RepayDebtParams({
            loanId: order.offer.loanId,
            owner: order.owner,
            from: params.from,
            amount: amounToRepay,
            underlyingAsset: params.underlyingAsset,
            uTokenVault: params.uTokenVault
          })
        );
        // // We remove from the total amount the debt repayed
        totalAmount = totalAmount - amounToRepay;
      }
    }
  }
}
