// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';

import '../../test-utils/base/Base.sol';

contract GenericLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_genericLogic_calculateLoanDebt() internal {}

  function test_genericLogic_calculateHealthFactorFromBalances() internal {}

  function test_genericLogic_calculateAvailableBorrows() internal {}

  function test_genericLogic_calculateAmountToArriveToLTV() internal {}

  function test_genericLogic_getMainWallet() internal {}

  function test_genericLogic_getMainWalletAddress() internal {}

  function test_genericLogic_getMainWalletOwner() internal {}

  function test_genericLogic_getMainWalletProtocolOwner() internal {}
}
