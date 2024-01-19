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
  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;

  address internal _manager;
  address internal _nft;
  address internal _action;
  address internal _WETH;
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

    _actor = makeAddr('filipe');
    _actorTwo = makeAddr('kiki');
    _actorThree = makeAddr('dani');
    _WETH = makeAsset('WETH');
    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(_actor, 'PUNK');
    createWalletAndMintTokens(_actorTwo, 'PUNK');
    createWalletAndMintTokens(_actorThree, 'PUNK');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
    _nft = _nfts.get('PUNK');
  }

  /////////////////////////////////////////////////////////////////////////////////
  // Repay
  /////////////////////////////////////////////////////////////////////////////////

  function test_action_repay_full_borrow() public {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 2, 2);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({user: _actor, loanId: loanId, price: 0, totalAssets: 0, totalArray: 2})
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }

    hoax(_actor);
    approveAsset(_WETH, address(_uTokenVault), amountToBorrow);

    hoax(_actor);
    Action(_action).repay(amountToBorrow, signAction, sig);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), false);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
  }

  function test_action_repay_unlock_one_asset_locked() public {
    uint256 amountToBorrow = 0.30 ether;

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, 4 ether, 2, 2);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({
          user: _actor,
          loanId: loanId,
          price: 2 ether,
          totalAssets: 1,
          totalArray: 1
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    hoax(_actor);
    Action(_action).repay(0, signAction, sig);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), false);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
  }

  function test_action_repay_unlock_multiple_assets() public {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 3, 3);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({
          user: _actor,
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1,
          totalArray: 2
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    hoax(_actor);
    Action(_action).repay(0, signAction, sig);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), false);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
  }

  function test_action_repay_token_assets_mismatch() public {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 3, 3);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({
          user: _actor,
          loanId: loanId,
          price: 1 ether,
          totalAssets: 5,
          totalArray: 1
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    hoax(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
    Action(_action).repay(0, signAction, sig);
  }

  function test_action_repay_full_borrow_but_not_unlock_all_nfts() public {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 3, 3);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({
          user: _actor,
          loanId: loanId,
          price: 1 ether,
          totalAssets: 3,
          totalArray: 0
        })
      );

    (bytes32[] memory assets, ) = generate_assets(_nft, 0, 3);
    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }

    hoax(_actor);
    approveAsset(_WETH, address(_uTokenVault), amountToBorrow);

    hoax(_actor);
    Action(_action).repay(amountToBorrow, signAction, sig);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), 0);
  }

  function test_action_repay_full_borrow_locked_loan() public {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;

    // Configure
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToBorrow, collateral, 2, 2);

    hoax(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({user: _actor, loanId: loanId, price: 0, totalAssets: 0, totalArray: 2})
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }

    vm.startPrank(_actor);
    approveAsset(_WETH, address(_uTokenVault), amountToBorrow);

    vm.expectRevert(Errors.LoanNotActive.selector);
    Action(_action).repay(amountToBorrow, signAction, sig);

    vm.stopPrank();

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToBorrow);
  }

  function test_action_repay_full_borrow_not_owned() public {
    uint256 amount = 0.5 ether;
    uint256 collateral = 2 ether;

    // Configure
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amount, collateral, 2, 2);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amount);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({
          user: _actorTwo,
          loanId: loanId,
          price: 2 ether,
          totalAssets: 2,
          totalArray: 2
        })
      );

    // Check that these nfts are locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }

    vm.startPrank(_actorTwo);
    approveAsset(_WETH, address(_uTokenVault), amount);
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualSender.selector));
    Action(_action).repay(amount, signAction, sig);
    vm.stopPrank();

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assets[i]), true);
      unchecked {
        ++i;
      }
    }
    // User doesn't have WETH
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amount);
  }

  function test_action_repay_owner_not_sender() public {
    uint256 amount = 0.5 ether;
    uint256 collateral = 2 ether;

    // Configure
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amount, collateral, 2, 2);

    assertEq(balanceAssets(makeAsset('WETH'), _actor), amount);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = action_signature(
        _action,
        _nft,
        _WETH,
        ActionSignParams({
          user: _actorTwo,
          loanId: loanId,
          price: 2 ether,
          totalAssets: 2,
          totalArray: 2
        })
      );

    // HERE We change the address of the ACTOR different from the loan and the signature
    vm.startPrank(_actorThree);

    approveAsset(_WETH, address(_uTokenVault), amount);
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualSender.selector));
    Action(_action).repay(amount, signAction, sig);

    vm.stopPrank();
  }
}
