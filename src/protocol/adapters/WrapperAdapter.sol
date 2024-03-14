// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IUTokenWrapper} from '../../interfaces/IUTokenWrapper.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';

import {BaseEmergency} from '../../libraries/base/BaseEmergency.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract WrapperAdapter is BaseEmergency, IMarketAdapter {
  using SafeERC20 for IERC20;
  using Address for address;
  address private immutable RESERVOIR;
  address private immutable ETH_RESERVOIR;

  ///////////////////////////////////////////////
  // MODIFIERS
  ///////////////////////////////////////////////

  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.AccessDenied();
    }
    _;
  }

  constructor(address aclManager, address reservoir, address eth) BaseEmergency(aclManager) {
    RESERVOIR = reservoir;
    ETH_RESERVOIR = eth;
  }

  function preSell(PreSellParams memory params) public payable onlyProtocol {
    // We need to approve the market inside of the WRAP
    IProtocolOwner(params.protocolOwner).approveSale(
      params.collection,
      params.tokenId,
      params.underlyingAsset,
      0,
      address(this),
      params.loanId
    );
  }

  function sell(SellParams memory params) public payable onlyProtocol {
    // Move the asset inside of the adapter
    IERC721(params.collection).safeTransferFrom(params.wallet, address(this), params.tokenId, '');
    // Execute the sell
    IUTokenWrapper(params.collection).sellOnMarket(
      params.underlyingAsset,
      params.marketPrice,
      params.marketApproval,
      params.tokenId,
      params.to,
      params.value,
      params.data
    );
    // We move the funds from the wallet to the sender
    IERC20(params.underlyingAsset).safeTransferFrom(params.wallet, msg.sender, params.marketPrice);
  }

  function preBuy(PreBuyParams memory) public payable onlyProtocol {
    // NOTHING TO DO
  }

  function buy(BuyParams memory) public payable onlyProtocol returns (uint256) {
    return 0;
  }

  receive() external payable {}

  fallback() external payable {}
}
