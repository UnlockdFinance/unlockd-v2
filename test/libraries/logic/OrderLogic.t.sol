// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../test-utils/base/Base.sol';

contract OrderLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_orderLogic_generateId() internal {}

  function test_orderLogic_createOrder_already_exist() internal {}

  function test_orderLogic_createOrder_new() internal {}

  function test_orderLogic_updateToLiquidationOrder() internal {}

  function test_orderLogic_borrowByBidder() internal {}

  function test_orderLogic_borrowByBidder_big_amount() internal {}

  function test_orderLogic_refundBidder_loanId_zero() internal {}

  function test_orderLogic_refundBidder_no_debt_on_loan() internal {}

  function test_orderLogic_refundBidder_big_debt() internal {}

  function test_orderLogic_repayOwnerDebt() internal {}

  function test_orderLogic_getMaxDebtOrDefault() internal {}

  function test_orderLogic_getMinDebtOrDefault() internal {}

  function test_orderLogic_getMinBid_first_bid() internal {}

  function test_orderLogic_getMinBid_second_bid() internal {}

  function test_orderLogic_calculateMinBid() internal {}

  function test_orderLogic_repayDebtToSell() internal {}

  function test_orderLogic_repayDebtToSell_debt_to_sell_zero() internal {}
}
