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
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

contract AuctionTest is Setup {
  uint256 internal ACTOR = 1;
  address internal _actor;
  address internal _manager;
  address internal _action;
  address internal _nft;

  function setUp() public virtual override {
    super.setUp();
    // Fill the protocol with funds
    addFundToUToken(address(_uTokens['WETH']), 'WETH', 10 ether);
    addFundToUToken(address(_uTokens['DAI']), 'DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(ACTOR, 'PUNK');
    _nft = super.getNFT('PUNK');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
  }

  //////////////////////////////////////////////////

  function _generate_assets(
    uint256 totalArray
  ) internal view returns (bytes32[] memory, DataTypes.Asset[] memory) {
    // Asesets
    bytes32[] memory assetsIds = new bytes32[](totalArray);
    DataTypes.Asset[] memory assets = new DataTypes.Asset[](totalArray);
    for (uint256 i = 0; i < totalArray; ) {
      uint256 tokenId = i + 1;
      assetsIds[i] = AssetLogic.assetId(_nft, tokenId);
      assets[i] = DataTypes.Asset({collection: _nft, tokenId: tokenId});
      unchecked {
        ++i;
      }
    }
    return (assetsIds, assets);
  }

  struct GenerateSignParams {
    address user;
    bytes32 loanId;
    uint256 price;
    uint256 totalAssets;
    uint256 totalArray;
  }

  function _generate_signature(
    GenerateSignParams memory params
  )
    internal
    view
    returns (
      DataTypes.SignAction memory,
      DataTypes.EIP712Signature memory,
      bytes32[] memory,
      DataTypes.Asset[] memory
    )
  {
    // Get nonce from the user
    uint256 nonce = ActionSign(_action).getNonce(params.user);
    uint40 deadline = uint40(block.timestamp + 1000);
    (bytes32[] memory assetsIds, DataTypes.Asset[] memory assets) = _generate_assets(
      params.totalArray
    );
    // Create the struct
    DataTypes.SignAction memory data = DataTypes.SignAction({
      loan: DataTypes.SignLoanConfig({
        loanId: params.loanId, // Because is new need to be 0
        aggLoanPrice: params.price,
        aggLtv: 6000,
        aggLiquidationThreshold: 6000,
        totalAssets: uint88(params.totalAssets),
        nonce: nonce,
        deadline: deadline
      }),
      assets: assetsIds,
      nonce: nonce,
      deadline: deadline
    });

    bytes32 digest = Action(_action).calculateDigest(nonce, data);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

    // Build signature struct
    DataTypes.EIP712Signature memory sig = DataTypes.EIP712Signature({
      v: v,
      r: r,
      s: s,
      deadline: deadline
    });

    return (data, sig, assetsIds, assets);
  }

  function _generate_borrow(
    uint256 amountToBorrow,
    uint256 price,
    uint256 totalAssets,
    uint256 totalArray
  ) internal returns (bytes32 loanId) {
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,
      DataTypes.Asset[] memory assets
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: 0,
          price: price,
          totalAssets: totalAssets,
          totalArray: totalArray
        })
      );
    vm.recordLogs();
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    return loanId;
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

  function test_addUToken() external {
    vm.assume(Manager(_manager).isUTokenActive(address(0x123)) == 0);
    vm.startPrank(_admin);
    Manager(_manager).addUToken(address(0x123), true);
    assertEq(Manager(_manager).isUTokenActive(address(0x123)), 1);
    vm.stopPrank();
  }

  function test_addUToken_disable() external {
    vm.assume(Manager(_manager).isUTokenActive(address(0x123)) == 0);
    vm.startPrank(_admin);
    // Set to true
    Manager(_manager).addUToken(address(0x123), true);
    assertEq(Manager(_manager).isUTokenActive(address(0x123)), 1);
    // Set to false
    Manager(_manager).addUToken(address(0x123), false);
    assertEq(Manager(_manager).isUTokenActive(address(0x123)), 0);
    vm.stopPrank();
  }

  function test_addUToken_zero() external {
    vm.assume(Manager(_manager).isUTokenActive(address(0x123)) == 0);
    vm.startPrank(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
    Manager(_manager).addUToken(address(0), true);
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
    vm.startPrank(getActorAddress(ACTOR));
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 2, 2);
    vm.stopPrank();
    DataTypes.Loan memory loan = Action(_action).getLoan(loanId);

    assertEq(uint(loan.state), uint(DataTypes.LoanState.ACTIVE));

    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loanUpdated = Action(_action).getLoan(loanId);
    assertEq(uint(loanUpdated.state), uint(DataTypes.LoanState.FREEZE));
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
    vm.startPrank(getActorAddress(ACTOR));
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 2, 2);
    vm.stopPrank();

    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loanUpdated = Action(_action).getLoan(loanId);
    assertEq(uint(loanUpdated.state), uint(DataTypes.LoanState.FREEZE));

    vm.startPrank(_admin);
    Manager(_manager).emergencyActivateLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loan = Action(_action).getLoan(loanId);

    assertEq(uint(loan.state), uint(DataTypes.LoanState.ACTIVE));
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
    vm.startPrank(getActorAddress(ACTOR));
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 2, 2);
    vm.stopPrank();

    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loanUpdated = Action(_action).getLoan(loanId);
    assertEq(uint(loanUpdated.state), uint(DataTypes.LoanState.FREEZE));

    vm.startPrank(_admin);
    Manager(_manager).emergencyBlockLoan(loanId);
    vm.stopPrank();

    DataTypes.Loan memory loan = Action(_action).getLoan(loanId);

    assertEq(uint(loan.state), uint(DataTypes.LoanState.BLOCKED));
  }
}
