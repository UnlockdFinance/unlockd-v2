// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import '../../types/DataTypes.sol';

interface IMarketModule {
  event MarketCreated(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    address collection,
    uint256 tokenId
  );
  event MarketBid(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    uint256 amountToPay,
    uint256 amountOfDebt,
    uint256 amount,
    address user
  );

  event MarketClaim(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    uint256 amount,
    address user
  );

  event MarketBuyNow(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    uint256 amount,
    address user
  );

  event MarketCancelBid(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    uint256 amount,
    address user
  );

  event MarketCancelAuction(bytes32 indexed loanId, bytes32 indexed orderId, address owner);

  struct CreateOrderInput {
    uint128 startAmount;
    uint128 endAmount;
    uint40 startTime;
    uint40 endTime;
    uint128 debtToSell;
  }
}
