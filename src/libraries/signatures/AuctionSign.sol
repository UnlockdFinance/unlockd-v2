// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

import {BaseSignature} from '../../libraries/base/BaseSignature.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';

contract AuctionSign is BaseSignature {
  string internal constant NAME = 'SignAuction';
  string internal constant VERSION = '1';

  bytes32 internal constant TYPEHASH =
    0x8d31d2830b9056b8637f9437088166b8c1e8016edcc3e8d4d70f79b0e0b86f42;

  constructor() BaseSignature(NAME, VERSION) {
    // NOTHINIG TO DO
  }

  function calculateDigest(
    uint256 nonce,
    DataTypes.SignAuction calldata signAuction
  ) public view validateDeadline(signAuction.deadline) returns (bytes32 digest) {
    unchecked {
      digest = _hashTypedData(_getStructHash(nonce, signAuction));
    }
  }

  function _validateSignature(
    address msgSender,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) internal {
    if (msgSender == address(0)) {
      revert Errors.SenderZeroAddress();
    }
    // Validate signature
    _validateRecoveredAddress(
      calculateDigest(_signNonce[msgSender]++, signAuction),
      _signer,
      signAuction.deadline,
      sig
    );
  }

  function _getStructHash(
    uint256 nonce,
    DataTypes.SignAuction calldata signAuction
  ) internal pure returns (bytes32 structHash) {
    structHash = keccak256(
      abi.encode(
        TYPEHASH,
        LoanLogic.getLoanStructHash(nonce, signAuction.loan),
        signAuction.assetId,
        signAuction.collection,
        signAuction.tokenId,
        signAuction.assetPrice,
        signAuction.assetLtv,
        signAuction.endTime,
        nonce,
        signAuction.deadline
      )
    );
  }
}
