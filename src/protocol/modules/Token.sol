// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BaseCoreModule} from '../../libraries/base/BaseCoreModule.sol';
import {ITokenModule} from '../../interfaces/modules/ITokenModule.sol';
import {IReserveOracle} from '../../interfaces/oracle/IReserveOracle.sol';
import {TokenLogic, DataTypes} from '@unlockd-wallet/src/libs/logic/TokenLogic.sol';

contract Token is BaseCoreModule, ITokenModule {
  constructor(uint256 moduleId_, bytes32 moduleVersion_) BaseCoreModule(moduleId_, moduleVersion_) {
    // NOTHING TO DO
  }

  function borrow(
    address[] calldata assets,
    uint256[] calldata amounts,
    address underlyingAsset,
    uint256 borrowAmount
  ) external {
    address msgSender = unpackTrailingParamMsgSender();

    uint256 priceUnit = IReserveOracle(_reserveOracle).getAssetPrice(underlyingAsset);
    uint256 borrowAmountUSD = borrowAmount * priceUnit;
    uint256 totalValueUSD = 0;

    // Create Loan

    bytes32 loanId = LoanLogic.generateId(msgSender, 0, block.timestamp);

    _loans[loanId].createLoan(
      LoanLogic.ParamsCreateLoan({
        msgSender: msgSender,
        underlyingAsset: signAction.underlyingAsset,
        // We added only when we lock the assets
        totalAssets: 0,
        loanId: loanId
      })
    );

    // Move Collateral

    for (uint i = 0; i < assets.length; i++) {
      address asset = assets[i];
      uint256 amount = amount[i];
      DataTypes.TokenData tokenConfig = _tokenConfig[asset];

      TokenLogic.transferAssets(tokenConfig, amount);
      totalValueUSD += TokenLogic.calculateLTVInUSD(tokenConfig, amount);
    }

    if (borrowAmountUSD > totalValueUSD) revert Errors.InvalidAmount();

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
