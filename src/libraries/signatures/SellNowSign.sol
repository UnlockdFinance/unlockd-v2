// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Errors} from '../../libraries/helpers/Errors.sol';
import {BaseSignature} from '../../libraries/base/BaseSignature.sol';
import {CoreStorage} from '../storage/CoreStorage.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {AssetLogic} from '../../libraries/logic/AssetLogic.sol';

contract SellNowSign is BaseSignature {
  string internal constant NAME = 'SignSellNow';
  string internal constant VERSION = '1';

  bytes32 internal constant TYPEHASH =
    0xb71ba05a3ff283a3c38d89a7da467e39f8d9ea231799d2657f9e1202fe345fe3;

  constructor() BaseSignature(NAME, VERSION) {
    // NOTHINIG TO DO
  }

  function calculateDigest(
    uint256 nonce,
    DataTypes.SignSellNow calldata signSellNow
  ) public view validateDeadline(signSellNow.deadline) returns (bytes32 digest) {
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signSellNow));
    }
  }

  function _validateSignature(
    address msgSender,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) internal {
    if (msgSender == address(0)) {
      revert Errors.SenderZeroAddress();
    }
    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender]++, signSellNow),
      _signer,
      signSellNow.deadline,
      sig
    );
  }

  function _getStructHash(
    uint256 nonce,
    DataTypes.SignSellNow calldata sellNowSign
  ) internal pure returns (bytes32 result) {
    result = keccak256(
      abi.encode(
        TYPEHASH,
        LoanLogic.getLoanStructHash(nonce, sellNowSign.loan),
        sellNowSign.assetId,
        sellNowSign.marketAdapter,
        sellNowSign.marketApproval,
        sellNowSign.marketPrice,
        sellNowSign.underlyingAsset,
        sellNowSign.from,
        sellNowSign.to,
        keccak256(abi.encodePacked(sellNowSign.data)),
        sellNowSign.value,
        nonce,
        sellNowSign.deadline
      )
    );
  }
}
