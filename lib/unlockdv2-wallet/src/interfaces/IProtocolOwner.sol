// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IProtocolOwner {
    ////////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////////

    event SetLockController(address indexed lockController, bool allowed);
    event ChangeOwner(address indexed asset, uint256 indexed assetId, address newOwner);
    event LockedAsset(
        address indexed asset,
        uint256 indexed assetId,
        uint256 claimDate,
        address indexed lockController
    );

    event UnlockedAsset(address indexed asset, uint256 indexed assetId, address indexed lockController);
    event ClaimedAsset(address indexed asset, uint256 indexed assetId, address indexed receiver);
    event TransferredAsset(address indexed asset, uint256 indexed assetId, address indexed receiver);

    event SetLoanId(bytes32 index, bytes32 loanId);
    event SetBatchLoanId(bytes32[] indexed assets, bytes32 indexed loanId);

    ////////////////////////////////////////////////////////////////////////////////
    // Functions
    ////////////////////////////////////////////////////////////////////////////////

    function approveSale(
        address _collection,
        uint256 _tokenId,
        address _underlyingAsset,
        uint256 _amount,
        address _marketApproval,
        bytes32 _loanId
    ) external;

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

    function delegateOneExecution(address to, bool value) external;

    function isDelegatedExecution(address to) external returns (bool);

    function isAssetLocked(bytes32 _id) external view returns (bool);

    function batchSetLoanId(bytes32[] calldata _assets, bytes32 _loanId) external;

    function batchSetToZeroLoanId(bytes32[] calldata _assets) external;

    function changeOwner(address _asset, uint256 _id, address _newOwner) external;

    function getLoanId(bytes32 _assetId) external returns (bytes32);

    function setLoanId(bytes32 _assetId, bytes32 _loanId) external;
}
