// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/**
 * @dev {IERC11554K} interface:
 */
interface IERC11554K {
  function owner() external view returns (address);

  function balanceOf(address user, uint256 item) external view returns (uint256);

  function royaltyInfo(
    uint256 _tokenId,
    uint256 _salePrice
  ) external view returns (address, uint256);

  function totalSupply(uint256 _tokenId) external view returns (uint256);
}
