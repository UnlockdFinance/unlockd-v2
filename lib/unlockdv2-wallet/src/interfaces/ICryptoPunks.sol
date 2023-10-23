// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

interface ICryptoPunks {
    struct Offer {
        bool isForSale;
        uint256 punkIndex;
        address seller;
        uint256 minValue; // in ether
        address onlySellTo; // specify to sell only to a specific person
    }

    // A record of punks that are offered for sale at a specific minimum value, and perhaps to a specific person
    function punksOfferedForSale(uint256 punkIndex) external view returns (Offer memory);

    function balanceOf(address owner) external view returns (uint256);

    function punkIndexToAddress(uint256 punkIndex) external view returns (address);

    function transferPunk(address to, uint256 punkIndex) external;

    function enterBidForPunk(uint punkIndex) external payable;

    function acceptBidForPunk(uint punkIndex, uint minPrice) external;

    function offerPunkForSale(uint punkIndex, uint minSalePriceInWei) external;

    function offerPunkForSaleToAddress(uint256 punkIndex, uint256 minSalePriceInWei, address toAddress) external;
}
