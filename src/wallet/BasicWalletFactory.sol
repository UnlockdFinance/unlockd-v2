// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {BeaconProxy} from '@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {BasicWalletVault} from './BasicWalletVault.sol';

contract BasicWalletFactory {
  address internal immutable _walletVaultBeacon;
  address internal immutable _registry;
  address internal immutable _aclManager;

  event WalletDeployed(
    address indexed safe,
    address indexed owner,
    address indexed guard,
    address delegationOwner,
    address protocolOwner,
    address sender
  );

  /**
   * @dev Modifier that checks if the sender has Protocol ROLE
   */
  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Emergency ROLE
   */
  modifier onlyEmergency() {
    if (!IACLManager(_aclManager).isEmergencyAdmin(msg.sender)) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  constructor(address aclManager, address registry, address walletVaultBeacon) {
    _registry = registry;
    _walletVaultBeacon = walletVaultBeacon;
    _aclManager = aclManager;
  }

  /**
   * @notice Deploys a new DelegationWallet with the msg.sender as the owner.
   */
  function deploy(address) external returns (address, address, address, address) {
    return deployFor(msg.sender, address(0));
  }

  /**
   * @notice Deploys a new DelegationWallet for a given owner.
   * @param _owner - The owner's address.
   */
  function deployFor(address _owner, address) public returns (address, address, address, address) {
    address walletVaultProxy = address(new BeaconProxy(_walletVaultBeacon, new bytes(0)));
    BasicWalletVault(walletVaultProxy).initialize(_owner);

    // Save wallet
    IDelegationWalletRegistry(_registry).setWallet(
      walletVaultProxy,
      _owner,
      address(0),
      walletVaultProxy,
      walletVaultProxy,
      walletVaultProxy
    );

    emit WalletDeployed(
      walletVaultProxy,
      _owner,
      walletVaultProxy,
      walletVaultProxy,
      walletVaultProxy,
      msg.sender
    );

    return (walletVaultProxy, walletVaultProxy, walletVaultProxy, walletVaultProxy);
  }
}
