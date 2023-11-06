// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';

import {ValidationLogic} from '../../libraries/logic/ValidationLogic.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';

import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';

import {IActionModule} from '../../interfaces/modules/IActionModule.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {ActionSign} from '../../libraries/signatures/ActionSign.sol';

import {DataTypes} from '../../types/DataTypes.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';

contract Action is BaseCoreModule, ActionSign, IActionModule {
  using LoanLogic for DataTypes.Loan;

  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  /**
   * @dev Get the current status of the LOAN
   * @param loanId identifier of the Loan
   */
  function getLoan(bytes32 loanId) external view returns (DataTypes.Loan memory) {
    return _loans[loanId];
  }

  /**
   * @dev This borrow function has diferent behavior
   *  - Create a new loan and borrow some colateral
   *  - If the amount is 0 and you pass the array of assets you can add colaterall to a especific loanId
   *  - If the amount is > 0 and the loanId exist
   *  @param uToken address of the utoken
   *  @param amount Amount asked for the user to perform the borrow
   *  @param signAction struct with all the parameter needed to perform the borrow
   *  @param sig validation of the signature
   *
   * */
  function borrow(
    address uToken,
    uint256 amount,
    DataTypes.Asset[] calldata assets,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) external isUTokenAllowed(uToken) {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    // We validate the signature
    _validateSignature(msgSender, signAction, sig);

    uint256 cachedAssets = assets.length;

    DataTypes.ReserveData memory reserve = IUToken(uToken).getReserve();

    // Generate the loanID
    // Check if exist
    DataTypes.Loan memory loan;
    // New Loan
    if (signAction.loan.loanId == 0) {
      if (cachedAssets == 0) {
        revert Errors.InvalidAssetAmount();
      }
      if (cachedAssets != signAction.loan.totalAssets) {
        revert Errors.InvalidArrayLength();
      }

      // Create a new one
      bytes32 loanId = LoanLogic.generateId(
        msgSender,
        signAction.loan.nonce,
        signAction.loan.deadline
      );
      _loans[loanId].createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
          uToken: uToken,
          underlyingAsset: reserve.underlyingAsset,
          // We added only when we lock the assets
          totalAssets: 0,
          loanId: loanId
        })
      );

      loan = _loans[loanId];
    } else {
      // Update Loan
      // If exist we validate if it's correct
      loan = _loans[signAction.loan.loanId];

      if (loan.owner != msgSender) {
        revert Errors.InvalidLoanOwner();
      }
      if (loan.uToken != uToken) {
        revert Errors.InvalidUToken();
      }
    }

    if (cachedAssets != 0) {
      // If there is a list of assets we block them to the new loanId

      (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
        _walletRegistry,
        msgSender
      );
      // Lock the asset

      for (uint256 i; i < cachedAssets; ) {
        DataTypes.Asset memory asset = assets[i];
        bytes32 assetId = AssetLogic.assetId(asset.collection, asset.tokenId);

        ValidationLogic.validateLockAsset(
          assetId,
          wallet,
          _allowedControllers,
          protocolOwner,
          asset
        );

        IProtocolOwner(protocolOwner).setLoanId(assetId, loan.loanId);
        unchecked {
          ++i;
        }
      }
      _loans[loan.loanId].totalAssets = loan.totalAssets + uint88(cachedAssets);
    }

    // If the amount is 0 we don't need to borrow more
    if (amount != 0) {
      // We validate if the user can borrow
      ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          user: msgSender,
          amount: amount,
          price: 0,
          reserveOracle: _reserveOracle,
          reserve: reserve,
          loanConfig: signAction.loan
        })
      );
      // update state MUST BEFORE get borrow amount which is depent on latest borrow index
      IUToken(uToken).updateStateReserve();

      IUToken(reserve.uToken).borrowOnBelhalf(loan.loanId, amount, msgSender, msgSender);
    }

    if (signAction.loan.totalAssets != _loans[loan.loanId].totalAssets) {
      revert Errors.TokenAssetsMismatch();
    }

    emit Borrow(msgSender, loan.loanId, amount, loan.totalAssets, loan.uToken);
  }

  /**
   * @dev Repay the dev for a Loan but also perform different actions
   *  - Repay current debt defining the amount to repay
   *  - Unlock x amount of assets if the HF is correct defined on the assets list
   *    NOTE: No need to be all the assets
   * */
  function repay(
    uint256 amount,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    _validateSignature(msgSender, signAction, sig);

    DataTypes.Loan memory loan = _loans[signAction.loan.loanId];

    if (loan.owner != msgSender) {
      revert Errors.NotEqualSender();
    }

    DataTypes.ReserveData memory reserve = IUToken(loan.uToken).getReserve();

    address reserveOracle = _reserveOracle;

    if (amount != 0) {
      ValidationLogic.validateRepay(
        signAction.loan.loanId,
        msgSender,
        amount,
        reserveOracle,
        reserve
      );

      IUToken(loan.uToken).updateStateReserve();
      IUToken(loan.uToken).repayOnBelhalf(loan.loanId, amount, msgSender, msgSender);
    }

    if (signAction.assets.length != 0) {
      /**
        We validate if the loan is healty .
        The aggLoanPrice of the Loan should be the value after removing the assets asigned to the loan
      */
      ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          user: msgSender,
          amount: amount,
          price: 0,
          reserveOracle: _reserveOracle,
          reserve: reserve,
          loanConfig: signAction.loan
        })
      );
      // Get delegation owner
      address protocolOwner = GenericLogic.getMainWalletProtocolOwner(_walletRegistry, msgSender);

      // Unlock specific assets
      IProtocolOwner(protocolOwner).batchSetToZeroLoanId(signAction.assets);
    }

    if (signAction.loan.totalAssets != _loans[loan.loanId].totalAssets - signAction.assets.length) {
      revert Errors.TokenAssetsMismatch();
    }
    // If the loan is full empty we remove the loan
    if (signAction.loan.totalAssets == 0) {
      // We remove the loan
      delete _loans[loan.loanId];
    } else {
      // We update the current number of assets on the loan
      _loans[loan.loanId].totalAssets = signAction.loan.totalAssets;
    }

    emit Repay(msgSender, loan.loanId, amount, signAction.assets.length);
  }
}
