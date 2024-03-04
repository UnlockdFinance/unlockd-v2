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

  /**
   * @dev Calculates the current debt of a specific loand and asset
   * @param loanId identifier of the loan
   * @param uTokenVault Current vault
   * @param underlyingAsset Underlying asset of the debt
   * @return currentDebt the amount of debt
   *
   */
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

  /**
   * @dev Calculates the amount needed to arrive the LTV, in case of a healty position returns 0
   * @param totalCollateral The total collateral
   * @param totalDebt The total borrow balance
   * @param ltv The average loan to value
   * @return amountToLtv the amount needed to arrive to LTV
   */
  function calculateAmountToArriveToLTV(
    uint256 totalCollateral,
    uint256 totalDebt,
    uint256 ltv
  ) internal pure returns (uint256 amountToLtv) {
    uint256 availableBorrows = totalCollateral.percentMul(ltv);

    unchecked {
      amountToLtv = availableBorrows < totalDebt ? totalDebt - availableBorrows : 0;
    }
  }

  /**
   * @dev Get the abstract wallet information
   * @param walletRegistry address of the wallet registry
   * @param owner Owner of the wallet
   * @return address wallet
   * @return address protocol owner
   */
  function getMainWallet(
    address walletRegistry,
    address owner
  ) internal view returns (address, address) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    return (wallet.wallet, wallet.protocolOwner);
  }

  /**
   * @dev Get the wallet adderess of the abstract wallet
   * @param walletRegistry address of the wallet registry
   * @param owner Owner of the wallet
   * @return walletAddress wallet
   */
  function getMainWalletAddress(
    address walletRegistry,
    address owner
  ) internal view returns (address walletAddress) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    walletAddress = wallet.wallet;
  }

  /**
   * @dev Get the owner adderess of the abstract wallet
   * @param walletRegistry address of the wallet registry
   * @param owner Owner of the wallet
   * @return walletOwner owner
   */
  function getMainWalletOwner(
    address walletRegistry,
    address owner
  ) internal view returns (address walletOwner) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    walletOwner = wallet.owner;
  }

  /**
   * @dev Get the protocol owner adderess of the abstract wallet
   * @param walletRegistry address of the wallet registry
   * @param owner Owner of the wallet
   * @return walletProtocolOwner protocol owner
   */
  function getMainWalletProtocolOwner(
    address walletRegistry,
    address owner
  ) internal view returns (address walletProtocolOwner) {
    IDelegationWalletRegistry.Wallet memory wallet = IDelegationWalletRegistry(walletRegistry)
      .getOwnerWalletAt(owner, 0);
    walletProtocolOwner = wallet.protocolOwner;
  }
}
