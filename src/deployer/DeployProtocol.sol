// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';
import {ACLManager} from '../libraries/configuration/ACLManager.sol';
import {Unlockd} from '../protocol/Unlockd.sol';
import {Constants} from '../libraries/helpers/Constants.sol';
import {Installer} from '../protocol/modules/Installer.sol';

import {Action} from '../protocol/modules/Action.sol';
import {Auction} from '../protocol/modules/Auction.sol';
import {BuyNow} from '../protocol/modules/BuyNow.sol';
import {Manager} from '../protocol/modules/Manager.sol';
import {SellNow} from '../protocol/modules/SellNow.sol';
import {Market} from '../protocol/modules/Market.sol';

contract DeployProtocol {
  address internal _aclManager;
  address internal _admin;
  address internal _adminUpdater;

  struct DeployInstallParams {
    address unlockd;
    address reserveOracle;
    address signer;
    address walletRegistry;
    address[] uTokens;
    address[] adapters;
  }

  constructor(address admin, address adminUpdater, address aclManager) {
    _admin = admin;
    _adminUpdater = adminUpdater;
    _aclManager = aclManager;
  }

  function deploy(bytes32 version) external returns (address) {
    Installer impInstaller = new Installer(version);
    Unlockd unlockd = new Unlockd(_aclManager, address(impInstaller));

    return address(unlockd);
  }
}
