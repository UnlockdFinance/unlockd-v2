// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;
 
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol'; 
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IUTokenWrapper6960} from '../../interfaces/IUTokenWrapper6960.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol'; 

import {BaseEmergency} from '../../libraries/base/BaseEmergency.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract PolytradeAdapter is BaseEmergency, IMarketAdapter, IERC721Receiver {
  
  using Address for address;
  address private immutable POLYTRADE_MARKET;
  address private immutable ETH_ADDRESS;

  ///////////////////////////////////////////////
  // MODIFIERS
  ///////////////////////////////////////////////

  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.AccessDenied();
    }
    _;
  }

  constructor(address aclManager, address market, address eth) BaseEmergency(aclManager) {
    POLYTRADE_MARKET = market;
    ETH_ADDRESS = eth;
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
    IUTokenWrapper6960(params.collection).sellOnMarket(
      params.underlyingAsset,
      params.marketPrice,
      params.marketApproval,
      params.tokenId,
      params.to,
      params.value,
      params.data,
      msg.sender
    );
  }

  function preBuy(PreBuyParams memory) public payable onlyProtocol {
    // NOTHING TO DO
  }

  function buy(BuyParams memory) public payable onlyProtocol returns (uint256) {
    return 0;
  }

  receive() external payable {}

  fallback() external payable {}

  /**
   * @dev See {ERC721-onERC721Received}.
   */
  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }
}
