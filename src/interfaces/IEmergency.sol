// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IEmergency {
  function emergencyWithdraw(address payable _to) external;

  function emergencyWithdrawERC20(address _asset, address _to) external;
}
