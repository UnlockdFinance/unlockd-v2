// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {UTokenFactory} from '../../src/protocol/UTokenFactory.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';
import {MaxApyStrategy} from '../../src/protocol/strategies/MaxApy.sol';
import {ReservoirAdapter} from '../../src/protocol/adapters/ReservoirAdapter.sol';

import {ScaledToken} from '../../src/libraries/tokens/ScaledToken.sol';
import {IUTokenFactory} from '../../src/interfaces/IUTokenFactory.sol';
import {InterestRate} from '../../src/libraries/base/InterestRate.sol';
import {ReserveOracle} from '../../src/libraries/oracles/ReserveOracle.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {DeployProtocol} from '../../src/deployer/DeployProtocol.sol';

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
        new MaxApyStrategy(DeployConfig.WETH, DeployConfig.MAXAPY, 1 ether, percentageToInvest)
      );
      addresses.strategy = _maxApyStrategy;
    }
    /******************** UTokenFactory ********************/
    {
      UTokenFactory uTokenFactoryImp = new UTokenFactory(addresses.aclManager);

      bytes memory data = abi.encodeWithSelector(
        UTokenFactory.initialize.selector,
        address(new ScaledToken())
      );

      address uTokenFactoryProxy = address(
        new UnlockdUpgradeableProxy(address(uTokenFactoryImp), data)
      );

      UTokenFactory _uTokenFactory = UTokenFactory(uTokenFactoryProxy);
      addresses.uTokenFactory = uTokenFactoryProxy;

      // Deploy weth pool
      _uTokenFactory.createMarket(
        IUTokenFactory.CreateMarketParams({
          interestRateAddress: address(
            new InterestRate(addresses.aclManager, 1 ether, 1 ether, 1 ether, 1 ether)
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
      _uTokenFactory.createMarket(
        IUTokenFactory.CreateMarketParams({
          interestRateAddress: address(
            new InterestRate(addresses.aclManager, 1 ether, 1 ether, 1 ether, 1 ether)
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
      _uTokenFactory.updateReserveState(DeployConfig.WETH, Constants.ReserveState.ACTIVE);
      _uTokenFactory.updateReserveState(DeployConfig.USDC, Constants.ReserveState.ACTIVE);
    }

    {
      // We define the base token to USDC
      addresses.reserveOracle = address(
        new ReserveOracle(addresses.aclManager, DeployConfig.USDC, 1 ether)
      );
      //////////////////////////////
      // WARNING ONLY FOR TESTING
      // Add DAI to the Oracle
      // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
      Source usdcSource = new Source(8, 100000000);
      // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
      Source wethSource = new Source(8, 224136576100);

      ReserveOracle(addresses.reserveOracle).addAggregator(DeployConfig.WETH, address(wethSource));
      ReserveOracle(addresses.reserveOracle).addAggregator(DeployConfig.USDC, address(usdcSource));

      // DEPLOY ADAPTER RESERVOIR
      addresses.adapter = address(
        new ReservoirAdapter(
          addresses.aclManager,
          DeployConfig.RESERVOIR_ROUTER,
          0x0000000000000000000000000000000000000000
        )
      );
    }

    _encodeJson(addresses);
  }
}
