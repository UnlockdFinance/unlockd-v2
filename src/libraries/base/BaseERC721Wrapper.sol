// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ERC721Upgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol';
import {IERC721ReceiverUpgradeable} from  '@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol';
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
    ERC721Upgradeable internal _erc721;
    address internal _wethAddress;
    address internal _usdcAddress;
    address internal _aclManager;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a token is minted.
    /// @param minter Address of the minter.
    /// @param tokenId ID of the minted token.
    /// @param to Address of the recipient.
    event Mint(address indexed minter, uint256 tokenId, address indexed to);
    
    /// @notice Emitted when a token is burned.
    /// @param burner Address of the burner.
    /// @param tokenId ID of the burned token.
    /// @param owner Address of the token owner.
    event Burn(address indexed burner, uint256 tokenId, address indexed owner);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Modifier that checks if the sender has Protocol ROLE
     */
    modifier onlyProtocol() {
        if (IACLManager(_aclManager).isProtocol(_msgSender()) == false) {
        revert Errors.ProtocolAccessDenied();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the sender has Emergency ROLE
     */
    modifier onlyEmergency() {
        if (IACLManager(_aclManager).isEmergencyAdmin(_msgSender()) == false) {
        revert Errors.EmergencyAccessDenied();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializer for the BaseERC721Wrapper contract.
    /// @dev Sets up the base ERC721 wrapper with necessary details and configurations.
    /// This function uses the `initializer` modifier to ensure it's only called once, 
    /// which is a common pattern in upgradeable contracts to replace constructors.
    /// @param name The name for the ERC721 token.
    /// @param symbol The symbol for the ERC721 token.
    /// @param underlyingAsset The address of the underlying ERC721 asset.
    /// @param aclManager The address of the ACL (Access Control List) manager contract.
    /// @param wethAddress The address of the WETH (Wrapped ETH) contract.
    /// @param usdcAddress The address of the USDC (USD Coin) contract.
    function __BaseERC721Wrapper_init(
        string memory name, 
        string memory symbol,
        address underlyingAsset, 
        address aclManager, 
        address wethAddress, 
        address usdcAddress
    ) internal initializer {
        __ERC721_init(name, symbol); 
        _erc721 = ERC721Upgradeable(underlyingAsset);
        _aclManager = aclManager;
        _wethAddress = wethAddress;
        _usdcAddress = usdcAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints a new token.
    /// @dev Mints a new ERC721 token representing a Sablier stream, verifies if the stream is cancelable and
    /// and if the asset in the stream is supported by the protocol.
    /// @param to The address to mint the token to.
    /// @param tokenId The token ID to mint.
    function baseMint(address to, uint256 tokenId) internal {
        _erc721.safeTransferFrom(msg.sender, address(this), tokenId);
        _mint(to, tokenId);

        emit Mint(msg.sender, tokenId, to);
    }

    /// @notice Burns a token.
    /// @dev Burns an ERC721 token and transfers the corresponding Sablier stream back to the burner.
    /// @param tokenId The token ID to burn.
    function baseBurn(uint256 tokenId) internal {
        _burn(tokenId);
        _erc721.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Burn(msg.sender, tokenId, _erc721.ownerOf(tokenId));
    }

    /// @dev See {ERC721-tokenURI}.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _erc721.tokenURI(tokenId);
    }

    /// @dev See {ERC721-approve}.
    function approve(address to, uint256 tokenId) public pure override {
        to; tokenId;
        revert Errors.ApproveNotSupported();
    }

    /// @dev See {ERC721-setApprovalForAll}.
    function setApprovalForAll(address operator, bool approved) public pure override {
        operator; approved;
        revert Errors.SetApprovalForAllNotSupported();
    }

    /// @dev See {ERC721-onERC721Received}.
    function onERC721Received(
    address operator, 
    address from, 
    uint256 tokenId, 
    bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @dev See {ERC721-_transfer}.
    function _transfer(address from, address to, uint256 tokenId) internal pure override {
        from; to; tokenId;
        revert Errors.TransferNotSupported();
    }
}