// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {Unlockd} from '../src/protocol/Unlockd.sol';
import {USablierLockupLinear} from '../src/protocol/wrappers/USablierLockupLinear.sol';
import {ISablierV2LockupLinear} from '../src/interfaces/wrappers/ISablierV2LockupLinear.sol';
import {ICryptoPunksMarket} from '../src/interfaces/wrappers/ICryptoPunksMarket.sol';
import {UnlockdBatchTransfer} from './test-utils/mock/wrapper/UnlockdBatchTransfer.sol';
import {MockDelegationWalletRegistry} from './test-utils/mock/wrapper/MockDelegationWalletRegistry.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract USablierLockupLinearTest is Setup {
  uint256 internal constant ACTOR = 1;

  address internal _wethAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
  address internal _usdcAddress = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
  address internal delegationRegistry = 0x15cF58144EF33af1e14b5208015d11F9143E27b9;
  address internal protocol = makeAddr('protocol');

  USablierLockupLinear uSablierLockUp;
  ISablierV2LockupLinear sablier =
    ISablierV2LockupLinear(0x7a43F8a888fa15e68C103E18b0439Eb1e98E4301);
  ERC1967Proxy uSablierProxy;
  USablierLockupLinear uSablierImplementation;
  UnlockdBatchTransfer batchTransfers;
  MockDelegationWalletRegistry _delegationRegistry;

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4917297);
    vm.startPrank(_admin);
    _aclManager.setProtocol(protocol);

    uSablierImplementation = new USablierLockupLinear(address(sablier));
    // UUPS Upgradeable Proxy
    uSablierProxy = new ERC1967Proxy(
      address(uSablierImplementation),
      abi.encodeWithSelector(
        uSablierImplementation.initialize.selector,
        'Unlockd bound Sablier LL',
        'USABLL',
        address(_aclManager)
      )
    );

    // Creates the wrapper version of the sablier contract
    uSablierLockUp = USablierLockupLinear(address(uSablierProxy));

    vm.startPrank(protocol);
    // deploy fake punk contract
    ICryptoPunksMarket cryptoPunk = ICryptoPunksMarket(0x987EfDB241fE66275b3594481696f039a82a799e);
    // deploy fake Delegation Wallet Registry - if condition onERC721Received
    _delegationRegistry = new MockDelegationWalletRegistry();
    // sets 2 fake wallet addresses: address(22) DelegationWallet and address(2) "Metamask"
    _delegationRegistry.setWallet(
      address(22),
      address(2),
      address(0),
      address(0),
      address(0),
      address(0)
    );
    // deploys a fake unlockd batch transfer
    batchTransfers = new UnlockdBatchTransfer(
      address(cryptoPunk),
      address(_aclManager),
      address(_delegationRegistry)
    );
    // sets the sablier and uSablierLockUp addresses to be wrapped
    batchTransfers.addToBeWrapped(address(sablier), address(uSablierLockUp));
    // sets the allowed uTokens
    uSablierLockUp.setERC20AllowedAddress(_wethAddress, true);
    uSablierLockUp.setERC20AllowedAddress(_usdcAddress, true);

    // after setting everythig up, we basically mint a sablier NFT and transfer it using the UnlockdBatchTransfer
    // to the DelegationWallet address, which is address(22), on the onERC721Received function we wrap the sablier NFT into uSablier.
    // almost all of the tests follow this logic, our frontend logic, in order to improve UX and avoid the user of having to wrap the NFT
    // after transfering to the Delegation Wallet.
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                              UTILS
  //////////////////////////////////////////////////////////////*/
  function mintSablierNFT(bool isCancelable, bool isTransferable) public {
    IERC20(_wethAddress).approve(address(sablier), 2 ether);

    ISablierV2LockupLinear.Durations memory duration = ISablierV2LockupLinear.Durations({
      cliff: 1701375965,
      total: 1701529208
    });

    ISablierV2LockupLinear.Broker memory broker = ISablierV2LockupLinear.Broker({
      fee: 0,
      account: address(0)
    });

    ISablierV2LockupLinear.CreateWithDurations memory create = ISablierV2LockupLinear
      .CreateWithDurations({
        sender: address(1),
        recipient: address(2),
        totalAmount: 1 ether,
        asset: ERC20(_wethAddress),
        cancelable: isCancelable,
        transferable: isTransferable,
        durations: duration,
        broker: broker
      });

    uint256 streamId = sablier.createWithDurations(create);
    assertEq(streamId, 1, 'StreamId should be 1');
    assertEq(sablier.ownerOf(1), address(2), 'The owner should be address(2)');
  }

  function approveNTransferToUWallet() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);

    vm.startPrank(address(2));
    sablier.setApprovalForAll(address(batchTransfers), true);

    UnlockdBatchTransfer.NftTransfer[] memory transfers = new UnlockdBatchTransfer.NftTransfer[](1);
    transfers[0] = UnlockdBatchTransfer.NftTransfer(address(sablier), 1);

    batchTransfers.batchTransferFrom(transfers, address(22));
    assertEq(uSablierLockUp.ownerOf(1), address(22), 'Address NOT Owner. Should be address(22)');
  }

  /*//////////////////////////////////////////////////////////////
                            POSITIVES
  //////////////////////////////////////////////////////////////*/
  function test_Initialization() public {
    assertEq(uSablierLockUp.name(), 'Unlockd bound Sablier LL', 'Token name mismatch');
    assertEq(uSablierLockUp.symbol(), 'USABLL', 'Token symbol mismatch');
  }

  function test_Add_ERC20Allowed() public {
    vm.prank(protocol);
    address newToken = makeAddr('newToken');
    uSablierLockUp.setERC20AllowedAddress(newToken, true);
    assertEq(uSablierLockUp.isERC20Allowed(newToken), true, 'Should be true');
    vm.stopPrank();
  }

  function test_authorizeUpgrade() public {
    USablierLockupLinear newImplementation = new USablierLockupLinear(address(sablier));

    vm.prank(address(1));
    vm.expectRevert(Errors.ProtocolAccessDenied.selector);
    uSablierLockUp.upgradeTo(address(newImplementation));

    vm.prank(protocol);
    uSablierLockUp.upgradeTo(address(newImplementation));
    vm.stopPrank();
  }

  function test_Mint() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    approveNTransferToUWallet();

    vm.stopPrank();
  }

  function test_1Burn() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);
    approveNTransferToUWallet();

    uint256 tokenId = 1;
    assertEq(uSablierLockUp.balanceOf(address(22)), 1, 'Balance should be 1');
    assertEq(uSablierLockUp.ownerOf(tokenId), address(22));
    vm.startPrank(address(22));
    uSablierLockUp.burn(tokenId);
    assertEq(uSablierLockUp.balanceOf(address(22)), 0, 'Balance should be 0');

    vm.stopPrank();
  }

  // function test_Withdraw_From_Stream() public {
  //   vm.startPrank(address(1));
  //   deal(_wethAddress, address(1), 2 ether);

  //   approveNTransferToUWallet();
  //   assertEq(uSablierLockUp.balanceOf(address(22)), 1, 'Balance should be 1');

  //   vm.startPrank(protocol); //onlyProtocol
  //   uint256 balanceBefore = IERC20(_wethAddress).balanceOf(protocol);
  //   uint256 streamBalance = sablier.withdrawableAmountOf(1);
  //   uSablierLockUp.burn(1);
  //   uint256 balanceAfter = IERC20(_wethAddress).balanceOf(protocol);
  //   assertEq(
  //     balanceAfter,
  //     balanceBefore + streamBalance,
  //     'Balance after should be balance before + streamBalance'
  //   );
  //   vm.stopPrank();
  // }

  /*//////////////////////////////////////////////////////////////
                            NEGATIVES
  //////////////////////////////////////////////////////////////*/
  function test_Mint_Reverts() public {
    vm.prank(address(2));
    vm.expectRevert();
    uSablierLockUp.mint(address(0), 1);
    vm.stopPrank();
  }

  function test_Add_ERC20Allowed_Reverts() public {
    vm.prank(address(2));
    vm.expectRevert(Errors.ProtocolAccessDenied.selector);
    uSablierLockUp.setERC20AllowedAddress(_wethAddress, true);
    vm.stopPrank();
  }

  // function test_Withdraw_Not_OnlyProtocol() public {
  //   vm.prank(address(this));
  //   // vm.expectRevert(0x56e40536);
  //   uSablierLockUp.burn(1);
  //   vm.stopPrank();
  // }

  // function test_Withdraw_From_Stream_Not_OnlyProtocol() public {
  //   vm.startPrank(address(1));
  //   deal(_wethAddress, address(1), 2 ether);

  //   approveNTransferToUWallet();

  //   vm.startPrank(address(this)); //onlyProtocol
  //   vm.expectRevert(Errors.BurnerNotApproved.selector);
  //   uSablierLockUp.burn(1);
  //   vm.stopPrank();
  // }

  // Test invalid input
  function test_Mint_Caller_Not_Owner() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);

    vm.startPrank(address(3));
    sablier.setApprovalForAll(address(uSablierLockUp), true);
    vm.expectRevert(Errors.CallerNotNFTOwner.selector);
    uSablierLockUp.mint(address(2), 1);
    vm.stopPrank();
  }

  function test_Mint_is_Cancebable() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(true, true);

    vm.startPrank(address(2));
    sablier.setApprovalForAll(address(uSablierLockUp), true);
    vm.expectRevert(Errors.StreamCancelable.selector);
    uSablierLockUp.mint(address(2), 1);
    vm.stopPrank();
  }

  function test_Mint_is_NOT_Transferable() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, false);

    vm.startPrank(address(2));
    sablier.setApprovalForAll(address(uSablierLockUp), true);
    vm.expectRevert(Errors.StreamNotTransferable.selector);
    uSablierLockUp.mint(address(2), 1);
    vm.stopPrank();
  }

  function test_Burn_NOT_Aproved() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    approveNTransferToUWallet();

    vm.startPrank(address(1));
    vm.expectRevert(Errors.BurnerNotApproved.selector);
    uSablierLockUp.burn(1);
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                    ERC721 FUNCTION "NOT ALLOWED"
  //////////////////////////////////////////////////////////////*/

  function test_Approve_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    approveNTransferToUWallet();

    vm.expectRevert(Errors.ApproveNotSupported.selector);
    uSablierLockUp.approve(address(1), 1);
    vm.stopPrank();
  }

  function test_Set_Approval_For_All_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    approveNTransferToUWallet();

    vm.expectRevert(Errors.SetApprovalForAllNotSupported.selector);
    uSablierLockUp.setApprovalForAll(address(1), true);
    vm.stopPrank();
  }

  function test_Transfer_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    approveNTransferToUWallet();

    vm.startPrank(address(22));
    vm.expectRevert(Errors.TransferNotSupported.selector);
    uSablierLockUp.transferFrom(address(22), address(1), 1);
    vm.stopPrank();
  }

  function test_Safe_Transfer_From_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    approveNTransferToUWallet();

    vm.startPrank(address(22));
    vm.expectRevert(Errors.TransferNotSupported.selector);
    uSablierLockUp.safeTransferFrom(address(22), address(1), 1);
    vm.stopPrank();
  }
}
