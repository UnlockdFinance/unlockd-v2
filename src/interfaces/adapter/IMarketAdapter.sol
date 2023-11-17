// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../../types/DataTypes.sol';

interface IMarketAdapter {
  ///////////////////////////////////////////////
  // STRUCTS
  ///////////////////////////////////////////////

  struct PreSellParams {
    bytes32 loanId;
    address collection;
    uint256 tokenId;
    address underlyingAsset;
    uint256 marketPrice;
    address marketApproval;
    address protocolOwner;
  }

  struct SellParams {
    address wallet;
    address protocolOwner;
    address underlyingAsset;
    uint256 marketPrice;
    address to;
    uint256 value;
    bytes data;
  }

  struct PreBuyParams {
    bytes32 loanId;
    address collection;
    uint256 tokenId;
    address underlyingAsset;
    uint256 marketPrice;
    address marketApproval;
    address protocolOwner;
  }

  struct BuyParams {
    address wallet;
    address underlyingAsset;
    uint256 marketPrice;
    address marketApproval;
    address to;
    uint256 value;
    bytes data;
  }

  function preBuy(PreBuyParams memory params) external payable;

  function buy(BuyParams memory params) external payable returns (uint256);

  function preSell(PreSellParams memory params) external payable;

  function sell(SellParams memory params) external payable;

  function withdraw(address payable _to) external;

  function withdrawERC20(address _asset, address _to) external;
}
