// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {console} from 'forge-std/console.sol';

contract NFTMarket {
  using SafeERC20 for IERC20;
  error LowAllowance();

  function sell(
    address nftAddress,
    uint256 tokenId,
    address underliyingAsset,
    uint256 price
  ) public {
    require(IERC721(nftAddress).ownerOf(tokenId) == msg.sender, 'MOCK:SENDER NOT OWNER');
    IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
    IERC20(underliyingAsset).transferFrom(address(this), msg.sender, price);
  }

  function buy(
    address taker,
    address nftAddress,
    uint256 tokenId,
    address underliyingAsset,
    uint256 price
  ) public {
    if (IERC20(underliyingAsset).allowance(msg.sender, address(this)) < price) {
      revert LowAllowance();
    }
    console.log('TRANSFER MONEY > ', IERC20(underliyingAsset).balanceOf(msg.sender));
    IERC20(underliyingAsset).safeTransferFrom(msg.sender, address(this), price);
    console.log('TRANSFER ASSET');
    IERC721(nftAddress).transferFrom(address(this), taker, tokenId);
  }
}
