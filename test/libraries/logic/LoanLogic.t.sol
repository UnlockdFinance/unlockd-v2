// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../test-utils/base/Base.sol';

contract LoanLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_loanLogic_generateId() internal {}

  function test_loanLogic_createLoan_already_exist() internal {}

  function test_loanLogic_createLoan_new() internal {}

  function test_loanLogic_freeze() internal {}

  function test_loanLogic_activate() internal {}

  function test_loanLogic_getLoanStructHash() internal {}
}
