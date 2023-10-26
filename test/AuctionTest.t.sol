// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Auction, AuctionSign, IAuctionModule} from '../src/protocol/modules/Auction.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

contract AuctionTest is Setup {
  uint256 internal ACTOR = 1;
  uint256 internal ACTORTWO = 2;
  uint256 internal ACTORTHREE = 3;
  uint256 internal ACTOR_NO_WALLET = 4;
  address internal _actor;
  address internal _nft;
  address internal _auction;
  address internal _action;
  uint256 internal deadlineIncrement;

  struct GenerateSignParams {
    address user;
    bytes32 loanId;
    uint128 price;
    uint256 totalAssets;
  }

  struct AssetParams {
    bytes32 assetId;
    address collection;
    uint32 tokenId;
    uint128 assetPrice;
    uint256 assetLtv;
  }

  struct GenerateActionSignParams {
    address user;
    bytes32 loanId;
    uint128 price;
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
    createWalletAndMintTokens(ACTORTWO, 'KITTY');
    createWalletAndMintTokens(ACTORTHREE, 'KITTY');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _auction = unlockd.moduleIdToProxy(Constants.MODULEID__AUCTION);
    _nft = super.getNFT('PUNK');

    // console.log('NFT address: ', _nft);
    // console.log('SUPPLY: ', MintableERC20(_nft).totalSupply());

    console.log('ACTOR 01', getActorAddress(ACTOR));
    console.log('ACTOR 02', getActorAddress(ACTORTWO));
  }

  function _generate_assets(
    uint256 startCounter,
    uint256 totalArray
  ) internal view returns (bytes32[] memory, DataTypes.Asset[] memory) {
    // Asesets
    uint256 counter = totalArray - startCounter;
    bytes32[] memory assetsIds = new bytes32[](counter);
    DataTypes.Asset[] memory assets = new DataTypes.Asset[](counter);
    for (uint256 i = 0; i < counter; ) {
      uint32 tokenId = uint32(startCounter + i);
      assetsIds[i] = AssetLogic.assetId(_nft, tokenId);
      assets[i] = DataTypes.Asset({collection: _nft, tokenId: tokenId});
      unchecked {
        ++i;
      }
    }
    return (assetsIds, assets);
  }

  function _generate_signature(
    GenerateSignParams memory params,
    AssetParams memory asset
  ) internal view returns (DataTypes.SignAuction memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = AuctionSign(_action).getNonce(params.user);
    uint40 deadline = uint40(block.timestamp + 1000);

    DataTypes.SignAuction memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignAuction({
        loan: DataTypes.SignLoanConfig({
          loanId: params.loanId, // Because is new need to be 0
          aggLoanPrice: params.price,
          aggLtv: 6000,
          aggLiquidationThreshold: 6000,
          totalAssets: uint88(params.totalAssets),
          nonce: nonce,
          deadline: deadline
        }),
        assetId: asset.assetId,
        collection: asset.collection,
        tokenId: asset.tokenId,
        assetPrice: asset.assetPrice,
        assetLtv: 6000,
        endTime: uint40(block.timestamp + 2000),
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = AuctionSign(_auction).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig);
  }

  function _generate_signature_action(
    GenerateActionSignParams memory params
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

  function _generate_borrow(
    uint256 index,
    uint256 amountToBorrow,
    uint256 price,
    uint256 totalAssets,
    uint256 totalArray
  ) internal useActor(ACTOR) returns (bytes32 loanId) {
    // Get data signed
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,
      DataTypes.Asset[] memory assets
    ) = _generate_signature_action(
        GenerateActionSignParams({
          user: super.getActorAddress(index),
          loanId: 0,
          price: uint128(price),
          totalAssets: totalAssets,
          totalArray: totalArray
        })
      );
    vm.recordLogs();
    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    loanId = bytes32(entries[entries.length - 1].topics[2]);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // BID
  /////////////////////////////////////////////////////////////////////////////////

  function test_auction_bid_zero_liquidation_auction() public {
    bytes32 loanId = _generate_borrow(ACTOR, 1.2 ether, 2 ether, 2, 2);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({user: actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    uint256 bidAmount = 1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTotalAmount.selector));
    Auction(_auction).bid(0, 0, signAuction, sig); // BID ON THE ASSET
  }

  function test_auction_bid_liquidation_auction() public returns (bytes32) {
    bytes32 loanId = _generate_borrow(ACTOR, 1.2 ether, 2 ether, 2, 2);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({user: actorTwo, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    uint128 bidAmount = 1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(actorTwo);
    Auction(_auction).bid(bidAmount, 0.5 ether, signAuction, sig); // BID ON THE ASSET

    return loanId;
  }

  function test_auction_bid_on_expired_liquidation_auction() public {
    bytes32 loanId = _generate_borrow(ACTOR, 1.2 ether, 2 ether, 2, 2);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    address actorThree = getActorWithFunds(ACTORTHREE, 'WETH', 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorTwo, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      // Add funds to the actor two

      hoax(actorTwo);
      approveAsset('WETH', address(getUnlockd()), 1 ether); // APPROVE AMOUNT

      hoax(actorTwo);
      Auction(_auction).bid(1 ether, 0.5 ether, signAuction, sig); // BID ON THE ASSET
    }
    // Finalize the auction

    vm.warp(block.timestamp + 3000);
    // Try to bid with a new user
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorThree, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      // Add funds to the actor two

      hoax(actorThree);
      approveAsset('WETH', address(getUnlockd()), 1.2 ether); // APPROVE AMOUNT

      hoax(actorThree);
      vm.expectRevert(Errors.TimestampExpired.selector);
      Auction(_auction).bid(1.2 ether, 0.5 ether, signAuction, sig); // BID ON THE ASSET
    }
  }

  function test_auction_bid_healty_liquidation_auction() public {
    bytes32 loanId = _generate_borrow(ACTOR, 1.2 ether, 2 ether, 2, 2);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({user: actorTwo, loanId: loanId, price: 3 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    uint256 bidAmount = 1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.HealtyLoan.selector);
    Auction(_auction).bid(0, 0, signAuction, sig); // BID ON THE ASSET
  }

  /////////////////////////////////////////////////////////////////////////////////
  // REDEEM
  /////////////////////////////////////////////////////////////////////////////////

  function test_auction_redeem_active_liquidation_auction() public {
    vm.recordLogs();
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    console.log('events', entries.length);
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    address actor = getActorWithFunds(ACTOR, 'WETH', 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actor, loanId: loanId, price: 0.6 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      // Add funds to the actor two

      hoax(actor);
      approveAsset('WETH', address(getUnlockd()), 877500000000000000); // APPROVE AMOUNT

      hoax(actor);
      Auction(_auction).redeem(orderId, 877500000000000000, signAuction, sig);
    }
  }

  function test_auction_redeem_expired_liquidation_auction() public {
    vm.recordLogs();
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    vm.warp(block.timestamp + 3000);

    address actor = getActorWithFunds(ACTOR, 'WETH', 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      // Add funds to the actor two

      hoax(actor);
      approveAsset('WETH', address(getUnlockd()), 757500000000097574); // APPROVE AMOUNT

      hoax(actor);
      vm.expectRevert(Errors.TimestampExpired.selector);
      Auction(_auction).redeem(orderId, 757500000000097574, signAuction, sig);
    }
  }

  /////////////////////////////////////////////////////////////////////////////////
  // FINALIZE
  /////////////////////////////////////////////////////////////////////////////////

  function test_auction_finalize_liquidation_auction() public {
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    // END AUCTION
    vm.warp(block.timestamp + 3000);

    {
      address actor = getActorWithFunds(ACTOR, 'WETH', 2 ether);
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      // Add funds to the actor two

      hoax(actor);
      Auction(_auction).finalize(orderId, signAuction, sig);
    }
  }

  function test_auction_finalize_not_ended_liquidation_auction() public {
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    {
      address actor = getActorWithFunds(ACTOR, 'WETH', 2 ether);
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      // Add funds to the actor two

      hoax(actor);
      vm.expectRevert(Errors.TimestampNotExpired.selector);
      Auction(_auction).finalize(orderId, signAuction, sig);
    }
  }

  function test_auction_finalize_two_times_liquidation_auction() public {
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    // END AUCTION
    vm.warp(block.timestamp + 3000);
    address actor = getActorWithFunds(ACTOR, 'WETH', 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actor);
      Auction(_auction).finalize(orderId, signAuction, sig);
    }

    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actor);
      vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOrderOwner.selector));
      Auction(_auction).finalize(orderId, signAuction, sig);
    }
  }
}
