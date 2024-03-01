// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DataTypes, Constants} from '../../types/DataTypes.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title ReserveConfiguration library
 * @author Unlockd
 * @notice Implements the bitmap logic to handle the reserve configuration
 */
library ReserveConfiguration {
  // @dev each F is x4
  uint256 internal constant RESERVE_FACTOR_MASK =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
  uint256 internal constant BORROW_CAP_MASK     =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFF; // prettier-ignore
  uint256 internal constant DEPOSIT_CAP_MASK    =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant MIN_CAP_MASK        =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant DECIMALS_MASK       =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant ACTIVE_MASK         =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant FROZEN_MASK         =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant PAUSED_MASK         =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant RESERVE_TYPE_MASK   =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

  ///////////////////////////////////////
  // BIT POSITIONS
  /// @dev For the RESERVE_FACTOR, the start bit is 0 (up to 15), hence no bitshifting is needed

  uint256 internal constant BORROW_CAP_START_BIT_POSITION     = 16; // prettier-ignore
  uint256 internal constant DEPOSIT_CAP_START_BIT_POSITION    = 52; // prettier-ignore
  uint256 internal constant MIN_CAP_START_BIT_POSITION        = 88; // prettier-ignore

  uint256 internal constant DECIMALS_START_BIT_POSITION       = 124; // prettier-ignore

  uint256 internal constant IS_ACTIVE_START_BIT_POSITION      = 132; // prettier-ignore
  uint256 internal constant IS_FROZEN_START_BIT_POSITION      = 133; // prettier-ignore
  uint256 internal constant IS_PAUSED_START_BIT_POSITION      = 136; // prettier-ignore

  uint256 internal constant RESERVE_TYPE_START_BIT_POSITION   = 140; // prettier-ignore

  ///////////////////////////////////////
  // VALIDATIONS

  uint256 internal constant MAX_VALID_DECIMALS                = 255; // prettier-ignore
  uint256 internal constant MAX_VALID_RESERVE_FACTOR          = 65535; // prettier-ignore
  uint256 internal constant MAX_VALID_BORROW_CAP              = 68719476735; // prettier-ignore
  uint256 internal constant MAX_VALID_DEPOSIT_CAP             = 68719476735; // prettier-ignore
  uint256 internal constant MAX_VALID_MIN_CAP                 = 68719476735; // prettier-ignore

  /**
   * @notice Sets reserve factor
   * @param self The reserve configuration
   * @param reserveFactor value reserve factor
   */
  function setReserveFactor(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 reserveFactor
  ) internal pure {
    if (reserveFactor > MAX_VALID_RESERVE_FACTOR) revert Errors.InvalidReserveFactor();
    self.data = (self.data & RESERVE_FACTOR_MASK) | reserveFactor;
  }

  /**
   * @notice Gets reserve factor
   * @param self The reserve configuration
   * @return The borrow cap
   */
  function getReserveFactor(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return self.data & ~RESERVE_FACTOR_MASK;
  }

  /**
   * @notice Sets the borrow cap of the reserve
   * @param self The reserve configuration
   * @param borrowCap The borrow cap
   */
  function setBorrowCap(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 borrowCap
  ) internal pure {
    if (borrowCap > MAX_VALID_BORROW_CAP) revert Errors.InvalidMaxBorrowCap();
    self.data = (self.data & BORROW_CAP_MASK) | (borrowCap << BORROW_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the borrow cap of the reserve
   * @param self The reserve configuration
   * @return The borrow cap
   */
  function getBorrowCap(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & ~BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the supply cap of the reserve
   * @param self The reserve configuration
   * @param depositCap The supply cap
   */
  function setDepositCap(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 depositCap
  ) internal pure {
    if (depositCap > MAX_VALID_DEPOSIT_CAP) revert Errors.InvalidMaxDepositCap();
    self.data = (self.data & DEPOSIT_CAP_MASK) | (depositCap << DEPOSIT_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the supply cap of the reserve
   * @param self The reserve configuration
   * @return The deposit cap
   */
  function getDepositCap(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & ~DEPOSIT_CAP_MASK) >> DEPOSIT_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the min cap of the reserve
   * @param self The reserve configuration
   * @param minCap The supply cap
   */
  function setMinCap(DataTypes.ReserveConfigurationMap memory self, uint256 minCap) internal pure {
    if (minCap > MAX_VALID_MIN_CAP) revert Errors.InvalidMaxMinCap();
    self.data = (self.data & MIN_CAP_MASK) | (minCap << MIN_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the min cap of the reserve
   * @param self The reserve configuration
   * @return The supply cap
   */
  function getMinCap(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & ~MIN_CAP_MASK) >> MIN_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @param decimals The decimals
   */
  function setDecimals(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 decimals
  ) internal pure {
    if (decimals > MAX_VALID_DECIMALS) revert Errors.InvalidMaxDecimals();
    self.data = (self.data & DECIMALS_MASK) | (decimals << DECIMALS_START_BIT_POSITION);
  }

  /**
   * @notice Gets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @return The decimals of the asset
   */
  function getDecimals(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & ~DECIMALS_MASK) >> DECIMALS_START_BIT_POSITION;
  }

  /**
   * @notice Sets the active state of the reserve
   * @param self The reserve configuration
   * @param active The active state
   */
  function setActive(DataTypes.ReserveConfigurationMap memory self, bool active) internal pure {
    self.data =
      (self.data & ACTIVE_MASK) |
      (uint256(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
  }

  /**
   * @notice Gets the active state of the reserve
   * @param self The reserve configuration
   * @return The active state
   */
  function getActive(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
    return (self.data & ~ACTIVE_MASK) != 0;
  }

  /**
   * @notice Sets the frozen state of the reserve
   * @param self The reserve configuration
   * @param frozen The frozen state
   */
  function setFrozen(DataTypes.ReserveConfigurationMap memory self, bool frozen) internal pure {
    self.data =
      (self.data & FROZEN_MASK) |
      (uint256(frozen ? 1 : 0) << IS_FROZEN_START_BIT_POSITION);
  }

  /**
   * @notice Gets the frozen state of the reserve
   * @param self The reserve configuration
   * @return The frozen state
   */
  function getFrozen(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
    return (self.data & ~FROZEN_MASK) != 0;
  }

  /**
   * @notice Sets the paused state of the reserve
   * @param self The reserve configuration
   * @param paused The paused state
   */
  function setPaused(DataTypes.ReserveConfigurationMap memory self, bool paused) internal pure {
    self.data =
      (self.data & PAUSED_MASK) |
      (uint256(paused ? 1 : 0) << IS_PAUSED_START_BIT_POSITION);
  }

  /**
   * @notice Gets the paused state of the reserve
   * @param self The reserve configuration
   * @return The paused state
   */
  function getPaused(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
    return (self.data & ~PAUSED_MASK) != 0;
  }

  /**
   * @notice Sets the reserve type of the reserve
   * @param self The reserve configuration
   * @param reserveType type of the reserve
   */
  function setReserveType(
    DataTypes.ReserveConfigurationMap memory self,
    Constants.ReserveType reserveType
  ) internal pure {
    self.data =
      (self.data & RESERVE_TYPE_MASK) |
      (uint(reserveType) << RESERVE_TYPE_START_BIT_POSITION);
  }

  /**
   * @notice Gets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @return The decimals of the asset
   */
  function getReserveType(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (Constants.ReserveType) {
    return
      Constants.ReserveType((self.data & ~RESERVE_TYPE_MASK) >> RESERVE_TYPE_START_BIT_POSITION);
  }

  /**
   * @notice Gets the caps parameters of the reserve from storage
   * @param self The reserve configuration
   * @return borrowCap The state param representing borrow cap
   * @return depositCap The state param representing supply cap.
   * @return MinCap The state param representing min cap.
   */
  function getCaps(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256, uint256, uint256) {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & ~BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION,
      (dataLocal & ~DEPOSIT_CAP_MASK) >> DEPOSIT_CAP_START_BIT_POSITION,
      (dataLocal & ~MIN_CAP_MASK) >> MIN_CAP_START_BIT_POSITION
    );
  }

  /**
   * @notice Gets the configuration flags of the reserve
   * @param self The reserve configuration
   * @return The state flag representing active
   * @return The state flag representing frozen
   * @return The state flag representing paused
   */
  function getFlags(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (bool, bool, bool) {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & ~ACTIVE_MASK) != 0,
      (dataLocal & ~FROZEN_MASK) != 0,
      (dataLocal & ~PAUSED_MASK) != 0
    );
  }
}
