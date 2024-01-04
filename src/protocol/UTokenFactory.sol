// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IStrategy} from '../interfaces/IStrategy.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {IUTokenFactory} from '../interfaces/IUTokenFactory.sol';
import {UFactoryStorage} from '../libraries/storage/UFactoryStorage.sol';
import {BaseEmergency} from '../libraries/base/BaseEmergency.sol';
import {MathUtils} from '../libraries/math/MathUtils.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {ReserveLogic} from '../libraries/logic/ReserveLogic.sol';
import {ScaledToken} from '../libraries/tokens/ScaledToken.sol';

import {Constants} from '../libraries/helpers/Constants.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DataTypes} from '../types/DataTypes.sol';

import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';

// import {console} from 'forge-std/console.sol';

contract UTokenFactory is UFactoryStorage, BaseEmergency, IUTokenFactory {
  using ReserveLogic for DataTypes.ReserveData;
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using WadRayMath for uint128;
  using SafeCast for uint256;

  //////////////////////////////////////////////////////

  modifier onlyProtocol() {
    if (IACLManager(_aclManager).isProtocol(msg.sender) == false) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  modifier onlyAdmin() {
    if (IACLManager(_aclManager).isUTokenAdmin(msg.sender) == false) {
      revert Errors.UTokenAccessDenied();
    }
    _;
  }

  /////////////////////////////////////////////////////

  constructor(address aclManager, address sharesTokenImp) BaseEmergency(aclManager) {
    if (sharesTokenImp == address(0)) revert Errors.ZeroAddress();

    _sharesTokenImp = sharesTokenImp;
  }

  function createMarket(IUTokenFactory.CreateMarketParams calldata params) external onlyAdmin {
    if (reserves[params.underlyingAsset].lastUpdateTimestamp != 0) {
      revert Errors.UnderlyingMarketAlreadyExist();
    }
    // Create Reserve Asset
    reserves[params.underlyingAsset].init(
      params.underlyingAsset,
      params.reserveType,
      _sharesToken(params.decimals, params.tokenName, params.tokenSymbol),
      params.interestRateAddress,
      params.strategyAddress,
      params.reserveFactor
    );
  }

  function supply(address underlyingAsset, uint256 amount, address onBehalf) external {
    Errors.verifyNotZero(underlyingAsset);
    Errors.verifyNotZero(onBehalf);
    Errors.verifyNotZero(amount);
    // Move amount to the pool
    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];

    if (reserve.reserveState != Constants.ReserveState.ACTIVE) {
      revert Errors.ReserveNotActive();
    }

    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    reserve.updateState(balance);

    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, amount, 0);

    reserve.mintScaled(balance, onBehalf, amount);

    reserve.strategyInvest(balance, amount);

    // emit Deposit(_msgSender(), _reserve.underlyingAsset, amount, onBehalf, '');
  }

  function withdraw(address underlyingAsset, uint256 amount, address onBehalf) external {
    Errors.verifyNotZero(underlyingAsset);
    Errors.verifyNotZero(onBehalf);
    Errors.verifyNotZero(amount);

    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];

    if (reserve.reserveState == Constants.ReserveState.FREEZED) {
      revert Errors.ReserveNotActive();
    }

    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    Errors.verifyNotZero(onBehalf);
    Errors.verifyNotZero(amount);

    // Check if we have enought to withdraw
    reserve.strategyWithdraw(balance, amount);

    reserve.updateState(balance);

    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, amount);

    // Burn scaled tokens
    reserve.burnScaled(balance, onBehalf, amount);
  }

  function borrow(
    address underlyingAsset,
    bytes32 loanId,
    uint256 amount,
    address to,
    address onBehalfOf
  ) external onlyProtocol {
    Errors.verifyNotZero(to);
    Errors.verifyNotZero(amount);
    Errors.verifyNotZero(onBehalfOf);

    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];

    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    if (reserve.reserveState != Constants.ReserveState.ACTIVE) {
      revert Errors.ReserveNotActive();
    }

    // Move amount to the pool
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    uint256 availableLiquidity = this.totalAvailableSupply(underlyingAsset);
    if (amount > availableLiquidity) {
      revert Errors.NotEnoughLiquidity();
    }
    // Check if we have enought to withdraw
    reserve.strategyWithdraw(balance, amount);

    reserve.updateState(balance);

    uint256 scaledAmount = reserve.increaseDebt(balance, amount);

    // Update balances
    borrowScaledBalanceByLoanId[loanId] += scaledAmount;
    borrowScaledBalanceByUser[onBehalfOf] += scaledAmount;

    IERC20(underlyingAsset).safeTransfer(to, amount);
    // Remove funds from the interest rate
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, amount);
  }

  function repay(
    address underlyingAsset,
    bytes32 loanId,
    uint256 amount,
    address from,
    address onBehalfOf
  ) external onlyProtocol {
    Errors.verifyNotZero(from);
    Errors.verifyNotZero(amount);
    Errors.verifyNotZero(onBehalfOf);

    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];

    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    if (reserve.reserveState == Constants.ReserveState.FREEZED) {
      revert Errors.ReserveNotActive();
    }

    // Move amount to the pool
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    uint256 scaledAmount = reserve.decreaseDebt(balance, amount);
    uint256 currentDebt = borrowScaledBalanceByLoanId[loanId];

    // User can't repay more thant the current debt
    if (currentDebt == 0 || currentDebt < scaledAmount) revert Errors.AmountExceedsDebt();
    // Update balances
    borrowScaledBalanceByLoanId[loanId] -= scaledAmount;
    borrowScaledBalanceByUser[onBehalfOf] -= scaledAmount;

    IERC20(underlyingAsset).safeTransferFrom(from, address(this), amount);
    reserve.updateState(balance);
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, amount, 0);
    reserve.strategyInvest(balance, amount);
  }

  /////////////////////////////////////////////////////////
  // Update
  /////////////////////////////////////////////////////////

  function updateState(address underlyingAsset) external {
    reserves[underlyingAsset].updateState(balances[underlyingAsset]);
  }

  function updateReserveState(
    address underlyingAsset,
    Constants.ReserveState reserveState
  ) external onlyEmergencyAdmin {
    reserves[underlyingAsset].reserveState = reserveState;
  }

  /////////////////////////////////////////////////////////
  // GET
  /////////////////////////////////////////////////////////

  function validateReserveType(
    Constants.ReserveType currentReserveType,
    Constants.ReserveType reserveType
  ) external pure returns (bool) {
    if (reserveType == Constants.ReserveType.DISABLED) return false;
    if (currentReserveType == reserveType) return true;

    if (
      reserveType == Constants.ReserveType.ALL &&
      currentReserveType != Constants.ReserveType.SPECIAL
    ) return true;

    return false;
  }

  function getReserveData(
    address underlyingAsset
  ) external view returns (DataTypes.ReserveData memory) {
    return reserves[underlyingAsset];
  }

  /////////////////////////////////////////////////////////
  // DEBT
  /////////////////////////////////////////////////////////
  function getTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return borrowScaledBalanceByUser[user].rayMul(reserves[underlyingAsset].getNormalizedDebt());
  }

  function getDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256) {
    return
      borrowScaledBalanceByLoanId[loanId].rayMul(reserves[underlyingAsset].getNormalizedDebt());
  }

  /////////////////////////////////////////////////////////
  // SUPPLY
  /////////////////////////////////////////////////////////

  function getBalances(
    address underlyingAsset
  ) external view returns (DataTypes.MarketBalance memory) {
    return balances[underlyingAsset];
  }

  function totalSupply(address underlyingAsset) external view returns (uint256) {
    return
      balances[underlyingAsset].totalSupplyScaled.rayMul(
        reserves[underlyingAsset].getNormalizedIncome()
      );
  }

  function totalAvailableSupply(address underlyingAsset) external view returns (uint256) {
    uint256 totalSupplyAssets = IERC20(underlyingAsset).balanceOf(address(this));
    if (reserves[underlyingAsset].strategyAddress != address(0)) {
      totalSupplyAssets += IStrategy(reserves[underlyingAsset].strategyAddress).balanceOf(
        address(this)
      );
    }
    return totalSupplyAssets;
  }

  function totalSupplyNotInvested(address underlyingAsset) external view returns (uint256) {
    // TotalSupplyNotInvested
    uint256 balance = balances[underlyingAsset].totalSupplyScaledNotInvested;
    return balance.rayMul(reserves[underlyingAsset].getNormalizedIncome());
  }

  /////////////////////////////////////////////////////////
  // INTERNAL
  /////////////////////////////////////////////////////////

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
