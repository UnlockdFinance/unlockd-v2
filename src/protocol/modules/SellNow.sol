// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {BaseCoreModule, IACLManager} from '../../libraries/base/BaseCoreModule.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {SellNowLogic} from '../../libraries/logic/SellNowLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';
import {OrderLogic} from '../../libraries/logic/OrderLogic.sol';

import {MathUtils} from '../../libraries/math/MathUtils.sol';

import {SellNowSign} from '../../libraries/signatures/SellNowSign.sol';
import {ISellNowModule} from '../../interfaces/modules/ISellNowModule.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';

import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract SellNow is BaseCoreModule, SellNowSign, ISellNowModule {
  using SafeERC20 for IERC20;
  using OrderLogic for DataTypes.Order;
  using LoanLogic for DataTypes.Loan;

  /**
   * @dev check if the market is allowed on the protocol
   * @param adapter Address of the Adapter
   *
   */
  modifier isMarketAdapterAllowed(address adapter) {
    if (_allowedMarketAdapter[adapter] == 0) revert Errors.AdapterNotAllowed();
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Auction Admin ROLE
   */
  modifier onlyAuctionAdmin() {
    if (IACLManager(_aclManager).isAuctionAdmin(unpackTrailingParamMsgSender()) == false)
      revert Errors.AccessDenied();
    _;
  }

  constructor(uint256 moduleId, bytes32 moduleVersion) BaseCoreModule(moduleId, moduleVersion) {
    // NOTHING TO DO
  }

  /**
   * @dev Force liquidation of a NFT managed by the bot from Unlockd
   * @param marketAdapter market used to sell the asset
   * @param asset asset to sell
   * @param signSellNow struct the information to sell the asset
   * @param sig validation of
   */
  function forzeSell(
    address marketAdapter,
    DataTypes.Asset calldata asset,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) external isMarketAdapterAllowed(marketAdapter) onlyAuctionAdmin {
    address msgSender = unpackTrailingParamMsgSender();

    _validateSignature(msgSender, signSellNow, sig);

    DataTypes.Loan memory loan = _loans[signSellNow.loan.loanId];

    IUToken(loan.uToken).updateStateReserve();
    DataTypes.ReserveData memory reserve = IUToken(loan.uToken).getReserve();

    uint256 totalDebt = ValidationLogic.validateFutureUnhealtyLoanState(
      ValidationLogic.ValidateLoanStateParams({
        user: loan.owner,
        amount: 0,
        price: signSellNow.marketPrice,
        reserveOracle: _reserveOracle,
        reserve: reserve,
        loanConfig: signSellNow.loan
      })
    );

    {
      (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
        _walletRegistry,
        loan.owner
      );
      // Check if this user has unlockd wallet
      Errors.verifyNotZero(wallet);
      // Validate current ownership
      ValidationLogic.validateOwnerAsset(wallet, asset.collection, asset.tokenId);
      // Sell the asset using the adapter
      SellNowLogic.sellAsset(
        SellNowLogic.SellParams({
          loanId: loan.loanId,
          asset: asset,
          signSellNow: signSellNow,
          wallet: wallet,
          protocolOwner: protocolOwner,
          marketAdapter: marketAdapter
        })
      );
    }
    // Repay debs and send funds to the user wallet
    SellNowLogic.repayDebtAndUser(
      SellNowLogic.RepayDebtAndUserParams({
        loanId: loan.loanId,
        aggLoanPrice: signSellNow.loan.aggLoanPrice,
        aggLtv: signSellNow.loan.aggLtv,
        totalDebt: totalDebt,
        marketPrice: signSellNow.marketPrice,
        underlyingAsset: loan.underlyingAsset,
        uToken: loan.uToken,
        owner: loan.owner
      })
    );
    if (_loans[signSellNow.loan.loanId].totalAssets != signSellNow.loan.totalAssets + 1) {
      revert Errors.TokenAssetsMismatch();
    }
    if (signSellNow.loan.totalAssets > 1) {
      // Activate loan
      _loans[loan.loanId].activate();
      _loans[signSellNow.loan.loanId].totalAssets = signSellNow.loan.totalAssets;
    } else {
      // If there is only one we can remove the loan
      delete _loans[loan.loanId];
    }

    emit ForceSold(
      signSellNow.loan.loanId,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      asset.collection,
      asset.tokenId,
      signSellNow.marketPrice
    );
  }

  /**
   * @dev Sell a nft on the market, can be locked on a loan and repay the debt until arrives to HF > 1
   * @param marketAdapter market used to sell the asset
   * @param asset asset to sell
   * @param signSellNow struct the information to sell the asset
   * @param sig validation of
   */
  function sell(
    address marketAdapter,
    DataTypes.Asset calldata asset,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) external isMarketAdapterAllowed(marketAdapter) {
    address msgSender = unpackTrailingParamMsgSender();

    _validateSignature(msgSender, signSellNow, sig);

    (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
      _walletRegistry,
      msgSender
    );
    // Check if this user has unlockd wallet
    Errors.verifyNotZero(wallet);
    // Validate current ownership
    ValidationLogic.validateOwnerAsset(wallet, asset.collection, asset.tokenId);

    uint256 totalDebt = 0;
    address uToken = address(0);
    bytes32 assetId = AssetLogic.assetId(asset.collection, asset.tokenId);
    // Check if is not already locked
    if (IProtocolOwner(protocolOwner).isAssetLocked(assetId) == true) {
      DataTypes.Loan memory loan = _loans[signSellNow.loan.loanId];
      uToken = loan.uToken;
      IUToken(loan.uToken).updateStateReserve();
      DataTypes.ReserveData memory reserve = IUToken(loan.uToken).getReserve();

      totalDebt = ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          user: loan.owner,
          amount: signSellNow.marketPrice,
          price: signSellNow.marketPrice,
          reserveOracle: _reserveOracle,
          reserve: reserve,
          loanConfig: signSellNow.loan
        })
      );
    }
    // Sell the asset using the adapter
    SellNowLogic.sellAsset(
      SellNowLogic.SellParams({
        loanId: signSellNow.loan.loanId,
        asset: asset,
        signSellNow: signSellNow,
        wallet: wallet,
        protocolOwner: protocolOwner,
        marketAdapter: marketAdapter
      })
    );

    // Repay debs and send funds to the user wallet
    if (totalDebt > 0) {
      SellNowLogic.repayDebtAndUser(
        SellNowLogic.RepayDebtAndUserParams({
          loanId: signSellNow.loan.loanId,
          aggLoanPrice: signSellNow.loan.aggLoanPrice,
          aggLtv: signSellNow.loan.aggLtv,
          totalDebt: totalDebt,
          marketPrice: signSellNow.marketPrice,
          underlyingAsset: signSellNow.underlyingAsset,
          uToken: uToken,
          owner: msgSender
        })
      );

      if (_loans[signSellNow.loan.loanId].totalAssets != signSellNow.loan.totalAssets + 1) {
        revert Errors.TokenAssetsMismatch();
      }
      // If we don't have more loans we can remoe it
      if (signSellNow.loan.totalAssets == 0) {
        delete _loans[signSellNow.loan.loanId];
      } else {
        // We update the counter
        _loans[signSellNow.loan.loanId].totalAssets = signSellNow.loan.totalAssets;
      }
    } else {
      // If there is no debt we send the amount to the user
      IERC20(signSellNow.underlyingAsset).safeTransfer(msgSender, signSellNow.marketPrice);
    }

    emit Sold(
      signSellNow.loan.loanId,
      assetId,
      asset.collection,
      asset.tokenId,
      signSellNow.marketPrice
    );
  }
}
