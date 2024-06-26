// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {ERC721Enumerable} from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

/**
 * @title MintableERC721
 * @dev ERC721 minting logic
 */
contract MintableERC721 is ERC721Enumerable {
  string public baseURI;
  address private owner;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    baseURI = 'https://MintableERC721/';
    owner = _msgSender();
  }

  function mint(uint256 tokenId) public returns (bool) {
    _mint(_msgSender(), tokenId);
    return true;
  }

  function mintToAddress(uint256 tokenId, address user) public returns (bool) {
    _mint(user, tokenId);
    return true;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function setBaseURI(string memory baseURI_) public {
    baseURI = baseURI_;
  }
}
