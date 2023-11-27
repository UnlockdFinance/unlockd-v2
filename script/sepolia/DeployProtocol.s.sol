// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';
import '../helpers/DeployerHelper.sol';

import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {Constants} from '../../src/libraries/helpers/Constants.sol';
import {Installer} from '../../src/protocol/modules/Installer.sol';

import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {DeployPeriphery} from '../../src/deployer/DeployPeriphery.sol';
import {DeployUToken} from '../../src/deployer/DeployUToken.sol';
import {DeployProtocol} from '../../src/deployer/DeployProtocol.sol';
import {DeployUTokenConfig} from '../../src/deployer/DeployUTokenConfig.sol';

import {Action} from '../../src/protocol/modules/Action.sol';
import {Auction} from '../../src/protocol/modules/Auction.sol';
import {BuyNow} from '../../src//protocol/modules/BuyNow.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';
import {SellNow} from '../../src/protocol/modules/SellNow.sol';
import {Market} from '../../src/protocol/modules/Market.sol';

contract DeployProtocolScript is DeployerHelper {
  bytes32 public constant VERSION = 0;

  function run() external broadcast onlyInChain(DeployConfig.CHAINID) {
    Addresses memory addresses = _decodeJson();

    /******************** DeployUTokenConfig ********************/
    {
      // Deploy Oracles
      DeployUTokenConfig deployerConfig = new DeployUTokenConfig(
        DeployConfig.ADMIN,
        DeployConfig.ADMIN,
        addresses.aclManager
      );

      // DebtToken
      DeployUTokenConfig.DeployDebtTokenParams memory debtParams = DeployUTokenConfig
        .DeployDebtTokenParams({
          decimals: 18,
          tokenName: 'Unlockd Debt WETH',
          tokenSymbol: 'UDWETH'
        });

      address debtToken = deployerConfig.deployDebtToken(debtParams);

      // Interes Rate
      DeployUTokenConfig.DeployInterestRateParams memory interestParams = DeployUTokenConfig
        .DeployInterestRateParams({
          optimalUtilizationRate: 1 ether,
          baseVariableBorrowRate: 1 ether,
          variableRateSlope1: 1 ether,
          variableRateSlope2: 1 ether
        });
      address interestRate = deployerConfig.deployInterestRate(interestParams);

      DeployUToken.DeployUtokenParams memory utokenParams = DeployUToken.DeployUtokenParams({
        treasury: DeployConfig.TREASURY,
        underlyingAsset: DeployConfig.WETH,
        decimals: 18,
        tokenName: 'UToken WETH',
        tokenSymbol: 'UWETH',
        strategyAddress: address(0),
        debtToken: debtToken,
        reserveFactor: 0,
        interestRate: interestRate
      });

      DeployUToken deployerUToken = new DeployUToken(DeployConfig.ADMIN, addresses.aclManager);
      // Grant rol UTokenAdmin to deploy and configure
      ACLManager(addresses.aclManager).addUTokenAdmin(address(deployerUToken));
      // Deploy
      addresses.uToken = deployerUToken.deploy(utokenParams);
      // Revoke Grant
      ACLManager(addresses.aclManager).removeUTokenAdmin(address(deployerUToken));
    }

    /******************** Deploy Periphery ********************/
    address reserveOracle;
    address adapter;
    {
      DeployPeriphery deployer = new DeployPeriphery(DeployConfig.ADMIN, addresses.aclManager);

      reserveOracle = deployer.deployReserveOracle(DeployConfig.WETH, 1 ether);
      adapter = deployer.deployReservoirMarket(
        DeployConfig.RESERVOIR_ROUTER,
        0x0000000000000000000000000000000000000000
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

      // DeployProtocol.DeployInstallParams memory params = DeployProtocol.DeployInstallParams({
      //   unlockd: addresses.unlockd,
      //   signer: DeployConfig.SIGNER,
      //   reserveOracle: reserveOracle,
      //   uTokens: listUTokens,
      //   adapters: listMarketAdapters,
      //   walletRegistry: addresses.walletRegistry
      // });
      ACLManager(addresses.aclManager).addProtocolAdmin(msg.sender);
      ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);

      // INSTALL

      {
        Manager managerImp = new Manager(Constants.MODULEID__MANAGER, VERSION);
        //   Action actionImp = new Action(Constants.MODULEID__ACTION, VERSION);
        //   Auction auctionImp = new Auction(Constants.MODULEID__AUCTION, VERSION);
        //   Market marketImp = new Market(Constants.MODULEID__MARKET, VERSION);
        //   BuyNow buyNowImp = new BuyNow(Constants.MODULEID__BUYNOW, VERSION);
        //   SellNow sellNowImp = new SellNow(Constants.MODULEID__SELLNOW, VERSION);
        //   // Install Modules
        address[] memory modules = new address[](1);
        modules[0] = address(managerImp);
        //   modules[1] = address(actionImp);
        //   modules[2] = address(auctionImp);
        //   modules[3] = address(marketImp);
        //   modules[4] = address(buyNowImp);
        //   modules[5] = address(sellNowImp);

        address installer = Unlockd(addresses.unlockd).moduleIdToProxy(
          Constants.MODULEID__INSTALLER
        );
        Installer(installer).installModules(modules);
      }

      /*** CONFIGURE PROTOCOL */
      {
        address[] memory listUTokens = new address[](1);
        listUTokens[0] = addresses.uToken;

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

        // Configure UTokens
        uint256 i = 0;
        while (i < listUTokens.length) {
          manager.addUToken(listUTokens[i], true);
          unchecked {
            ++i;
          }
        }

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
