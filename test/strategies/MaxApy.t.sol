// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';

contract MaxApyTest is Setup {
  uint256 internal ACTOR = 1;

  function setUp() public virtual override {
    super.setUp();
  }

  function test_maxapy_createStrategy() internal {}

  function test_maxapy_asset() internal {}

  function test_maxapy_getConfig() internal {}

  function test_maxapy_balanceOf() internal {}

  function test_maxapy_calculateAmountToSupply() internal {}

  function test_maxapy_supply() internal {}

  function test_maxapy_calculateAmountToWithdraw() internal {}

  function test_maxapy_withdraw() internal {}

  function test_maxapy_updateDeepConfig() internal {}

  function test_maxapy_updateStrategyConfig() internal {}
}
