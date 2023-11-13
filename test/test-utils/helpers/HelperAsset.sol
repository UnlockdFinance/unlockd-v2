// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import '../mock/asset/MintableERC20.sol';

using Assets for AssetsState global;

struct AssetsState {
  mapping(string => address) list;
}

library Assets {
  function get(AssetsState storage self, string memory name) internal view returns (address) {
    return self.list[name];
  }

  function makeAsset(
    AssetsState storage self,
    string memory name,
    uint8 decimals
  ) internal returns (address) {
    if (self.list[name] == address(0)) {
      MintableERC20 asset = new MintableERC20(name, name, decimals);
      self.list[name] = address(asset);
      return self.list[name];
    }
    return self.list[name];
  }

  function mintToAddress(
    AssetsState storage self,
    address addr,
    string memory name,
    uint256 amount
  ) internal {
    MintableERC20(self.list[name]).mintToAddress(amount, addr);
  }
}
