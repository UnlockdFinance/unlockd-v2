// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {BaseCore, Errors} from '../../src/libraries/base/BaseCore.sol';

import {console} from 'forge-std/console.sol';

contract TestBaseCore is BaseCore {
  uint256 internal _id;

  function createProxy(uint256 id) external returns (address) {
    _id = id;
    return _createProxy(id);
  }

  function internalCall(uint256 moduleId, bytes memory input) external returns (bytes memory) {
    return callInternalModule(moduleId, input);
  }

  function getId() external view returns (uint256) {
    return _id;
  }
}

contract BaseCoreTest is Setup {
  TestBaseCore internal _test;

  function setUp() public virtual override {
    _test = new TestBaseCore();
  }

  function test_create_proxy() public {
    address proxy = _test.createProxy(2);
    assertNotEq(proxy, address(0));
  }

  function test_create_proxy_invalid_id() public {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidModule.selector));
    address proxy = _test.createProxy(0);
  }

  function test_create_proxy_max_modules() public {
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidModule.selector));
    address proxy = _test.createProxy(999_999_999);
  }

  // function test_internal_call() public {
  //   TestBaseCore moduleOne = new TestBaseCore();
  //   address oneProxy = moduleOne.createProxy(2);
  //   TestBaseCore moduleTwo = new TestBaseCore();
  //   address twoProxy = moduleTwo.createProxy(3);
  //   bytes memory result = moduleOne.internalCall(
  //     3,
  //     abi.encodeWithSelector(TestBaseCore.getId.selector)
  //   );
  // }
}
