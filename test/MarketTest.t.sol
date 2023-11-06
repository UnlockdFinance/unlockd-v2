// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';
import {Manager} from '../src/protocol/modules/Manager.sol';

import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

import {console} from 'forge-std/console.sol';

contract MarketTest is Setup {
  uint256 internal ACTOR = 1;
  uint256 internal ACTORTWO = 2;
  uint256 internal ACTORTHREE = 3;
  uint256 internal ACTOR_NO_WALLET = 4;
  address internal _actor;
  address internal _nft;
  address internal _market;
  address internal _action;
  address internal _manager;
  uint256 internal deadlineIncrement;

  struct GenerateSignParams {
    address user;
    bytes32 loanId;
    uint256 price;
    uint256 totalAssets;
  }

  struct GenerateActionSignParams {
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
    createWalletAndMintTokens(ACTORTWO, 'KITTY');
    createWalletAndMintTokens(ACTORTHREE, 'KITTY');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _market = unlockd.moduleIdToProxy(Constants.MODULEID__MARKET);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
    _nft = super.getNFT('PUNK');

    // console.log('NFT address: ', _nft);
    // console.log('SUPPLY: ', MintableERC20(_nft).totalSupply());
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
      uint256 tokenId = startCounter + i;
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
  ) internal view returns (DataTypes.SignMarket memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = MarketSign(_action).getNonce(params.user);
    uint40 deadline = uint40(block.timestamp + 1000);

    DataTypes.SignMarket memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignMarket({
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
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = MarketSign(_market).calculateDigest(nonce, data);
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
  ) internal returns (bytes32 loanId) {
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

  function _generate_borrow_more(
    bytes32 loanId,
    uint256 index,
    uint256 amountToBorrow,
    uint256 price,
    uint256 totalAssets
  ) internal {
    // Get data signed
    DataTypes.Asset[] memory assets;
    (
      DataTypes.SignAction memory signAction,
      DataTypes.EIP712Signature memory sig,
      ,

    ) = _generate_signature_action(
        GenerateActionSignParams({
          user: super.getActorAddress(index),
          loanId: loanId,
          price: price,
          totalAssets: totalAssets,
          totalArray: 0
        })
      );

    // Borrow amount
    Action(_action).borrow(address(_uTokens['WETH']), amountToBorrow, assets, signAction, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
  }

  //////////////////////////////////////////////
  // CREATE ORDER
  //////////////////////////////////////////////

  function test_create_order_type_auction() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 0, 2 ether, 1, 1);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 0,
          totalAssets: 0
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });

    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_type_auction_minBid_set() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 0, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 1 ether,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });

    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_type_fixed_price() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 0, 2 ether, 2, 2);
    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0.5 ether,
      endAmount: 1 ether,
      startTime: 0,
      endTime: 0,
      debtToSell: 0
    });

    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_FIXED_PRICE,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_without_order_type_fixed_price_auction() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 0, 2 ether, 2, 2);
    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0.5 ether,
      endAmount: 1 ether,
      startTime: uint40(block.timestamp),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });

    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_FIXED_PRICE_AND_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_liquidation_auction() public useActor(ACTOR) {
    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({user: getActorAddress(ACTOR), loanId: 0, price: 0, totalAssets: 0}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_LIQUIDATION_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_invalid_uToken() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 0, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });
    vm.expectRevert(Errors.UTokenNotAllowed.selector);
    Market(_market).create(
      address(0x0001),
      DataTypes.OrderType.TYPE_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_type_auction_with_debt_loan() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 1.2 ether, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0.7 ether,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });

    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  function test_create_order_type_auction_with_debt_loan_with_marging() public useActor(ACTOR) {
    bytes32 loanId = _generate_borrow(ACTOR, 0.5 ether, 3 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTOR),
          loanId: loanId,
          price: 2 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });
    Market(_market).create(
      address(_uTokens['WETH']),
      DataTypes.OrderType.TYPE_AUCTION,
      config,
      signMarket,
      sig
    );
  }

  //////////////////////////////////////////////
  // Update TIMESTAMP
  //////////////////////////////////////////////

  function test_update_timestamp_auction() public {
    vm.recordLogs();
    test_create_order_type_auction();

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    vm.startPrank(_admin);
    Manager(_manager).emergencyUpdateEndTimeAuction(orderId, order.timeframe.endTime + 2000);
    assertEq(Market(_market).getOrder(orderId).timeframe.endTime - block.timestamp, 3000);
    vm.stopPrank();
  }

  //////////////////////////////////////////////
  // BID
  //////////////////////////////////////////////

  function test_bid_type_auction_minBid_zero() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_type_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 0,
          totalAssets: 0
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    uint128 bidAmount = 0.1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    // BID Can't be ZERO
    hoax(actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0, 0, signMarket, sig); // BID ON THE ASSET

    // add small amount to bid
    hoax(actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);

    return (loanId, orderId);
  }

  function test_bid_type_auction_minBid_debt() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_type_auction_with_debt_loan_with_marging();

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    // We borrow more to change the debt
    vm.startPrank(getActorAddress(ACTOR));
    _generate_borrow_more(loanId, ACTOR, 0.5 ether, 3 ether, 2);
    vm.stopPrank();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 10 ether);
    uint128 bidAmount = 0.4 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), 10 ether); // APPROVE AMOUNT

    // add small amount to bid
    hoax(actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0.1 ether, 0, signMarket, sig); // BID ON THE ASSET

    hoax(actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);

    return (loanId, orderId);
  }

  function test_bid_type_auction_minBid_set_min_amount() public {
    vm.recordLogs();
    test_create_order_type_auction_minBid_set();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    uint128 bidAmount = 1.1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0.9 ether, 0, signMarket, sig); // BID ON THE ASSET

    hoax(actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);
  }

  function test_bid_type_auction_minBid_set() public {
    vm.recordLogs();
    test_create_order_type_auction_minBid_set();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    uint128 bidAmount = 1.1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0.9 ether, 0, signMarket, sig); // BID ON THE ASSET

    hoax(actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);
  }

  function test_bid_type_auction_minBid_set_with_debt() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_type_auction_with_debt_loan();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    uint256 minBid = Market(_market).getMinBidPrice(
      orderId,
      address(_uTokens['WETH']),
      2 ether,
      6000
    );

    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), minBid); // APPROVE AMOUNT

    hoax(actorTwo);
    Market(_market).bid(orderId, uint128(minBid), 0.1 ether, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actorTwo);
    assertEq(order.bid.amountToPay, minBid);

    return (loanId, orderId);
  }

  function test_bid_second_bid_action() public {
    vm.recordLogs();
    test_create_order_type_auction_minBid_set();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    address actorThree = getActorWithFunds(ACTORTHREE, 'WETH', 2 ether);
    uint128 bidAmount = 0.9 ether;
    uint128 reBidAmount = bidAmount + 0.2 ether;

    {
      // USER TWO
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({
            user: getActorAddress(ACTORTWO),
            loanId: loanId,
            price: 1 ether,
            totalAssets: 1
          }),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(actorTwo);
      approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      hoax(actorTwo);
      Market(_market).bid(orderId, bidAmount, 0.2 ether, signMarket, sig); // BID ON THE ASSET
    }
    {
      // USER THREE
      (
        DataTypes.SignMarket memory signMarketThree,
        DataTypes.EIP712Signature memory sigThree
      ) = _generate_signature(
          GenerateSignParams({
            user: getActorAddress(ACTORTHREE),
            loanId: loanId,
            price: 1 ether,
            totalAssets: 1
          }),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actorThree);
      approveAsset('WETH', address(getUnlockd()), reBidAmount); // APPROVE AMOUNT

      hoax(actorThree);
      Market(_market).bid(orderId, reBidAmount, 0.2 ether, signMarketThree, sigThree); // BID ON THE ASSET
    }
    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actorThree);
    assertEq(order.bid.amountToPay, reBidAmount);
  }

  function test_bid_type_fixed_price() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_type_fixed_price();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    uint128 bidAmount = 1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).bid(orderId, bidAmount, 0.2 ether, signMarket, sig); // BID ON THE ASSET

    return (loanId, orderId);
  }

  function test_bid_cancel_order_and_bid() public {
    vm.recordLogs();
    test_create_order_type_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = _generate_signature(
        GenerateSignParams({
          user: getActorAddress(ACTORTWO),
          loanId: loanId,
          price: 1 ether,
          totalAssets: 1
        }),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    uint128 bidAmount = 0.1 ether;

    // cancel order
    hoax(getActorAddress(ACTOR));
    Market(_market).cancel(orderId);

    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    // add small amount to bid
    hoax(actorTwo);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
  }

  function test_bid_cancel_order_with_bid_and_bid_again() public {
    vm.recordLogs();
    test_create_order_type_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    address actorThree = getActorWithFunds(ACTORTHREE, 'WETH', 2 ether);
    uint128 bidAmount = 0.1 ether;

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actorTwo);
      approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      // add small amount to bid
      hoax(actorTwo);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
    }

    // cancel order
    hoax(getActorAddress(ACTOR));
    Market(_market).cancel(orderId);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorThree, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actorThree);
      approveAsset('WETH', address(getUnlockd()), bidAmount + 0.5 ether); // APPROVE AMOUNT

      // add small amount to bid
      hoax(actorThree);
      vm.expectRevert(Errors.OrderNotAllowed.selector);
      Market(_market).bid(orderId, bidAmount + 0.5 ether, 0, signMarket, sig); // BID ON THE ASSET
    }
  }

  function test_bid_ended_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      address actorThree = getActorWithFunds(ACTORTHREE, 'WETH', 20 ether);
      vm.startPrank(actorThree);

      // We try to bid on a finalized auction
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorThree, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      uint128 bidAmount = 0.2 ether;

      approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT
      // Check auction ended

      vm.expectRevert(Errors.TimestampExpired.selector);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
      vm.stopPrank();
    }
  }

  function test_bid_type_fixed_price_and_auction() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_without_order_type_fixed_price_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTOR));
    {
      (
        DataTypes.SignMarket memory signMarket,
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

      uint128 bidAmount = 0.6 ether;
      hoax(actorTwo);
      approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      // BID Can't be ZERO
      hoax(actorTwo);
      vm.expectRevert(Errors.AmountToLow.selector);
      Market(_market).bid(orderId, 0, 0, signMarket, sig); // BID ON THE ASSET

      // add small amount to bid
      hoax(actorTwo);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
    }
    return (loanId, orderId);
  }

  function test_bid_and_buynow_type_fixed_price_and_auction() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_without_order_type_fixed_price_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    address actorThree = getActorWithFunds(ACTORTHREE, 'WETH', 2 ether);
    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTOR));
    {
      (
        DataTypes.SignMarket memory signMarket,
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

      uint128 bidAmount = 0.6 ether;
      hoax(actorTwo);
      approveAsset('WETH', address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      // BID Can't be ZERO
      hoax(actorTwo);
      vm.expectRevert(Errors.AmountToLow.selector);
      Market(_market).bid(orderId, 0, 0, signMarket, sig); // BID ON THE ASSET

      // add small amount to bid
      hoax(actorTwo);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
    }

    {
      uint256 buyAmount = 1 ether;
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorThree, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actorThree);
      approveAsset('WETH', address(getUnlockd()), buyAmount); // APPROVE AMOUNT

      // add small amount to bid
      hoax(actorThree);
      Market(_market).buyNow(true, orderId, buyAmount, 0, signMarket, sig); // BID ON THE ASSET
    }

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTORTHREE));
  }

  function test_bid_type_auction_minBid_set_with_debt_two_bids() public returns (bytes32, bytes32) {
    vm.recordLogs();
    test_create_order_type_auction_with_debt_loan();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);

    // Add funds to the actor two
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    address actorThree = getActorWithFunds(ACTORTHREE, 'WETH', 2 ether);

    {
      uint256 minBid = Market(_market).getMinBidPrice(
        orderId,
        address(_uTokens['WETH']),
        1 ether,
        6000
      );
      // USER TWO
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({
            user: getActorAddress(ACTORTWO),
            loanId: loanId,
            price: 1 ether,
            totalAssets: 1
          }),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(actorTwo);
      approveAsset('WETH', address(getUnlockd()), minBid); // APPROVE AMOUNT

      hoax(actorTwo);
      Market(_market).bid(orderId, uint128(minBid), 0, signMarket, sig); // BID ON THE ASSET

      DataTypes.Order memory order = Market(_market).getOrder(orderId);

      assertEq(order.bid.buyer, actorTwo);
      assertEq(order.bid.amountToPay, minBid);
    }
    {
      uint256 minBid = Market(_market).getMinBidPrice(
        orderId,
        address(_uTokens['WETH']),
        1 ether,
        6000
      );
      // USER THREE
      (
        DataTypes.SignMarket memory signMarketThree,
        DataTypes.EIP712Signature memory sigThree
      ) = _generate_signature(
          GenerateSignParams({
            user: getActorAddress(ACTORTHREE),
            loanId: loanId,
            price: 1 ether,
            totalAssets: 1
          }),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actorThree);
      approveAsset('WETH', address(getUnlockd()), minBid); // APPROVE AMOUNT

      hoax(actorThree);
      Market(_market).bid(orderId, uint128(minBid), 0, signMarketThree, sigThree); // BID ON THE ASSET

      DataTypes.Order memory order = Market(_market).getOrder(orderId);

      assertEq(order.bid.buyer, actorThree);
      assertEq(order.bid.amountToPay, minBid);
    }
  }

  //////////////////////////////////////////////
  // BuyNow function
  //////////////////////////////////////////////

  function test_buyNow_type_fixed_price_unlockd_wallet() public {
    vm.recordLogs();
    test_create_order_type_fixed_price();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);

    (
      DataTypes.SignMarket memory signMarket,
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

    uint256 amount = 0.9 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(actorTwo);

    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTORTWO));
  }

  function test_buyNow_type_fixed_price_eoa() public {
    vm.recordLogs();
    test_create_order_type_fixed_price();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);

    (
      DataTypes.SignMarket memory signMarket,
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

    uint256 amount = 1 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(actorTwo);

    Market(_market).buyNow(false, orderId, amount, 0 ether, signMarket, sig); // BID ON THE ASSET

    assertEq(MintableERC721(_nft).ownerOf(1), getActorAddress(ACTORTWO));
  }

  function test_buyNow_type_fixed_price_canceled() public {
    vm.recordLogs();
    test_create_order_type_fixed_price();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);
    // We cancel the current auction
    hoax(getActorAddress(ACTOR));
    Market(_market).cancel(orderId);
    // We try to buyNow
    (
      DataTypes.SignMarket memory signMarket,
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

    uint256 amount = 0.9 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET
  }

  function test_buyNow_type_auction() public {
    vm.recordLogs();
    test_create_order_type_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);

    (
      DataTypes.SignMarket memory signMarket,
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

    uint256 amount = 0.9 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET
  }

  function test_buyNow_type_fixed_price_and_auction() public {
    vm.recordLogs();
    test_create_order_without_order_type_fixed_price_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);

    (
      DataTypes.SignMarket memory signMarket,
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

    uint256 amount = 0.9 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(actorTwo);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTORTWO));
  }

  function test_buyNow_type_fixed_price_and_auction_expired() public {
    vm.recordLogs();
    test_create_order_without_order_type_fixed_price_auction();
    vm.warp(block.timestamp + 2000);
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32 loanId = bytes32(entries[entries.length - 1].topics[3]);
    address actorTwo = getActorWithFunds(ACTORTWO, 'WETH', 2 ether);

    (
      DataTypes.SignMarket memory signMarket,
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

    uint256 amount = 0.9 ether;
    hoax(actorTwo);
    approveAsset('WETH', address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(actorTwo);
    vm.expectRevert(Errors.TimestampExpired.selector);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET
  }

  //////////////////////////////////////////////
  // Claim function
  //////////////////////////////////////////////

  function test_claim_ended_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(actorTwo);
      Market(_market).claim(false, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), actorTwo);
    }
  }

  function test_claim_ended_auction_but_can_not_claim() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_debt();
    // Force finalize the auction
    vm.warp(block.timestamp + 5000);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          // The price is 1 eth and we get the loan unhealty beacause the interest of the time.
          GenerateSignParams({user: actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(actorTwo);
      vm.expectRevert(Errors.UnhealtyLoan.selector);
      Market(_market).claim(false, orderId, signMarket, sig);

      hoax(actorTwo);
      Market(_market).cancelClaim(false, orderId, signMarket, sig);
    }
  }

  function test_claim_ended_auction_with_debt() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_debt();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          // We increase the price of the current balance in order tho get a healty loan.
          GenerateSignParams({user: actorTwo, loanId: loanId, price: 1.5 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(actorTwo);
      vm.expectRevert(Errors.AmountExceedsDebt.selector);
      Market(_market).cancelClaim(false, orderId, signMarket, sig);

      hoax(actorTwo);
      Market(_market).claim(false, orderId, signMarket, sig);
    }
  }

  function test_claim_ended_auction_not_finished() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_set_with_debt();

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
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
      hoax(actorTwo);
      vm.expectRevert(Errors.TimestampNotExpired.selector);
      Market(_market).claim(false, orderId, signMarket, sig);
    }
  }

  function test_claim_ended_auction_with_debt_on_the_bidder() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_set_with_debt();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
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
      hoax(actorTwo);
      vm.expectRevert(Errors.DelegationOwnerZeroAddress.selector);
      Market(_market).claim(false, orderId, signMarket, sig);

      hoax(actorTwo);
      Market(_market).claim(true, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTORTWO));
    }
  }

  function test_claim_ended_auction_claim_in_uWallet() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction

    vm.warp(block.timestamp + 2000);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = _generate_signature(
          GenerateSignParams({user: actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(actorTwo);
      Market(_market).claim(true, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(ACTORTWO));
    }
  }

  function test_claim_ended_fixed_price_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_fixed_price_and_auction();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
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
      hoax(actorTwo);
      Market(_market).claim(false, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), actorTwo);
    }
  }

  function test_claim_fixed_price() public {}

  function test_claim_canceled() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    hoax(getActorAddress(ACTOR));
    Market(_market).cancel(orderId);

    {
      address actorTwo = getActorAddress(ACTORTWO);
      (
        DataTypes.SignMarket memory signMarket,
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
      hoax(actorTwo);
      vm.expectRevert(Errors.OrderNotAllowed.selector);
      Market(_market).claim(false, orderId, signMarket, sig);
    }
  }

  // //////////////////////////////////////////////
  // // Cancel function
  // //////////////////////////////////////////////

  function test_cancel_fixed_price() public {
    (, bytes32 orderId) = test_bid_type_fixed_price();
    hoax(getActorAddress(ACTOR));
    Market(_market).cancel(orderId);
  }

  function test_cancel_expired_auction() public {
    (, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    vm.warp(block.timestamp + 2000);
    // Force finalize the auction
    hoax(getActorAddress(ACTOR));
    vm.expectRevert(Errors.TimestampExpired.selector);
    Market(_market).cancel(orderId);
  }

  function test_cancel_not_owned() public {
    (, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    hoax(getActorAddress(ACTORTWO));
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualOrderOwner.selector));
    Market(_market).cancel(orderId);
  }
}
