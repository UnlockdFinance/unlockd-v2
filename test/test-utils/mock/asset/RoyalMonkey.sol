// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

import '@openzeppelin/contracts/utils/Strings.sol';

contract RoyalMonkey is ERC721Enumerable, ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  constructor() ERC721('RoyalMonkey', 'RMK') {}

  function _baseURI() internal pure override returns (string memory) {
    return 'https://ipfs.io/ipfs/QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/';
  }

  function mint() public {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(msg.sender, tokenId);
  }

  function mintToAddress(uint256 tokenId, address user) public returns (bool) {
    _safeMint(user, tokenId);
    return true;
  }

  function bachMint() public {
    for (uint i = 0; i < 10; i++) {
      mint();
    }
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(
    uint256 tokenId
  ) public pure override(ERC721, ERC721URIStorage) returns (string memory) {
    return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId)));
  }

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721URIStorage, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
