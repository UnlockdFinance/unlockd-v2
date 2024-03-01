// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IEmergency} from '../../interfaces/IEmergency.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title BaseEmergency
 * @notice Base logic to recover funds
 * @author Unlockd
 */
contract BaseEmergency is IEmergency {
  using SafeERC20 for IERC20;

  address immutable _aclManager;
  /**
   * @dev Modifier that checks if the sender has Protocol Emergency Admin ROLE
   */
  modifier onlyEmergencyAdmin() {
    if (!IACLManager(_aclManager).isEmergencyAdmin(msg.sender)) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  constructor(address aclManager) {
    if (aclManager == address(0)) revert Errors.ZeroAddress();
    _aclManager = aclManager;
  }

  /**
   * @dev Execute emegency native withdraw, only executable by the emergency admin
   * @param _to address to send the amount
   */
  function emergencyWithdraw(address payable _to) external onlyEmergencyAdmin {
    (bool sent, ) = _to.call{value: address(this).balance}('');
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }

  /**
   * @dev Execute emegency ERC20 withdraw, only executable by the emergency admin
   * @param _to address to send the amount
   */
  function emergencyWithdrawERC20(address _asset, address _to) external onlyEmergencyAdmin {
    IERC20(_asset).safeTransfer(_to, IERC20(_asset).balanceOf(address(this)));
  }
}
