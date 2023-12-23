// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ISablierV2LockupLinear} from '../../interfaces/wrappers/ISablierV2LockupLinear.sol';
import {BaseERC721Wrapper, Errors} from '../../libraries/base/BaseERC721Wrapper.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

/**
 * @title USablierLockUpLinear - ERC721 wrapper representing a Sablier token stream
 * @dev Implements minting and burning for Sablier token streams without transfer capabilities
 **/
contract USablierLockUpLinear is BaseERC721Wrapper, UUPSUpgradeable {

    /*//////////////////////////////////////////////////////////////
                           VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISablierV2LockupLinear private immutable _sablier;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Modifier to check if this UToken is allowed by the protocol
     * @param asset Address of the ERC20 token streaming
     */
    modifier isStreamERC20Allowed(address asset) {
        if (asset != _wethAddress && asset != _usdcAddress) revert Errors.StreamERC20NotSupported();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /** 
     * @dev Initializes the contract with Sablier, WETH, and USDC addresses.=
     */
    function initialize(
        address underlyingAsset, 
        address aclManager, 
        address wethAddress, 
        address usdcAddress,
        string memory name, 
        string memory symbol
    ) external initializer {
        __BaseERC721Wrapper_init(
            name, 
            symbol,
            underlyingAsset, 
            aclManager, 
            wethAddress, 
            usdcAddress
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
                            SABLIER
    //////////////////////////////////////////////////////////////*/
    function withDrawFromStream(uint256 tokenId) external onlyProtocol {
        // need to withdraw all the stream balance and repay the loan or the utoken. 
        _sablier.withdrawMax(tokenId, address(this));
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
    function mint(address to, uint256 tokenId) external isStreamERC20Allowed(address(_sablier.getStream(tokenId).asset)) {
        if(_sablier.ownerOf(tokenId) != msg.sender) revert Errors.CallerNotNFTOwner();
        if(!_sablier.isCancelable(tokenId)) revert Errors.StreamCancelable();

        baseMint(to, tokenId);

        emit Mint(msg.sender, tokenId, to);
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