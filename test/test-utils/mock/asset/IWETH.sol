// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {IERC20} from './IERC20.sol';

interface IWETH is IERC20 {
  function deposit() external payable;

  function withdraw(uint amount) external;
}
