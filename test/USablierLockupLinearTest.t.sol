// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {Unlockd} from '../src/protocol/Unlockd.sol';
import {USablierLockupLinear} from '../src/protocol/wrappers/USablierLockupLinear.sol';
import {ISablierV2LockupLinear} from '../src/interfaces/wrappers/ISablierV2LockupLinear.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract USablierLockupLinearTest is Setup {
  uint256 internal constant ACTOR = 1;

  address internal _wethAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
  address internal _usdcAddress = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
  USablierLockupLinear sablierLockUp;
  ISablierV2LockupLinear sablier = ISablierV2LockupLinear(0xd4300c5bC0B9e27c73eBAbDc747ba990B1B570Db);
  

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4783334);
    Unlockd unlockd = super.getUnlockd();
    vm.startPrank(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));

    USablierLockupLinear implementation = new USablierLockupLinear(address(sablier));
    address proxyAddress = address(
      new ERC1967Proxy(
        address(implementation), 
        abi.encodeWithSelector(
            implementation.initialize.selector, 
            address(sablier), 
            address(_aclManager), 
            _wethAddress, 
            _usdcAddress, 
            "Unlockd bound Sablier LL", 
            "USABLL"
          )
        )
      );

    sablierLockUp = USablierLockupLinear(proxyAddress);
    vm.stopPrank();
  }

  function testInitialization() public {
    assertEq(sablierLockUp._wethAddress(), _wethAddress, "WETH address mismatch");
    assertEq(sablierLockUp._usdcAddress(), _usdcAddress, "USDC address mismatch");
  }
}