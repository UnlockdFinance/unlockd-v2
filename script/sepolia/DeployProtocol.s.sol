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

contract DeployProtocolScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();
    UTokenFactory _uTokenFactory;
    /******************** DeployUTokenConfig ********************/
    {
      ACLManager(addresses.aclManager).addUTokenAdmin(msg.sender);
      ACLManager(addresses.aclManager).addEmergencyAdmin(msg.sender);
      ACLManager(addresses.aclManager).addPriceUpdater(msg.sender);

      uint256 percentageToInvest = 10000; // 100%
      address _maxApyStrategy = address(
        new MaxApyStrategy(DeployConfig.WETH, DeployConfig.MAXAPY, 1 ether, percentageToInvest)
      );

      UTokenFactory uTokenFactoryImp = new UTokenFactory(addresses.aclManager);

      bytes memory data = abi.encodeWithSelector(
        UTokenFactory.initialize.selector,
        address(new ScaledToken())
      );

      address uTokenFactoryProxy = address(
        new UnlockdUpgradeableProxy(address(uTokenFactoryImp), data)
      );

      _uTokenFactory = UTokenFactory(address(uTokenFactoryProxy));
      addresses.uToken = uTokenFactoryProxy;

      // Deploy weth pool
      _uTokenFactory.createMarket(
        IUTokenFactory.CreateMarketParams({
          interestRateAddress: address(
            new InterestRate(addresses.aclManager, 1 ether, 1 ether, 1 ether, 1 ether)
          ),
          strategyAddress: _maxApyStrategy,
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

    /******************** Deploy Periphery ********************/
    address reserveOracle;
    address adapter;
    {
      // We define the base token to USDC
      reserveOracle = address(new ReserveOracle(addresses.aclManager, DeployConfig.USDC, 1 ether));
      //////////////////////////////
      // WARNING ONLY FOR TESTING
      // Add DAI to the Oracle
      // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
      Source usdcSource = new Source(8, 100000000);
      // https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd
      Source wethSource = new Source(8, 224136576100);

      ReserveOracle(reserveOracle).addAggregator(DeployConfig.WETH, address(wethSource));
      ReserveOracle(reserveOracle).addAggregator(DeployConfig.USDC, address(usdcSource));

      // DEPLOY ADAPTER RESERVOIR
      adapter = address(
        new ReservoirAdapter(
          addresses.aclManager,
          DeployConfig.RESERVOIR_ROUTER,
          0x0000000000000000000000000000000000000000
        )
      );
    }
    /******************** Deploy Protocol ********************/
    {
      DeployProtocol deployerProtocol = new DeployProtocol(
        DeployConfig.ADMIN,
        DeployConfig.ADMIN,
        addresses.aclManager
      );
      addresses.unlockd = deployerProtocol.deploy(VERSION);

      ACLManager(addresses.aclManager).setProtocol(addresses.unlockd);
      ACLManager(addresses.aclManager).addProtocolAdmin(msg.sender);
      ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);

      // INSTALL

      {
        // Install Manager MODULE

        Manager managerImp = new Manager(Constants.MODULEID__MANAGER, VERSION);
        //   // Install Modules
        address[] memory modules = new address[](1);
        modules[0] = address(managerImp);

        address installer = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__INSTALLER
        );
        Installer(installer).installModules(modules);
      }

      /*** CONFIGURE PROTOCOL */
      {
        address[] memory listMarketAdapters = new address[](1);
        listMarketAdapters[0] = adapter;

        address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__MANAGER
        );
        Manager manager = Manager(managerAddress);

        manager.setSigner(DeployConfig.SIGNER);
        manager.setReserveOracle(reserveOracle);
        manager.setWalletRegistry(addresses.walletRegistry);
        manager.setAllowedControllers(addresses.allowedControllers);
        manager.setUTokenFactory(address(_uTokenFactory));
        // Configure Adapters
        uint256 x = 0;
        while (x < listMarketAdapters.length) {
          manager.addMarketAdapters(listMarketAdapters[x], true);
          unchecked {
            ++x;
          }
        }
      }

      ACLManager(addresses.aclManager).removeUTokenAdmin(msg.sender);
      ACLManager(addresses.aclManager).removeGovernanceAdmin(msg.sender);
    }

    _encodeJson(addresses);
  }
}
