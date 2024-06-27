// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol'; 
import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {UPolytrade} from '../../src/protocol/wrappers/UPolytrade.sol';
import {PolytradeAdapter} from '../../src/protocol/adapters/PolytradeAdapter.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';

import {UnlockdUpgradeableProxy} from '../../src/libraries/proxy/UnlockdUpgradeableProxy.sol';

contract DeployPolytradeScript is DeployerHelper {
  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    // DEPLOY WRAPPER
    UPolytrade uPolyImp = new UPolytrade(DeployConfig.POLYTRADE_WRAPPER);

    bytes memory data = abi.encodeWithSelector(
      UPolytrade.initialize.selector,
      'WUPolytrade',
      'Wrapper Unlockd Polytrade',
      addresses.aclManager
    );

    address uPolyWrapperProxy = address(
      new UnlockdUpgradeableProxy(address(uPolyImp), data)
    );

    // DEPLOY ADAPTER
    PolytradeAdapter adapter = new PolytradeAdapter(
      addresses.aclManager,
      DeployConfig.POLYTRADE_MARKET,
      0x0000000000000000000000000000000000000000
    );

    // ENABLE ADAPTER AND WRAPPER
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    Manager manager = Manager(managerAddress);
    manager.addMarketAdapters(address(adapter), true);
    manager.allowCollectionReserveType(uPolyWrapperProxy, Constants.ReserveType.ALL);
  }
}
