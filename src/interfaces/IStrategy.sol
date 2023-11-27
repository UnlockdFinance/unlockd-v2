// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IStrategy {
  // Returns a name for this strategy
  function name() external view returns (string memory name);

  // Returns a description for this strategy
  function description() external view returns (string memory description);

  function asset() external view returns (address _asset);

  function vault() external view returns (address);

  // Returns the total value the strategy holds (principle + gain) expressed in asset token amount.
  function balanceOf(address sharesPool) external view returns (uint256 amount);

  // Returns the maximum amount that can be withdrawn
  function withdrawable(address sharesPool) external view returns (uint256 amount);

  // Function that invest on the this strategy
  function supply(address pool_, address asset_, address from, uint256 amount) external;

  // Function to withdraw specific amount
  function withdraw(address pool_, address asset_, address to, uint256 amount) external;
}
