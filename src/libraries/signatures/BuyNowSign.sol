// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Errors} from '../../libraries/helpers/Errors.sol';
import {BaseSignature} from '../../libraries/base/BaseSignature.sol';
import {CoreStorage} from '../storage/CoreStorage.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {AssetLogic} from '../../libraries/logic/AssetLogic.sol';

contract BuyNowSign is BaseSignature {
  string internal constant NAME = 'SignBuyNow';
  string internal constant VERSION = '1';

  bytes32 internal constant TYPEHASH =
    0x6b77050f9bf3df21b1bd19ccdbf03be95abec0c1da32ea40a2950af432b17e6f;

  constructor() BaseSignature(NAME, VERSION) {
    // NOTHINIG TO DO
  }

  function calculateDigest(
    uint256 nonce,
    DataTypes.SignBuyNow calldata signBuyNow
  ) public view validateDeadline(signBuyNow.deadline) returns (bytes32 digest) {
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signBuyNow));
    }
  }

  function _validateSignature(
    address msgSender,
    DataTypes.SignBuyNow calldata signBuyNow,
    DataTypes.EIP712Signature calldata sig
  ) internal {
    if (msgSender == address(0)) {
      revert Errors.SenderZeroAddress();
    }

    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender]++, signBuyNow),
      _signer,
      signBuyNow.deadline,
      sig
    );
  }

  function _getStructHash(
    uint256 nonce,
    DataTypes.SignBuyNow calldata buyNowSign
  ) internal pure returns (bytes32) {
    bytes32 result;
    {
      result = keccak256(
        abi.encode(
          TYPEHASH,
          AssetLogic.getAssetStructHash(nonce, buyNowSign.asset),
          buyNowSign.marketAdapter,
          buyNowSign.assetLtv,
          buyNowSign.assetLiquidationThreshold,
          buyNowSign.from,
          buyNowSign.to,
          keccak256(abi.encodePacked(buyNowSign.data)),
          buyNowSign.value,
          buyNowSign.marketApproval,
          buyNowSign.marketPrice,
          buyNowSign.underlyingAsset,
          nonce,
          buyNowSign.deadline
        )
      );
    }
    return result;
  }
}
