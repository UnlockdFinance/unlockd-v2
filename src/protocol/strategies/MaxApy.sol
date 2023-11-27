// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IStrategy} from '../../interfaces/IStrategy.sol';
import {IMaxApyVault} from '../../interfaces/strategies/IMaxApyVault.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {PercentageMath} from '../../libraries/math/PercentageMath.sol';

contract MaxApyStrategy is IStrategy {
  using PercentageMath for uint256;

  uint256 internal constant MAX_LOSS = 100; // 1%
  uint256 internal constant MIN_AMOUNT_TO_INVEST = 0.5 ether;

  address internal immutable _asset;
  address internal immutable _vault;
  uint256 internal immutable _minCap;
  uint256 internal immutable _percentageToInvest;

  constructor(address asset_, address vault_, uint256 minCap_, uint256 percentageToInvest_) {
    _asset = asset_;
    _vault = vault_;
    _minCap = minCap_;
    _percentageToInvest = percentageToInvest_;
  }

  function name() external view returns (string memory name) {
    return 'MaxAPY';
  }

  // Returns a description for this strategy
  function description() external view returns (string memory description) {
    return 'MaxAPY strategy';
  }

  function asset() external view returns (address _asset) {
    return _asset;
  }

  function vault() external view returns (address) {
    return _vault;
  }

  // Returns the total value the strategy holds (principle + gain) expressed in asset token amount.
  function balanceOf(address owner) external view returns (uint256 amount) {
    return IMaxApyVault(_vault).shareValue(IMaxApyVault(_vault).balanceOf(owner));
  }

  // Returns the maximum amount that can be withdrawn
  function withdrawable(address sharesPool) external view returns (uint256 amount) {
    // NOTHING TO DO
  }

  //////////////////////////////////////////////////////////////////
  // DELEGATED CALLS

  // Function that invest on the this strategy
  function supply(address vault_, address asset_, address from_, uint256 amount_) external {
    uint256 amountNotInvested = IUToken(address(this)).totalSupplyNotInvested();
    if (amountNotInvested > _minCap) {
      uint256 investAmount = (amountNotInvested - _minCap).percentMul(_percentageToInvest);
      if (investAmount > MIN_AMOUNT_TO_INVEST) {
        IERC20(asset_).approve(vault_, amount_);
        IMaxApyVault(vault_).deposit(amount_, from_);
      }
    }
  }

  // Function to withdraw specific amount
  function withdraw(address vault_, address asset_, address to, uint256 amount_) external {
    uint256 amountToWithdraw = IUToken(address(this)).totalSupplyNotInvested() / 3 < amount_
      ? amount_
      : 0;
    if (amountToWithdraw > 0) IMaxApyVault(vault_).withdraw(amount_, to, MAX_LOSS);
  }
}
