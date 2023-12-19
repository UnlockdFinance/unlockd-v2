// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {ProtocolOwner} from '@unlockd-wallet/src/libs/owners/ProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Manager} from '../src/protocol/modules/Manager.sol';

import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';

import {console} from 'forge-std/console.sol';

contract RepayTest is Setup {
  uint256 internal ACTOR = 1;
  uint256 internal ACTOR_TWO = 2;
  uint256 internal ACTOR_THREE = 3;
  address internal _actor;
  address internal _nft;
  address internal _action;
  address internal _manager;
  uint256 internal deadlineIncrement;

  struct GenerateSignParams {
    address user;
    bytes32 loanId;
    uint256 price;
    uint256 totalAssets;
    uint256 totalArray;
  }

  function setUp() public virtual override {
    super.setUp();

    // Fill the protocol with funds
    addFundToUToken(address(_uTokens['WETH']), 'WETH', 10 ether);
    addFundToUToken(address(_uTokens['DAI']), 'DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(ACTOR, 'PUNK');
    createWalletAndMintTokens(ACTOR_TWO, 'PUNK');
    createWalletAndMintTokens(ACTOR_THREE, 'PUNK');
    // Add funds to the user
    getActorWithFunds(ACTOR_TWO, 'WETH', 5 ether);

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);

    _nft = super.getNFT('PUNK');
  }

  /////////////////////////////////////////////////////////////////////////////////
  // Repay
  /////////////////////////////////////////////////////////////////////////////////

  function test_action_repay_full_borrow() public {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amountToBorrow, collateral, 2, 2);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 0,
          totalAssets: 0,
          totalArray: 2
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    uint256 initialGas = gasleft();

    hoax(getActorAddress(ACTOR));
    approveAsset('WETH', address(_uTokens['WETH']), amountToBorrow);
    hoax(getActorAddress(ACTOR));
    Action(_action).repay(amountToBorrow, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), false);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
  }

  function test_action_repay_unlock_one_asset_locked() public {
    uint256 amountToBorrow = 0.30 ether;

    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amountToBorrow, 4 ether, 2, 2);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 2 ether,
          totalAssets: 1,
          totalArray: 1
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    uint256 initialGas = gasleft();
    hoax(getActorAddress(ACTOR));
    Action(_action).repay(0, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), false);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
  }

  function test_action_repay_unlock_multiple_assets() public {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amountToBorrow, collateral, 3, 3);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1,
          totalArray: 2
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    uint256 initialGas = gasleft();
    hoax(getActorAddress(ACTOR));
    Action(_action).repay(0, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), false);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
  }

  function test_action_repay_token_assets_mismatch() public {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amountToBorrow, collateral, 3, 3);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 5,
          totalArray: 1
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    hoax(getActorAddress(ACTOR));
    vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
    Action(_action).repay(0, signAction, sig);
  }

  function test_action_repay_full_borrow_but_not_unlock_all_nfts() public {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amountToBorrow, collateral, 3, 3);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 3,
          totalArray: 0
        })
      );

    (bytes32[] memory assets, ) = generate_assets(_nft, 0, 3);
    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    uint256 initialGas = gasleft();
    hoax(getActorAddress(ACTOR));
    approveAsset('WETH', address(_uTokens['WETH']), amountToBorrow);
    hoax(getActorAddress(ACTOR));
    Action(_action).repay(amountToBorrow, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
  }

  function test_action_repay_full_borrow_locked_loan() public {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    address actor = super.getActorAddress(ACTOR);
    // Configure
    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amountToBorrow, collateral, 2, 2);

    hoax(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);

    assertEq(balanceOfAsset('WETH', actor), amountToBorrow);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 0,
          totalAssets: 0,
          totalArray: 2
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    uint256 initialGas = gasleft();

    vm.startPrank(actor);
    approveAsset('WETH', address(_uTokens['WETH']), amountToBorrow);
    vm.expectRevert(Errors.LoanNotActive.selector);
    Action(_action).repay(amountToBorrow, signAction, sig);

    vm.stopPrank();
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
  }

  function test_action_repay_full_borrow_not_owned() public {
    uint256 amount = 0.5 ether;
    uint256 collateral = 2 ether;
    address actor = super.getActorAddress(ACTOR);
    // Configure

    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amount, collateral, 2, 2);

    assertEq(balanceOfAsset('WETH', actor), amount);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR_TWO),
          loanId: loanId,
          price: 2 ether,
          totalAssets: 2,
          totalArray: 2
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    uint256 initialGas = gasleft();
    vm.startPrank(super.getActorAddress(ACTOR_TWO));
    approveAsset('WETH', address(_uTokens['WETH']), amount);
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualSender.selector));
    Action(_action).repay(amount, signAction, sig);
    vm.stopPrank();
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amount);
  }

  function test_action_repay_owner_not_sender() public {
    uint256 amount = 0.5 ether;
    uint256 collateral = 2 ether;
    address actor = super.getActorAddress(ACTOR);
    // Configure

    bytes32 loanId = borrow_action(_action, _nft, ACTOR, amount, collateral, 2, 2);

    assertEq(balanceOfAsset('WETH', actor), amount);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = action_signature(
        _action,
        _nft,
        ActionSignParams({
          user: super.getActorAddress(ACTOR_TWO),
          loanId: loanId,
          price: 2 ether,
          totalAssets: 2,
          totalArray: 2
        })
      );

    uint256 initialGas = gasleft();
    // HERE We change the address of the ACTOR different from the loan and the signature
    vm.startPrank(super.getActorAddress(ACTOR_THREE));
    approveAsset('WETH', address(_uTokens['WETH']), amount);
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualSender.selector));
    Action(_action).repay(amount, signAction, sig);
    vm.stopPrank();
    uint256 gasUsed = initialGas - gasleft();
    console.log('Repay GAS: ', gasUsed);
  }
}
