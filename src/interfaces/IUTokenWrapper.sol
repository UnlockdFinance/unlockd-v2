// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IUTokenWrapper {
  function mint(address to, uint256 tokenId) external;

  function burn(address to, uint256 tokenId) external;

  function preMintChecks(address, uint256 tokenId) external view;

  function wrappedMaxAmount() external returns (uint256);

  function collection() external returns (address);

  function wrappedTokenId(uint256 tokenId) external returns (uint256);
}
