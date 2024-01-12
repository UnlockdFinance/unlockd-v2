// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

interface IWETHGateway {
  function supplyETH(address onBehalfOf) external payable;

  function withdrawETH(uint256 amount, address to) external;
}
