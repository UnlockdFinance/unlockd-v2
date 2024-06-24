// SPDX-License-Identifier: agpl-3.0 
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
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
  using SafeERC20 for IERC20;

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
   * @param collection_ The address of the Sablier lockup linear contract,
   */
  constructor(address collection_) BaseERC1155Wrapper(collection_) {
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
  function mint(address to, uint256 tokenId) external override {
    preMintChecks(to, tokenId);
    _baseMint(to, tokenId, true);
  }

  function burn(uint256 tokenId) external override {
    _baseBurn(tokenId, msg.sender, true);
  }

  /**
   * @notice Sell the asset on the market
   * @dev this exectuion only can be performed by the wrapper adapter
   * @param underlyingAsset UnderlyingAsset returned on the sell.
   * @param amount Amount to transfer once the transaction it was executed.
   * @param marketAproval The address to mint the token to.
   * @param tokenId Token id of the asset
   * @param to Where we are going to send the tx
   * @param value value in case of ETH
   * @param data data in bytes to execute the transaction
   */
  function sellOnMarket(
    address underlyingAsset,
    uint256 amount,
    address marketAproval,
    uint256 tokenId,
    address to,
    uint256 value,
    bytes memory data,
    address amountTo
  ) external onlyWrapperAdapter {
    // Set approve for all
    if (!_erc1155.isApprovedForAll(address(this), marketAproval)) {
      _erc1155.setApprovalForAll(marketAproval, true);
    }
    // Execute the sell
    _rawExec(tokenId, to, value, data);
    // Check the amount we expect
    if (amount > 0) {
      uint256 currentBalance = IERC20(underlyingAsset).balanceOf(address(this));
      if (currentBalance < amount) revert Errors.SoldForASmallerAmount();
      // We transfer all the amount to the wrapper
      IERC20(underlyingAsset).safeTransfer(amountTo, currentBalance);
    }

    try _erc1155.setApprovalForAll(marketAproval, false) {
      // SUCCESS
    } catch {
      // ON Revert ignore
    }
    // We burn the asset
    _burn(tokenId);
  }

  /**
   * @notice Verifies if the stream is cancelable, transferable, if the token matches our uToken
   *  and if the owner is not the user or this contract.
   *  adding the preMintChecks will bring flexibility to the BASEERC721Wrapper contract.
    
   */
  function preMintChecks(address, uint256) public view override {
    if (!_controller.isActiveCollection(address(_erc1155))) revert CollectionDisabled();
  }

  /*//////////////////////////////////////////////////////////////
                           UUPSUpgradeable
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyProtocol {}
}
