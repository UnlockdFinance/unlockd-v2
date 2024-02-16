// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

/**
 * @title Unlockd UnlockdUpgradeableProxy
 * @author Unlockd
 * @notice Proxy ERC1967Proxy
 */
contract UnlockdUpgradeableProxy is ERC1967Proxy {
  constructor(address _implementation, bytes memory _data) ERC1967Proxy(_implementation, _data) {}
}
