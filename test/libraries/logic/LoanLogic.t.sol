// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';
import {LoanLogic} from '../../../src/libraries/logic/LoanLogic.sol';

contract LoanLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_loanLogic_generateId() public {
    assertEq(
      LoanLogic.generateId(makeAddr('filipe'), 10, block.number),
      0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a
    );
    assertEq(
      LoanLogic.generateId(makeAddr('filipe'), 11, block.number + 1),
      0xae9aa480e411041889dafbf2076785b412463e446d5ef68e14edf75675ec2768
    );
    assertEq(
      LoanLogic.generateId(makeAddr('filipe'), 10, block.number + 1),
      0x78281d7739aef9efc7788d9d1ff513c564e3c6fbfde70e376a38ae25680d5425
    );
    assertEq(
      LoanLogic.generateId(makeAddr('filipe'), 11, block.number),
      0x94f6efc32f9ce371fb45c1da8233f05b6b4b386e9f9525c42e9562403a471e2a
    );
  }

  function test_loanLogic_createLoan_already_exist() internal {}

  function test_loanLogic_createLoan_new() internal {}

  function test_loanLogic_freeze() internal {}

  function test_loanLogic_activate() internal {}

  function test_loanLogic_getLoanStructHash() internal {}
}
