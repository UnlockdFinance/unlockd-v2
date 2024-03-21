// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

contract DeployACLManagerScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();
    /******************** ACLMANAGER ********************/
    require(DeployConfig.DEPLOYER == msg.sender, 'Not valid deployer');

    ACLManager aclManager = new ACLManager(DeployConfig.DEPLOYER);

    aclManager.addGovernanceAdmin(DeployConfig.DEPLOYER);
    // Add the admin address in all the places

    aclManager.addUTokenAdmin(DeployConfig.DEPLOYER);
    aclManager.addProtocolAdmin(DeployConfig.DEPLOYER);
    aclManager.addGovernanceAdmin(DeployConfig.DEPLOYER);
    aclManager.addAuctionAdmin(DeployConfig.DEPLOYER);
    aclManager.addEmergencyAdmin(DeployConfig.DEPLOYER);
    aclManager.addPriceUpdater(DeployConfig.DEPLOYER);

    addresses.aclManager = address(aclManager);
    addresses.deployer = DeployConfig.DEPLOYER;

    _encodeJson(addresses);
  }
}
