// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/setups/Setup.sol';
import {SellNowLogic, DataTypes} from '../../../src/libraries/logic/SellNowLogic.sol';

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {NFTMarket} from '../../test-utils/mock/market/NFTMarket.sol';

contract SellNowLogicTest is Setup {
  DataTypes.Order private order;

  address internal _actor;
  address internal _actorTwo;
  address internal _actorThree;
  address internal _actorNoWallet;

  address internal _nft;
  address internal _action;
  address internal _auction;
  NFTMarket internal _market;

  address internal _sellnow;

  address internal _WETH;

  // *************************************
  function setUp() public override {
    super.setUp();
    _market = new NFTMarket();
    _actor = makeAddr('filipe');
    _actorTwo = makeAddr('kiki');
    _actorThree = makeAddr('dani');
    _actorNoWallet = makeAddr('noWallet');

    _WETH = makeAsset('WETH');
    // Fill the protocol with funds
    addFundToUToken('WETH', 100 ether);
    addFundToUToken('DAI', 100 ether);

    createWalletAndMintTokens(_actor, 'PUNK');
    createWalletAndMintTokens(_actorTwo, 'KITTY');
    createWalletAndMintTokens(_actorThree, 'KITTY');

    Unlockd unlockd = super.getUnlockd();
    _action = unlockd.moduleIdToProxy(Constants.MODULEID__ACTION);
    _auction = unlockd.moduleIdToProxy(Constants.MODULEID__AUCTION);
    _sellnow = unlockd.moduleIdToProxy(Constants.MODULEID__SELLNOW);
    _nft = _nfts.get('PUNK');
    vm.startPrank(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));
    vm.stopPrank();
  }

  // function test_sellNow_repayDebtAndUser() public {
  //   hoax(_actor);

  //   writeTokenBalance(makeAddr('protocol'), _WETH, 10 ether);
  //   vm.startPrank(makeAddr('protocol'));
  //   _uTokenVault.borrow(_WETH, 'loan_0', 1 ether, _actor, _actor);
  //   assertEq(_uTokenVault.getScaledDebtFromLoanId(_WETH, 'loan_0'), 1 ether);

  //   assertEq(IERC20(_WETH).balanceOf(_actor), 1 ether);
  //   IERC20(_WETH).approve(address(_uTokenVault), 10 ether);

  //   SellNowLogic.repayDebtAndUser(
  //     SellNowLogic.RepayDebtAndUserParams({
  //       loanId: 'loan_0',
  //       aggLoanPrice: 0.5 ether,
  //       aggLtv: 6000,
  //       totalDebt: 1 ether,
  //       marketPrice: 2 ether,
  //       underlyingAsset: _WETH,
  //       uTokenVault: address(_uTokenVault),
  //       from: makeAddr('protocol'),
  //       owner: _actor
  //     })
  //   );

  //   assertEq(_uTokenVault.getScaledDebtFromLoanId(_WETH, 'loan_0'), 0.3 ether);
  //   assertEq(IERC20(_WETH).balanceOf(_actor), 2.3 ether);
  //   vm.stopPrank();
  // }

  // function test_sellNow_sellAsset() public {
  //   DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 0});
  //   address walletAddress = getWalletAddress(_actor);
  //   address protocolOwner = getProtocolOwnerAddress(_actor);

  //   writeTokenBalance(address(_market), makeAsset('WETH'), 100 ether);

  //   DataTypes.SignSellNow memory data = DataTypes.SignSellNow({
  //     loan: DataTypes.SignLoanConfig({
  //       loanId: 'loan_0', // Because is new need to be 0
  //       aggLoanPrice: 1 ether,
  //       aggLtv: 6000,
  //       aggLiquidationThreshold: 6000,
  //       totalAssets: 1,
  //       nonce: 0,
  //       deadline: 0
  //     }),
  //     assetId: AssetLogic.assetId(asset.collection, asset.tokenId),
  //     marketAdapter: address(_reservoirAdapter),
  //     marketApproval: address(_market),
  //     marketPrice: 1 ether,
  //     underlyingAsset: _WETH,
  //     from: walletAddress,
  //     to: address(_market),
  //     data: abi.encodeWithSelector(
  //       NFTMarket.sell.selector,
  //       asset.collection,
  //       asset.tokenId,
  //       makeAsset('WETH'),
  //       1 ether
  //     ),
  //     value: 1 ether,
  //     nonce: 0,
  //     deadline: 0
  //   });

  //   vm.startPrank(makeAddr('protocol'));

  //   IProtocolOwner(protocolOwner).setLoanId(
  //     AssetLogic.assetId(asset.collection, asset.tokenId),
  //     'loan_0'
  //   );

  //   SellNowLogic.sellAsset(
  //     SellNowLogic.SellParams({
  //       signSellNow: data,
  //       asset: asset,
  //       wallet: walletAddress,
  //       protocolOwner: protocolOwner
  //     })
  //   );
  //   vm.stopPrank();
  // }
}
