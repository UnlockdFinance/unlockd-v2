// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IStrategy {
  struct StrategyConfig {
    address asset;
    address vault;
    uint256 minCap;
    uint256 percentageToInvest;
  }

  // Returns a name for this strategy
  function name() external view returns (string memory name);

  // Returns a description for this strategy
  function description() external view returns (string memory description);

  function asset() external view returns (address _asset);

  function getConfig() external view returns (StrategyConfig memory);

  // Returns the total value the strategy holds (principle + gain) expressed in asset token amount.
  function balanceOf(address sharesPool) external view returns (uint256 amount);

  // Returns the maximum amount that can be withdrawn
  function withdrawable(address sharesPool) external view returns (uint256 amount);

  // Function that invest on the this strategy
  function supply(uint256 amount_, address from_, StrategyConfig memory config) external;

  // Function to withdraw specific amount
  function withdraw(
    uint256 amount_,
    address from,
    address to,
    StrategyConfig memory config
  ) external;
}
