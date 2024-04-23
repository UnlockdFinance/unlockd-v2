// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {ITokenModule} from '../../interfaces/modules/ITokenModule.sol';

contract Token is BaseCoreModule, ITokenModule {
  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  function borrow(address underlyingAsset, uint256 amount) external {
    // Deposit tokens
    // Get value tokens
    // Calculate HF
    //
    // - Add liquidity for this position
    // - Borrow with this tokens
  }

  function repay() external {
    // Return assets borrowed
    // Return amount ERC20
  }

  function liquidation() external {
    // Check HF
    // Repay position and give bonus to the liquidator
    // Check HF of the position
  }
}
