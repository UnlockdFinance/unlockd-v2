// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../helpers/HelperNFT.sol'; // solhint-disable-line

contract NFTBase {
  // NFTs
  NFTsState internal _nfts;

  // Asset utils
  function approveNFTAsset(string memory asset, address to, uint256 tokenId) internal {
    MintableERC721(_nfts.get(asset)).approve(to, tokenId);
  }

  function ownerOf(string memory asset, uint256 tokenId) internal view returns (address) {
    return MintableERC721(_nfts.get(asset)).ownerOf(tokenId);
  }
}
