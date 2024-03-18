// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';
import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {Config} from './test-utils/config/Config.sol';
import {console} from 'forge-std/console.sol';
import './test-utils/mock/asset/MintableERC20.sol';

// WALLET
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {DelegationOwner} from '@unlockd-wallet/src/libs/owners/DelegationOwner.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

// COMMON
import {DataTypes, Constants} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import {UTokenVault} from '../src/protocol/UTokenVault.sol';
import {IUTokenVault} from '../src/interfaces/IUTokenVault.sol';
// MODULES
import {Manager} from '../src/protocol/modules/Manager.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Auction, AuctionSign, IAuctionModule} from '../src/protocol/modules/Auction.sol';
import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';

contract IssueTest is Test {
  function _fork_sepolia() internal {
    Config.ChainConfig memory config = Config.getConfig(11155111);
    // Chain FORK
    uint256 chainFork = vm.createFork(config.chainName, 5429256);
    vm.selectFork(chainFork);
  }

  function setUp() public {
    // NOTHING
  }

  function test_vault_getReserveData() public {
    // Sepolia
    _fork_sepolia();
    IUTokenVault vault = IUTokenVault(0x1f2984a908451294493e354F8E9708F3B3e44b0a);
    vault.getReserveData(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
    vault.getReserveData(0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8);
    address scaledToken = vault.getScaledToken(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
    console.log('SCALED TOKEN >>> ', scaledToken);
    (bool isActiveONE, , ) = vault.getFlags(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
    console.log('IS ACTIVE >>> ', isActiveONE);
    (bool isActive, , ) = vault.getFlags(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
    console.log('IS ACTIVE >>> ', isActive);
    vault.getScaledBalanceByUser(
      0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
      0xBCE85e9874AD6859D2dD4394B86142d683A2D5b7
    );
  }
}
