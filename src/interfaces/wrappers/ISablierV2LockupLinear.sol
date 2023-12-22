// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISablierV2LockupLinear {

    /*//////////////////////////////////////////////////////////////
                           STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Struct encapsulating the deposit, withdrawn, and refunded amounts, all denoted in units
    /// of the asset's decimals.
    /// @dev Because the deposited and the withdrawn amount are often read together, declaring them in
    /// the same slot saves gas.
    /// @param deposited The initial amount deposited in the stream, net of fees.
    /// @param withdrawn The cumulative amount withdrawn from the stream.
    /// @param refunded The amount refunded to the sender. Unless the stream was canceled, this is always zero.
    struct Amounts {
        // slot 0
        uint128 deposited;
        uint128 withdrawn;
        // slot 1
        uint128 refunded;
    }

    /// @notice Lockup Linear stream.
    /// @dev The fields are arranged like this to save gas via tight variable packing.
    /// @param sender The address streaming the assets, with the ability to cancel the stream.
    /// @param startTime The Unix timestamp indicating the stream's start.
    /// @param cliffTime The Unix timestamp indicating the cliff period's end.
    /// @param isCancelable Boolean indicating if the stream is cancelable.
    /// @param wasCanceled Boolean indicating if the stream was canceled.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param endTime The Unix timestamp indicating the stream's end.
    /// @param isDepleted Boolean indicating if the stream is depleted.
    /// @param isStream Boolean indicating if the struct entity exists.
    /// @param isTransferable Boolean indicating if the stream NFT is transferable.
    /// @param amounts Struct containing the deposit, withdrawn, and refunded amounts, all denoted in units of the
    /// asset's decimals.
    struct Stream {
        // slot 0
        address sender;
        uint40 startTime;
        uint40 cliffTime;
        bool isCancelable;
        bool wasCanceled;
        // slot 1
        IERC20 asset;
        uint40 endTime;
        bool isDepleted;
        bool isStream;
        bool isTransferable;
        // slot 2 and 3
        Amounts amounts;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721 COMPATIBLE
    //////////////////////////////////////////////////////////////*/
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                        ISABLIERV2LOCKUPLINEAR
    //////////////////////////////////////////////////////////////*/
    function getAsset(uint256 streamId) external view returns (IERC20 asset);
    function getStream(uint256 streamId) external view returns (Stream memory stream);
    function isCancelable(uint256 streamId) external view returns (bool result);
    function isStream(uint256 streamId) external view returns (bool result);
    function withdrawableAmountOf(uint256 streamId) external view returns (uint128 withdrawableAmount);
    function withdraw(uint256 streamId, address to, uint128 amount) external;
    function withdrawMax(uint256 streamId, address to) external;
}