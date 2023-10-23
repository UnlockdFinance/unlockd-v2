// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

interface IAllowedControllers {
    event Collections(address indexed collections, bool isAllowed);

    event DelegationController(address indexed delegationController, bool isAllowed);

    function isAllowedDelegationController(address _controller) external view returns (bool);

    function isAllowedCollection(address _collection) external view returns (bool);
}
