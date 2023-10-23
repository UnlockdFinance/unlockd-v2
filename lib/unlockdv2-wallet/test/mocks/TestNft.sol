// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { console } from "forge-std/console.sol";

contract TestNft is ERC721URIStorage {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    constructor() ERC721("TestNFT", "TNFT") {}

    function mint(address to, string memory tokenURI) external returns (uint256) {
        _tokenIds.increment();

        uint256 tokenId = _tokenIds.current();

        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        console.log("MSG SENDER", msg.sender);
        super.transferFrom(from, to, tokenId);
    }
}
