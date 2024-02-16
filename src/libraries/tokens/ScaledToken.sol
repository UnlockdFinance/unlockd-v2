// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import {BaseToken, Errors, DataTypes} from '../base/BaseToken.sol';
import {WadRayMath} from '../math/WadRayMath.sol';

/**
 * @title ScaledToken
 * @author Unlockd
 * @notice Implements a scaled token to track the amount deposited of the user
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
    address uTokenVault,
    uint8 tokenDecimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) public initializer {
    __BaseToken_init(aclManager, uTokenVault, tokenDecimals, tokenName, tokenSymbol);
  }

  /**
   * @dev Mints scaled token to the `user` address
   * -  Only callable by the UToken
   * @param amount The amount being minted
   * @param index The variable index of the reserve
   * @return scaledAmount amount scaled
   *
   */
  function mint(
    address user,
    uint256 amount,
    uint256 index
  ) external onlyUTokenVault returns (uint256) {
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
  function burn(
    address user,
    uint256 amount,
    uint256 index
  ) external onlyUTokenVault returns (uint256) {
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
