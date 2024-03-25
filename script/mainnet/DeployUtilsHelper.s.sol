// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';
import {console} from 'forge-std/console.sol';
import {DeployConfig} from '../helpers/DeployConfig.mainnet.sol';
import {UnlockdHelper} from '../../src/utils/UnlockdHelper.sol';

contract DeployUtilsHelperScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    /******************** ACLMANAGER ********************/
    require(DeployConfig.DEPLOYER == msg.sender, 'Not valid deployer');

    UnlockdHelper helper = new UnlockdHelper();
    console.log('HELPER: ', address(helper));
  }
}
