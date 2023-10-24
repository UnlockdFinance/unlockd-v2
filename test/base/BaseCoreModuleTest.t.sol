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

  function getOnlyAdmin() external view onlyAdmin returns (bool) {
    return true;
  }

  function getOnlyGovernance() external view onlyGovernance returns (bool) {
    return true;
  }

  function getOnlyEmergency() external view onlyEmergency returns (bool) {
    return true;
  }

  function getOnlyByRole() external view onlyRole(keccak256('EMERGENCY_ADMIN')) returns (bool) {
    return true;
  }

  function getMsgSender() external view returns (address) {
    return unpackTrailingParamMsgSender();
  }

  function getMsgSenderAndProxy() external view returns (address, address) {
    return unpackTrailingParams();
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

  function test_role_admin() public {
    uint256 moduleId = 5;
    // Prepare
    vm.startPrank(_admin);
    address[] memory modules = new address[](1);
    modules[0] = address(new TestBaseModuleCore(moduleId, version));
    address installer = _unlockd.moduleIdToProxy(1);
    Installer(installer).installModules(modules);
    vm.stopPrank();
    // Checks
    address newUser = address(111999999);
    vm.startPrank(newUser);
    assertEq(_aclManager.isProtocolAdmin(newUser), false);
    address moduleAddress = _unlockd.moduleIdToProxy(moduleId);

    vm.expectRevert(abi.encodeWithSelector(Errors.ProtocolAccessDenied.selector));
    TestBaseModuleCore(moduleAddress).getOnlyAdmin();

    vm.stopPrank();
    // Add role admin to the userr
    hoax(_admin);
    _aclManager.addProtocolAdmin(newUser);

    hoax(newUser);
    assertEq(TestBaseModuleCore(moduleAddress).getOnlyAdmin(), true);
    assertEq(_aclManager.isProtocolAdmin(newUser), true);
  }

  function test_role_governance() public {
    uint256 moduleId = 5;
    // Prepare
    vm.startPrank(_admin);
    address[] memory modules = new address[](1);
    modules[0] = address(new TestBaseModuleCore(moduleId, version));
    address installer = _unlockd.moduleIdToProxy(1);
    Installer(installer).installModules(modules);
    vm.stopPrank();
    // Checks
    address newUser = address(111999999);
    vm.startPrank(newUser);
    assertEq(_aclManager.isGovernanceAdmin(newUser), false);
    address moduleAddress = _unlockd.moduleIdToProxy(moduleId);

    vm.expectRevert(abi.encodeWithSelector(Errors.GovernanceAccessDenied.selector));
    TestBaseModuleCore(moduleAddress).getOnlyGovernance();

    vm.stopPrank();
    // Add role admin to the userr
    hoax(_admin);
    _aclManager.addGovernanceAdmin(newUser);

    hoax(newUser);
    assertEq(TestBaseModuleCore(moduleAddress).getOnlyGovernance(), true);
    assertEq(_aclManager.isGovernanceAdmin(newUser), true);
  }

  function test_role_emergency() public {
    uint256 moduleId = 5;
    // Prepare
    vm.startPrank(_admin);
    address[] memory modules = new address[](1);
    modules[0] = address(new TestBaseModuleCore(moduleId, version));
    address installer = _unlockd.moduleIdToProxy(1);
    Installer(installer).installModules(modules);
    vm.stopPrank();
    // Checks
    address newUser = address(111999999);
    vm.startPrank(newUser);
    assertEq(_aclManager.isEmergencyAdmin(newUser), false);
    address moduleAddress = _unlockd.moduleIdToProxy(moduleId);

    vm.expectRevert(abi.encodeWithSelector(Errors.EmergencyAccessDenied.selector));
    TestBaseModuleCore(moduleAddress).getOnlyEmergency();
    vm.expectRevert(abi.encodeWithSelector(Errors.RoleAccessDenied.selector));
    TestBaseModuleCore(moduleAddress).getOnlyByRole();
    vm.stopPrank();
    // Add role admin to the userr
    hoax(_admin);
    _aclManager.addEmergencyAdmin(newUser);

    hoax(newUser);
    assertEq(TestBaseModuleCore(moduleAddress).getOnlyEmergency(), true);
    hoax(newUser);
    assertEq(TestBaseModuleCore(moduleAddress).getOnlyByRole(), true);

    assertEq(_aclManager.isEmergencyAdmin(newUser), true);
  }

  function test_get_msg_sender() public {
    uint256 moduleId = 5;
    // Prepare
    vm.startPrank(_admin);
    address[] memory modules = new address[](1);
    modules[0] = address(new TestBaseModuleCore(moduleId, version));
    address installer = _unlockd.moduleIdToProxy(1);
    Installer(installer).installModules(modules);
    vm.stopPrank();
    // Checks
    address moduleAddress = _unlockd.moduleIdToProxy(moduleId);
    // Add role admin to the userr

    hoax(address(111999999));
    assertEq(TestBaseModuleCore(moduleAddress).getMsgSender(), address(111999999));
    hoax(address(0));
    assertEq(TestBaseModuleCore(moduleAddress).getMsgSender(), address(address(0)));

    vm.startPrank(address(12123123123123123));

    (address msgSender, address proxy) = TestBaseModuleCore(moduleAddress).getMsgSenderAndProxy();
    assertEq(address(12123123123123123), msgSender);
    assertEq(moduleAddress, proxy);

    vm.stopPrank();
  }
}
