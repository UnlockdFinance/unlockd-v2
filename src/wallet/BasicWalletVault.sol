import {IProtocolOwner} from '@unlockd-wallet/src/interfaces/IProtocolOwner.sol';
import {Errors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';

contract BasicWalletVault is Initializable, IProtocolOwner {
  /**
   * @notice ACL Manager that control the access and the permisions
   */
  address internal immutable _aclManager;

  /**
   * @notice List of loans Id
   */
  mapping(bytes32 => bytes32) loansIds;

  /**
   * @notice Check to on time execution delegation
   */
  mapping(address => bool) oneTimeDelegation;

  /**
   * @notice The owner of the DelegationWallet, it is set only once upon initialization. Since this contract works
   * in tandem with DelegationGuard which do not allow to change the Safe owners, this owner can't change neither.
   */
  address public owner;

  // Struct to encapsulate information about an individual NFT transfer.
  // It holds the address of the ERC721 contract and the specific token ID to be transferred.
  struct NftTransfer {
    address contractAddress;
    uint256 tokenId;
  }

  //////////////////////////////////////////////////////////////
  //                           ERRORS
  //////////////////////////////////////////////////////////////
  error TransferFromFailed();
  error CantReceiveETH();
  error Fallback();

  /**
   * @dev Modifier that checks if the sender has Protocol ROLE
   */
  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(msg.sender)) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Emergency ROLE
   */
  modifier onlyEmergency() {
    if (!IACLManager(_aclManager).isEmergencyAdmin(msg.sender)) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  modifier onlyOneTimeDelegation() {
    if (oneTimeDelegation[msg.sender] == false)
      revert Errors.ProtocolOwner__invalidDelegatedAddressAddress();
    _;
  }

  modifier onlyOwner() {
    if (owner != msg.sender) revert Errors.DelegationOwner__onlyOwner();
    _;
  }

  constructor(address aclManager) {
    _aclManager = aclManager;
  }

  /**
     * @notice Initializes the proxy state.

     * @param _safe - The DelegationWallet address, the GnosisSafe.
     * @param _owner - The owner of the DelegationWallet.
     * @param _delegationOwner - Use delegation owner
     */
  function initialize(address _owner) public initializer {
    if (_owner == address(0)) revert Errors.DelegationGuard__initialize_invalidOwner();
    owner = _owner;
  }

  //////////////////////////////////////////////
  // PUBLIC
  //////////////////////////////////////////////

  // WITHDRAW ERC20

  // WITHDRAW ERC721
  function withdrawAssets(NftTransfer[] calldata nftTransfers, address to) external onlyOwner {
    uint256 length = nftTransfers.length;

    // Iterate through each NFT in the array to facilitate the transfer.
    for (uint i = 0; i < length; ) {
      address contractAddress = nftTransfers[i].contractAddress;
      uint256 tokenId = nftTransfers[i].tokenId;

      // TODO : Check if it is locked

      // Dynamically call the `transferFrom` function on the target ERC721 contract.
      (bool success, ) = contractAddress.call(
        abi.encodeWithSignature('transferFrom(address,address,uint256)', address(this), to, tokenId)
      );

      // Check the transfer status.
      if (!success) {
        revert TransferFromFailed();
      }

      // Use unchecked block to bypass overflow checks for efficiency.
      unchecked {
        i++;
      }
    }
  }

  /*//////////////////////////////////////////////////////////////
                    Fallback and Receive Functions
    //////////////////////////////////////////////////////////////*/
  // Explicitly reject any Ether sent to the contract
  fallback() external payable {
    revert Fallback();
  }

  // Explicitly reject any Ether transfered to the contract
  receive() external payable {
    revert CantReceiveETH();
  }

  //////////////////////////////////////////////
  // ONLY PROTOCOL
  //////////////////////////////////////////////

  function approveSale(
    address _collection,
    uint256 _tokenId,
    address _underlyingAsset,
    uint256 _amount,
    address _marketApproval,
    bytes32 _loanId
  ) external onlyOneTimeDelegation onlyProtocol {
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

  // Delegatee Functions
  function execTransaction(
    address _to,
    uint256 _value,
    bytes calldata _data,
    uint256 _safeTxGas,
    uint256 _baseGas,
    uint256 _gasPrice,
    address _gasToken,
    address payable _refundReceiver
  ) external onlyOneTimeDelegation onlyProtocol returns (bool success) {
    _rawExec(_to, _value, _data);
  }

  function delegateOneExecution(address to, bool value) external onlyProtocol {
    if (to == address(0)) revert Errors.ProtocolOwner__invalidDelegatedAddressAddress();
    oneTimeDelegation[to] = value;
  }

  function isDelegatedExecution(address to) external view returns (bool) {
    return oneTimeDelegation[to];
  }

  function isAssetLocked(bytes32 _id) external view onlyProtocol returns (bool) {
    // TODO: Pending to check
    return _isLocked(_id);
  }

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

  function changeOwner(address _asset, uint256 _id, address _newOwner) external onlyProtocol {
    bytes32 id = AssetLogic.assetId(_asset, _id);

    // We unlock the current asset
    _setLoanId(id, 0);

    bool success = _transferAsset(_asset, _id, _newOwner);
    if (!success) revert Errors.DelegationOwner__changeOwner_notSuccess();

    emit ChangeOwner(_asset, _id, _newOwner);
  }

  function getLoanId(bytes32 _assetId) external view returns (bytes32) {
    return loansIds[_assetId];
  }

  function setLoanId(bytes32 _assetId, bytes32 _loanId) external onlyProtocol {
    _setLoanId(_assetId, _loanId);
    emit SetLoanId(_assetId, _loanId);
  }

  function safeSetLoanId(address _asset, uint256 _id, bytes32 _loanId) external onlyProtocol {
    bytes32 id = AssetLogic.assetId(_asset, _id);
    // Reset approve
    _approveAsset(_asset, _id, address(0));
    // Lock asset
    _setLoanId(id, _loanId);
    emit SetLoanId(id, _loanId);
  }

  //////////////////////////////////////////////
  // PRIVATE
  //////////////////////////////////////////////

  function _isLocked(bytes32 _id) internal returns (bool) {
    return loansIds[_id].length > 0;
  }

  function _setLoanId(bytes32 _assetId, bytes32 _loanId) internal {
    loansIds[_assetId] = _loanId;
  }

  function _rawExec(address to, uint256 value, bytes memory data) internal {
    // Ensure the target is a contract
    (bool sent, ) = payable(to).call{value: value}(data);
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }

  function _approveAsset(address _asset, uint256 _id, address _receiver) internal {
    // TODO : Pending
  }

  function _approveERC20(address _asset, uint256 _amount, address _receiver) internal {
    // TODO : Pending
  }

  function _transferAsset(address _asset, uint256 _id, address _receiver) internal {
    // TODO : Pending
  }
}
