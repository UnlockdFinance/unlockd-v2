// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import { DelegationOwner } from "src/libs/owners/DelegationOwner.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// import "forge-std/Test.sol";

contract TestLoanController is Ownable {
    function lock(address _safeOwner, address _nft, uint256 _id, uint256 _claimDate) external onlyOwner {
        // DelegationOwner(_safeOwner).lockAsset(_nft, _id, _claimDate);
    }

    function unlock(address _safeOwner, address _nft, uint256 _id) external onlyOwner {
        // DelegationOwner(_safeOwner).unlockAsset(_nft, _id);
    }

    function claim(address _safeOwner, address _nft, uint256 _id) external onlyOwner {
        // DelegationOwner(_safeOwner).claimAsset(_nft, _id, owner());
    }
}
