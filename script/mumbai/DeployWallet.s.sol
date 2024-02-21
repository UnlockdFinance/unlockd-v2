// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.mumbai.sol';

import {AllowedControllers} from '@unlockd-wallet/src/libs/allowed/AllowedControllers.sol';
import {DelegationRecipes} from '@unlockd-wallet/src/libs/recipes/DelegationRecipes.sol';

import {GuardOwner} from '@unlockd-wallet/src/libs/owners/GuardOwner.sol';
import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {ProtocolOwner} from '@unlockd-wallet/src/libs/owners/ProtocolOwner.sol';
import {TransactionGuard} from '@unlockd-wallet/src/libs/guards/TransactionGuard.sol';

import {DelegationWalletRegistry} from '@unlockd-wallet/src/DelegationWalletRegistry.sol';
import {DelegationWalletFactory} from '@unlockd-wallet/src/DelegationWalletFactory.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';

import {UpgradeableBeacon} from '@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol';

contract DeployWalletScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    require(DeployConfig.DEPLOYER == msg.sender, 'Not valid deployer');

    /******************** WALLET ********************/
    {
      address[] memory paramsAllowedControllers;
      AllowedControllers allowedControllers = new AllowedControllers(
        addresses.aclManager,
        paramsAllowedControllers
      );

      DelegationRecipes delegationRecipes = new DelegationRecipes();

      // Declare GUARD
      TransactionGuard guardImp = new TransactionGuard(DeployConfig.CRYPTOPUNK);

      // Declare implementation guard OWNER
      GuardOwner guardOwnerImpl = new GuardOwner(DeployConfig.CRYPTOPUNK, addresses.aclManager);
      // Declare implementation protocol OWNER
      ProtocolOwner protocolOwnerImpl = new ProtocolOwner(
        DeployConfig.CRYPTOPUNK,
        addresses.aclManager
      );
      // Declare implementation delegation OWNER
      DelegationOwner delegationOwnerImp = new DelegationOwner(
        DeployConfig.CRYPTOPUNK,
        address(delegationRecipes),
        address(allowedControllers),
        addresses.aclManager
      );

      // Create beacons
      UpgradeableBeacon safeGuardBeacon = new UpgradeableBeacon(address(guardImp));

      UpgradeableBeacon safeGuardOwnerBeacon = new UpgradeableBeacon(address(guardOwnerImpl));
      UpgradeableBeacon safeDelegationOwnerBeacon = new UpgradeableBeacon(
        address(delegationOwnerImp)
      );
      UpgradeableBeacon safeProtocolOwnerBeacon = new UpgradeableBeacon(address(protocolOwnerImpl));

      DelegationWalletRegistry delegationWalletRegistry = new DelegationWalletRegistry();

      DelegationWalletFactory unlockdFactory = new DelegationWalletFactory(
        DeployConfig.GNOSIS_SAFE_PROXY_FACTORY,
        DeployConfig.GNOSIS_SAFE_TEMPLATE,
        DeployConfig.COMPATIBILITY_FALLBACK_HANDLER,
        address(safeGuardBeacon),
        address(safeGuardOwnerBeacon),
        address(safeDelegationOwnerBeacon),
        address(safeProtocolOwnerBeacon),
        address(delegationWalletRegistry)
      );
      addresses.allowedControllers = address(allowedControllers);
      addresses.walletFactory = address(unlockdFactory);
      addresses.walletRegistry = address(delegationWalletRegistry);

      delegationWalletRegistry.setFactory(addresses.walletFactory);
    }
    /******************** CONFIG ********************/
    {
      if (addresses.unlockd != address(0)) {
        // If it's a update we are update the registry on the protocol
        address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__MANAGER
        );
        Manager manager = Manager(managerAddress);
        manager.setWalletRegistry(addresses.walletRegistry);
        manager.setAllowedControllers(addresses.allowedControllers);
      }
    }
    _encodeJson(addresses);
  }
}
