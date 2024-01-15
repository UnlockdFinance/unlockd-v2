// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
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

contract UTokenFactory is
  Initializable,
  UUPSUpgradeable,
  UFactoryStorage,
  BaseEmergency,
  IUTokenFactory
{
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

  constructor(address aclManager) BaseEmergency(aclManager) {
    if (aclManager == address(0)) revert Errors.ZeroAddress();
  }

  function initialize(address sharesTokenImp) public initializer {
    if (sharesTokenImp == address(0)) revert Errors.ZeroAddress();
    _sharesTokenImp = sharesTokenImp;
  }

  function createMarket(IUTokenFactory.CreateMarketParams calldata params) external onlyAdmin {
    if (reserves[params.underlyingAsset].lastUpdateTimestamp != 0) {
      revert Errors.UnderlyingMarketAlreadyExist();
    }
    address sharesToken = _sharesToken(params.decimals, params.tokenName, params.tokenSymbol);
    // Create Reserve Asset
    reserves[params.underlyingAsset].init(
      params.underlyingAsset,
      params.reserveType,
      sharesToken,
      params.interestRateAddress,
      params.strategyAddress,
      params.reserveFactor
    );

    emit MarketCreated(
      params.underlyingAsset,
      params.interestRateAddress,
      params.strategyAddress,
      sharesToken
    );
  }

  function deposit(address underlyingAsset, uint256 amount, address onBehalfOf) external {
    Errors.verifyNotZero(underlyingAsset);
    Errors.verifyNotZero(onBehalfOf);
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

    reserve.mintScaled(balance, onBehalfOf, amount);

    reserve.strategyInvest(balance, amount);

    emit Deposit(msg.sender, onBehalfOf, reserve.underlyingAsset, amount);
  }

  function withdraw(address underlyingAsset, uint256 amount, address to) external {
    Errors.verifyNotZero(underlyingAsset);
    Errors.verifyNotZero(to);
    Errors.verifyNotZero(amount);

    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];

    if (reserve.reserveState == Constants.ReserveState.FREEZED) {
      revert Errors.ReserveNotActive();
    }

    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    Errors.verifyNotZero(to);
    Errors.verifyNotZero(amount);

    // Check if we have enought to withdraw
    reserve.strategyWithdraw(balance, amount);

    reserve.updateState(balance);

    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, amount);

    // Burn scaled tokens
    reserve.burnScaled(balance, msg.sender, to, amount);

    emit Withdraw(msg.sender, to, reserve.underlyingAsset, amount);
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
    borrowScaledBalanceByLoanId[underlyingAsset][loanId] += scaledAmount;
    borrowScaledBalanceByUser[underlyingAsset][onBehalfOf] += scaledAmount;

    IERC20(underlyingAsset).safeTransfer(to, amount);

    // Remove funds from the interest rate
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, amount);

    emit Borrow(
      msg.sender,
      onBehalfOf,
      underlyingAsset,
      amount,
      loanId,
      reserve.currentVariableBorrowRate
    );
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
    uint256 currentDebt = borrowScaledBalanceByLoanId[underlyingAsset][loanId];

    // User can't repay more thant the current debt
    if (currentDebt == 0 || currentDebt < scaledAmount) revert Errors.AmountExceedsDebt();
    // Update balances
    borrowScaledBalanceByLoanId[underlyingAsset][loanId] -= scaledAmount;
    borrowScaledBalanceByUser[underlyingAsset][onBehalfOf] -= scaledAmount;

    IERC20(underlyingAsset).safeTransferFrom(from, address(this), amount);
    reserve.updateState(balance);

    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, amount, 0);

    reserve.strategyInvest(balance, amount);

    emit Repay(
      msg.sender,
      onBehalfOf,
      underlyingAsset,
      amount,
      loanId,
      reserve.currentVariableBorrowRate
    );
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

  function getScaledToken(address underlyingAsset) external view returns (address) {
    return reserves[underlyingAsset].scaledTokenAddress;
  }

  /////////////////////////////////////////////////////////
  // DEBT
  /////////////////////////////////////////////////////////

  function getScaledTotalDebtMarket(address underlyingAsset) external view returns (uint256) {
    return
      balances[underlyingAsset].totalBorrowScaled.rayMul(
        reserves[underlyingAsset].getNormalizedDebt()
      );
  }

  function getTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return borrowScaledBalanceByUser[underlyingAsset][user];
  }

  function getScaledTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return
      borrowScaledBalanceByUser[underlyingAsset][user].rayMul(
        reserves[underlyingAsset].getNormalizedDebt()
      );
  }

  function getDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256) {
    return borrowScaledBalanceByLoanId[underlyingAsset][loanId];
  }

  function getScaledDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256) {
    return
      borrowScaledBalanceByLoanId[underlyingAsset][loanId].rayMul(
        reserves[underlyingAsset].getNormalizedDebt()
      );
  }

  /////////////////////////////////////////////////////////
  // SUPPLY
  /////////////////////////////////////////////////////////

  function getBalances(
    address underlyingAsset
  ) external view returns (DataTypes.MarketBalance memory) {
    return balances[underlyingAsset];
  }

  function getBalanceByUser(address underlyingAsset, address user) external view returns (uint256) {
    return ScaledToken(reserves[underlyingAsset].scaledTokenAddress).balanceOf(user);
  }

  function getScaledBalanceByUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return
      ScaledToken(reserves[underlyingAsset].scaledTokenAddress).balanceOf(user).rayMul(
        reserves[underlyingAsset].getNormalizedIncome()
      );
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
      address(this),
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

  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyAdmin {}
}
