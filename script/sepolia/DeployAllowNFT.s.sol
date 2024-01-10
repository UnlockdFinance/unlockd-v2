// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import '../helpers/DeployerHelper.sol';

contract DeployAllowNFTScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();

    ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    Manager manager = Manager(managerAddress);

    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0x4Ac593920D734BE24250cb0bfAC39DF621C6e636,
        true
      );

      manager.allowCollectiononReserveType(
        0x4Ac593920D734BE24250cb0bfAC39DF621C6e636,
        Constants.ReserveType.ALL
      );
    }

    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0x720b094Ab68D7306d1545AD615fDE974fA6D86D9,
        true
      );
      manager.allowCollectiononReserveType(
        0x720b094Ab68D7306d1545AD615fDE974fA6D86D9,
        Constants.ReserveType.ALL
      );
    }

    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0x876252A90E1CfEF75b40E235629a2E67BC7E68A8,
        true
      );
      manager.allowCollectiononReserveType(
        0x876252A90E1CfEF75b40E235629a2E67BC7E68A8,
        Constants.ReserveType.ALL
      );
    }

    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0x1750D2e6f2Fb7FdD6a751833F55007cF76Fbb358,
        true
      );
      manager.allowCollectiononReserveType(
        0x1750D2e6f2Fb7FdD6a751833F55007cF76Fbb358,
        Constants.ReserveType.ALL
      );
    }
    // MOCK NFT
    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0x9cD69C4154557455F19B1ff94e9f9BbD8f802753,
        true
      );
      manager.allowCollectiononReserveType(
        0x9cD69C4154557455F19B1ff94e9f9BbD8f802753,
        Constants.ReserveType.ALL
      );
    }
    ACLManager(addresses.aclManager).removeGovernanceAdmin(msg.sender);
  }
}
