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

contract Token is BaseCoreModule, ITokenModule {
  using LoanLogic for DataTypes.Loan;

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
      revert();

      //   // We calculate the previus amount deposited
      //   for (uint i = 0; i < loan.assets.length; i++) {
      //     address asset = loan.assets[i];
      //     uint256 amount = loan.amountAssets[i];

      //     DataTypes.TokenData tokenConfig = _tokenConfig[asset];
      //     totalValueLTVUSD += TokenLogic.calculateLTVInUSD(tokenConfig, amount);
      //   }
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
        tokenLoan.collateral[asset] = amount;

        DataTypes.TokenData memory tokenConfig = _tokenConfigs[asset];
        // Transfer the assets
        TokenLogic.transferAssets(tokenConfig, amount);

        totalValueLTVUSD += TokenLogic.calculateLTVInUSD(tokenConfig, amount);
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

    UTokenVault(_uTokenVault).borrow(underlyingAsset, loanId, borrowAmount, msgSender, msgSender);
  }

  function repay(bytes32 loanId, uint256 amount) external {
    // Return assets borrowed
    // Return amount ERC20
  }

  function liquidation() external {
    // Check HF
    // Repay position and give bonus to the liquidator
    // Check HF of the position
  }
}
