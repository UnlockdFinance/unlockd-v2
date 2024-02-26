// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';
import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

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
import {Config} from './test-utils/config/Config.sol';
import {console} from 'forge-std/console.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';

contract IssueTest is Setup {
  address internal _actor;

  address internal _nft;
  // MODULES
  address internal _manager;
  address internal _action;
  address internal _market;

  function setUp() public virtual override {
    super.setUp();
    _actor = makeAddr('filipe');

    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);
    // Create wallet
    createWalletAndMintTokens(_actor, 'PUNK');
    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _market = unlockd.moduleIdToProxy(Constants.MODULEID__MARKET);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
    _nft = _nfts.get('PUNK');
  }

  // function xtest_weirdResponse() public {
  //   // Sepolia
  //   Config.ChainConfig memory config = Config.getConfig(11155111);
  //   // Chain FORK
  //   uint256 chainFork = vm.createFork(config.chainName, 5346800);
  //   vm.selectFork(chainFork);

  //   address _auction_deployed = 0x876B57F8C3cb8085502cFBF0E47Ca8130Ea6c021;
  //   Auction auction = Auction(_auction_deployed);
  //   vm.expectRevert();
  //   uint256 result = auction.getMinBidPriceAuction(
  //     0x0c55e62e379946b598dc89288aae8cffe3027561c0810021286b9620684c9dff,
  //     0x4399b219a932066b478a6f69a79412652cf47734f64512b2895af8afaed5880f,
  //     1000,
  //     0,
  //     0
  //   );

  //   // assertEq(result, 2929000);
  // }
}
