// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Errors, DataTypes, ERC20Upgradeable} from '../libraries/base/BaseERC20.sol';
import {MathUtils} from '../libraries/math/MathUtils.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {ReserveAssetLogic} from '../libraries/logic/ReserveAssetLogic.sol';
// import {UTokenStorage} from '../libraries/storage/UTokenStorage.sol';
import {ScaledToken} from '../tokens/ScaledToken.sol';
import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';
import {IStrategy} from '../interfaces/IStrategy.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';

import {Constants} from '../libraries/helpers/Constants.sol';

import {console} from 'forge-std/console.sol';

contract UTokenV2 {
  using ReserveAssetLogic for DataTypes.ReserveDataV2;
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using WadRayMath for uint128;
  using SafeCast for uint256;

  address internal _aclManager;
  address internal _sharesTokenImp;
  // UnderlyingAsset -> Reserve
  mapping(address => DataTypes.ReserveDataV2) public reserves;
  // UnderlyingAsset -> Reserve
  mapping(address => DataTypes.MarketBalance) public balances;
  // Scaled balances by loan and user
  mapping(bytes32 => uint256) internal borrowScaledBalanceByLoanId;
  mapping(address => uint256) internal borrowScaledBalanceByUser;

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

  modifier onlyEmergency() {
    if (IACLManager(_aclManager).isEmergencyAdmin(msg.sender) == false) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  /////////////////////////////////////////////////////

  constructor(address aclManager, address sharesTokenImp) {
    if (aclManager == address(0)) revert Errors.ZeroAddress();
    if (sharesTokenImp == address(0)) revert Errors.ZeroAddress();
    _aclManager = aclManager;
    _sharesTokenImp = sharesTokenImp;
  }

  function createMarket(
    DataTypes.CreateMarketParams calldata params,
    address underlyingAsset,
    Constants.ReserveType reserveType,
    uint8 decimals,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external onlyAdmin {
    if (reserves[underlyingAsset].lastUpdateTimestamp != 0) {
      revert Errors.UnderlyingMarketAlreadyExist();
    }

    // Create Reserve Asset
    reserves[underlyingAsset].init(
      underlyingAsset,
      reserveType,
      _sharesToken(decimals, tokenName, tokenSymbol),
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
    DataTypes.ReserveDataV2 storage reserve = reserves[underlyingAsset];

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

    DataTypes.ReserveDataV2 storage reserve = reserves[underlyingAsset];

    if (reserve.reserveState == Constants.ReserveState.FREEZE) {
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

    DataTypes.ReserveDataV2 storage reserve = reserves[underlyingAsset];

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

    DataTypes.ReserveDataV2 storage reserve = reserves[underlyingAsset];

    if (reserve.lastUpdateTimestamp == 0) {
      revert Errors.UnderlyingMarketNotExist();
    }

    if (reserve.reserveState == Constants.ReserveState.FREEZE) {
      revert Errors.ReserveNotActive();
    }

    // Move amount to the pool
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    uint256 scaledAmount = reserve.decreaseDebt(balance, amount);
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
  ) external onlyEmergency {
    reserves[underlyingAsset].reserveState = reserveState;
  }

  /////////////////////////////////////////////////////////
  // GET
  /////////////////////////////////////////////////////////
  function validateReserveType(
    Constants.ReserveType currentReserveType,
    Constants.ReserveType reserveType
  ) external view returns (bool) {
    if (
      currentReserveType == Constants.ReserveType.ALL &&
      reserveType != Constants.ReserveType.SPECIAL
    ) return true;
    if (currentReserveType == reserveType) return true;
    return false;
  }

  function getReserveData(
    address underlyingAsset
  ) external returns (DataTypes.ReserveDataV2 memory) {
    return reserves[underlyingAsset];
  }

  /////////////////////////////////////////////////////////
  // DEBT
  /////////////////////////////////////////////////////////
  function getTotalDebtFromUser(address underlyingAsset, address user) external returns (uint256) {
    return borrowScaledBalanceByUser[user].rayMul(reserves[underlyingAsset].getNormalizedDebt());
  }

  function getDebtFromLoanId(address underlyingAsset, bytes32 loanId) external returns (uint256) {
    return
      borrowScaledBalanceByLoanId[loanId].rayMul(reserves[underlyingAsset].getNormalizedDebt());
  }

  /////////////////////////////////////////////////////////
  // SUPPLY
  /////////////////////////////////////////////////////////

  function getBalances(address underlyingAsset) external returns (DataTypes.MarketBalance memory) {
    return balances[underlyingAsset];
  }

  function totalSupply(address underlyingAsset) external returns (uint256) {
    return
      balances[underlyingAsset].totalSupplyScaled.rayMul(
        reserves[underlyingAsset].getNormalizedIncome()
      );
  }

  function totalAvailableSupply(address underlyingAsset) external returns (uint256) {
    uint256 totalSupplyAssets = IERC20(underlyingAsset).balanceOf(address(this));
    if (reserves[underlyingAsset].strategyAddress != address(0)) {
      totalSupplyAssets += IStrategy(reserves[underlyingAsset].strategyAddress).balanceOf(
        address(this)
      );
    }
    return totalSupplyAssets;
  }

  function totalSupplyNotInvested(address underlyingAsset) external returns (uint256) {
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
