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
    // CryptoPunk address
    SafeERC721 safeERC721 = new SafeERC721(DeployConfig.CRYPTOPUNK);

    ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    Manager manager = Manager(managerAddress);
    // Set the new SAFE ERC721
    manager.setSafeERC721(address(safeERC721));

    // WHACHES
    // https://etherscan.io/address/0xd7AB81881c8a0A8fbfDa70072D56ac6D7b3c3EfF
    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0xd7AB81881c8a0A8fbfDa70072D56ac6D7b3c3EfF,
        true
      );
      manager.allowCollectionReserveType(
        0xd7AB81881c8a0A8fbfDa70072D56ac6D7b3c3EfF,
        Constants.ReserveType.STABLE
      );
    }

    // UNIKURA
    // https://etherscan.io/address/0xEA89a88284fF9a9A9A54F4c43Fc4efbF099e992F
    {
      AllowedControllers(addresses.allowedControllers).setCollectionAllowance(
        0xEA89a88284fF9a9A9A54F4c43Fc4efbF099e992F,
        true
      );
      manager.allowCollectionReserveType(
        0xEA89a88284fF9a9A9A54F4c43Fc4efbF099e992F,
        Constants.ReserveType.STABLE
      );
    }
  }
}
