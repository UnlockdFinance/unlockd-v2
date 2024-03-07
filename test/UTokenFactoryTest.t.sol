// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

contract UTokenVaultTest is Setup {
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

  function test_basic_deposit() public {
    // DEPOSIT
    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenVault), 2 ether);
    _uTokenVault.deposit(_WETH, 1 ether, _actor);
    vm.stopPrank();

    (bool isActive, bool isFrozen, bool isPaused) = _uTokenVault.getFlags(_WETH);
    assertEq(isActive, true);
    assertEq(isFrozen, false);
    assertEq(isPaused, false);

    Constants.ReserveType rType = _uTokenVault.getReserveType(_WETH);
    assertEq(uint256(Constants.ReserveType.COMMON), uint256(rType));
  }

  function test_basic_withdraw() public {
    assertEq(_uTokenVault.totalSupplyNotInvested(_WETH), 0);
    // DEPOSIT
    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenVault), 1 ether);
    _uTokenVault.deposit(_WETH, 1 ether, _actor);
    vm.stopPrank();

    assertEq(_uTokenVault.totalSupplyNotInvested(_WETH), 1 ether);
    // Get DATA
    DataTypes.ReserveData memory reserve = _uTokenVault.getReserveData(_WETH);

    assertEq(ScaledToken(reserve.scaledTokenAddress).balanceOf(_actor), 1 ether);

    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenVault), 1 ether);
    _uTokenVault.withdraw(_WETH, 1 ether, _actor);
    vm.stopPrank();
    assertEq(ScaledToken(reserve.scaledTokenAddress).balanceOf(_actor), 0);
    assertEq(_uTokenVault.totalSupplyNotInvested(_WETH), 0);
  }

  function test_basic_borrow() public {
    test_basic_deposit();
    bytes32 loanId = 'new_loan';
    vm.startPrank(_actor);
    _uTokenVault.borrow(_WETH, loanId, 0.5 ether, makeAddr('paco'), makeAddr('paco'));
    vm.stopPrank();
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
  }

  function test_basic_repay() public {
    test_basic_borrow();

    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenVault), 0.5 ether);

    assertEq(_uTokenVault.getScaledTotalDebtFromUser(_WETH, makeAddr('paco')), 0.5 ether);
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
    bytes32 loanId = 'new_loan';

    _uTokenVault.repay(_WETH, loanId, 0.5 ether, _actor, makeAddr('paco'));
    vm.stopPrank();
    assertEq(_uTokenVault.getScaledTotalDebtFromUser(_WETH, makeAddr('paco')), 0);
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
  }

  function test_disable_strategy() public {
    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenVault), 10 ether);
    _uTokenVault.deposit(_WETH, 10 ether, _actor);
    assertEq(_uTokenVault.totalSupplyNotInvested(_WETH), 1 ether);
    vm.stopPrank();
    vm.startPrank(_admin);
    _uTokenVault.disableStrategy(_WETH);
    vm.stopPrank();
    assertEq(_uTokenVault.totalSupplyNotInvested(_WETH), 10 ether);
  }

  function test_update_strategy() public {
    vm.startPrank(_actor);
    super.approveAsset(_WETH, address(_uTokenVault), 10 ether);
    _uTokenVault.deposit(_WETH, 10 ether, _actor);
    assertEq(_uTokenVault.totalSupplyNotInvested(_WETH), 1 ether);
    vm.stopPrank();

    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.StrategyNotEmpty.selector));
    _uTokenVault.updateReserveStrategy(_WETH, makeAddr('new_strategy'));
    _uTokenVault.disableStrategy(_WETH);
    _uTokenVault.updateReserveStrategy(_WETH, makeAddr('new_strategy'));
    DataTypes.ReserveData memory data = _uTokenVault.getReserveData(_WETH);
    assertEq(data.strategyAddress, makeAddr('new_strategy'));

    vm.stopPrank();
  }
}
