// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

contract UTokenFactoryTest is Setup {
  address internal _actor;

  address internal _manager;
  address internal _WETH;

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4783334);

    _actor = makeAddr('filipe');
    _WETH = makeAsset('WETH');
    // Add funds
    writeTokenBalance(_actor, makeAsset('WETH'), 100 ether);
    vm.startPrank(_admin);
    _aclManager.setProtocol(_actor);
    vm.stopPrank();
  }

  function test_basic_supply() public {
    // DEPOSIT
    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenFactory), 2 ether);
    _uTokenFactory.supply(_WETH, 1 ether, _actor);
    vm.stopPrank();
    // Get DATA
    // DataTypes.MarketBalance memory balance = _uTokenFactory.getBalances(_WETH);
  }

  function test_basic_withdraw() public {
    assertEq(_uTokenFactory.totalSupplyNotInvested(_WETH), 0);
    // DEPOSIT
    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenFactory), 1 ether);
    _uTokenFactory.supply(_WETH, 1 ether, _actor);
    vm.stopPrank();

    assertEq(_uTokenFactory.totalSupplyNotInvested(_WETH), 1 ether);
    // Get DATA
    DataTypes.ReserveData memory reserve = _uTokenFactory.getReserveData(_WETH);

    assertEq(ScaledToken(reserve.scaledTokenAddress).balanceOf(_actor), 1 ether);

    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenFactory), 1 ether);
    _uTokenFactory.withdraw(_WETH, 1 ether, _actor);
    vm.stopPrank();
    assertEq(ScaledToken(reserve.scaledTokenAddress).balanceOf(_actor), 0);
    assertEq(_uTokenFactory.totalSupplyNotInvested(_WETH), 0);
  }

  function test_basic_borrow() public {
    test_basic_supply();
    bytes32 loanId = 'new_loan';
    vm.startPrank(_actor);
    _uTokenFactory.borrow(_WETH, loanId, 0.5 ether, makeAddr('paco'), makeAddr('paco'));
    vm.stopPrank();
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
  }

  function test_basic_repay() public {
    test_basic_borrow();

    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenFactory), 0.5 ether);

    assertEq(_uTokenFactory.getTotalDebtFromUser(_WETH, makeAddr('paco')), 0.5 ether);
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
    bytes32 loanId = 'new_loan';

    _uTokenFactory.repay(_WETH, loanId, 0.5 ether, _actor, makeAddr('paco'));
    vm.stopPrank();
    assertEq(_uTokenFactory.getTotalDebtFromUser(_WETH, makeAddr('paco')), 0);
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
  }
}
