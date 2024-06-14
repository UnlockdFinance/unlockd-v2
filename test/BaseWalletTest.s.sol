// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {ProtocolOwner} from '@unlockd-wallet/src/libs/owners/ProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';

import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Manager} from '../src/protocol/modules/Manager.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import {IBasicWalletVault} from '../src/interfaces/IBasicWalletVault.sol';

contract BaseWalletTest is Setup {
  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;

  // MODULES
  address internal _manager;
  address internal _action;
  address internal _market;

  address internal _nft;
  address internal _WETH;

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

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _market = unlockd.moduleIdToProxy(Constants.MODULEID__MARKET);
    _manager = unlockd.moduleIdToProxy(Constants.MODULEID__MANAGER);
    _nft = _nfts.get('PUNK');
  }

  function test_create_wallet() public {
    (
      address wallet,
      address delegationOwner,
      address protocolOwner,
      address guardOwner
    ) = DelegationWalletFactory(_walletFactory).deployFor(_actorTwo, address(0));
  }

  /////////////////////////////////////////////////////////////////////////////////
  // Wallet
  /////////////////////////////////////////////////////////////////////////////////
  function test_deposit_nft_asset_basic_wallet() public {
    uint256 tokenId = 101;
    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);
    mintNFTToken(_actor, 'PUNK', tokenId);
    assertEq(IERC721(address(_nft)).ownerOf(tokenId), _actor);
    IERC721(address(_nft)).safeTransferFrom(_actor, wallet, tokenId);
    assertEq(IERC721(address(_nft)).ownerOf(tokenId), wallet);
    vm.stopPrank();
  }

  function test_withdraw_nft_asset_basic_wallet() public {
    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);
    IBasicWalletVault.AssetTransfer[] memory transfers = new IBasicWalletVault.AssetTransfer[](1);
    transfers[0] = IBasicWalletVault.AssetTransfer({contractAddress: address(_nft), value: 1, isERC20: false});
    IBasicWalletVault(wallet).withdrawAssets(transfers, _actor);
    vm.stopPrank();
  }

  function test_deposit_asset_basic_wallet() public {
    uint256 amount = 1 ether;
    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);
    mintERC20Token(_actor, 'WETH', amount);
    assertEq(IERC20(_WETH).balanceOf(_actor), amount);
    IERC20(_WETH).transfer(wallet, amount);
    assertEq(IERC20(_WETH).balanceOf(wallet), amount);
    vm.stopPrank();
  }

  function test_withdraw_asset_basic_wallet() public {
    uint256 amount = 2 ether;
    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);
    mintERC20Token(wallet, 'WETH', amount);
    IBasicWalletVault.AssetTransfer[] memory transfers = new IBasicWalletVault.AssetTransfer[](1);
    transfers[0] = IBasicWalletVault.AssetTransfer({contractAddress: _WETH, value: amount, isERC20: true});
    IBasicWalletVault(wallet).withdrawAssets(transfers, _actor);
    vm.stopPrank();
  }

  function test_deposit_multiple_assets_basic_wallet() public {
    uint256 tokenId = 101;
    uint256 amount = 1 ether;

    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);

    mintNFTToken(_actor, 'PUNK', tokenId);
    assertEq(IERC721(address(_nft)).ownerOf(tokenId), _actor);
    mintERC20Token(_actor, 'WETH', amount);
    assertEq(IERC20(_WETH).balanceOf(_actor), amount);

    IERC721(address(_nft)).safeTransferFrom(_actor, wallet, tokenId);
    assertEq(IERC721(address(_nft)).ownerOf(tokenId), wallet);
    IERC20(_WETH).transfer(wallet, amount);
    assertEq(IERC20(_WETH).balanceOf(wallet), amount);
  }

  function test_withdraw_multiple_assets_basic_wallet() public {
    uint256 amount = 1 ether;
    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);
    mintERC20Token(wallet, 'WETH', amount);
    IBasicWalletVault.AssetTransfer[] memory transfers = new IBasicWalletVault.AssetTransfer[](2);
    transfers[0] = IBasicWalletVault.AssetTransfer({contractAddress: address(_nft), value: 1, isERC20: false});
    transfers[1] = IBasicWalletVault.AssetTransfer({contractAddress: _WETH, value: amount, isERC20: true});
    IBasicWalletVault(wallet).withdrawAssets(transfers, _actor);
    vm.stopPrank();
  }

  function test_borrow_block_withdraw() public {
    uint256 amountToRepay = 0.5 ether;
    uint256 collateral = 2 ether;
    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, amountToRepay, collateral, 2, 2);
    assertEq(balanceAssets(makeAsset('WETH'), _actor), amountToRepay);
    vm.startPrank(_actor);
    address wallet = getWalletAddress(_actor);
    IBasicWalletVault.AssetTransfer[] memory transfers = new IBasicWalletVault.AssetTransfer[](1);
    transfers[0] = IBasicWalletVault.AssetTransfer({contractAddress: address(_nft), value: 1, isERC20: false});
    vm.expectRevert(abi.encodeWithSelector(Errors.AssetLocked.selector));
    IBasicWalletVault(wallet).withdrawAssets(transfers, _actor);
    vm.stopPrank();
  }
}
