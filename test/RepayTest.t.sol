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
  address internal _actor;
  address internal _nft;
  address internal _action;
  address internal _manager;
  uint256 internal deadlineIncrement;

  function setUp() public virtual override {
    super.setUp();

    // Fill the protocol with funds
    addFundToUToken(address(_uTokens['WETH']), 'WETH', 10 ether);
    addFundToUToken(address(_uTokens['DAI']), 'DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(ACTOR, 'PUNK');
    createWalletAndMintTokens(ACTOR_TWO, 'PUNK');
    // Add funds to the user
    getActorWithFunds(ACTOR_TWO, 'WETH', 5 ether);

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);

    _nft = super.getNFT('PUNK');
  }

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

  function test_repay_full_borrow() public useActor(ACTOR) {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 2, 2);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: collateral,
          totalAssets: 2,
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

    approveAsset('WETH', address(_uTokens['WETH']), amountToBorrow);
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

  function test_repay_unlock_one_asset() public useActor(ACTOR) {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 3, 3);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets, // We only generate the signature with the asset that we want to unlock

    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
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

  function test_repay_full_borrow_but_not_unlock_all_nfts() public useActor(ACTOR) {
    uint256 amountToBorrow = 0.59 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 3, 3);

    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Price updated
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 2,
          totalArray: 0
        })
      );

    (bytes32[] memory assets, ) = _generate_assets(3);
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
    approveAsset('WETH', address(_uTokens['WETH']), amountToBorrow);
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

  function test_repay_full_borrow_locked_loan() public {
    uint256 amountToBorrow = 0.5 ether;
    uint256 collateral = 2 ether;
    address actor = super.getActorAddress(ACTOR);
    // Configure
    vm.startPrank(actor);
    bytes32 loanId = _generate_borrow(amountToBorrow, collateral, 2, 2);
    vm.stopPrank();

    vm.prank(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);

    assertEq(balanceOfAsset('WETH', actor), amountToBorrow);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: collateral,
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

  function test_repay_full_borrow_not_owned() public {
    uint256 amount = 0.5 ether;
    uint256 collateral = 2 ether;
    address actor = super.getActorAddress(ACTOR);
    // Configure
    vm.startPrank(actor);
    bytes32 loanId = _generate_borrow(amount, collateral, 2, 2);
    vm.stopPrank();

    assertEq(balanceOfAsset('WETH', actor), amount);

    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assets,

    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR_TWO),
          loanId: loanId,
          price: collateral,
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
}
