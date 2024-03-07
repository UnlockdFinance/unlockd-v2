// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {BaseCore} from '../libraries/base/BaseCore.sol';
import {ICore} from '../interfaces/ICore.sol';
import {Constants} from '../libraries/helpers/Constants.sol';
import {ACLManager} from '../libraries/configuration/ACLManager.sol';
import {Errors} from '../libraries/helpers/Errors.sol';

/**
 * @title Unlockd Protocol
 * @author Unlockd
 * @notice Router
 * @dev fork from https://github.com/euler-xyz/euler-contracts/blob/master/contracts/Euler.sol
 */
contract Unlockd is ICore, BaseCore {
  constructor(address aclManager, address installerModule) {
    Errors.verifyNotZero(aclManager);
    Errors.verifyNotZero(installerModule);

    emit Genesis();

    _aclManager = aclManager;

    // Installer
    _moduleLookup[Constants.MODULEID__INSTALLER] = installerModule;
    address installerProxy = _createProxy(Constants.MODULEID__INSTALLER);
    _trustedSenders[installerProxy].moduleImpl = installerModule;
  }

  string public constant NAME = 'Unlockd Protocol V2';

  function moduleIdToImplementation(uint256 moduleId) external view returns (address) {
    return _moduleLookup[moduleId];
  }

  function moduleIdToProxy(uint256 moduleId) external view returns (address) {
    return _proxyLookup[moduleId];
  }

  function dispatch() external reentrantOK {
    assembly {
      // get moduleId and moduleImpl slot from trustedSenders mapping
      mstore(0x00, caller())
      mstore(0x20, _trustedSenders.slot)
      let slot := sload(keccak256(0x00, 0x40))

      // moduleId is the first 32 bits of the slot
      let moduleId := and(slot, 0xFFFFFFFF)
      // moduleImpl is the 160 bits after the first 32 bits
      let moduleImpl := shr(96, shl(64, slot))

      // if (moduleId == 0) revert Errors.InvalidParams();
      if iszero(moduleId) {
        mstore(0x00, 0xa86b6512)
        revert(0x1c, 0x04)
      }

      // if (moduleImpl == address(0)) moduleImpl = _moduleLookup[moduleId];
      if iszero(moduleImpl) {
        mstore(0x00, moduleId)
        mstore(0x20, _moduleLookup.slot)
        moduleImpl := sload(keccak256(0x00, 0x40))
      }

      // if (msg.data.length < (4 + 4 + 20)) revert Errors.BaseInputToShort();
      if lt(calldatasize(), 28) {
        mstore(0x00, 0xa18d5bdc)
        revert(0x1c, 0x04)
      }

      let payloadSize := sub(calldatasize(), 4)
      calldatacopy(0, 4, payloadSize)
      mstore(payloadSize, shl(96, caller()))

      let result := delegatecall(gas(), moduleImpl, 0, add(payloadSize, 20), 0, 0)

      returndatacopy(0, 0, returndatasize())

      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
