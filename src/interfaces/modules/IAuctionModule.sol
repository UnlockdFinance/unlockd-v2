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
    address user
  );
  event AuctionOrderRedeemed(
    bytes32 indexed loanId,
    bytes32 indexed orderId,
    uint256 amountOfDebt,
    uint256 amountToPay,
    uint256 bonus,
    uint256 countBids
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

  function getAmountToReedem(
    bytes32 loanId,
    bytes32[] calldata assets
  ) external view returns (uint256, uint256, uint256);

  function getMinBidPriceAuction(
    bytes32 loanId,
    bytes32 assetId,
    uint256 assetPrice,
    uint256 aggLoanPrice,
    uint256 aggLtv
  ) external view returns (uint256);

  function getOrderAuction(bytes32 orderId) external view returns (DataTypes.Order memory);

  function redeem(
    uint256 amount,
    bytes32[] calldata assets,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external;

  function finalize(
    bool claimOnUWallet,
    bytes32 orderId,
    DataTypes.Asset calldata asset,
    DataTypes.SignAuction calldata signAuction,
    DataTypes.EIP712Signature calldata sig
  ) external;
}
