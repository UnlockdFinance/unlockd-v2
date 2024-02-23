// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';
import {console} from 'forge-std/console.sol';
import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src//protocol/modules/BuyNow.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';

contract ExecuteScript is DeployerHelper {
  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    // Manager manager = Manager(0x9151329be2D23fdf33865cA69cf57a727fAC7706);

    // manager.emergencyActivateLoan(
    //   0x0c55e62e379946b598dc89288aae8cffe3027561c0810021286b9620684c9dff
    // );

    Auction auction = Auction(0x876B57F8C3cb8085502cFBF0E47Ca8130Ea6c021);
    uint256 result = auction.getMinBidPriceAuction(
      0x0c55e62e379946b598dc89288aae8cffe3027561c0810021286b9620684c9dff,
      0x4399b219a932066b478a6f69a79412652cf47734f64512b2895af8afaed5880f,
      1000,
      0,
      0
    );
    console.log('RESULT', result);
  }
}
