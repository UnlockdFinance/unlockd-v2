// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

contract MockAggregatorV3 is AggregatorV3Interface {
  function decimals() external pure returns (uint8) {
    return 18;
  }

  function description() external pure returns (string memory) {
    return 'muuuuu';
  }

  function version() external pure returns (uint256) {
    return 1;
  }

  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (1, 1 ether, block.timestamp, block.timestamp, 1);
  }

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (1, 1 ether, block.timestamp, block.timestamp, 1);
  }
}
