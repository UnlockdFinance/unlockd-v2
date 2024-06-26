// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;
import {IUTokenWrapper} from '../IUTokenWrapper.sol';

/**
 * @title IUSablierLockupLinear - Interface for the USablierLockupLinear contract
 **/
interface IUSablierLockupLinear is IUTokenWrapper {
  /*//////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/
  event AllowedAddress(address indexed asset, bool allowed);

  /*//////////////////////////////////////////////////////////////
                            CONTRACT
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice validates is the given ERC20 token is allowed by the protocol (WETH and USDC).
   * @param asset the address of the ERC20 token
   */
  function isERC20Allowed(address asset) external view returns (bool);

  // /**
  //  * @notice Verifies if the stream is cancelable, transferable, if the token matches our uToken
  //  *  and if the owner is not the user or this contract.
  //  *  adding the preMintChecks will bring flexibility to the BASEERC721Wrapper contract.
  //  * @param tokenId the token id representing the stream
  //  */
  // function preMintChecks(address, uint256 tokenId) external view;

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
  function mint(address to, uint256 tokenId) external;
}
