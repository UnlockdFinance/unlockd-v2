// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {ProtocolOwner} from '@unlockd-wallet/src/libs/owners/ProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

import {console} from 'forge-std/console.sol';

contract BorrowTest is Setup {
  uint256 internal ACTOR = 1;
  address internal _actor;
  address internal _nft;
  address internal _action;
  uint256 internal deadlineIncrement;

  function setUp() public virtual override {
    super.setUp();

    // Fill the protocol with funds
    addFundToUToken(address(_uTokens['WETH']), 'WETH', 10 ether);
    addFundToUToken(address(_uTokens['DAI']), 'DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(ACTOR, 'PUNK');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _nft = super.getNFT('PUNK');

    console.log('NFT address: ', _nft);
    console.log('SUPPLY: ', MintableERC20(_nft).totalSupply());
  }

  function _generate_assets(
    uint256 startCounter,
    uint256 totalArray
  ) internal returns (bytes32[] memory, DataTypes.Asset[] memory) {
    // Asesets
    uint256 counter = totalArray - startCounter;
    bytes32[] memory assetsIds = new bytes32[](counter);
    DataTypes.Asset[] memory assets = new DataTypes.Asset[](counter);
    for (uint256 i = 0; i < counter; ) {
      uint256 tokenId = startCounter + i;
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

    // Asesets
    (bytes32[] memory assetsIds, DataTypes.Asset[] memory assets) = _generate_assets(
      0,
      params.totalArray
    );

    DataTypes.SignAction memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignAction({
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
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig, assetsIds, assets);
  }

  function test_borrow_one_asset() public useActor(ACTOR) {
    uint256 amountToBorrow = 0.5 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,
      DataTypes.Asset[] memory assets
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: 0,
          price: 2 ether,
          totalAssets: 1,
          totalArray: 1
        })
      );
    uint256 initialGas = gasleft();

    console.log('LIST ASSETS', assets.length);
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    // We check the new balance
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Check if the asset is locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assets.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assetsIds[i]), true);
      unchecked {
        ++i;
      }
    }
  }

  function test_borrow_with_multiples_nfts() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,
      DataTypes.Asset[] memory assets
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: 0,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    // We check the new balance
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    // Check if the asset is locked
    IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

    for (uint256 i = 0; i < assetsIds.length; ) {
      assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assetsIds[i]), true);
      unchecked {
        ++i;
      }
    }
  }

  function test_borrow_two_times() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
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
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();
    vm.recordLogs();
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    (
      DataTypes.SignAction memory signActionTwo,
      DataTypes.EIP712Signature memory sigTwo,
      ,
      DataTypes.Asset[] memory assetsTwo
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 0
        })
      );

    // We check the new balance
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);

    // Borrow amount
    Action(_action).borrow(
      address(_uTokens['WETH']),
      amountToBorrow,
      assetsTwo,
      signActionTwo,
      sigTwo
    );

    // We check the new balance
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow * 2);
  }

  function test_borrow_two_times_same_message() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
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
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();

    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecoveredAddress.selector));
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
  }

  function test_borrow_with_one_nft_different_coin() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
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
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();
    vm.recordLogs();
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    (
      DataTypes.SignAction memory signActionTwo,
      DataTypes.EIP712Signature memory sigTwo,
      ,
      DataTypes.Asset[] memory assetsTwo
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: loanId,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 0
        })
      );

    // We check the new balance
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);

    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidUToken.selector));
    // Borrow amount
    Action(_action).borrow(
      address(_uTokens['DAI']),
      amountToBorrow,
      assetsTwo,
      signActionTwo,
      sigTwo
    );
  }

  function test_borrow_with_zero_loanId() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
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
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();

    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);

    (
      DataTypes.SignAction memory signActionTwo,
      DataTypes.EIP712Signature memory sigTwo,
      ,
      DataTypes.Asset[] memory assetsTwo
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: 0,
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );

    // We check the new balance
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
    vm.expectRevert(Errors.AssetLocked.selector);
    // Borrow amount
    Action(_action).borrow(
      address(_uTokens['WETH']),
      amountToBorrow,
      assetsTwo,
      signActionTwo,
      sigTwo
    );
  }

  function test_borrow_with_wrong_loanId() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,
      DataTypes.Asset[] memory assets
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: bytes32('2'),
          price: 10 ether,
          totalAssets: 10,
          totalArray: 10
        })
      );
    uint256 initialGas = gasleft();

    // Borrow amount
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidLoanOwner.selector));
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
  }

  function test_borrow_add_more_assets_to_loan() public useActor(ACTOR) {
    uint256 amountToBorrow = 1 ether;
    // User doesn't have WETH
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 0);
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      bytes32[] memory assetsIds,
      DataTypes.Asset[] memory assets
    ) = _generate_signature(
        GenerateSignParams({
          user: super.getActorAddress(ACTOR),
          loanId: 0,
          price: 10 ether,
          totalAssets: 5,
          totalArray: 5
        })
      );
    uint256 initialGas = gasleft();
    vm.recordLogs();
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    uint256 gasUsed = initialGas - gasleft();
    console.log('GAS Used:', gasUsed);
    assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[2]);

    {
      // Generate new signature with new assets
      // Get nonce from the user
      uint256 nonce = ActionSign(_action).getNonce(super.getActorAddress(ACTOR));
      uint40 deadline = uint40(block.timestamp + 1000);
      uint256 startAssets = assetsIds.length;
      uint256 endAssets = startAssets + 2;

      // Asesets
      (bytes32[] memory assetsIdsTwo, DataTypes.Asset[] memory assetsTwo) = _generate_assets(
        startAssets,
        endAssets
      );

      // Create the struct
      DataTypes.SignAction memory data = DataTypes.SignAction({
        loan: DataTypes.SignLoanConfig({
          loanId: loanId, // Because is new need to be 0
          aggLoanPrice: 10 ether,
          aggLtv: 60000,
          aggLiquidationThreshold: 60000,
          totalAssets: uint88(endAssets),
          nonce: nonce,
          deadline: deadline
        }),
        assets: assetsIdsTwo,
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = Action(_action).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      DataTypes.EIP712Signature memory sigtwo = DataTypes.EIP712Signature({
        v: v,
        r: r,
        s: s,
        deadline: deadline
      });

      // We check the new balance
      // assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
      // Borrow amount
      Action(_action).borrow(address(_uTokens['WETH']), 0, assetsTwo, data, sigtwo);
      // We don't borrow more
      assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), 1 ether);
    }
  }
}
