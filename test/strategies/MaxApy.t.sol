// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {IMarketAdapter} from '../../src/interfaces/adapter/IMarketAdapter.sol';
import {IEmergency} from '../../src/interfaces/IEmergency.sol';

import {Action, ActionSign} from '../../src/protocol/modules/Action.sol';
import {Auction, AuctionSign, IAuctionModule} from '../../src/protocol/modules/Auction.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import '../test-utils/mock/asset/MintableERC20.sol';

import {NFTMarket} from '../test-utils/mock/market/NFTMarket.sol';

contract MaxApyTest is Setup {
  uint256 internal ACTOR = 1;

  address internal _actor;
  address internal _nft;
  address internal _protocolOwner;
  address internal _wallet;
  uint256 internal deadlineIncrement;
  NFTMarket internal _market;

  function setUp() public virtual override {
    super.setUp();
    _market = new NFTMarket();
    _actor = getActorAddress(ACTOR);
    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    // Create wallet and mint to the safe wallet
    (_wallet, , _protocolOwner, ) = createWalletAndMintTokens(_actor, 'PUNK');
    writeTokenBalance(_actor, makeAsset('WETH'), 100 ether);
    writeTokenBalance(address(_market), makeAsset('WETH'), 100 ether);

    _nft = _nfts.get('PUNK');

    vm.startPrank(_admin);
    _aclManager.setProtocol(_actor);
    vm.stopPrank();
  }

  // /////////////////////////////////////////////////////////////////////////////////
  // // RESERVOIR
  // /////////////////////////////////////////////////////////////////////////////////

  function test_reservoirAdapter_preSell() public {
    hoax(_actor);
    IProtocolOwner(_protocolOwner).delegateOneExecution(_reservoirAdapter, true);

    hoax(_actor);
    IMarketAdapter(_reservoirAdapter).preSell(
      IMarketAdapter.PreSellParams({
        loanId: 0,
        collection: address(_nft),
        tokenId: 1,
        underlyingAsset: makeAsset('WETH'),
        marketPrice: 1 ether,
        marketApproval: address(_market),
        protocolOwner: _protocolOwner
      })
    );
  }

  function test_reservoirAdapter_sell() public {
    test_reservoirAdapter_preSell();

    IMarketAdapter.SellParams memory sellParams = IMarketAdapter.SellParams({
      collection: address(_nft),
      tokenId: 1,
      wallet: _wallet,
      protocolOwner: _protocolOwner,
      underlyingAsset: makeAsset('WETH'),
      marketPrice: 1 ether,
      to: address(_market),
      value: 0,
      data: abi.encodeWithSelector(
        NFTMarket.sell.selector,
        address(_nft),
        1,
        makeAsset('WETH'),
        1 ether
      )
    });

    hoax(_actor);
    IProtocolOwner(_protocolOwner).delegateOneExecution(_reservoirAdapter, true);

    hoax(_actor);
    IMarketAdapter(_reservoirAdapter).sell(sellParams);

    assertEq(ERC721(_nft).ownerOf(1), address(_market));
  }

  function test_reservoirAdapter_preBuy() public {
    hoax(_actor);
    IMarketAdapter(_reservoirAdapter).preBuy(
      IMarketAdapter.PreBuyParams({
        loanId: 0,
        collection: address(_nft),
        tokenId: 1,
        underlyingAsset: makeAsset('WETH'),
        marketPrice: 1 ether,
        marketApproval: address(_market),
        protocolOwner: _protocolOwner
      })
    );
  }

  function test_reservoirAdapter_buy() public {
    // Mint the asset on the market
    MintableERC20(_nft).mintToAddress(111, address(_market));
    // Send amount to the adapter
    hoax(_actor);
    IERC20(makeAsset('WETH')).transfer(_reservoirAdapter, 1 ether);
    // Execute buy
    hoax(_actor);
    IMarketAdapter(_reservoirAdapter).buy(
      IMarketAdapter.BuyParams({
        wallet: _wallet,
        underlyingAsset: makeAsset('WETH'),
        marketPrice: 1 ether,
        marketApproval: address(_market),
        to: address(_market),
        value: 0,
        data: abi.encodeWithSelector(
          NFTMarket.buy.selector,
          _actor,
          address(_nft),
          111,
          makeAsset('WETH'),
          1 ether
        )
      })
    );
    // We check that the current owner is the wallet
    assertEq(ERC721(_nft).ownerOf(111), _actor);
  }

  function test_reservoirAdapter_emergency_withdraw() public {
    // PREPARE
    hoax(_actor);
    (bool success, ) = payable(_reservoirAdapter).call{value: 1 ether}('');
    require(success, 'Address: unable to send value, recipient may have reverted');
    hoax(_actor);
    IERC20(makeAsset('WETH')).transfer(_reservoirAdapter, 1 ether);
    assertEq(makeAddr('filipe').balance, 0);
    hoax(_admin);
    IEmergency(_reservoirAdapter).emergencyWithdraw(payable(makeAddr('filipe')));

    assertEq(makeAddr('filipe').balance, 1 ether);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('filipe')), 0);
    hoax(_admin);
    IEmergency(_reservoirAdapter).emergencyWithdrawERC20(makeAsset('WETH'), makeAddr('filipe'));

    assertEq(IERC20(makeAsset('WETH')).balanceOf(makeAddr('filipe')), 1 ether);
  }
}
