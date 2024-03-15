// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {console} from 'forge-std/console.sol';

contract NFTMarket is IERC1155Receiver {
  using SafeERC20 for IERC20;
  error LowAllowance();

  function sell(
    address nftAddress,
    uint256 tokenId,
    address underliyingAsset,
    uint256 price
  ) public payable {
    if (nftAddress == 0x927a51275a610Cd93e23b176670c88157bC48AF2) {
      require(IERC1155(nftAddress).balanceOf(msg.sender, tokenId) > 0, 'MOCK:SENDER NOT OWNER');
      IERC1155(nftAddress).safeTransferFrom(msg.sender, address(this), tokenId, 1, '');
    } else {
      require(IERC721(nftAddress).ownerOf(tokenId) == msg.sender, 'MOCK:SENDER NOT OWNER');
      IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
    }
    console.log(IERC20(underliyingAsset).balanceOf(address(this)));
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
    IERC20(underliyingAsset).safeTransferFrom(msg.sender, address(this), price);
    IERC721(nftAddress).transferFrom(address(this), taker, tokenId);
  }

  function onERC1155Received(
    address operator,
    address from,
    uint256 id,
    uint256 value,
    bytes calldata data
  ) external returns (bytes4) {
    return IERC1155Receiver.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint256[] calldata ids,
    uint256[] calldata values,
    bytes calldata data
  ) external returns (bytes4) {
    return IERC1155Receiver.onERC1155BatchReceived.selector;
  }

  function supportsInterface(bytes4 interfaceId) external view returns (bool) {
    return true;
  }
}
