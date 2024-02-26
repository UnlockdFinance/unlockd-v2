// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeTransferLib} from '@solady/utils/SafeTransferLib.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {IDelegationOwner} from '@unlockd-wallet/src/interfaces/IDelegationOwner.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {SafeCastLib} from '@solady/utils/SafeCastLib.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';

import {BaseCoreModule, IACLManager} from '../../libraries/base/BaseCoreModule.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IAuctionModule} from '../../interfaces/modules/IAuctionModule.sol';
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';
import {AuctionSign} from '../../libraries/signatures/AuctionSign.sol';

import {PercentageMath} from '../../libraries/math/PercentageMath.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';
import {OrderLogic} from '../../libraries/logic/OrderLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';

import {DataTypes} from '../../types/DataTypes.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {Constants} from '../../libraries/helpers/Constants.sol';

import {console} from 'forge-std/console.sol';

contract Auction is BaseCoreModule, AuctionSign, IAuctionModule {
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using PercentageMath for uint256;
  using SafeTransferLib for address;
  using SafeERC20 for IERC20;
  using SafeCastLib for uint256;
  using OrderLogic for DataTypes.Order;
  using LoanLogic for DataTypes.Loan;

  constructor(
    uint256 moduleId_,
    bytes32 moduleVersion_
  ) BaseCoreModule(moduleId_, moduleVersion_) {}

  function getAmountToReedem(
    bytes32 loanId,
    bytes32[] calldata assets
  ) public view returns (uint256, uint256, uint256) {
    DataTypes.Loan memory loan = _loans[loanId];
    if (loan.owner == address(0)) return (0, 0, 0);
    uint256 totalDebt = GenericLogic.calculateLoanDebt(
      loan.loanId,
      _uTokenVault,
      loan.underlyingAsset
    );
    (uint256 totalAmount, uint256 totalBidderBonus, , ) = _calculateRedeemAmount(loan, assets);
    return (totalAmount + totalDebt, totalDebt, totalBidderBonus);
  }

  /**
   * @dev Get min bid on auction
   * @param loanId identifier of the loanId
   * @param assetId assetId of the asset
   * @param assetPrice price of this asset on the market
   * @param aggLoanPrice aggregated loan colaterized on the Loan
   * @param aggLtv aggregated ltv between assets on the Loan
   */
  function getMinBidPriceAuction(
    bytes32 loanId,
    bytes32 assetId,
    uint256 assetPrice,
    uint256 aggLoanPrice,
    uint256 aggLtv
  ) external view returns (uint256) {
    DataTypes.Loan memory loan = _loans[loanId];

    if (loan.owner == address(0) || loan.underlyingAsset == address(0)) return 0;

    DataTypes.ReserveData memory reserve = IUTokenVault(_uTokenVault).getReserveData(
      loan.underlyingAsset
    );
    // Calculate the order ID
    bytes32 orderId = OrderLogic.generateId(assetId, loanId);
    DataTypes.Order memory order = _orders[orderId];

    if (order.owner == address(0)) {
      return
        OrderLogic.getMinDebtOrDefault(
          loan.loanId,
          _uTokenVault,
          assetPrice,
          aggLoanPrice,
          aggLtv,
          reserve
        );
    }

    return OrderLogic.getMinBid(order, _uTokenVault, aggLoanPrice, aggLtv, reserve);
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

    bytes32 orderId = OrderLogic.generateId(signAuction.assets[0], signAuction.loan.loanId);

    IUTokenVault(_uTokenVault).updateState(loan.underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenVault(_uTokenVault).getReserveData(
      loan.underlyingAsset
    );

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
          _uTokenVault,
          signAuction.assetPrice,
          signAuction.loan.aggLoanPrice,
          signAuction.loan.aggLtv,
          reserve
        );

        // Validate bid in order
        // Check if the Loan is Unhealty

        ValidationLogic.validateFutureUnhealtyLoanState(
          ValidationLogic.ValidateLoanStateParams({
            amount: 0,
            price: signAuction.assetPrice,
            reserveOracle: _reserveOracle,
            uTokenVault: _uTokenVault,
            reserve: reserve,
            loanConfig: signAuction.loan
          })
        );

        // Creation of the Order
        order.createOrder(
          OrderLogic.ParamsCreateOrder({
            orderType: Constants.OrderType.TYPE_LIQUIDATION_AUCTION,
            orderId: orderId,
            owner: loan.owner,
            loanId: signAuction.loan.loanId,
            assetId: signAuction.assets[0],
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
          _uTokenVault,
          signAuction.loan.aggLoanPrice,
          signAuction.loan.aggLtv,
          reserve
        );

        // If the auction is in market, we migrate this type of auction to liquidation
        if (order.orderType != Constants.OrderType.TYPE_LIQUIDATION_AUCTION) {
          ValidationLogic.validateFutureUnhealtyLoanState(
            ValidationLogic.ValidateLoanStateParams({
              amount: order.bid.amountOfDebt + order.bid.amountToPay,
              price: signAuction.assetPrice,
              reserveOracle: _reserveOracle,
              uTokenVault: _uTokenVault,
              reserve: reserve,
              loanConfig: signAuction.loan
            })
          );
          // You only can convert the aution if the lastBid don't cover the debt
          order.updateToLiquidationOrder(
            OrderLogic.ParamsUpdateOrder({
              loanId: signAuction.loan.loanId,
              assetId: signAuction.assets[0],
              endTime: signAuction.endTime,
              minBid: uint128(minBid)
            })
          );
        }
      }
    }
    ValidationLogic.validateBid(totalAmount, signAuction.loan.totalAssets, minBid, order, loan);

    // stake the assets on the protocol
    loan.underlyingAsset.safeTransferFrom(msgSender, address(this), amountToPay);
    bytes32 loanId;
    // The bidder asks for a debt
    if (amountOfDebt != 0) {
      loanId = _createBidLoan(amountOfDebt, msgSender, loan.underlyingAsset, signAuction);
    }
    {
      if (order.countBids == 0) {
        // We repay the debt at the beginning
        // The ASSET only support a % of the current debt in case of the next bids
        // we are not repaying more debt until the auction is ended.

        OrderLogic.repayDebt(
          OrderLogic.RepayDebtParams({
            loanId: loan.loanId,
            owner: order.owner,
            from: address(this),
            underlyingAsset: loan.underlyingAsset,
            uTokenVault: _uTokenVault,
            amount: minBid
          })
        );
        // The first time we calculate the bonus for this user
        // BONUS AMOUNT
        order.bidderBonus = totalAmount.percentMul(GenericLogic.FIRST_BID_INCREMENT);

        // The protocol freeze the loan repayed until end of the auction
        // to protect against borrow again
        order.bidderDebtPayed = minBid;
        _loans[loan.loanId].freeze();
      } else {
        // Cancel debt from old bidder and refund
        uint256 amountToPayBuyer = order.bid.amountToPay;
        if (order.countBids == 1) {
          // The first bidder gets 2.5% of benefit over the second bidder
          // We increate the amount to repay
          amountToPayBuyer = amountToPayBuyer + order.bidderBonus;
        }
        // We assuming that the ltv is enought to cover the growing interest of this bid
        OrderLogic.refundBidder(
          OrderLogic.RefundBidderParams({
            loanId: order.bid.loanId,
            owner: order.bid.buyer,
            reserveOracle: _reserveOracle,
            from: address(this),
            underlyingAsset: loan.underlyingAsset,
            uTokenVault: _uTokenVault,
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

    emit AuctionBid(loanId, orderId, signAuction.assets[0], amountToPay, amountOfDebt, msgSender);
  }

  /**
   * @dev Unlock the Loan, recover the asset only if the auction is still active
  
   * @param amount amount of dept to pay
   * @param assets list of assets on the loan
   * @param signAuction struct of the data needed
   * @param sig validation of this struct
   * */
  function redeem(
    uint256 amount,
    bytes32[] calldata assets,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();

    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signAuction, sig);

    // Validate signature
    DataTypes.Loan storage loan = _loans[signAuction.loan.loanId];

    if (loan.owner != msgSender) {
      revert Errors.InvalidOrderOwner();
    }
    address underlyingAsset = loan.underlyingAsset;
    IUTokenVault(_uTokenVault).updateState(underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenVault(_uTokenVault).getReserveData(
      underlyingAsset
    );

    if (assets.length != signAuction.loan.totalAssets || loan.totalAssets != assets.length) {
      revert Errors.LoanNotUpdated();
    }

    uint256 totalDebt = GenericLogic.calculateLoanDebt(
      loan.loanId,
      _uTokenVault,
      loan.underlyingAsset
    );

    (
      uint256 totalAmount,
      ,
      uint256 assetsToRepay,
      bytes32[] memory ordersToUpdate
    ) = _calculateRedeemAmount(loan, assets);
    // We add the current debt
    totalAmount += totalDebt;
    if (totalAmount != amount) revert Errors.InvalidAmount();
    if (assetsToRepay == 0) revert Errors.InvalidAssets();

    underlyingAsset.safeTransferFrom(msgSender, address(this), totalAmount);

    // payments
    for (uint256 i; i < ordersToUpdate.length; i++) {
      {
        // Check if the assets are correct
        if (assets[i] != signAuction.assets[i]) revert Errors.AssetsMismatch();

        if (ordersToUpdate[i] == 0) continue;
        DataTypes.Order memory cacheOrder = _orders[ordersToUpdate[i]];

        if (cacheOrder.owner == address(0)) revert Errors.InvalidOrderOwner();
        uint256 amountToPayBuyer = cacheOrder.bid.amountToPay;

        if (cacheOrder.countBids == 1) {
          amountToPayBuyer = amountToPayBuyer + cacheOrder.bidderBonus;
        }

        OrderLogic.refundBidder(
          OrderLogic.RefundBidderParams({
            loanId: cacheOrder.bid.loanId,
            owner: cacheOrder.bid.buyer,
            reserveOracle: _reserveOracle,
            from: address(this),
            underlyingAsset: underlyingAsset,
            uTokenVault: _uTokenVault,
            amountOfDebt: cacheOrder.bid.amountOfDebt,
            amountToPay: amountToPayBuyer,
            reserve: reserve
          })
        );

        emit AuctionOrderRedeemed(
          loan.loanId,
          cacheOrder.orderId,
          cacheOrder.bid.amountOfDebt,
          cacheOrder.bid.amountToPay,
          cacheOrder.bidderBonus,
          cacheOrder.countBids
        );

        delete _orders[cacheOrder.orderId];
      }
    }

    if (totalDebt > 0) {
      IERC20(underlyingAsset).forceApprove(_uTokenVault, totalDebt);
      // We repay all the debt
      IUTokenVault(_uTokenVault).repay(
        underlyingAsset,
        loan.loanId,
        totalDebt,
        address(this),
        msgSender
      );
    }

    _loans[loan.loanId].activate();

    emit AuctionRedeem(loan.loanId, totalAmount, msgSender);
  }

  /**
   * @dev Finalize the liquidation auction once is expired in time.
   * @param claimOnUWallet Order identifier to redeem the asset and pay the debt related
   * @param orderId Order identifier to redeem the asset and pay the debt related
   * @param asset asset to liquidate
   * @param signAuction struct of the data needed
   * @param sig validation of this struct
   * */
  function finalize(
    bool claimOnUWallet,
    bytes32 orderId,
    DataTypes.Asset calldata asset,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _validateSignature(msgSender, signAuction, sig);

    bytes32 assetId = AssetLogic.assetId(asset.collection, asset.tokenId);
    if (signAuction.assets[0] != assetId) {
      revert Errors.AssetsMismatch();
    }
    DataTypes.Order memory order = _orders[orderId];

    if (order.owner == address(0)) revert Errors.InvalidOrderOwner();
    if (order.orderType != Constants.OrderType.TYPE_LIQUIDATION_AUCTION) {
      revert Errors.OrderNotAllowed();
    }
    if (order.offer.loanId != signAuction.loan.loanId) {
      revert Errors.InvalidLoanId();
    }
    bytes32 offerLoanId = order.offer.loanId;

    DataTypes.Loan storage loan = _loans[offerLoanId];

    // The aution need to be ended
    Errors.verifyExpiredTimestamp(order.timeframe.endTime, block.timestamp);

    // By default we get the EOA from the buyer
    address buyer = order.bid.buyer;
    address protocolOwnerBuyer;

    if (claimOnUWallet) {
      (address wallet, address protocol) = GenericLogic.getMainWallet(
        _walletRegistry,
        order.bid.buyer
      );
      buyer = wallet;
      protocolOwnerBuyer = protocol;
    }

    // If the bidder has a loan with the new asset
    // we need to activate the loan and change the ownership to this new loan
    if (order.bid.loanId != 0) {
      if (protocolOwnerBuyer == address(0)) {
        revert Errors.ProtocolOwnerZeroAddress();
      }
      // Block the asset
      IProtocolOwner(protocolOwnerBuyer).setLoanId(assetId, loan.loanId);
      // Update the loan
      _loans[order.bid.loanId].totalAssets = 1;
      // Activate the loan from the bidder
      _loans[order.bid.loanId].activate();
    }

    // The start amount it was payed as a debt
    uint256 amount = (order.bid.amountOfDebt + order.bid.amountToPay) -
      (order.bidderDebtPayed + order.bidderBonus);

    loan.underlyingAsset.safeTransfer(order.owner, amount);
    // Remove the order
    delete _orders[orderId];

    // Check the struct passed it's correct
    if (_loans[loan.loanId].totalAssets != signAuction.loan.totalAssets + 1) {
      revert Errors.LoanNotUpdated();
    }

    {
      // Check HF
      uint256 currentDebt = GenericLogic.calculateLoanDebt(
        signAuction.loan.loanId,
        _uTokenVault,
        loan.underlyingAsset
      );

      // We calculate the current debt and the HF
      uint256 healthFactor = GenericLogic.calculateHealthFactorFromBalances(
        signAuction.loan.aggLoanPrice,
        currentDebt,
        signAuction.loan.aggLiquidationThreshold
      );

      if (healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
        // If it's unhealty we can only update the totalAssets
        loan.totalAssets = signAuction.loan.totalAssets;
        // @dev if total assets is 0 we have this loan with a bad debt
      } else {
        // Healty path
        if (signAuction.loan.totalAssets == 0) {
          // If there is only one we can remove the loan
          delete _loans[offerLoanId];
        } else {
          // Activate loan
          loan.activate();
          loan.totalAssets = signAuction.loan.totalAssets;
        }
      }
    } // Get protocol owner from owner of the asset to transfer
    address protocolOwner = GenericLogic.getMainWalletProtocolOwner(_walletRegistry, order.owner);

    // We transfer the ownership to the new Owner
    IProtocolOwner(protocolOwner).changeOwner(
      asset.collection,
      asset.tokenId,
      // We send the asset to
      buyer
    );

    emit AuctionFinalize(
      offerLoanId,
      orderId,
      assetId,
      order.offer.startAmount,
      amount,
      order.bid.buyer,
      order.owner
    );
  }

  /////////////////////////////////////////////////////////////////////////////////////
  // PRIVATE
  /////////////////////////////////////////////////////////////////////////////////////

  function _createBidLoan(
    uint256 amountOfDebt,
    address msgSender,
    address underlyingAsset,
    DataTypes.SignAuction calldata signAuction
  ) internal returns (bytes32 loanId) {
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
        to: address(this),
        underlyingAsset: underlyingAsset,
        uTokenVault: _uTokenVault,
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
        underlyingAsset: underlyingAsset,
        totalAssets: 1,
        loanId: loanId
      })
    );
    // Freeze the loan until the auction is finished
    _loan.freeze();
  }

  function _calculateRedeemAmount(
    DataTypes.Loan memory loan,
    bytes32[] calldata assets
  ) internal view returns (uint256, uint256, uint256, bytes32[] memory) {
    if (loan.totalAssets != assets.length) {
      revert Errors.LoanNotUpdated();
    }
    address owner = loan.owner;
    bytes32 loanId = loan.loanId;
    uint256 totalBidderBonus;
    uint256 assetsToRepay;
    uint256 totalAmount;

    address protocolOwner = GenericLogic.getMainWalletProtocolOwner(_walletRegistry, owner);
    bytes32[] memory ordersIds = new bytes32[](assets.length); // TODO : Aqui esta el problema no todos seran
    for (uint256 i; i < assets.length; i++) {
      {
        bytes32 assetId = assets[i];

        bytes32 assetLoanId = IProtocolOwner(protocolOwner).getLoanId(assetId);

        if (assetLoanId != loanId) {
          revert Errors.InvalidLoanId();
        }

        bytes32 orderId = OrderLogic.generateId(assetId, assetLoanId);
        DataTypes.Order memory order = _orders[orderId];
        if (order.owner == address(0)) {
          // If there is no order created
          continue;
        }

        if (order.owner != owner) {
          // throw error in case that the loan is not the owner of the order
          revert Errors.InvalidLoanId();
        }

        // Only if the assets they had a pending order
        if (order.orderType != Constants.OrderType.TYPE_LIQUIDATION_AUCTION) {
          // We skip this scenario
          continue;
        }

        if (order.offer.loanId != loanId) {
          revert Errors.InvalidLoanId();
        }
        Errors.verifyNotExpiredTimestamp(order.timeframe.endTime, block.timestamp);

        totalBidderBonus += order.bidderBonus;
        totalAmount += order.bidderDebtPayed + order.bidderBonus;
        ordersIds[i] = orderId;
        assetsToRepay++;
      }
    }
    // We asign the list
    return (totalAmount, totalBidderBonus, assetsToRepay, ordersIds);
  }
}
