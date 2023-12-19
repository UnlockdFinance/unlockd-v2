// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {BuyNow, BuyNowSign} from '../src/protocol/modules/BuyNow.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';
import {NFTMarket} from './test-utils/mock/market/NFTMarket.sol';
import {console} from 'forge-std/console.sol';

contract BuyNowTest is Setup {
  uint256 internal ACTOR = 1;
  address internal _action;
  address internal _actor;
  address internal _nft;
  address internal _buyNow;
  uint256 internal _tokenId;
  uint256 internal deadlineIncrement;
  NFTMarket internal _market;
  ReservoirData dataBuyWETHCurrency;

  function setUp() public virtual override {
    super.setUp();
    _market = new NFTMarket();
    _actor = getActorAddress(ACTOR);
    // // Fill the protocol with funds
    addFundToUToken(address(_uTokens['WETH']), 'WETH', 10 ether);
    addFundToUToken(address(_uTokens['DAI']), 'DAI', 10 ether);
    // Add funds to the market
    writeTokenBalance(address(_market), getAssetAddress('WETH'), 100 ether);
    writeTokenBalance(address(_actor), getAssetAddress('WETH'), 100 ether);
    // Create wallet and mint to the safe wallet
    createWalletAndMintTokens(ACTOR, 'PUNK');
    _tokenId = mintNextNFTToken(address(_market), 'PUNK');
    _nft = super.getNFT('PUNK');
    _action = _unlock.moduleIdToProxy(Constants.MODULEID__ACTION);
    _buyNow = _unlock.moduleIdToProxy(Constants.MODULEID__BUYNOW);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // GENERATE SIGNATURE
  /////////////////////////////////////////////////////////////////////////////////

  function _generate_signature(
    address sender
  ) internal view returns (DataTypes.SignBuyNow memory, DataTypes.EIP712Signature memory) {
    // Get nonce from the user
    uint256 nonce = BuyNowSign(_buyNow).getNonce(sender);
    uint256 deadline = block.timestamp + 1000;

    DataTypes.SignBuyNow memory data;
    DataTypes.EIP712Signature memory sig;
    {
      // Create the struct
      data = DataTypes.SignBuyNow({
        asset: DataTypes.SignAsset({
          assetId: AssetLogic.assetId(address(_nft), _tokenId),
          collection: address(_nft),
          tokenId: _tokenId,
          price: dataBuyWETHCurrency.price,
          nonce: nonce,
          deadline: deadline
        }),
        assetLtv: 6000,
        assetLiquidationThreshold: 6000,
        from: dataBuyWETHCurrency.from,
        to: dataBuyWETHCurrency.to,
        data: dataBuyWETHCurrency.data,
        value: dataBuyWETHCurrency.value,
        marketApproval: dataBuyWETHCurrency.approvalTo,
        marketPrice: dataBuyWETHCurrency.price,
        underlyingAsset: config.weth,
        nonce: nonce,
        deadline: deadline
      });

      bytes32 digest = BuyNow(_buyNow).calculateDigest(nonce, data);
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

      // Build signature struct
      sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
    }
    return (data, sig);
  }

  /////////////////////////////////////////////////////////////////////////////////
  // BUYNOW
  /////////////////////////////////////////////////////////////////////////////////

  function test_buynow_buy() public {
    dataBuyWETHCurrency = ReservoirData({
      blockNumber: block.number,
      nftAsset: address(_nft),
      nftTokenId: _tokenId,
      currency: getAssetAddress('WETH'),
      from: getWalletAddress(ACTOR),
      to: address(_market),
      approval: address(_market),
      approvalTo: address(_market),
      approvalData: '0x',
      data: abi.encodeWithSelector(
        NFTMarket.buy.selector,
        getWalletAddress(ACTOR),
        address(_nft),
        _tokenId,
        getAssetAddress('WETH'),
        1 ether
      ),
      price: 1 ether,
      value: 0
    });

    vm.assume(IERC20(getAssetAddress('WETH')).balanceOf(_actor) == 100 ether);
    vm.assume(IERC721(address(_nft)).ownerOf(_tokenId) == address(_market));

    (DataTypes.SignBuyNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor
    );
    hoax(_actor);
    IERC20(getAssetAddress('WETH')).approve(address(_unlock), 1 ether);
    hoax(_actor);
    BuyNow(_buyNow).buy(_reservoirAdapter, address(_uTokens['WETH']), 1 ether, data, sig);
    // assertEq(IERC20(getAssetAddress('WETH')).balanceOf(_actor), 1 ether);
    assertEq(IERC721(address(_nft)).ownerOf(_tokenId), getWalletAddress(ACTOR));
  }

  function test_buynow_buy_with_loan() public {
    dataBuyWETHCurrency = ReservoirData({
      blockNumber: block.number,
      nftAsset: address(_nft),
      nftTokenId: _tokenId,
      currency: getAssetAddress('WETH'),
      from: getWalletAddress(ACTOR),
      to: address(_market),
      approval: address(_market),
      approvalTo: address(_market),
      approvalData: '0x',
      data: abi.encodeWithSelector(
        NFTMarket.buy.selector,
        getWalletAddress(ACTOR),
        address(_nft),
        _tokenId,
        getAssetAddress('WETH'),
        1 ether
      ),
      price: 1 ether,
      value: 0
    });

    vm.assume(IERC20(getAssetAddress('WETH')).balanceOf(_actor) == 100 ether);
    vm.assume(IERC721(address(_nft)).ownerOf(_tokenId) == address(_market));

    (DataTypes.SignBuyNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor
    );
    hoax(_actor);
    IERC20(getAssetAddress('WETH')).approve(address(_unlock), 1 ether);
    hoax(_actor);
    BuyNow(_buyNow).buy(_reservoirAdapter, address(_uTokens['WETH']), 0.9 ether, data, sig);

    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(_walletRegistry)
      .getOwnerWalletAt(_actor, 0);

    assertEq(
      IProtocolOwner(wallet.protocolOwner).isAssetLocked(
        AssetLogic.assetId(address(_nft), _tokenId)
      ),
      true
    );
    assertEq(IERC721(address(_nft)).ownerOf(_tokenId), getWalletAddress(ACTOR));
  }

  function test_buynow_buy_with_loan_error_to_low() public {
    dataBuyWETHCurrency = ReservoirData({
      blockNumber: block.number,
      nftAsset: address(_nft),
      nftTokenId: _tokenId,
      currency: getAssetAddress('WETH'),
      from: getWalletAddress(ACTOR),
      to: address(_market),
      approval: address(_market),
      approvalTo: address(_market),
      approvalData: '0x',
      data: abi.encodeWithSelector(
        NFTMarket.buy.selector,
        getWalletAddress(ACTOR),
        address(_nft),
        _tokenId,
        getAssetAddress('WETH'),
        1 ether
      ),
      price: 1 ether,
      value: 0
    });

    vm.assume(IERC20(getAssetAddress('WETH')).balanceOf(_actor) == 100 ether);
    vm.assume(IERC721(address(_nft)).ownerOf(_tokenId) == address(_market));

    (DataTypes.SignBuyNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
      _actor
    );
    hoax(_actor);
    IERC20(getAssetAddress('WETH')).approve(address(_unlock), 1 ether);

    vm.startPrank(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.AmountToLow.selector));
    BuyNow(_buyNow).buy(_reservoirAdapter, address(_uTokens['WETH']), 0.39 ether, data, sig);
    vm.stopPrank();
  }

  /////////////////////////////////////////////////////////////////////////////////
  // CALCULATIONS
  /////////////////////////////////////////////////////////////////////////////////

  function test_buynow_calculations() public {
    dataBuyWETHCurrency = ReservoirData({
      blockNumber: block.number,
      nftAsset: address(_nft),
      nftTokenId: _tokenId,
      currency: getAssetAddress('WETH'),
      from: getWalletAddress(ACTOR),
      to: address(_market),
      approval: address(_market),
      approvalTo: address(_market),
      approvalData: '0x',
      data: abi.encodeWithSelector(
        NFTMarket.buy.selector,
        getWalletAddress(ACTOR),
        address(_nft),
        _tokenId,
        getAssetAddress('WETH'),
        1 ether
      ),
      price: 1 ether,
      value: 0
    });

    vm.assume(IERC20(getAssetAddress('WETH')).balanceOf(_actor) == 100 ether);
    vm.assume(IERC721(address(_nft)).ownerOf(_tokenId) == address(_market));

    (DataTypes.SignBuyNow memory data, ) = _generate_signature(_actor);

    (uint256 minAmount, uint256 maxAmount) = BuyNow(_buyNow).getCalculations(
      address(_uTokens['WETH']),
      data
    );

    assertEq(minAmount, 400000000000000000);
    assertEq(maxAmount, 600000000000000000);
  }

  function test_buynow_calculations_invalid_utoken() public {
    dataBuyWETHCurrency = ReservoirData({
      blockNumber: block.number,
      nftAsset: address(_nft),
      nftTokenId: _tokenId,
      currency: getAssetAddress('WETH'),
      from: getWalletAddress(ACTOR),
      to: address(_market),
      approval: address(_market),
      approvalTo: address(_market),
      approvalData: '0x',
      data: abi.encodeWithSelector(
        NFTMarket.buy.selector,
        getWalletAddress(ACTOR),
        address(_nft),
        _tokenId,
        getAssetAddress('WETH'),
        1 ether
      ),
      price: 1 ether,
      value: 0
    });

    vm.assume(IERC20(getAssetAddress('WETH')).balanceOf(_actor) == 100 ether);
    vm.assume(IERC721(address(_nft)).ownerOf(_tokenId) == address(_market));

    (DataTypes.SignBuyNow memory data, ) = _generate_signature(_actor);
    vm.expectRevert(abi.encodeWithSelector(Errors.UTokenNotAllowed.selector));
    BuyNow(_buyNow).getCalculations(address(0x001), data);
  }
}
