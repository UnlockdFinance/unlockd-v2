// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../../types/DataTypes.sol';
import {GenericLogic} from './GenericLogic.sol';

/**
 * @title AssetLogic library
 * @author Unlockd
 * @notice Implements the logic to sign the asset
 */
library AssetLogic {
  bytes32 internal constant TYPEHASH =
    0x952d72a21d7cc0fcc1bc09ed86fbffc8c63ecf57742377a17e9461f7a2d704fd;

  /**
   * @dev return the Asset struct hashed
   * @param nonce nonce of the struct
   * @param signAsset struct of the asset to hash
   *
   */
  function getAssetStructHash(
    uint256 nonce,
    DataTypes.SignAsset calldata signAsset
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          TYPEHASH,
          signAsset.assetId,
          signAsset.collection,
          signAsset.tokenId,
          signAsset.price,
          nonce,
          signAsset.deadline
        )
      );
  }
}
