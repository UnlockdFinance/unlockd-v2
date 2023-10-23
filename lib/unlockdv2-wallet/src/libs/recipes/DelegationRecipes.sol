// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Errors } from "../helpers/Errors.sol";

/**
 * @title DelegationRecipes
 * @author BootNode
 * @dev Registers the functions that will be allowed to be executed by assets delegates.
 * Functions are grouped by target contract and asset collection.
 */
contract DelegationRecipes is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // collection address -> keccak256(collection, contract, selector)
    mapping(address => EnumerableSet.Bytes32Set) internal functionByCollection;

    // keccak256(collection, contract, selector) -> description
    mapping(bytes32 => string) public functionDescriptions;

    event AddRecipe(address indexed collection, address[] contracts, bytes4[] selectors, string[] description);

    event RemoveRecipe(address indexed collection, address[] contracts, bytes4[] selectors);

    /**
     * @notice Adds a group of allowed functions to a collection.
     * @param _collection - The asset collection address.
     * @param _contracts - The target contract addresses.
     * @param _selectors - The allowed function selectors.
     */
    function add(
        address _collection,
        address[] calldata _contracts,
        bytes4[] calldata _selectors,
        string[] calldata _descriptions
    ) external onlyOwner {
        if (_contracts.length != _selectors.length || _selectors.length != _descriptions.length)
            revert Errors.DelegationRecipes__add_arityMismatch();

        bytes32 functionId;
        uint256 length = _contracts.length;
        for (uint256 i; i < length; ) {
            functionId = keccak256(abi.encodePacked(_collection, _contracts[i], _selectors[i]));
            functionByCollection[_collection].add(functionId);
            functionDescriptions[functionId] = _descriptions[i];

            emit AddRecipe(_collection, _contracts, _selectors, _descriptions);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Removes a group of allowed functions from a collection.
     * @param _collection - The owner's address.
     * @param _contracts - The owner's address.
     * @param _selectors - The owner's address.
     */
    function remove(
        address _collection,
        address[] calldata _contracts,
        bytes4[] calldata _selectors
    ) external onlyOwner {
        if (_contracts.length != _selectors.length) revert Errors.DelegationRecipes__remove_arityMismatch();

        bytes32 functionId;
        uint256 length = _contracts.length;
        for (uint256 i; i < length; ) {
            functionId = keccak256(abi.encodePacked(_collection, _contracts[i], _selectors[i]));
            functionByCollection[_collection].remove(functionId);
            delete functionDescriptions[functionId];

            emit RemoveRecipe(_collection, _contracts, _selectors);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Checks if a function is allowed for a collection.
     * @param _collection - The owner's address.
     * @param _contract - The owner's address.
     * @param _selector - The owner's address.
     */
    function isAllowedFunction(address _collection, address _contract, bytes4 _selector) external view returns (bool) {
        bytes32 functionId = keccak256(abi.encodePacked(_collection, _contract, _selector));
        return functionByCollection[_collection].contains(functionId);
    }
}
