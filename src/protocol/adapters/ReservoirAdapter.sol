// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IMarketAdapter} from '../../interfaces/adapter/IMarketAdapter.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {DataTypes} from '../../types/DataTypes.sol';

contract ReservoirAdapter is IMarketAdapter {
  using SafeERC20 for IERC20;
  using Address for address;
  address private immutable RESERVOIR;
  address private immutable ETH_RESERVOIR;
  address private immutable _aclManager;

  ///////////////////////////////////////////////
  // MODIFIERS
  ///////////////////////////////////////////////
  modifier onlyAdmin() {
    if (IACLManager(_aclManager).isProtocolAdmin(msg.sender) == false) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }
  modifier onlyProtocol() {
    if (IACLManager(_aclManager).isProtocol(msg.sender) == false) {
      revert Errors.AccessDenied();
    }
    _;
  }

  constructor(address reservoir, address aclManager, address eth) {
    RESERVOIR = reservoir;
    ETH_RESERVOIR = eth;
    _aclManager = aclManager;
  }

  function preSell(PreSellParams memory params) public payable onlyProtocol {
    IProtocolOwner(params.protocolOwner).approveSale(
      params.collection,
      params.tokenId,
      params.underlyingAsset,
      params.marketPrice,
      params.marketApproval,
      params.loanId
    );
  }

  function sell(SellParams memory params) public payable onlyProtocol {
    IProtocolOwner(params.protocolOwner).execTransaction(
      params.to,
      params.value,
      params.data,
      0,
      0,
      0,
      address(0),
      payable(0)
    );
    // We move the funds from the wallet to the sender
    IERC20(params.underlyingAsset).safeTransferFrom(params.wallet, msg.sender, params.marketPrice);
  }

  function preBuy(PreBuyParams memory params) public payable onlyProtocol {
    // NOTHING TO DO
  }

  function buy(BuyParams memory params) public payable onlyProtocol returns (uint256) {
    uint256 initialBalance = _getBalance(params.underlyingAsset);
    // Make the approval
    if (params.underlyingAsset != ETH_RESERVOIR) {
      IERC20(params.underlyingAsset).approve(params.marketApproval, params.marketPrice);
    }
    // Run the transaction
    _rawExec(params.to, params.value, params.data);
    // Calcualte end balance
    uint256 endBalance = _getBalance(params.underlyingAsset);
    // Calculate real cost
    uint256 realCost = initialBalance - endBalance;

    return realCost;
  }

  function withdraw(address payable _to) external onlyProtocol {
    (bool sent, ) = _to.call{value: address(this).balance}('');
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }

  function withdrawERC20(address payable _to) external onlyProtocol {
    (bool sent, ) = _to.call{value: address(this).balance}('');
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }

  function _rawExec(address to, uint256 value, bytes memory data) private {
    // Ensure the target is a contract

    (bool sent, ) = payable(to).call{value: value}(data);
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }

  function _getBalance(address currency) internal view returns (uint256) {
    if (currency == ETH_RESERVOIR) {
      return address(this).balance;
    }
    return IERC20(currency).balanceOf(address(this));
  }

  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}
}
