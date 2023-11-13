// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IUToken} from '../../interfaces/tokens/IUToken.sol';
import {MathUtils} from '../../libraries/math/MathUtils.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {GenericLogic, Errors, DataTypes} from './GenericLogic.sol';

// import {console} from 'forge-std/console.sol';

library SellNowLogic {
  using SafeERC20 for IERC20;

  struct RepayDebtAndUserParams {
    bytes32 loanId;
    uint256 aggLoanPrice;
    uint256 aggLtv;
    uint256 totalDebt;
    uint256 marketPrice;
    address underlyingAsset;
    address uToken;
    address owner;
  }

  function repayDebtAndUser(RepayDebtAndUserParams memory params) internal {
    uint256 calculatedMinDebt = GenericLogic.calculateAmountToArriveToLTV(
      params.aggLoanPrice,
      params.totalDebt,
      params.aggLtv
    );

    uint256 minRepay = MathUtils.minOf(calculatedMinDebt, params.marketPrice);
    if (minRepay > 0) {
      // Repay Owner debt to arrive ltv
      IERC20(params.underlyingAsset).safeApprove(params.uToken, minRepay);
      IUToken(params.uToken).repayOnBelhalf(params.loanId, minRepay, address(this), params.owner);
    }
    // Send benefits to the owner
    uint256 amountLeft = params.marketPrice - minRepay;
    if (amountLeft > 0) {
      IERC20(params.underlyingAsset).safeTransfer(params.owner, amountLeft);
    }
  }

  struct SellParams {
    DataTypes.SignSellNow signSellNow;
    DataTypes.Asset asset;
    bytes32 loanId;
    address wallet;
    address protocolOwner;
    address marketAdapter;
  }

  function sellAsset(SellParams memory params) internal {
    // Approve the sale
    IProtocolOwner(params.protocolOwner).delegateOneExecution(params.marketAdapter, true);
    IMarketAdapter(params.marketAdapter).preSell(
      IMarketAdapter.PreSellParams({
        loanId: params.signSellNow.loan.loanId,
        collection: params.asset.collection,
        tokenId: params.asset.tokenId,
        underlyingAsset: params.signSellNow.underlyingAsset,
        marketPrice: params.signSellNow.marketPrice,
        marketApproval: params.signSellNow.marketApproval,
        protocolOwner: params.protocolOwner
      })
    );

    // Buy the asset
    IProtocolOwner(params.protocolOwner).delegateOneExecution(params.marketAdapter, true);
    IMarketAdapter(params.marketAdapter).sell(
      IMarketAdapter.SellParams({
        wallet: params.wallet,
        protocolOwner: params.protocolOwner,
        underlyingAsset: params.signSellNow.underlyingAsset,
        marketPrice: params.signSellNow.marketPrice,
        to: params.signSellNow.to,
        value: params.signSellNow.value,
        data: params.signSellNow.data
      })
    );
  }
}
