// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IEmergency} from '../../interfaces/IEmergency.sol';
import {Errors} from '../helpers/Errors.sol';

contract BaseEmergency is IEmergency {
  using SafeERC20 for IERC20;

  address immutable _aclManager;

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

  function emergencyWithdraw(address payable _to) external onlyEmergencyAdmin {
    (bool sent, ) = _to.call{value: address(this).balance}('');
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }

  function emergencyWithdrawERC20(address _asset, address _to) external onlyEmergencyAdmin {
    IERC20(_asset).safeTransfer(_to, IERC20(_asset).balanceOf(address(this)));
  }
}
