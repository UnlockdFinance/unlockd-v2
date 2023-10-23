// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {Constants} from '../../libraries/helpers/Constants.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';

contract Installer is BaseCoreModule {
  uint256 constant INSTALLERINSTALLMODULE_EVENT =
    0x15fc136599039b272cb44c0ace0b099754f2656d1d52691b99c9e348662c805a;

  constructor(
    bytes32 moduleVersion_
  ) BaseCoreModule(Constants.MODULEID__INSTALLER, moduleVersion_) {
    // NOTHING TO DO
  }

  function installModules(address[] memory moduleAddrs) external onlyAdmin {
    uint256 length = moduleAddrs.length;
    for (uint256 i; i < length; ) {
      address moduleAddr = moduleAddrs[i];
      uint256 newModuleId = BaseCoreModule(moduleAddr).moduleId();
      bytes32 moduleVersion = BaseCoreModule(moduleAddr).moduleVersion();

      _moduleLookup[newModuleId] = moduleAddr;

      if (newModuleId <= Constants.MAX_EXTERNAL_SINGLE_PROXY_MODULEID) {
        address proxyAddr = _createProxy(newModuleId);
        _trustedSenders[proxyAddr].moduleImpl = moduleAddr;
      }

      assembly {
        //  Emit the `InstallerInstallModule` event
        mstore(0x00, moduleVersion)
        log3(0x00, 0x20, INSTALLERINSTALLMODULE_EVENT, newModuleId, moduleAddr)
      }

      unchecked {
        ++i;
      }
    }
  }
}
