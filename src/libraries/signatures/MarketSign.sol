// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Errors} from '../../libraries/helpers/Errors.sol';
import {BaseSignature} from '../../libraries/base/BaseSignature.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {CoreStorage} from '../storage/CoreStorage.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract MarketSign is BaseSignature {
  string internal constant NAME = 'SignMarket';
  string internal constant VERSION = '1';

  bytes32 internal constant TYPEHASH =
    0xe2c65ba1936d7b01e83e66ebd6dc2381ac954780414c6e43d41dd69c8653327c;

  constructor() BaseSignature(NAME, VERSION) {
    // NOTHINIG TO DO
  }

  function calculateDigest(
    uint256 nonce,
    DataTypes.SignMarket calldata signMarket
  ) public view validateDeadline(signMarket.deadline) returns (bytes32 digest) {
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signMarket));
    }
  }

  function _validateSignature(
    address msgSender,
    DataTypes.SignMarket calldata signMarket,
    DataTypes.EIP712Signature calldata sig
  ) internal {
    if (msgSender == address(0)) {
      revert Errors.SenderZeroAddress();
    }
    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender]++, signMarket),
      _signer,
      signMarket.deadline,
      sig
    );
  }

  function _getStructHash(
    uint256 nonce,
    DataTypes.SignMarket calldata signMarket
  ) internal pure returns (bytes32 structHash) {
    structHash = keccak256(
      abi.encode(
        TYPEHASH,
        LoanLogic.getLoanStructHash(nonce, signMarket.loan),
        signMarket.assetId,
        signMarket.collection,
        signMarket.tokenId,
        signMarket.assetPrice,
        signMarket.assetLtv,
        nonce,
        signMarket.deadline
      )
    );
  }
}
