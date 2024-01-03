// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ILoan} from './ILoan.sol';
import '../../types/DataTypes.sol';

interface IBuyNowModule is ILoan {
  // EVENTS
  event BuyNowPayLater(
    bytes32 loanId,
    address asset,
    uint256 tokenId,
    uint256 price,
    uint256 amount
  );

  struct CalculatedDataBuyNow {
    bytes32 loanId;
    uint256 userAmountApproved;
    uint256 minAmount;
    uint256 maxAmountToBorrow;
    uint256 realCost;
  }

  function buy(
    uint256 amount,
    DataTypes.SignBuyNow calldata signBuyNow,
    DataTypes.EIP712Signature calldata sig
  ) external;

  function getCalculations(
    address underlyingAsset,
    DataTypes.SignBuyNow calldata signBuyNow
  ) external view returns (uint256, uint256);
}
