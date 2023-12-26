// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ReserveOracle, IReserveOracle} from '../libraries/oracles/ReserveOracle.sol';
import {ReservoirAdapter} from '../protocol/adapters/ReservoirAdapter.sol';

import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';
import {ACLManager} from '../libraries/configuration/ACLManager.sol';
import {InterestRate} from '../libraries/base/InterestRate.sol';

import {Manager} from '../protocol/modules/Manager.sol';
import {Unlockd} from '../protocol/Unlockd.sol';
import {Constants} from '../libraries/helpers/Constants.sol';

import {Errors} from '../libraries/helpers/Errors.sol';

contract DeployPeriphery {
  // MAINNET
  struct DeployInstallParams {
    address unlockd;
    address reserveOracle;
    address signer;
    address walletRegistry;
    address[] uTokens;
    address[] adapters;
  }
  address internal immutable _aclManager;
  address internal immutable _adminUpdater;

  constructor(address adminUpdater, address aclManager) {
    Errors.verifyNotZero(adminUpdater);
    Errors.verifyNotZero(aclManager);

    _adminUpdater = adminUpdater;
    _aclManager = aclManager;
  }

  function deployReserveOracle(address baseAsset, uint baseUnit) external returns (address) {
    Errors.verifyNotZero(baseAsset);

    ReserveOracle reserveOracle = new ReserveOracle(_aclManager, baseAsset, baseUnit);
    return address(reserveOracle);
  }

  // Adapters

  function deployReservoirMarket(
    address reservoirRouter,
    address ethAddress
  ) external returns (address) {
    Errors.verifyNotZero(reservoirRouter);

    ReservoirAdapter impReservoir = new ReservoirAdapter(_aclManager, reservoirRouter, ethAddress);

    return address(impReservoir);
  }
}
