// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/**
 *
 * @title IReserveOracle interface
 * @notice Interface for getting Reserve price oracle.
 */
interface IReserveOracle {
  event AggregatorAdded(address currencyKey, address aggregator);
  event AggregatorRemoved(address currencyKey, address aggregator);

  /**
   *
   * @dev returns the asset price in the base CURRENCY
   */
  function getAssetPrice(address asset) external view returns (uint256);
}
