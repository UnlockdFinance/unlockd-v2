// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/setups/Setup.sol';

import {OrderLogic} from '../../../src/libraries/logic/OrderLogic.sol';
import {UToken} from '../../../src/protocol/UToken.sol';

contract OrderLogicTest is Setup {
  DataTypes.Order private order;
  address internal uToken;

  // *************************************
  function setUp() public override useFork(MAINNET) {
    deploy_acl_manager();
    uToken = deploy_utoken(makeAsset('WETH'));

    deploy_periphery();
    addFundToUToken(uToken, 'WETH', 100 ether);
    vm.startPrank(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));
    vm.stopPrank();
  }

  function test_orderLogic_generateId() public {
    assertEq(
      OrderLogic.generateId(
        0x6661696c65640000000000000000000000000000000000000000000000000000,
        0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a
      ),
      0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f
    );
  }

  function test_orderLogic_createOrder_new() public {
    OrderLogic.createOrder(
      order,
      OrderLogic.ParamsCreateOrder({
        orderId: 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f,
        owner: makeAddr('filipe'),
        orderType: DataTypes.OrderType.TYPE_AUCTION,
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        assetId: 0x6661696c65640000000000000000000000000000000000000000000000000000,
        startAmount: 0,
        endAmount: 10 ether,
        debtToSell: 10,
        startTime: uint40(block.timestamp),
        endTime: uint40(block.timestamp)
      })
    );
    assertEq(uint(order.orderType), uint(DataTypes.OrderType.TYPE_AUCTION));
  }

  function test_orderLogic_updateToLiquidationOrder() public {
    test_orderLogic_createOrder_new();
    assertEq(uint(order.orderType), uint(DataTypes.OrderType.TYPE_AUCTION));
    OrderLogic.updateToLiquidationOrder(
      order,
      OrderLogic.ParamsUpdateOrder({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        assetId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        endTime: uint40(block.timestamp),
        minBid: uint128(1 ether)
      })
    );

    assertEq(uint(order.orderType), uint(DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION));
  }

  function test_orderLogic_borrowByBidder() public {
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uToken: uToken,
        amountOfDebt: 0.2 ether,
        assetPrice: 1 ether,
        assetLtv: 6000
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_borrowByBidder_big_amount() public {
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uToken: uToken,
        amountOfDebt: 1 ether,
        assetPrice: 10 ether,
        assetLtv: 6000
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_borrowByBidder_ProtocolAccessDenied() public {
    vm.expectRevert(abi.encodeWithSelector(Errors.ProtocolAccessDenied.selector));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uToken: uToken,
        amountOfDebt: 10,
        assetPrice: 1 ether,
        assetLtv: 6000
      })
    );
  }

  function test_orderLogic_borrowByBidder_error_big_amount() public {
    vm.startPrank(makeAddr('protocol'));
    vm.expectRevert(abi.encodeWithSelector(Errors.AmountExceedsDebt.selector));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uToken: uToken,
        amountOfDebt: 0.9 ether,
        assetPrice: 1 ether,
        assetLtv: 6000
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_borrowByBidder_loanId_zero() public {
    vm.startPrank(makeAddr('protocol'));
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidLoanId.selector));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0,
        owner: makeAddr('filipe'),
        uToken: uToken,
        amountOfDebt: 0.1 ether,
        assetPrice: 1 ether,
        assetLtv: 6000
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_refundBidder() public {
    test_orderLogic_borrowByBidder();
    writeTokenBalance(makeAddr('protocol'), UToken(uToken).UNDERLYING_ASSET_ADDRESS(), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uToken: uToken,
        from: makeAddr('protocol'),
        underlyingAsset: UToken(uToken).UNDERLYING_ASSET_ADDRESS(),
        reserveOracle: _reserveOracle,
        amountToPay: 0.2 ether,
        amountOfDebt: 1 ether,
        reserve: UToken(uToken).getReserve()
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_refundBidder_no_debt() public {
    test_orderLogic_borrowByBidder();
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: 0,
        owner: makeAddr('filipe'),
        uToken: uToken,
        from: makeAddr('protocol'),
        underlyingAsset: makeAsset('WETH'),
        reserveOracle: _reserveOracle,
        amountToPay: 1 ether,
        amountOfDebt: 0,
        reserve: UToken(uToken).getReserve()
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_refundBidder_big_debt() public {
    test_orderLogic_borrowByBidder_big_amount();
    writeTokenBalance(makeAddr('protocol'), UToken(uToken).UNDERLYING_ASSET_ADDRESS(), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uToken: uToken,
        from: makeAddr('protocol'),
        underlyingAsset: UToken(uToken).UNDERLYING_ASSET_ADDRESS(),
        reserveOracle: _reserveOracle,
        amountToPay: 0.2 ether,
        amountOfDebt: 0,
        reserve: UToken(uToken).getReserve()
      })
    );
    vm.stopPrank();
  }

  function test_orderLogic_repayOwnerDebt() internal {}

  function test_orderLogic_getMaxDebtOrDefault() internal {}

  function test_orderLogic_getMinDebtOrDefault() internal {}

  function test_orderLogic_getMinBid_first_bid() internal {}

  function test_orderLogic_getMinBid_second_bid() internal {}

  function test_orderLogic_calculateMinBid() internal {}

  function test_orderLogic_repayDebtToSell() internal {}

  function test_orderLogic_repayDebtToSell_debt_to_sell_zero() internal {}
}
