// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ILoan} from './ILoan.sol';
import '../../types/DataTypes.sol';

interface ISellNowModule is ILoan {
  // EVENTS
  event ForceSellNow(
    bytes32 loanId,
    bytes32 assetId,
    address collection,
    uint256 tokenId,
    uint256 amount
  );
  event SellNow(
    bytes32 loanId,
    bytes32 assetId,
    address collection,
    uint256 tokenId,
    uint256 amount
  );

  function forzeSell(
    address marketAdapter,
    DataTypes.Asset calldata asset,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) external;

  function sell(
    address marketAdapter,
    DataTypes.Asset calldata asset,
    DataTypes.SignSellNow calldata signSellNow,
    DataTypes.EIP712Signature calldata sig
  ) external;
}
