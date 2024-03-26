// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';

contract ReserveLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_reserveLogic_getNormalizedIncome() internal {}

  function test_reserveLogic_getNormalizedDebt() internal {}

  function test_reserveLogic_updateState() internal {}

  function test_reserveLogic_cumulateToLiquidityIndex() internal {}

  function test_reserveLogic_init() internal {}

  function test_reserveLogic_updateInterestRates() internal {}

  function test_reserveLogic_increaseDebt() internal {}

  function test_reserveLogic_decreaseDebt() internal {}

  function test_reserveLogic_mintScaled() internal {}

  function test_reserveLogic_burnScaled() internal {}

  function test_reserveLogic_strategyInvest() internal {}

  function test_reserveLogic_strategyWithdraw() internal {}

  function test_reserveLogic_strategyWithdrawAll() internal {}
}
