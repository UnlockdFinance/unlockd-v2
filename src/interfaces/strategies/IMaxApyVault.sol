// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

/**
 * @notice MaxApyVault contains the main interface for MaxApy Vaults
 */
interface IMaxApyVault {
  /// User-facing vault functions
  function deposit(uint256 amount, address recipient) external returns (uint256);

  function withdraw(uint256 shares, address recipient, uint256 maxLoss) external returns (uint256);

  /// ERC20 Token functions
  function name() external returns (string memory);

  function symbol() external returns (string memory);

  function decimals() external returns (uint8);

  function underlyingAsset() external view returns (address);

  function totalSupply() external view returns (uint256);

  function balanceOf(address user) external view returns (uint256);

  /// Vault configuration
  function debtRatio() external returns (uint256);

  function totalDebt() external returns (uint256);

  function totalIdle() external returns (uint256);

  function withdrawalQueue(uint256 index) external returns (address);

  /// Vault view functions
  function performanceFee() external returns (uint256);

  function managementFee() external returns (uint256);

  function lockedProfitDegradation() external view returns (uint256);

  function depositLimit() external returns (uint256);

  function MAXIMUM_STRATEGIES() external returns (uint256);

  function DEGRADATION_COEFFICIENT() external view returns (uint256);

  function shareValue(uint256 shares) external view returns (uint256);

  function sharesForAmount(uint256 amount) external view returns (uint256 shares);

  function debtOutstanding(address strategy) external view returns (uint256);

  function totalAssets() external view returns (uint256);

  function lastReport() external view returns (uint256);

  function lockedProfit() external view returns (uint256);
}
