// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';
import {LoanLogic} from '../../../src/libraries/logic/LoanLogic.sol';

contract TestLib {
  function getHash(DataTypes.SignLoanConfig calldata loanConfig) public pure returns (bytes32) {
    return LoanLogic.getLoanStructHash(1, loanConfig);
  }
}

contract LoanLogicTest is Base {
  DataTypes.Loan private loan;

  TestLib test;

  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
    test = new TestLib();
  }

  function test_loanLogic_generateId() external {
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

  function test_loanLogic_createLoan_new() public {
    LoanLogic.createLoan(
      loan,
      LoanLogic.ParamsCreateLoan({
        loanId: LoanLogic.generateId(makeAddr('filipe'), 11, block.number),
        uToken: makeAddr('utoken'),
        msgSender: makeAddr('filipe'),
        underlyingAsset: makeAddr('asset'),
        totalAssets: 10
      })
    );

    assertEq(loan.loanId, LoanLogic.generateId(makeAddr('filipe'), 11, block.number));
    assertEq(loan.uToken, makeAddr('utoken'));
    assertEq(loan.owner, makeAddr('filipe'));
    assertEq(loan.underlyingAsset, makeAddr('asset'));
    assertEq(loan.totalAssets, 10);
    assertEq(uint(loan.state), uint(DataTypes.LoanState.ACTIVE));
  }

  function test_loanLogic_freeze() public {
    test_loanLogic_createLoan_new();
    LoanLogic.freeze(loan);

    assertEq(uint(loan.state), uint(DataTypes.LoanState.FREEZE));
  }

  function test_loanLogic_activate() public {
    test_loanLogic_createLoan_new();
    LoanLogic.activate(loan);
    assertEq(uint(loan.state), uint(DataTypes.LoanState.ACTIVE));
  }

  function test_loanLogic_getLoanStructHash() public {
    bytes32 hash = test.getHash(
      DataTypes.SignLoanConfig({
        loanId: 0x8a72e222b30f0e57c11ec223b05d97af19a8e9576591b24c4e7ef523be567f39,
        aggLoanPrice: 1 ether,
        aggLtv: 6000,
        aggLiquidationThreshold: 6000,
        totalAssets: 10,
        nonce: 1,
        deadline: block.timestamp + 1000
      })
    );
    assertEq(0x60135c070e87cf6242f7d4f7cb3aa65faa96b439fbef2b98cca8401564599f0a, hash);
  }
}
