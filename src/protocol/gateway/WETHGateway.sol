// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {WadRayMath} from '../../libraries/math/WadRayMath.sol';

import {IWETH} from '../../interfaces/tokens/IWETH.sol';
import {IWETHGateway} from '../../interfaces/IWETHGateway.sol';
import {IUTokenVault} from '../../interfaces/IUTokenVault.sol';

import {DataTypes} from '../../types/DataTypes.sol';

contract WETHGateway is IWETHGateway, Ownable {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  IWETH internal immutable WETH;
  IUTokenVault internal immutable IUTOKEN;
  address internal immutable SCALEDTOKEN;

  /**
   * @dev Sets the WETH address and the LendingPoolAddressesProvider address. Infinite approves lending pool.
   * @param weth Address of the Wrapped Ether contract
   **/
  constructor(address weth, address uTokenVault) {
    WETH = IWETH(weth);
    IUTOKEN = IUTokenVault(uTokenVault);
    SCALEDTOKEN = IUTOKEN.getScaledToken(weth);
  }

  function authorizeProtocol(address uTokenVault) external onlyOwner {
    WETH.approve(uTokenVault, type(uint256).max);
  }

  function depositETH(address onBehalfOf) external payable override {
    WETH.deposit{value: msg.value}();
    IUTOKEN.deposit(address(WETH), msg.value, onBehalfOf);
  }

  function withdrawETH(uint256 amount, address to) external override {
    uint256 amountToWithdraw = amount;
    uint256 scaledAmount;
    if (type(uint256).max == amount) {
      amountToWithdraw = IUTOKEN.getBalanceByUser(address(WETH), msg.sender);
      scaledAmount = IERC20(SCALEDTOKEN).balanceOf(msg.sender);
    } else {
      amountToWithdraw = amount;
      // We update the index
      IUTOKEN.updateState(address(WETH));
      DataTypes.ReserveData memory reserve = IUTOKEN.getReserveData(address(WETH));
      scaledAmount = amountToWithdraw.rayDiv(reserve.liquidityIndex);
    }
    IERC20(SCALEDTOKEN).safeTransferFrom(msg.sender, address(this), scaledAmount);
    IUTOKEN.withdraw(address(WETH), amountToWithdraw, address(this));
    WETH.withdraw(amountToWithdraw);
    _safeTransferETH(to, amountToWithdraw);
  }

  /**
   * @dev transfer ETH to an address, revert if it fails.
   * @param to recipient of the transfer
   * @param value the amount to send
   */
  function _safeTransferETH(address to, uint256 value) internal {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, 'ETH_TRANSFER_FAILED');
  }

  /**
   * @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
   * direct transfers to the contract address.
   * @param token token to transfer
   * @param to recipient of the transfer
   * @param amount amount to send
   */
  function emergencyTokenTransfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).transfer(to, amount);
  }

  /**
   * @dev transfer native Ether from the utility contract, for native Ether recovery in case of stuck Ether
   * due selfdestructs or transfer ether to pre-computated contract address before deployment.
   * @param to recipient of the transfer
   * @param amount amount to send
   */
  function emergencyEtherTransfer(address to, uint256 amount) external onlyOwner {
    _safeTransferETH(to, amount);
  }

  /**
   * @dev Get WETH address used by WETHGateway
   */
  function getWETHAddress() external view returns (address) {
    return address(WETH);
  }

  /**
   * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
   */
  receive() external payable {
    require(msg.sender == address(WETH), 'Receive not allowed');
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert('Fallback not allowed');
  }
}
