// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IERC20Vault {
  function withdraw(address underlyingAsset, uint256 amount, address to) external;
}
