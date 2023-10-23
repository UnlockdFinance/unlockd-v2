// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CoreStorage} from '../storage/CoreStorage.sol';
import {ICore} from '../../interfaces/ICore.sol';
import {UnlockdMinimalProxy} from '../proxy/UnlockdMinimalProxy.sol';
import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';

import {console} from 'forge-std/console.sol';

abstract contract BaseCore is CoreStorage, ICore {
  function _createProxy(uint256 proxyModuleId) internal returns (address) {
    if (proxyModuleId == 0) {
      revert Errors.InvalidModule();
    }
    if (proxyModuleId > Constants.MAX_EXTERNAL_MODULEID) {
      revert Errors.InvalidModule();
    }

    // If we've already created a proxy for a single-proxy module, just return it:
    if (_proxyLookup[proxyModuleId] != address(0)) return _proxyLookup[proxyModuleId];

    // Otherwise create a proxy:
    address proxyAddr = address(new UnlockdMinimalProxy());

    if (proxyModuleId <= Constants.MAX_EXTERNAL_SINGLE_PROXY_MODULEID) {
      _proxyLookup[proxyModuleId] = proxyAddr;
    }

    TrustedSenderInfo storage trustedSenderInfo = _trustedSenders[proxyAddr];

    trustedSenderInfo.moduleId = uint32(proxyModuleId);

    emit ProxyCreated(proxyAddr, proxyModuleId);

    return proxyAddr;
  }

  function callInternalModule(
    uint256 moduleId,
    bytes memory input
  ) internal returns (bytes memory) {
    (bool success, bytes memory result) = _moduleLookup[moduleId].delegatecall(input);
    console.log('SUCCESS', success);
    if (!success) revertBytes(result);
    return result;
  }

  // Modifiers

  modifier reentrantOK() {
    // documentation only
    _;
  }

  // Used to flag functions which do not modify storage, but do perform a delegate call
  // to a view function, which prohibits a standard view modifier. The flag is used to
  // patch state mutability in compiled ABIs and interfaces.
  modifier staticDelegate() {
    _;
  }

  // WARNING: Must be very careful with this modifier. It resets the free memory pointer
  // to the value it was when the function started. This saves gas if more memory will
  // be allocated in the future. However, if the memory will be later referenced
  // (for example because the function has returned a pointer to it) then you cannot
  // use this modifier.

  modifier FREEMEM() {
    uint256 origFreeMemPtr;
    assembly {
      origFreeMemPtr := mload(0x40)
    }
    _;
    /*  
        assembly { // DEV_MODE: overwrite the freed memory with garbage to detect bugs
            let garbage := 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF
            for { let i := origFreeMemPtr } lt(i, mload(0x40)) { i := add(i, 32) } { mstore(i, garbage) }
        }
        */

    assembly {
      mstore(0x40, origFreeMemPtr)
    }
  }

  // Error handling
  function revertBytes(bytes memory errMsg) internal pure {
    if (errMsg.length > 0) {
      assembly {
        revert(add(32, errMsg), mload(errMsg))
      }
    }

    revert Errors.RevertEmptyBytes();
  }
}
