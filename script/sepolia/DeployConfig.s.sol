// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {console} from 'forge-std/console.sol';
import 'forge-std/Script.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import '../helpers/DeployerHelper.sol';
import '../../test/test-utils/mock/signature/SignatureMock.sol';

contract DeployConfigScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();

    SignatureMock sign = new SignatureMock(0x07fd350Bb866d1768b4eEb87B452F1669038FbD0);
    console.log('DEPLOY', address(sign));
  }
}
