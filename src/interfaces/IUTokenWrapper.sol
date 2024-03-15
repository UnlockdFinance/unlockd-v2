// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IUTokenWrapper {
  function mint(address to, uint256 tokenId) external;

  function burn(uint256 tokenId) external;

  function wrappedMaxAmount() external returns (uint256);

  function collection() external returns (address);

  function wrappedTokenId(uint256 tokenId) external returns (uint256);

  function sellOnMarket(
    address underlyingAsset,
    uint256 marketPrice,
    address marketApproval,
    uint256 tokenId,
    address to,
    uint256 value,
    bytes memory data,
    address amountTo
  ) external;
}
