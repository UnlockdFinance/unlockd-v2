// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import {IERC1155MetadataURI} from '@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol';
import {ERC721Upgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol';
import {ERC721Burnable} from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import {IERC1155ReceiverUpgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC1155/IERC1155ReceiverUpgradeable.sol';
import {AddressUpgradeable} from '@openzeppelin-upgradeable/contracts/utils/AddressUpgradeable.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title ERC1155 Base Wrapper
 * @dev Implements a generic ERC1155 wrapper for any NFT that needs to be "managed"
 **/
abstract contract BaseERC1155Wrapper is ERC721Upgradeable, IERC1155ReceiverUpgradeable {
  /*//////////////////////////////////////////////////////////////
                           VARIABLES
    //////////////////////////////////////////////////////////////*/
  uint256 internal constant AMOUNT = 1;

  IERC1155 internal immutable _erc1155;
  uint256 internal _counter = 1;
  // Old token ID => new Token ID
  mapping(uint256 => uint256) internal _tokenIds;
  address internal _aclManager;

  /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emitted when a token is minted.
   * @param minter Address of the minter.
   * @param tokenId ID of the minted token.
   * @param to Address of the recipient.
   */
  event Mint(address indexed minter, uint256 tokenId, address indexed to);

  /**
   *  @notice Emitted when a token is burned.
   * @param burner Address of the burner.
   * @param tokenId ID of the burned token.
   * @param owner Address of the token owner.
   */
  event Burn(address indexed burner, uint256 tokenId, address indexed owner);

  /**
   * @dev Emitted when the contract is initialized.
   * @param name of the underlying asset.
   * @param symbol of the underlying asset.
   */
  event Initialized(string name, string symbol);

  /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Modifier that checks if the sender has Protocol ROLE
   */
  modifier onlyProtocol() {
    if (!IACLManager(_aclManager).isProtocol(_msgSender())) {
      revert Errors.ProtocolAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Emergency ROLE
   */
  modifier onlyEmergency() {
    if (!IACLManager(_aclManager).isEmergencyAdmin(_msgSender())) {
      revert Errors.EmergencyAccessDenied();
    }
    _;
  }

  /**
   * @dev Modifier that checks if the sender has Wrapper ROLE
   */
  modifier onlyWrapperAdapter() {
    if (!IACLManager(_aclManager).isWrapperAdapter(_msgSender())) {
      revert Errors.NotWrapperAdapter();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Initializer for the BaseERC721Wrapper contract.
   * @dev Sets up the base ERC721 wrapper with necessary details and configurations.
   * This function uses the `initializer` modifier to ensure it's only called once,
   * which is a common pattern in upgradeable contracts to replace constructors.
   * @param name The name for the ERC721 token.
   * @param symbol The symbol for the ERC721 token.
   * @param aclManager The address of the ACL (Access Control List) manager contract.
   */
  function __BaseERC1155Wrapper_init(
    string memory name,
    string memory symbol,
    address aclManager
  ) internal onlyInitializing {
    __ERC721_init(name, symbol);
    _aclManager = aclManager;
  }

  /**
   * @notice Initializes the underlying asset contract by setting the ERC721 address.
   * @param underlyingAsset The address of the underlying asset to be wrapped.
   */
  constructor(address underlyingAsset) {
    _erc1155 = IERC1155(underlyingAsset);
    _disableInitializers();
  }

  /*//////////////////////////////////////////////////////////////
                            ERC721
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice in case the underlying asset needs some specific checks before minting.
   * the params are supposed to be collection:tokenId.
   */
  function preMintChecks(address, uint256) public virtual;

  /**
   * @notice Mints a new token.
   * @dev Mints a new ERC721 token representing the underlying asset and stores the real asset in this contract.
   * @param to The address to mint the token to.
   * @param tokenId The token ID to mint.
   */
  function _baseMint(address to, uint256 tokenId, bool needTransfer) internal {
    // We only move one
    if (needTransfer) {
      _erc1155.safeTransferFrom(msg.sender, address(this), tokenId, AMOUNT, '');
    }
    uint256 newTokenId = _counter++;
    _tokenIds[newTokenId] = tokenId;
    _mint(to, newTokenId);

    emit Mint(msg.sender, tokenId, to);
  }

  /**
   * @notice Burns a token.
   * @dev Burns an ERC721 token and transfers the underlying asset to its owner.
   * @param tokenId The token ID to burn.
   * @param to Send the token to.
   * @param needTransfer Need transfer
   */
  function _baseBurn(uint256 tokenId, address to, bool needTransfer) internal {
    if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert Errors.BurnerNotApproved();
    if (needTransfer) _erc1155.safeTransferFrom(address(this), to, _tokenIds[tokenId], AMOUNT, '');
    _burn(tokenId);
    delete _tokenIds[tokenId];
    emit Burn(msg.sender, tokenId, to);
  }

  /**
   * @dev See {ERC721-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return IERC1155MetadataURI(address(_erc1155)).uri(_tokenIds[tokenId]);
  }

  /**
   * @dev See {ERC1155-onERC1155Received}.
   */
  function onERC1155Received(
    address operator,
    address,
    uint256 tokenId,
    uint256 value,
    bytes calldata data
  ) external returns (bytes4) {
    if (operator != address(this)) {
      if (value != 1) revert Errors.ERC1155AmountNotValid();
      address newWallet = abi.decode(data, (address));
      if (newWallet == address(0)) newWallet = operator;
      preMintChecks(newWallet, tokenId);
      _baseMint(newWallet, tokenId, false);
    }

    return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address operator,
    address,
    uint256[] calldata tokensIds,
    uint256[] calldata values,
    bytes calldata data
  ) external returns (bytes4) {
    if(tokensIds.length != values.length) revert Errors.InvalidArrayLength();
    if (operator != address(this)) {
      address newWallet = abi.decode(data, (address));
      for (uint256 i; i < tokensIds.length; ) {
        uint256 tokenId = tokensIds[i];
        uint256 value = values[i];
        if (value != 1) revert Errors.ERC1155AmountNotValid();
        preMintChecks(newWallet, tokenId);
        _baseMint(newWallet, tokenId, false);
      }
    }
    return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
  }

  /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev Funtion to execute raw data, only can be execuited by the WrappedAdapter when this one is the owner
   * @param tokenId token id of the asset
   * @param to to address of the execution
   * @param value value of the data execution
   * @param data data in bytes for the execution
   */
  function _rawExec(
    uint256 tokenId,
    address to,
    uint256 value,
    bytes memory data
  ) internal onlyWrapperAdapter {
    if (ownerOf(tokenId) == address(this)) revert Errors.NotWrapperAdapter();
    // Ensure the target is a contract
    if(!AddressUpgradeable.isContract(to)) revert Errors.NotContract();
    (bool sent, ) = payable(to).call{value: value}(data);
    if (sent == false) revert Errors.UnsuccessfulExecution();
  }
}
