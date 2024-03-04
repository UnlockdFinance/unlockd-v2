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
import {Auction, AuctionSign, IAuctionModule} from '../src/protocol/modules/Auction.sol';
import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';
import {DataTypes, Constants} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';

import {console} from 'forge-std/console.sol';

contract AuctionTest is Setup {
  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;
  address internal _actorNoWallet;

  address internal _nft;

  address internal _auction;
  address internal _action;
  address internal _market;
  address internal _manager;

  address internal _WETH;

  function setUp() public virtual override {
    super.setUp();

    _actor = makeAddr('filipe');
    _actorTwo = makeAddr('kiki');
    _actorThree = makeAddr('dani');
    _actorNoWallet = makeAddr('noWallet');

    _WETH = makeAsset('WETH');
    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(_actor, 'PUNK');
    createWalletAndMintTokens(_actorTwo, 'KITTY');
    createWalletAndMintTokens(_actorThree, 'KITTY');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _auction = unlockd.moduleIdToProxy(Constants.MODULEID__AUCTION);
    _market = unlockd.moduleIdToProxy(Constants.MODULEID__MARKET);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
    _nft = _nfts.get('PUNK');
  }

  function _create_market_auction(bytes32 loanId, uint128 startAmount) internal returns (bytes32) {
    vm.recordLogs();
    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: _actor, loanId: loanId, price: 0, totalAssets: 0}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    IMarketModule.CreateOrderInput memory config = IMarketModule.CreateOrderInput({
      startAmount: startAmount,
      endAmount: 0,
      startTime: uint40(block.timestamp - 1),
      endTime: uint40(block.timestamp + 1000),
      debtToSell: 0
    });

    hoax(_actor);
    Market(_market).create(_WETH, Constants.OrderType.TYPE_AUCTION, config, signMarket, sig);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    return orderId;
  }

  function _bid_market_auction(bytes32 loanId, bytes32 orderId, address actor) internal {
    vm.startPrank(actor);
    // Fund user with am
    writeTokenBalance(actor, _WETH, 2 ether);

    (
      DataTypes.SignMarket memory signMarket,
      DataTypes.EIP712Signature memory sig
    ) = market_signature(
        _market,
        MarketSignParams({user: actor, loanId: loanId, price: 0, totalAssets: 0}),
        AssetParams({
          assetId: AssetLogic.assetId(_nft, 1),
          collection: _nft,
          tokenId: 1,
          assetPrice: 1 ether,
          assetLtv: 6000
        })
      );

    // Because there is only one loan all is 0
    uint256 minBid = Market(_market).getMinBidPrice(orderId, _WETH, 0, 6000);

    approveAsset(_WETH, address(getUnlockd()), minBid);
    // APPROVE AMOUNT

    // add small amount to bid
    Market(_market).bid(orderId, uint128(minBid), 0, signMarket, sig); // BID ON THE ASSET

    DataTypes.Order memory order = Market(_market).getOrder(orderId);

    assertEq(order.bid.buyer, actor);
    assertEq(order.bid.amountToPay, minBid);
    vm.stopPrank();
  }

  /////////////////////////////////////////////////////////////////////////////////
  // BID
  /////////////////////////////////////////////////////////////////////////////////

  function test_auction_bid_zero_liquidation_auction() public {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1.2 ether, 2 ether, 2, 2);
    writeTokenBalance(_actorTwo, _WETH, 2 ether);
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);
    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = auction_signature(
        _auction,
        AuctionSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
      );
    // Add funds to the actor two

    uint256 bidAmount = 1 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTotalAmount.selector));
    Auction(_auction).bid(0, 0, signAuction, sig); // BID ON THE ASSET
  }

  function test_auction_bid_liquidation_auction() public returns (bytes32) {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1.2 ether, 2 ether, 2, 2);
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    writeTokenBalance(_actorTwo, _WETH, 2 ether);
    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = auction_signature(
        _auction,
        AuctionSignParams({user: _actorTwo, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
        AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
      );
    // Add funds to the actor two
    uint256 minBid = Auction(_auction).getMinBidPriceAuction(
      loanId,
      AssetLogic.assetId(_nft, 0),
      1 ether,
      0.8 ether,
      6000
    );

    uint128 bidAmount = 1 ether;
    uint128 bidDebtAmount = 0.5 ether;

    assertTrue(minBid <= bidAmount + bidDebtAmount);

    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(_actorTwo);
    Auction(_auction).bid(bidAmount, bidDebtAmount, signAuction, sig); // BID ON THE ASSET

    return loanId;
  }

  //////////////////////////////////7
  function test_auction_bid_on_expired_liquidation_auction() public returns (bytes32) {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1.2 ether, 2 ether, 2, 2);

    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    writeTokenBalance(_actorTwo, _WETH, 2 ether);
    writeTokenBalance(_actorThree, _WETH, 2 ether);

    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actorTwo, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );
      // Add funds to the actor two

      hoax(_actorTwo);
      approveAsset(_WETH, address(getUnlockd()), 1 ether); // APPROVE AMOUNT

      hoax(_actorTwo);
      Auction(_auction).bid(1 ether, 0.5 ether, signAuction, sig); // BID ON THE ASSET
    }
    // Finalize the auction

    vm.warp(block.timestamp + 3000);
    // Try to bid with a new user
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actorThree, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );
      // Add funds to the actor two

      hoax(_actorThree);
      approveAsset(_WETH, address(getUnlockd()), 1.2 ether); // APPROVE AMOUNT

      hoax(_actorThree);
      vm.expectRevert(Errors.TimestampExpired.selector);
      Auction(_auction).bid(1.2 ether, 0.5 ether, signAuction, sig); // BID ON THE ASSET
    }
    return loanId;
  }

  function test_auction_bid_healty_liquidation_auction() public {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1.2 ether, 2 ether, 2, 2);
    writeTokenBalance(_actorTwo, _WETH, 2 ether);

    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = auction_signature(
        _auction,
        AuctionSignParams({user: _actorTwo, loanId: loanId, price: 3 ether, totalAssets: 1}),
        AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
      );
    // Add funds to the actor two

    uint256 bidAmount = 1 ether;
    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.HealtyLoan.selector);
    Auction(_auction).bid(0, 0, signAuction, sig); // BID ON THE ASSET
  }

  function test_auction_bid_with_market_auction_active() public {
    /**
      - Borrow with one asset 0.2 ether
      - Create a reguar auction in market
      - Bid on the market auction
      - Borrow more increasing the valuation of the asset
      - Reduce the price and force the position to be unhealty
      */

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.2 ether, 1 ether, 1, 1);

    bytes32 orderId = _create_market_auction(loanId, 0.2 ether);
    // Bid AUCTION 3
    _bid_market_auction(loanId, orderId, _actorThree);

    // ACTIVATE the loan
    hoax(_admin);
    Manager(_manager).emergencyActivateLoan(loanId);
    // We force borrow more because a price increased
    borrow_more_action(loanId, _action, _nft, _WETH, _actor, 0.2 ether, 10 ether, 1);
    // Freeze LOAN
    hoax(_admin);
    Manager(_manager).emergencyFreezeLoan(loanId);

    uint256 minBid = Auction(_auction).getMinBidPriceAuction(
      loanId,
      AssetLogic.assetId(_nft, 1),
      0.3 ether,
      0,
      6000
    );
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    writeTokenBalance(_actorTwo, _WETH, 2 ether);
    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = auction_signature(
        _auction,
        AuctionSignParams({user: _actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
        AssetAuctionParams({
          assets: assets,
          // We reduce the price of the asset to force the liquidation
          assetPrice: 0.3 ether,
          assetLtv: 6000
        })
      );
    // Add funds to the actor two

    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), minBid); // APPROVE AMOUNT

    hoax(_actorTwo);
    Auction(_auction).bid(uint128(minBid), 0, signAuction, sig); // BID ON THE ASSET
  }

  function test_auction_bid_error_with_market_auction_ongoing_healty() public {
    /**
      - Borrow with one asset 0.2 ether
      - Create a reguar auction in market
      - Bid on the market auction
      - Borrow more increasing the valuation of the asset
      - Reduce the price and force the position to be unhealty
      */
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.2 ether, 1 ether, 1, 1);

    bytes32 orderId = _create_market_auction(loanId, 0.2 ether);

    _bid_market_auction(loanId, orderId, _actorThree);

    uint256 minBid = Auction(_auction).getMinBidPriceAuction(
      loanId,
      AssetLogic.assetId(_nft, 1),
      1 ether,
      0,
      6000
    );

    writeTokenBalance(_actorTwo, _WETH, 2 ether);
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = auction_signature(
        _auction,
        AuctionSignParams({user: _actorTwo, loanId: loanId, price: 0, totalAssets: 0}),
        AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
      );

    hoax(_actorTwo);
    approveAsset(_WETH, address(getUnlockd()), minBid); // APPROVE AMOUNT

    hoax(_actorTwo);
    vm.expectRevert(Errors.HealtyLoan.selector);
    Auction(_auction).bid(uint128(minBid), 0, signAuction, sig); // BID ON THE ASSET
  }

  /////////////////////////////////////////////////////////////////////////////////
  // REDEEM
  /////////////////////////////////////////////////////////////////////////////////

  function test_auction_redeem_active_liquidation_auction() public {
    /*
      - Create a Loan with two assets
      - Establish a position that is set to liquidate, generating a debt of 0.5. Then, place a bid on this position using User One.
      - Then, bid again and verify that the value of the last bid has increased by 2.5%  (0,5125 ether)
      - Redeem, which means the owner of the loan is required to repay the initial debt plus an additional 2.5%.(0,5125 ether)

    */

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1 ether, 2 ether, 2, 2);
    writeTokenBalance(_actorTwo, _WETH, 1 ether);
    writeTokenBalance(_actorThree, _WETH, 1 ether);

    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    (
      DataTypes.SignAuction memory signAuction,
      DataTypes.EIP712Signature memory sig
    ) = auction_signature(
        _auction,
        AuctionSignParams({user: _actorTwo, loanId: loanId, price: 1 ether, totalAssets: 1}),
        AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 5000})
      );

    {
      vm.startPrank(_actorTwo);
      // USER 2 BIDS
      // Add funds to the actor two
      uint256 bidAmount = Auction(_auction).getMinBidPriceAuction(
        loanId,
        AssetLogic.assetId(_nft, 0),
        1 ether,
        1 ether,
        5000
      );
      assertEq(bidAmount, 0.5 ether);

      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT

      Auction(_auction).bid(uint128(bidAmount), 0, signAuction, sig); // BID ON THE ASSET
      vm.stopPrank();
    }
    assertEq(IERC20(_WETH).balanceOf(_actorTwo), 0.5 ether);

    {
      vm.startPrank(_actorThree);

      // Add funds to the actor two
      uint256 bidAmount = Auction(_auction).getMinBidPriceAuction(
        loanId,
        AssetLogic.assetId(_nft, 0),
        1 ether,
        1 ether,
        5000
      );

      assertEq(bidAmount, 0.5125 ether);

      (uint256 totalAmount, uint256 totalDebt, uint256 bidderBonus) = Auction(_auction)
        .getAmountToReedem(loanId, assets);

      assertEq(totalDebt, 0.5 ether);
      assertEq(totalAmount, 1.0125 ether);
      assertEq(bidderBonus, 0.0125 ether);

      approveAsset(_WETH, address(getUnlockd()), bidAmount); // APPROVE AMOUNT
      Auction(_auction).bid(uint128(bidAmount), 0, signAuction, sig); // BID ON THE ASSET
      vm.stopPrank();
    }
    assertEq(IERC20(_WETH).balanceOf(_actorThree), 0.4875 ether); // - debt + 2.5%
    assertEq(IERC20(_WETH).balanceOf(_actorTwo), 1.0125 ether); // +deb + 2.5%

    writeTokenBalance(_actor, _WETH, 3 ether);

    {
      (uint256 totalAmount, uint256 totalDebt, uint256 bidderBonus) = Auction(_auction)
        .getAmountToReedem(loanId, assets);

      assertEq(totalDebt, 0.5 ether);
      assertEq(totalAmount, 1.0125 ether);
      assertEq(bidderBonus, 0.0125 ether);

      (
        DataTypes.SignAuction memory signAuctionRedeem,
        DataTypes.EIP712Signature memory sigRedeem
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 2}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 5000})
        );

      hoax(_actor);
      approveAsset(_WETH, address(getUnlockd()), totalAmount); // APPROVE AMOUNT

      hoax(_actor);
      Auction(_auction).redeem(totalAmount, assets, signAuctionRedeem, sigRedeem);
    }
  }

  function test_auction_redeem_expired_liquidation_auction() public {
    bytes32 loanId = test_auction_bid_liquidation_auction();

    // bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    vm.warp(block.timestamp + 3000);

    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    writeTokenBalance(_actor, _WETH, 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 1 ether, totalAssets: 2}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      approveAsset(_WETH, address(getUnlockd()), 757500000000097574); // APPROVE AMOUNT

      hoax(_actor);
      vm.expectRevert(Errors.TimestampExpired.selector);
      Auction(_auction).redeem(757500000000097574, assets, signAuction, sig);
    }
  }

  /////////////////////////////////////////////////////////////////////////////////
  // FINALIZE
  /////////////////////////////////////////////////////////////////////////////////

  function test_auction_finalize_liquidation_auction_success() public {
    vm.recordLogs();
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    DataTypes.Order memory order = Auction(_auction).getOrderAuction(orderId);

    // We check that the owner of the ASSET is the LOAN owner
    {
      // Check that these nfts are locked
      IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
        .getOwnerWalletAt(_actor, 0);
      // Get the loan from the winner bidder
      DataTypes.Loan memory loan = Action(_action).getLoan(loanId);

      assertEq(_actor, loan.owner);
      assertEq(
        ProtocolOwner(wallet.protocolOwner).isAssetLocked(AssetLogic.assetId(_nft, 0)),
        true
      );
      assertEq(
        ProtocolOwner(wallet.protocolOwner).getLoanId(AssetLogic.assetId(_nft, 0)),
        loan.loanId
      );
      assertEq(IERC721(_nft).ownerOf(0), wallet.wallet);
    }
    // END AUCTION
    vm.warp(block.timestamp + 3000);
    writeTokenBalance(_actor, _WETH, 2 ether);
    {
      bytes32[] memory assets = new bytes32[](2);
      assets[0] = AssetLogic.assetId(_nft, 0);
      assets[1] = AssetLogic.assetId(_nft, 1);
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );
    }

    // We check the new owner
    {
      // Check that these nfts are locked
      IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
        .getOwnerWalletAt(_actorTwo, 0);
      // Get the loan from the winner bidder
      DataTypes.Loan memory loan = Action(_action).getLoan(order.bid.loanId);

      assertEq(_actorTwo, loan.owner);
      assertEq(
        ProtocolOwner(wallet.protocolOwner).isAssetLocked(AssetLogic.assetId(_nft, 0)),
        true
      );
      assertEq(
        ProtocolOwner(wallet.protocolOwner).getLoanId(AssetLogic.assetId(_nft, 0)),
        loan.loanId
      );
      assertEq(IERC721(_nft).ownerOf(0), wallet.wallet);
    }
  }

  function test_auction_finalize_liquidation_auction_error_LoanNotUpdated() public {
    vm.recordLogs();
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);

    // END AUCTION
    vm.warp(block.timestamp + 3000);
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);

    {
      writeTokenBalance(_actor, _WETH, 2 ether);
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 3}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      vm.expectRevert(Errors.LoanNotUpdated.selector);
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );
    }
  }

  function test_auction_finalize_liquidation_auction_reactivate_loan() public {
    vm.recordLogs();
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32[] memory assets = new bytes32[](1);
    assets[0] = AssetLogic.assetId(_nft, 0);

    // END AUCTION
    vm.warp(block.timestamp + 3000);
    writeTokenBalance(_actor, _WETH, 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );

      DataTypes.Loan memory loan = Action(_action).getLoan(loanId);
      assertEq(uint(loan.state), uint(Constants.LoanState.ACTIVE));
    }
  }

  function test_auction_finalize_error_OrderNotAllowed() public {
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.2 ether, 1 ether, 1, 1);
    bytes32 orderId = _create_market_auction(loanId, 0.2 ether);
    bytes32[] memory assets = new bytes32[](1);
    assets[0] = AssetLogic.assetId(_nft, 0);
    // END AUCTION
    vm.warp(block.timestamp + 3000);
    writeTokenBalance(_actor, _WETH, 2 ether);
    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      vm.expectRevert(Errors.OrderNotAllowed.selector);
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );
    }
  }

  function test_auction_finalize_not_ended_liquidation_auction() public {
    vm.recordLogs();
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);
    {
      writeTokenBalance(_actor, _WETH, 2 ether);
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      vm.expectRevert(Errors.TimestampNotExpired.selector);
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );
    }
  }

  function test_auction_finalize_two_times_liquidation_auction() public {
    bytes32 loanId = test_auction_bid_liquidation_auction();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 orderId = bytes32(entries[entries.length - 1].topics[2]);
    bytes32[] memory assets = new bytes32[](2);
    assets[0] = AssetLogic.assetId(_nft, 0);
    assets[1] = AssetLogic.assetId(_nft, 1);
    // END AUCTION
    vm.warp(block.timestamp + 3000);

    {
      writeTokenBalance(_actor, _WETH, 2 ether);

      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );
    }

    {
      (
        DataTypes.SignAuction memory signAuction,
        DataTypes.EIP712Signature memory sig
      ) = auction_signature(
          _auction,
          AuctionSignParams({user: _actor, loanId: loanId, price: 0.8 ether, totalAssets: 1}),
          AssetAuctionParams({assets: assets, assetPrice: 1 ether, assetLtv: 6000})
        );

      hoax(_actor);
      vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOrderOwner.selector));
      Auction(_auction).finalize(
        true,
        orderId,
        DataTypes.Asset({collection: _nft, tokenId: 0}),
        signAuction,
        sig
      );
    }
  }
}
