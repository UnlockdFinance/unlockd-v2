// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

// import {IUToken, DataTypes} from '../../interfaces/tokens/IUToken.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {GenericLogic, DataTypes} from './GenericLogic.sol';

library BuyNowLogic {
  /**
   *  @dev In charge of the calculation to buy the asset to get the max Amount needed contributed by
   *  the user and the max amount to borrow by the protocol to buy the asset.
   *  @param buyData struct with the information needed to buy the asset
   */
  function calculations(
    DataTypes.SignBuyNow calldata buyData
  ) internal pure returns (uint256, uint256) {
    uint256 maxAmountToBorrow;
    // We calculate the max amount that the user can borrow based on the min price.
    maxAmountToBorrow = GenericLogic.calculateAvailableBorrows(
      buyData.marketPrice > buyData.asset.price ? buyData.asset.price : buyData.marketPrice,
      0,
      buyData.assetLtv
    );
    uint256 minAmount = buyData.marketPrice - maxAmountToBorrow;

    return (minAmount, maxAmountToBorrow);
  }
}
