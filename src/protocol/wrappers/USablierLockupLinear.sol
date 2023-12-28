// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ISablierV2LockupLinear} from '../../interfaces/wrappers/ISablierV2LockupLinear.sol';
import {BaseERC721Wrapper, Errors} from '../../libraries/base/BaseERC721Wrapper.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

/**
 * @title USablierLockupLinear - ERC721 wrapper representing a Sablier token stream
 * @dev Implements minting and burning for Sablier token streams without transfer capabilities
 **/
contract USablierLockupLinear is BaseERC721Wrapper, UUPSUpgradeable {

    /*//////////////////////////////////////////////////////////////
                           VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISablierV2LockupLinear private immutable _sablier;
    mapping(address => bool) private _ERC20Allowed;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Modifier to check if this UToken is allowed by the protocol
     * @param asset Address of the ERC20 token streaming
     */
    modifier isStreamERC20Allowed(address asset) {
        if (!_ERC20Allowed[asset]) revert Errors.StreamERC20NotSupported();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /** 
     * @dev Initializes the contract with Sablier, WETH, and USDC addresses.=
     */
    function initialize(
        string memory name, 
        string memory symbol,
        address underlyingAsset, 
        address aclManager
    ) external initializer {
        __BaseERC721Wrapper_init(
            name, 
            symbol,
            underlyingAsset, 
            aclManager
        );

        emit Initialized(underlyingAsset);
    }

    /** 
     * @notice Initializes the USablierLockUpLinear contract by setting the Sablier lockup linear address.
     * @dev This constructor sets the Sablier lockup linear address and disables further initializations.
     * @param sablierLockUpLinearAddress The address of the Sablier lockup linear contract, 
     */
    constructor(address sablierLockUpLinearAddress) {
        _sablier = ISablierV2LockupLinear(sablierLockUpLinearAddress);
        _disableInitializers();
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
    /**
     * @notice The protocol will call to withdraw from the stream
     * if HF < 1, and enough funds are available in the stream to make the position green.
     * Otherwise the protocol will wait for a bidder/redeem or the stream to end.
     * @param tokenId the token id representing the stream
     * @param to the address to send the funds to
     */
    function withdrawFromStream(uint256 tokenId, address to) external onlyProtocol {
        _sablier.withdrawMaxAndTransfer(tokenId, to);
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
    function mint(address to, uint256 tokenId) external isStreamERC20Allowed(address(_sablier.getAsset(tokenId))) {
        if(_sablier.ownerOf(tokenId) != msg.sender) revert Errors.CallerNotNFTOwner();
        if(_sablier.isCancelable(tokenId)) revert Errors.StreamCancelable();
        if(!_sablier.isTransferable(tokenId)) revert Errors.StreamNotTransferable();

        baseMint(to, tokenId);
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