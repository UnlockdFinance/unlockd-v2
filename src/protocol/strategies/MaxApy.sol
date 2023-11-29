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

  // Returns the maximum amount that can be withdrawn
  function withdrawable(address sharesPool) external view returns (uint256 amount) {
    // NOTHING TO DO
  }

  //////////////////////////////////////////////////////////////////
  // DELEGATED CALLS

  // Function that invest on the this strategy
  function supply(uint256 amount_, address from_, StrategyConfig memory config) external {
    uint256 amountNotInvested = IUToken(from_).totalSupplyNotInvested();
    if (amountNotInvested > config.minCap) {
      uint256 investAmount = (amountNotInvested - config.minCap).percentMul(
        config.percentageToInvest
      );
      if (investAmount > MIN_AMOUNT_TO_INVEST) {
        IERC20(config.asset).approve(config.vault, investAmount);
        IMaxApyVault(config.vault).deposit(investAmount, from_);
      }
    }
  }

  // Function to withdraw specific amount
  function withdraw(
    uint256 amount_,
    address from_,
    address to_,
    StrategyConfig memory config
  ) external {
    uint256 currentSupply = IUToken(from_).totalSupplyNotInvested();
    uint256 amountToWithdraw = _getAmountToWithdraw(currentSupply, amount_);
    if (amountToWithdraw != 0) {
      // This logic is for recover the minCap
      if (currentSupply < config.minCap) {
        uint256 amountToMinCap = config.minCap - currentSupply;
        uint256 updatedAmount = amountToWithdraw + amountToMinCap;
        // We check if we have liquidity on this strategy
        if (this.balanceOf(from_) > updatedAmount) {
          amountToWithdraw = updatedAmount;
        }
      }
      IMaxApyVault(config.vault).withdraw(amountToWithdraw, to_, MAX_LOSS);
    }
  }

  function _getAmountToWithdraw(
    uint256 currentSupply,
    uint256 amount
  ) internal view returns (uint256) {
    if (currentSupply == 0) return 0;
    if (currentSupply / 3 < amount) {
      return amount;
    }
    return 0;
  }
}
