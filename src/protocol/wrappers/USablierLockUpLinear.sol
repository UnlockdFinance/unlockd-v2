// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ERC721Upgradeable} from '@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol';
import {IERC721ReceiverUpgradeable} from  '@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol';
import {AddressUpgradeable} from  '@openzeppelin-upgradeable/contracts/utils/AddressUpgradeable.sol';
import {Initializable} from  '@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol';
import {ISablierV2LockupLinear} from '../../interfaces/wrappers/ISablierV2LockupLinear.sol';

/**
 * @title USablierLockUpLinear - ERC721 wrapper representing a Sablier token stream
 * @dev Implements minting and burning for Sablier token streams without transfer capabilities
 **/
contract USablierLockUpLinear is Initializable, ERC721Upgradeable, IERC721ReceiverUpgradeable {

    /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/
    error CallerNotContract();
    error TokenAlreadyMinted();
    error CallerNotNFTOwner();
    error TokenDoesNotExist();
    error CallerNotApproved();
    error UriNonExistent();
    error TransferNotSupported();
    error ApproveNotSupported();
    error SetApprovalForAllNotSupported();
    error StreamERC20NotSupported();
    error StreamCancelable();

    /*//////////////////////////////////////////////////////////////
                           VARIABLES
    //////////////////////////////////////////////////////////////*/
    ISablierV2LockupLinear private immutable _sablier; // MAKE THEM IMMUTABLE!?
    address public immutable _wethAddress;
    address public immutable _usdcAddress;

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
     * @dev Modifier to check if this UToken is allowed by the protocol
     * @param asset Address of the ERC20 token streaming
     */
    modifier isStreamERC20Allowed(address asset) {
        if (asset != _wethAddress && asset != _usdcAddress) revert StreamERC20NotSupported();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /// @dev Initializes the contract with Sablier, WETH, and USDC addresses.=
    function initialize(
    ) external initializer {
        __ERC721_init('UBound SablierV2LockupLinear', 'uSABLL'); 
    }

    constructor(address sablierLockUpLinearAddress, address wethAddress, address usdcAddress) {
        _wethAddress = wethAddress;
        _usdcAddress = usdcAddress;
        _sablier = ISablierV2LockupLinear(sablierLockUpLinearAddress);
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            ERC721
    //////////////////////////////////////////////////////////////*/
    /// @notice Mints a new token.
    /// @dev Mints a new ERC721 token representing a Sablier stream, verifies if the stream is cancelable and
    /// and if the asset in the stream is supported by the protocol.
    /// @param to The address to mint the token to.
    /// @param tokenId The token ID to mint.
    function mint(address to, uint256 tokenId) external isStreamERC20Allowed(address(_sablier.getStream(tokenId).asset)) {
        if(_sablier.ownerOf(tokenId) != msg.sender) revert CallerNotNFTOwner();
        if(!_sablier.isCancelable(tokenId)) revert StreamCancelable();

        _sablier.safeTransferFrom(msg.sender, address(this), tokenId);
        _mint(to, tokenId);

        emit Mint(msg.sender, tokenId, to);
    }

    /// @notice Burns a token.
    /// @dev Burns an ERC721 token and transfers the corresponding Sablier stream back to the burner.
    /// @param tokenId The token ID to burn.
    function burn(uint256 tokenId) external {
        _burn(tokenId);
        _sablier.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Burn(msg.sender, tokenId, _sablier.ownerOf(tokenId));
    }

    /// @dev See {ERC721-tokenURI}.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _sablier.tokenURI(tokenId);
    }

    /// @dev See {ERC721-approve}.
    function approve(address to, uint256 tokenId) public pure override {
        to; tokenId;
        revert ApproveNotSupported();
    }

    /// @dev See {ERC721-setApprovalForAll}.
    function setApprovalForAll(address operator, bool approved) public pure override {
        operator; approved;
        revert SetApprovalForAllNotSupported();
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
        revert TransferNotSupported();
    }
}