// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ILoan} from './ILoan.sol';
import '../../types/DataTypes.sol';

interface IActionModule is ILoan {
  // Events

  event Borrow(
    address indexed user,
    bytes32 indexed loanId,
    uint256 amount,
    uint256 totalAssets,
    address token
  );
  event Repay(address indexed user, bytes32 indexed loanId, uint256 amount, bytes32[] assets);

  // Functions

  function borrow(
    uint256 amount,
    DataTypes.Asset[] calldata assets,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature memory sig
  ) external;

  function repay(
    uint256 amount,
    DataTypes.SignAction calldata signAction,
    DataTypes.EIP712Signature calldata sig
  ) external;

  function getLoan(bytes32 loanId) external view returns (DataTypes.Loan memory);
}
