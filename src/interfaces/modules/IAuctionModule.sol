// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../../types/DataTypes.sol';

interface IAuctionModule {
  event Repay(address indexed user, bytes32 indexed loanId, uint256 amount, uint256 debt);
  event AuctionBid(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    uint256 amountToPay,
    uint256 amountOfDebt,
    uint256 amount,
    address user
  );

  event AuctionRedeem(bytes32 indexed loanId, uint256 indexed amount, address indexed user);

  event AuctionFinalize(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    bytes32 indexed assetId,
    uint256 debtAmount,
    uint256 amount,
    address winner,
    address owner
  );

  struct AmountToRedeemParams {
    address underlyingAsset;
    bytes32 loanId;
    address owner;
    uint256 aggLoanPrice;
    uint256 aggLtv;
    uint256 countBids;
    uint256 totalAmountBid;
    uint256 startAmount;
  }
}
