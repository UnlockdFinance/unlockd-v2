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

    /// @notice Struct encapsulating the cliff duration and the total duration.
    /// @param cliff The cliff duration in seconds.
    /// @param total The total duration in seconds.
    struct Durations {
        uint40 cliff;
        uint40 total;
    }

    /// @notice Struct encapsulating the broker parameters passed to the create functions. Both can be set to zero.
    /// @param account The address receiving the broker's fee.
    /// @param fee The broker's percentage fee from the total amount, denoted as a fixed-point number where 1e18 is 100%.
    struct Broker {
        address account;
        uint256 fee; //UD60x18
    }

    /// @notice Struct encapsulating the parameters for the {SablierV2LockupLinear.createWithDurations} function.
    /// @param sender The address streaming the assets, with the ability to cancel the stream. It doesn't have to be the
    /// same as `msg.sender`.
    /// @param recipient The address receiving the assets.
    /// @param totalAmount The total amount of ERC-20 assets to be paid, including the stream deposit and any potential
    /// fees, all denoted in units of the asset's decimals.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param cancelable Indicates if the stream is cancelable.
    /// @param transferable Indicates if the stream NFT is transferable.
    /// @param durations Struct containing (i) cliff period duration and (ii) total stream duration, both in seconds.
    /// @param broker Struct containing (i) the address of the broker assisting in creating the stream, and (ii) the
    /// percentage fee paid to the broker from `totalAmount`, denoted as a fixed-point number. Both can be set to zero.
    struct CreateWithDurations {
        address sender;
        address recipient;
        uint128 totalAmount;
        IERC20 asset;
        bool cancelable;
        Durations durations;
        Broker broker;
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
    
    function createWithDurations(CreateWithDurations calldata params)
        external
        returns (uint256 streamId);

    function withdrawableAmountOf(uint256 streamId) external view returns (uint128 withdrawableAmount);
    function withdraw(uint256 streamId, address to, uint128 amount) external;
    function withdrawMax(uint256 streamId, address to) external;
}