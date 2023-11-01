// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';

import {MarketSign} from '../../libraries/signatures/MarketSign.sol';
import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {OrderLogic} from '../../libraries/logic/OrderLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';

import {PercentageMath} from '../../libraries/math/PercentageMath.sol';
import {WadRayMath} from '../../libraries/math/WadRayMath.sol';

import {MathUtils} from '../../libraries/math/MathUtils.sol';

import {DataTypes} from '../../types/DataTypes.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {IDebtToken} from '../../interfaces/tokens/IDebtToken.sol';
import {IMarketModule} from '../../interfaces/modules/IMarketModule.sol';

import {console} from 'forge-std/console.sol';

contract Market is BaseCoreModule, IMarketModule, MarketSign {
  using SafeERC20 for IERC20;
  using OrderLogic for DataTypes.Order;
  using LoanLogic for DataTypes.Loan;

  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  /**
   * @dev Get Order stored by ID
   * @param orderId identifier of the order
   */
  function getOrder(bytes32 orderId) external view returns (DataTypes.Order memory) {
    return _orders[orderId];
  }

  /**
   * @dev Get min bid on auction
   * @param orderId identifier of the order
   * @param uToken token of the loan
   * @param aggLoanPrice aggregated loan colaterized on the Loan
   * @param aggLTV aggregated ltv between assets on the Loan
   */
  function getMinBidPrice(
    bytes32 orderId,
    address uToken,
    uint256 aggLoanPrice,
    uint256 aggLTV
  ) external view returns (uint256 minBid, uint nextBid) {
    (minBid, nextBid) = OrderLogic.getMinBid(
      _orders[orderId],
      _reserveOracle,
      aggLoanPrice,
      aggLTV,
      IUToken(uToken).getReserve()
    );
  }

  /**
   * @dev Get price to buy the asset
   * @param orderId identifier of the order
   * @param uToken token of the loan
   * @param aggLoanPrice aggregated loan colaterized on the Loan
   * @param aggLTV aggregated ltv between assets on the Loan
   */
  function getBuyNowPrice(
    bytes32 orderId,
    address uToken,
    uint256 aggLoanPrice,
    uint256 aggLTV
  ) external view returns (uint256 amount) {
    DataTypes.Order memory order = _orders[orderId];
    amount = OrderLogic.getMaxDebtOrDefault(
      order.offer.loanId,
      order.owner,
      _reserveOracle,
      order.offer.endAmount,
      aggLoanPrice,
      aggLTV,
      IUToken(uToken).getReserve()
    );
  }

  /**
   * @dev Creation of the Order
   * @param orderType type of the order to create
   * @param config configuration to create the order
   * @param signMarket signed struct with the parameters needed to create the order
   *        - the loan struct need to be once the nft is not anymore inside of the original loan.
   *        - assetPrice and assetLtv need to be the values only of this asset where we want to interact
   * @param sig validation of the signature
   */
  function create(
    address uToken,
    DataTypes.OrderType orderType,
    CreateOrderInput calldata config,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external isUTokenAllowed(uToken) {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signMarket, sig);

    DataTypes.Loan storage loan = _loans[signMarket.loan.loanId];

    // In case we want to create a auction with a nft that are not in a loan
    if (loan.loanId == 0) {
      // Create a new one

      loan.createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
          totalAssets: 1,
          loanId: LoanLogic.generateId(msgSender, signMarket.loan.nonce, signMarket.loan.deadline),
          uToken: uToken,
          underlyingAsset: IUToken(uToken).UNDERLYING_ASSET_ADDRESS()
        })
      );

      (address wallet, address delegationOwner) = GenericLogic.getMainWallet(
        _walletRegistry,
        msgSender
      );
      ValidationLogic.validateLockAsset(
        signMarket.assetId,
        wallet,
        _allowedControllers,
        delegationOwner,
        DataTypes.Asset({collection: signMarket.collection, tokenId: signMarket.tokenId})
      );
      // Lock the asset
      IProtocolOwner(delegationOwner).setLoanId(signMarket.assetId, loan.loanId);
    } else {
      if (loan.uToken != uToken) {
        revert Errors.InvalidUToken();
      }

      if (loan.owner != msgSender) {
        revert Errors.InvalidLoanOwner();
      }

      if (signMarket.loan.totalAssets == loan.totalAssets) {
        revert Errors.LoanNotUpdated();
      }

      ValidationLogic.validateAuctionLoan(
        msgSender,
        config.startAmount,
        _reserveOracle,
        loan,
        IUToken(loan.uToken).getReserve(),
        signMarket.loan
      );
    }

    bytes32 orderId = OrderLogic.generateId(signMarket.assetId, signMarket.loan.loanId);

    ValidationLogic.validateCreateOrderMarket(
      ValidationLogic.ValidateCreateOrderMarketParams({
        orderType: orderType,
        debtToSell: config.debtToSell,
        startAmount: config.startAmount,
        endAmount: config.endAmount,
        startTime: config.startTime,
        endTime: config.endTime,
        currentTimestamp: block.timestamp
      })
    );

    // Creation of the Order
    _orders[orderId].createOrder(
      OrderLogic.ParamsCreateOrder({
        orderType: orderType,
        orderId: orderId,
        owner: msgSender,
        loanId: signMarket.loan.loanId,
        assetId: signMarket.assetId,
        debtToSell: config.debtToSell,
        startAmount: config.startAmount,
        endAmount: config.endAmount, // Optional only mandatory for FIXED_PRICE
        startTime: config.startTime,
        endTime: config.endTime // Optional only mandatory for for AUCTION type
      })
    );
  }

  /**
   * @dev Cancel the order anytime, only the owner of the order can do that
   * @param orderId identifier of the order to cancel
   */
  function cancel(bytes32 orderId) external {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    // Cache Order data
    DataTypes.Order storage order = _orders[orderId];
    address orderOwner = order.owner;
    DataTypes.OrderType orderType = order.orderType;
    uint40 orderTimeframeEndtime = order.timeframe.endTime;
    DataTypes.Bid memory bid = order.bid;

    // Cache Loan data
    DataTypes.Loan storage loan = _loans[order.offer.loanId];
    address loanUToken = loan.uToken;
    DataTypes.LoanState loanState = loan.state;

    ValidationLogic.validateCancelOrderMarket(
      msgSender,
      loanState,
      orderOwner,
      orderType,
      orderTimeframeEndtime
    );

    //Refund bid
    if (bid.buyer != address(0)) {
      DataTypes.ReserveData memory reserve = IUToken(loanUToken).getReserve();
      IUToken(loanUToken).updateStateReserve();
      // We assuming that the ltv is enought to cover the growing interest of this bid
      OrderLogic.refundBidder(
        OrderLogic.RefundBidderParams({
          loanId: bid.loanId,
          owner: bid.buyer,
          reserveOracle: _reserveOracle,
          uToken: loanUToken,
          underlyingAsset: loan.underlyingAsset,
          amountOfDebt: bid.amountOfDebt,
          amountToPay: bid.amountToPay,
          reserve: reserve
        })
      );
      if (bid.loanId != 0) {
        // Remove old loan
        delete _loans[bid.loanId];
      }
      _loans[order.offer.loanId].activate();
    }
    delete _orders[orderId];
  }

  /**
   * @dev place to create bid on the current orders
   * @param orderId identifier of the order to place the bid
   * @param amountToPay amount that the user need to add
   * @param amountOfDebt specified amount to create as a debt considering the asset buyed as a collateral
   * @param signMarket struct with information of the loan and prices
   * @param sig validation of this struct
   * */
  function bid(
    bytes32 orderId,
    uint128 amountToPay,
    uint128 amountOfDebt,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signMarket, sig);

    DataTypes.Order storage order = _orders[orderId];
    DataTypes.Loan storage loan = _loans[order.offer.loanId];
    // Check if the loan is updated
    // The loan need to be the final result of the modification once the auction is ended
    if (signMarket.loan.totalAssets == loan.totalAssets) {
      revert Errors.LoanNotUpdated();
    }
    ValidationLogic.validateOrderBid(
      signMarket.loan.totalAssets,
      order.orderType,
      order.timeframe.endTime,
      loan.totalAssets,
      loan.state
    );

    // Cache UToken address
    address uToken = loan.uToken;

    //Validate if the loan is healthy and starts and auction
    DataTypes.ReserveData memory reserve = IUToken(uToken).getReserve();
    IUToken(uToken).updateStateReserve();

    // We need to validate that the next bid is bigger than the last one.
    uint256 totalAmount = amountToPay + amountOfDebt;
    {
      (, uint256 nextBid) = OrderLogic.getMinBid(
        order,
        _reserveOracle,
        signMarket.loan.aggLoanPrice,
        signMarket.loan.aggLtv,
        reserve
      );

      if (totalAmount == 0 || totalAmount < nextBid) {
        revert Errors.AmountToLow();
      }
    }
    // stake the assets on the protocol
    IERC20(loan.underlyingAsset).safeTransferFrom(msgSender, address(this), amountToPay);

    bytes32 loanId = 0;
    // The bidder asks for a debt
    if (amountOfDebt > 0) {
      // This path neet to be a abstract wallet
      address wallet = GenericLogic.getMainWalletAddress(_walletRegistry, msgSender);
      Errors.verifyNotZero(wallet);

      loanId = LoanLogic.generateId(msgSender, signMarket.nonce, signMarket.deadline);
      // Borrow the debt amount on belhalf of the bidder
      OrderLogic.borrowByBidder(
        OrderLogic.BorrowByBidderParams({
          loanId: loanId,
          owner: msgSender,
          uToken: uToken,
          amountOfDebt: amountOfDebt,
          assetPrice: signMarket.assetPrice,
          assetLtv: signMarket.assetLtv
        })
      );
      // Create the loan associated
      _loans[loanId].createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
          uToken: uToken,
          underlyingAsset: reserve.underlyingAsset,
          totalAssets: 1,
          loanId: loanId
        })
      );
      // Freeze the loan until the auction is finished
      _loans[loanId].freeze();
    }

    // Cancel debt from old bidder and refund
    if (order.bid.buyer != address(0)) {
      // We assuming that the ltv is enought to cover the growing interest of this bid
      OrderLogic.refundBidder(
        OrderLogic.RefundBidderParams({
          loanId: order.bid.loanId,
          owner: order.bid.buyer,
          reserveOracle: _reserveOracle,
          uToken: uToken,
          underlyingAsset: loan.underlyingAsset,
          amountOfDebt: order.bid.amountOfDebt,
          amountToPay: order.bid.amountToPay,
          reserve: reserve
        })
      );

      if (order.bid.loanId != 0) {
        // Remove old loan
        delete _loans[order.bid.loanId];
      }
    }

    order.countBids++;

    order.bid = DataTypes.Bid({
      loanId: loanId,
      amountToPay: amountToPay,
      amountOfDebt: amountOfDebt,
      buyer: msgSender
    });
    // Freeze owner LOAN position
    _loans[order.offer.loanId].freeze();

    emit MarketBid(loanId, order.orderId, order.offer.assetId, totalAmount, msgSender);
  }

  /**
   * @dev Claim the assets once the auction is ended. This function can be executed by anyone.
   * @param claimOnUWallet force claim on unlockd wallet
   * @param orderId identifier of the order
   * @param signMarket struct with information of the loan and prices
   * @param sig validation of this struct
   * */
  function claim(
    bool claimOnUWallet,
    bytes32 orderId,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signMarket, sig);
    DataTypes.Order memory order = _orders[orderId];

    // Get the loan asigned to the Order
    DataTypes.Loan storage loan = _loans[order.offer.loanId];

    {
      // Avoid stack too deep
      uint88 loanTotalAssets = loan.totalAssets;
      DataTypes.LoanState loanState = loan.state;
      // Validate if the order is ended
      ValidationLogic.validateOrderClaim(
        signMarket.loan.totalAssets,
        order,
        loanTotalAssets,
        loanState
      );
    }

    // Cache uToken and underlying asset addresses
    address uToken = loan.uToken;
    address underlyingAsset = loan.underlyingAsset;

    DataTypes.ReserveData memory reserve = IUToken(uToken).getReserve();
    IUToken(uToken).updateStateReserve();

    uint256 totalAmount = order.bid.amountToPay + order.bid.amountOfDebt;

    // We check if the bid is in the correct range in order to ensure that the HF is correct.
    // Because the interest can be grow and the auction endend and the liquidation can happend in mind time.
    ValidationLogic.validateAuctionLoan(
      order.owner,
      totalAmount,
      _reserveOracle,
      loan,
      IUToken(loan.uToken).getReserve(),
      signMarket.loan
    );

    // Calculated the percentage desired by the user to repay
    totalAmount = OrderLogic.repayDebtToSell(
      order,
      OrderLogic.RepayDebtToSellParams({
        reserveOracle: _reserveOracle,
        underlyingAsset: underlyingAsset,
        uToken: uToken,
        totalAmount: totalAmount,
        aggLoanPrice: signMarket.loan.aggLoanPrice,
        aggLtv: signMarket.loan.aggLtv
      }),
      reserve
    );

    // Return the amount to the owner
    IERC20(underlyingAsset).safeTransfer(order.owner, totalAmount);

    // By default we get the EOA from the buyer
    address buyer = order.bid.buyer;
    address buyerDelegationOwner;
    if (claimOnUWallet) {
      (address wallet, address delegationOwner) = GenericLogic.getMainWallet(
        _walletRegistry,
        order.bid.buyer
      );
      buyer = wallet;
      buyerDelegationOwner = delegationOwner;
    }
    if (order.bid.loanId != 0) {
      // If there is a loanId the Unlockd wallet from the bider is required
      if (buyerDelegationOwner == address(0)) {
        revert Errors.DelegationOwnerZeroAddress();
      }
      // Assign the asset to a new Loan
      IProtocolOwner(buyerDelegationOwner).setLoanId(order.offer.assetId, order.bid.loanId);
      // Once the asset is sended to the correct wallet we reactivate
      _loans[order.bid.loanId].activate();
    }

    // Cache loan ID
    bytes32 loanId = loan.loanId;

    if (signMarket.loan.totalAssets != _loans[loan.loanId].totalAssets - 1) {
      revert Errors.TokenAssetsMismatch();
    }
    // We check the status
    if (signMarket.loan.totalAssets == 0) {
      // Remove the loan because doens't have more assets
      delete _loans[loanId];
    } else {
      // We update the counter
      _loans[loanId].totalAssets = signMarket.loan.totalAssets;
      _loans[loanId].activate();
    }

    {
      // Get delegation owner
      address delegationOwnerOwner = GenericLogic.getMainWalletProtocolOwner(
        _walletRegistry,
        order.owner
      );
      // We transfer the ownership to the new Owner
      IProtocolOwner(delegationOwnerOwner).changeOwner(
        signMarket.collection,
        signMarket.tokenId,
        buyer
      );

      emit MarketClaim(loanId, order.orderId, signMarket.assetId, totalAmount, msgSender);

      delete _orders[order.orderId];
    }
  }

  function cancelClaim(
    bool claimOnUWallet,
    bytes32 orderId,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signMarket, sig);
    DataTypes.Order memory order = _orders[orderId];

    // Get the loan asigned to the Order
    DataTypes.Loan storage loan = _loans[order.offer.loanId];

    {
      // Avoid stack too deep
      uint88 loanTotalAssets = loan.totalAssets;
      DataTypes.LoanState loanState = loan.state;
      // Validate if the order is ended
      ValidationLogic.validateOrderClaim(
        signMarket.loan.totalAssets,
        order,
        loanTotalAssets,
        loanState
      );
    }

    // Cache uToken and underlying asset addresses
    address uToken = loan.uToken;
    address underlyingAsset = loan.underlyingAsset;

    DataTypes.ReserveData memory reserve = IUToken(uToken).getReserve();
    IUToken(uToken).updateStateReserve();

    uint256 totalAmount = order.bid.amountToPay + order.bid.amountOfDebt;

    // We check if the bid is in the correct range in order to ensure that the HF is correct.
    // Because the interest can be grow and the auction endend and the liquidation can happend in mind time.
    {
      uint256 minBid = OrderLogic.getMaxDebtOrDefault(
        order.offer.loanId,
        order.owner,
        _reserveOracle,
        totalAmount,
        signMarket.loan.aggLoanPrice,
        signMarket.loan.aggLtv,
        reserve
      );

      if (totalAmount >= minBid) {
        revert Errors.AmountExceedsDebt();
      }
    }
    // We assuming that the ltv is enought to cover the growing interest of this bid
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: order.bid.loanId,
        owner: order.bid.buyer,
        reserveOracle: _reserveOracle,
        uToken: uToken,
        underlyingAsset: loan.underlyingAsset,
        amountOfDebt: order.bid.amountOfDebt,
        amountToPay: order.bid.amountToPay,
        reserve: reserve
      })
    );

    if (order.bid.loanId != 0) {
      // Remove old loan
      delete _loans[order.bid.loanId];
    }

    _loans[order.offer.loanId].activate();

    delete _orders[order.orderId];

    emit MarketCancelBid(
      order.offer.loanId,
      order.orderId,
      signMarket.assetId,
      totalAmount,
      order.owner
    );
  }

  /**
   * @dev Buy directly the asset and cancel the current auction
   * @param claimOnUWallet force claim on unlockd wallet
   * @param orderId order identification
   * @param amountToPay amount that the user need to add
   * @param amountOfDebt specified amount to create as a debt considering the asset buyed as a collateral
   * @param signMarket struct signed
   * @param sig validation of this struct
   */
  function buyNow(
    bool claimOnUWallet,
    bytes32 orderId,
    uint256 amountToPay,
    uint256 amountOfDebt,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signMarket, sig);

    DataTypes.Order memory order = _orders[orderId];
    DataTypes.Loan storage loan = _loans[order.offer.loanId];

    {
      // Avoid stack too deep
      uint88 loanTotalAssets = loan.totalAssets;
      DataTypes.LoanState loanState = loan.state;

      ValidationLogic.validateBuyNow(
        signMarket.loan.totalAssets,
        order,
        loanTotalAssets,
        loanState
      );
    }

    // Cache uToken and underlying asset addresses
    address uToken = loan.uToken;
    address underlyingAsset = loan.underlyingAsset;

    IUToken(uToken).updateStateReserve();
    DataTypes.ReserveData memory reserve = IUToken(uToken).getReserve();

    uint256 totalAmount = amountToPay + amountOfDebt;

    {
      // Check what is the correct pricing for this asset
      uint256 assetPrice = OrderLogic.getMaxDebtOrDefault(
        order.offer.loanId,
        order.owner,
        _reserveOracle,
        order.offer.endAmount,
        signMarket.loan.aggLoanPrice,
        signMarket.loan.aggLtv,
        IUToken(uToken).getReserve()
      );

      if (totalAmount != assetPrice) revert Errors.InvalidTotalAmount();
    }
    // stake the assets on the protocol
    IERC20(underlyingAsset).safeTransferFrom(msgSender, address(this), amountToPay);

    address buyer = msgSender;
    {
      address delegationOwnerBuyer;
      if (claimOnUWallet) {
        (address wallet, address delegationOwner) = GenericLogic.getMainWallet(
          _walletRegistry,
          msgSender
        );

        delegationOwnerBuyer = delegationOwner;
        buyer = wallet;
      }
      // The bidder asks for a debt
      if (amountOfDebt > 0) {
        // This path neet to be a abstract wallet
        if (delegationOwnerBuyer == address(0)) {
          revert Errors.DelegationOwnerZeroAddress();
        }

        bytes32 newLoanId = LoanLogic.generateId(msgSender, signMarket.nonce, signMarket.deadline);
        // Borrow the debt amount on belhalf of the bidder
        OrderLogic.borrowByBidder(
          OrderLogic.BorrowByBidderParams({
            loanId: newLoanId,
            owner: msgSender,
            uToken: uToken,
            amountOfDebt: amountOfDebt,
            assetPrice: signMarket.assetPrice,
            assetLtv: signMarket.assetLtv
          })
        );
        // Create the loan associated
        _loans[newLoanId].createLoan(
          LoanLogic.ParamsCreateLoan({
            msgSender: msgSender,
            uToken: uToken,
            underlyingAsset: reserve.underlyingAsset,
            totalAssets: 1,
            loanId: newLoanId
          })
        );

        // Assign the asset to a new Loan
        IProtocolOwner(delegationOwnerBuyer).setLoanId(order.offer.assetId, newLoanId);
      }
    }
    // Cancel debt from old bidder and refund
    {
      if (order.bid.buyer != address(0)) {
        // We assuming that the ltv is enought to cover the growing interest of this bid
        OrderLogic.refundBidder(
          OrderLogic.RefundBidderParams({
            loanId: order.bid.loanId,
            owner: order.bid.buyer,
            reserveOracle: _reserveOracle,
            uToken: uToken,
            underlyingAsset: underlyingAsset,
            amountOfDebt: order.bid.amountOfDebt,
            amountToPay: order.bid.amountToPay,
            reserve: reserve
          })
        );

        if (order.bid.loanId != 0) {
          // Remove old loan
          delete _loans[order.bid.loanId];
        }
      }
    }
    // Calculated the percentage desired by the user to repay
    totalAmount = OrderLogic.repayDebtToSell(
      order,
      OrderLogic.RepayDebtToSellParams({
        reserveOracle: _reserveOracle,
        underlyingAsset: underlyingAsset,
        uToken: uToken,
        totalAmount: totalAmount,
        aggLoanPrice: signMarket.loan.aggLoanPrice,
        aggLtv: signMarket.loan.aggLtv
      }),
      reserve
    );

    {
      // Return the amount to the owner
      IERC20(underlyingAsset).safeTransfer(order.owner, totalAmount);

      (, address delegationOwner) = GenericLogic.getMainWallet(_walletRegistry, order.owner);
      // Get the wallet of the owner

      // We transfer the ownership to the new Owner
      IProtocolOwner(delegationOwner).changeOwner(signMarket.collection, signMarket.tokenId, buyer);

      emit MarketBuyNow(
        signMarket.loan.loanId,
        orderId,
        signMarket.assetId,
        totalAmount,
        msgSender
      );

      // We remove the current order asociated to this asset
      delete _orders[orderId];

      if (signMarket.loan.totalAssets != _loans[loan.loanId].totalAssets - 1) {
        revert Errors.TokenAssetsMismatch();
      }
      // We check the status
      if (signMarket.loan.totalAssets == 0) {
        // Remove the loan because doesn't have more assets
        delete _loans[loan.loanId];
      } else {
        // We update the counter
        _loans[loan.loanId].totalAssets = signMarket.loan.totalAssets;
        _loans[loan.loanId].activate();
      }
    }
  }
}
