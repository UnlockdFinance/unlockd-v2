// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {BaseSignature} from '../../libraries/base/BaseSignature.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';

contract ActionSign is BaseSignature {
  string internal constant NAME = 'SignAction';
  string internal constant VERSION = '1';

  bytes32 internal constant TYPEHASH =
    0xaea5ef078039001523d9d26ac859c8b25b58fd95973363be47520b7cf95915b8;

  constructor() BaseSignature(NAME, VERSION) {
    // DO NOTHING
  }

  function calculateDigest(
    uint256 nonce,
    DataTypes.SignAction calldata signAction
  ) public view validateDeadline(signAction.deadline) returns (bytes32 digest) {
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signAction));
    }
  }

  function _validateSignature(
    address msgSender,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) internal {
    if (msgSender == address(0)) {
      revert Errors.SenderZeroAddress();
    }
    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender]++, signAction),
      _signer,
      signAction.deadline,
      sig
    );
  }

  function _getStructHash(
    uint256 nonce,
    DataTypes.SignAction calldata signAction
  ) internal pure returns (bytes32 structHash) {
    structHash = keccak256(
      abi.encode(
        TYPEHASH,
        LoanLogic.getLoanStructHash(nonce, signAction.loan),
        keccak256(abi.encodePacked(signAction.assets)),
        nonce,
        signAction.deadline
      )
    );
  }
}
