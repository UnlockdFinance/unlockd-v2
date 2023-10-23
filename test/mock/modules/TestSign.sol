// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {Errors} from '../../../src/libraries/helpers/Errors.sol';
import {BaseSignature} from '../../../src/libraries/base/BaseSignature.sol';
import {CoreStorage} from '../../../src/libraries/storage/CoreStorage.sol';
import {DataTypes} from '../../../src/types/DataTypes.sol';
import {LoanLogic} from '../../../src/libraries/logic/LoanLogic.sol';

contract TestSign is BaseSignature {
  string internal constant NAME = 'SignTest';
  string internal constant VERSION = '1';

  struct SignTest {
    DataTypes.SignLoanConfig loan;
    bytes32[] assets;
    uint256 nonce;
    uint256 deadline;
  }
  bytes32 internal constant LOAN_TYPEHASH =
    keccak256(
      'SignLoanConfig(bytes32 loanId,uint256 aggLoanPrice,uint256 aggLtv,uint256 aggLiquidationThreshold,uint256 totalAssets,uint256 nonce,uint256 deadline)'
    );
  bytes32 internal constant TYPEHASH =
    keccak256(
      'SignTest(SignLoanConfig loan,bytes32[] assets,uint256 nonce,uint256 deadline)SignLoanConfig(bytes32 loanId,uint256 aggLoanPrice,uint256 aggLtv,uint256 aggLiquidationThreshold,uint256 totalAssets,uint256 nonce,uint256 deadline)'
    );

  constructor() BaseSignature(NAME, VERSION) {
    // NOTHINIG TO DO
  }

  function calculateDigest(
    uint256 nonce,
    SignTest calldata signTest
  ) public view validateDeadline(signTest.deadline) returns (bytes32) {
    bytes32 digest;
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signTest));
    }
    return digest;
  }

  function _validateSignature(
    address msgSender,
    SignTest calldata signTest,
    DataTypes.EIP712Signature calldata sig
  ) internal {
    Errors.verifyNotZero(msgSender);
    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender]++, signTest),
      _signer,
      signTest.deadline,
      sig
    );
  }

  function _getStructHash(
    uint256 nonce,
    SignTest calldata signTest
  ) internal pure returns (bytes32) {
    bytes32 result;
    {
      result = keccak256(
        abi.encode(
          TYPEHASH,
          LoanLogic.getLoanStructHash(nonce, signTest.loan),
          keccak256(abi.encodePacked(signTest.assets)),
          nonce,
          signTest.deadline
        )
      );
    }
    return result;
  }
}
