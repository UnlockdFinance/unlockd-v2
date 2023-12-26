// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import '../mock/asset/MintableERC721.sol';

using NFTs for NFTsState global;

struct NFTsState {
  uint256 count;
  address[] collections;
  mapping(string => mapping(address => uint256[])) minted;
  mapping(string => MintableERC721) list;
}

library NFTs {
  function get(NFTsState storage self, string memory name) internal view returns (address) {
    return address(self.list[name]);
  }

  function totalSupply(NFTsState storage self, string memory name) internal view returns (uint256) {
    MintableERC721 asset = self.list[name];
    return asset.totalSupply();
  }

  function newAsset(NFTsState storage self, string memory name) internal returns (MintableERC721) {
    MintableERC721 asset = new MintableERC721(name, name);

    self.list[name] = asset;
    self.collections.push(address(asset));
    return asset;
  }

  function mintToAddress(
    NFTsState storage self,
    address addr,
    string memory name,
    uint256 tokenId
  ) internal {
    MintableERC721 asset = self.list[name];
    require(
      address(asset) != 0x0000000000000000000000000000000000000000,
      'Mock Asset NFT not created '
    );
    asset.mintToAddress(tokenId, addr);
    self.minted[name][addr].push(tokenId);
  }

  function transfer(
    NFTsState storage self,
    string memory name,
    address from,
    address to,
    uint256 tokenId
  ) internal {
    MintableERC721 asset = self.list[name];
    asset.safeTransferFrom(from, to, tokenId);
  }
}
