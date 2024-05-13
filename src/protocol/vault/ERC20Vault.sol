// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20Vault} from '../../interfaces/vault/IERC20Vault.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {BaseEmergency} from '../../libraries/base/BaseEmergency.sol';

contract ERC20Vault is IERC20Vault, BaseEmergency {
  using SafeERC20 for IERC20;

  address internal _aclManager;
  /**
   * @dev Modifier that checks if the sender has Protocol ROLE
   */
  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  constructor(address aclManager) {
    _aclManager = aclManager;
  }

  function withdraw(address underlyingAsset, uint256 amount, address to) external onlyProtocol {
    // Withdraw only protocol
    IERC20(underlyingAsset).safeTransfer(amount, to);
  }
}
