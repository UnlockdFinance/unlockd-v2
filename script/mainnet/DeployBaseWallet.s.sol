// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import {DeployConfig} from '../helpers/DeployConfig.mainnet.sol';

import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {BasicWalletFactory} from '../../src/wallet/BasicWalletFactory.sol';
import {BasicWalletRegistry} from '../../src/wallet/BasicWalletRegistry.sol';
import {BasicWalletVault} from '../../src/wallet/BasicWalletVault.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

import '../helpers/DeployerHelper.sol';

contract DeployBaseWalletScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();

    AllowedControllers allowedController = AllowedControllers(addresses.allowedControllers);
    // Create Implementations
    BasicWalletVault walletImp = new BasicWalletVault(addresses.aclManager);
    // Create beacons
    UpgradeableBeacon walletBeacon = new UpgradeableBeacon(address(walletImp));

    // Create Registry
    BasicWalletRegistry walletRegistry = new BasicWalletRegistry();

    BasicWalletFactory walletFactory = new BasicWalletFactory(
      address(walletImp),
      address(walletRegistry),
      address(walletBeacon)
    );

    addresses.walletFactory = address(walletFactory);
    addresses.walletRegistry = address(walletRegistry);
    /******************** CONFIG ********************/
    walletRegistry.setFactory(address(walletFactory));

    // If it's a update we are update the registry on the protocol
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    manager.setWalletRegistry(addresses.walletRegistry);

    _encodeJson(addresses);
  }
}
