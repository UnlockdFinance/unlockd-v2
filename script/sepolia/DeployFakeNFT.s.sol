// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';
import '../helpers/DeployerHelper.sol';
import '../../test/test-utils/mock/asset/RoyalMonkey.sol';

contract DeployFakeNftsScript is DeployerHelper {
  RoyalMonkey public nft;

  function run() external broadcast {
    Addresses memory addresses = _decodeJson();
    if (addresses.mockNFT == address(0)) {
      nft = new RoyalMonkey();
    } else {
      nft = RoyalMonkey(addresses.mockNFT);
    }

    addresses.mockNFT = address(nft);

    _encodeJson(addresses);
  }
}
