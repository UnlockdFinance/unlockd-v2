// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import {Errors, DataTypes, ERC20Upgradeable} from '../libraries/base/BaseERC20.sol';
// import {ReentrancyGuard} from '../libraries/utils/ReentrancyGuard.sol';
import {MathUtils} from '../libraries/math/MathUtils.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {ReserveAssetLogic} from '../libraries/logic/ReserveAssetLogic.sol';
// import {DelegateCall} from '../libraries/utils/DelegateCall.sol';
// import {IStrategy} from '../interfaces/IStrategy.sol';
import {UTokenStorage} from '../libraries/storage/UTokenStorage.sol';
import {ScaledToken} from '../tokens/ScaledToken.sol';
import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';

contract UTokenV2 {
  using ReserveAssetLogic for DataTypes.ReserveDataV2;

  using WadRayMath for uint256;

  address internal _aclManager;
  address internal _sharesTokenImp;
  // UnderlyingAsset -> Reserve
  mapping(address => DataTypes.ReserveDataV2) public reserves;
  // UnderlyingAsset -> Reserve
  mapping(address => DataTypes.MarketBalance) public balances;

  constructor(address aclManager, address sharesTokenImp) {
    if (aclManager == address(0)) revert Errors.ZeroAddress();
    if (sharesTokenImp == address(0)) revert Errors.ZeroAddress();
    _aclManager = aclManager;
    _sharesTokenImp = sharesTokenImp;
  }

  function createMarket(
    DataTypes.CreateMarketParams calldata params,
    address underlyingAsset,
    uint8 decimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external {
    if (reserves[underlyingAsset].lastUpdateTimestamp != 0) {
      revert();
    }

    // Create Reserve Asset
    reserves[underlyingAsset].init(
      underlyingAsset,
      _sharesToken(decimals, tokenName, tokenSymbol),
      params.interestRateAddress,
      params.strategyAddress,
      params.reserveFactor
    );
  }

  function supply(address underlyingAsset, uint256 amount, address onBehalf) external {
    if (reserves[underlyingAsset].lastUpdateTimestamp == 0) {
      revert();
    }
    Errors.verifyNotZero(onBehalf);
    Errors.verifyNotZero(amount);

    // Move amount to the pool
    DataTypes.ReserveDataV2 storage reserve = reserves[underlyingAsset];
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    reserve.updateState(balance);

    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, amount, 0);

    reserve.mintScaled(balance, onBehalf, amount);

    reserve.strategyInvest(balance, amount);

    // emit Deposit(_msgSender(), _reserve.underlyingAsset, amount, onBehalf, '');
  }

  function withdraw(address underlyingAsset, uint256 amount, address onBehalf) external {
    if (reserves[underlyingAsset].lastUpdateTimestamp == 0) {
      revert();
    }
    Errors.verifyNotZero(onBehalf);
    Errors.verifyNotZero(amount);

    DataTypes.ReserveDataV2 storage reserve = reserves[underlyingAsset];
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    reserve.updateState(balance);
    // Burn SHARES
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, amount);
    // Check if we have enought to withdraw
    reserve.strategyWithdraw(balance, amount);
    // Burn scaled tokens
    reserve.burnScaled(balance, onBehalf, amount);
  }

  function borrow(bytes32 loanId, uint256 amount, address to, address onBehalfOf) external {}

  function repay(bytes32 loanId, uint256 amount, address from, address onBehalfOf) external {}

  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  // function _authorizeUpgrade(address) internal override {}

  function getReserveData(
    address underlyingAsset
  ) external returns (DataTypes.ReserveDataV2 memory) {
    return reserves[underlyingAsset];
  }

  function getBalance(address underlyingAsset) external returns (DataTypes.MarketBalance memory) {
    return balances[underlyingAsset];
  }

  function totalSupplyNotInvested(address underlyingAsset) external returns (uint256) {
    // TotalSupplyNotInvested
    uint256 balance = balances[underlyingAsset].totalSupplyScaledNotInvested;
    return balance.rayMul(reserves[underlyingAsset].getNormalizedIncome());
  }

  function _sharesToken(
    uint8 decimals,
    string memory name,
    string memory symbol
  ) internal returns (address) {
    // Deploy shares token
    bytes memory data = abi.encodeWithSelector(
      ScaledToken.initialize.selector,
      _aclManager,
      decimals,
      name,
      symbol
    );

    UnlockdUpgradeableProxy scaledTokenProxy = new UnlockdUpgradeableProxy(
      address(_sharesTokenImp),
      data
    );

    return address(scaledTokenProxy);
  }
}
