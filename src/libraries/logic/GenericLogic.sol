// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';
import {FixedPointMathLib} from '@solady/utils/FixedPointMathLib.sol';

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IReserveOracle} from '../../interfaces/oracles/IReserveOracle.sol';
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';

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

  uint256 internal constant FIRST_BID_INCREMENT = 250; // 2.5 %
  uint256 internal constant NEXT_BID_INCREMENT = 100; // 1 %

  struct CalculateLoanDataVars {
    uint256 reserveUnitPrice;
    uint256 reserveUnit;
    uint256 healthFactor;
    uint256 totalCollateralInReserve;
    uint256 totalDebtInReserve;
    uint256 amount;
  }

  function calculateFutureLoanData(
    uint256 amount,
    uint256 price,
    uint256 currentDebt,
    address reserveOracle,
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

    vars.totalDebtInReserve = currentDebt.mulDiv(vars.reserveUnitPrice, vars.reserveUnit);
    // If the total assets are 0, then we need to calculate the collateral with the current value of the market
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

  function calculateLoanDebt(
    bytes32 loanId,
    address uTokenVault,
    address underlyingAsset
  ) internal view returns (uint256) {
    if (loanId == 0) return 0;
    // fetching variable debt
    uint256 userTotalDebt = IUTokenVault(uTokenVault).getScaledDebtFromLoanId(
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
