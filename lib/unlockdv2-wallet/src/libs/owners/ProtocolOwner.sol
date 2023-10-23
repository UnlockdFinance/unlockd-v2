// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import { console } from "forge-std/console.sol";
import { IGnosisSafe } from "../../interfaces/IGnosisSafe.sol";
import { ICryptoPunks } from "../../interfaces/ICryptoPunks.sol";
import { IACLManager } from "../../interfaces/IACLManager.sol";
import { IProtocolOwner } from "../../interfaces/IProtocolOwner.sol";

import { TransactionGuard } from "../guards/TransactionGuard.sol";
import { DelegationOwner } from "./DelegationOwner.sol";
import { AssetLogic } from "../logic/AssetLogic.sol";
import { SafeLogic } from "../logic/SafeLogic.sol";
import { Errors } from "../helpers/Errors.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { ISignatureValidator } from "@gnosis.pm/safe-contracts/contracts/interfaces/ISignatureValidator.sol";

import { BaseSafeOwner } from "../base/BaseSafeOwner.sol";

/**
 * @title ProtocolOwner
 * @author Unlockd
 * @dev This contract contains the logic that enables asset/signature delegates to interact with a Gnosis Safe wallet.
 * In the case of assets delegates, it will allow them to execute functions though the Safe, only those registered
 * as allowed on the DelegationRecipes contract.
 * In the case of signatures it validates that a signature was made by the current delegatee.
 * It is also used by the delegation controller to set delegations and the lock controller to lock, unlock and claim
 * assets.
 *
 * It should be use a proxy's implementation.
 */
contract ProtocolOwner is Initializable, BaseSafeOwner, IProtocolOwner {
    // bytes32 public constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    DelegationOwner public delegationOwner;
    mapping(bytes32 => bytes32) loansIds;
    mapping(address => bool) oneTimeDelegation;
    /**
     * @notice The DelegationGuard address.
     */
    TransactionGuard public guard;

    ////////////////////////////////////////////////////////////////////////////////
    // Modifiers
    ////////////////////////////////////////////////////////////////////////////////

    modifier onlyOneTimeDelegation() {
        if (oneTimeDelegation[msg.sender] == false) revert Errors.ProtocolOwner__invalidDelegatedAddressAddress();
        _;
    }

    /**
     * @dev Disables the initializer in order to prevent implementation initialization.
     */
    constructor(address _cryptoPunks, address _aclManager) BaseSafeOwner(_cryptoPunks, _aclManager) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the proxy state.
     
     * @param _safe - The DelegationWallet address, the GnosisSafe.
     * @param _owner - The owner of the DelegationWallet.
     * @param _delegationOwner - Use delegation owner
     */
    function initialize(address _guard, address _safe, address _owner, address _delegationOwner) public initializer {
        // if (_guard == address(0)) revert Errors.DelegationGuard__initialize_invalidGuardBeacon();
        if (_safe == address(0)) revert Errors.DelegationGuard__initialize_invalidSafe();
        if (_owner == address(0)) revert Errors.DelegationGuard__initialize_invalidOwner();

        delegationOwner = DelegationOwner(_delegationOwner);
        safe = _safe;
        owner = _owner;

        guard = TransactionGuard(_guard);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Public Functions
    ////////////////////////////////////////////////////////////////////////////////

    function approveSale(
        address _collection,
        uint256 _tokenId,
        address _underlyingAsset,
        uint256 _amount,
        address _marketApproval,
        bytes32 _loanId
    ) external onlyOneTimeDelegation {
        // Doesnt' matter if fails, it need to delegate again.
        oneTimeDelegation[msg.sender] = false;

        if (loansIds[AssetLogic.assetId(_collection, _tokenId)] != _loanId) {
            revert Errors.DelegationOwner__wrongLoanId();
        }
        // Asset approval to the adapter to perform the sell
        _approveAsset(_collection, _tokenId, _marketApproval);
        // Approval of the ERC20 to repay the debs
        _approveERC20(_underlyingAsset, _amount, msg.sender);
    }

    /**
     * @notice Execute a transaction through the GnosisSafe wallet.
     * The sender should be the delegatee of the given asset and the function should be allowed for the collection.
     * @param _asset - The delegated asset addresses.
     * @param _id - The delegated asset ids.
     * @param _to - Destination address of Safe transaction.
     * @param _value - Ether value of Safe transaction.
     * @param _data - Data payload of Safe transaction.
     * @param _safeTxGas - Gas that should be used for the Safe transaction.
     * @param _baseGas Gas costs that are independent of the transaction execution(e.g. base transaction fee, signature
     * check, payment of the refund)
     * @param _gasPrice - Gas price that should be used for the payment calculation.
     * @param _gasToken - Token address (or 0 if ETH) that is used for the payment.
     * @param _refundReceiver - Address of receiver of gas payment (or 0 if tx.origin).
     */
    function execTransaction(
        address _asset,
        uint256 _id,
        address _to,
        uint256 _value,
        bytes calldata _data,
        uint256 _safeTxGas,
        uint256 _baseGas,
        uint256 _gasPrice,
        address _gasToken,
        address payable _refundReceiver
    ) external onlyOneTimeDelegation returns (bool success) {
        // Doesnt' matter if fails, it need to delegate again.
        oneTimeDelegation[msg.sender] = false;

        // Admin execution no safe guard
        isExecuting = true;
        currentTxHash = IGnosisSafe(payable(safe)).getTransactionHash(
            // Transaction info
            _to,
            _value,
            _data,
            Enum.Operation.Call,
            _safeTxGas,
            // Payment info
            _baseGas,
            _gasPrice,
            _gasToken,
            _refundReceiver,
            // Signature info
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

        (success) = IGnosisSafe(safe).execTransaction(
            _to,
            _value,
            _data,
            Enum.Operation.Call,
            _safeTxGas,
            _baseGas,
            _gasPrice,
            _gasToken,
            _refundReceiver,
            signature
        );

        isExecuting = false;
        currentTxHash = bytes32(0);

        if (!success) revert Errors.ProtocolOwner__execTransaction_notSuccess();
    }

    function delegateOneExecution(address to, bool value) external onlyProtocol {
        if (to == address(0)) revert Errors.ProtocolOwner__invalidDelegatedAddressAddress();
        oneTimeDelegation[to] = value;
    }

    function isDelegatedExecution(address to) external view returns (bool) {
        return oneTimeDelegation[to];
    }

    /**
     * @notice Returns if an asset is locked.
     * @param _id - The asset id.
     */
    function isAssetLocked(bytes32 _id) external view returns (bool) {
        return delegationOwner.guard().isLocked(_id);
    }

    /**
     * @notice Return the LoanId asigned to a asset
     *   0 means the asset is locked
     */
    function getLoanId(bytes32 index) external view returns (bytes32) {
        return loansIds[index];
    }

    /**
     * @notice set loan id assigned to a especific assetId
     */
    function setLoanId(bytes32 _index, bytes32 _loanId) external onlyProtocol {
        _setLoanId(_index, _loanId);
        emit SetLoanId(_index, _loanId);
    }

    /**
     * @notice change the current ownership of a asset
     */
    function changeOwner(address _asset, uint256 _id, address _newOwner) external onlyProtocol {
        bytes32 id = AssetLogic.assetId(_asset, _id);

        // We unlock the current asset
        _setLoanId(id, 0);
        // Force end delegation
        delegationOwner.forceEndDelegation(_asset, _id);

        bool success = _transferAsset(_asset, _id, _newOwner);
        if (!success) revert Errors.DelegationOwner__changeOwner_notSuccess();

        emit ChangeOwner(_asset, _id, _newOwner);
    }

    /**
     * @notice batch function to set to 0 a group of assets
     */
    function batchSetToZeroLoanId(bytes32[] calldata _assets) external onlyProtocol {
        uint256 cachedAssets = _assets.length;
        for (uint256 i = 0; i < cachedAssets; ) {
            if (loansIds[_assets[i]] == 0) revert Errors.DelegationOwner__assetNotLocked();
            _setLoanId(_assets[i], 0);
            unchecked {
                i++;
            }
        }
        emit SetBatchLoanId(_assets, 0);
    }

    /**
     * @notice batch function to set to differnt from 0 a group of assets
     */
    function batchSetLoanId(bytes32[] calldata _assets, bytes32 _loanId) external onlyProtocol {
        uint256 cachedAssets = _assets.length;
        for (uint256 i = 0; i < cachedAssets; ) {
            if (loansIds[_assets[i]] != 0) revert Errors.DelegationOwner__assetAlreadyLocked();
            _setLoanId(_assets[i], _loanId);
            unchecked {
                i++;
            }
        }
        emit SetBatchLoanId(_assets, _loanId);
    }

    //////////////////////////////////////////////
    //       Internal functions
    //////////////////////////////////////////////

    function _setLoanId(bytes32 _assetId, bytes32 _loanId) internal {
        loansIds[_assetId] = _loanId;

        // We update the guard from DelegationOwner
        if (_loanId == 0) {
            guard.unlockAsset(_assetId);
        } else {
            guard.lockAsset(_assetId);
        }
    }
}
