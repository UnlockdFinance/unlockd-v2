// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface ISafeERC721 {
  function ownerOf(address collection, uint256 tokenId) external view returns (address);
}
