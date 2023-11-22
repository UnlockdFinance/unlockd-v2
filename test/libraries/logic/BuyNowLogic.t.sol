// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import '../../test-utils/setups/Setup.sol';

import {BuyNowLogic, DataTypes} from '../../../src/libraries/logic/BuyNowLogic.sol';

contract TestLib {
  function calculations(
    address uToken,
    DataTypes.SignBuyNow calldata buyData
  ) public view returns (uint256, uint256) {
    return BuyNowLogic.calculations(uToken, buyData);
  }
}

contract BuyNowLogicTest is Setup {
  TestLib internal test;
  address internal uToken;
  address internal uTokenWrong;

  // *************************************
  function setUp() public override useFork(MAINNET) {
    deploy_acl_manager();

    uToken = deploy_utoken(makeAsset('WETH'));
    uTokenWrong = deploy_utoken(makeAsset('DAI'));
    // By default Mainnet
    test = new TestLib();
  }

  function test_buyNow_calculations_wrong_uToken() public {
    vm.expectRevert(abi.encodeWithSelector(Errors.NotEqualUnderlyingAsset.selector));
    (uint256 minAmount, uint256 maxAmount) = test.calculations(
      uTokenWrong,
      DataTypes.SignBuyNow({
        asset: DataTypes.SignAsset({
          assetId: 0x952d72a21d7cc0fcc1bc09ed86fbffc8c63ecf57742377a17e9461f7a2d704fd,
          collection: makeAddr('fake_collection'),
          tokenId: 1,
          price: 1 ether,
          nonce: 1,
          deadline: block.number + 1000
        }),
        assetLtv: 6000,
        assetLiquidationThreshold: 6000,
        from: makeAddr('pilipe'),
        to: makeAddr('kike'),
        data: 'NO_DATA',
        value: 0,
        marketApproval: makeAddr('market_1'),
        marketPrice: 1 ether,
        underlyingAsset: getAssetAddress('WETH'),
        nonce: 1,
        deadline: block.number + 1000
      })
    );
  }

  function test_buyNow_calculations() internal {
    (uint256 minAmount, uint256 maxAmount) = test.calculations(
      uToken,
      DataTypes.SignBuyNow({
        asset: DataTypes.SignAsset({
          assetId: 0x952d72a21d7cc0fcc1bc09ed86fbffc8c63ecf57742377a17e9461f7a2d704fd,
          collection: makeAddr('fake_collection'),
          tokenId: 1,
          price: 1 ether,
          nonce: 1,
          deadline: block.number + 1000
        }),
        assetLtv: 6000,
        assetLiquidationThreshold: 6000,
        from: makeAddr('pilipe'),
        to: makeAddr('kike'),
        data: 'NO_DATA',
        value: 0,
        marketApproval: makeAddr('market_1'),
        marketPrice: 1 ether,
        underlyingAsset: getAssetAddress('WETH'),
        nonce: 1,
        deadline: block.number + 1000
      })
    );

    assertEq(minAmount, 400000000000000000);
    assertEq(maxAmount, 600000000000000000);
  }

  function test_buyNow_calculations_price_bigger() internal {
    (uint256 minAmount, uint256 maxAmount) = test.calculations(
      uToken,
      DataTypes.SignBuyNow({
        asset: DataTypes.SignAsset({
          assetId: 0x952d72a21d7cc0fcc1bc09ed86fbffc8c63ecf57742377a17e9461f7a2d704fd,
          collection: makeAddr('fake_collection'),
          tokenId: 1,
          price: 2 ether,
          nonce: 1,
          deadline: block.number + 1000
        }),
        assetLtv: 6000,
        assetLiquidationThreshold: 6000,
        from: makeAddr('pilipe'),
        to: makeAddr('kike'),
        data: 'NO_DATA',
        value: 0,
        marketApproval: makeAddr('market_1'),
        marketPrice: 1 ether,
        underlyingAsset: getAssetAddress('WETH'),
        nonce: 1,
        deadline: block.number + 1000
      })
    );

    assertEq(minAmount, 400000000000000000);
    assertEq(maxAmount, 600000000000000000);
  }

  function test_buyNow_calculations_marketprice_bigger() internal {
    (uint256 minAmount, uint256 maxAmount) = test.calculations(
      uToken,
      DataTypes.SignBuyNow({
        asset: DataTypes.SignAsset({
          assetId: 0x952d72a21d7cc0fcc1bc09ed86fbffc8c63ecf57742377a17e9461f7a2d704fd,
          collection: makeAddr('fake_collection'),
          tokenId: 1,
          price: 1 ether,
          nonce: 1,
          deadline: block.number + 1000
        }),
        assetLtv: 6000,
        assetLiquidationThreshold: 6000,
        from: makeAddr('pilipe'),
        to: makeAddr('kike'),
        data: 'NO_DATA',
        value: 0,
        marketApproval: makeAddr('market_1'),
        marketPrice: 2 ether,
        underlyingAsset: getAssetAddress('WETH'),
        nonce: 1,
        deadline: block.number + 1000
      })
    );

    assertEq(minAmount, 400000000000000000);
    assertEq(maxAmount, 600000000000000000);
  }
}
