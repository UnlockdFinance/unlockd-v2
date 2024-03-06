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

// MODULES
import {Manager} from '../src/protocol/modules/Manager.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {Auction, AuctionSign, IAuctionModule} from '../src/protocol/modules/Auction.sol';
import {Market, MarketSign, IMarketModule} from '../src/protocol/modules/Market.sol';

// VAULT
import {UTokenVault} from '../src/protocol/UTokenVault.sol';

contract IssueTest is Test {
  function _fork_sepolia() internal {
    Config.ChainConfig memory config = Config.getConfig(11155111);
    // Chain FORK
    uint256 chainFork = vm.createFork(config.chainName, 5380000);
    vm.selectFork(chainFork);
  }

  function setUp() public {
    // NOTHING
  }

  function test_vault_getReserveData() public {
    // Sepolia
    _fork_sepolia();
    UTokenVault vault = UTokenVault(0x28038Bec841EE4CD13FD3D25AA666fE1ca22bE79);
    // vault.getReserveData(0xAC4bB3ab0bDA6f447287753b5d307D2FD20bC0A6);
    // vault.getReserveData(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
    // address scaledToken = vault.getScaledToken(0xAC4bB3ab0bDA6f447287753b5d307D2FD20bC0A6);
    // console.log('SCALED TOKEN', scaledToken);
    // vault.getScaledBalanceByUser(
    //   0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
    //   0xBCE85e9874AD6859D2dD4394B86142d683A2D5b7
    // );
  }
}
