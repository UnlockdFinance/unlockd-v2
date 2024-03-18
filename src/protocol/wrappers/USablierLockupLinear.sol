// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ISablierV2LockupLinear} from '../../interfaces/wrappers/ISablierV2LockupLinear.sol';
import {IUSablierLockupLinear} from '../../interfaces/wrappers/IUSablierLockupLinear.sol';
import {BaseERC721Wrapper, Errors} from '../../libraries/base/BaseERC721Wrapper.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

/**
 * @title USablierLockupLinear - ERC721 wrapper representing a Sablier token stream
 * @dev Implements minting and burning for Sablier token streams without transfer capabilities
 **/
contract USablierLockupLinear is IUSablierLockupLinear, BaseERC721Wrapper, UUPSUpgradeable {
  /*//////////////////////////////////////////////////////////////
                           VARIABLES
    //////////////////////////////////////////////////////////////*/
  mapping(address => bool) private _ERC20Allowed;

  /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
  /**
   * @dev Initializes the contract with Sablier, WETH, and USDC addresses.=
   */
  function initialize(
    string memory name,
    string memory symbol,
    address aclManager
  ) external initializer {
    __BaseERC721Wrapper_init(name, symbol, aclManager);

    emit Initialized(name, symbol);
  }

  /**
   * @notice Initializes the USablierLockUpLinear contract by setting the Sablier lockup linear address.
   * @dev This constructor sets the Sablier lockup linear address and disables further initializations.
   * @param sablierLockUpLinearAddress The address of the Sablier lockup linear contract,
   */
  constructor(address sablierLockUpLinearAddress) BaseERC721Wrapper(sablierLockUpLinearAddress) {
    _disableInitializers();
  }

  /*//////////////////////////////////////////////////////////////
                            CUSTOM
    //////////////////////////////////////////////////////////////*/

  function wrappedMaxAmount() external pure returns (uint256) {
    return 1;
  }

  function collection() external view returns (address) {
    return address(_erc721);
  }

  function wrappedTokenId(uint256 tokenId) external pure returns (uint256) {
    return tokenId;
  }

  /*//////////////////////////////////////////////////////////////
                            CONTRACT
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Sets the ERC20 token addresses allowed by the protocol (WETH and USDC) and the token from the streams.
   * @param asset the address of the ERC20 token
   * @param allowed boolean indicating if the token is allowed
   */
  function setERC20AllowedAddress(address asset, bool allowed) external onlyProtocol {
    _ERC20Allowed[asset] = allowed;

    emit AllowedAddress(asset, allowed);
  }

  /**
   * @notice validates is the given ERC20 token is allowed by the protocol (WETH and USDC).
   * @param asset the address of the ERC20 token
   */
  function isERC20Allowed(address asset) external view returns (bool) {
    return _ERC20Allowed[asset];
  }

  /*//////////////////////////////////////////////////////////////
                            SABLIER
    //////////////////////////////////////////////////////////////*/

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
  function mint(address to, uint256 tokenId) public override {
    preMintChecks(to, tokenId);
    _baseMint(to, tokenId);
  }

  /**
   * @notice Verifies if the stream is cancelable, transferable, if the token matches our uToken
   *  and if the owner is not the user or this contract.
   *  adding the preMintChecks will bring flexibility to the BASEERC721Wrapper contract.
   * @param tokenId the token id representing the stream
   */
  function preMintChecks(address, uint256 tokenId) public view override {
    ISablierV2LockupLinear sablier = ISablierV2LockupLinear(address(_erc721));
    if (!_ERC20Allowed[address(sablier.getAsset(tokenId))]) revert Errors.StreamERC20NotSupported();
    if (sablier.ownerOf(tokenId) != msg.sender && sablier.ownerOf(tokenId) != address(this))
      revert Errors.CallerNotNFTOwner();
    if (sablier.isCancelable(tokenId)) revert Errors.StreamCancelable();
    if (!sablier.isTransferable(tokenId)) revert Errors.StreamNotTransferable();
  }

  /**
   * @notice Burns a token.
   * @dev Burns an ERC721 token representing a Sablier stream and transfers the underlying asset to its owner.
   * @param tokenId The token ID to burn.
   */
  function burn(uint256 tokenId) external {
    ISablierV2LockupLinear(address(_erc721)).withdrawMaxAndTransfer(tokenId, msg.sender);
    _baseBurn(tokenId, msg.sender, false);
  }

  function sellOnMarket(
    address underlyingAsset,
    uint256 amount,
    address marketApproval,
    uint256 tokenId,
    address to,
    uint256 value,
    bytes memory data,
    address amountTo
  ) external {
    // NOTHING TO DO
    ISablierV2LockupLinear(address(_erc721)).withdrawMaxAndTransfer(tokenId, amountTo);
    _burn(tokenId);
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
