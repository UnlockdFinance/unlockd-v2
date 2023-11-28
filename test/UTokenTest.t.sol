// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';

import './test-utils/setups/Setup.sol';
import './test-utils/mock/MaxApyMirror.sol';

import '../src/protocol/UToken.sol';
import '../src/interfaces/tokens/IUToken.sol';
import '../src/interfaces/strategies/IMaxApyVault.sol';

contract UTokenSetup is Setup {
  uint256 internal constant ACTOR = 1;

  address internal _manager;

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4783334);
    Unlockd unlockd = super.getUnlockd();
    vm.startPrank(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));
    vm.stopPrank();
  }

  function test_basic_deposit() internal useAssetActor(ACTOR, 100000) {
    UToken uToken = getUToken('WETH');
    super.approveAsset('WETH', address(uToken), 100000);
    uToken.deposit(100000, super.getActorAddress(ACTOR), 0);
    assertEq(uToken.balanceOf(super.getActorAddress(ACTOR)), 100000);
  }

  function test_basic_withdraw() internal useAssetActor(ACTOR, 100000) {
    string memory token = 'WETH';
    address actor = super.getActorAddress(ACTOR);
    UToken uToken = super.getUToken(token);
    // DEPOSIT
    super.approveAsset(token, address(uToken), 100000);
    uToken.deposit(100000, actor, 0);
    assertEq(uToken.balanceOf(actor), 100000);

    // WITHDRAW
    uToken.withdraw(100000, actor);
    assertEq(uToken.balanceOf(actor), 0);
    assertEq(balanceOfAsset(token, actor), 100000);
  }

  function test_deposit_less_min_cap() public {
    vm.assume(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])) == 0);
    UToken uToken = getUToken('WETH');
    address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);

    vm.startPrank(actor);
    approveAsset('WETH', address(uToken), 0.5 ether);
    uToken.deposit(0.5 ether, super.getActorAddress(ACTOR), 0);
    vm.stopPrank();

    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])), 0.5 ether);
  }

  // function test_deposit_more_min_cap() public {
  //   vm.assume(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])) == 0);
  //   UToken uToken = getUToken('WETH');
  //   address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);

  //   vm.startPrank(actor);
  //   approveAsset('WETH', address(uToken), 3 ether);
  //   uToken.deposit(3 ether, super.getActorAddress(ACTOR), 0);
  //   vm.stopPrank();

  //   assertEq(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])), 2 ether);
  // }

  // function test_borrow_below_min_cap() public {
  //   test_deposit_more_min_cap();
  //   UToken uToken = getUToken('WETH');
  //   vm.assume(uToken.totalSupply() == 3 ether);

  //   vm.startPrank(makeAddr('protocol'));
  //   uToken.borrowOnBelhalf('1', 1 ether, makeAddr('protocol'), makeAddr('protocol'));
  //   vm.stopPrank();
  //   assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 1 ether);
  // }

  function test_borrow_more_than_minCap() public {
    // address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);

    console.log('SHARES', IMaxApyVault(config.maxapy).shareValue(1 ether));
    // vm.assume(IMaxApyVault(config.maxapy).shareValue(1 ether) == 1 ether);

    // vm.startPrank(actor);
    // IERC20(makeAsset('WETH')).approve(config.maxapy, 1 ether);
    // IMaxApyVault(config.maxapy).deposit(1 ether, actor);
    // uint256 value = IMaxApyVault(config.maxapy).shareValue(10000);

    // vm.stopPrank();

    // console.log('VALUE', value);
  }
}
