// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

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
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';
import {ISafeERC721} from '../../interfaces/ISafeERC721.sol';
import {IBuyNowModule} from '../../interfaces/modules/IBuyNowModule.sol';
import {BuyNowSign} from '../../libraries/signatures/BuyNowSign.sol';

import {ReserveConfiguration} from '../../libraries/configuration/ReserveConfiguration.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract BuyNow is BaseCoreModule, BuyNowSign, IBuyNowModule {
  using SafeTransferLib for address;
  using LoanLogic for DataTypes.Loan;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  constructor(uint256 moduleId, bytes32 moduleVersion) BaseCoreModule(moduleId, moduleVersion) {
    // NOTHING TO DO
  }

  /**
   *  @dev Get the calculation
   *  @param signBuyMarket struct with the information needed about the asset to realize the buy
   *
   */
  function getCalculations(
    DataTypes.SignBuyNow calldata signBuyMarket
  ) external pure returns (uint256, uint256) {
    return BuyNowLogic.calculations(signBuyMarket);
  }

  /**
   * @dev BuyNowPayLater functionality, allow the user to buy a asset throw the adapter implementation
   * and create a loan on belhalf of this new NFT to pay part of the final price.
   * @param amount Amount that the user wan't to use to buy the asset
   * @param signBuyMarket signed struct with the information needed to proceed the process
   * @param sig validation of the signature
   */
  function buy(
    uint256 amount,
    DataTypes.SignBuyNow calldata signBuyMarket,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signBuyMarket, sig);

    CalculatedDataBuyNow memory vars;

    (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
      _walletRegistry,
      msgSender
    );
    // Update pool liquidity
    IUTokenVault(_uTokenVault).updateState(signBuyMarket.underlyingAsset);
    DataTypes.ReserveData memory reserve = IUTokenVault(_uTokenVault).getReserveData(
      signBuyMarket.underlyingAsset
    );
    // We move the funds from user to the Adapter
    reserve.underlyingAsset.safeTransferFrom(msgSender, signBuyMarket.marketAdapter, amount);

    // If the user don't pay the full amount we create a loan
    if (amount < signBuyMarket.marketPrice) {
      if (
        IUTokenVault(_uTokenVault).validateReserveType(
          reserve.config.getReserveType(),
          _allowedCollections[signBuyMarket.asset.collection]
        ) == false
      ) {
        revert Errors.NotValidReserve();
      }
      vars.loanId = _borrowLoan(msgSender, amount, protocolOwner, signBuyMarket);
    }

    {
      Errors.verifyAreEquals(wallet, signBuyMarket.from);

      // Buy the asset
      vars.realCost = IMarketAdapter(signBuyMarket.marketAdapter).buy(
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
        ISafeERC721(_safeERC721).ownerOf(
          signBuyMarket.asset.collection,
          signBuyMarket.asset.tokenId
        ),
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
    uint256 amount,
    address protocolOwner,
    DataTypes.SignBuyNow calldata signBuyMarket
  ) internal returns (bytes32 loanId) {
    (uint256 minAmount, ) = BuyNowLogic.calculations(signBuyMarket);

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
        underlyingAsset: signBuyMarket.underlyingAsset,
        totalAssets: 1,
        loanId: loanId
      })
    );
    // We borrow on belhalf of the user and sent the money to the Adapter.
    IUTokenVault(_uTokenVault).borrow(
      signBuyMarket.underlyingAsset,
      loanId,
      amountNeeded,
      signBuyMarket.marketAdapter,
      msgSender
    );
    // Set the new NFT assigned to the LoanId
    IProtocolOwner(protocolOwner).setLoanId(signBuyMarket.asset.assetId, loanId);
  }
}
