// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.mumbai.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {UTokenVault} from '../../src/protocol/UTokenVault.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';
import {MaxApyStrategy} from '../../src/protocol/strategies/MaxApy.sol';
import {WETHGateway} from '../../src/protocol/gateway/WETHGateway.sol';

import {ReservoirAdapter} from '../../src/protocol/adapters/ReservoirAdapter.sol';

import {ScaledToken} from '../../src/libraries/tokens/ScaledToken.sol';
import {IUTokenVault} from '../../src/interfaces/IUTokenVault.sol';
import {InterestRate} from '../../src/libraries/base/InterestRate.sol';
import {ReserveOracle} from '../../src/libraries/oracles/ReserveOracle.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';

import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src//protocol/modules/BuyNow.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';
// Only testing
import {Source} from '../../test/test-utils/mock/chainlink/Source.sol';

import {UnlockdUpgradeableProxy} from '../../src/libraries/proxy/UnlockdUpgradeableProxy.sol';

contract DeployPeripheryScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    /******************** STRATEGY ********************/
    {
      uint256 percentageToInvest = 10000; // 100%
      address _maxApyStrategy = address(
        new MaxApyStrategy(
          addresses.aclManager,
          DeployConfig.WETH,
          DeployConfig.MAXAPY,
          1 ether,
          percentageToInvest
        )
      );
      addresses.strategy = _maxApyStrategy;
    }

    /******************** UTokenVault ********************/
    {
      UTokenVault uTokenVaultImp = new UTokenVault(addresses.aclManager);

      bytes memory data = abi.encodeWithSelector(
        UTokenVault.initialize.selector,
        address(new ScaledToken())
      );

      address uTokenVaultProxy = address(
        new UnlockdUpgradeableProxy(address(uTokenVaultImp), data)
      );

      UTokenVault _uTokenVault = UTokenVault(uTokenVaultProxy);
      addresses.uTokenVault = uTokenVaultProxy;

      // Deploy weth pool
      _uTokenVault.createMarket(
        IUTokenVault.CreateMarketParams({
          interestRateAddress: address(
            new InterestRate(
              addresses.aclManager,
              900000000000000000000000000,
              0,
              28000000000000000000000000,
              800000000000000000000000000
            )
          ),
          strategyAddress: addresses.strategy,
          reserveFactor: 0,
          underlyingAsset: DeployConfig.WETH,
          reserveType: Constants.ReserveType.COMMON,
          decimals: 18,
          tokenName: 'UWETH',
          tokenSymbol: 'UWETH'
        })
      );

      // Deploy weth usdc
      _uTokenVault.createMarket(
        IUTokenVault.CreateMarketParams({
          interestRateAddress: address(
            new InterestRate(
              addresses.aclManager,
              900000000000000000000000000,
              0,
              60000000000000000000000000,
              600000000000000000000000000
            )
          ),
          strategyAddress: address(0),
          reserveFactor: 0,
          underlyingAsset: DeployConfig.USDC,
          reserveType: Constants.ReserveType.STABLE,
          decimals: 6,
          tokenName: 'UUSDC',
          tokenSymbol: 'UUSDC'
        })
      );

      // Activate Pools
      _uTokenVault.setActive(DeployConfig.WETH, true);
      _uTokenVault.setActive(DeployConfig.USDC, true);
    }

    {
      // We define the base token to USDC
      addresses.reserveOracle = address(
        new ReserveOracle(addresses.aclManager, DeployConfig.WETH, 1 ether)
      );
      //////////////////////////////
      // WARNING ONLY FOR TESTING
      // Add DAI to the Oracle
      // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
      // Source usdcSource = new Source(8, 100000000);
      // // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
      // Source wethSource = new Source(8, 224136576100);

      // ReserveOracle(addresses.reserveOracle).addAggregator(DeployConfig.WETH, address(wethSource));
      // ReserveOracle(addresses.reserveOracle).addAggregator(DeployConfig.USDC, address(usdcSource));

      // DEPLOY ADAPTER RESERVOIR
      addresses.adapter = address(
        new ReservoirAdapter(
          addresses.aclManager,
          DeployConfig.RESERVOIR_ROUTER,
          0x0000000000000000000000000000000000000000
        )
      );
    }
    /******************** WETHGATEWAY ********************/
    {
      WETHGateway wethGateway = new WETHGateway(DeployConfig.WETH, addresses.uTokenVault);
      addresses.wethGateway = address(wethGateway);

      if (addresses.uTokenVault != address(0)) {
        // Authorize protocol
        wethGateway.authorizeProtocol(addresses.uTokenVault);
      }
    }

    _encodeJson(addresses);
  }
}
