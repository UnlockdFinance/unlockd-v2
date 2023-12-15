// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {IMaxApyVault} from '@maxapy/interfaces/IMaxApyVault.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import {DebtToken} from '../src/protocol/DebtToken.sol';
import '../src/protocol/UToken.sol';
import '../src/interfaces/tokens/IUToken.sol';

import {console} from 'forge-std/console.sol';

contract UTokenTest is Setup {
  uint256 internal constant ACTOR = 1;

  address internal _manager;

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4783334);
    Unlockd unlockd = super.getUnlockd();
    vm.startPrank(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));
    vm.stopPrank();
  }

  function test_basic_deposit() public useAssetActor(ACTOR, 100000) {
    UToken uToken = getUToken('WETH');
    super.approveAsset('WETH', address(uToken), 100000);
    uToken.deposit(100000, super.getActorAddress(ACTOR), 0);
    assertEq(uToken.balanceOf(super.getActorAddress(ACTOR)), 100000);
  }

  function test_basic_withdraw() public useAssetActor(ACTOR, 100000) {
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

  function test_deposit_less_minCap() public {
    vm.assume(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])) == 0);
    UToken uToken = getUToken('WETH');
    address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);

    vm.startPrank(actor);
    approveAsset('WETH', address(uToken), 0.5 ether);
    uToken.deposit(0.5 ether, super.getActorAddress(ACTOR), 0);
    vm.stopPrank();

    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])), 0.5 ether);
  }

  function test_deposit_more_minCap() internal {
    vm.assume(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])) == 0);
    UToken uToken = getUToken('WETH');
    address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);

    vm.startPrank(actor);
    approveAsset('WETH', address(uToken), 4 ether);
    uToken.deposit(4 ether, super.getActorAddress(ACTOR), 0);
    vm.stopPrank();

    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(_uTokens['WETH'])), 1 ether);
  }

  function test_borrow_below_minCap() internal {
    test_deposit_more_minCap();
    UToken uToken = getUToken('WETH');
    vm.assume(uToken.totalSupply() == 4 ether);

    vm.startPrank(makeAddr('protocol'));
    uToken.borrowOnBelhalf('1', 0.2 ether, makeAddr('protocol'), makeAddr('protocol'));
    vm.stopPrank();
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 0.2 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(uToken)), 0.8 ether);
  }

  function test_borrow_more_than_minCap() internal {
    test_deposit_more_minCap();
    UToken uToken = getUToken('WETH');
    vm.assume(uToken.totalSupply() == 4 ether);

    vm.startPrank(makeAddr('protocol'));
    uToken.borrowOnBelhalf('1', 2 ether, makeAddr('protocol'), makeAddr('protocol'));
    vm.stopPrank();
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 2 ether);
    // This is the remaining minCap that is need to mantain on the UToken
    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(uToken)), 1 ether);
  }

  function test_borrow_force_rebalancing() internal {
    test_deposit_more_minCap();
    UToken uToken = getUToken('WETH');
    DebtToken debtToken = DebtToken(uToken.getDebtToken());
    vm.assume(uToken.totalSupply() == 4 ether);

    //////////////////////////////////////////////////////////////

    vm.startPrank(makeAddr('protocol'));
    uToken.borrowOnBelhalf('1', 2 ether, makeAddr('protocol'), makeAddr('protocol'));
    vm.stopPrank();
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 2 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(uToken)), 1 ether);
    //////////////////////////////////////////////////////////////

    vm.startPrank(makeAddr('protocol'));
    uToken.borrowOnBelhalf('1', 0.5 ether, makeAddr('protocol'), makeAddr('protocol'));
    vm.stopPrank();
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 2.5 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(uToken)), 1 ether);
    //////////////////////////////////////////////////////////////

    vm.startPrank(makeAddr('protocol'));
    uToken.borrowOnBelhalf('1', 0.5 ether, makeAddr('protocol'), makeAddr('protocol'));
    vm.stopPrank();
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 3 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(uToken)), 1 ether);
  }

  function test_borrow_all() internal {
    test_deposit_more_minCap();
    UToken uToken = getUToken('WETH');
    vm.assume(uToken.totalSupply() == 4 ether);

    vm.startPrank(makeAddr('protocol'));
    uToken.borrowOnBelhalf('1', 4 ether, makeAddr('protocol'), makeAddr('protocol'));
    vm.stopPrank();
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 4 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(address(uToken)), 0);
  }
}
