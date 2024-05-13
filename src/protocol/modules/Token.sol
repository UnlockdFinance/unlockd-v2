// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {ITokenModule} from '../../interfaces/modules/ITokenModule.sol';
import {IReserveOracle} from '../../interfaces/oracles/IReserveOracle.sol';
import {TokenLogic, DataTypes, Errors} from '../../libraries/logic/TokenLogic.sol';
import {GenericLogic} from '../../libraries/logic/GenericLogic.sol';
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';
import {UTokenVault} from '../UTokenVault.sol';
import {LoanLogic} from '../../libraries/logic/LoanLogic.sol';
import {IERC20Vault} from '../../interfaces/vault/IERC20Vault.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract Token is BaseCoreModule, ITokenModule {
  using LoanLogic for DataTypes.Loan;
  using SafeERC20 for IERC20;

  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  function borrow(
    bytes32 loanId,
    address[] calldata assets,
    uint256[] calldata amounts,
    address underlyingAsset,
    uint256 borrowAmount
  ) external {
    address msgSender = unpackTrailingParamMsgSender();

    uint256 priceUnit = IReserveOracle(_reserveOracle).getAssetPrice(underlyingAsset);
    uint256 borrowAmountUSD = borrowAmount * priceUnit;
    uint256 totalValueLTVUSD = 0;

    // Create Loan
    if (loanId == bytes32(0)) {
      // NEW LOAN
      loanId = LoanLogic.generateId(msgSender, 0, block.timestamp);

      _loans[loanId].createLoan(
        LoanLogic.ParamsCreateLoan({
          msgSender: msgSender,
          underlyingAsset: underlyingAsset,
          totalAssets: 0, // TODO: Check if this could create inconsistences
          loanId: loanId
        })
      );
    }

    // Check previous balance
    DataTypes.TokenLoan storage tokenLoan = _tokenLoan[loanId];

    if (tokenLoan.underlyingAsset != address(0)) {
      if (tokenLoan.underlyingAsset != underlyingAsset) {
        // We can't use a different underlyingAsset
        revert();
      }
      // TODO: Find a way to add more collateral to the loan
      // revert();

      // // We calculate the previus amount deposited
      // for (uint i = 0; i < loan.assets.length; i++) {
      //   address asset = loan.assets[i];
      //   uint256 amount = loan.amountAssets[i];

      //   DataTypes.TokenData tokenConfig = _tokenConfig[asset];
      //   totalValueLTVUSD += TokenLogic.calculateLTVInUSD(tokenConfig, amount);
      // }
    }
    {
      // Calculate collateral
      // Add new collateral
      address[] memory newAssets = new address[](assets.length);

      for (uint i = 0; i < assets.length; i++) {
        address asset = assets[i];
        uint256 amount = amounts[i];
        // Update values
        newAssets[i] = asset;
        tokenLoan.collateral[asset] += amount;

        DataTypes.TokenData memory tokenConfig = _tokenConfigs[asset];

        if (amount > 0) {
          // Transfer the assets new assets
          TokenLogic.transferAssets(tokenConfig, amount);
        }
        // Calculate current value of the collateral
        totalValueLTVUSD += TokenLogic.calculateLTVInUSD(tokenConfig, tokenLoan.collateral[asset]);
      }

      // Update total Assets
      tokenLoan.assets = newAssets;
      tokenLoan.underlyingAsset = underlyingAsset;
    }
    {
      // Validation
      uint256 currentDebt = GenericLogic.calculateLoanDebt(loanId, _uTokenVault, underlyingAsset);

      // We calculate DEBT
      uint256 updatedDebtUSDC = (currentDebt * priceUnit) + borrowAmountUSD;

      // We calculate the current debt and the HF
      uint256 healthFactor = GenericLogic.calculateHealthFactorFromBalances(
        totalValueLTVUSD,
        updatedDebtUSDC,
        _liquidationThreshold
      );

      // Check HF
      if (healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
        revert Errors.UnhealtyLoan();
      }
    }

    // Add more collateral to the loan
    if (borrowAmount > 0) {
      UTokenVault(_uTokenVault).borrow(underlyingAsset, loanId, borrowAmount, msgSender, msgSender);
    }
  }

  function repay(
    bytes32 loanId,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256 amountRepay
  ) external {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.TokenLoan storage tokenLoan = _tokenLoan[loanId];
    uint256 priceUnit = IReserveOracle(_reserveOracle).getAssetPrice(tokenLoan.underlyingAsset);

    uint256 currentDebt = GenericLogic.calculateLoanDebt(
      loanId,
      _uTokenVault,
      tokenLoan.underlyingAsset
    );

    if (amountRepay == type(uint256).max || currentDebt == amountRepay) {
      // **** FULL AMOUNT ****

      // Move assets to the contract
      IERC20(tokenLoan.underlyingAsset).safeTransferFrom(msgSender, address(this), currentDebt);
      // Repay full amount
      UTokenVault(_uTokenVault).repay(
        tokenLoan.underlyingAsset,
        loanId,
        currentDebt,
        address(this),
        msgSender
      );

      // Withdraw all assets
      for (uint i = 0; i < tokenLoan.assets.length; i++) {
        address asset = tokenLoan.assets[i];
        IERC20Vault(_erc20Vault).withdraw(asset, tokenLoan.collateral[asset], msgSender);
      }

      delete _tokenLoan[loanId];
      delete _loans[loanId];

      // EMIT EVENT FULL REPAY
    } else {
      // **** PARTIAL ****

      uint256 repayAmountUSD = amountRepay * priceUnit;
      uint256 totalValueUSD = 0;

      {
        //******* CALCULATE COLLATERAL*******/

        for (uint i = 0; i < tokenLoan.assets.length; i++) {
          // Need to follow the same order
          if (assets[i] != tokenLoan.assets[i]) revert('NEED_SAME_ORDER');

          address asset = tokenLoan.assets[i];
          DataTypes.TokenData memory tokenConfig = _tokenConfigs[asset];
          totalValueUSD += TokenLogic.calculateValueInUSD(
            tokenConfig,
            tokenLoan.collateral[asset] - amounts[i] // We remove from the calculation the withdraw
          );
        }
      }

      {
        //******* VALIDATE HF  *******/

        // We calculate DEBT
        uint256 updatedDebtUSDC = (currentDebt * priceUnit) - repayAmountUSD;

        // We calculate the current debt and the HF
        uint256 healthFactor = GenericLogic.calculateHealthFactorFromBalances(
          totalValueUSD,
          updatedDebtUSDC,
          _liquidationThreshold
        );

        // Check HF
        if (healthFactor <= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
          revert Errors.UnhealtyLoan();
        }
      }

      /////////////////////////////

      // Withdraw all assets
      for (uint i = 0; i < assets.length; i++) {
        address asset = assets[i];
        tokenLoan.collateral[asset] -= amounts[i];
        IERC20Vault(_erc20Vault).withdraw(asset, amounts[i], msgSender);
      }

      // EMIT EVENT PARTIAL REPAY
    }
  }

  function liquidation() external {
    // Check HF
    // Repay position and give bonus to the liquidator
    // Check HF of the position
  }
}
