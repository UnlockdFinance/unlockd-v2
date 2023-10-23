// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import { IGnosisSafe } from "../../interfaces/IGnosisSafe.sol";
import { ICryptoPunks } from "../../interfaces/ICryptoPunks.sol";
import { IAllowedControllers } from "../../interfaces/IAllowedControllers.sol";
import { IACLManager } from "../../interfaces/IACLManager.sol";
import { DelegationRecipes } from "../recipes/DelegationRecipes.sol";

import { TransactionGuard } from "../guards/TransactionGuard.sol";
import { AssetLogic } from "../logic/AssetLogic.sol";
import { SafeLogic } from "../logic/SafeLogic.sol";
import { Errors } from "../helpers/Errors.sol";

import { IDelegationOwner } from "../../interfaces/IDelegationOwner.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

import { BaseSafeOwner } from "../base/BaseSafeOwner.sol";

contract GuardOwner is Initializable, BaseSafeOwner {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    bytes32 public constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    TransactionGuard public guard;

    constructor(address _cryptoPunks, address _aclManager) BaseSafeOwner(_cryptoPunks, _aclManager) {
        if (_aclManager == address(0)) revert Errors.GuardOwner__initialize_aclManager();
        _disableInitializers();
    }

    function initialize(
        address _guardBeacon,
        address _safe,
        address _owner,
        address _delegationOnwer,
        address _protocolOwner
    ) public initializer {
        if (_guardBeacon == address(0)) revert Errors.GuardOwner__initialize_invalidGuardBeacon();
        if (_safe == address(0)) revert Errors.GuardOwner__initialize_invalidSafe();
        if (_owner == address(0)) revert Errors.GuardOwner__initialize_invalidOwner();
        if (_delegationOnwer == address(0)) revert Errors.GuardOwner__initialize_invalidDelegationOwner();
        if (_protocolOwner == address(0)) revert Errors.GuardOwner__initialize_invalidProtocolOwner();

        safe = _safe;
        owner = _owner;

        address guardProxy = address(
            new BeaconProxy(
                _guardBeacon,
                abi.encodeWithSelector(TransactionGuard.initialize.selector, _delegationOnwer, _protocolOwner)
            )
        );
        guard = TransactionGuard(guardProxy);
        // Set up guard
        _setupGuard(_safe, guard);
    }

    function _setupGuard(address _safe, TransactionGuard _guard) internal {
        // this requires this address to be a owner of the safe already
        isExecuting = true;
        bytes memory payload = abi.encodeWithSelector(IGnosisSafe.setGuard.selector, _guard);
        currentTxHash = IGnosisSafe(payable(_safe)).getTransactionHash(
            // Transaction info
            safe,
            0,
            payload,
            Enum.Operation.Call,
            0,
            // Payment info
            0,
            0,
            address(0),
            payable(0),
            // Signature info
            IGnosisSafe(payable(_safe)).nonce()
        );

        // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
        bytes memory signature = abi.encodePacked(
            abi.encode(address(this)), // r
            abi.encode(uint256(65)), // s
            bytes1(0), // v
            abi.encode(currentTxHash.length),
            currentTxHash
        );

        IGnosisSafe(_safe).execTransaction(
            safe,
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
    }
}
