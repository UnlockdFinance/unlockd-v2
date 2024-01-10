// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {FixedPointMathLib} from '@solady/utils/FixedPointMathLib.sol';

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IReserveOracle} from '../../interfaces/oracles/IReserveOracle.sol';
import {IUTokenFactory} from '../../interfaces/IUTokenFactory.sol';

import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';

import {Errors} from '../helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

// import {console} from 'forge-std/console.sol';

/**
 * @title GenericLogic library
 * @author Unlockd
 * @notice Implements protocol-level logic to calculate and validate the state of a user
 */
library GenericLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using FixedPointMathLib for uint256;
  // HEALTH FACTOR 1
  uint256 internal constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;

  uint256 internal constant FIRST_BID_INCREMENT = 250;
  uint256 internal constant NEXT_BID_INCREMENT = 100;

  struct CalculateLoanDataVars {
    uint256 reserveUnitPrice;
    uint256 reserveUnit;
    uint256 healthFactor;
    uint256 totalCollateralInReserve;
    uint256 totalDebtInReserve;
    uint256 amount;
  }

  function calculateFutureLoanData(
    bytes32 loanId,
    uint256 amount,
    uint256 price,
    address reserveOracle,
    address uTokenFactory,
    DataTypes.ReserveData memory reserveData,
    DataTypes.SignLoanConfig memory loanConfig
  ) internal view returns (uint256, uint256, uint256, uint256) {
    CalculateLoanDataVars memory vars;

    // Calculate the reserve price
    vars.reserveUnit = 10 ** reserveData.decimals;
    vars.reserveUnitPrice = IReserveOracle(reserveOracle).getAssetPrice(
      reserveData.underlyingAsset
    );
    vars.amount = amount.mulDiv(vars.reserveUnitPrice, vars.reserveUnit);

    // Calculate total debt in base currency
    vars.totalDebtInReserve = getUserDebtInBaseCurrency(
      loanId,
      reserveData.underlyingAsset,
      uTokenFactory,
      vars.reserveUnitPrice,
      vars.reserveUnit
    );

    // If the total assets are 0, then we need to calculate the collateral with the current value
    // All the assets are expresed in the amount of the BASE (USD)
    uint256 collateral = loanConfig.totalAssets == 0 ? price : loanConfig.aggLoanPrice;
    // We transform the collateral in BASE currency
    vars.totalCollateralInReserve = collateral.mulDiv(vars.reserveUnitPrice, vars.reserveUnit);

    uint256 updatedDebt = vars.totalDebtInReserve > vars.amount
      ? vars.totalDebtInReserve - vars.amount
      : 0;

    // Calculate the HF
    vars.healthFactor = calculateHealthFactorFromBalances(
      vars.totalCollateralInReserve,
      updatedDebt,
      loanConfig.aggLiquidationThreshold
    );

    return (vars.totalCollateralInReserve, vars.totalDebtInReserve, vars.amount, vars.healthFactor);
  }

  struct CalculateLoanDebtDataVars {
    uint256 reserveUnitPrice;
    uint256 reserveUnit;
    uint256 totalDebtInReserve;
  }

  function calculateLoanDebtInBase(
    bytes32 loanId,
    address reserveOracle,
    address uTokenFactory,
    DataTypes.ReserveData memory reserveData
  ) internal view returns (uint256) {
    CalculateLoanDataVars memory vars;

    // Calculate the reserve price
    vars.reserveUnit = 10 ** reserveData.decimals;
    vars.reserveUnitPrice = IReserveOracle(reserveOracle).getAssetPrice(
      reserveData.underlyingAsset
    );
    // Calculate total debt in base currency
    vars.totalDebtInReserve = getUserDebtInBaseCurrency(
      loanId,
      reserveData.underlyingAsset,
      uTokenFactory,
      vars.reserveUnitPrice,
      vars.reserveUnit
    );

    return vars.totalDebtInReserve;
  }

  function calculateLoanDebt(
    bytes32 loanId,
    address uTokenFactory,
    address underlyingAsset
  ) internal view returns (uint256) {
    if (loanId == 0) return 0;
    // fetching variable debt
    uint256 userTotalDebt = IUTokenFactory(uTokenFactory).getDebtFromLoanId(
      underlyingAsset,
      loanId
    );
    return userTotalDebt;
  }

  /**
   * @dev Calculates the health factor from the corresponding balances
   * @param totalCollateral The total collateral
   * @param totalDebt The total debt
   * @param liquidationThreshold The avg liquidation threshold
   * @return healthFactor The health factor calculated from the balances provided
   *
   */
  function calculateHealthFactorFromBalances(
    uint256 totalCollateral,
    uint256 totalDebt,
    uint256 liquidationThreshold
  ) internal pure returns (uint256 healthFactor) {
    healthFactor = totalDebt == 0
      ? type(uint256).max
      : (totalCollateral.percentMul(liquidationThreshold)).wadDiv(totalDebt);
  }

  /**
   * @dev Calculates the equivalent amount that an user can borrow, depending on the available collateral and the
   * average Loan To Value
   * @param totalCollateral The total collateral
   * @param totalDebt The total borrow balance
   * @param ltv The average loan to value
   * @return availableBorrows the amount available to borrow for the user
   *
   */

  function calculateAvailableBorrows(
    uint256 totalCollateral,
    uint256 totalDebt,
    uint256 ltv
  ) internal pure returns (uint256 availableBorrows) {
    availableBorrows = totalCollateral.percentMul(ltv);

    unchecked {
      availableBorrows = availableBorrows < totalDebt ? 0 : availableBorrows - totalDebt;
    }
  }

  function calculateAmountToArriveToLTV(
    uint256 totalCollateral,
    uint256 totalDebt,
    uint256 ltv
  ) internal pure returns (uint256 amount) {
    uint256 availableBorrows = totalCollateral.percentMul(ltv);
    unchecked {
      amount = availableBorrows < totalDebt ? totalDebt - availableBorrows : 0;
    }
  }

  /**
   * @notice Calculates total debt of the user in the based currency used to normalize the values of the assets
   * @dev This fetches the `balanceOf` of the stable and variable debt tokens for the user. For gas reasons, the
   * variable debt balance is calculated by fetching `scaledBalancesOf` normalized debt, which is cheaper than
   * fetching `balanceOf`
   * @param loanId Id of the loan
   * @param underlyingAsset address underlying
   * @param uTokenFactory address of the uToken factory
   * @param assetPrice The price of the asset for which the total debt of the user is being calculated
   * @param assetUnit The value representing one full unit of the asset (10^decimals)
   * @return The total debt of the user normalized to the base currency
   */
  function getUserDebtInBaseCurrency(
    bytes32 loanId,
    address underlyingAsset,
    address uTokenFactory,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    if (loanId == 0) return 0;
    // fetching variable debt
    uint256 userTotalDebt = IUTokenFactory(uTokenFactory).getDebtFromLoanId(
      underlyingAsset,
      loanId
    );
    if (userTotalDebt == 0) return 0;
    return userTotalDebt.mulDiv(assetPrice, assetUnit);
  }

  function getMainWallet(
    address walletRegistry,
    address owner
  ) internal view returns (address, address) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    return (wallet.wallet, wallet.protocolOwner);
  }

  function getMainWalletAddress(
    address walletRegistry,
    address owner
  ) internal view returns (address walletAddress) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    walletAddress = wallet.wallet;
  }

  function getMainWalletOwner(
    address walletRegistry,
    address owner
  ) internal view returns (address walletOwner) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    walletOwner = wallet.owner;
  }

  function getMainWalletProtocolOwner(
    address walletRegistry,
    address owner
  ) internal view returns (address walletProtocolOwner) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    walletProtocolOwner = wallet.protocolOwner;
  }
}
