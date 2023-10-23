// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import '@solady/utils/ECDSA.sol';
import '../utils/EIP712.sol';

import {CoreStorage, DataTypes} from '../storage/CoreStorage.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';

/**
 * @title BaseSignature
 * @notice Base logic to implement EIP712
 * @author Unlockd
 */
abstract contract BaseSignature is EIP712, CoreStorage {
  using ECDSA for bytes32;

  modifier validateDeadline(uint256 deadline) {
    Errors.verifyNotExpiredTimestamp(deadline, block.timestamp);
    _;
  }

  constructor(string memory name, string memory version) EIP712(name, version) {
    // NOTHING TO DO
  }

  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  function _validateRecoveredAddress(
    bytes32 digest,
    address expectedAddress,
    uint256 deadline,
    DataTypes.EIP712Signature memory sig
  ) internal view returns (bool) {
    if (sig.deadline != deadline) {
      revert Errors.NotEqualDeadline();
    }
    Errors.verifyNotExpiredTimestamp(sig.deadline, block.timestamp);
    address recoveredAddress = _getAddressRecover(digest, sig);

    if (recoveredAddress != expectedAddress || recoveredAddress == address(0)) {
      revert Errors.InvalidRecoveredAddress();
    }
    return true;
  }

  function _getAddressRecover(
    bytes32 digest,
    DataTypes.EIP712Signature memory sig
  ) internal view returns (address) {
    return digest.recover(sig.v, sig.r, sig.s);
  }

  function _hashTypedData(bytes32 structHash) internal view returns (bytes32) {
    return _hashTypedDataV4(structHash);
  }

  function getNonce(address sender) external view returns (uint256) {
    return _signNonce[sender];
  }
}
