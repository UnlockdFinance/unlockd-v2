// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract UnlockdHelper {
  function getAssetId(address collection, uint256 tokenId) external pure returns (bytes32) {
    return keccak256(abi.encodePacked(collection, tokenId));
  }

  function getEncodedAssetId(
    address collection,
    uint256 tokenId
  ) external pure returns (bytes memory) {
    return abi.encodePacked(collection, tokenId);
  }

  function getOrderId(bytes32 assetId, bytes32 loanId) external pure returns (bytes32) {
    return keccak256(abi.encodePacked(loanId, assetId));
  }
}
