// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IReserveOracle} from '../../interfaces/oracles/IReserveOracle.sol';
import {MathUtils} from '../math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {Errors} from '../helpers/Errors.sol';
import {DataTypes, Constants} from '../../types/DataTypes.sol';

/**
 * @title Token library
 * @author Unlockd
 * @notice Implements the logic to update the reserves state
 */
library TokenLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for uint256;
  using SafeERC20 for IERC20;

  function transferAssets(DataTypes.TokenData memory _tokenData, uint256 amount) internal {
    IERC20(_tokenData.asset).safeTransfer(_tokenData.vault, amount);
  }

  function calculateLTVInUSD(
    DataTypes.TokenData memory _tokenData,
    uint256 amount
  ) internal returns (uint256 value) {
    uint256 priceUnit = IReserveOracle(_tokenData.oracle).getAssetPrice(_tokenData.asset);
    // TODO: Calculate TVL for this coin and add the result
    value += amount * priceUnit;
  }
}
