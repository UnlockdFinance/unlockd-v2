// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IReservoir {
  struct ExecutionInfo {
    address module; // to
    bytes data;
    uint256 value;
  }
  struct AmountCheckInfo {
    address target;
    bytes data;
    uint256 threshold;
  }

  function execute(ExecutionInfo[] calldata executionInfos) external payable;

  function executeWithAmountCheck(
    ExecutionInfo[] calldata executionInfos,
    AmountCheckInfo calldata amountCheckInfo
  ) external payable;
}
