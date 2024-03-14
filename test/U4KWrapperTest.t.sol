// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from 'forge-std/console.sol';
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import './test-utils/setups/Setup.sol';

import {U4K} from '../src/protocol/wrappers/U4K.sol';

import {IUTokenWrapper} from '../src/interfaces/IUTokenWrapper.sol';
import {IERC11554K} from '../src/interfaces/wrappers/IERC11554K.sol';
import {IERC11554KController} from '../src/interfaces/wrappers/IERC11554KController.sol';
import {MockDelegationWalletRegistry} from './test-utils/mock/wrapper/MockDelegationWalletRegistry.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

contract U4KWrapperTest is Setup {
  // Mainnet
  address _controller = 0xCb4977b21e157d61A8F0f0b7d7973A9eF7462805;

  address _activeCollection = 0x927a51275a610Cd93e23b176670c88157bC48AF2; // tokenId: 42 owner: 0x96152D223763790435a886Db5DEa3aEaA602e904
  address _disabledCollection = 0x207c490D215fd661234F4333dcd4d74D7617e388; // 10

  address _tokenOwner = 0x96152D223763790435a886Db5DEa3aEaA602e904;
  address u4KWrapper;

  function setUp() public virtual override {
    super.setUpByChain(1, 19419853);

    hoax(_admin);
    _aclManager.setProtocol(makeAddr('protocol'));

    U4K wrapperImp = new U4K(_activeCollection);
    u4KWrapper = address(
      new ERC1967Proxy(
        address(wrapperImp),
        abi.encodeWithSelector(
          U4K.initialize.selector,
          'Unlockd 4K Wrapper',
          'U4KW',
          address(_aclManager),
          _controller
        )
      )
    );
  }

  function test_wrapp() external {
    hoax(_tokenOwner);
    IERC1155(_activeCollection).setApprovalForAll(u4KWrapper, true);
    hoax(_tokenOwner);
    IUTokenWrapper(u4KWrapper).mint(makeAddr('abwallet'), 42);
    console.log('HGOLA');
  }

  function test_unwrapp() external {
    hoax(_tokenOwner);
    IERC1155(_activeCollection).setApprovalForAll(u4KWrapper, true);

    hoax(_tokenOwner);
    IUTokenWrapper(u4KWrapper).mint(makeAddr('abwallet'), 42);
    assertEq(IERC1155(_activeCollection).balanceOf(_tokenOwner, 42), 0);

    hoax(makeAddr('abwallet'));
    IUTokenWrapper(u4KWrapper).burn(0);

    assertEq(IERC1155(_activeCollection).balanceOf(makeAddr('abwallet'), 42), 1);
  }
}
