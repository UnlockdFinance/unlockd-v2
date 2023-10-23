// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {Errors} from '../../../src/libraries/helpers/Errors.sol';
import {DataTypes} from '../../../src/types/DataTypes.sol';
import {BaseSignature} from '../../../src/libraries/base/BaseSignature.sol';

contract SignatureMock is BaseSignature {
  string internal constant NAME = 'SignAction';
  string internal constant VERSION = '1';

  bytes32 TYPEHASH = keccak256('SignAction(uint256 random,uint256 nonce,uint256 deadline)');

  struct SignMock {
    uint256 random;
    uint256 nonce;
    uint256 deadline;
  }

  constructor(address signer) BaseSignature('SignAction', '1') {
    _signer = signer;
  }

  function calculateDigest(
    uint256 nonce,
    SignMock calldata signAction
  ) public view validateDeadline(signAction.deadline) returns (bytes32) {
    bytes32 digest;
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signAction));
    }
    return digest;
  }

  function validateSignature(
    address msgSender,
    SignMock calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) external {
    Errors.verifyNotZero(msgSender);
    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender], signAction),
      _signer,
      signAction.deadline,
      sig
    );
    unchecked {
      _signNonce[msgSender]++;
    }
  }

  function getAddressRecover(
    bytes32 digest,
    DataTypes.EIP712Signature memory sig
  ) external view returns (address) {
    return _getAddressRecover(digest, sig);
  }

  function _getStructHash(
    uint256 nonce,
    SignMock calldata signAction
  ) internal view returns (bytes32) {
    return keccak256(abi.encode(TYPEHASH, signAction.random, nonce, signAction.deadline));
  }
}
