// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface IUTokenWrapper6960 {
    
  function mint(address to, uint256 mainId, uint256 subId) external;

  function burn(uint256 tokenId) external;

  function wrappedMaxAmount() external returns (uint256);

  function collection() external returns (address);

  function wrappedMainId(uint256 tokenId) external returns (uint256);

  function wrappedSubId(uint256 tokenId) external returns (uint256);

  function wrappedIds(uint256 tokenId) external returns (uint256, uint256);
  
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
