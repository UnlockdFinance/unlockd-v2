// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title ACLManager
 * @notice Access Control List Manager. Main registry of system roles and permissions.
 * @author Unlockd
 */
contract ACLManager is AccessControl, IACLManager {
  // @dev address of the PROTOCOL
  address public UNLOCK_PROTOCOL;

  // @dev utoken admin in charge of updating the utoken
  bytes32 public constant override UTOKEN_ADMIN = keccak256('UTOKEN_ADMIN');
  // @dev protocol admin in charge of updating the protocol
  bytes32 public constant override PROTOCOL_ADMIN = keccak256('PROTOCOL_ADMIN');
  // @dev update the prices of the oracle
  bytes32 public constant override PRICE_UPDATER = keccak256('PRICE_UPDATER');
  // @dev check if the loans are healty and creates the auction
  bytes32 public constant override AUCTION_ADMIN = keccak256('AUCTION_ADMIN');
  // @dev block the pools and the protocol in case of a emergency
  bytes32 public constant override EMERGENCY_ADMIN = keccak256('EMERGENCY_ADMIN');
  // @dev modify the configuration of the protocol
  bytes32 public constant override GOVERNANCE_ADMIN = keccak256('GOVERNANCE_ADMIN');

  /**
   * @dev Constructor
   * @dev The ACL admin should be initialized at the addressesProvider beforehand
   * @param aclAdmin address of the general admin
   */
  constructor(address aclAdmin) {
    if (aclAdmin == address(0)) {
      revert Errors.ACLAdminZeroAddress();
    }
    _setupRole(DEFAULT_ADMIN_ROLE, aclAdmin);
  }

  /// @inheritdoc IACLManager
  function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setRoleAdmin(role, adminRole);
  }

  /// @inheritdoc IACLManager
  function setProtocol(address protocol) external onlyRole(DEFAULT_ADMIN_ROLE) {
    Errors.verifyNotZero(protocol);
    UNLOCK_PROTOCOL = protocol;
  }

  /// @inheritdoc IACLManager
  function isProtocol(address protocol) external view returns (bool) {
    return UNLOCK_PROTOCOL == protocol;
  }

  /// @inheritdoc IACLManager
  function addUTokenAdmin(address admin) external {
    grantRole(UTOKEN_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function removeUTokenAdmin(address admin) external {
    revokeRole(UTOKEN_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function isUTokenAdmin(address admin) external view returns (bool) {
    return hasRole(UTOKEN_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function addProtocolAdmin(address borrower) external {
    grantRole(PROTOCOL_ADMIN, borrower);
  }

  /// @inheritdoc IACLManager
  function removeProtocolAdmin(address borrower) external {
    revokeRole(PROTOCOL_ADMIN, borrower);
  }

  /// @inheritdoc IACLManager
  function isAuctionAdmin(address borrower) external view returns (bool) {
    return hasRole(PROTOCOL_ADMIN, borrower);
  }

  /// @inheritdoc IACLManager
  function addAuctionAdmin(address borrower) external {
    grantRole(PROTOCOL_ADMIN, borrower);
  }

  /// @inheritdoc IACLManager
  function removeAuctionAdmin(address borrower) external {
    revokeRole(PROTOCOL_ADMIN, borrower);
  }

  /// @inheritdoc IACLManager
  function isProtocolAdmin(address protocol) external view returns (bool) {
    return hasRole(PROTOCOL_ADMIN, protocol);
  }

  /// @inheritdoc IACLManager
  function addEmergencyAdmin(address admin) external {
    grantRole(EMERGENCY_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function removeEmergencyAdmin(address admin) external {
    revokeRole(EMERGENCY_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function isEmergencyAdmin(address admin) external view returns (bool) {
    return hasRole(EMERGENCY_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function addPriceUpdater(address admin) external {
    grantRole(PRICE_UPDATER, admin);
  }

  /// @inheritdoc IACLManager
  function removePriceUpdater(address admin) external {
    revokeRole(PRICE_UPDATER, admin);
  }

  /// @inheritdoc IACLManager
  function isPriceUpdater(address admin) external view returns (bool) {
    return hasRole(PRICE_UPDATER, admin);
  }

  /// @inheritdoc IACLManager
  function addGovernanceAdmin(address admin) external {
    grantRole(GOVERNANCE_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function removeGovernanceAdmin(address admin) external {
    revokeRole(GOVERNANCE_ADMIN, admin);
  }

  /// @inheritdoc IACLManager
  function isGovernanceAdmin(address admin) external view returns (bool) {
    return hasRole(GOVERNANCE_ADMIN, admin);
  }
}
