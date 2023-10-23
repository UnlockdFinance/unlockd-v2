// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;
import { Guard } from "@gnosis.pm/safe-contracts/contracts/base/GuardManager.sol";
import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { IGnosisSafe } from "../../interfaces/IGnosisSafe.sol";
import { IACLManager } from "../../interfaces/IACLManager.sol";
import { AssetLogic } from "../logic/AssetLogic.sol";
import { SafeLogic } from "../logic/SafeLogic.sol";
import { Errors } from "../helpers/Errors.sol";

import { ISignatureValidator } from "@gnosis.pm/safe-contracts/contracts/interfaces/ISignatureValidator.sol";

contract BaseSafeOwner is ISignatureValidator {
    /**
     * @notice Execution protect
     */
    bool internal isExecuting;
    bytes32 internal currentTxHash;
    /**
     * @notice Address of cryptoPunks
     */
    address public immutable cryptoPunks;
    /**
     * @notice The ACLManager address implementatiuon.
     */
    address public immutable aclManager;

    /**
     * @notice Safe wallet address.
     */
    address public safe;
    /**
     * @notice The owner of the DelegationWallet, it is set only once upon initialization. Since this contract works
     * in tandem with DelegationGuard which do not allow to change the Safe owners, this owner can't change neither.
     */
    address public owner;

    constructor(address _cryptoPunks, address _aclManager) {
        cryptoPunks = _cryptoPunks;
        aclManager = _aclManager;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Modifiers
    ////////////////////////////////////////////////////////////////////////////////
    /**
     * @notice This modifier indicates that only the Delegation Controller can execute a given function.
     */
    modifier onlyOwner() {
        if (owner != msg.sender) revert Errors.DelegationOwner__onlyOwner();
        _;
    }

    modifier onlyProtocol() {
        if (IACLManager(aclManager).isProtocol(msg.sender) == false) revert Errors.Caller_notProtocol();
        _;
    }

    modifier onlyGov() {
        if (IACLManager(aclManager).isGovernanceAdmin(msg.sender) == false) revert Errors.Caller_notGovernanceAdmin();
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Public
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns the hash of the NFTs.
     */
    function assetId(address _asset, uint256 _id) external pure returns (bytes32) {
        return AssetLogic.assetId(_asset, _id);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Private
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Transfer an asset owned by the safe.
     */
    function _transferAsset(address _asset, uint256 _id, address _receiver) internal returns (bool) {
        bytes memory payload = _asset == cryptoPunks
            ? SafeLogic._transferPunksPayload(_asset, _id, _receiver, safe)
            : SafeLogic._transferERC721Payload(_asset, _id, _receiver, safe);

        isExecuting = true;
        currentTxHash = IGnosisSafe(payable(safe)).getTransactionHash(
            _asset,
            0,
            payload,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            IGnosisSafe(payable(safe)).nonce()
        );

        // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
        bytes memory signature = abi.encodePacked(
            abi.encode(address(this)), // r
            abi.encode(uint256(65)), // s
            bytes1(0), // v
            abi.encode(currentTxHash.length),
            currentTxHash
        );

        bool success = IGnosisSafe(safe).execTransaction(
            _asset,
            0,
            payload,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );

        isExecuting = false;
        currentTxHash = bytes32(0);

        return success;
    }

    /**
     * @notice Approve an asset owned by the safe wallet.
     */
    function _approveAsset(address _asset, uint256 _id, address _receiver) internal returns (bool) {
        bytes memory payload = _asset == cryptoPunks
            ? SafeLogic._approvePunksPayload(_asset, _id, _receiver, safe)
            : SafeLogic._approveERC721Payload(_asset, _id, _receiver, safe);

        isExecuting = true;
        currentTxHash = IGnosisSafe(payable(safe)).getTransactionHash(
            _asset,
            0,
            payload,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            IGnosisSafe(payable(safe)).nonce()
        );

        // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
        bytes memory signature = abi.encodePacked(
            abi.encode(address(this)), // r
            abi.encode(uint256(65)), // s
            bytes1(0), // v
            abi.encode(currentTxHash.length),
            currentTxHash
        );

        bool success = IGnosisSafe(safe).execTransaction(
            _asset,
            0,
            payload,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );

        isExecuting = false;
        currentTxHash = bytes32(0);

        return success;
    }

    /**
     * @notice Approve an asset owned by the safe wallet.
     */
    function _approveERC20(address _asset, uint256 _amount, address _receiver) internal returns (bool) {
        bytes memory payload = SafeLogic._approveERC20Payload(_asset, _amount, _receiver, safe);

        isExecuting = true;
        currentTxHash = IGnosisSafe(payable(safe)).getTransactionHash(
            _asset,
            0,
            payload,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            IGnosisSafe(payable(safe)).nonce()
        );

        // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
        bytes memory signature = abi.encodePacked(
            abi.encode(address(this)), // r
            abi.encode(uint256(65)), // s
            bytes1(0), // v
            abi.encode(currentTxHash.length),
            currentTxHash
        );

        bool success = IGnosisSafe(safe).execTransaction(
            _asset,
            0,
            payload,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(0),
            signature
        );

        isExecuting = false;
        currentTxHash = bytes32(0);

        return success;
    }

    /**
     * @notice Validates that the signer is the current signature delegatee, or a valid transaction executed by a asset
     * delegatee.
     * @param _data Hash of the data signed on the behalf of address(msg.sender) which must be encoded as bytes,
     * necessary to make it compatible how the Safe calls the function.
     * @param _signature Signature byte array associated with _dataHash
     */
    function isValidSignature(
        bytes memory _data,
        bytes memory _signature
    ) public view virtual override returns (bytes4) {
        bytes32 txHash = abi.decode(_signature, (bytes32));
        if (txHash != currentTxHash) revert Errors.DelegationOwner__isValidSignature_invalidExecSig();

        return EIP1271_MAGIC_VALUE;
    }
}
