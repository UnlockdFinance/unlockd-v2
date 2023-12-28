// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {Unlockd} from '../src/protocol/Unlockd.sol';
import {USablierLockupLinear} from '../src/protocol/wrappers/USablierLockupLinear.sol';
import {ISablierV2LockupLinear} from '../src/interfaces/wrappers/ISablierV2LockupLinear.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract USablierLockupLinearTest is Setup {
  uint256 internal constant ACTOR = 1;

  address internal _wethAddress = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
  address internal _usdcAddress = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
  address internal protocol = makeAddr('protocol');
  
  USablierLockupLinear sablierLockUp;
  ISablierV2LockupLinear sablier = ISablierV2LockupLinear(0x7a43F8a888fa15e68C103E18b0439Eb1e98E4301);
  ERC1967Proxy sablierProxy;
  USablierLockupLinear sablierImplementation;

  function setUp() public virtual override {
    super.setUpByChain(11155111, 4917297);
    vm.startPrank(_admin);
    _aclManager.setProtocol(protocol);

    sablierImplementation = new USablierLockupLinear(address(sablier));
    sablierProxy = new ERC1967Proxy(
      address(sablierImplementation), 
      abi.encodeWithSelector(
        sablierImplementation.initialize.selector, 
        "Unlockd bound Sablier LL", 
        "USABLL",
        address(sablier), 
        address(_aclManager)
      )
    );

    sablierLockUp = USablierLockupLinear(address(sablierProxy));

    vm.startPrank(protocol);
    sablierLockUp.setERC20AllowedAddress(_wethAddress, true);
    sablierLockUp.setERC20AllowedAddress(_usdcAddress, true);
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                            POSITIVES
  //////////////////////////////////////////////////////////////*/
  function test_Initialization() public {
    assertEq(sablierLockUp.name(), "Unlockd bound Sablier LL", "Token name mismatch");
    assertEq(sablierLockUp.symbol(), "USABLL", "Token symbol mismatch");
  }

  function test_Add_ERC20Allowed() public {
    vm.prank(protocol);
    address newToken = makeAddr('newToken');
    sablierLockUp.setERC20AllowedAddress(newToken, true);
    assertEq(sablierLockUp.isERC20Allowed(newToken), true, "Should be true");
  }

  function test_authorizeUpgrade() public {
    USablierLockupLinear newImplementation = new USablierLockupLinear(address(sablier));

    vm.prank(address(1));
    vm.expectRevert(Errors.ProtocolAccessDenied.selector); 
    sablierLockUp.upgradeTo(address(newImplementation));

    vm.prank(protocol);
    sablierLockUp.upgradeTo(address(newImplementation));
  }

  function test_Mint() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(2)), 1, "Balance should be 1");
    
    vm.stopPrank();
  }

  function test_Burn() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(2)), 1, "Balance should be 1");
    
    sablierLockUp.burn(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(2)), 0, "Balance should be 0");
    assertEq(sablier.balanceOf(address(2)), 1, "Balance should be 1");
    vm.stopPrank();
  }
  
  function test_Withdraw_From_Stream() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(2)), 1, "Balance should be 1");
    
    vm.startPrank(protocol); //onlyProtocol
    uint256 balanceBefore = IERC20(_wethAddress).balanceOf(address(2));
    uint256 streamBalance = sablier.withdrawableAmountOf(1);
    sablierLockUp.withdrawFromStream(1, address(2));
    uint256 balanceAfter = IERC20(_wethAddress).balanceOf(address(2));
    assertEq(balanceAfter, balanceBefore + streamBalance, "Balance after should be balance before + streamBalance");
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                            NEGATIVES
  //////////////////////////////////////////////////////////////*/
  function test_Mint_Reverts() public {
    vm.prank(address(2));
    vm.expectRevert();
    sablierLockUp.mint(address(0), 1);
  }

  function test_Add_ERC20Allowed_Reverts() public {
    vm.prank(address(2));
    vm.expectRevert(Errors.ProtocolAccessDenied.selector);
    sablierLockUp.setERC20AllowedAddress(_wethAddress, true);
  }

  function test_Withdraw_Not_OnlyProtocol() public {
    vm.prank(address(this)); 
    vm.expectRevert(0x56e40536);
    sablierLockUp.withdrawFromStream(1, address(1));
  }

  function test_Withdraw_From_Stream_Not_OnlyProtocol() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(2)), 1, "Balance should be 1");
    
    vm.startPrank(address(this)); //onlyProtocol
    vm.expectRevert(Errors.ProtocolAccessDenied.selector);
    sablierLockUp.withdrawFromStream(1, address(2));
    vm.stopPrank();
  }

  // Test invalid input 
  function test_Mint_Caller_Not_Owner() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(3)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    vm.expectRevert(Errors.CallerNotNFTOwner.selector);
    sablierLockUp.mint(address(2), 1);
    vm.stopPrank();
  }

  function test_Mint_is_Cancebable() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(true, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    vm.expectRevert(Errors.StreamCancelable.selector);
    sablierLockUp.mint(address(2), 1);
    vm.stopPrank();
  }

  function test_Mint_is_NOT_Transferable() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, false);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    vm.expectRevert(Errors.StreamNotTransferable.selector);
    sablierLockUp.mint(address(2), 1);
    vm.stopPrank();
  }

  function test_Burn_NOT_Aproved() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    assertEq(sablierLockUp.balanceOf(address(2)), 1, "Balance should be 1");
    
    vm.startPrank(address(1));
    vm.expectRevert(Errors.BurnerNotApproved.selector);
    sablierLockUp.burn(address(2), 1);
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                    ERC721 FUNCTION "NOT ALLOWED"
  //////////////////////////////////////////////////////////////*/

  function test_Approve_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    vm.expectRevert(Errors.ApproveNotSupported.selector);
    sablierLockUp.approve(address(1), 1); 
  }

  function test_Set_Approval_For_All_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    vm.expectRevert(Errors.SetApprovalForAllNotSupported.selector);
    sablierLockUp.setApprovalForAll(address(1), true);
  }  

  function test_Transfer_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    vm.expectRevert(Errors.TransferNotSupported.selector);
    sablierLockUp.transferFrom(address(2), address(1), 1);
  }

  function test_Safe_Transfer_From_Reverts() public {
    vm.startPrank(address(1));
    deal(_wethAddress, address(1), 2 ether);

    mintSablierNFT(false, true);
    
    vm.startPrank(address(2)); 
    sablier.setApprovalForAll(address(sablierLockUp), true);
    sablierLockUp.mint(address(2), 1);
    vm.expectRevert(Errors.TransferNotSupported.selector);
    sablierLockUp.safeTransferFrom(address(2), address(1), 1); 
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

    ISablierV2LockupLinear.CreateWithDurations memory create = ISablierV2LockupLinear.CreateWithDurations({
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
    assertEq(streamId, 1, "StreamId should be 1");
    assertEq(sablier.ownerOf(1), address(2), "The owner should be address(2)");
  }
}