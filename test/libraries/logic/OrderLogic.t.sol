// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/setups/Setup.sol';

import {OrderLogic, DataTypes} from '../../../src/libraries/logic/OrderLogic.sol';

// import {UToken} from '../../../src/protocol/UToken.sol';

contract OrderLogicTest is Setup {
  DataTypes.Order private order;

  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;
  address internal _actorNoWallet;

  address internal _nft;

  address internal _auction;
  address internal _action;
  address internal _market;
  address internal _manager;

  address internal _WETH;

  // *************************************
  function setUp() public override {
    super.setUp();

    _actor = makeAddr('filipe');
    _actorTwo = makeAddr('kiki');
    _actorThree = makeAddr('dani');
    _actorNoWallet = makeAddr('noWallet');

    _WETH = makeAsset('WETH');
    // Fill the protocol with funds
    addFundToUToken('WETH', 100 ether);
    addFundToUToken('DAI', 100 ether);

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
        orderType: Constants.OrderType.TYPE_AUCTION,
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        assetId: 0x6661696c65640000000000000000000000000000000000000000000000000000,
        startAmount: 0,
        endAmount: 1 ether,
        debtToSell: 1000,
        startTime: uint40(block.timestamp),
        endTime: uint40(block.timestamp)
      })
    );
    assertEq(uint(order.orderType), uint(Constants.OrderType.TYPE_AUCTION));
    assertEq(order.orderId, 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f);
    assertEq(order.offer.endAmount, 1 ether);
    assertEq(order.offer.debtToSell, 1000);
  }

  function test_orderLogic_updateToLiquidationOrder() public {
    test_orderLogic_createOrder_new();
    assertEq(uint(order.orderType), uint(Constants.OrderType.TYPE_AUCTION));
    OrderLogic.updateToLiquidationOrder(
      order,
      OrderLogic.ParamsUpdateOrder({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        assetId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        endTime: uint40(block.timestamp),
        minBid: uint128(1 ether)
      })
    );

    assertEq(uint(order.orderType), uint(Constants.OrderType.TYPE_LIQUIDATION_AUCTION));
  }

  function test_orderLogic_borrowByBidder() public {
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 0.2 ether,
        assetPrice: 1 ether,
        assetLtv: 6000
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('filipe')), 0.2 ether);
    vm.stopPrank();
  }

  function test_orderLogic_borrowByBidder_big_amount() public {
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 1 ether,
        assetPrice: 10 ether,
        assetLtv: 6000
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 0);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('filipe')), 1 ether);
    vm.stopPrank();
  }

  function test_orderLogic_borrowByBidder_ProtocolAccessDenied() public {
    vm.expectRevert(abi.encodeWithSelector(Errors.ProtocolAccessDenied.selector));
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
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
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
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
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 0.1 ether,
        assetPrice: 1 ether,
        assetLtv: 6000
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 99000000000000000000);
    vm.stopPrank();
  }

  function test_orderLogic_refundBidder() public {
    test_orderLogic_borrowByBidder();
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        underlyingAsset: makeAsset('WETH'),
        reserveOracle: _reserveOracle,
        amountToPay: 0.2 ether,
        amountOfDebt: 1 ether,
        reserve: _uTokenVault.getReserveData(makeAsset('WETH'))
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 98800000000000000000);
    vm.stopPrank();
  }

  function test_orderLogic_refundBidder_no_debt() public {
    test_orderLogic_borrowByBidder();
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: 0,
        owner: makeAddr('filipe'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        underlyingAsset: makeAsset('WETH'),
        reserveOracle: _reserveOracle,
        amountToPay: 1 ether,
        amountOfDebt: 0,
        reserve: _uTokenVault.getReserveData(makeAsset('WETH'))
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 99000000000000000000);
    vm.stopPrank();
  }

  function test_orderLogic_refundBidder_big_debt() public {
    test_orderLogic_borrowByBidder_big_amount();
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.refundBidder(
      OrderLogic.RefundBidderParams({
        loanId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        underlyingAsset: makeAsset('WETH'),
        reserveOracle: _reserveOracle,
        amountToPay: 0.2 ether,
        amountOfDebt: 0,
        reserve: _uTokenVault.getReserveData(makeAsset('WETH'))
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 99800000000000000000);
    vm.stopPrank();
  }

  function test_orderLogic_repayOwnerDebt() public {
    // We create the loan with the bid but it's the same.
    test_orderLogic_borrowByBidder_big_amount();
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    vm.startPrank(makeAddr('protocol'));
    OrderLogic.repayDebt(
      OrderLogic.RepayDebtParams({
        loanId: 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f,
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        owner: makeAddr('filipe'),
        amount: 1 ether
      })
    );
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('protocol')), 99000000000000000000);
    vm.stopPrank();
  }

  function test_orderLogic_repayDebtToSell() public {
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    bytes32 loanId = 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f;
    vm.startPrank(makeAddr('protocol'));
    // Create order
    OrderLogic.createOrder(
      order,
      OrderLogic.ParamsCreateOrder({
        orderId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        orderType: Constants.OrderType.TYPE_AUCTION,
        loanId: loanId,
        assetId: 0x6661696c65640000000000000000000000000000000000000000000000000000,
        startAmount: 0,
        endAmount: 1 ether,
        debtToSell: 1000, // 10%
        startTime: uint40(block.timestamp),
        endTime: uint40(block.timestamp)
      })
    );

    assertEq(order.offer.debtToSell, 1000);
    // Borrow
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: loanId,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 1 ether,
        assetPrice: 10 ether,
        assetLtv: 6000
      })
    );
    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 1 ether);
    // Repay Debt
    uint256 amountLeft = OrderLogic.repayDebtToSell(
      order,
      OrderLogic.RepayDebtToSellParams({
        reserveOracle: _reserveOracle,
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        totalAmount: 2 ether,
        aggLoanPrice: 10 ether,
        aggLtv: 6000
      }),
      _uTokenVault.getReserveData(makeAsset('WETH'))
    );
    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 0.9 ether);
    vm.stopPrank();
  }

  function test_orderLogic_repayDebtToSell_no_collateral() public {
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    bytes32 loanId = 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f;
    vm.startPrank(makeAddr('protocol'));
    // Create order
    OrderLogic.createOrder(
      order,
      OrderLogic.ParamsCreateOrder({
        orderId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        orderType: Constants.OrderType.TYPE_AUCTION,
        loanId: loanId,
        assetId: 0x6661696c65640000000000000000000000000000000000000000000000000000,
        startAmount: 0,
        endAmount: 1 ether,
        debtToSell: 1000, // 10%
        startTime: uint40(block.timestamp),
        endTime: uint40(block.timestamp)
      })
    );

    assertEq(order.offer.debtToSell, 1000);
    // Borrow
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: loanId,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 1 ether,
        assetPrice: 10 ether,
        assetLtv: 6000
      })
    );
    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 1 ether);
    // Repay Debt
    uint256 amountLeft = OrderLogic.repayDebtToSell(
      order,
      OrderLogic.RepayDebtToSellParams({
        reserveOracle: _reserveOracle,
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        totalAmount: 1 ether,
        aggLoanPrice: 0,
        aggLtv: 6000
      }),
      _uTokenVault.getReserveData(makeAsset('WETH'))
    );
    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 0);
    vm.stopPrank();
  }

  function test_orderLogic_repayDebtToSell_all() external {
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    bytes32 loanId = 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f;
    vm.startPrank(makeAddr('protocol'));
    // Create order
    OrderLogic.createOrder(
      order,
      OrderLogic.ParamsCreateOrder({
        orderId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        orderType: Constants.OrderType.TYPE_AUCTION,
        loanId: loanId,
        assetId: 0x6661696c65640000000000000000000000000000000000000000000000000000,
        startAmount: 0,
        endAmount: 1 ether,
        debtToSell: 10000, // Repay 100%
        startTime: uint40(block.timestamp),
        endTime: uint40(block.timestamp)
      })
    );
    assertEq(order.offer.debtToSell, 10000);
    // Borrow
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: loanId,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 1 ether,
        assetPrice: 10 ether,
        assetLtv: 6000
      })
    );
    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 1 ether);
    // Repay Debt
    uint256 amountLeft = OrderLogic.repayDebtToSell(
      order,
      OrderLogic.RepayDebtToSellParams({
        reserveOracle: _reserveOracle,
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        from: makeAddr('protocol'),
        totalAmount: 2 ether,
        aggLoanPrice: 10 ether,
        aggLtv: 6000
      }),
      _uTokenVault.getReserveData(makeAsset('WETH'))
    );

    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 0);

    vm.stopPrank();
  }

  function test_orderLogic_repayDebtToSell_debToSell_bigger_than_amount() external {
    writeTokenBalance(makeAddr('protocol'), makeAsset('WETH'), 100 ether);
    bytes32 loanId = 0xff7a1e776049eff68797fa267f8359fdef4658ccd2794220032729778966754f;
    vm.startPrank(makeAddr('protocol'));
    // Create order
    OrderLogic.createOrder(
      order,
      OrderLogic.ParamsCreateOrder({
        orderId: 0xd162c4fbc1f5c172e955d240e018e6eb6b3dfdd9fb4b66ebb33f749262b40c3a,
        owner: makeAddr('filipe'),
        orderType: Constants.OrderType.TYPE_AUCTION,
        loanId: loanId,
        assetId: 0x6661696c65640000000000000000000000000000000000000000000000000000,
        startAmount: 0,
        endAmount: 1 ether,
        debtToSell: 10000, // Repay 100%
        startTime: uint40(block.timestamp),
        endTime: uint40(block.timestamp)
      })
    );
    assertEq(order.offer.debtToSell, 10000);
    // Borrow
    OrderLogic.borrowByBidder(
      OrderLogic.BorrowByBidderParams({
        loanId: loanId,
        owner: makeAddr('filipe'),
        to: makeAddr('filipe'),
        underlyingAsset: makeAsset('WETH'),
        uTokenVault: address(_uTokenVault),
        amountOfDebt: 3 ether,
        assetPrice: 10 ether,
        assetLtv: 6000
      })
    );
    assertEq(_uTokenVault.getDebtFromLoanId(makeAsset('WETH'), loanId), 3 ether);
    // Repay Debt
    DataTypes.ReserveData memory data = _uTokenVault.getReserveData(makeAsset('WETH'));
    OrderLogic.RepayDebtToSellParams memory orderData = OrderLogic.RepayDebtToSellParams({
      reserveOracle: _reserveOracle,
      underlyingAsset: makeAsset('WETH'),
      uTokenVault: address(_uTokenVault),
      from: makeAddr('protocol'),
      totalAmount: 1 ether,
      aggLoanPrice: 0,
      aggLtv: 6000
    });

    // TODO: This is not working properly
    //  vm.expectRevert(abi.encodeWithSelector(Errors.DebtExceedsAmount.selector));
    // OrderLogic.repayDebtToSell(order, orderData, data);

    vm.stopPrank();
  }
}
