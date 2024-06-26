// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../../types/DataTypes.sol';
import {GenericLogic} from './GenericLogic.sol';
import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title LoanLogic library
 * @author Unlockd
 * @notice Implements protocol-level logic to calculate and validate the state of a user
 */
library LoanLogic {
  event LoanCreated(address indexed user, bytes32 indexed loanId, uint256 totalAssets);
  event FreezeLoan(bytes32 loanId);
  event ActivateLoan(bytes32 loanId);
  event BlockLoan(bytes32 loanId);

  bytes32 internal constant TYPEHASH =
    0x4b24ba5d0861514e3889c8dcf89590916d297469584a6cf27d0e9d3750a33970;

  struct ParamsCreateLoan {
    address msgSender;
    address underlyingAsset;
    bytes32 loanId;
    uint88 totalAssets;
  }

  /**
   * @dev generate unique loanId, because the nonce is x address and is incremental it should be unique.
   * @param msgSender address of the user
   * @param nonce incremental number
   * @param deadline timestamp
   * */
  function generateId(
    address msgSender,
    uint256 nonce,
    uint256 deadline
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(msgSender, abi.encodePacked(nonce, deadline)));
  }

  /**
   * @dev creates a new Loan object on the storage
   * @param loan storage of the loan
   * @param params Parameters to create the new loan
   */
  function createLoan(DataTypes.Loan storage loan, ParamsCreateLoan memory params) internal {
    unchecked {
      loan.loanId = params.loanId;
      loan.owner = params.msgSender;
      loan.underlyingAsset = params.underlyingAsset;
      loan.totalAssets = params.totalAssets;

      loan.state = Constants.LoanState.ACTIVE;
    }
    emit LoanCreated(params.msgSender, loan.loanId, params.totalAssets);
  }

  /**
   * @dev Freeze loan
   */
  function freeze(DataTypes.Loan storage loan) internal {
    loan.state = Constants.LoanState.FREEZE;
    emit FreezeLoan(loan.loanId);
  }

  /**
   * @dev Activate loan
   */
  function activate(DataTypes.Loan storage loan) internal {
    loan.state = Constants.LoanState.ACTIVE;
    emit ActivateLoan(loan.loanId);
  }

  /**
   * @dev Block loan
   */
  function blocked(DataTypes.Loan storage loan) internal {
    loan.state = Constants.LoanState.BLOCKED;
    emit BlockLoan(loan.loanId);
  }

  /**
   * @dev return the loan struct hashed
   * @param nonce Nonce of the signature
   */
  function getLoanStructHash(
    uint256 nonce,
    DataTypes.SignLoanConfig calldata signLoanConfig
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          TYPEHASH,
          signLoanConfig.loanId,
          signLoanConfig.aggLoanPrice,
          signLoanConfig.aggLtv,
          signLoanConfig.aggLiquidationThreshold,
          signLoanConfig.totalAssets,
          nonce,
          signLoanConfig.deadline
        )
      );
  }
}
