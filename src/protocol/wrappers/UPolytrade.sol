// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

import {BaseERC6960Wrapper, Errors} from '../../libraries/base/BaseERC6960Wrapper.sol';
import {IERC11554KController} from '../../interfaces/wrappers/IERC11554KController.sol';
import {IERC11554K} from '../../interfaces/wrappers/IERC11554K.sol';
import {IUTokenWrapper6960} from '../../interfaces/IUTokenWrapper6960.sol';

/**
 * @title Polytrade - ERC721 wrapper representing a ERC6960 Polytrade
 * @dev Implements a wrapper for the ERC6960 assets from polytrade to ERC721
 * @dev DO NOT SEND ERC6960 DIRECTLY TO THIS CONTRACT, THEY WILL BE LOCKED FOREVER
 **/
contract UPolytrade is IUTokenWrapper6960, BaseERC6960Wrapper, UUPSUpgradeable {
  using SafeERC20 for IERC20;

  error CollectionDisabled();
  error ApprovalForAllError();

  /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Initialize the contract
   * @param name Name of the wrapper
   * @param symbol Symbol of the wrapper
   * @param aclManager access manager for the wrapper
   */

  function initialize(
    string memory name,
    string memory symbol,
    address aclManager
  ) external initializer {
    __BaseERC6960Wrapper_init(name, symbol, aclManager);
    emit Initialized(name, symbol);
  }

  /**
   * @notice Initializes the UPolytrade
   * @dev This constructor sets the UPolytrade address and disables further initializations.
   * @param collection_ The address of the supported collection
   */
  constructor(address collection_) BaseERC6960Wrapper(collection_) {
    _disableInitializers();
  }

  /*//////////////////////////////////////////////////////////////
                            CUSTOM
    //////////////////////////////////////////////////////////////*/

  function wrappedMaxAmount() external pure returns (uint256) {
    return AMOUNT;
  }

  function collection() external view returns (address) {
    return address(_erc6960);
  }

  function wrappedMainId(uint256 tokenId) external view returns (uint256) {
    return _mainIds[tokenId];
  }

  function wrappedSubId(uint256 tokenId) external view returns (uint256) {
    return _subIds[tokenId];
  }

  function wrappedIds(uint256 tokenId) external view returns (uint256, uint256) {
    return (_mainIds[tokenId], _subIds[tokenId]);
  }

  /*//////////////////////////////////////////////////////////////
                                ERC721
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Mints a new token.
   * @dev Mints a new ERC721 token representing a Polytrade
   * @param to The address to mint the token to.
   * @param mainId The main ID to mint.
   * @param subId The sub ID to mint.

   */
  function mint(address to, uint256 mainId, uint256 subId) external {
    preMintChecks(to, mainId, subId);
    _baseMint(to, mainId, subId, true);
  }

  function burn(uint256 tokenId) external {
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
    if (!_erc6960.isApprovedForAll(address(this), marketAproval)) {
      _erc6960.setApprovalForAll(marketAproval, true);
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

    try _erc6960.setApprovalForAll(marketAproval, false) {
      // SUCCESS
    } catch {
       // ON Revert ignore
    }
     _burn(tokenId);
  }

  /**
   * @notice Verification for mint
   */
  function preMintChecks(address, uint256, uint256) public view override {
    // NOTHING TO DO
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
