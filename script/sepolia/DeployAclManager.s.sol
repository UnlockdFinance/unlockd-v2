// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

contract DeployACLManagerScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  // address public constant FILIPE = 0x94aBa23b9Bbfe7bb62A9eB8b1215D72b5f6F33a1;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();
    /******************** ACLMANAGER ********************/
    require(DeployConfig.DEPLOYER == msg.sender, 'Not valid deployer');

    ACLManager aclManager = new ACLManager(msg.sender);

    aclManager.addGovernanceAdmin(msg.sender);
    // Add the admin address in all the places

    aclManager.addUTokenAdmin(msg.sender);
    aclManager.addProtocolAdmin(msg.sender);
    aclManager.addGovernanceAdmin(msg.sender);
    aclManager.addAuctionAdmin(msg.sender);
    aclManager.addEmergencyAdmin(msg.sender);
    aclManager.addPriceUpdater(msg.sender);

    // aclManager.addUTokenAdmin(FILIPE);
    // aclManager.addProtocolAdmin(FILIPE);
    // aclManager.addGovernanceAdmin(FILIPE);
    // aclManager.addAuctionAdmin(FILIPE);
    // aclManager.addEmergencyAdmin(FILIPE);
    // aclManager.addPriceUpdater(FILIPE);

    addresses.aclManager = address(aclManager);
    addresses.deployer = msg.sender;

    _encodeJson(addresses);
  }
}
