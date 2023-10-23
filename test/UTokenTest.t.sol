// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';
import '../src/protocol/UToken.sol';

import '../src/interfaces/tokens/IDebtToken.sol';
import '../src/interfaces/tokens/IUToken.sol';

import '../src/protocol/DebtToken.sol';
import '../src/libraries/proxy/UnlockdUpgradeableProxy.sol';
import './test-utils/mock/asset/MintableERC20.sol';
import './test-utils/mock/yearn/MockYVault.sol';
import '../src/libraries/base/InterestRate.sol';

contract UTokenSetup is Setup {
  uint256 internal constant ACTOR = 1;

  function setUp() public virtual override {
    super.setUp();
  }

  function test_basic_deposit() public useAssetActor(ACTOR, 100000) {
    string memory token = 'WETH';
    UToken uToken = super.getUToken(token);
    super.approveAsset(token, address(uToken), 100000);
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
}
