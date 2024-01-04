// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20Upgradeable} from '../utils/tokens/ERC20Upgradeable.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title BaseToken
 * @notice Base ERC20 implementation
 * @author Unlockd
 *
 */
abstract contract BaseToken is ERC20Upgradeable {
  /////////////////////////////////////////
  //  CONFIGURATION
  /////////////////////////////////////////
  address internal _aclManager;
  address internal _uTokenFactory;
  uint8 internal _decimals;
  /////////////////////////////////////////
  //  Status
  /////////////////////////////////////////
  bool internal _active;
  bool internal _frozen;

  /////////////////////////////////////////
  //  MODIFIERS
  /////////////////////////////////////////

  modifier isActive() {
    if (_active == false) revert Errors.Paused();
    _;
  }

  modifier isFrozen() {
    if (_frozen == true) revert Errors.Frozen();
    _;
  }

  modifier onlyProtocol() {
    if (IACLManager(_aclManager).isProtocol(_msgSender()) == false) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  modifier onlyEmergencyAdmin() {
    if (IACLManager(_aclManager).isEmergencyAdmin(msg.sender) == false) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  modifier onlyAdmin() {
    if (IACLManager(_aclManager).isUTokenAdmin(_msgSender()) == false) {
      revert Errors.UTokenAccessDenied();
    }
    _;
  }

  modifier onlyUTokenFactory() {
    if (_uTokenFactory != _msgSender()) revert Errors.UTokenAccessDenied();
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Emergency ROLE
   */
  modifier onlyEmergency() {
    if (IACLManager(_aclManager).isEmergencyAdmin(_msgSender()) == false) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  ////////////////////////////////////////////////////7

  function __BaseToken_init(
    address aclManager_,
    address uTokenFactory_,
    uint8 decimals_,
    string calldata name_,
    string calldata symbol_
  ) internal initializer {
    _aclManager = aclManager_;
    _uTokenFactory = uTokenFactory_;
    _decimals = decimals_;
    __ERC20_init(name_, symbol_);

    // Set inital state
    _active = true;
    _frozen = false;
  }

  ////////////////////////////////////////////////////7
  // PUBLIC
  ////////////////////////////////////////////////////7

  function setActive(bool active) external onlyEmergencyAdmin {
    _active = active;
  }

  function setFrozen(bool frozen) external onlyEmergencyAdmin {
    _frozen = frozen;
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  ////////////////////////////////////////////////////7
  // PRIVATE
  ////////////////////////////////////////////////////7

  function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
    super._transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual override isFrozen isActive {
    super._mint(account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual override isFrozen {
    super._burn(account, amount);
  }
}
