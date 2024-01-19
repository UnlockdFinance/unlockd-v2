// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {UTokenFactory} from '../../src/protocol/UTokenFactory.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';
import {MaxApyStrategy} from '../../src/protocol/strategies/MaxApy.sol';
import {ReservoirAdapter} from '../../src/protocol/adapters/ReservoirAdapter.sol';

import {IWETHGateway} from '../../src/interfaces/IWETHGateway.sol';

import {ScaledToken} from '../../src/libraries/tokens/ScaledToken.sol';
import {IUTokenFactory} from '../../src/interfaces/IUTokenFactory.sol';
import {InterestRate} from '../../src/libraries/base/InterestRate.sol';
import {ReserveOracle} from '../../src/libraries/oracles/ReserveOracle.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {DeployProtocol} from '../../src/deployer/DeployProtocol.sol';

import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src//protocol/modules/BuyNow.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';
// Only testing
import {Source} from '../../test/test-utils/mock/chainlink/Source.sol';

import {UnlockdUpgradeableProxy} from '../../src/libraries/proxy/UnlockdUpgradeableProxy.sol';

contract DeployProtocolScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    /******************** Deploy Protocol ********************/
    {
      DeployProtocol deployerProtocol = new DeployProtocol(
        DeployConfig.ADMIN,
        DeployConfig.ADMIN,
        addresses.aclManager
      );
      addresses.unlockd = deployerProtocol.deploy(VERSION);

      ACLManager(addresses.aclManager).setProtocol(addresses.unlockd);

      {
        // Install Manager MODULE

        Manager managerImp = new Manager(Constants.MODULEID__MANAGER, VERSION);
        //   // Install Modules
        address[] memory modules = new address[](1);
        modules[0] = address(managerImp);

        address installer = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__INSTALLER
        );
        Installer(installer).installModules(modules);
      }
      // ALLOW WETHGATEWEY
      if (addresses.wethGateway != address(0)) {
        // Authorize protocol
        IWETHGateway(addresses.wethGateway).authorizeProtocol(addresses.unlockd);
      }

      /*** CONFIGURE PROTOCOL */
      {
        address[] memory listMarketAdapters = new address[](1);
        listMarketAdapters[0] = addresses.adapter;

        address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__MANAGER
        );
        Manager manager = Manager(managerAddress);

        manager.setSigner(DeployConfig.SIGNER);
        manager.setReserveOracle(addresses.reserveOracle);
        manager.setWalletRegistry(addresses.walletRegistry);
        manager.setAllowedControllers(addresses.allowedControllers);
        manager.setUTokenFactory(addresses.uTokenFactory);
        // Configure Adapters
        uint256 x = 0;
        while (x < listMarketAdapters.length) {
          manager.addMarketAdapters(listMarketAdapters[x], true);
          unchecked {
            ++x;
          }
        }
      }
    }

    _encodeJson(addresses);
  }
}
