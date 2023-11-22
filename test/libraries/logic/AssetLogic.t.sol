// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {stdStorage, StdStorage, Test, Vm, console} from 'forge-std/Test.sol';
import '../../test-utils/base/Base.sol';
import {AssetLogic, DataTypes} from '../../../src/libraries/logic/AssetLogic.sol';

contract TestLib {
  function getHash(DataTypes.SignAsset calldata signAsset) public pure returns (bytes32) {
    return AssetLogic.getAssetStructHash(1, signAsset);
  }
}

contract AssetLogicTest is Base {
  bytes32 internal constant TYPEHASH =
    0x952d72a21d7cc0fcc1bc09ed86fbffc8c63ecf57742377a17e9461f7a2d704fd;
  TestLib test;

  // *************************************
  function setUp() public useFork(MAINNET) {
    // By default Mainnet
    test = new TestLib();
  }

  function test_assetLogic_getAssetStruckHash_ok() public {
    vm.startPrank(makeAddr('alice'));
    DataTypes.SignAsset memory data = DataTypes.SignAsset({
      assetId: 0x8a72e222b30f0e57c11ec223b05d97af19a8e9576591b24c4e7ef523be567f39,
      collection: makeAddr('fake_collection'),
      tokenId: 1,
      price: 1 ether,
      nonce: 2,
      deadline: block.number + 10000
    });
    bytes32 hash = test.getHash(data);

    vm.stopPrank();
    assertEq(0x98adde490d45f4c48ac000080f42178ae893b3d394ae1759b8a913f855c5015d, hash);
  }

  function test_assetLogic_getAssetStruckHash_correct_hash() public {
    assertEq(AssetLogic.TYPEHASH, TYPEHASH);
  }
}
