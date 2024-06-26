// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title ICryptoPunksMarket
 * @author Unlockd
 * @notice Defines the basic interface to interact with PunksMarket.
 **/
interface ICryptoPunksMarket {
  function punkIndexToAddress(uint256 index) external view returns (address);
}

/**
 * @title NFTBatchTransfer
 * @dev This is a public contract in order to allow batch transfers of NFTs,
 * in a single transaction, reducing gas costs and improving efficiency.
 * It is designed to work with standard ERC721 contracts, as well as the CryptoPunks contract.
 * No events, use the ones from the ERC721 contract
 */
contract NFTBatchTransfer {
  /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/
  error TransferFromFailed();
  error BuyFailed();
  error TransferFailed();
  error NotOwner();
  error CantReceiveETH();
  error Fallback();

  /*//////////////////////////////////////////////////////////////
                           IMMUTABLES
    //////////////////////////////////////////////////////////////*/
  // Immutable address for the CryptoPunks contract. This is set at deployment and cannot be altered afterwards.
  address public immutable punkContract;

  /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
  // Struct to encapsulate information about an individual NFT transfer.
  // It holds the address of the ERC721 contract and the specific token ID to be transferred.
  struct NftTransfer {
    address contractAddress;
    uint256 tokenId;
  }

  /*//////////////////////////////////////////////////////////////
                          INITIALIZATION
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Constructor to set the initial state of the contract.
   * @param _punkContract The address of the CryptoPunks contract.
   */
  constructor(address _punkContract) {
    punkContract = _punkContract;
  }

  /*//////////////////////////////////////////////////////////////
                    Fallback and Receive Functions
    //////////////////////////////////////////////////////////////*/
  // Explicitly reject any Ether sent to the contract
  fallback() external payable {
    revert Fallback();
  }

  // Explicitly reject any Ether transfered to the contract
  receive() external payable {
    revert CantReceiveETH();
  }

  /*//////////////////////////////////////////////////////////////
                          LOGIC
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Orchestrates a batch transfer of standard ERC721 NFTs.
   * @param nftTransfers An array of NftTransfer structs detailing the NFTs to be moved.
   * @param to The recipient's address.
   */
  function batchTransferFrom(NftTransfer[] calldata nftTransfers, address to) external payable {
    uint256 length = nftTransfers.length;

    // Iterate through each NFT in the array to facilitate the transfer.
    for (uint i = 0; i < length; ) {
      address contractAddress = nftTransfers[i].contractAddress;
      uint256 tokenId = nftTransfers[i].tokenId;

      // Dynamically call the `transferFrom` function on the target ERC721 contract.
      (bool success, ) = contractAddress.call(
        abi.encodeWithSignature('transferFrom(address,address,uint256)', msg.sender, to, tokenId)
      );

      // Check the transfer status.
      if (!success) {
        revert TransferFromFailed();
      }

      // Use unchecked block to bypass overflow checks for efficiency.
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Manages a batch transfer of NFTs, that allow the use of
   * CryptoPunks alongside other standard ERC721 NFTs.
   * @param nftTransfers An array of NftTransfer structs specifying the NFTs for transfer.
   * @param to The destination address for the NFTs.
   */
  function batchPunkTransferFrom(NftTransfer[] calldata nftTransfers, address to) external payable {
    uint256 length = nftTransfers.length;
    bool success;

    // Process batch transfers, differentiate between CryptoPunks and standard ERC721 tokens.
    for (uint i = 0; i < length; ) {
      address contractAddr = nftTransfers[i].contractAddress;
      uint256 tokenId = nftTransfers[i].tokenId;

      // Check if the NFT is a CryptoPunk.
      if (contractAddr != punkContract) {
        // If it's not a CryptoPunk, use the standard ERC721 `transferFrom` function.
        (success, ) = contractAddr.call(
          abi.encodeWithSignature('transferFrom(address,address,uint256)', msg.sender, to, tokenId)
        );
      }
      // If it's a CryptoPunk, use the CryptoPunksMarket contract to transfer the punk.
      else {
        // Verify OwnerShip
        if (ICryptoPunksMarket(punkContract).punkIndexToAddress(tokenId) != msg.sender)
          revert NotOwner();

        // If it's a CryptoPunk, first the contract buy the punk to be allowed to transfer it.
        (success, ) = punkContract.call{value: 0}(
          abi.encodeWithSignature('buyPunk(uint256)', tokenId)
        );

        // Check the buyPunk status
        if (!success) {
          revert BuyFailed();
        }

        // Once the punk is owned by the contract, the transfer method is executed
        (success, ) = punkContract.call(
          abi.encodeWithSignature('transferPunk(address,uint256)', to, tokenId)
        );

        // Check the transfer status.
        if (!success) {
          revert TransferFailed();
        }
      }

      // Use unchecked block to bypass overflow checks for efficiency.
      unchecked {
        i++;
      }
    }
  }
}
