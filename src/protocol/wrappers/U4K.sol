// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {BaseERC1155Wrapper, Errors} from '../../libraries/base/BaseERC1155Wrapper.sol';
import {IERC11554KController} from '../../interfaces/wrappers/IERC11554KController.sol';
import {IUTokenWrapper} from '../../interfaces/IUTokenWrapper.sol';
import {IERC11554K} from '../../interfaces/wrappers/IERC11554K.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

/**
 * @title U4K - ERC721 wrapper representing a ERC1155 4K
 * @dev Implements a wrapper for the ERC1155 assets from 4K to ERC721
 **/
contract U4K is IUTokenWrapper, BaseERC1155Wrapper, UUPSUpgradeable {
  IERC11554KController internal _controller;

  error CollectionDisabled();

  /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Initializes the contract with 4K Controller
   */

  function initialize(
    string memory name,
    string memory symbol,
    address aclManager,
    address controller
  ) external initializer {
    __BaseERC1155Wrapper_init(name, symbol, aclManager);
    _controller = IERC11554KController(controller);
    emit Initialized(name, symbol);
  }

  /**
   * @notice Initializes the USablierLockUpLinear contract by setting the Sablier lockup linear address.
   * @dev This constructor sets the Sablier lockup linear address and disables further initializations.
   * @param fourkAddress The address of the Sablier lockup linear contract,
   */
  constructor(address fourkAddress) BaseERC1155Wrapper(fourkAddress) {
    _disableInitializers();
  }

  /*//////////////////////////////////////////////////////////////
                            CUSTOM
    //////////////////////////////////////////////////////////////*/

  function wrappedMaxAmount() external pure returns (uint256) {
    return AMOUNT;
  }

  function collection() external view returns (address) {
    return address(_erc1155);
  }

  function wrappedTokenId(uint256 tokenId) external view returns (uint256) {
    return _tokenIds[tokenId];
  }

  /*//////////////////////////////////////////////////////////////
                                ERC721
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Mints a new token.
   * @dev Mints a new ERC721 token representing a Sablier stream, verifies if the stream is cancelable and
   * and if the asset in the stream is supported by the protocol.
   * @param to The address to mint the token to.
   * @param tokenId The token ID to mint.
   */
  function mint(address to, uint256 tokenId) external override(BaseERC1155Wrapper, IUTokenWrapper) {
    preMintChecks(to, tokenId);
    _baseMint(to, tokenId, true);
  }

  function burn(address to, uint256 tokenId) external override(BaseERC1155Wrapper, IUTokenWrapper) {
    _baseBurn(tokenId, to);
  }

  

  /**
   * @notice Verifies if the stream is cancelable, transferable, if the token matches our uToken
   *  and if the owner is not the user or this contract.
   *  adding the preMintChecks will bring flexibility to the BASEERC721Wrapper contract.
   * @param tokenId the token id representing the stream
   */
  function preMintChecks(
    address,
    uint256 tokenId
  ) public view override(BaseERC1155Wrapper, IUTokenWrapper) {
    if (!_controller.isActiveCollection(address(_erc1155))) revert CollectionDisabled();
    if (_erc1155.balanceOf(msg.sender, tokenId) == 0) revert Errors.CallerNotNFTOwner();
  }

  //   /**
  //    * @notice Burns a token.
  //    * @dev Burns an ERC721 token representing a Sablier stream and transfers the underlying asset to its owner.
  //    * @param to The address to send the NFT to.
  //    * @param tokenId The token ID to burn.
  //    */
  //   function burn(address to, uint256 tokenId) external override {
  //     _baseBurn(tokenId, to);
  //   }

  /*//////////////////////////////////////////////////////////////
                           UUPSUpgradeable
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyProtocol {}
}
