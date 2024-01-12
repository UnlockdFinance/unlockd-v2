// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {ICryptoPunks} from '../../interfaces/tokens/ICryptoPunks.sol';

contract SafeERC721 {
  address internal CRYPTO_PUNK;

  constructor(address cryptoPunks) {
    CRYPTO_PUNK = cryptoPunks;
  }

  function ownerOf(address collection, uint256 tokenId) external view returns (address) {
    if (collection == CRYPTO_PUNK) {
      return ICryptoPunks(collection).punkIndexToAddress(tokenId);
    }
    return IERC721(collection).ownerOf(tokenId);
  }
}
