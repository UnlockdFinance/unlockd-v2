// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IBasicWalletVault} from '../interfaces/IBasicWalletVault.sol';
import {IACLManager} from '../interfaces/IACLManager.sol';
import {Errors} from '../libraries/helpers/Errors.sol';

contract BasicWalletVault is Initializable, IBasicWalletVault, IERC721Receiver {
  using SafeERC20 for IERC20;
  /**
   * @notice ACL Manager that control the access and the permisions
   */
  address internal immutable _aclManager;

  /**
   * @notice A List of loan Ids
   */
  mapping(bytes32 => bytes32) loansIds;

  /**
   * @notice Check execution of the oneTimeDelegation
   */
  mapping(address => bool) oneTimeDelegation;

  /**
   * @notice The owner of the DelegationWallet, it is set only once upon initialization. Since this contract works
   * in tandem with DelegationGuard which do not allow to change the Safe owners, this owner can't change neither.
   */
  address public owner;

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
      revert WalletErrors.ProtocolOwner__invalidDelegatedAddressAddress();
    _;
  }

  modifier onlyOwner() {
    if (owner != msg.sender) revert WalletErrors.DelegationOwner__onlyOwner();
    _;
  }

  constructor(address aclManager) {
    _aclManager = aclManager;
    _disableInitializers();
  }

  /**
   * @notice Initializes the proxy state.
   * @param _owner - The owner of the DelegationWallet.
   */
  function initialize(address _owner) public initializer {
    if (_owner == address(0)) revert WalletErrors.DelegationGuard__initialize_invalidOwner();
    owner = _owner;
  }

  //////////////////////////////////////////////
  // PUBLIC
  //////////////////////////////////////////////
  /**
   * @notice Withdraw assets stored in the vault checking if they are locked.
   * @param assetTransfers - list of assets to withdraw
   * @param to address to send the assets
   */
  function withdrawAssets(AssetTransfer[] calldata assetTransfers, address to) external onlyOwner {
    uint256 length = assetTransfers.length;
    bool success;
    // Iterate through each NFT in the array to facilitate the transfer.
    for (uint i = 0; i < length; ) {
      address contractAddress = assetTransfers[i].contractAddress;
      uint256 value = assetTransfers[i].value;

      if(!assetTransfers[i].isERC20) {
        // check if the asset is locked
        bytes32 id = AssetLogic.assetId(contractAddress, value);
        bool isLocked = _isLocked(id);
        if (isLocked) revert Errors.AssetLocked();
        // Dynamically call the `safeTransferFrom` function on the target ERC721 contract.
        (success, ) = contractAddress.call(
          abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', address(this), to, value)
        );

        // Check the transfer status.
        if (!success) {
          revert TransferFromFailed();
        }
      } else {
        _safeTransferERC20(contractAddress, value, to);
      }

      // Use unchecked block to bypass overflow checks for efficiency.
      unchecked {
        i++;
      }
    }
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
  ) external onlyOneTimeDelegation {
    // Doesnt' matter if fails, it need to delegate again.
    oneTimeDelegation[msg.sender] = false;

    if (loansIds[AssetLogic.assetId(_collection, _tokenId)] != _loanId) {
      revert WalletErrors.DelegationOwner__wrongLoanId();
    }
    // Approves the asset to be sold
    _approveAsset(_collection, _tokenId, _marketApproval);
    // Approval of the ERC20 to repay the debs
    _approveERC20(_underlyingAsset, _amount, msg.sender);
  }

  // Delegatee Functions
  function execTransaction(
    address _to,
    uint256 _value,
    bytes calldata _data,
    uint256,
    uint256,
    uint256,
    address,
    address payable
  ) external onlyOneTimeDelegation returns (bool success) {
    oneTimeDelegation[msg.sender] = false;
    _rawExec(_to, _value, _data);
    return true;
  }

  function delegateOneExecution(address to, bool value) external onlyProtocol {
    if (to == address(0)) revert WalletErrors.ProtocolOwner__invalidDelegatedAddressAddress();
    oneTimeDelegation[to] = value;
  }

  function isDelegatedExecution(address to) external view returns (bool) {
    return oneTimeDelegation[to];
  }

  function isAssetLocked(bytes32 _id) external view returns (bool) {
    return _isLocked(_id);
  }

  function batchSetLoanId(bytes32[] calldata _assets, bytes32 _loanId) external onlyProtocol {
    uint256 cachedAssets = _assets.length;
    for (uint256 i = 0; i < cachedAssets; ) {
      if (loansIds[_assets[i]] != 0) revert WalletErrors.DelegationOwner__assetAlreadyLocked();
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
      if (loansIds[_assets[i]] == 0) revert WalletErrors.DelegationOwner__assetNotLocked();
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

    _transferAsset(_asset, _id, _newOwner);

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
  // RECEIVER
  //////////////////////////////////////////////

  //receive() external payable {}

  //fallback() external payable {}

  /**
   * @dev See {ERC721-onERC721Received}.
   */
  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  //////////////////////////////////////////////
  // PRIVATE
  //////////////////////////////////////////////

  function _isLocked(bytes32 _id) internal view returns (bool) {
    return loansIds[_id] != bytes32(0);
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
    IERC721(_asset).approve(_receiver, _id);
  }

  function _safeTransferERC20(address _asset, uint256 _amount, address _receiver) internal {
    IERC20(_asset).safeTransfer(_receiver, _amount);
  }

  function _approveERC20(address _asset, uint256 _amount, address _receiver) internal {
    IERC20(_asset).approve(_receiver, _amount);
  }

  function _transferAsset(address _asset, uint256 _id, address _receiver) internal {
    IERC721(_asset).safeTransferFrom(address(this), _receiver, _id, '');
  }
}
