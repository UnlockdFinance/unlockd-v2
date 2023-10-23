// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ILoan} from './ILoan.sol';
import '../../types/DataTypes.sol';

interface ISellNowModule is ILoan {
  // EVENTS
  event FinalizeAuction(bytes32 loanId, address asset, uint256 tokenId, uint256 amount);

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
