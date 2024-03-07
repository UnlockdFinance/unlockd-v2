// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

/**
 * @title Unlockd Minimal Proxy
 * @author Unlockd
 * @notice Proxy for the modules
 * @dev fork from https://github.com/euler-xyz/euler-contracts/blob/master/contracts/Proxy.sol
 */
contract UnlockdMinimalProxy {
  address immutable creator;

  constructor() {
    creator = msg.sender;
  }

  // External interface

  fallback() external {
    address creator_ = creator;
    assembly {
      mstore(0, 0xe9c4a3ac00000000000000000000000000000000000000000000000000000000) // dispatch() selector
      calldatacopy(4, 0, calldatasize())
      mstore(add(4, calldatasize()), shl(96, caller()))

      let result := call(gas(), creator_, 0, 0, add(24, calldatasize()), 0, 0)
      returndatacopy(0, 0, returndatasize())

      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
