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
  function name() external view returns (string memory);

  // Returns a description for this strategy
  function description() external view returns (string memory);

  function asset() external view returns (address);

  function getConfig() external view returns (StrategyConfig memory);

  // Returns the total value the strategy holds (principle + gain) expressed in asset token amount.
  function balanceOf(address sharesPool) external view returns (uint256);

  function calculateAmountToSupply(address from_, uint256 amount_) external returns (uint256);

  // Function that invest on the this strategy
  function supply(address vault_, address asset_, address from_, uint256 amount_) external;

  function calculateAmountToWithdraw(
    address from_,
    uint256 amount_
  ) external view returns (uint256);

  // Function to withdraw specific amount
  function withdraw(address vault_, address to_, uint256 amount_) external;
}
