// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {Initializable} from '@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20Upgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol';

contract MockYVault is ERC20 {
  using SafeERC20 for IERC20;

  IERC20Upgradeable public _underlyingAsset;
  uint256 internal _lock = 1;

  constructor(address asset) ERC20('YVault', 'yWETH') {
    _underlyingAsset = IERC20Upgradeable(asset);
  }

  function token() external view returns (address) {
    return address(_underlyingAsset);
  }

  function totalAssets() external view returns (uint256) {
    return balanceOf(address(this));
  }

  /**
   * @dev Returns the price per share in the vault
   * @return value representing the price per share
   */
  function pricePerShare() external pure returns (uint256) {
    return 1 ether;
  }

  function deposit(uint256 amount) external {
    _underlyingAsset.transferFrom(msg.sender, address(this), amount);
    _mint(msg.sender, amount);
  }

  function withdraw(uint256 amount) external returns (uint256) {
    _burn(msg.sender, amount);
    _underlyingAsset.transfer(msg.sender, amount);

    return amount;
  }

  function balanceOf(address user) public view virtual override returns (uint256) {
    return super.balanceOf(user);
  }
}
