// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./TestNft.sol";
import "./TokenERC20.sol";

contract Adapter {
    address private _token;

    constructor(address token) {
        _token = token;
    }

    function sell(address _contract, uint256 _tokenId, address to) external {
        TestNft(_contract).transferFrom(to, address(this), _tokenId);
        TokenERC20(_token).transfer(to, 1000);
    }
}
