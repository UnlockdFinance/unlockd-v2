// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {ISafeERC721} from '../../interfaces/ISafeERC721.sol';
import {BaseCoreModule, IACLManager} from '../../libraries/base/BaseCoreModule.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {SellNowLogic} from '../../libraries/logic/SellNowLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';
import {OrderLogic} from '../../libraries/logic/OrderLogic.sol';

import {MathUtils} from '../../libraries/math/MathUtils.sol';

import {SellNowSign} from '../../libraries/signatures/SellNowSign.sol';
import {ISellNowModule} from '../../interfaces/modules/ISellNowModule.sol';
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';

// import {IUToken} from '../../interfaces/tokens/IUToken.sol';

import {Errors} from '../../libraries/helpers/Errors.sol';
import {Constants} from '../../libraries/helpers/Constants.sol';

import {DataTypes} from '../../types/DataTypes.sol';

contract SellNow is BaseCoreModule, SellNowSign, ISellNowModule {
  using SafeERC20 for IERC20;
  using OrderLogic for DataTypes.Order;
  using LoanLogic for DataTypes.Loan;

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
   * @param asset asset to sell
   * @param signSellNow struct the information to sell the asset
   * @param sig validation of
   */
  function forceSell(
    DataTypes.Asset calldata asset,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) external onlyAuctionAdmin {
    address msgSender = unpackTrailingParamMsgSender();

    _validateSignature(msgSender, signSellNow, sig);

    DataTypes.Loan memory loan = _loans[signSellNow.loan.loanId];

    IUTokenVault(_uTokenVault).updateState(loan.underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenVault(_uTokenVault).getReserveData(
      loan.underlyingAsset
    );
    uint256 totalDebt = IUTokenVault(_uTokenVault).getScaledDebtFromLoanId(
      loan.underlyingAsset,
      loan.loanId
    );

    ValidationLogic.validateFutureUnhealtyLoanState(
      ValidationLogic.ValidateLoanStateParams({
        amount: 0,
        price: signSellNow.marketPrice,
        reserveOracle: _reserveOracle,
        uTokenVault: _uTokenVault,
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
      if (ISafeERC721(_safeERC721).ownerOf(asset.collection, asset.tokenId) != wallet) {
        revert Errors.NotAssetOwner();
      }

      // Sell the asset using the adapter
      SellNowLogic.sellAsset(
        SellNowLogic.SellParams({
          loanId: loan.loanId,
          asset: asset,
          signSellNow: signSellNow,
          wallet: wallet,
          protocolOwner: protocolOwner,
          marketAdapter: signSellNow.marketAdapter
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
        uTokenVault: _uTokenVault,
        owner: loan.owner
      })
    );

    if (_loans[signSellNow.loan.loanId].totalAssets != signSellNow.loan.totalAssets + 1) {
      revert Errors.LoanNotUpdated();
    }
    if (signSellNow.loan.totalAssets == 0) {
      // If there is only one we can remove the loan
      delete _loans[loan.loanId];
    } else {
      // Activate loan
      _loans[loan.loanId].activate();
      _loans[signSellNow.loan.loanId].totalAssets = signSellNow.loan.totalAssets;
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
   * @param asset asset to sell
   * @param signSellNow struct the information to sell the asset
   * @param sig validation of
   */
  function sell(
    DataTypes.Asset calldata asset,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();

    _validateSignature(msgSender, signSellNow, sig);

    (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
      _walletRegistry,
      msgSender
    );
    // Check if this user has unlockd wallet
    Errors.verifyNotZero(wallet);
    bytes32 assetId = AssetLogic.assetId(asset.collection, asset.tokenId);

    // Validate current ownership
    if (ISafeERC721(_safeERC721).ownerOf(asset.collection, asset.tokenId) != wallet) {
      revert Errors.NotAssetOwner();
    }

    uint256 totalDebt = 0;

    bytes32 assetLoanId = IProtocolOwner(protocolOwner).getLoanId(assetId);
    // Check if is not already locked
    if (assetLoanId != 0) {
      if (assetLoanId != signSellNow.loan.loanId) {
        revert Errors.InvalidLoanId();
      }

      DataTypes.Loan memory loan = _loans[signSellNow.loan.loanId];

      // The loan need to be active
      if (loan.state != Constants.LoanState.ACTIVE) {
        revert Errors.LoanNotActive();
      }

      IUTokenVault(_uTokenVault).updateState(loan.underlyingAsset);
      DataTypes.ReserveData memory reserve = IUTokenVault(_uTokenVault).getReserveData(
        loan.underlyingAsset
      );

      ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          amount: signSellNow.marketPrice,
          price: signSellNow.marketPrice,
          reserveOracle: _reserveOracle,
          uTokenVault: _uTokenVault,
          reserve: reserve,
          loanConfig: signSellNow.loan
        })
      );

      totalDebt = IUTokenVault(_uTokenVault).getScaledDebtFromLoanId(
        loan.underlyingAsset,
        loan.loanId
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
        marketAdapter: signSellNow.marketAdapter
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
          uTokenVault: _uTokenVault,
          owner: msgSender
        })
      );

      if (_loans[signSellNow.loan.loanId].totalAssets != signSellNow.loan.totalAssets + 1) {
        revert Errors.LoanNotUpdated();
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
