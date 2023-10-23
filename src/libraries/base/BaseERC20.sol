// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20Upgradeable} from '../utils/tokens/ERC20Upgradeable.sol';
import {UTokenStorage} from '../storage/UTokenStorage.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title BaseERC20
 * @notice Base ERC20 implementation
 * @author Unlockd
 *
 */
abstract contract BaseERC20 is ERC20Upgradeable, UTokenStorage {
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

  modifier onlyAdmin() {
    if (IACLManager(_aclManager).isUTokenAdmin(_msgSender()) == false) {
      revert Errors.UTokenAccessDenied();
    }
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

  function setActive(bool active) external onlyAdmin {
    _active = active;
  }

  function setFrozen(bool frozen) external onlyAdmin {
    _frozen = frozen;
  }

  function __BaseERC20_init(
    address aclManager,
    string calldata name,
    string calldata symbol
  ) internal initializer {
    _aclManager = aclManager;
    __ERC20_init(name, symbol);
    // Status of the UTOKEN
    _active = true;
    _frozen = false;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
    super._transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual override isActive isFrozen {
    super._mint(account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual override isActive {
    super._burn(account, amount);
  }
}
