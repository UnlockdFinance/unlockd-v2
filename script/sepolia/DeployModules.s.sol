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

import {Test} from '../../test/test-utils/mock/modules/Test.sol';
import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src//protocol/modules/BuyNow.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';

contract DeployModulesScript is DeployerHelper {
  bytes32 public constant VERSION = '13';
  uint256 public constant MODULE_ID = 100;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    {
      // INSTALL

      {
        Action moduleImp1 = new Action(Constants.MODULEID__ACTION, VERSION);
        Auction moduleImp2 = new Auction(Constants.MODULEID__AUCTION, VERSION);
        BuyNow moduleImp3 = new BuyNow(Constants.MODULEID__BUYNOW, VERSION);
        SellNow moduleImp4 = new SellNow(Constants.MODULEID__SELLNOW, VERSION);
        Market moduleImp5 = new Market(Constants.MODULEID__MARKET, VERSION);

        // Install Modules
        address[] memory modules = new address[](5);
        modules[0] = address(moduleImp1);
        modules[1] = address(moduleImp2);
        modules[2] = address(moduleImp3);
        modules[3] = address(moduleImp4);
        modules[4] = address(moduleImp5);

        address installer = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__INSTALLER
        );
        Installer(installer).installModules(modules);
      }
    }
  }
}
