// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ERC721Upgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol';
import {IERC721ReceiverUpgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol';
import {ERC721Burnable} from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../helpers/Errors.sol';

/**
 * @title ERC721 Base Wrapper
 * @dev Implements a generic ERC721 wrapper for any NFT that needs to be "managed"
 **/
abstract contract BaseERC721Wrapper is ERC721Upgradeable, IERC721ReceiverUpgradeable {
  /*//////////////////////////////////////////////////////////////
                           VARIABLES
    //////////////////////////////////////////////////////////////*/
  ERC721Upgradeable internal immutable _erc721;
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
  function __BaseERC721Wrapper_init(
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
    _erc721 = ERC721Upgradeable(underlyingAsset);
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
  function _baseMint(address to, uint256 tokenId) internal {
    _erc721.safeTransferFrom(msg.sender, address(this), tokenId);
    _mint(to, tokenId);

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
    if (needTransfer) _erc721.safeTransferFrom(address(this), to, tokenId);

    _burn(tokenId);
    emit Burn(msg.sender, tokenId, to);
  }

  /**
   * @dev See {ERC721-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return _erc721.tokenURI(tokenId);
  }

  /**
   * @dev See {ERC721-approve}.
   */
  function approve(address, uint256) public pure override {
    revert Errors.ApproveNotSupported();
  }

  /**
   * @dev See {ERC721-setApprovalForAll}.
   */
  function setApprovalForAll(address, bool) public pure override {
    revert Errors.SetApprovalForAllNotSupported();
  }

  /**
   * @dev See {ERC721-onERC721Received}.
   */
  function onERC721Received(
    address operator,
    address,
    uint256 tokenId,
    bytes calldata data
  ) external virtual override returns (bytes4) {
    if (operator != address(this)) {
      address newWallet = abi.decode(data, (address));
      if (newWallet == address(0)) newWallet = operator;
      preMintChecks(newWallet, tokenId);
      _mint(newWallet, tokenId);
    }
    return this.onERC721Received.selector;
  }

  /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev See {ERC721-_transfer}.
   */
  function _transfer(address, address, uint256) internal pure override {
    revert Errors.TransferNotSupported();
  }
}
