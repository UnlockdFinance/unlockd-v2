// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

// import {console} from 'forge-std/console.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {FixedPointMathLib} from '@solady/utils/FixedPointMathLib.sol';

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IReserveOracle} from '../../interfaces/oracles/IReserveOracle.sol';
import {IDebtToken} from '../../interfaces/tokens/IDebtToken.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';

import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';

import {Errors} from '../helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';
import {console} from 'forge-std/console.sol';

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
  uint256 internal constant AUCTION_DURATION = 2 days;
  uint256 internal constant FIRST_BID_INCREMENT = 250;
  uint256 internal constant NEXT_BID_INCREMENT = 100;

  struct CalculateLoanDataVars {
    uint256 reserveUnitPrice;
    uint256 reserveUnit;
    uint256 healthFactor;
    uint256 totalCollateralInReserve;
    uint256 totalDebtInReserve;
  }

  function calculateLoanData(
    bytes32 loanId,
    address user,
    address reserveOracle,
    DataTypes.ReserveData memory reserveData,
    DataTypes.SignLoanConfig memory loanConfig
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    CalculateLoanDataVars memory vars;

    // Calculate the reserve price
    vars.reserveUnit = 10 ** reserveData.decimals;
    vars.reserveUnitPrice = IReserveOracle(reserveOracle).getAssetPrice(
      reserveData.underlyingAsset
    );
    // Calculate total debt in base currency
    vars.totalDebtInReserve = getUserDebtInBaseCurrency(
      loanId,
      user,
      reserveData,
      vars.reserveUnitPrice,
      vars.reserveUnit
    );

    vars.totalCollateralInReserve = loanConfig.aggLoanPrice.mulDiv(
      vars.reserveUnit,
      vars.reserveUnitPrice
    );

    // Calculate the HF
    vars.healthFactor = calculateHealthFactorFromBalances(
      vars.totalCollateralInReserve,
      vars.totalDebtInReserve,
      loanConfig.aggLiquidationThreshold
    );

    return (
      vars.totalCollateralInReserve,
      vars.totalDebtInReserve,
      vars.healthFactor,
      loanConfig.aggLtv,
      loanConfig.aggLiquidationThreshold
    );
  }

  function calculateLoanDataRepay(
    bytes32 loanId,
    uint256 amount,
    address user,
    address reserveOracle,
    DataTypes.ReserveData memory reserveData,
    DataTypes.SignLoanConfig memory loanConfig
  ) internal view returns (uint256, uint256, uint256) {
    CalculateLoanDataVars memory vars;

    // Calculate the reserve price
    vars.reserveUnit = 10 ** reserveData.decimals;
    vars.reserveUnitPrice = IReserveOracle(reserveOracle).getAssetPrice(
      reserveData.underlyingAsset
    );
    // Calculate total debt in base currency
    vars.totalDebtInReserve = getUserDebtInBaseCurrency(
      loanId,
      user,
      reserveData,
      vars.reserveUnitPrice,
      vars.reserveUnit
    );

    vars.totalCollateralInReserve = loanConfig.aggLoanPrice.mulDiv(
      vars.reserveUnit,
      vars.reserveUnitPrice
    );
    uint256 updatedDebt = vars.totalDebtInReserve > amount ? vars.totalDebtInReserve - amount : 0;
    // Calculate the HF
    vars.healthFactor = calculateHealthFactorFromBalances(
      vars.totalCollateralInReserve,
      updatedDebt,
      loanConfig.aggLiquidationThreshold
    );

    return (vars.totalCollateralInReserve, updatedDebt, vars.healthFactor);
  }

  struct CalculateLoanDebtDataVars {
    uint256 reserveUnitPrice;
    uint256 reserveUnit;
    uint256 totalDebtInReserve;
  }

  function calculateLoanDebt(
    bytes32 loanId,
    address user,
    address reserveOracle,
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
      user,
      reserveData,
      vars.reserveUnitPrice,
      vars.reserveUnit
    );

    return vars.totalDebtInReserve;
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
  ) internal view returns (uint256 amount) {
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
   * @param user The address of the user
   * @param reserve The data of the reserve for which the total debt of the user is being calculated
   * @param assetPrice The price of the asset for which the total debt of the user is being calculated
   * @param assetUnit The value representing one full unit of the asset (10^decimals)
   * @return The total debt of the user normalized to the base currency
   */
  function getUserDebtInBaseCurrency(
    bytes32 loanId,
    address user,
    DataTypes.ReserveData memory reserve,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    if (loanId == 0) return 0;
    // fetching variable debt
    uint256 userTotalDebt = IDebtToken(reserve.debtTokenAddress).scaledBalanceOf(loanId, user);

    if (userTotalDebt != 0) {
      userTotalDebt = userTotalDebt.rayMul(
        IUToken(reserve.uToken).getReserveNormalizedVariableDebt()
      );
    }

    return assetPrice.mulDiv(userTotalDebt, assetUnit);
  }

  function amountToBeHealthy(
    DataTypes.Loan memory loan,
    uint256 _loanDebt,
    uint256 _debtToBeHealthy
  ) internal pure returns (uint256 amount) {
    if (loan.totalAssets == 1) {
      return _loanDebt;
    }

    if (_loanDebt > _debtToBeHealthy) {
      unchecked {
        amount = _loanDebt - _debtToBeHealthy;
      }
    }
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
