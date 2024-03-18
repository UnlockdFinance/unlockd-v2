// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import './IERC11554K.sol';

/**
 * @dev {IERC11554KController} interface:
 */
interface IERC11554KController {
  function owner() external returns (address);

  function originators(address collection, uint256 tokenId) external returns (address);

  function isActiveCollection(address collection) external view returns (bool);

  function isLinkedCollection(address collection) external returns (bool);

  function maxMintPeriod() external returns (uint256);

  function guardians() external view returns (address);
}
