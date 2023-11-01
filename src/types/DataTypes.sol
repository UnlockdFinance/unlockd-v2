// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

library DataTypes {

  ///////////////////////////////////////////////////////
  // ASSET 
  ///////////////////////////////////////////////////////

  struct ReserveData {
    // Slot 0
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    // Slot 1
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    // Slot 2
    address uToken;
    // last update
    uint40 lastUpdateTimestamp;
    // Decimals of the underlyingAsset
    uint8 decimals;
    // Reserve factor
    uint16 reserveFactor;
    // Slot 3
    //debt token
    address debtTokenAddress;
    // Slot 4
    // Underlying Token
    address underlyingAsset;
    // Slot 5
    //address of the interest rate strategy 
    address interestRateAddress;
    
  }

  ///////////////////////////////////////////////////////
  // ORDER 
  ///////////////////////////////////////////////////////

  enum OrderType {
    TYPE_LIQUIDATION_AUCTION,
    //Auction with BIDs
    TYPE_AUCTION,
    // Fixed price only buynow function
    TYPE_FIXED_PRICE,
    // Fixed price and auction with bids
    TYPE_FIXED_PRICE_AND_AUCTION
  }

  struct OfferItem {
    // Slot 0
    bytes32 loanId;
    // Slot 1
    bytes32 assetId;
    // Slot 2
    uint128 startAmount;
    uint128 endAmount; 
    // Slot 3
    uint128 debtToSell;
  }  

  struct Timeframe {
    // Slot 0
    uint40 startTime;
    uint40 endTime;
  }

  struct Bid {
    // Slot 0
    bytes32 loanId;
    // Slot 1
    address buyer;
    // Slot 2
    uint128 amountToPay;
    uint128 amountOfDebt;
  }

  struct Order {
    // Slot 0
    bytes32 orderId;
    // Slot 1
    address owner;
    OrderType orderType;
    uint88 countBids;
    // Slot 2
    OfferItem offer;
    // Slot 3
    Timeframe timeframe;
    // Slot 4
    Bid bid;
  }

  ///////////////////////////////////////////////////////
  // LOAN 
  ///////////////////////////////////////////////////////

  struct Loan {
    // Slot 0
    bytes32 loanId;
    // Slot 1
    address uToken;
    uint88 totalAssets;
    LoanState state;
    // Slot 2
    address underlyingAsset;
    // Slot 3
    address owner;
  }

  enum LoanState {
    ACTIVE,
    FREEZE
  }

  ///////////////////////////////////////////////////////
  // Asset
  ///////////////////////////////////////////////////////

  struct Asset {
    address collection;
    uint256 tokenId;
  }
 
  ///////////////////////////////////////////////////////
  // SIGNATURES 
  ///////////////////////////////////////////////////////

  struct EIP712Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 deadline;
  }

  struct SignLoanConfig {
    bytes32 loanId;
    uint256 aggLoanPrice;
    uint256 aggLtv;
    uint256 aggLiquidationThreshold;
    uint88 totalAssets;
    uint256 nonce;
    uint256 deadline;
  }

  struct SignAsset {
    bytes32 assetId;
    address collection;
    uint256 tokenId;
    uint256 price;
    uint256 nonce;
    uint256 deadline;
  }

  struct SignBuyNow {
    SignAsset asset;
    uint256 assetLtv; // configuration asset
    uint256 assetLiquidationThreshold; // configuration asset
    // tx Data
    address from;
    address to;
    bytes data;
    uint256 value;
    // Configuration
    address marketApproval; // Approval needed to make the buy
    uint256 marketPrice; // Market Adapter Price (Reservoir, Opensea ...)
    address underlyingAsset; // asset needed to buy
   
    uint256 nonce;
    uint256 deadline;
  }

  struct SignSellNow {
    SignLoanConfig loan;
    // approval
    address marketApproval;
    uint256 marketPrice;
    address underlyingAsset;
    // sell data
    address from;
    address to;
    bytes data;
    uint256 value;
  
    // signature
    uint256 nonce;
    uint256 deadline;
  }

  struct SignAction {
    SignLoanConfig loan;
    bytes32[] assets;
    uint256 nonce;
    uint256 deadline;
  }

  struct SignMarket {
    SignLoanConfig loan;
    bytes32 assetId;
    address collection;
    uint256 tokenId;
    uint256 assetPrice;
    uint256 assetLtv;
    uint256 nonce;
    uint256 deadline;
  }

  struct SignAuction {
    SignLoanConfig loan;
    bytes32 assetId;
    address collection;
    uint256 tokenId;
    uint256 assetPrice;
    uint256 assetLtv;
    uint40 endTime; // @audit-info review this
    uint256 nonce;
    uint256 deadline;
  }
}
