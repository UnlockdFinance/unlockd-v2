// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {Initializable} from '@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol';
import {ERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {IMarketAdapter} from '../../../src/interfaces/adapter/IMarketAdapter.sol';
import {IACLManager} from '../../../src/interfaces/IACLManager.sol';
import {DataTypes} from '../../../src/types/DataTypes.sol';

import {console} from 'forge-std/console.sol';

contract MockAdapter is IMarketAdapter {
  address private _aclManager;
  address private RESERVOIR;
  address private ETH_RESERVOIR;

  modifier onlyAdmin() {
    require(IACLManager(_aclManager).isProtocol(msg.sender), 'CALLER_NOT_ADMIN');
    _;
  }

  constructor(address reservoir, address aclManager, address eth) {
    RESERVOIR = reservoir;
    ETH_RESERVOIR = eth;
    _aclManager = aclManager;
  }

  function preSell(PreSellParams memory params) external payable {
    // Nothing to do
  }

  function sell(SellParams memory params) external payable onlyAdmin {
    // Send the amount to the address specified
    IERC20(params.underlyingAsset).transferFrom(address(this), params.to, params.marketPrice);
  }

  function preBuy(PreBuyParams memory params) external payable {
    // Nothing to do
  }

  function buy(BuyParams memory params) external payable onlyAdmin returns (uint256) {
    if (params.underlyingAsset == ETH_RESERVOIR) {
      require(address(this).balance == params.value, 'MOCK:NO_ENOUGHT_AMOUNT');
    } else {
      require(
        IERC20(params.underlyingAsset).balanceOf(address(this)) == params.marketPrice,
        'MOCK:NOT_ENOUGHT_AMOUNT'
      );
    }
    // ERC721(params.collection).transferFrom(address(this), params.to, params.tokenId);

    return address(this).balance;
  }
}
