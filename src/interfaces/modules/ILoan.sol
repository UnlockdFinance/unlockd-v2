// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import '../../types/DataTypes.sol';

interface ILoan {
  /**
   * @dev Emitted when a loan is created
   * @param user The address initiating the action
   */
  event LoanCreated(
    address indexed user,
    uint256 indexed loanId,
    uint256 totalAssets,
    uint256 amount,
    uint256 borrowIndex
  );
}
