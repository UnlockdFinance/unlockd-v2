// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {console} from 'forge-std/console.sol';
import 'forge-std/Script.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import '../helpers/DeployerHelper.sol';
import '../../test/test-utils/mock/MaxApyMirror.sol';

contract DeployMaxApyScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();

    MaxApyMirror mirror = new MaxApyMirror(DeployConfig.MAXAPY);
    console.log('DEPLOY', address(mirror));
  }
}
