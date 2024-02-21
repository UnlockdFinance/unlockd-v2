// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/types/DataTypes.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {BaseCore, Errors} from '../../src/libraries/base/BaseCore.sol';
import {ReserveConfiguration} from '../../src/libraries/configuration/ReserveConfiguration.sol';

// import {console} from 'forge-std/console.sol';

contract ReserveConfigurationTest is Setup {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  DataTypes.ReserveConfigurationMap internal configuration;

  function setUp() public virtual override {}

  function test_set_reserve_factor() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    uint256 reserveFactor_ = 10000;
    config.setReserveFactor(reserveFactor_);
    assertEq(config.getReserveFactor(), reserveFactor_);
    configuration = config;
  }

  function test_set_borrow_cap() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    uint256 borrowCap_ = 18719476735;
    config.setBorrowCap(borrowCap_);
    assertEq(config.getBorrowCap(), borrowCap_);
    configuration = config;
  }

  function test_set_deposit_cap() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    uint256 depositCap_ = 18719476735;
    config.setDepositCap(depositCap_);
    assertEq(config.getDepositCap(), depositCap_);
    configuration = config;
  }

  function test_set_min_cap() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    uint256 minCap_ = 1;
    config.setMinCap(minCap_);
    assertEq(config.getMinCap(), minCap_);
    configuration = config;
  }

  function test_set_decimals() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    uint256 decimals_ = 18;
    config.setDecimals(decimals_);
    assertEq(config.getDecimals(), decimals_);
    configuration = config;
  }

  function test_set_active() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    assertEq(config.getActive(), false);
    config.setActive(true);
    assertEq(config.getActive(), true);
    config.setActive(false);
    assertEq(config.getActive(), false);
  }

  function test_set_frozen() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    bool frozen_ = true;
    assertEq(config.getFrozen(), false);
    config.setFrozen(frozen_);
    assertEq(config.getFrozen(), true);
  }

  function test_set_frozen_or_active() public {
    DataTypes.ReserveConfigurationMap memory config = configuration;

    assertEq(config.getFrozen(), false);
    assertEq(config.getActive(), false);
    config.setFrozen(true);
    assertEq(config.getFrozen(), true);
    assertEq(config.getActive(), false);
    config.setActive(true);
    assertEq(config.getFrozen(), true);
    assertEq(config.getActive(), true);
  }

  function test_set_paused() internal {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    assertEq(config.getPaused(), false);
    config.setPaused(true);
    assertEq(config.getPaused(), true);
  }

  function test_set_reserve_type() internal {
    DataTypes.ReserveConfigurationMap memory config = configuration;
    assertEq(uint(config.getReserveType()), uint(Constants.ReserveType.DISABLED));
    config.setReserveType(Constants.ReserveType.ALL);
    assertEq(uint(config.getReserveType()), uint(Constants.ReserveType.ALL));
    config.setReserveType(Constants.ReserveType.STABLE);
    assertEq(uint(config.getReserveType()), uint(Constants.ReserveType.STABLE));
    config.setReserveType(Constants.ReserveType.COMMON);
    assertEq(uint(config.getReserveType()), uint(Constants.ReserveType.COMMON));
    config.setReserveType(Constants.ReserveType.SPECIAL);
    assertEq(uint(config.getReserveType()), uint(Constants.ReserveType.SPECIAL));
  }
}
