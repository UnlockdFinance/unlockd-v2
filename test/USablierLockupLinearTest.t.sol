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

import {IWETH} from './test-utils/mock/asset/IWETH.sol';

contract USablierLockupLinearTest is Setup {
  uint256 internal constant ACTOR = 1;

  address internal _wethAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
  address internal _usdcAddress = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
  USablierLockupLinear sablierLockUp;
  ISablierV2LockupLinear sablier = ISablierV2LockupLinear(0xd4300c5bC0B9e27c73eBAbDc747ba990B1B570Db);
  
  function setUp() public virtual override {
    super.setUpByChain(11155111, 4783334);
    vm.startPrank(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));

    USablierLockupLinear implementation = new USablierLockupLinear(address(sablier));
    address _proxyAddress = address(
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

    sablierLockUp = USablierLockupLinear(address(_proxyAddress));
    vm.stopPrank();
  }

  function testInitialization() public {
    assertEq(sablierLockUp._wethAddress(), _wethAddress, "WETH address mismatch");
    assertEq(sablierLockUp._usdcAddress(), _usdcAddress, "USDC address mismatch");
  }

  function testMintReverts() public {
    vm.prank(address(2)); // Simulate a call from an unauthorized address
    vm.expectRevert();
    sablierLockUp.mint(address(0), 1);
  }

  // function testUpgrade() public {
  //  USablierLockupLinear newImplementation = new USablierLockupLinear(address(sablier));
  //  UUPSUpgradeable(address(sablierLockUp)).upgradeTo(address(newImplementation));
  //  assertEq(address(UUPSUpgradeable(address(sablierLockUp))._getImplementation()), address(newImplementation), "Implementation should be updated");
  // }

  function testMint() public {
    // Simulate a call from an authorized address
    mintSablierNFT();
    sablierLockUp.mint(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(1)), 1, "Balance should be 1");
  }

  function mintSablierNFT() public {
     // Simulate a call from an authorized address
    IERC20(_wethAddress).approve(address(sablier), 2 ether);
    
    ISablierV2LockupLinear.Durations memory duration = ISablierV2LockupLinear.Durations({
      cliff: 1701375965,
      total: 1701529208
    });

    ISablierV2LockupLinear.Broker memory broker = ISablierV2LockupLinear.Broker({
      fee: 0,
      account: address(0)
    });

    ISablierV2LockupLinear.CreateWithDurations memory create = ISablierV2LockupLinear.CreateWithDurations({
        sender: address(1),
        recipient: address(2),
        totalAmount: 1 ether,
        asset: IERC20(_wethAddress),
        cancelable: false,
        durations: duration,
        broker: broker
    });

    sablier.createWithDurations(create);

  }
}