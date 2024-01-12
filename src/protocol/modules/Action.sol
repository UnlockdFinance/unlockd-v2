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
import {IUTokenFactory} from '../../interfaces/IUTokenFactory.sol';
import {ISafeERC721} from '../../interfaces/ISafeERC721.sol';
import {UTokenFactory} from '../UTokenFactory.sol';
import {ActionSign} from '../../libraries/signatures/ActionSign.sol';

import {DataTypes} from '../../types/DataTypes.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {Constants} from '../../libraries/helpers/Constants.sol';

// import {console} from 'forge-std/console.sol';

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
   * @dev Get the amount of debt pending on this loan
   * @param loanId identifier of the Loan
   */
  function getAmountToRepay(bytes32 loanId) external view returns (uint256 amount) {
    DataTypes.Loan memory loan = _loans[loanId];
    return GenericLogic.calculateLoanDebt(loanId, _uTokenFactory, loan.underlyingAsset);
  }

  /**
   * @dev This borrow function has diferent behavior
   *  - Create a new loan and borrow some colateral
   *  - If the amount is 0 and you pass the array of assets you can add colaterall to a especific loanId
   *  - If the amount is > 0 and the loanId exist
   *  @param amount Amount asked for the user to perform the borrow
   *  @param assets Array of assets for interaction should maintain the same order as the signature action.
   *  @param signAction struct with all the parameter needed to perform the borrow
   *  @param sig validation of the signature
   *
   * */
  function borrow(
    uint256 amount,
    DataTypes.Asset[] calldata assets,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    _checkHasUnlockdWallet(msgSender);

    // We validate the signature
    _validateSignature(msgSender, signAction, sig);

    uint256 cachedAssets = assets.length;

    DataTypes.ReserveData memory reserve = UTokenFactory(_uTokenFactory).getReserveData(
      signAction.underlyingAsset
    );
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
          underlyingAsset: signAction.underlyingAsset,
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

      if (loan.underlyingAsset != signAction.underlyingAsset) {
        revert Errors.InvalidUnderlyingAsset();
      }
    }

    if (cachedAssets != 0) {
      (address wallet, address protocolOwner) = GenericLogic.getMainWallet(
        _walletRegistry,
        msgSender
      );
      // Lock the asset

      for (uint256 i; i < cachedAssets; ) {
        DataTypes.Asset memory asset = assets[i];
        bytes32 assetId = AssetLogic.assetId(asset.collection, asset.tokenId);

        // Validation of params
        if (assetId != signAction.assets[i]) {
          revert Errors.AssetsMismatch();
        }

        if (
          UTokenFactory(_uTokenFactory).validateReserveType(
            reserve.reserveType,
            _allowedCollections[asset.collection]
          ) == false
        ) {
          revert Errors.NotValidReserve();
        }

        if (IProtocolOwner(protocolOwner).isAssetLocked(assetId) == true) {
          revert Errors.AssetLocked();
        }

        if (ISafeERC721(_safeERC721).ownerOf(asset.collection, asset.tokenId) != wallet) {
          revert Errors.NotAssetOwner();
        }

        IProtocolOwner(protocolOwner).setLoanId(assetId, loan.loanId);
        unchecked {
          ++i;
        }
      }
      // Update total assets
      _loans[loan.loanId].totalAssets = loan.totalAssets + uint88(cachedAssets);
    }

    // If the amount is 0 we don't need to borrow more
    if (amount != 0) {
      // We validate if the user can borrow
      ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          amount: amount,
          price: 0,
          reserveOracle: _reserveOracle,
          uTokenFactory: _uTokenFactory,
          reserve: reserve,
          loanConfig: signAction.loan
        })
      );

      if (loan.state != Constants.LoanState.ACTIVE) {
        revert Errors.LoanNotActive();
      }

      // We have to update the index BEFORE obtaining the borrowed amount.
      UTokenFactory(_uTokenFactory).updateState(loan.underlyingAsset);

      UTokenFactory(_uTokenFactory).borrow(
        loan.underlyingAsset,
        loan.loanId,
        amount,
        msgSender,
        msgSender
      );
    }

    if (signAction.loan.totalAssets != _loans[loan.loanId].totalAssets) {
      revert Errors.LoanNotUpdated();
    }

    emit Borrow(msgSender, loan.loanId, amount, loan.totalAssets, loan.underlyingAsset);
  }

  /**
   * @dev Repay the specific debt for a Loan but also perform different actions
   *  - Repay current debt defining the amount to repay
   *  - Unlock x amount of assets if the HF > 1 on the assets list
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

    if (loan.underlyingAsset != signAction.underlyingAsset) {
      revert Errors.InvalidUnderlyingAsset();
    }

    UTokenFactory uTokenFactory = UTokenFactory(_uTokenFactory);

    if (type(uint256).max == amount) {
      // If the amount is uint max we return the full amount
      amount = uTokenFactory.getScaledDebtFromLoanId(loan.underlyingAsset, loan.loanId);
    }

    DataTypes.ReserveData memory reserve = uTokenFactory.getReserveData(loan.underlyingAsset);
    uTokenFactory.updateState(loan.underlyingAsset);

    if (amount != 0) {
      ValidationLogic.validateRepay(signAction.loan.loanId, _uTokenFactory, amount, reserve);

      uTokenFactory.repay(loan.underlyingAsset, loan.loanId, amount, msgSender, msgSender);
    }

    if (signAction.assets.length != 0) {
      /**
        We validate if the loan is healthy.
        The aggLoanPrice of the Loan should be the value after removing the assets assigned to the loan.
      */
      ValidationLogic.validateFutureLoanState(
        ValidationLogic.ValidateLoanStateParams({
          amount: amount,
          price: 0,
          reserveOracle: _reserveOracle,
          uTokenFactory: _uTokenFactory,
          reserve: reserve,
          loanConfig: signAction.loan
        })
      );

      if (loan.state != Constants.LoanState.ACTIVE) {
        revert Errors.LoanNotActive();
      }

      // Get protocol owner
      address protocolOwner = GenericLogic.getMainWalletProtocolOwner(_walletRegistry, msgSender);

      // Unlock specific assets
      IProtocolOwner(protocolOwner).batchSetToZeroLoanId(signAction.assets);
    }

    if (signAction.loan.totalAssets != _loans[loan.loanId].totalAssets - signAction.assets.length) {
      revert Errors.LoanNotUpdated();
    }
    // If the loan is empty we remove the loan
    if (signAction.loan.totalAssets == 0) {
      // We remove the loan
      delete _loans[loan.loanId];
    } else {
      // We update the current number of assets on the loan
      _loans[loan.loanId].totalAssets = signAction.loan.totalAssets;
    }

    emit Repay(msgSender, loan.loanId, amount, signAction.assets);
  }
}
