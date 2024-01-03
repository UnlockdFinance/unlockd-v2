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
import {Constants} from '../../libraries/helpers/Constants.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {OrderLogic} from '../../libraries/logic/OrderLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';

import {PercentageMath} from '../../libraries/math/PercentageMath.sol';
import {WadRayMath} from '../../libraries/math/WadRayMath.sol';

import {MathUtils} from '../../libraries/math/MathUtils.sol';

import {DataTypes} from '../../types/DataTypes.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IMarketModule} from '../../interfaces/modules/IMarketModule.sol';
import {IUTokenFactory} from '../../interfaces/IUTokenFactory.sol';

// import {console} from 'forge-std/console.sol';

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
   * @param underlyingAsset token asset of the loan
   * @param aggLoanPrice aggregated loan colaterized on the Loan
   * @param aggLTV aggregated ltv between assets on the Loan
   */
  function getMinBidPrice(
    bytes32 orderId,
    address underlyingAsset,
    uint256 aggLoanPrice,
    uint256 aggLTV
  ) external view returns (uint256 minBid) {
    minBid = OrderLogic.getMinBid(
      _orders[orderId],
      _uTokenFactory,
      aggLoanPrice,
      aggLTV,
      IUTokenFactory(_uTokenFactory).getReserveData(underlyingAsset)
    );
  }

  /**
   * @dev Get price to buy the asset
   * @param orderId identifier of the order
   * @param underlyingAsset token asset of the loan
   * @param aggLoanPrice aggregated loan colaterized on the Loan
   * @param aggLTV aggregated ltv between assets on the Loan
   */
  function getBuyNowPrice(
    bytes32 orderId,
    address underlyingAsset,
    uint256 aggLoanPrice,
    uint256 aggLTV
  ) external view returns (uint256 amount) {
    DataTypes.Order memory order = _orders[orderId];
    amount = OrderLogic.getMaxDebtOrDefault(
      order.offer.loanId,
      _uTokenFactory,
      order.offer.endAmount,
      aggLoanPrice,
      aggLTV,
      IUTokenFactory(_uTokenFactory).getReserveData(underlyingAsset)
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
    address underlyingAsset,
    Constants.OrderType orderType,
    CreateOrderInput calldata config,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signMarket, sig);

    DataTypes.Loan storage loan = _loans[signMarket.loan.loanId];
    DataTypes.ReserveData memory reserve = IUTokenFactory(_uTokenFactory).getReserveData(
      underlyingAsset
    );

    // In case we want to create a auction with a nft that are not in a loan
    if (loan.loanId == 0) {
      // Create a new one

      loan.createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
          totalAssets: 1,
          loanId: LoanLogic.generateId(msgSender, signMarket.loan.nonce, signMarket.loan.deadline),
          underlyingAsset: underlyingAsset
        })
      );

      (address wallet, address delegationOwner) = GenericLogic.getMainWallet(
        _walletRegistry,
        msgSender
      );

      if (
        IUTokenFactory(_uTokenFactory).validateReserveType(
          reserve.reserveType,
          _allowedCollections[signMarket.collection]
        ) == false
      ) {
        revert Errors.NotValidReserve();
      }
      ValidationLogic.validateLockAsset(
        signMarket.assetId,
        wallet,
        delegationOwner,
        DataTypes.Asset({collection: signMarket.collection, tokenId: signMarket.tokenId})
      );
      // Lock the asset
      IProtocolOwner(delegationOwner).setLoanId(signMarket.assetId, loan.loanId);
    } else {
      if (loan.underlyingAsset != underlyingAsset) {
        revert Errors.InvalidUnderlyingAsset();
      }

      if (loan.owner != msgSender) {
        revert Errors.InvalidLoanOwner();
      }

      if (signMarket.loan.totalAssets == loan.totalAssets) {
        revert Errors.LoanNotUpdated();
      }

      IUTokenFactory(_uTokenFactory).updateState(underlyingAsset);

      ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          amount: config.startAmount,
          price: signMarket.assetPrice,
          reserveOracle: _reserveOracle,
          uTokenFactory: _uTokenFactory,
          reserve: reserve,
          loanConfig: signMarket.loan
        })
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
        currentTimestamp: block.timestamp,
        loanState: loan.state
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

    emit MarketCreated(
      signMarket.loan.loanId,
      orderId,
      signMarket.assetId,
      signMarket.collection,
      signMarket.tokenId
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
    Constants.OrderType orderType = order.orderType;
    uint40 orderTimeframeEndtime = order.timeframe.endTime;
    DataTypes.Bid memory bidData = order.bid;

    // Cache Loan data
    DataTypes.Loan storage loan = _loans[order.offer.loanId];
    Constants.LoanState loanState = loan.state;

    ValidationLogic.validateCancelOrderMarket(
      msgSender,
      loanState,
      orderOwner,
      orderType,
      orderTimeframeEndtime
    );

    //Refund bid
    if (bidData.buyer != address(0)) {
      IUTokenFactory(_uTokenFactory).updateState(loan.underlyingAsset);
      DataTypes.ReserveData memory reserve = IUTokenFactory(_uTokenFactory).getReserveData(
        loan.underlyingAsset
      );
      // We assuming that the ltv is enought to cover the growing interest of this bid
      OrderLogic.refundBidder(
        OrderLogic.RefundBidderParams({
          loanId: bidData.loanId,
          owner: bidData.buyer,
          reserveOracle: _reserveOracle,
          from: address(this),
          underlyingAsset: loan.underlyingAsset,
          uTokenFactory: _uTokenFactory,
          amountOfDebt: bidData.amountOfDebt,
          amountToPay: bidData.amountToPay,
          reserve: reserve
        })
      );
      if (bidData.loanId != 0) {
        // Remove old loan
        delete _loans[bidData.loanId];
      }
      _loans[order.offer.loanId].activate();
    }
    delete _orders[orderId];

    emit MarketCancelAuction(loan.loanId, orderId, order.owner);
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

    if (order.offer.loanId != signMarket.loan.loanId) {
      revert Errors.InvalidLoanId();
    }
    // Check if the loan is updated
    // The loan need to be the final result of the modification once the auction is ended
    if (signMarket.loan.totalAssets == loan.totalAssets) {
      revert Errors.LoanNotUpdated();
    }
    Constants.LoanState loanState = loan.state;
    ValidationLogic.validateOrderBid(
      order.orderType,
      order.timeframe.endTime,
      signMarket.loan.totalAssets,
      loan.totalAssets,
      loanState
    );

    // Cache UToken address

    //Validate if the loan is healthy and starts and auction
    IUTokenFactory(_uTokenFactory).updateState(loan.underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenFactory(_uTokenFactory).getReserveData(
      loan.underlyingAsset
    );

    // We need to validate that the next bid is bigger than the last one.
    uint256 totalAmount = amountToPay + amountOfDebt;
    {
      uint256 nextBid = OrderLogic.getMinBid(
        order,
        _uTokenFactory,
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
          amountOfDebt: amountOfDebt,
          underlyingAsset: reserve.underlyingAsset,
          uTokenFactory: _uTokenFactory,
          assetPrice: signMarket.assetPrice,
          assetLtv: signMarket.assetLtv
        })
      );
      // Create the loan associated
      _loans[loanId].createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
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
          from: address(this),
          underlyingAsset: loan.underlyingAsset,
          uTokenFactory: _uTokenFactory,
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
    if (order.offer.loanId != signMarket.loan.loanId) {
      revert Errors.InvalidLoanId();
    }

    {
      // Avoid stack too deep
      uint88 loanTotalAssets = loan.totalAssets;
      Constants.LoanState loanState = loan.state;
      // Validate if the order is ended
      ValidationLogic.validateOrderClaim(
        signMarket.loan.totalAssets,
        order,
        loanTotalAssets,
        loanState
      );
    }

    // Cache uToken and underlying asset addresses

    address underlyingAsset = loan.underlyingAsset;

    IUTokenFactory(_uTokenFactory).updateState(underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenFactory(_uTokenFactory).getReserveData(
      underlyingAsset
    );

    uint256 totalAmount = order.bid.amountToPay + order.bid.amountOfDebt;

    // We check if the bid is in the correct range in order to ensure that the HF is correct.
    // Because the interest can be grow and the auction endend and the liquidation can happend in mind time.

    ValidationLogic.validateFutureLoanState(
      ValidationLogic.ValidateLoanStateParams({
        amount: totalAmount,
        price: signMarket.assetPrice,
        reserveOracle: _reserveOracle,
        uTokenFactory: _uTokenFactory,
        reserve: reserve,
        loanConfig: signMarket.loan
      })
    );

    // Calculated the percentage desired by the user to repay
    totalAmount = OrderLogic.repayDebtToSell(
      order,
      OrderLogic.RepayDebtToSellParams({
        reserveOracle: _reserveOracle,
        underlyingAsset: underlyingAsset,
        uTokenFactory: _uTokenFactory,
        from: address(this),
        totalAmount: totalAmount,
        aggLoanPrice: signMarket.loan.aggLoanPrice,
        aggLtv: signMarket.loan.aggLtv
      }),
      reserve
    );

    if (totalAmount > 0) {
      // Return the amount to the owner
      IERC20(underlyingAsset).safeTransfer(order.owner, totalAmount);
    }
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
      // Update the loan
      _loans[order.bid.loanId].totalAssets = 1;
      // Once the asset is sended to the correct wallet we reactivate
      _loans[order.bid.loanId].activate();
    }

    // Cache loan ID
    bytes32 loanId = loan.loanId;

    if (_loans[loan.loanId].totalAssets != signMarket.loan.totalAssets + 1) {
      revert Errors.LoanNotUpdated();
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

      delete _orders[order.orderId];

      // We transfer the ownership to the new Owner
      IProtocolOwner(delegationOwnerOwner).changeOwner(
        signMarket.collection,
        signMarket.tokenId,
        buyer
      );

      emit MarketClaim(loanId, order.orderId, signMarket.assetId, totalAmount, msgSender);
    }
  }

  /**
   * @dev Function to cancel a claim. It can only be executed if, due to the variation in the price of the asset,
   * the minBid is larger than the bid made in the auction, and you want to recover the money deposited.
   * @param orderId identifier of the order
   * @param signMarket struct with information of the loan and prices
   * @param sig validation of this struct
   */
  function cancelClaim(
    bytes32 orderId,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signMarket, sig);
    DataTypes.Order memory order = _orders[orderId];

    // Get the loan asigned to the Order
    DataTypes.Loan storage loan = _loans[signMarket.loan.loanId];

    if (order.offer.loanId != signMarket.loan.loanId) {
      revert Errors.InvalidLoanId();
    }

    {
      // Avoid stack too deep
      uint88 loanTotalAssets = loan.totalAssets;
      Constants.LoanState loanState = loan.state;
      // Validate if the order is ended
      ValidationLogic.validateOrderClaim(
        signMarket.loan.totalAssets,
        order,
        loanTotalAssets,
        loanState
      );
    }

    // Cache uToken and underlying asset addresses
    address underlyingAsset = loan.underlyingAsset;

    IUTokenFactory(_uTokenFactory).updateState(underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenFactory(_uTokenFactory).getReserveData(
      underlyingAsset
    );

    uint256 totalAmount = order.bid.amountToPay + order.bid.amountOfDebt;

    {
      uint256 minBid = OrderLogic.getMaxDebtOrDefault(
        order.offer.loanId,
        _uTokenFactory,
        totalAmount,
        signMarket.loan.aggLoanPrice,
        signMarket.loan.aggLtv,
        reserve
      );
      // WARNING
      // We check if the minBid is bigger than the amount added, in this case,
      // anyone can cancel the current bid and refund the amount deposited.
      if (totalAmount >= minBid) {
        revert Errors.AmountExceedsDebt();
      }
    }
    // We assume that the LTV is enough to cover the growing interest in this bid
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: order.bid.loanId,
        owner: order.bid.buyer,
        reserveOracle: _reserveOracle,
        from: address(this),
        underlyingAsset: loan.underlyingAsset,
        uTokenFactory: _uTokenFactory,
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
    DataTypes.Loan storage loan = _loans[signMarket.loan.loanId];

    if (order.offer.loanId != signMarket.loan.loanId) {
      revert Errors.InvalidLoanId();
    }

    {
      // Avoid stack too deep
      uint88 loanTotalAssets = loan.totalAssets;
      Constants.LoanState loanState = loan.state;

      ValidationLogic.validateBuyNow(
        signMarket.loan.totalAssets,
        order,
        loanTotalAssets,
        loanState
      );
    }

    // Cache uToken and underlying asset addresses

    address underlyingAsset = loan.underlyingAsset;

    IUTokenFactory(_uTokenFactory).updateState(underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenFactory(_uTokenFactory).getReserveData(
      underlyingAsset
    );

    uint256 totalAmount = amountToPay + amountOfDebt;

    {
      // Check what is the correct pricing for this asset
      uint256 assetPrice = OrderLogic.getMaxDebtOrDefault(
        order.offer.loanId,
        _uTokenFactory,
        order.offer.endAmount,
        signMarket.loan.aggLoanPrice,
        signMarket.loan.aggLtv,
        reserve
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
            underlyingAsset: reserve.underlyingAsset,
            uTokenFactory: _uTokenFactory,
            amountOfDebt: amountOfDebt,
            assetPrice: signMarket.assetPrice,
            assetLtv: signMarket.assetLtv
          })
        );
        // Create the loan associated
        _loans[newLoanId].createLoan(
          LoanLogic.ParamsCreateLoan({
            msgSender: msgSender,
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
            from: address(this),
            underlyingAsset: underlyingAsset,
            uTokenFactory: _uTokenFactory,
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
        uTokenFactory: _uTokenFactory,
        from: address(this),
        totalAmount: totalAmount,
        aggLoanPrice: signMarket.loan.aggLoanPrice,
        aggLtv: signMarket.loan.aggLtv
      }),
      reserve
    );

    if (totalAmount > 0) {
      // Return the amount to the owner
      IERC20(underlyingAsset).safeTransfer(order.owner, totalAmount);
    }

    address protocolOwner = GenericLogic.getMainWalletProtocolOwner(_walletRegistry, order.owner);
    // Get the wallet of the owner

    // We remove the current order asociated to this asset
    delete _orders[orderId];

    if (_loans[loan.loanId].totalAssets != signMarket.loan.totalAssets + 1) {
      revert Errors.LoanNotUpdated();
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

    // We transfer the ownership to the new Owner
    IProtocolOwner(protocolOwner).changeOwner(signMarket.collection, signMarket.tokenId, buyer);

    emit MarketBuyNow(signMarket.loan.loanId, orderId, signMarket.assetId, totalAmount, msgSender);
  }
}
