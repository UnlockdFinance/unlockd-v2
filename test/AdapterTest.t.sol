// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './setups/Setup.sol';

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import {IReservoir} from '../src/interfaces/adapter/IReservoir.sol';
import {ReservoirAdapter} from '../src/protocol/adapters/ReservoirAdapter.sol';
import './mock/asset/MintableERC20.sol';

contract AdapterTests is Setup {
  // RESERVOIR MAINNET
  // address internal RESERVOIR_MAINNET = 0xC2c862322E9c97D6244a3506655DA95F05246Fd8;

  // ASSETS MAINNET
  address internal ETH_ADDRESS = 0x0000000000000000000000000000000000000000;
  address internal DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address internal WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  ReservoirData dataSellWETHCurrency;
  ReservoirData dataWETHCurrency;
  ReservoirData dataDAICurrency;

  function setUp() public virtual override {
    super.setUp();

    dataWETHCurrency = _decodeJsonReservoirData(
      './exec/buy_test_data_0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.json'
    );

    dataDAICurrency = _decodeJsonReservoirData(
      './exec/buy_test_data_0x6B175474E89094C44Da98b954EedeAC495271d0F.json'
    );

    dataSellWETHCurrency = _decodeJsonReservoirData(
      './exec/sell_test_data_0x6B175474E89094C44Da98b954EedeAC495271d0F.json'
    );
  }

  // function xtest_sell_validate_weth_test_data_owner()
  //   public
  //   useForkMainnet(dataSellWETHCurrency.blockNumber)
  // {
  //   vm.assume(
  //     IERC721(dataSellWETHCurrency.nftAsset).ownerOf(dataSellWETHCurrency.nftTokenId) ==
  //       dataSellWETHCurrency.from
  //   );
  //   vm.startPrank(dataSellWETHCurrency.from);
  //   IERC721(dataSellWETHCurrency.nftAsset).approve(
  //     dataSellWETHCurrency.approvalTo,
  //     dataSellWETHCurrency.nftTokenId
  //   );
  //   (bool sent, ) = payable(dataSellWETHCurrency.to).call{value: dataSellWETHCurrency.value}(
  //     dataSellWETHCurrency.data
  //   );
  //   assertEq(sent, true);
  //   assertNotEq(
  //     IERC721(dataSellWETHCurrency.nftAsset).ownerOf(dataSellWETHCurrency.nftTokenId),
  //     dataSellWETHCurrency.from
  //   );
  //   vm.stopPrank();
  // }

  // function test_sell_validate_weth_test_data_external()
  //   public
  //   useForkMainnet(dataSellWETHCurrency.blockNumber)
  // {
  //   vm.assume(
  //     IERC721(dataSellWETHCurrency.nftAsset).ownerOf(dataSellWETHCurrency.nftTokenId) ==
  //       dataSellWETHCurrency.from
  //   );
  //   vm.startPrank(dataSellWETHCurrency.from);
  //   IERC721(dataSellWETHCurrency.nftAsset).approve(
  //     dataSellWETHCurrency.approvalTo,
  //     dataSellWETHCurrency.nftTokenId
  //   );
  //   vm.stopPrank();
  //   address externalOwner = address(0x1);
  //   vm.deal(externalOwner, 1 ether);
  //   vm.startPrank(externalOwner);
  //   (bool sent, ) = payable(dataSellWETHCurrency.to).call{value: dataSellWETHCurrency.value}(
  //     dataSellWETHCurrency.data
  //   );
  //   assertEq(sent, true);
  //   // assertNotEq(
  //   //   IERC721(dataSellWETHCurrency.nftAsset).ownerOf(dataSellWETHCurrency.nftTokenId),
  //   //   dataSellWETHCurrency.from
  //   // );
  //   vm.stopPrank();
  // }

  // function test_buy_validate_weth_test_data() public useForkMainnet(dataWETHCurrency.blockNumber) {
  //   vm.startPrank(dataWETHCurrency.from);
  //   vm.deal(dataWETHCurrency.from, 1 ether);

  //   (bool sent, ) = payable(dataWETHCurrency.to).call{value: dataWETHCurrency.value}(
  //     dataWETHCurrency.data
  //   );
  //   assertEq(sent, true);
  //   vm.stopPrank();
  // }

  // function test_buy_validate_test_data_erc20() public {
  //   vm.startPrank(dataDAICurrency.from);
  //   vm.deal(dataDAICurrency.from, 1 ether);
  //   writeTokenBalance(dataDAICurrency.from, DAI_ADDRESS, dataDAICurrency.price);
  //   assertEq(dataDAICurrency.currency, DAI_ADDRESS);
  //   uint startBalance = IERC20(dataDAICurrency.currency).balanceOf(dataDAICurrency.from);
  //   // Step 1: We run the approval
  //   (bool sentApproval, ) = payable(dataDAICurrency.approvalTo).call{value: dataDAICurrency.value}(
  //     dataDAICurrency.approvalData
  //   );
  //   assertEq(sentApproval, true);
  //   // Step 2: We run the TX
  //   (bool sent, ) = payable(dataDAICurrency.to).call{value: dataDAICurrency.value}(
  //     dataDAICurrency.data
  //   );
  //   assertEq(sent, true);
  //   uint endBalance = IERC20(dataDAICurrency.currency).balanceOf(dataDAICurrency.from);
  //   uint spended = startBalance - endBalance;
  //   // The end balance need to be lower
  //   assertLt(endBalance, startBalance);
  //   // The price has a slippage of 5%
  //   assertLt(spended, dataDAICurrency.price);
  //   vm.stopPrank();
  // }

  // function test_buy_using_adapter_weth() public {
  //   // Creates and selects a fork, returns a fork ID
  //   ReservoirAdapter adapter = new ReservoirAdapter(
  //     RESERVOIR_MAINNET,
  //     address(_aclManager),
  //     ETH_ADDRESS
  //   );
  //   // DATA
  //   DataTypes.SignBuyNow memory bnow = DataTypes.SignBuyNow({
  //     asset: DataTypes.SignAsset({
  //       assetId: AssetLogic.assetId(dataWETHCurrency.nftAsset, dataWETHCurrency.nftTokenId),
  //       collection: dataWETHCurrency.nftAsset,
  //       tokenId: dataWETHCurrency.nftTokenId,
  //       price: dataWETHCurrency.price,
  //       nonce: 1,
  //       deadline: 0
  //     }),
  //     assetLtv: 6000,
  //     assetLiquidationThreshold: 6000,
  //     data: dataWETHCurrency.data,
  //     value: dataWETHCurrency.value,
  //     from: dataWETHCurrency.from,
  //     to: dataWETHCurrency.to,
  //     marketApproval: dataWETHCurrency.approval,
  //     underlyingAsset: dataWETHCurrency.currency,
  //     marketPrice: dataWETHCurrency.price,
  //     nonce: 1,
  //     deadline: 0
  //   });
  //   // We set the protocol on the aclManager
  //   vm.startPrank(_admin);
  //   _aclManager.setProtocol(dataWETHCurrency.from);
  //   vm.stopPrank();

  //   vm.deal(address(dataWETHCurrency.from), 1 ether);
  //   vm.startPrank(dataWETHCurrency.from);
  //   // We check only the protocol can call the adapter
  //   // We send some DAI to the adapter
  //   vm.deal(address(adapter), 1 ether);
  //   writeTokenBalance(address(adapter), WETH_ADDRESS, dataWETHCurrency.price);
  //   assertEq(dataWETHCurrency.currency, WETH_ADDRESS);
  //   uint startBalance = IERC20(WETH_ADDRESS).balanceOf(address(adapter));

  //   // We buy the asset.
  //   adapter.buy(bnow);

  //   uint endBalance = IERC20(WETH_ADDRESS).balanceOf(address(adapter));

  //   uint spended = startBalance - endBalance;
  //   // The end balance need to be lower
  //   assertLt(endBalance, startBalance);
  //   // The price has a slippage of 5%
  //   assertLt(spended, dataWETHCurrency.price);
  //   // We check if we are the new owner.
  //   assertEq(
  //     IERC721Upgradeable(dataWETHCurrency.nftAsset).ownerOf(dataWETHCurrency.nftTokenId),
  //     dataWETHCurrency.from
  //   );

  //   vm.stopPrank();
  // }
}
