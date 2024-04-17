import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';

interface IBasicWalletVault is IProtocolOwner {
  // Struct to encapsulate information about an individual NFT transfer.
  // It holds the address of the ERC721 contract and the specific token ID to be transferred.
  struct NftTransfer {
    address contractAddress;
    uint256 tokenId;
  }

  //////////////////////////////////////////////////////////////
  //                           ERRORS
  //////////////////////////////////////////////////////////////
  error TransferFromFailed();
  error CantReceiveETH();
  error Fallback();

  function withdrawAssets(NftTransfer[] calldata nftTransfers, address to) external;
}