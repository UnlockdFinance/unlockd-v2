// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeTransferLib} from '@solady/utils/SafeTransferLib.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {IDelegationOwner} from '@unlockd-wallet/src/interfaces/IDelegationOwner.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {SafeCastLib} from '@solady/utils/SafeCastLib.sol';

import {BaseCoreModule, IACLManager} from '../../libraries/base/BaseCoreModule.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {IDebtToken} from '../../interfaces/tokens/IDebtToken.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IAuctionModule} from '../../interfaces/modules/IAuctionModule.sol';

import {AuctionSign} from '../../libraries/signatures/AuctionSign.sol';

import {PercentageMath} from '../../libraries/math/PercentageMath.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';
import {OrderLogic} from '../../libraries/logic/OrderLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';

import {DataTypes} from '../../types/DataTypes.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';

// import {console} from 'forge-std/console.sol';

contract Auction is BaseCoreModule, AuctionSign, IAuctionModule {
  using PercentageMath for uint256;
  using SafeTransferLib for address;
  using SafeCastLib for uint256;
  using OrderLogic for DataTypes.Order;
  using LoanLogic for DataTypes.Loan;

  constructor(
    uint256 moduleId_,
    bytes32 moduleVersion_
  ) BaseCoreModule(moduleId_, moduleVersion_) {}

  function getAmountToReedem(
    AmountToRedeemParams memory params
  )
    public
    view
    returns (uint256 totalAmount, uint256 totalDebt, uint256 minDebt, uint256 bidderBonus)
  {
    DataTypes.ReserveData memory reserve = IUToken(params.uToken).getReserve();

    totalDebt = GenericLogic.calculateLoanDebt(
      params.loanId,
      params.owner,
      _reserveOracle,
      reserve
    );
    // The user need to recover at least until the LTV
    minDebt = GenericLogic.calculateAmountToArriveToLTV(
      params.aggLoanPrice,
      totalDebt,
      params.aggLtv
    );

    if (params.countBids == 1) {
      // The first bidder gets 2.5% of benefit over the second bidder
      // We increate the amount to repay
      bidderBonus = (params.totalAmountBid).percentMul(GenericLogic.FIRST_BID_INCREMENT);
    }

    totalAmount = params.startAmount + minDebt + bidderBonus;

    // ........................ DEBUG MODE ....................................
    // console.log('-----------------------------------------------');
    // console.log('START AMOUNT      : ', params.startAmount);
    // console.log('MIN DEBT          : ', minDebt);
    // console.log('BONUS             : ', bidderBonus);
    // console.log('TOTAL DEBT        : ', totalDebt);
    // console.log('CALCULATED AMOUNT : ', totalAmount);
    // console.log('-----------------------------------------------');
  }

  /**
   * @dev Get min bid on auction
   * @param orderId identifier of the order
   * @param uToken token of the loan
   * @param aggLoanPrice aggregated loan colaterized on the Loan
   * @param aggLTV aggregated ltv between assets on the Loan
   */
  function getMinBidPriceAuction(
    bytes32 orderId,
    address uToken,
    uint256 aggLoanPrice,
    uint256 aggLTV
  ) external view returns (uint256 minBid) {
    minBid = OrderLogic.getMinBid(
      _orders[orderId],
      _reserveOracle,
      aggLoanPrice,
      aggLTV,
      IUToken(uToken).getReserve()
    );
  }

  /**
   * @dev Get Order stored by ID
   * @param orderId identifier of the order
   */
  function getOrderAuction(bytes32 orderId) external view returns (DataTypes.Order memory) {
    return _orders[orderId];
  }

  /**
   * @dev Bid in a asset with a unhealty loan
   * @param amountToPay Transfered amount from the user
   * @param amountOfDebt Amount borrowed agains the asset
   * @param signAuction struct signed
   * @param sig validation of this struct
   */
  function bid(
    uint128 amountToPay,
    uint128 amountOfDebt,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();

    _validateSignature(msgSender, signAuction, sig);
    // Validate signature
    DataTypes.Loan memory loan = _loans[signAuction.loan.loanId];
    bytes32 orderId = OrderLogic.generateId(signAuction.assetId, signAuction.loan.loanId);

    IUToken utoken = IUToken(loan.uToken);
    utoken.updateStateReserve();
    DataTypes.ReserveData memory reserve = utoken.getReserve();

    uint256 totalAmount = amountToPay + amountOfDebt;

    uint256 minBid;
    // Load the storage of the order
    DataTypes.Order storage order = _orders[orderId];

    if (order.owner == address(0)) {
      {
        // The loan need to be after the changes are success
        // We use the min or default because this asset maybe can't support the full debt and
        // we need to continue the auction with the rest of the elements in the loan.
        minBid = OrderLogic.getMinDebtOrDefault(
          loan.loanId,
          loan.owner,
          _reserveOracle,
          signAuction.assetPrice,
          signAuction.loan.aggLoanPrice,
          signAuction.loan.aggLtv,
          reserve
        );

        // Validate bid in order
        // Check if the Loan is Unhealty

        ValidationLogic.validateFutureHasUnhealtyLoanState(
          ValidationLogic.ValidateLoanStateParams({
            user: loan.owner,
            amount: 0,
            price: signAuction.assetPrice,
            reserveOracle: _reserveOracle,
            reserve: reserve,
            loanConfig: signAuction.loan
          })
        );

        // Creation of the Order
        order.createOrder(
          OrderLogic.ParamsCreateOrder({
            orderType: DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION,
            orderId: orderId,
            owner: loan.owner,
            loanId: signAuction.loan.loanId,
            assetId: signAuction.assetId,
            debtToSell: 1e4, // PercentageMath.ONE_HUNDRED_PERCENT
            // Start amount price of the current debt or
            startAmount: minBid.toUint128(),
            endAmount: 0,
            startTime: 0,
            endTime: signAuction.endTime
          })
        );
      }
    } else {
      {
        minBid = OrderLogic.getMinBid(
          order,
          _reserveOracle,
          signAuction.loan.aggLoanPrice,
          signAuction.loan.aggLtv,
          reserve
        );

        // If the auction is in market, we migrate this type of auction to liquidation
        if (order.orderType != DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION) {
          ValidationLogic.validateFutureHasUnhealtyLoanState(
            ValidationLogic.ValidateLoanStateParams({
              user: order.owner,
              amount: order.bid.amountOfDebt + order.bid.amountToPay,
              price: signAuction.assetPrice,
              reserveOracle: _reserveOracle,
              reserve: reserve,
              loanConfig: signAuction.loan
            })
          );
          // You only can convert the aution if the lastBid don't cover the debt
          order.updateToLiquidationOrder(minBid, signAuction);
        }
      }
    }
    ValidationLogic.validateBid(totalAmount, signAuction.loan.totalAssets, minBid, order, loan);

    // stake the assets on the protocol
    loan.underlyingAsset.safeTransferFrom(msgSender, address(this), amountToPay);
    bytes32 loanId;
    // The bidder asks for a debt
    if (amountOfDebt != 0) {
      // This path needs to be a abstract wallet
      address owner = GenericLogic.getMainWalletOwner(_walletRegistry, msgSender);
      if (owner != msgSender) {
        revert Errors.InvalidWalletOwner();
      }

      loanId = LoanLogic.generateId(msgSender, signAuction.nonce, signAuction.deadline);
      // Borrow the debt amount on belhalf of the bidder
      OrderLogic.borrowByBidder(
        OrderLogic.BorrowByBidderParams({
          loanId: loanId,
          owner: msgSender,
          uToken: address(utoken),
          amountOfDebt: amountOfDebt,
          assetPrice: signAuction.assetPrice,
          assetLtv: signAuction.assetLtv
        })
      );

      DataTypes.Loan storage _loan = _loans[loanId];
      // Create the loan associated
      _loan.createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
          uToken: address(utoken),
          underlyingAsset: reserve.underlyingAsset,
          totalAssets: 1,
          loanId: loanId
        })
      );
      // Freeze the loan until the auction is finished
      _loan.freeze();
    }

    if (order.bid.buyer == address(0)) {
      // We repay the debt at the beginning
      // The ASSET only support a % of the current debt in case of the next bids
      // we are not repaying more debt until the auction is ended.
      OrderLogic.repayOwnerDebt(
        OrderLogic.RepayOwnerDebtParams({
          loanId: loan.loanId,
          owner: order.owner,
          uToken: address(utoken),
          underlyingAsset: loan.underlyingAsset,
          minBid: minBid
        })
      );
      // The protocol freeze the loan repayed until end of the auction
      // to protect against borrow again
      _loans[loan.loanId].freeze();
    } else {
      // Cancel debt from old bidder and refund
      uint256 amountToPayBuyer = order.bid.amountToPay;
      if (order.countBids == 1) {
        // The first bidder gets 2.5% of benefit over the second bidder
        // We increate the amount to repay
        amountToPayBuyer =
          amountToPayBuyer +
          (amountToPayBuyer + order.bid.amountOfDebt).percentMul(GenericLogic.FIRST_BID_INCREMENT);
      }
      // We assuming that the ltv is enought to cover the growing interest of this bid
      OrderLogic.refundBidder(
        OrderLogic.RefundBidderParams({
          loanId: order.bid.loanId,
          owner: order.bid.buyer,
          reserveOracle: _reserveOracle,
          uToken: address(utoken),
          underlyingAsset: loan.underlyingAsset,
          amountOfDebt: order.bid.amountOfDebt,
          amountToPay: amountToPayBuyer,
          reserve: reserve
        })
      );
      {
        // cache loanId value to prevent a second storage access
        bytes32 loanId_ = order.bid.loanId;
        if (loanId_ != 0) {
          // Remove old loan
          delete _loans[loanId_];
        }
      }
    }
    unchecked {
      order.countBids++;
    }

    order.bid = DataTypes.Bid({
      loanId: loanId,
      amountToPay: amountToPay,
      amountOfDebt: amountOfDebt,
      buyer: msgSender
    });

    emit AuctionBid(loanId, order.orderId, order.offer.assetId, totalAmount, msgSender);
  }

  /**
   * @dev Unlock the Loan, recover the asset only if the auction is still active
   * @param orderId Order identifier to redeem the asset and pay the debt related
   * @param amount amount of dept to pay
   * @param signAuction struct of the data needed
   * @param sig validation of this struct
   * */
  function redeem(
    bytes32 orderId,
    uint256 amount,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signAuction, sig);
    DataTypes.Order memory order = _orders[orderId];
    if (order.orderType != DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION) {
      revert Errors.OrderNotAllowed();
    }
    if (order.owner != msgSender) {
      revert Errors.InvalidOrderOwner();
    }

    // Validate signature
    DataTypes.Loan storage loan = _loans[order.offer.loanId];
    address utoken = loan.uToken;
    address underlyingAsset = loan.underlyingAsset;

    IUToken(utoken).updateStateReserve();
    DataTypes.ReserveData memory reserve = IUToken(utoken).getReserve();

    Errors.verifyNotExpiredTimestamp(order.timeframe.endTime, block.timestamp);
    // Check pending debt
    (uint256 totalAmount, , uint256 minDebt, uint256 bidderBonus) = getAmountToReedem(
      AmountToRedeemParams({
        uToken: utoken,
        loanId: order.offer.loanId,
        owner: order.owner,
        aggLoanPrice: signAuction.loan.aggLoanPrice,
        aggLtv: signAuction.loan.aggLtv,
        countBids: order.countBids,
        totalAmountBid: order.bid.amountToPay + order.bid.amountOfDebt,
        startAmount: order.offer.startAmount
      })
    );
    if (totalAmount != amount) revert Errors.InvalidAmount();
    // Transfer all the amount to the contract
    underlyingAsset.safeTransferFrom(msgSender, address(this), amount);

    // We assuming that the ltv is enought to cover the growing interest of this bid
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: order.bid.loanId,
        owner: order.bid.buyer,
        reserveOracle: _reserveOracle,
        uToken: utoken,
        underlyingAsset: underlyingAsset,
        amountOfDebt: order.bid.amountOfDebt,
        amountToPay: order.offer.startAmount + bidderBonus,
        reserve: reserve
      })
    );

    if (order.bid.loanId != 0) {
      // Remove old loan
      delete _loans[order.bid.loanId];
    }

    if (minDebt > 0) {
      underlyingAsset.safeApprove(utoken, minDebt);
      IUToken(utoken).repayOnBelhalf(order.offer.loanId, minDebt, address(this), msgSender);
    }

    emit AuctionRedeem(order.offer.loanId, orderId, order.offer.assetId, totalAmount, msgSender);

    delete _orders[orderId];
    _loans[order.offer.loanId].activate();
  }

  /**
   * @dev Finalize the liquidation auction once is expired in time.
   * @param orderId Order identifier to redeem the asset and pay the debt related
   * @param signAuction struct of the data needed
   * @param sig validation of this struct
   * */
  function finalize(
    bytes32 orderId,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signAuction, sig);

    DataTypes.Order memory order = _orders[orderId];
    if (order.owner == address(0)) revert Errors.InvalidOrderOwner();
    if (order.orderType != DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION) {
      revert Errors.OrderNotAllowed();
    }

    bytes32 offerLoanId = order.offer.loanId;

    DataTypes.Loan storage loan = _loans[offerLoanId];

    // The aution need to be ended
    Errors.verifyExpiredTimestamp(order.timeframe.endTime, block.timestamp);

    // Se the address of the buyer to the EOA
    address buyer = order.bid.buyer;

    // If the bidder has a loan with the new asset
    // we need to activate the loan and change the ownership to this new loan
    if (order.bid.loanId != 0) {
      (address walletBuyer, address protocolOwnerBuyer) = GenericLogic.getMainWallet(
        _walletRegistry,
        buyer
      );

      // Change the address of the buyer to the UnlockdWallet
      buyer = walletBuyer;
      // Block the asset
      IProtocolOwner(protocolOwnerBuyer).setLoanId(signAuction.assetId, loan.loanId);
      // Activate the loan from the bidder
      _loans[order.bid.loanId].activate();
    }

    // Get protocol owner
    address protocolOwner = GenericLogic.getMainWalletProtocolOwner(_walletRegistry, msgSender);

    // We transfer the ownership to the new Owner
    IProtocolOwner(protocolOwner).changeOwner(
      signAuction.collection,
      signAuction.tokenId,
      // We send the asset to
      buyer
    );

    // The start amount it was payed as a debt
    uint256 amount = order.bid.amountOfDebt + order.bid.amountToPay - order.offer.startAmount;
    loan.underlyingAsset.safeTransfer(order.owner, amount);
    // Remove the order
    delete _orders[orderId];

    // Check the messe it's correct
    if (_loans[loan.loanId].totalAssets != signAuction.loan.totalAssets + 1) {
      revert Errors.TokenAssetsMismatch();
    }
    if (signAuction.loan.totalAssets > 1) {
      // Activate loan
      loan.activate();
      loan.totalAssets = signAuction.loan.totalAssets;
    } else {
      // If there is only one we can remove the loan
      delete _loans[offerLoanId];
    }

    emit AuctionFinalize(
      offerLoanId,
      orderId,
      signAuction.assetId,
      order.offer.startAmount,
      amount,
      order.bid.buyer,
      order.owner
    );
  }
}
