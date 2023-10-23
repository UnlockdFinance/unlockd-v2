// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {BaseCoreModule, Errors} from '../../src/libraries/base/BaseCoreModule.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';
import {console} from 'forge-std/console.sol';

contract TestBaseModuleCore is BaseCoreModule {
  uint256 internal _number = 0;

  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  function internalCall(uint256 moduleId, bytes memory input) external returns (bytes memory) {
    return callInternalModule(moduleId, input);
  }

  function incr() external {
    _number = _number + 1;
  }

  function getNumber() external view returns (uint256) {
    return _number;
  }
}

contract BaseCoreTest is Setup {
  Unlockd internal _unlockd;

  bytes32 internal version = '1';
  address internal _actor = address(1);

  function setUp() public virtual override {
    deploy_aclManager();
    _unlockd = new Unlockd(address(_aclManager), address(new Installer(version)));
  }

  function deploy_aclManager() internal {
    vm.startPrank(_admin);
    _aclManager = new ACLManager(_admin);
    // Configure ADMINS
    _aclManager.addUTokenAdmin(_admin);
    _aclManager.addProtocolAdmin(_admin);
    _aclManager.addGovernanceAdmin(_admin);
    _aclManager.addAuctionAdmin(_admin);
    _aclManager.addEmergencyAdmin(_admin);
    _aclManager.addPriceUpdater(_admin);
    vm.stopPrank();
  }

  function test_install_only_admin() public {
    address[] memory modules = new address[](1);
    modules[0] = address(new TestBaseModuleCore(2, version));
    address installer = _unlockd.moduleIdToProxy(1);
    vm.expectRevert(abi.encodeWithSelector(Errors.ProtocolAccessDenied.selector));
    Installer(installer).installModules(modules);
  }

  function test_create_proxy() public {
    vm.startPrank(_admin);
    address[] memory modules = new address[](1);
    modules[0] = address(new TestBaseModuleCore(2, version));
    address installer = _unlockd.moduleIdToProxy(1);
    Installer(installer).installModules(modules);
    // Check imp
    assertEq(_unlockd.moduleIdToImplementation(2), modules[0]);
    vm.stopPrank();
  }

  function test_internal_call() public {
    vm.startPrank(_admin);
    address[] memory modules = new address[](2);
    modules[0] = address(new TestBaseModuleCore(2, version));
    modules[1] = address(new TestBaseModuleCore(3, version));
    address installer = _unlockd.moduleIdToProxy(1);
    Installer(installer).installModules(modules);
    // Check imp
    assertEq(_unlockd.moduleIdToImplementation(2), modules[0]);
    TestBaseModuleCore(_unlockd.moduleIdToProxy(2)).internalCall(
      3,
      abi.encodeWithSelector(TestBaseModuleCore.incr.selector)
    );
    TestBaseModuleCore(_unlockd.moduleIdToProxy(3)).incr();
    assertEq(2, uint256(TestBaseModuleCore(_unlockd.moduleIdToProxy(3)).getNumber()));
    assertEq(2, uint256(TestBaseModuleCore(_unlockd.moduleIdToProxy(2)).getNumber()));
    vm.stopPrank();
  }
}
