// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

using Actors for ActorsState global;

struct ActorsState {
  address last;
  address[] active;
  mapping(address => bool) exists;
}

library Actors {
  function get(ActorsState storage self, uint256 index) internal pure returns (address) {
    self;
    return address(uint160(100 * index));
  }

  function add(ActorsState storage self, address actor) internal returns (address) {
    if (!self.exists[actor]) {
      self.active.push(actor);
      self.last = actor;
    }
    return actor;
  }

  function pop(ActorsState storage self) internal returns (address) {
    address last = self.active[self.active.length - 1];
    self.active.pop();
    return last;
  }
}
