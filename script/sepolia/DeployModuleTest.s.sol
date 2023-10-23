// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';
import {console} from 'forge-std/console.sol';
import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {DeployPeriphery} from '../../src/deployer/DeployPeriphery.sol';
import {DeployUToken} from '../../src/deployer/DeployUToken.sol';
import {DeployProtocol} from '../../src/deployer/DeployProtocol.sol';
import {DeployUTokenConfig} from '../../src/deployer/DeployUTokenConfig.sol';

import {Test} from '../../test/mock/modules/Test.sol';
import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src//protocol/modules/BuyNow.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';

contract DeployModuleTestScript is DeployerHelper {
  bytes32 public constant VERSION = '12';
  uint256 public constant MODULE_ID = 100;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    {
      ACLManager(addresses.aclManager).addProtocolAdmin(msg.sender);
      ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);

      // INSTALL

      {
        // Test testImp = new Test(MODULE_ID, VERSION);

        // Market sellImp = new Market(Constants.MODULEID__MARKET, VERSION);
        SellNow buyNowImp = new SellNow(Constants.MODULEID__SELLNOW, VERSION);
        // Install Modules
        address[] memory modules = new address[](1);
        modules[0] = address(buyNowImp);
        // modules[1] = address(buyNowImp);

        address installer = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__INSTALLER
        );
        Installer(installer).installModules(modules);
      }

      {
        DeployPeriphery deployer = new DeployPeriphery(DeployConfig.ADMIN, addresses.aclManager);

        address adapter = deployer.deployReservoirMarket(
          DeployConfig.RESERVOIR_ROUTER,
          0x0000000000000000000000000000000000000000
        );
        address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__MANAGER
        );
        Manager manager = Manager(managerAddress);
        manager.addMarketAdapters(adapter, true);

        console.log('ADAPTER', adapter);
      }

      ACLManager(addresses.aclManager).removeUTokenAdmin(msg.sender);
      ACLManager(addresses.aclManager).removeGovernanceAdmin(msg.sender);
    }
  }
}
