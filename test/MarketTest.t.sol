// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';
import {Manager} from '../src/protocol/modules/Manager.sol';

import {DataTypes, Constants} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

import {console} from 'forge-std/console.sol';

contract MarketTest is Setup {
  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;
  address internal _actorNoWallet;

  address internal _nft;

  address internal _market;
  address internal _action;

  address internal _manager;
  uint256 internal deadlineIncrement;

  address internal _WETH;

  function setUp() public virtual override {
    super.setUp();

    _actor = makeAddr('filipe');
    _actorTwo = makeAddr('kiki');
    _actorThree = makeAddr('dani');
    _actorNoWallet = makeAddr('noWallet');
    // Fill the protocol with funds
    _WETH = makeAsset('WETH');
    _nft = _nfts.get('PUNK');
    // Fill the protocol with funds
    addFundToUToken('WETH', 30 ether);
    // addFundToUToken('DAI', 30 ether);
    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(_actor, 'PUNK');
    createWalletAndMintTokens(_actorTwo, 'KITTY');
    createWalletAndMintTokens(_actorThree, 'KITTY');

    writeTokenBalance(_actorTwo, _WETH, 20 ether);
    writeTokenBalance(_actorThree, _WETH, 20 ether);

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _market = unlockd.moduleIdToProxy(Constants.MODULEID__MARKET);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
  }

  //////////////////////////////////////////////
  // CREATE ORDER
  //////////////////////////////////////////////

  function test_create_order_type_auction() public returns (bytes32, bytes32) {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0 ether, 1 ether, 1, 1);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 0, totalAssets: 0}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 0,
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

    vm.recordLogs();
    hoax(_actor);
    Market(_market).create(_WETH, Constants.OrderType.TYPE_AUCTION, config, signMarket, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    return (loanId, orderId);
  }

  function test_create_order_two_times_with_the_same_asset() public {
    // TODO: Make test
  }

  function test_create_order_type_auction_minBid_set() public returns (bytes32, bytes32) {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1 ether, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    vm.recordLogs();
    hoax(_actor);
    Market(_market).create(_WETH, Constants.OrderType.TYPE_AUCTION, config, signMarket, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    return (loanId, orderId);
  }

  function test_create_order_type_fixed_price() public returns (bytes32, bytes32) {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.5 ether, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: 0.6 ether,
      endAmount: 1 ether,
      startTime: 0,
      endTime: 0,
      debtToSell: 100
    });
    vm.recordLogs();
    hoax(_actor);
    Market(_market).create(_WETH, Constants.OrderType.TYPE_FIXED_PRICE, config, signMarket, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    return (loanId, orderId);
  }

  function test_create_order_without_order_type_fixed_price_auction()
    public
    returns (bytes32, bytes32)
  {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.5 ether, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 1}),
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

    vm.recordLogs();
    hoax(_actor);
    Market(_market).create(
      _WETH,
      Constants.OrderType.TYPE_FIXED_PRICE_AND_AUCTION,
      config,
      signMarket,
      sig
    );
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    return (loanId, orderId);
  }

  function test_create_order_liquidation_auction() public {
    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: 0, price: 0, totalAssets: 0}),
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
    hoax(_actor);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).create(
      _WETH,
      Constants.OrderType.TYPE_LIQUIDATION_AUCTION,
      config,
      signMarket,
      sig
    );
    vm.stopPrank();
  }

  function test_create_order_invalid_underlying() public {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0 ether, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actor);
    vm.expectRevert(Errors.InvalidUnderlyingAsset.selector);
    Market(_market).create(
      makeAsset('DAI'),
      Constants.OrderType.TYPE_AUCTION,
      config,
      signMarket,
      sig
    );
    vm.stopPrank();
  }

  function test_create_order_type_auction_with_debt_loan() public returns (bytes32, bytes32) {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1 ether, 2 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    vm.recordLogs();
    hoax(_actor);
    Market(_market).create(_WETH, Constants.OrderType.TYPE_AUCTION, config, signMarket, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    return (loanId, orderId);
  }

  function test_create_order_type_auction_with_debt_loan_with_marging()
    public
    returns (bytes32, bytes32)
  {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.5 ether, 3 ether, 2, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 2 ether, totalAssets: 1}),
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
    vm.recordLogs();
    hoax(_actor);
    Market(_market).create(_WETH, Constants.OrderType.TYPE_AUCTION, config, signMarket, sig);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    return (loanId, orderId);
  }

  //   //////////////////////////////////////////////
  //   // Update TIMESTAMP
  //   //////////////////////////////////////////////

  function test_update_timestamp_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction();

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
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    uint128 bidAmount = 0.1 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    // BID Can't be ZERO
    hoax(_actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0, 0, signMarket, sig); // BID ON THE ASSET

    // add small amount to bid
    hoax(_actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, _actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);

    return (loanId, orderId);
  }

  function test_bid_type_auction_minBid_debt() public returns (bytes32, bytes32) {
    (
      bytes32 loanId,
      bytes32 orderId
    ) = test_create_order_type_auction_with_debt_loan_with_marging();

    borrow_more_action(loanId, _action, _nft, _WETH, _actor, 1 ether, 3 ether, 2);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), 10 ether); // APPROVE AMOUNT

    // add small amount to bid
    hoax(_actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0.1 ether, 0, signMarket, sig); // BID ON THE ASSET

    hoax(_actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, _actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);

    return (loanId, orderId);
  }

  function test_bid_type_auction_minBid_set_min_amount() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction_minBid_set();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    uint128 bidAmount = 1.1 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0.9 ether, 0, signMarket, sig); // BID ON THE ASSET

    hoax(_actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, _actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);
  }

  function test_bid_type_auction_minBid_set() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction_minBid_set();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    uint128 bidAmount = 1.1 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.AmountToLow.selector);
    Market(_market).bid(orderId, 0.9 ether, 0, signMarket, sig); // BID ON THE ASSET

    hoax(_actorTwo);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, _actorTwo);
    assertEq(order.bid.amountToPay, bidAmount);
  }

  function test_bid_type_auction_minBid_set_with_debt() public returns (bytes32, bytes32) {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction_with_debt_loan();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    uint256 minBid = Market(_market).getMinBidPrice(orderId, _WETH, 2 ether, 6000);

    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), minBid); // APPROVE AMOUNT

    hoax(_actorTwo);
    Market(_market).bid(orderId, uint128(minBid), 0.1 ether, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, _actorTwo);
    assertEq(order.bid.amountToPay, minBid);

    return (loanId, orderId);
  }

  function test_bid_second_bid_action() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction_minBid_set();

    // Add funds to the actor two

    uint128 bidAmount = 0.9 ether;
    uint128 reBidAmount = bidAmount + 0.2 ether;

    {
      // USER TWO
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      hoax(_actorTwo);
      Market(_market).bid(orderId, bidAmount, 0.2 ether, signMarket, sig); // BID ON THE ASSET
    }
    {
      (
        DataTypes.SignMarket memory signMarketThree,
        DataTypes.EIP712Signature memory sigThree
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorThree, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(_actorThree);
      approveAsset(_WETH, address(getUnlockd()), reBidAmount); // APPROVE AMOUNT

      hoax(_actorThree);
      Market(_market).bid(orderId, reBidAmount, 0.2 ether, signMarketThree, sigThree); // BID ON THE ASSET
    }
    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, _actorThree);
    assertEq(order.bid.amountToPay, reBidAmount);
  }

  function test_bid_type_fixed_price() public returns (bytes32, bytes32) {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_fixed_price();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    uint128 bidAmount = 1 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).bid(orderId, bidAmount, 0.2 ether, signMarket, sig); // BID ON THE ASSET

    return (loanId, orderId);
  }

  function test_bid_cancel_order_and_bid() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    uint128 bidAmount = 0.1 ether;

    // cancel order
    hoax(_actor);
    Market(_market).cancel(orderId);

    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    // add small amount to bid
    hoax(_actorTwo);
    vm.expectRevert(Errors.InvalidLoanId.selector);
    Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
  }

  function test_bid_cancel_order_with_bid_and_bid_again() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction();

    uint128 bidAmount = 0.1 ether;
    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(_actorTwo);
      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      // add small amount to bid
      hoax(_actorTwo);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
    }

    // cancel order
    hoax(_actor);
    Market(_market).cancel(orderId);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorThree, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(_actorThree);
      approveAsset(_WETH, address(getUnlockd()), bidAmount + 0.5 ether); // APPROVE AMOUNT

      // add small amount to bid
      hoax(_actorThree);
      vm.expectRevert(Errors.InvalidLoanId.selector);
      Market(_market).bid(orderId, bidAmount + 0.5 ether, 0, signMarket, sig); // BID ON THE ASSET
    }
  }

  function test_bid_cancel_order_with_no_bids_and_expired() public {
    // TODO: Pending test
  }

  function test_bid_ended_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      vm.startPrank(_actorThree);

      // We try to bid on a finalized auction
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorThree, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      uint128 bidAmount = 0.2 ether;

      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT
      // Check auction ended

      vm.expectRevert(Errors.TimestampExpired.selector);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
      vm.stopPrank();
    }
  }

  function test_bid_type_fixed_price_and_auction() public returns (bytes32, bytes32) {
    (bytes32 loanId, bytes32 orderId) = test_create_order_without_order_type_fixed_price_auction();

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
      hoax(_actorTwo);
      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      // BID Can't be ZERO
      hoax(_actorTwo);
      vm.expectRevert(Errors.AmountToLow.selector);
      Market(_market).bid(orderId, 0, 0, signMarket, sig); // BID ON THE ASSET

      // add small amount to bid
      hoax(_actorTwo);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
    }
    return (loanId, orderId);
  }

  function test_bid_and_buynow_type_fixed_price_and_auction_success()
    public
    returns (bytes32, bytes32)
  {
    (bytes32 loanId, bytes32 orderId) = test_create_order_without_order_type_fixed_price_auction();

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
      hoax(_actorTwo);
      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      // BID Can't be ZERO
      hoax(_actorTwo);
      vm.expectRevert(Errors.AmountToLow.selector);
      Market(_market).bid(orderId, 0, 0, signMarket, sig); // BID ON THE ASSET

      // add small amount to bid
      hoax(_actorTwo);
      Market(_market).bid(orderId, bidAmount, 0, signMarket, sig); // BID ON THE ASSET
    }

    {
      uint256 buyAmount = 1 ether;
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorThree, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(_actorThree);
      approveAsset(_WETH, address(getUnlockd()), buyAmount); // APPROVE AMOUNT

      // add small amount to bid
      hoax(_actorThree);
      Market(_market).buyNow(true, orderId, buyAmount, 0, signMarket, sig); // BID ON THE ASSET
    }

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(_actorThree));
    return (loanId, orderId);
  }

  function test_bid_and_buynow_type_fixed_price_and_auction_loan_not_updated() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_without_order_type_fixed_price_auction();

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(_actor));

    {
      uint256 buyAmount = 1 ether;
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorThree, loanId: loanId, price: 1 ether, totalAssets: 3}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(_actorThree);
      approveAsset(_WETH, address(getUnlockd()), buyAmount); // APPROVE AMOUNT

      // add small amount to bid
      hoax(_actorThree);
      vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
      Market(_market).buyNow(true, orderId, buyAmount, 0, signMarket, sig); // BID ON THE ASSET
    }
  }

  function test_bid_type_auction_minBid_set_with_debt_two_bids() public returns (bytes32, bytes32) {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction_with_debt_loan();

    {
      uint256 minBid = Market(_market).getMinBidPrice(orderId, _WETH, 1 ether, 6000);
      // USER TWO
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      approveAsset(_WETH, address(getUnlockd()), minBid); // APPROVE AMOUNT

      hoax(_actorTwo);
      Market(_market).bid(orderId, uint128(minBid), 0, signMarket, sig); // BID ON THE ASSET

      DataTypes.Order memory order = Market(_market).getOrder(orderId);

      assertEq(order.bid.buyer, _actorTwo);
      assertEq(order.bid.amountToPay, minBid);
    }
    {
      uint256 minBid = Market(_market).getMinBidPrice(orderId, _WETH, 1 ether, 6000);
      // USER THREE
      (
        DataTypes.SignMarket memory signMarketThree,
        DataTypes.EIP712Signature memory sigThree
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorThree, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );

      hoax(_actorThree);
      approveAsset(_WETH, address(getUnlockd()), minBid); // APPROVE AMOUNT

      hoax(_actorThree);
      Market(_market).bid(orderId, uint128(minBid), 0, signMarketThree, sigThree); // BID ON THE ASSET

      DataTypes.Order memory order = Market(_market).getOrder(orderId);

      assertEq(order.bid.buyer, _actorThree);
      assertEq(order.bid.amountToPay, minBid);
    }
  }

  //   //////////////////////////////////////////////
  //   // BuyNow function
  //   //////////////////////////////////////////////

  function test_buyNow_type_fixed_price_unlockd_wallet() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_fixed_price();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(_actorTwo);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(_actorTwo));
  }

  function test_buyNow_type_fixed_price_eoa() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_fixed_price();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(_actorTwo);
    Market(_market).buyNow(false, orderId, amount, 0 ether, signMarket, sig); // BID ON THE ASSET

    assertEq(MintableERC721(_nft).ownerOf(1), _actorTwo);
  }

  function test_buyNow_type_fixed_price_canceled() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_fixed_price();
    // We cancel the current auction
    hoax(_actor);
    Market(_market).cancel(orderId);
    // We try to buyNow
    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.InvalidLoanId.selector);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET
  }

  function test_buyNow_type_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_type_auction();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.OrderNotAllowed.selector);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET
  }

  function test_buyNow_type_fixed_price_and_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_without_order_type_fixed_price_auction();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
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
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(_actorTwo);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET

    assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(_actorTwo));
  }

  function test_buyNow_type_fixed_price_and_auction_expired() public {
    (bytes32 loanId, bytes32 orderId) = test_create_order_without_order_type_fixed_price_auction();

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    uint256 amount = 0.9 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), amount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.TimestampExpired.selector);
    Market(_market).buyNow(true, orderId, amount, 0.1 ether, signMarket, sig); // BID ON THE ASSET
  }

  //   //////////////////////////////////////////////
  //   // Claim function
  //   //////////////////////////////////////////////

  function test_claim_ended_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      Market(_market).claim(false, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), _actorTwo);
    }
  }

  function test_claim_ended_auction_but_can_not_claim() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_debt();
    // Force finalize the auction
    vm.warp(block.timestamp + 5000);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 0.2 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      vm.expectRevert(Errors.UnhealtyLoan.selector);
      Market(_market).claim(false, orderId, signMarket, sig);

      hoax(_actorTwo);
      Market(_market).cancelClaim(orderId, signMarket, sig);
    }
  }

  function test_claim_ended_auction_with_debt() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_debt();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1.5 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      vm.expectRevert(Errors.AmountExceedsDebt.selector);
      Market(_market).cancelClaim(orderId, signMarket, sig);

      hoax(_actorTwo);
      Market(_market).claim(false, orderId, signMarket, sig);
    }
  }

  function test_claim_ended_auction_not_finished() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_set_with_debt();

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
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
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      vm.expectRevert(Errors.ProtocolOwnerZeroAddress.selector);
      Market(_market).claim(false, orderId, signMarket, sig);

      hoax(_actorTwo);
      Market(_market).claim(true, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), getWalletAddress(_actorTwo));
    }
  }

  function test_claim_ended_fixed_price_auction() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_fixed_price_and_auction();
    // Force finalize the auction
    vm.warp(block.timestamp + 2000);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      Market(_market).claim(false, orderId, signMarket, sig);

      assertEq(MintableERC721(_nft).ownerOf(1), _actorTwo);
    }
  }

  function test_claim_canceled() public {
    (bytes32 loanId, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    hoax(_actor);
    Market(_market).cancel(orderId);

    {
      (
        DataTypes.SignMarket memory signMarket,
        DataTypes.EIP712Signature memory sig
      ) = market_signature(
          _market,
          MarketSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
          AssetParams({
            assetId: AssetLogic.assetId(_nft, 1),
            collection: _nft,
            tokenId: 1,
            assetPrice: 1 ether,
            assetLtv: 6000
          })
        );
      hoax(_actorTwo);
      vm.expectRevert(Errors.ZeroAddress.selector);
      Market(_market).claim(false, orderId, signMarket, sig);
    }
  }

  // //////////////////////////////////////////////
  // // Cancel function
  // //////////////////////////////////////////////

  function test_cancel_fixed_price() public {
    (, bytes32 orderId) = test_bid_type_fixed_price();
    hoax(_actor);
    Market(_market).cancel(orderId);
  }

  function test_cancel_expired_auction() public {
    (, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    vm.warp(block.timestamp + 2000);
    // Force finalize the auction
    hoax(_actor);
    vm.expectRevert(Errors.TimestampExpired.selector);
    Market(_market).cancel(orderId);
  }

  function test_cancel_not_owned() public {
    (, bytes32 orderId) = test_bid_type_auction_minBid_zero();
    // Force finalize the auction
    hoax(_actorTwo);
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualOrderOwner.selector));
    Market(_market).cancel(orderId);
  }
}
