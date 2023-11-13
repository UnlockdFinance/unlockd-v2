// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';

import '../../test-utils/base/Base.sol';

contract GenericLogicTest is Base {
  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
  }

  function test_genericLogic_calculateFutureLoanData_healty_loan() internal {}

  function test_genericLogic_calculateFutureLoanData_unhealty_loan() internal {}

  function test_genericLogic_calculateLoanDebt_zero_debt() internal {}

  function test_genericLogic_calculateLoanDebt_big_amount_debt() internal {}

  function test_genericLogic_calculateHealthFactorFromBalances_healty() internal {}

  function test_genericLogic_calculateHealthFactorFromBalances_zero_collateral() internal {}

  function test_genericLogic_calculateHealthFactorFromBalances_zero_debt() internal {}

  function test_genericLogic_calculateHealthFactorFromBalances_liquidation() internal {}

  function test_genericLogic_calculateAvailableBorrows_zero_available() internal {}

  function test_genericLogic_calculateAvailableBorrows_no_debt_available() internal {}

  function test_genericLogic_calculateAmountToArriveToLTV_zero_available() internal {}

  function test_genericLogic_calculateAmountToArriveToLTV_bigDebt_available() internal {}

  function test_genericLogic_getUserDebtInBaseCurrency_in_eth() internal {}

  function test_genericLogic_getUserDebtInBaseCurrency_in_usdc() internal {}

  function test_genericLogic_getMainWallet_no_main_wallet() internal {}

  function test_genericLogic_getMainWallet_two_wallets() internal {}

  function test_genericLogic_getMainWallet_bad_configured() internal {}
}
