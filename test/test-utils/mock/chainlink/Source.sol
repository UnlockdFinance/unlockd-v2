// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {AggregatorV3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

contract Source is AggregatorV3Interface {
  function decimals() external pure returns (uint8) {
    return 18;
  }

  function description() external pure returns (string memory) {
    return 'MOCK';
  }

  function getRoundData(
    uint80 _roundId
  )
    external
    pure
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    _roundId;
    return (0, 1, 0, 0, 1);
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
    // 1DAI = 0.0004829 ETH
    return (0, 482900000000000, block.timestamp, block.timestamp, 1);
  }

  function version() external pure returns (uint256) {
    return 1;
  }
}
