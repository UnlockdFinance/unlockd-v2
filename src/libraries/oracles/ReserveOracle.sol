// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import {IReserveOracle} from '../../interfaces/oracles/IReserveOracle.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../helpers/Errors.sol';

contract ReserveOracle is IReserveOracle {
  uint256 private constant _AGREGATOR_ADDED_EVENT_SIGNATURE =
    0xd0fba1bf19483034d35babed2c54b89fb8cbe1fac33ac43b2a36d81be7c91e79;

  address public immutable BASE_CURRENCY;
  uint256 public immutable BASE_CURRENCY_UNIT;
  address internal immutable ACL_MANAGER;
  mapping(address => AggregatorV3Interface) public _priceFeedMap;

  struct ChainlinkResponse {
    uint80 roundId;
    int256 answer;
    uint256 updatedAt;
    bool success;
  }

  modifier onlyPriceUpdater() {
    if (!IACLManager(ACL_MANAGER).isPriceUpdater(msg.sender)) revert Errors.AccessDenied();
    _;
  }

  constructor(address aclManager, address baseCurrency, uint256 baseCurrencyUnit) {
    if (baseCurrencyUnit == 0) revert Errors.InvalidAggregator();

    ACL_MANAGER = aclManager;
    BASE_CURRENCY = baseCurrency;
    BASE_CURRENCY_UNIT = baseCurrencyUnit;
  }

  /**
   * @notice add the aggregators and pricefeedkeys
   * @param priceFeedKeys the array of pricefeed keys
   * @param aggregators the array of aggregators
   *
   */
  function addAggregators(
    address[] calldata priceFeedKeys,
    address[] calldata aggregators
  ) external onlyPriceUpdater {
    uint256 length = priceFeedKeys.length;
    if (length != aggregators.length) {
      revert Errors.InvalidArrayLength();
    }
    for (uint256 i; i < length; ) {
      _addAggregator(priceFeedKeys[i], aggregators[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice adds a single aggregator on the map
   * @param priceFeedKey the pricefeed key
   * @param aggregator the aggregator to add
   *
   */
  function addAggregator(address priceFeedKey, address aggregator) external onlyPriceUpdater {
    _addAggregator(priceFeedKey, aggregator);
  }

  /**
   * @notice removes a single aggregator from the map
   * @param priceFeedKey the pricefeed key of the aggregator to remove
   *
   */
  function removeAggregator(address priceFeedKey) external onlyPriceUpdater {
    address aggregator = address(_priceFeedMap[priceFeedKey]);
    if (aggregator == address(0)) revert Errors.InvalidAggregator();
    delete _priceFeedMap[priceFeedKey];
  }

  /**
   * @notice returns an aggregator gicen a pricefeed key
   * @param priceFeedKey the pricefeed key of the aggregator to fetch
   *
   */
  function getAggregator(address priceFeedKey) public view returns (address) {
    return address(_priceFeedMap[priceFeedKey]);
  }

  /**
   * @inheritdoc IReserveOracle
   */
  function getAssetPrice(address priceFeedKey) external view override returns (uint256) {
    AggregatorV3Interface aggregator = _priceFeedMap[priceFeedKey];

    if (priceFeedKey == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    }

    if (address(aggregator) == address(0)) revert Errors.InvalidAggregator();

    ChainlinkResponse memory cl;

    try aggregator.latestRoundData() returns (
      uint80 roundId,
      int256 answer,
      uint256 /* startedAt */,
      uint256 updatedAt,
      uint80 /* answeredInRound */
    ) {
      cl.success = true;
      cl.roundId = roundId;
      cl.answer = answer;
      cl.updatedAt = updatedAt;
    } catch {
      revert Errors.InvalidLastRoundData();
    }

    if (
      cl.success == true &&
      cl.roundId != 0 &&
      cl.answer >= 0 &&
      cl.updatedAt != 0 &&
      cl.updatedAt <= block.timestamp
    ) {
      return uint256(cl.answer);
    } else {
      revert Errors.InvalidLastRoundData();
    }
  }

  /**
   * @notice returns the aggregator's latest timestamp
   * @param priceFeedKey the pricefeed key of the aggregator to fetch
   *
   */
  function getLatestTimestamp(address priceFeedKey) public view returns (uint256) {
    if (priceFeedKey == address(0)) revert Errors.InvalidPriceFeedKey();
    AggregatorV3Interface aggregator = _priceFeedMap[priceFeedKey];
    if (address(aggregator) == address(0)) revert Errors.InvalidAggregator();
    (, , , uint256 timestamp, ) = aggregator.latestRoundData();
    return timestamp;
  }

  ////////////////////////////////////////////////////////////////////////////
  // PRIVATE
  ////////////////////////////////////////////////////////////////////////////

  /**
   * @notice adds a single aggregator on the map
   * @param priceFeedKey the pricefeed key
   * @param aggregator the aggregator to add
   *
   */
  function _addAggregator(address priceFeedKey, address aggregator) internal {
    if (priceFeedKey == address(0)) revert Errors.InvalidPriceFeedKey();
    if (aggregator == address(0)) revert Errors.InvalidAggregator();
    _priceFeedMap[priceFeedKey] = AggregatorV3Interface(aggregator);

    assembly {
      // Emit the `AggregatorAdded` event
      mstore(0x00, priceFeedKey)
      mstore(0x20, aggregator)
      log1(0x00, 0x40, _AGREGATOR_ADDED_EVENT_SIGNATURE)
    }
  }
}
