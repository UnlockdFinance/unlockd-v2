// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {WETHGateway} from '../../src/protocol/gateway/WETHGateway.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';

contract WETHGatewayTest is Setup {
  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;
  address internal _actorNoWallet;
  address internal _WETH;
  WETHGateway internal gateway;

  function setUp() public virtual override {
    super.setUp();

    _actor = makeAddr('filipe');
    _actorTwo = makeAddr('kiki');
    _actorThree = makeAddr('dani');
    _actorNoWallet = makeAddr('noWallet');

    _WETH = makeAsset('WETH');
    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    vm.startPrank(_admin);
    gateway = new WETHGateway(_WETH, address(_uTokenVault));
    _aclManager.setProtocol(makeAddr('protocol'));
    vm.stopPrank();
  }

  function test_depositETH() public {
    hoax(_actor);
    vm.expectRevert('SafeERC20: low-level call failed');
    gateway.depositETH{value: 1 ether}(_actor);

    hoax(_admin);
    gateway.authorizeProtocol(address(_uTokenVault));

    hoax(_actor);
    gateway.depositETH{value: 1 ether}(_actor);
  }

  function test_withdrawETH() public {
    address scaled = _uTokenVault.getScaledToken(_WETH);
    hoax(_admin);
    gateway.authorizeProtocol(address(_uTokenVault));

    hoax(_actor);
    gateway.depositETH{value: 1 ether}(_actor);

    hoax(_actor);
    IERC20(scaled).approve(address(gateway), 2 ether);

    hoax(_actor);
    gateway.withdrawETH(1 ether, _actorTwo);

    assertEq(_actorTwo.balance, 1 ether);
  }

  function test_emergencyTokenTransfer() public {
    address scaled = _uTokenVault.getScaledToken(_WETH);
    hoax(_admin);
    gateway.authorizeProtocol(address(_uTokenVault));

    hoax(_actor);
    gateway.depositETH{value: 1 ether}(_actor);

    hoax(_actor);
    IERC20(scaled).transfer(address(gateway), 1 ether);

    hoax(_admin);
    gateway.emergencyTokenTransfer(scaled, _actorTwo, 1 ether);

    assertEq(IERC20(scaled).balanceOf(_actorTwo), 1 ether);
  }

  function test_emergencyEtherTransfer() public {
    // hoax(_actor);
    // (bool success, ) = payable(address(gateway)).call{value: 1 ether}('');
    // require(success, 'fail transfer');
    // hoax(_admin);
    // gateway.emergencyEtherTransfer(_actorTwo, 1 ether);
    // assertEq(_actorTwo.balance, 1 ether);
  }
}
