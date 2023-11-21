// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {ReserveOracle} from '../../../src/libraries/oracles/ReserveOracle.sol';
import '../../test-utils/setups/Setup.sol';

contract ReserveOracleTest is Setup {
  // Adding different feeds to test
  // ETH - USD
  address aggETHUSD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  // USDC - USD
  address aggUSDCUSD = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
  address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  // DAI - USD
  address aggDAIUSD = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
  address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  // AAVE -USD
  address aggAAVEUSD = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9;
  address AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  // ORACLE
  ReserveOracle oracle;

  // *************************************
  function setUp() public override useFork(MAINNET) {
    deploy_acl_manager();
    // IF we choose as a base usd 1
    oracle = new ReserveOracle(address(_aclManager), address(0), 1 ether);
  }

  function test_reserveOracle_addAggregators() public {
    address[] memory priceFeedKeys = new address[](2);
    priceFeedKeys[0] = WETH;
    priceFeedKeys[1] = USDC;

    address[] memory aggregators = new address[](2);
    aggregators[0] = aggETHUSD;
    aggregators[1] = aggUSDCUSD;

    hoax(_admin);
    oracle.addAggregators(priceFeedKeys, aggregators);
  }

  function test_reserveOracle_addAggregators_InvalidArrayLength() public {
    address[] memory priceFeedKeys = new address[](2);
    priceFeedKeys[0] = WETH;
    priceFeedKeys[1] = USDC;

    address[] memory aggregators = new address[](1);
    aggregators[0] = aggETHUSD;

    hoax(_admin);
    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArrayLength.selector));
    oracle.addAggregators(priceFeedKeys, aggregators);
  }

  function test_reserveOracle_addAggregator() public {
    hoax(_admin);
    oracle.addAggregator(WETH, aggETHUSD);
  }

  function test_reserveOracle_removeAggregator() public {
    test_reserveOracle_addAggregator();
    hoax(_admin);
    oracle.removeAggregator(WETH);
  }

  function test_reserveOracle_getAggregator() public {
    test_reserveOracle_addAggregators();
    assertEq(oracle.getAggregator(WETH), aggETHUSD);
  }

  function test_reserveOracle_getAssetPrice() public {
    test_reserveOracle_addAggregators();
    uint256 ethPrice = oracle.getAssetPrice(WETH);
    assertEq(ethPrice, 181944000000);
  }

  function test_reserveOracle_getAssetPrice_BASEPRICE() public {
    test_reserveOracle_addAggregators();
    uint256 usd = oracle.getAssetPrice(address(0));
    assertEq(usd, 1 ether);
  }

  function test_reserveOracle_getLatestTimestamp() public {
    test_reserveOracle_addAggregators();
    uint256 timestamp = oracle.getLatestTimestamp(WETH);
    assertEq(timestamp, 1684227347);
  }
}
