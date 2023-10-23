// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import { IGnosisSafe } from "../../interfaces/IGnosisSafe.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICryptoPunks } from "../../interfaces/ICryptoPunks.sol";
import { Errors } from "../helpers/Errors.sol";

library SafeLogic {
    function _transferERC721Payload(
        address _asset,
        uint256 _id,
        address _receiver,
        address _safe
    ) internal view returns (bytes memory) {
        // safe should be owner
        if (IERC721(_asset).ownerOf(_id) != _safe) revert Errors.DelegationOwner__transferAsset_assetNotOwned();

        return abi.encodeWithSelector(IERC721.transferFrom.selector, _safe, _receiver, _id);
    }

    function _transferPunksPayload(
        address _asset,
        uint256 _id,
        address _receiver,
        address _safe
    ) internal view returns (bytes memory) {
        // safe should be owner
        if (ICryptoPunks(_asset).punkIndexToAddress(_id) != _safe)
            revert Errors.DelegationOwner__transferAsset_assetNotOwned();

        return abi.encodeWithSelector(ICryptoPunks.transferPunk.selector, _receiver, _id);
    }

    // TODO: Check if this is safe
    function _approvePunksPayload(
        address _asset,
        uint256 _id,
        address _receiver,
        address _safe
    ) internal view returns (bytes memory) {
        // safe should be owner
        if (ICryptoPunks(_asset).punkIndexToAddress(_id) != _safe)
            revert Errors.DelegationOwner__approveAsset_assetNotOwned();

        return abi.encodeWithSelector(ICryptoPunks.offerPunkForSaleToAddress.selector, _receiver, 0, _id);
    }

    function _approveERC721Payload(
        address _asset,
        uint256 _id,
        address _receiver,
        address _safe
    ) internal view returns (bytes memory) {
        // safe should be owner
        if (IERC721(_asset).ownerOf(_id) != _safe) revert Errors.DelegationOwner__approveAsset_assetNotOwned();

        return abi.encodeWithSelector(IERC721.approve.selector, _receiver, _id);
    }

    function _approveERC20Payload(
        address _asset,
        uint256 _amount,
        address _receiver,
        address _safe
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(IERC20.approve.selector, _receiver, _amount);
    }
}
