// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IStrategy} from '../interfaces/IStrategy.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {IUTokenVault} from '../interfaces/IUTokenVault.sol';
import {UVaultStorage} from '../libraries/storage/UVaultStorage.sol';
import {BaseEmergency} from '../libraries/base/BaseEmergency.sol';
import {MathUtils} from '../libraries/math/MathUtils.sol';
import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {ReserveLogic} from '../libraries/logic/ReserveLogic.sol';
import {ValidationLogic} from '../libraries/logic/ValidationLogic.sol';
import {ScaledToken} from '../libraries/tokens/ScaledToken.sol';
import {ReserveConfiguration} from '../libraries/configuration/ReserveConfiguration.sol';
import {Constants} from '../libraries/helpers/Constants.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DataTypes} from '../types/DataTypes.sol';

import {console} from 'forge-std/console.sol';
import {UnlockdUpgradeableProxy} from '../libraries/proxy/UnlockdUpgradeableProxy.sol';

contract UTokenVault is Initializable, UUPSUpgradeable, UVaultStorage, BaseEmergency, IUTokenVault {
  using ReserveLogic for DataTypes.ReserveData;
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using WadRayMath for uint128;
  using SafeCast for uint256;

  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  //////////////////////////////////////////////////////

  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  modifier onlyAdmin() {
    if (!IACLManager(_aclManager).isUTokenAdmin(msg.sender)) {
      revert Errors.UTokenAccessDenied();
    }
    _;
  }

  /////////////////////////////////////////////////////

  constructor(address aclManager) BaseEmergency(aclManager) {
    if (aclManager == address(0)) revert Errors.ZeroAddress();
    _disableInitializers();
  }

  function initialize(address sharesTokenImp) public initializer {
    if (sharesTokenImp == address(0)) revert Errors.ZeroAddress();
    _sharesTokenImp = sharesTokenImp;
  }

  /**
    @notice Create new market
    @param params IUTokenVault.CreateMarketParams struct to create the reserve
    struct CreateMarketParams {
      address interestRateAddress;
      address strategyAddress;
      uint16 reserveFactor;
      address underlyingAsset;
      Constants.ReserveType reserveType;
      uint8 decimals;
      string tokenName;
      string tokenSymbol;
    }
  */
  function createMarket(IUTokenVault.CreateMarketParams calldata params) external onlyAdmin {
    if (reserves[params.underlyingAsset].lastUpdateTimestamp != 0) {
      revert Errors.UnderlyingMarketAlreadyExist();
    }
    address sharesToken = _sharesToken(params.decimals, params.tokenName, params.tokenSymbol);
    // Create Reserve Asset
    reserves[params.underlyingAsset].init(
      params.reserveType,
      params.underlyingAsset,
      sharesToken,
      params.interestRateAddress,
      params.strategyAddress,
      params.decimals,
      params.reserveFactor
    );

    emit MarketCreated(
      params.underlyingAsset,
      params.interestRateAddress,
      params.strategyAddress,
      sharesToken
    );
  }

  /**
    @notice Withdraw from the vault
    @param underlyingAsset asset of the vault
    @param amount amount to deposit
    @param onBehalfOf address to recive the scaled tokens
  */
  function deposit(address underlyingAsset, uint256 amount, address onBehalfOf) external {
    Errors.verifyNotZero(underlyingAsset);
    Errors.verifyNotZero(onBehalfOf);
    Errors.verifyNotZero(amount);

    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    ValidationLogic.validateVaultDeposit(reserve, amount);

    reserve.updateState(balance);
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, amount, 0);

    reserve.mintScaled(balance, msg.sender, onBehalfOf, amount);

    reserve.strategyInvest(balance, amount);

    emit Deposit(msg.sender, onBehalfOf, reserve.underlyingAsset, amount);
  }

  /**
    @notice Withdraw from the vault
    @param underlyingAsset asset of the vault
    @param amount amount to borrow
    @param to user to send the funds
  */
  function withdraw(address underlyingAsset, uint256 amount, address to) external {
    Errors.verifyNotZero(underlyingAsset);
    Errors.verifyNotZero(to);
    Errors.verifyNotZero(amount);

    DataTypes.ReserveData storage reserve = reserves[underlyingAsset];

    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    ValidationLogic.validateVaultWithdraw(reserve);

    reserve.updateState(balance);
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, amount);

    reserve.strategyWithdraw(balance, amount);
    // Burn scaled tokens
    reserve.burnScaled(balance, msg.sender, to, amount);

    emit Withdraw(msg.sender, to, reserve.underlyingAsset, amount);
  }

  /**
    @notice Borrorw
    @param underlyingAsset asset of the vault
    @param loanId loan to asign the debt
    @param amount amount to borrow
    @param to user to send the funds
    @param onBehalfOf address to repay on behalf of other user
  */
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

    ValidationLogic.validateVaultBorrow(reserve, amount);

    // Move amount to the pool
    DataTypes.MarketBalance storage balance = balances[underlyingAsset];

    uint256 availableLiquidity = this.totalAvailableSupply(underlyingAsset);
    if (amount > availableLiquidity) {
      revert Errors.NotEnoughLiquidity();
    }

    // Check if we have enought to withdraw
    reserve.strategyWithdraw(balance, amount);

    uint256 scaledAmount = reserve.increaseDebt(balance, amount);

    // Update balances
    borrowScaledBalanceByLoanId[underlyingAsset][loanId] += scaledAmount;
    borrowScaledBalanceByUser[underlyingAsset][onBehalfOf] += scaledAmount;

    IERC20(underlyingAsset).safeTransfer(to, amount);

    reserve.updateState(balance);
    // @dev Because we update the debt with increaseDebt, we don't need to pass the current amount into the calculation.
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, 0);

    emit Borrow(
      msg.sender,
      onBehalfOf,
      underlyingAsset,
      amount,
      loanId,
      reserve.currentVariableBorrowRate
    );
  }

  /**
    @notice Repay loan 
    @param underlyingAsset asset of the vault
    @param loanId loanId to repay
    @param amount amount to repay, if you send uint.max you repay all
    @param from original user from the loan
    @param onBehalfOf address to repay on behalf of other user
  */
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

    ValidationLogic.validateVaultRepay(reserve);
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
    // @dev Because we update the debt with increaseDebt, we don't need to pass the current amount into the calculation.
    reserve.updateInterestRates(balance.totalBorrowScaled, balance.totalSupplyAssets, 0, 0);

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

  /**
    @notice Update state of the reserve, recalculate index
    @param underlyingAsset asset of the vault
  */
  function updateState(address underlyingAsset) external {
    reserves[underlyingAsset].updateState(balances[underlyingAsset]);
  }

  /**
    @notice Active reserve 
    @param underlyingAsset asset of the vault
    @param isActive active true/false
  */
  function setActive(address underlyingAsset, bool isActive) external onlyEmergencyAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = reserves[underlyingAsset].config;
    currentConfig.setActive(isActive);
    reserves[underlyingAsset].config = currentConfig;
    emit ActiveVault(underlyingAsset, isActive);
  }

  /**
    @notice Frozen reserve 
    @param underlyingAsset asset of the vault
    @param isFrozen frozen true/false
  */
  function setFrozen(address underlyingAsset, bool isFrozen) external onlyEmergencyAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = reserves[underlyingAsset].config;
    currentConfig.setFrozen(isFrozen);
    reserves[underlyingAsset].config = currentConfig;
    emit FrozenVault(underlyingAsset, isFrozen);
  }

  /**
    @notice Pause or Unpause reserve 
    @param underlyingAsset asset of the vault
    @param isPaused pause true/false 
  */
  function setPaused(address underlyingAsset, bool isPaused) external onlyEmergencyAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = reserves[underlyingAsset].config;
    currentConfig.setPaused(isPaused);
    reserves[underlyingAsset].config = currentConfig;
    emit PausedVault(underlyingAsset, isPaused);
  }

  /**
    @notice Update caps 
    @param underlyingAsset asset of the vault
    @param minCap min cap
    @param depositCap max deposit cap
    @param borrowCap max borrow cap
  */
  function setCaps(
    address underlyingAsset,
    uint256 minCap,
    uint256 depositCap,
    uint256 borrowCap
  ) external onlyEmergencyAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = reserves[underlyingAsset].config;
    currentConfig.setMinCap(minCap);
    currentConfig.setDepositCap(depositCap);
    currentConfig.setBorrowCap(borrowCap);
    reserves[underlyingAsset].config = currentConfig;

    emit UpdateCaps(underlyingAsset, minCap, depositCap, borrowCap);
  }

  /**
    @notice Withdraw and disable current strategy
    @param underlyingAsset asset of the vault
  */
  function disableStrategy(address underlyingAsset) external onlyEmergencyAdmin {
    if (reserves[underlyingAsset].strategyAddress != address(0)) {
      reserves[underlyingAsset].strategyWithdrawAll(balances[underlyingAsset]);
      reserves[underlyingAsset].updateState(balances[underlyingAsset]);
      reserves[underlyingAsset].strategyAddress = address(0);
      emit DisableReserveStrategy(underlyingAsset);
    }
  }

  /**
    @notice Update strategy on the reserve
    @param underlyingAsset asset of the vault
    @param newStrategy address of the new strategy
  */
  function updateReserveStrategy(
    address underlyingAsset,
    address newStrategy
  ) external onlyEmergencyAdmin {
    if (reserves[underlyingAsset].strategyAddress != address(0)) {
      revert Errors.StrategyNotEmpty();
    }
    Errors.verifyNotZero(newStrategy);
    reserves[underlyingAsset].strategyAddress = newStrategy;
    emit UpdateReserveStrategy(underlyingAsset, newStrategy);
  }

  /////////////////////////////////////////////////////////
  // GET
  /////////////////////////////////////////////////////////

  /**
    @notice Validate if the configuration of the reserve allows to interact
    @param currentReserveType reserve type
    @param reserveType asset reserve type
    @return bool true or false 
  */
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

  /**
    @notice Return reserve data from the vault
    @param underlyingAsset asset of the reserve
    @return reserveData ReserveData struct from the vault
    struct ReserveData {
        ReserveConfigurationMap config;
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        address underlyingAsset;
        address scaledTokenAddress;
        address interestRateAddress;
        address strategyAddress;
        uint40 lastUpdateTimestamp;
    }
  */
  function getReserveData(
    address underlyingAsset
  ) external view returns (DataTypes.ReserveData memory) {
    return reserves[underlyingAsset];
  }

  /**
    @notice Return scaled token address
    @param underlyingAsset asset of the reserve
    @return scaledTokenAddress address of the scaled token
  */
  function getScaledToken(address underlyingAsset) external view returns (address) {
    return reserves[underlyingAsset].scaledTokenAddress;
  }

  /**
    @notice Return the current caps of the reserve
    @param underlyingAsset asset of the reserve
    @return borrowCap Max amount to borrow
    @return depositCap Max amount to deposit
    @return minCap Min amount to deposit and borrow
     */
  function getCaps(address underlyingAsset) external view returns (uint256, uint256, uint256) {
    return reserves[underlyingAsset].config.getCaps();
  }

  /**
    @notice Return the current state of the reserve
    @param underlyingAsset asset of the reserve
    @return active Reserve is active
    @return frozen Reserve is frozen
    @return paused Reserve is paused
     */
  function getFlags(address underlyingAsset) external view returns (bool, bool, bool) {
    return reserves[underlyingAsset].config.getFlags();
  }

  /**
    @notice Return decimals configured for the reserve
    @param underlyingAsset asset of the reserve
    @return decimals decimals of the reserve
  */
  function getDecimals(address underlyingAsset) external view returns (uint256) {
    return reserves[underlyingAsset].config.getDecimals();
  }

  /**
    @notice Return the type of the reserve
    @param underlyingAsset asset of the reserve
    @return reserveType reserve type
  */
  function getReserveType(address underlyingAsset) external view returns (Constants.ReserveType) {
    return reserves[underlyingAsset].config.getReserveType();
  }

  /////////////////////////////////////////////////////////
  // DEBT
  /////////////////////////////////////////////////////////

  /**
    @notice Return scaled total debt market
    @param underlyingAsset asset of the reserve
    @return total Total amount scaled
  */
  function getScaledTotalDebtMarket(address underlyingAsset) external view returns (uint256) {
    return
      balances[underlyingAsset].totalBorrowScaled.rayMul(
        reserves[underlyingAsset].getNormalizedDebt()
      );
  }

  /**
    @notice Return total debt from user
    @param underlyingAsset asset of the reserve
    @param user address from user
    @return total Total amount 
  */
  function getTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return borrowScaledBalanceByUser[underlyingAsset][user];
  }

  /**
    @notice Return scaled total debt from user
    @param underlyingAsset asset of the reserve
    @param user address from user
    @return total Total amount scaled
  */
  function getScaledTotalDebtFromUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return
      borrowScaledBalanceByUser[underlyingAsset][user].rayMul(
        reserves[underlyingAsset].getNormalizedDebt()
      );
  }

  /**
    @notice Return total debt from loanId
    @param underlyingAsset asset of the reserve
    @param loanId loanId assigned 
    @return total Total amount 
  */
  function getDebtFromLoanId(
    address underlyingAsset,
    bytes32 loanId
  ) external view returns (uint256) {
    return borrowScaledBalanceByLoanId[underlyingAsset][loanId];
  }

  /**
    @notice Return scaled total debt from loanId
    @param underlyingAsset asset of the reserve
    @param loanId loanId assigned 
    @return total Total amount scaled
  */
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

  /**
    @notice Return supply struct
    @param underlyingAsset asset of the reserve
    @return marketBalance DataTypes.MarketBalance
    struct MarketBalance {
        uint128 totalSupplyScaledNotInvested;   
        uint128 totalSupplyAssets;
        uint128 totalSupplyScaled;
        uint128 totalBorrowScaled;
        uint40 lastUpdateTimestamp;
    }
  */
  function getBalances(
    address underlyingAsset
  ) external view returns (DataTypes.MarketBalance memory) {
    return balances[underlyingAsset];
  }

  /**
    @notice Return balance from user
    @param underlyingAsset asset of the reserve
    @param user address of the user
    @return balance balance from user 
  */
  function getBalanceByUser(address underlyingAsset, address user) external view returns (uint256) {
    return ScaledToken(reserves[underlyingAsset].scaledTokenAddress).balanceOf(user);
  }

  /**
    @notice Return scaled balance from user
    @param underlyingAsset asset of the reserve
    @param user address of the user
    @return balance scaled balance from user 
  */
  function getScaledBalanceByUser(
    address underlyingAsset,
    address user
  ) external view returns (uint256) {
    return
      ScaledToken(reserves[underlyingAsset].scaledTokenAddress).balanceOf(user).rayMul(
        reserves[underlyingAsset].getNormalizedIncome()
      );
  }

  /**
    @notice Return total supply of the pool
    @param underlyingAsset asset of the reserve
    @return totalSupply scaled total supply
  */
  function totalSupply(address underlyingAsset) external view returns (uint256) {
    return
      balances[underlyingAsset].totalSupplyScaled.rayMul(
        reserves[underlyingAsset].getNormalizedIncome()
      );
  }

  /**
    @notice Available supply including the invested
    @param underlyingAsset asset of the reserve
    @return totalSupply supply 
  */
  function totalAvailableSupply(address underlyingAsset) external view returns (uint256) {
    uint256 totalSupplyAssets = IERC20(underlyingAsset).balanceOf(address(this));
    if (reserves[underlyingAsset].strategyAddress != address(0)) {
      totalSupplyAssets += IStrategy(reserves[underlyingAsset].strategyAddress).balanceOf(
        address(this)
      );
    }
    return totalSupplyAssets;
  }

  /**
    @notice Available supply not invested in the estrategy
    @param underlyingAsset asset of the reserve
    @return totalSupply supply not invested
  */
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
   * @dev Only UTokenVault is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyAdmin {}
}
