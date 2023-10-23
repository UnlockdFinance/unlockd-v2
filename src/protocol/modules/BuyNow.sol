// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeTransferLib} from '@solady/utils/SafeTransferLib.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';

import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';

import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';
import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {BuyNowLogic} from '../../libraries/logic/BuyNowLogic.sol';

import {IBuyNowModule} from '../../interfaces/modules/IBuyNowModule.sol';
import {BuyNowSign} from '../../libraries/signatures/BuyNowSign.sol';

import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract BuyNow is BaseCoreModule, BuyNowSign, IBuyNowModule {
  using SafeTransferLib for address;
  using LoanLogic for DataTypes.Loan;

  constructor(uint256 moduleId, bytes32 moduleVersion) BaseCoreModule(moduleId, moduleVersion) {
    // NOTHING TO DO
  }

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
   *  @dev WARNING : Get the calculation without validation
   *  @param uToken address of the Utoken to calculate the payment
   *  @param signBuyMarket struct with the information needed about the asset to realize the buy
   *
   */
  function getCalculations(
    address uToken,
    DataTypes.SignBuyNow calldata signBuyMarket
  ) external view isUTokenAllowed(uToken) returns (uint256, uint256) {
    return BuyNowLogic.calculations(uToken, signBuyMarket);
  }

  /**
   * @dev BuyNowPayLater functionality, allow the user to buy a asset throw the adapter implementation
   * and create a loan on belhalf of this new NFT to pay part of the final price.
   * @param marketAdapter Address of the adapter to buy the asset
   * @param uToken address of the UToken coin to proceed with the buy
   * @param amount Amount that the user wan't to use to buy the asset
   * @param signBuyMarket signed struct with the information needed to proceed the process
   * @param sig validation of the signature
   */
  function buy(
    address marketAdapter,
    address uToken,
    uint256 amount,
    DataTypes.SignBuyNow calldata signBuyMarket,
    DataTypes.EIP712Signature calldata sig
  ) external isMarketAdapterAllowed(marketAdapter) isUTokenAllowed(uToken) {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signBuyMarket, sig);

    CalculatedDataBuyNow memory vars;

    (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
      _walletRegistry,
      msgSender
    );
    // Update pool liquidity
    IUToken(uToken).updateStateReserve();

    DataTypes.ReserveData memory reserve = IUToken(uToken).getReserve();
    // We move the funds from user to the Adapter
    reserve.underlyingAsset.safeTransferFrom(msgSender, marketAdapter, amount);

    // If the user don't pay the full amount we create a loan
    if (amount < signBuyMarket.marketPrice) {
      vars.loanId = _borrowLoan(
        msgSender,
        marketAdapter,
        amount,
        uToken,
        protocolOwner,
        reserve.underlyingAsset,
        signBuyMarket
      );
    }

    {
      Errors.verifyAreEquals(wallet, signBuyMarket.from);

      // Buy the asset
      vars.realCost = IMarketAdapter(marketAdapter).buy(
        IMarketAdapter.BuyParams({
          wallet: wallet,
          underlyingAsset: signBuyMarket.underlyingAsset,
          marketPrice: signBuyMarket.marketPrice,
          marketApproval: signBuyMarket.marketApproval,
          to: signBuyMarket.to,
          value: signBuyMarket.value,
          data: signBuyMarket.data
        })
      );

      // Validate we recived the NFT.
      Errors.verifyAreEquals(
        IERC721(signBuyMarket.asset.collection).ownerOf(signBuyMarket.asset.tokenId),
        wallet
      );
    }

    emit BuyNowPayLater(
      vars.loanId,
      signBuyMarket.asset.collection,
      signBuyMarket.asset.tokenId,
      vars.realCost,
      amount
    );
  }

  function _borrowLoan(
    address msgSender,
    address marketAdapter,
    uint256 amount,
    address uToken,
    address protocolOwner,
    address underlyingAsset,
    DataTypes.SignBuyNow calldata signBuyMarket
  ) internal returns (bytes32 loanId) {
    (uint256 minAmount, ) = BuyNowLogic.calculations(uToken, signBuyMarket);

    // We check that the amount is bigger or equal than the minimum
    if (minAmount > amount) {
      revert Errors.AmountToLow();
    }
    uint256 amountNeeded = signBuyMarket.marketPrice - amount;
    // Create LOAN
    loanId = LoanLogic.generateId(msgSender, signBuyMarket.nonce, signBuyMarket.deadline);

    _loans[loanId].createLoan(
      LoanLogic.ParamsCreateLoan({
        msgSender: msgSender,
        uToken: uToken,
        underlyingAsset: underlyingAsset,
        totalAssets: 1,
        loanId: loanId
      })
    );
    // We borrow on belhalf of the user and sent the money to the Adapter.
    IUToken(uToken).borrowOnBelhalf(loanId, amountNeeded, marketAdapter, msgSender);
    // Set the new NFT assigned to the LoanId
    IProtocolOwner(protocolOwner).setLoanId(signBuyMarket.asset.assetId, loanId);
  }
}
