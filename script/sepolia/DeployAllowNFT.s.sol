// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {SafeERC721} from '../../src/libraries/tokens/SafeERC721.sol';
import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import '../helpers/DeployerHelper.sol';

contract DeployAllowNFTScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();

    ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    Manager manager = Manager(managerAddress);

    // CryptoPunk address
    SafeERC721 safeERC721 = new SafeERC721(DeployConfig.CRYPTOPUNK);

    // Set the new SAFE ERC721
    manager.setSafeERC721(address(safeERC721));

    // // WHACHES
    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0xA6a9AcFDD1F64EC324eE936344cDB1457BDbDDF0,
        true
      );
      manager.allowCollectionReserveType(
        0xA6a9AcFDD1F64EC324eE936344cDB1457BDbDDF0,
        Constants.ReserveType.STABLE
      );
    }

    // 0x388043e55a388e07A75E9A1412FE2d64e48343A5

    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0x388043e55a388e07A75E9A1412FE2d64e48343A5,
        true
      );
      manager.allowCollectionReserveType(
        0x388043e55a388e07A75E9A1412FE2d64e48343A5,
        Constants.ReserveType.STABLE
      );
    }
  }
}
