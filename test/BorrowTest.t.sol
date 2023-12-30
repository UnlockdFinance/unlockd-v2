// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {ProtocolOwner} from '@unlockd-wallet/src/libs/owners/ProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';
import {Manager} from '../src/protocol/modules/Manager.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

import {console} from 'forge-std/console.sol';

contract BorrowTest is Setup {
  address internal _actor;
  address internal _manager;
  address internal _nft;
  address internal _action;
  uint256 internal deadlineIncrement;

  function setUp() public virtual override {
    super.setUp();
    _actor = makeAddr('filipe');
    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    // Create wallet
    createWalletAndMintTokens(_actor, 'PUNK');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
    _nft = _nfts.get('PUNK');
  }

  /////////////////////////////////////////////////////////////////////////////////
  // BORROW
  /////////////////////////////////////////////////////////////////////////////////

  function test_borrow_one_asset() public {
    uint256 amountToBorrow = 0.5 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,
      DataTypes.Asset[] memory assets
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({user: _actor, loanId: 0, price: 2 ether, totalAssets: 1, totalArray: 1})
      );
    uint256 initialGas = gasleft();

    // Borrow amount
    hoax(_actor);
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    // We check the new balance
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Check if the asset is locked
    address protocolOwner = getProtocolOwnerAddress(_actor);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(protocolOwner).isAssetLocked(assetsIds[i]), true);
      unchecked {
        ++i;
      }
    }
  }

  function test_borrow_with_multiples_nfts() public {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,
      DataTypes.Asset[] memory assets
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({
          user: _actor,
          loanId: 0,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();
    // Borrow amount
    hoax(_actor);
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    // We check the new balance
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Check if the asset is locked
    address protocolOwner = getProtocolOwnerAddress(_actor);

    for (uint256 i = 0; i < assetsIds.length; ) {
      assertEq(ProtocolOwner(protocolOwner).isAssetLocked(assetsIds[i]), true);
      unchecked {
        ++i;
      }
    }
  }

  function test_borrow_two_times() public {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,
      DataTypes.Asset[] memory assets
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({
          user: _actor,
          loanId: 0,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();
    vm.recordLogs();
    // Borrow amount
    hoax(_actor);
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    (
      DataTypes.SignAction memory signActionTwo,
      DataTypes.EIP712Signature memory sigTwo,
      ,
      DataTypes.Asset[] memory assetsTwo
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({
          user: _actor,
          loanId: loanId,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 0
        })
      );

    // We check the new balance
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);

    // Borrow amount
    hoax(_actor);
    Action(_action).borrow(amountToBorrow, assetsTwo, signActionTwo, sigTwo);

    // We check the new balance
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow * 2);
  }

  function test_borrow_two_times_same_message() public {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);

    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,
      DataTypes.Asset[] memory assets
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({
          user: _actor,
          loanId: 0,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();

    // Borrow amount
    hoax(_actor);
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    vm.startPrank(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    // Borrow amount
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    vm.stopPrank();
  }

  function test_borrow_with_one_nft_different_coin() public {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    vm.recordLogs();
    {
      // BORROW first time
      (
        DataTypes.SignAction memory signAction,
        DataTypes.EIP712Signature memory sig,
        bytes32[] memory assetsIds,
        DataTypes.Asset[] memory assets
      ) = action_signature(
          _action,
          _nft,
          makeAsset('WETH'),
          ActionSignParams({
            user: _actor,
            loanId: 0,
            price: 10 ether,
            totalAssets: 1,
            totalArray: 1
          })
        );
      // Borrow amount
      hoax(_actor);
      Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    }
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    {
      assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
      // We check the new balance

      (
        DataTypes.SignAction memory signAction,
        DataTypes.EIP712Signature memory sig,
        bytes32[] memory assetsIds,
        DataTypes.Asset[] memory assets
      ) = action_signature(
          _action,
          _nft,
          makeAsset('DAI'),
          ActionSignParams({
            user: _actor,
            loanId: loanId,
            price: 10 ether,
            totalAssets: 1,
            totalArray: 1
          })
        );

      vm.expectRevert(abi.encodeWithSelector(Errors.InvalidUnderlyingAsset.selector));
      hoax(_actor);
      Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    }
  }

  function test_borrow_with_zero_loanId() public {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    vm.recordLogs();
    {
      // BORROW first time
      (
        DataTypes.SignAction memory signAction,
        DataTypes.EIP712Signature memory sig,
        bytes32[] memory assetsIds,
        DataTypes.Asset[] memory assets
      ) = action_signature(
          _action,
          _nft,
          makeAsset('WETH'),
          ActionSignParams({
            user: _actor,
            loanId: 0,
            price: 10 ether,
            totalAssets: 1,
            totalArray: 1
          })
        );
      // Borrow amount
      hoax(_actor);
      Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    }
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    {
      assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
      // We check the new balance

      (
        DataTypes.SignAction memory signAction,
        DataTypes.EIP712Signature memory sig,
        bytes32[] memory assetsIds,
        DataTypes.Asset[] memory assets
      ) = action_signature(
          _action,
          _nft,
          makeAsset('WETH'),
          ActionSignParams({
            user: _actor,
            loanId: loanId,
            price: 10 ether,
            totalAssets: 1,
            totalArray: 1
          })
        );

      vm.expectRevert(abi.encodeWithSelector(Errors.AssetLocked.selector));
      hoax(_actor);
      Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    }
  }

  //   function test_borrow_with_wrong_loanId() public useActor(ACTOR) {
  //     uint256 amountToBorrow = 1 ether;
  //     // User doesn't have WETH
  //     assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
  //     // Get data signed
  //     (
  //       DataTypes.SignAction memory signAction,
  //       DataTypes.EIP712Signature memory sig,
  //       bytes32[] memory assetsIds,
  //       DataTypes.Asset[] memory assets
  //     ) = action_signature(
  //         _action,
  //         _nft,
  //         ActionSignParams({
  //           user: super.getActorAddress(ACTOR),
  //           loanId: bytes32('2'),
  //           price: 10 ether,
  //           totalAssets: 10,
  //           totalArray: 10
  //         })
  //       );
  //     uint256 initialGas = gasleft();

  //     // Borrow amount
  //     vm.expectRevert(abi.encodeWithSelector(Errors.InvalidLoanOwner.selector));
  //     Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
  //     uint256 gasUsed = initialGas - gasleft();
  //     console.log('GAS Used:', gasUsed);
  //   }

  function test_borrow_add_more_assets_to_loan() public {
    uint256 amountToBorrow = 1 ether;
    uint256 amountToBorrowMore = 0.5 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    vm.recordLogs();
    {
      // BORROW first time
      (
        DataTypes.SignAction memory signAction,
        DataTypes.EIP712Signature memory sig,
        bytes32[] memory assetsIds,
        DataTypes.Asset[] memory assets
      ) = action_signature(
          _action,
          _nft,
          makeAsset('WETH'),
          ActionSignParams({
            user: _actor,
            loanId: 0,
            price: 10 ether,
            totalAssets: 1,
            totalArray: 1
          })
        );
      // Borrow amount
      hoax(_actor);
      Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    }
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    // BORROW MORE
    {
      assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
      // We check the new balance

      (
        DataTypes.SignAction memory signAction,
        DataTypes.EIP712Signature memory sig,
        bytes32[] memory assetsIds,
        DataTypes.Asset[] memory assets
      ) = action_signature(
          _action,
          _nft,
          makeAsset('WETH'),
          ActionSignParams({
            user: _actor,
            loanId: loanId,
            price: 10 ether,
            totalAssets: 1,
            totalArray: 0
          })
        );

      hoax(_actor);
      Action(_action).borrow(amountToBorrowMore, assets, signAction, sig);
    }

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow + amountToBorrowMore);
  }

  function test_borrow_error_invalid_assets_array_lenght() public {
    uint256 amountToBorrow = 0.5 ether;
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    // Get data signed

    DataTypes.Asset[] memory assets;

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,

    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({user: _actor, loanId: 0, price: 10 ether, totalAssets: 1, totalArray: 1})
      );
    // Borrow amount
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAssetAmount.selector));
    hoax(_actor);
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
  }

  //   function test_borrow_error_invalid_assets_array_lenght_in_loan() public useActor(ACTOR) {
  //     uint256 amountToBorrow = 0.5 ether;
  //     // User doesn't have WETH
  //     assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
  //     // Get data signed

  //     (
  //       DataTypes.SignAction memory signAction,
  //       DataTypes.EIP712Signature memory sig,
  //       bytes32[] memory assetsIds,
  //       DataTypes.Asset[] memory assets
  //     ) = action_signature(
  //         _action,
  //         _nft,
  //         ActionSignParams({
  //           user: super.getActorAddress(ACTOR),
  //           loanId: 0,
  //           price: 2 ether,
  //           totalAssets: 2,
  //           totalArray: 1
  //         })
  //       );
  //     uint256 initialGas = gasleft();
  //     DataTypes.Asset[] memory newAssets = new DataTypes.Asset[](1);
  //     newAssets[0] = assets[0];
  //     console.log('LIST ASSETS', assets.length);
  //     // Borrow amount
  //     vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArrayLength.selector));
  //     Action(_action).borrow(amountToBorrow, newAssets, signAction, sig);
  //     uint256 gasUsed = initialGas - gasleft();
  //     console.log('GAS Used:', gasUsed);
  //   }

  //   function test_borrow_token_assets_mismatch() public useActor(ACTOR) {
  //     uint256 amountToBorrow = 1 ether;
  //     // User doesn't have WETH

  //     // FIRST BORROW
  //     assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
  //     // Get data signed
  //     (
  //       DataTypes.SignAction memory signAction,
  //       DataTypes.EIP712Signature memory sig,
  //       ,
  //       DataTypes.Asset[] memory assets
  //     ) = action_signature(
  //         _action,
  //         _nft,
  //         ActionSignParams({
  //           user: super.getActorAddress(ACTOR),
  //           loanId: 0,
  //           price: 10 ether,
  //           totalAssets: 10,
  //           totalArray: 10
  //         })
  //       );
  //     uint256 initialGas = gasleft();
  //     vm.recordLogs();
  //     // Borrow amount
  //     Action(_action).borrow(amountToBorrow, assets, signAction, sig);
  //     uint256 gasUsed = initialGas - gasleft();
  //     console.log('GAS Used:', gasUsed);

  //     Vm.Log[] memory entries = vm.getRecordedLogs();

  //     // SECOND BORROW
  //     bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

  //     (
  //       DataTypes.SignAction memory signActionTwo,
  //       DataTypes.EIP712Signature memory sigTwo,
  //       ,
  //       DataTypes.Asset[] memory assetsTwo
  //     ) = action_signature(
  //         _action,
  //         _nft,
  //         ActionSignParams({
  //           user: super.getActorAddress(ACTOR),
  //           loanId: loanId,
  //           price: 10 ether,
  //           totalAssets: 11,
  //           totalArray: 0
  //         })
  //       );

  //     // We check the new balance
  //     assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
  //     vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
  //     // Borrow amount
  //     Action(_action).borrow(
  //       address(_uTokens['WETH']),
  //       amountToBorrow,
  //       assetsTwo,
  //       signActionTwo,
  //       sigTwo
  //     );
  //   }

  function test_borrow_token_frezze() public {
    vm.startPrank(_actor);
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH

    // FIRST BORROW
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,
      DataTypes.Asset[] memory assets
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({
          user: _actor,
          loanId: 0,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();
    vm.recordLogs();
    // Borrow amount
    Action(_action).borrow(amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    // SECOND BORROW
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    vm.stopPrank();
    ///////////////////////
    vm.startPrank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);
    vm.stopPrank();

    ///////////////////////
    vm.startPrank(_actor);
    (
      DataTypes.SignAction memory signActionTwo,
      DataTypes.EIP712Signature memory sigTwo,
      ,
      DataTypes.Asset[] memory assetsTwo
    ) = action_signature(
        _action,
        _nft,
        makeAsset('WETH'),
        ActionSignParams({
          user: _actor,
          loanId: loanId,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 0
        })
      );

    // We check the new balance
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);

    vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotActive.selector));
    Action(_action).borrow(amountToBorrow, assetsTwo, signActionTwo, sigTwo);
    vm.stopPrank();
  }

  ///////////////////////////////////////////////////////////////////
  // TODO: Pending tests
  ///////////////////////////////////////////////////////////////////

  function test_borrow_adding_new_asset_in_params() internal {}

  function test_borrow_with_diferent_asset_params() internal {}

  function test_borrow_wrong_reserve_type() internal {}

  ///////////////////////////////////////////////////////////////////
}
