// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import '../helpers/HelperActor.sol'; // solhint-disable-line

contract ActorsBase {
  // Actors
  ActorsState internal _actors;

  function getActorAddress(uint256 index) internal returns (address) {
    return _actors.get(index);
  }
}
