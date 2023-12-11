// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;
import {IMaxApyVault} from '@maxapy/interfaces/IMaxApyVault.sol';
import {IStrategy} from '../../interfaces/IStrategy.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {PercentageMath} from '../../libraries/math/PercentageMath.sol';

import {console} from 'forge-std/console.sol';

contract MaxApyStrategy is IStrategy {
  using PercentageMath for uint256;

  uint256 internal constant MAX_LOSS = 100; // 1%
  uint256 internal constant MIN_AMOUNT_TO_INVEST = 0.5 ether;
  uint256 internal constant RATIO = 3;
  address internal _asset;
  address internal _vault;
  uint256 internal _minCap;
  uint256 internal _percentageToInvest;

  constructor(address asset_, address vault_, uint256 minCap_, uint256 percentageToInvest_) {
    _asset = asset_;
    _vault = vault_;
    _minCap = minCap_;
    _percentageToInvest = percentageToInvest_;
  }

  function name() external view returns (string memory) {
    return 'MaxAPY';
  }

  // Returns a description for this strategy
  function description() external view returns (string memory) {
    return 'MaxAPY strategy';
  }

  function asset() external view returns (address) {
    return _asset;
  }

  function getConfig() external view returns (StrategyConfig memory) {
    return
      StrategyConfig({
        asset: _asset,
        vault: _vault,
        minCap: _minCap,
        percentageToInvest: _percentageToInvest
      });
  }

  // Returns the total value the strategy holds (principle + gain) expressed in asset token amount.
  function balanceOf(address owner) external view returns (uint256) {
    uint256 shares = IMaxApyVault(_vault).balanceOf(owner);
    if (shares == 0) return 0;
    return IMaxApyVault(_vault).shareValue(shares);
  }

  //////////////////////////////////////////////////////////////////
  // DELEGATED CALLS

  function calculateAmountToSupply(
    uint256 totalSupplyNotInvested,
    address from_,
    uint256 amount_
  ) external returns (uint256) {
    if (totalSupplyNotInvested < _minCap) return 0;
    uint256 investAmount = (totalSupplyNotInvested - _minCap).percentMul(_percentageToInvest);
    return investAmount > MIN_AMOUNT_TO_INVEST ? investAmount : 0;
  }

  // Function that invest on the this strategy
  function supply(address vault_, address asset_, address from_, uint256 amount_) external {
    IERC20(asset_).approve(vault_, amount_);
    IMaxApyVault(vault_).deposit(amount_, from_);
  }

  function calculateAmountToWithdraw(
    uint256 totalSupplyNotInvested_,
    address from_,
    uint256 amount_
  ) external view returns (uint256) {
    uint256 amountToWithdraw = _getAmountToWithdraw(totalSupplyNotInvested_, amount_);
    uint256 currentBalance = this.balanceOf(from_);
    if (currentBalance == 0 || amountToWithdraw == 0) return 0;
    // This logic is for recover the minCap
    if (totalSupplyNotInvested_ < _minCap) {
      uint256 amountToMinCap = _minCap - totalSupplyNotInvested_;
      uint256 updatedAmount = amountToWithdraw + amountToMinCap;
      // We check if we have liquidity on this strategy
      amountToWithdraw = currentBalance > updatedAmount ? updatedAmount : currentBalance;
    }
    return amountToWithdraw;
  }

  // Function to withdraw specific amount
  function withdraw(address vault_, address to_, uint256 amount_) external {
    IMaxApyVault(vault_).withdraw(amount_, to_, MAX_LOSS);
  }

  function _getAmountToWithdraw(
    uint256 currentSupply,
    uint256 amount
  ) internal view returns (uint256) {
    if (currentSupply == 0) return amount;
    if (currentSupply / RATIO < amount) {
      return amount;
    }
    return 0;
  }
}
