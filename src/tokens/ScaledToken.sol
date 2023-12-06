// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

import {BaseToken, Errors, DataTypes} from '../libraries/base/BaseToken.sol';
import {IUToken} from '../interfaces/tokens/IUToken.sol';
import {IDebtToken} from '../interfaces/tokens/IDebtToken.sol';

import {WadRayMath} from '../libraries/math/WadRayMath.sol';

/**
 * @title ScaledToken
 * @notice Implements a scaled token to track the amount deposited of the user
 * @author Unlockd
 *
 */
contract ScaledToken is BaseToken, UUPSUpgradeable {
  using WadRayMath for uint256;

  /**
   * @dev Initializes the scaled token.
   * @param aclManager ACLManager aclManager
   * @param tokenDecimals The decimals of the ScaledToken, same as the underlying asset's
   * @param tokenName The name of the token
   * @param tokenSymbol The symbol of the token
   */
  function initialize(
    address aclManager,
    uint8 tokenDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) public initializer {
    __BaseToken_init(aclManager, tokenDecimals, tokenName, tokenSymbol);
  }

  /**
   * @dev Mints scaled token to the `user` address
   * -  Only callable by the UToken
   * @param amount The amount being minted
   * @param index The variable index of the reserve
   * @return scaledAmount amount scaled
   *
   */
  function mint(address user, uint256 amount, uint256 index) external onlyUToken returns (uint256) {
    // index is expressed in Ray, so:
    uint256 amountScaled = amount.rayDiv(index);
    if (amountScaled == 0) {
      revert Errors.InvalidAmount();
    }
    super._mint(user, amountScaled);
    return amountScaled;
  }

  /**
   * @dev Burns user sharedToken
   * -  Only callable by the UToken
   * @param user The user whose is getting burned
   * @param amount The amount getting burned
   * @param index The variable index of the reserve
   * @return scaledAmount amount scaled
   *
   */
  function burn(address user, uint256 amount, uint256 index) external onlyUToken returns (uint256) {
    uint256 amountScaled = amount.rayDiv(index);
    if (amountScaled == 0) {
      revert Errors.InvalidAmount();
    }
    super._burn(user, amountScaled);
    return amountScaled;
  }

  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyAdmin {}
}
