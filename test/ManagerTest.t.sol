// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';
import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Manager} from '../src/protocol/modules/Manager.sol';
import {DataTypes, Constants} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

contract ManagerTest is Setup {
  address internal _actor;
  address internal _manager;
  address internal _action;
  address internal _nft;
  address internal _WETH;

  function setUp() public virtual override {
    super.setUp();

    _actor = makeAddr('filipe');
    _WETH = makeAsset('WETH');
    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(_actor, 'PUNK');
    _nft = _nfts.get('PUNK');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
  }

  ////////////////////////////////////////////////

  function test_setReserveOracle() external {
    vm.assume(Manager(_manager).getReserveOracle() == _reserveOracle);
    vm.startPrank(_admin);
    Manager(_manager).setReserveOracle(address(0x123));
    assertEq(Manager(_manager).getReserveOracle(), address(0x123));
    vm.stopPrank();
  }

  function test_setReserveOracle_error_zero() external {
    vm.assume(Manager(_manager).getReserveOracle() == _reserveOracle);
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).setReserveOracle(address(0));
    vm.stopPrank();
  }

  function test_setSigner() external {
    vm.assume(Manager(_manager).getSigner() == _signer);
    vm.startPrank(_admin);
    Manager(_manager).setSigner(address(0x123));
    assertEq(Manager(_manager).getSigner(), address(0x123));
    vm.stopPrank();
  }

  function test_setSigner_error_zero() external {
    vm.assume(Manager(_manager).getSigner() == _signer);
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).setSigner(address(0));
    vm.stopPrank();
  }

  function test_setWalletRegistry() external {
    vm.assume(Manager(_manager).getWalletRegistry() == _walletRegistry);
    vm.startPrank(_admin);
    Manager(_manager).setWalletRegistry(address(0x123));
    assertEq(Manager(_manager).getWalletRegistry(), address(0x123));
    vm.stopPrank();
  }

  function test_setWalletRegistry_error_zero() external {
    vm.assume(Manager(_manager).getWalletRegistry() == _walletRegistry);
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).setWalletRegistry(address(0));
    vm.stopPrank();
  }

  function test_setAllowedControllers() external {
    vm.assume(Manager(_manager).getAllowedController() == _allowedControllers);
    vm.startPrank(_admin);
    Manager(_manager).setAllowedControllers(address(0x123));
    assertEq(Manager(_manager).getAllowedController(), address(0x123));
    vm.stopPrank();
  }

  function test_setAllowedControllers_error_zero() external {
    vm.assume(Manager(_manager).getAllowedController() == _allowedControllers);
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).setAllowedControllers(address(0));
    vm.stopPrank();
  }

  function test_setUTokenFactory() external {
    vm.startPrank(_admin);
    Manager(_manager).setUTokenFactory(address(0x123));
    assertEq(Manager(_manager).getUTokenFactory(), address(0x123));
    vm.stopPrank();
  }

  function test_setUTokenFactory_zero() external {
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).setUTokenFactory(address(0));
    vm.stopPrank();
  }

  function test_allowCollectiononReserveType() external {
    /**
    enum ReserveType {
        DISABLED, // Disabled collection
        ALL, // All the assets with the exception SPECIAL
        STABLE, // For the stable coins
        COMMON, // Common coins WETH etc ...
        SPECIAL // Only if the collection is also isolated to one asset token
    }
    **/
    vm.startPrank(_admin);

    assertEq(
      uint(Manager(_manager).getCollectiononReserveType(address(0x10001))),
      uint(Constants.ReserveType.DISABLED)
    );

    Manager(_manager).allowCollectiononReserveType(address(0x1), Constants.ReserveType.DISABLED);
    assertEq(
      uint(Manager(_manager).getCollectiononReserveType(address(0x1))),
      uint(Constants.ReserveType.DISABLED)
    );

    Manager(_manager).allowCollectiononReserveType(address(0x2), Constants.ReserveType.ALL);
    assertEq(
      uint(Manager(_manager).getCollectiononReserveType(address(0x2))),
      uint(Constants.ReserveType.ALL)
    );

    Manager(_manager).allowCollectiononReserveType(address(0x3), Constants.ReserveType.STABLE);
    assertEq(
      uint(Manager(_manager).getCollectiononReserveType(address(0x3))),
      uint(Constants.ReserveType.STABLE)
    );

    Manager(_manager).allowCollectiononReserveType(address(0x4), Constants.ReserveType.COMMON);
    assertEq(
      uint(Manager(_manager).getCollectiononReserveType(address(0x4))),
      uint(Constants.ReserveType.COMMON)
    );

    Manager(_manager).allowCollectiononReserveType(address(0x5), Constants.ReserveType.SPECIAL);
    assertEq(
      uint(Manager(_manager).getCollectiononReserveType(address(0x5))),
      uint(Constants.ReserveType.SPECIAL)
    );
    vm.stopPrank();
  }

  function test_addMarketAdapters() external {
    vm.assume(Manager(_manager).isMarketAdapterActive(address(0x123)) == 0);
    vm.startPrank(_admin);
    Manager(_manager).addMarketAdapters(address(0x123), true);
    assertEq(Manager(_manager).isMarketAdapterActive(address(0x123)), 1);
    vm.stopPrank();
  }

  function test_addMarketAdapters_disable() external {
    vm.assume(Manager(_manager).isMarketAdapterActive(address(0x123)) == 0);
    vm.startPrank(_admin);
    // Set to true
    Manager(_manager).addMarketAdapters(address(0x123), true);
    assertEq(Manager(_manager).isMarketAdapterActive(address(0x123)), 1);
    // Set to false
    Manager(_manager).addMarketAdapters(address(0x123), false);
    assertEq(Manager(_manager).isMarketAdapterActive(address(0x123)), 0);
    vm.stopPrank();
  }

  function test_addMarketAdapters_error_zero() external {
    vm.assume(Manager(_manager).isMarketAdapterActive(address(0x123)) == 0);
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).addMarketAdapters(address(0), true);
    vm.stopPrank();
  }

  function test_emergencyFreezeLoan() external {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 2, 2);
    DataTypes.Loan memory loan = Action(_action).getLoan(loanId);
    assertEq(uint(loan.state), uint(Constants.LoanState.ACTIVE));

    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loanUpdated = Action(_action).getLoan(loanId);
    assertEq(uint(loanUpdated.state), uint(Constants.LoanState.FREEZE));
  }

  function test_emergencyFreezeLoan_error() external {
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidLoanId.selector));
    Manager(_manager).emergencyFreezeLoan(0);
    vm.stopPrank();
  }

  function test_emergencyActivateLoan() external {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 2, 2);

    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loanUpdated = Action(_action).getLoan(loanId);
    assertEq(uint(loanUpdated.state), uint(Constants.LoanState.FREEZE));

    vm.startPrank(_admin);
    Manager(_manager).emergencyActivateLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loan = Action(_action).getLoan(loanId);

    assertEq(uint(loan.state), uint(Constants.LoanState.ACTIVE));
  }

  function test_emergencyActivateLoan_error() external {
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidLoanId.selector));
    Manager(_manager).emergencyActivateLoan(0);
    vm.stopPrank();
  }

  function test_emergencyBlockLoan() external {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 2, 2);

    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loanUpdated = Action(_action).getLoan(loanId);
    assertEq(uint(loanUpdated.state), uint(Constants.LoanState.FREEZE));

    vm.startPrank(_admin);
    Manager(_manager).emergencyBlockLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loan = Action(_action).getLoan(loanId);

    assertEq(uint(loan.state), uint(Constants.LoanState.BLOCKED));
  }
}
