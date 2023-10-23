// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IDelegationOwner {
    ////////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////////

    event SetDelegationController(address indexed delegationController, bool allowed);
    event SetLockController(address indexed lockController, bool allowed);
    event NewDelegation(
        address indexed asset,
        uint256 indexed assetId,
        uint256 from,
        uint256 to,
        address indexed delegatee,
        address delegationController
    );
    event EndDelegation(address indexed asset, uint256 indexed assetId, address delegationController);
    event ChangeOwner(address indexed asset, uint256 indexed assetId, address newOwner);
    event DelegatedSignature(
        uint256 from,
        uint256 to,
        address indexed delegatee,
        address[] assets,
        uint256[] assetIds,
        address delegationController
    );
    event EndDelegatedSignature(address[] assets, uint256[] assetIds, address delegationController);

    event ClaimedAsset(address indexed asset, uint256 indexed assetId, address indexed receiver);
    event TransferredAsset(address indexed asset, uint256 indexed assetId, address indexed receiver);

    ////////////////////////////////////////////////////////////////////////////////
    // Structs
    ////////////////////////////////////////////////////////////////////////////////

    struct SignatureAssets {
        address[] assets;
        uint256[] ids;
    }

    /**
     * @notice Delegation information, it is used for assets and signatures.
     *
     * @param controller - The delegation controller address that created the delegations.
     * @param delegatee - The delegatee address.
     * @param from - The date (seconds timestamp) when the delegation starts.
     * @param to - The date (seconds timestamp) when the delegation ends.
     */
    struct Delegation {
        address controller;
        address delegatee;
        uint256 from;
        uint256 to;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Functions
    ////////////////////////////////////////////////////////////////////////////////

    function delegate(address _asset, uint256 _assetId, address _delegatee, uint256 _duration) external;

    function endDelegate(address _asset, uint256 _assetId) external;

    function delegateSignature(
        address[] calldata _assets,
        uint256[] calldata _assetIds,
        address _delegatee,
        uint256 _duration
    ) external;

    // Lock Controller Functions

    function claimAsset(address _asset, uint256 _assetId, address _receiver) external;

    // Delegatee Functions
    function execTransaction(
        address _asset,
        uint256 _assetId,
        address _to,
        uint256 _value,
        bytes calldata _data,
        uint256 _safeTxGas,
        uint256 _baseGas,
        uint256 _gasPrice,
        address _gasToken,
        address payable _refundReceiver
    ) external returns (bool success);

    function isAllowedFunction(address _asset, address _contract, bytes4 _selector) external view returns (bool);

    function isAssetDelegated(address _asset, uint256 _assetId) external view returns (bool);

    function isSignatureDelegated() external view returns (bool);
}
