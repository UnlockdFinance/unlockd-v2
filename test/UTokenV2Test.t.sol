// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {UTokenV2, DataTypes} from '../src/protocol/UTokenV2.sol';
import {InterestRateV2} from '../src/libraries/base/InterestRateV2.sol';
import {ScaledToken} from '../src/tokens/ScaledToken.sol';

import '../src/interfaces/tokens/IUToken.sol';
import {console} from 'forge-std/console.sol';

contract UTokenV2Test is Setup {
  uint256 internal constant ACTOR = 1;

  UTokenV2 internal _uTokenV2;
  InterestRateV2 internal _interestRateV2;
  address internal _manager;
  address internal _WETH;

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4783334);
    _WETH = getAssetAddress('WETH');

    ScaledToken token = new ScaledToken();
    _uTokenV2 = new UTokenV2(address(_aclManager), address(token));
    _interestRateV2 = new InterestRateV2(address(_aclManager), 1 ether, 1 ether, 1 ether, 1 ether);
    vm.startPrank(_admin);
    _aclManager.setUToken(address(_uTokenV2));
    _aclManager.setProtocol(makeAddr('protocol'));
    vm.stopPrank();
    create_new_market();
  }

  function create_new_market() internal {
    _uTokenV2.createMarket(
      DataTypes.CreateMarketParams({
        interestRateAddress: address(_interestRateV2),
        strategyAddress: _maxApyStrategy,
        reserveFactor: 0
      }),
      _WETH,
      Constants.ReserveType.COMMON,
      18,
      string(abi.encodePacked('UToken ', 'WETH')),
      string(abi.encodePacked('U', 'WETH'))
    );
  }

  function test_basic_supply() public {
    address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);
    // DEPOSIT
    vm.startPrank(actor);
    super.approveAsset('WETH', address(_uTokenV2), 2 ether);
    _uTokenV2.supply(_WETH, 1 ether, actor);
    vm.stopPrank();
    // Get DATA
    DataTypes.MarketBalance memory balance = _uTokenV2.getBalances(_WETH);

    // assertEq(_uTokenV2.balanceOf(actor), 100000);

    // WITHDRAW
  }

  function test_basic_withdraw() public {
    address actor = getActorWithFunds(ACTOR, 'WETH', 10 ether);
    assertEq(_uTokenV2.totalSupplyNotInvested(_WETH), 0);
    // DataTypes.MarketBalance memory prevBalance = _uTokenV2.getBalance(_WETH);
    // console.log('BALANCE', prevBalance.totalSupplyAssets);
    // DEPOSIT
    vm.startPrank(actor);
    super.approveAsset('WETH', address(_uTokenV2), 1 ether);
    _uTokenV2.supply(_WETH, 1 ether, actor);
    vm.stopPrank();

    assertEq(_uTokenV2.totalSupplyNotInvested(_WETH), 1 ether);
    // Get DATA
    DataTypes.ReserveDataV2 memory reserve = _uTokenV2.getReserveData(_WETH);

    assertEq(ScaledToken(reserve.scaledTokenAddress).balanceOf(actor), 1 ether);

    vm.startPrank(actor);
    super.approveAsset('WETH', address(_uTokenV2), 1 ether);
    _uTokenV2.withdraw(_WETH, 1 ether, actor);
    vm.stopPrank();
    assertEq(ScaledToken(reserve.scaledTokenAddress).balanceOf(actor), 0);
    // DataTypes.MarketBalance memory balance = _uTokenV2.getBalance(_WETH);
    assertEq(_uTokenV2.totalSupplyNotInvested(_WETH), 0);
    // console.log('BALANCE', balance.totalSupplyAssets);
    // assertEq(uToken.balanceOf(actor), 100000);

    // WITHDRAW
  }

  function test_basic_borrow() public {
    test_basic_supply();
    bytes32 loanId = 'new_loan';
    vm.startPrank(makeAddr('protocol'));
    _uTokenV2.borrow(_WETH, loanId, 0.5 ether, makeAddr('paco'), makeAddr('paco'));
    vm.stopPrank();
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
  }

  function test_basic_repay() public {
    test_basic_borrow();

    vm.startPrank(makeAddr('paco'));
    super.approveAsset('WETH', address(_uTokenV2), 0.5 ether);

    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0.5 ether);
    bytes32 loanId = 'new_loan';

    _uTokenV2.repay(_WETH, loanId, 0.5 ether, makeAddr('paco'), makeAddr('paco'));
    vm.stopPrank();
    assertEq(IERC20(_WETH).balanceOf(makeAddr('paco')), 0 ether);
  }
}
