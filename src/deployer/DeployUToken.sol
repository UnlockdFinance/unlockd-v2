// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {UToken, IUToken} from '../protocol/UToken.sol';
import {DebtToken, IDebtToken} from '../protocol/DebtToken.sol';

import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';
import {ACLManager} from '../libraries/configuration/ACLManager.sol';
import {InterestRate} from '../libraries/base/InterestRate.sol';

contract DeployUToken {
  address internal _aclManager;
  address internal _admin;
  address internal _adminUpdater;

  struct DeployUtokenParams {
    address treasury;
    address underlyingAsset;
    address strategyAddress;
    uint256 decimals;
    string tokenName;
    string tokenSymbol;
    address interestRate;
    address debtToken;
    uint16 reserveFactor;
  }

  constructor(address admin, address aclManager) {
    _admin = admin;
    _aclManager = aclManager;
  }

  function deploy(DeployUtokenParams calldata params) external returns (address) {
    require(ACLManager(_aclManager).isUTokenAdmin(address(this)), 'NOT_UTOKEN_ADMIN');

    // UToken deployment
    UToken uTokenImplementation = new UToken();

    bytes memory data = abi.encodeWithSelector(
      IUToken.initialize.selector,
      _aclManager,
      params.treasury,
      params.underlyingAsset,
      params.interestRate,
      params.strategyAddress,
      params.debtToken,
      params.decimals,
      params.reserveFactor,
      params.tokenName,
      params.tokenSymbol
    );

    UnlockdUpgradeableProxy proxy = new UnlockdUpgradeableProxy(
      address(uTokenImplementation),
      data
    );

    //Only updateable by Admin UTOKEN

    DebtToken(params.debtToken).setUToken(address(proxy));

    return address(proxy);
  }
}
