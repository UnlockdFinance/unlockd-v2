// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.mainnet.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

contract UpdatePermissionsScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  address internal constant newAdmin = 0xAc5b3317D065D0e9cbc8633F336Dc44D90090b25;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();
    /******************** ACLMANAGER ********************/
    require(DeployConfig.DEPLOYER == msg.sender, 'Not valid deployer');

    ACLManager aclManager = ACLManager(addresses.aclManager);

    aclManager.addGovernanceAdmin(newAdmin);
    aclManager.addUTokenAdmin(newAdmin);
    aclManager.addProtocolAdmin(newAdmin);
    aclManager.addAuctionAdmin(newAdmin);
    aclManager.addEmergencyAdmin(newAdmin);
    aclManager.addPriceUpdater(newAdmin);

    _encodeJson(addresses);
  }
}
