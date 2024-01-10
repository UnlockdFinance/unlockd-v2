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
    0x2b5fb3950865094faa266e01d5f20a42b500057e9664bd3e8cf41f17c14c163b;

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
        signAction.underlyingAsset,
        nonce,
        signAction.deadline
      )
    );
  }
}
