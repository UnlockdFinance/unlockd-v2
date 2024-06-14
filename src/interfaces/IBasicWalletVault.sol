// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';

interface IBasicWalletVault is IProtocolOwner {
  // Struct to encapsulate information about an individual NFT transfer.
  // It holds the address of the ERC721 contract and the specific token ID to be transferred.
  struct NftTransfer {
    address contractAddress;
    uint256 tokenId;
  }

  struct FtTransfer {
    address contractAddress;
    uint256 amount;
    bool isETH;
  }

  //////////////////////////////////////////////////////////////
  //                           ERRORS
  //////////////////////////////////////////////////////////////
  error TransferFromFailed();
  error CantReceiveETH();
  error Fallback();

  function withdrawAssets(NftTransfer[] calldata nftTransfers, address to) external;

  function withdrawFt(FtTransfer[] calldata ftTransfers, address to) external;
}
