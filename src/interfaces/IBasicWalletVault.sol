// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';

interface IBasicWalletVault is IProtocolOwner {
  // Struct to encapsulate information about an individual NFT transfer.
  // It holds the address of the ERC721 contract and the specific token ID to be transferred.
  struct AssetTransfer {
    address contractAddress;
    uint256 value;
    bool isERC20;
  }

  //////////////////////////////////////////////////////////////
  //                           ERRORS
  //////////////////////////////////////////////////////////////
  error TransferFromFailed();
  error CantReceiveETH();
  error Fallback();

  function withdrawAssets(AssetTransfer[] calldata assetTransfers, address to) external;
}
