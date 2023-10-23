// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

library AssetLogic {
    function assetId(address _asset, uint256 _id) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_asset, _id));
    }

    function getSelector(bytes memory _data) internal pure returns (bytes4 selector) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(_data, 32))
        }
    }
}
