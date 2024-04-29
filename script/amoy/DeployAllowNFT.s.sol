// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';
import {DeployConfig} from '../helpers/DeployConfig.amoy.sol';

import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {SafeERC721} from '../../src/libraries/tokens/SafeERC721.sol';

contract DeployAllowNFTScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();
    // CryptoPunk address
    // SafeERC721 safeERC721 = new SafeERC721(DeployConfig.CRYPTOPUNK);

    ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    Manager manager = Manager(managerAddress);
    // Set the new SAFE ERC721
    // manager.setSafeERC721(address(safeERC721));
    // {
    //   manager.allowCollectionReserveType(
    //     0x6E6DF8330DF6d167F337BFd4CD0158110b8312f7,
    //     Constants.ReserveType.ALL
    //   );
    // }
  }
}
