// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {Action, ActionSign} from '../../src/protocol/modules/Action.sol';
import {Auction, AuctionSign, IAuctionModule} from '../../src/protocol/modules/Auction.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import '../test-utils/mock/asset/MintableERC20.sol';

contract ReservoidAdapterTest is Setup {
  uint256 internal ACTOR = 1;
  uint256 internal ACTORTWO = 2;
  uint256 internal ACTORTHREE = 3;
  uint256 internal ACTOR_NO_WALLET = 4;
  address internal _actor;
  address internal _nft;
  address internal _auction;
  address internal _action;
  uint256 internal deadlineIncrement;

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

  /////////////////////////////////////////////////////////////////////////////////
  // BID
  /////////////////////////////////////////////////////////////////////////////////
}
