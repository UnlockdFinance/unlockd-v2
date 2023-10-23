// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

library Errors {
    // ========== General ===========
    error Caller_notProtocol();
    error Caller_notGovernanceAdmin();
    error Caller_notAdmin();
    // ========== Delegation Recipes ===========
    error DelegationRecipes__add_arityMismatch();
    error DelegationRecipes__remove_arityMismatch();

    // ========== Delegation Owner ===========

    error DelegationGuard__initialize_invalidGuardBeacon();
    error DelegationGuard__initialize_invalidRecipes();
    error DelegationGuard__initialize_invalidSafe();
    error DelegationGuard__initialize_invalidOwner();
    error DelegationGuard__initialize_aclManager();
    error DelegationOwner__assetNotLocked();
    error DelegationOwner__wrongLoanId();
    error DelegationOwner__assetAlreadyLocked();
    error DelegationOwner__collectionNotAllowed();
    error DelegationOwner__onlyOwner();
    error DelegationOwner__onlyDelegationController();
    error DelegationOwner__onlyLockController();
    error DelegationOwner__onlyDelegationCreator();
    error DelegationOwner__onlySignatureDelegationCreator();
    error DelegationOwner__onlyLockCreator();

    error DelegationOwner__delegate_currentlyDelegated();
    error DelegationOwner__delegate_invalidDelegatee();
    error DelegationOwner__delegate_invalidDuration();
    error DelegationOwner__delegate_assetLocked();

    error DelegationOwner__deposit_collectionNotAllowed();
    error DelegationOwner__delegateSignature_invalidArity();
    error DelegationOwner__delegateSignature_currentlyDelegated();
    error DelegationOwner__delegateSignature_invalidDelegatee();
    error DelegationOwner__delegateSignature_invalidDuration();
    error DelegationOwner__endDelegateSignature_invalidArity();

    error DelegationOwner__isValidSignature_notDelegated();
    error DelegationOwner__isValidSignature_invalidSigner();
    error DelegationOwner__isValidSignature_invalidExecSig();

    error DelegationOwner__execTransaction_notDelegated();
    error DelegationOwner__execTransaction_invalidDelegatee();
    error DelegationOwner__execTransaction_notAllowedFunction();
    error DelegationOwner__execTransaction_notSuccess();

    error DelegationOwner__lockAsset_assetLocked();
    error DelegationOwner__lockAsset_invalidClaimDate();

    error DelegationOwner__changeClaimDate_invalidClaimDate();

    error DelegationOwner__claimAsset_assetNotClaimable();
    error DelegationOwner__claimAsset_assetLocked();
    error DelegationOwner__claimAsset_notSuccess();

    error DelegationOwner__changeOwner_notSuccess();
    error DelegationOwner__transferAsset_assetNotOwned();
    error DelegationOwner__approveAsset_assetNotOwned();

    error DelegationOwner__checkOwnedAndNotApproved_assetNotOwned();
    error DelegationOwner__checkOwnedAndNotApproved_assetApproved();

    error DelegationOwner__checkClaimDate_assetDelegatedLonger();
    error DelegationOwner__checkClaimDate_signatureDelegatedLonger();

    error DelegationOwner__lockCreatorChecks_assetNotLocked();
    error DelegationOwner__lockCreatorChecks_onlyLockCreator();

    error DelegationOwner__delegationCreatorChecks_notDelegated();
    error DelegationOwner__delegationCreatorChecks_onlyDelegationCreator();

    error DelegationOwner__setDelegationController_notAllowedController();
    error DelegationOwner__setLockController_notAllowedController();

    error DelegationOwner__batchSetLoanId_arityMismatch();
    // ========== Guard Owner ===========
    error GuardOwner__initialize_aclManager();
    error GuardOwner__initialize_invalidGuardBeacon();
    error GuardOwner__initialize_invalidSafe();
    error GuardOwner__initialize_invalidOwner();
    error GuardOwner__initialize_invalidDelegationOwner();
    error GuardOwner__initialize_invalidProtocolOwner();

    // ========== Transaction Guard ===========
    error TransactionGuard__onlyManagersOwner();
    error TransactionGuard__initialize_invalidDelegationOwner();
    error TransactionGuard__initialize_invalidProtocolOwner();
    error TransactionGuard__checkTransaction_noDelegateCall();
    error TransactionGuard__checkApproveForAll_noApprovalForAll();

    error TransactionGuard__checkLocked_noTransfer();
    error TransactionGuard__checkLocked_noApproval();
    error TransactionGuard__checkConfiguration_ownershipChangesNotAllowed();
    error TransactionGuard__checkConfiguration_guardChangeNotAllowed();
    error TransactionGuard__checkConfiguration_enableModuleNotAllowed();
    error TransactionGuard__checkConfiguration_setFallbackHandlerNotAllowed();

    // ========== Allowed Controllers ===========
    error AllowedCollections__setCollectionsAllowances_invalidAddress();
    error AllowedCollections__setCollectionsAllowances_arityMismatch();
    error AllowedControllers__setLockControllerAllowances_arityMismatch();
    error AllowedControllers__setDelegationControllerAllowances_arityMismatch();
    error AllowedControllers__setLockControllerAllowance_invalidAddress();
    error AllowedControllers__setDelegationControllerAllowance_invalidAddress();

    // ========== Delegation Wallet Registry ===========
    error DelegationWalletRegistry__onlyFactoryOrOwner();

    error DelegationWalletRegistry__setFactory_invalidAddress();

    error DelegationWalletRegistry__setWallet_invalidWalletAddress();
    error DelegationWalletRegistry__setWallet_invalidOwnerAddress();
    error DelegationWalletRegistry__setWallet_invalidDelegationOwnerAddress();
    error DelegationWalletRegistry__setWallet_invalidGuardAddress();
    error DelegationWalletRegistry__setWallet_invalidProtocolOwnerAddress();

    // ========== Protocol OWNER ===========
    error ProtocolOwner__invalidDelegatedAddressAddress();
    error ProtocolOwner__execTransaction_notSuccess();
}
