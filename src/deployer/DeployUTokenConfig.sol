// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

// import {DebtToken, IDebtToken} from '../protocol/DebtToken.sol';
// import {UToken, IUToken} from '../protocol/UToken.sol';
import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';
import {ACLManager} from '../libraries/configuration/ACLManager.sol';
import {InterestRate} from '../libraries/base/InterestRate.sol';

contract DeployUTokenConfig {
  address internal _aclManager;
  address internal _admin;
  address internal _adminUpdater;

  struct DeployInterestRateParams {
    uint256 optimalUtilizationRate;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  struct DeployDebtTokenParams {
    uint256 decimals;
    string tokenName;
    string tokenSymbol;
  }

  constructor(address admin, address adminUpdater, address aclManager) {
    _admin = admin;
    _adminUpdater = adminUpdater;
    _aclManager = aclManager;
  }

  function deployInterestRate(DeployInterestRateParams calldata params) external returns (address) {
    // Interest Rate
    InterestRate interestRate = new InterestRate(
      _adminUpdater,
      params.optimalUtilizationRate,
      params.baseVariableBorrowRate,
      params.variableRateSlope1,
      params.variableRateSlope2
    );
    return address(interestRate);
  }

  function deployDebtToken(DeployDebtTokenParams calldata params) external pure returns (address) {
    params;
    // DebtToken impDebtToken = new DebtToken();
    // bytes memory debtData = abi.encodeWithSelector(
    //   IDebtToken.initialize.selector,
    //   _aclManager,
    //   params.decimals,
    //   params.tokenName,
    //   params.tokenSymbol
    // );

    // UnlockdUpgradeableProxy proxy = new UnlockdUpgradeableProxy(address(impDebtToken), debtData);
    return address(0);
  }
}
