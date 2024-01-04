// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {SellNow, SellNowSign} from '../src/protocol/modules/SellNow.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';
import {NFTMarket} from './test-utils/mock/market/NFTMarket.sol';
import {console} from 'forge-std/console.sol';

contract SellNowTest is Setup {
  address internal _actor;
  address internal _nft;
  address internal _WETH;

  address internal _sellNow;
  address internal _action;

  NFTMarket internal _market;

  address internal _wallet;

  function setUp() public virtual override {
    super.setUp();
    _market = new NFTMarket();
    _actor = makeAddr('filipe');
    _WETH = makeAsset('WETH');

    // Fill the protocol with funds
    addFundToUToken('WETH', 10 ether);
    addFundToUToken('DAI', 10 ether);

    // Add funds to the market
    writeTokenBalance(address(_market), makeAsset('WETH'), 100 ether);
    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(_actor, 'PUNK');

    // Mint a nfs inside of the market

    _nft = _nfts.get('PUNK');

    _action = _unlock.moduleIdToProxy(Constants.MODULEID__ACTION);
    _sellNow = _unlock.moduleIdToProxy(Constants.MODULEID__SELLNOW);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // SELLNOW
  /////////////////////////////////////////////////////////////////////////////////
  struct LoanData {
    bytes32 loanId;
    uint256 aggLoanPrice;
    uint88 totalAssets;
  }

  function _generate_signature(
    address sender,
    bytes32 assetId,
    LoanData memory loanData,
    ReservoirData memory dataSellWETHCurrency
  ) internal view returns (DataTypes.SignSellNow memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = SellNowSign(_sellNow).getNonce(sender);
    uint256 deadline = block.timestamp + 1000;

    DataTypes.SignSellNow memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignSellNow({
        loan: DataTypes.SignLoanConfig({
          loanId: loanData.loanId, // Because is new need to be 0
          aggLoanPrice: loanData.aggLoanPrice,
          aggLtv: 6000,
          aggLiquidationThreshold: 6000,
          totalAssets: loanData.totalAssets,
          nonce: nonce,
          deadline: deadline
        }),
        assetId: assetId,
        marketAdapter: address(_reservoirAdapter),
        marketApproval: dataSellWETHCurrency.approvalTo,
        marketPrice: dataSellWETHCurrency.price,
        underlyingAsset: config.weth,
        from: dataSellWETHCurrency.from,
        to: dataSellWETHCurrency.to,
        data: dataSellWETHCurrency.data,
        value: dataSellWETHCurrency.value,
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = SellNow(_sellNow).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // SELL
  /////////////////////////////////////////////////////////////////////////////////

  function test_sellnow_sell_no_loan() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 2});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: 0x0, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_actor);
    SellNow(_sellNow).sell(asset, data, sig);
    assertEq(IERC20(makeAsset('WETH')).balanceOf(_actor), 1 ether);
    assertEq(IERC721(address(_nft)).ownerOf(2), address(_market));
  }

  function test_sellnow_sell_repay_loan() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 0});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.2 ether, 2 ether, 1, 1);
    // Preparing data to execute

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_actor);
    SellNow(_sellNow).sell(asset, data, sig);

    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), address(_market));
  }

  function test_sellnow_sell_repay_loan_multiple_assets() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 1});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.2 ether, 3 ether, 3, 3);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 2 ether, totalAssets: 2}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_actor);
    SellNow(_sellNow).sell(asset, data, sig);
    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), address(_market));
  }

  function test_sellnow_sell_error_unhealty_loan() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 1});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.5 ether, 2 ether, 2, 2);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 0.5 ether, totalAssets: 1}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          0.1 ether
        ),
        price: 0.1 ether,
        value: 0
      })
    );
    hoax(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.UnhealtyLoan.selector)); // Unhealty loan
    SellNow(_sellNow).sell(asset, data, sig);

    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), walletAddress);
  }

  function test_sellnow_sell_error_unhealty_loan_with_multiples_assets() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 2});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.8 ether, 2 ether, 3, 3);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 1 ether, totalAssets: 2}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          0.2 ether
        ),
        price: 0.2 ether,
        value: 0
      })
    );

    hoax(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.UnhealtyLoan.selector)); // Unhealty loan
    SellNow(_sellNow).sell(asset, data, sig);

    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), walletAddress);
  }

  function test_sellnow_sell_error_price_do_not_cover_debt() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 0});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.8 ether, 2 ether, 1, 1);

    // Preparing data to execute

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          0.5 ether
        ),
        price: 0.5 ether,
        value: 0
      })
    );
    hoax(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.UnhealtyLoan.selector));
    SellNow(_sellNow).sell(asset, data, sig);
  }

  function test_sellnow_sell_error_loan_not_updated() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 0});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.8 ether, 2 ether, 2, 2);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 2 ether, totalAssets: 3}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
    SellNow(_sellNow).sell(asset, data, sig);
  }

  function test_sellnow_sell_error_less_price() public {
    // Preparing data to execute
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 0});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.8 ether, 2 ether, 1, 1);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          0.5 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_actor);
    vm.expectRevert('SafeERC20: low-level call failed');
    SellNow(_sellNow).sell(asset, data, sig);

    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), walletAddress);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // FORCE SELL
  /////////////////////////////////////////////////////////////////////////////////

  function test_sellnow_force_sell_only_one_asset() public {
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 0});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 0.8 ether, 2 ether, 1, 1);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _admin,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_admin);
    SellNow(_sellNow).forceSell(asset, data, sig);
    // Check that the nft is on the market

    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), address(_market));
  }

  function test_sellnow_force_sell_two_assets() public {
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 2});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1.4 ether, 3 ether, 3, 3);
    // Preparing data to execute

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _admin,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 1.5 ether, totalAssets: 2}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_admin);
    SellNow(_sellNow).forceSell(asset, data, sig);
    // Check that the nft is on the market
    assertEq(IERC721(asset.collection).ownerOf(asset.tokenId), address(_market));
  }

  function test_sellnow_force_sell_error_loan_not_updated() public {
    address walletAddress = getWalletAddress(_actor);
    DataTypes.Asset memory asset = DataTypes.Asset({collection: address(_nft), tokenId: 2});

    vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
    vm.assume(IERC721(asset.collection).ownerOf(asset.tokenId) == walletAddress);

    bytes32 loanId = borrow_action(_action, _nft, _WETH, _actor, 1.4 ether, 3 ether, 3, 3);

    (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _admin,
      AssetLogic.assetId(asset.collection, asset.tokenId),
      LoanData({loanId: loanId, aggLoanPrice: 1.5 ether, totalAssets: 0}),
      ReservoirData({
        blockNumber: block.number,
        nftAsset: asset.collection,
        nftTokenId: asset.tokenId,
        currency: makeAsset('WETH'),
        from: walletAddress,
        to: address(_market),
        approval: address(_market),
        approvalTo: address(_market),
        approvalData: '0x',
        data: abi.encodeWithSelector(
          NFTMarket.sell.selector,
          asset.collection,
          asset.tokenId,
          makeAsset('WETH'),
          1 ether
        ),
        price: 1 ether,
        value: 0
      })
    );
    hoax(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
    SellNow(_sellNow).forceSell(asset, data, sig);
  }
}
