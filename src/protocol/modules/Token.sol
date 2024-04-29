// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {ITokenModule} from '../../interfaces/modules/ITokenModule.sol';
import {IReserveOracle} from '../../interfaces/oracle/IReserveOracle.sol';
import {TokenLogic, DataTypes} from '@unlockd-wallet/src/libs/logic/TokenLogic.sol';
import {GenericLogic} from '@unlockd-wallet/src/libs/logic/GenericLogic.sol';

contract Token is BaseCoreModule, ITokenModule {
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
          underlyingAsset: signAction.underlyingAsset,
          totalAssets: 0, // TODO: Check if this could create inconsistences
          loanId: loanId
        })
      );
    }

    // Check previous balance
    DataTypes.TokenLoan memory loan = _tokenLoan[loanId];

    if (loan.underlyingAsset != address(0)) {
      // We calculate the previus amount deposited
      for (uint i = 0; i < loan.assets.length; i++) {
        address asset = loan.assets[i];
        uint256 amount = loan.amountAssets[i];

        DataTypes.TokenData tokenConfig = _tokenConfig[asset];
        totalValueLTVUSD += TokenLogic.calculateLTVInUSD(tokenConfig, amount);
      }
    }
    // Add new collateral
    for (uint i = 0; i < assets.length; i++) {
      address asset = assets[i];
      uint256 amount = amount[i];
      DataTypes.TokenData tokenConfig = _tokenConfig[asset];

      TokenLogic.transferAssets(tokenConfig, amount);
      totalValueLTVUSD += TokenLogic.calculateLTVInUSD(tokenConfig, amount);
      // Create UToken For each asset
    }

    uint256 currentDebt = GenericLogic.calculateLoanDebt(
      loanId,
      _uTokenVault,
      _loans[loanId].underlyingAsset
    );

    uint256 updatedDebt = currentDebt < amount ? 0 : currentDebt - amount;

    // We calculate the current debt and the HF
    uint256 healthFactor = GenericLogic.calculateHealthFactorFromBalances(
      totalValueLTVUSD,
      updatedDebt,
      _liquidationThreshold
    );

    UTokenVault(_uTokenVault).borrow(
      loan.underlyingAsset,
      loan.loanId,
      amount,
      msgSender,
      msgSender
    );
    // Deposit tokens
    // Get value tokens
    // Calculate HF
    //
    // - Add liquidity for this position
    // - Borrow with this tokens
  }

  function repay() external {
    // Return assets borrowed
    // Return amount ERC20
  }

  function liquidation() external {
    // Check HF
    // Repay position and give bonus to the liquidator
    // Check HF of the position
  }
}
