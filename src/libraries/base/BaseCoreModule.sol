// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {BaseCore} from './BaseCore.sol';
import {Errors} from '../helpers/Errors.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Constants} from '../helpers/Constants.sol';

/**
 * @title BaseCoreModule
 * @notice Base logic on each module
 * @author Unlockd
 */
contract BaseCoreModule is BaseCore {
  // public accessors common to all modules
  uint256 public immutable moduleId;
  bytes32 public immutable moduleVersion;

  constructor(uint256 moduleId_, bytes32 moduleVersion_) {
    moduleId = moduleId_;
    moduleVersion = moduleVersion_;
  }

  /**
   * @dev Modifier that checks if the sender has Protocol Admin ROLE
   */
  modifier onlyAdmin() {
    if (!IACLManager(_aclManager).isProtocolAdmin(unpackTrailingParamMsgSender())) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Governance ROLE
   */
  modifier onlyGovernance() {
    // We can create a new role for that
    if (!IACLManager(_aclManager).isGovernanceAdmin(unpackTrailingParamMsgSender())) {
      revert Errors.GovernanceAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Emergency ROLE
   */
  modifier onlyEmergency() {
    if (!IACLManager(_aclManager).isEmergencyAdmin(unpackTrailingParamMsgSender())) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has the defined ROLE, this allow us to not need to update the BaseCoreModule with each
   * new functionality
   * @param role Assigned role to check with the sender
   */
  modifier onlyRole(bytes32 role) {
    if (!IACLManager(_aclManager).hasRole(role, unpackTrailingParamMsgSender())) {
      revert Errors.RoleAccessDenied();
    }
    _;
  }

  // Accessing parameters

  /**
   * @dev Due we are using the router we need to do this thing in order to extract the real sender, by default msg.sender is the router
   */
  function unpackTrailingParamMsgSender() internal pure returns (address msgSender) {
    /// @solidity memory-safe-assembly
    assembly {
      msgSender := shr(96, calldataload(sub(calldatasize(), 40)))
    }
  }

  function unpackTrailingParams() internal pure returns (address msgSender, address proxyAddr) {
    /// @solidity memory-safe-assembly
    assembly {
      msgSender := shr(96, calldataload(sub(calldatasize(), 40)))
      proxyAddr := shr(96, calldataload(sub(calldatasize(), 20)))
    }
  }

  /**
   *  @dev Internal function that checks if the sender is an abstract wallet created by us
   *  the protocol only allow on wallet x address
   */
  function _checkHasUnlockdWallet(address msgSender) internal view {
    if (
      IDelegationWalletRegistry(_walletRegistry).getOwnerWalletAt(msgSender, 0).owner != msgSender
    ) {
      revert Errors.UnlockdWalletNotFound();
    }
  }

  function _checkUnderlyingAsset(address underlyingAsset) internal view {}
}
