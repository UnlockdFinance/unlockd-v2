// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Script.sol';

import {Constants} from '../../src/libraries/helpers/Constants.sol';

import {Unlockd} from '../../src/protocol/Unlockd.sol';
import {DeployConfig} from '../helpers/DeployConfig.sepolia.sol';
import {DeployUToken} from '../../src/deployer/DeployUToken.sol';
import {ACLManager} from '../../src/libraries/configuration/ACLManager.sol';
import {DeployUTokenConfig} from '../../src/deployer/DeployUTokenConfig.sol';
import {ReserveOracle, IReserveOracle} from '../../src/libraries/oracles/ReserveOracle.sol';
import {Manager} from '../../src/protocol/modules/Manager.sol';

import '../helpers/DeployerHelper.sol';
import '../../test/mock/asset/FTokenERC20.sol';
import {MockAggregatorV3} from '../../test/mock/aggregator/AggregatorV3.sol';

contract DeployFakeUTokenScript is DeployerHelper {
  function run() external broadcast {
    Addresses memory addresses = _decodeJson();

    // DEPLOY TOKEN
    FTokenERC20 token = new FTokenERC20('FIL', 'FIL', 18);

    // ADD AGGREGATOR TO ORACLE
    // If it's a update we are update the registry on the protocol
    address managerAddress = Unlockd(addresses.unlockd).moduleIdToProxy(
      Constants.MODULEID__MANAGER
    );
    Manager manager = Manager(managerAddress);
    address oracle = manager.getReserveOracle();
    // Grant rol UTokenAdmin to deploy and configure
    ACLManager(addresses.aclManager).addPriceUpdater(msg.sender);
    // Update Oracle
    ReserveOracle(oracle).addAggregator(address(token), address(new MockAggregatorV3()));
    ACLManager(addresses.aclManager).removePriceUpdater(msg.sender);
    // Deploy Oracles
    DeployUTokenConfig deployerConfig = new DeployUTokenConfig(
      DeployConfig.ADMIN,
      DeployConfig.ADMIN,
      addresses.aclManager
    );

    // DebtToken
    DeployUTokenConfig.DeployDebtTokenParams memory debtParams = DeployUTokenConfig
      .DeployDebtTokenParams({decimals: 18, tokenName: 'Unlockd Debt FIL', tokenSymbol: 'UDFIL'});

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
      underlyingAsset: address(token),
      decimals: 18,
      tokenName: 'UToken FIL',
      tokenSymbol: 'UFIL',
      debtToken: debtToken,
      reserveFactor: 0,
      interestRate: interestRate
    });

    DeployUToken deployerUToken = new DeployUToken(DeployConfig.ADMIN, addresses.aclManager);
    // Grant rol UTokenAdmin to deploy and configure
    ACLManager(addresses.aclManager).addGovernanceAdmin(address(deployerUToken));
    ACLManager(addresses.aclManager).addUTokenAdmin(address(deployerUToken));
    ACLManager(addresses.aclManager).addGovernanceAdmin(msg.sender);
    ACLManager(addresses.aclManager).addUTokenAdmin(msg.sender);
    // Deploy
    addresses.uTokenTwo = deployerUToken.deploy(utokenParams);
    manager.addUToken(addresses.uTokenTwo, true);

    // Revoke Grant
    ACLManager(addresses.aclManager).removeUTokenAdmin(address(deployerUToken));
    ACLManager(addresses.aclManager).removeGovernanceAdmin(address(deployerUToken));

    ACLManager(addresses.aclManager).removeUTokenAdmin(msg.sender);
    ACLManager(addresses.aclManager).removeGovernanceAdmin(msg.sender);

    _encodeJson(addresses);
  }
}
