// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';
import '../test-utils/setups/Setup.sol';
import {ActionSign} from '../../src/libraries/signatures/ActionSign.sol';
import {AuctionSign} from '../../src/libraries/signatures/AuctionSign.sol';
import {BuyNowSign} from '../../src/libraries/signatures/BuyNowSign.sol';
import {MarketSign} from '../../src/libraries/signatures/MarketSign.sol';
import {SellNowSign} from '../../src/libraries/signatures/SellNowSign.sol';
import {LoanLogic} from '../../src/libraries/logic/LoanLogic.sol';
import {AssetLogic as AssetLogicUnlockd} from '../../src/libraries/logic/AssetLogic.sol';

contract ActionSignMock is ActionSign {
  function getTypeHash() public pure returns (bytes32) {
    return TYPEHASH;
  }
}

contract AuctionSignMock is AuctionSign {
  function getTypeHash() public pure returns (bytes32) {
    return TYPEHASH;
  }
}

contract BuyNowSignMock is BuyNowSign {
  function getTypeHash() public pure returns (bytes32) {
    return TYPEHASH;
  }
}

contract MarketSignMock is MarketSign {
  function getTypeHash() public pure returns (bytes32) {
    return TYPEHASH;
  }
}

contract SellNowSignMock is SellNowSign {
  function getTypeHash() public pure returns (bytes32) {
    return TYPEHASH;
  }
}

contract TypeHashCheckTest is Test {
  address internal _nft;
  address internal _seam;
  uint256 internal ACTOR = 1;

  string internal constant LOAN_CONFIG =
    'SignLoanConfig(bytes32 loanId,uint256 aggLoanPrice,uint256 aggLtv,uint256 aggLiquidationThreshold,uint88 totalAssets,uint256 nonce,uint256 deadline)';

  string internal constant ASSET =
    'SignAsset(bytes32 assetId,address collection,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)';

  function setUp() public {
    // DO NOTHING
  }

  function test_loan_config_typehash() public {
    bytes32 TYPEHASH = keccak256(abi.encodePacked(LOAN_CONFIG));
    assertEq(TYPEHASH, LoanLogic.TYPEHASH);
    console.logBytes32(TYPEHASH);
  }

  function test_asset_typehash() public {
    bytes32 TYPEHASH = keccak256(abi.encodePacked(ASSET));
    assertEq(TYPEHASH, AssetLogicUnlockd.TYPEHASH);
    console.logBytes32(TYPEHASH);
  }

  function test_action_typehash() public {
    bytes32 TYPEHASH = keccak256(
      abi.encodePacked(
        'SignAction(SignLoanConfig loan,bytes32[] assets,address underlyingAsset,uint256 nonce,uint256 deadline)',
        LOAN_CONFIG
      )
    );
    ActionSignMock sign = new ActionSignMock();
    assertEq(TYPEHASH, sign.getTypeHash(), 'WRONG_TYPEHASH');
    console.logBytes32(TYPEHASH);
  }

  function test_auction_typehash() public {
    bytes32 TYPEHASH = keccak256(
      abi.encodePacked(
        'SignAuction(SignLoanConfig loan,bytes32[] assets,uint256 assetPrice,uint256 assetLtv,uint40 endTime,uint256 nonce,uint256 deadline)',
        LOAN_CONFIG
      )
    );
    AuctionSignMock sign = new AuctionSignMock();
    assertEq(TYPEHASH, sign.getTypeHash(), 'WRONG_TYPEHASH');
    console.logBytes32(TYPEHASH);
  }

  function test_buynow_typehash() public {
    bytes32 TYPEHASH = keccak256(
      abi.encodePacked(
        'SignBuyNow(SignAsset asset,address marketAdapter,uint256 assetLtv,uint256 assetLiquidationThreshold,address from,address to,bytes data,uint256 value,address marketApproval,uint256 marketPrice,address underlyingAsset,uint256 nonce,uint256 deadline)',
        ASSET
      )
    );
    BuyNowSignMock sign = new BuyNowSignMock();
    assertEq(TYPEHASH, sign.getTypeHash(), 'WRONG_TYPEHASH');
    console.logBytes32(TYPEHASH);
  }

  function test_market_typehash() public {
    bytes32 TYPEHASH = keccak256(
      abi.encodePacked(
        'SignMarket(SignLoanConfig loan,bytes32 assetId,address collection,uint256 tokenId,uint256 assetPrice,uint256 assetLtv,uint256 nonce,uint256 deadline)',
        LOAN_CONFIG
      )
    );
    MarketSignMock sign = new MarketSignMock();
    assertEq(TYPEHASH, sign.getTypeHash(), 'WRONG_TYPEHASH');
    console.logBytes32(TYPEHASH);
  }

  function test_sellnow_typehash() public {
    bytes32 TYPEHASH = keccak256(
      abi.encodePacked(
        'SignSellNow(SignLoanConfig loan,bytes32 assetId,address marketAdapter,address marketApproval,uint256 marketPrice,address underlyingAsset,address from,address to,bytes data,uint256 value,uint256 nonce,uint256 deadline)',
        LOAN_CONFIG
      )
    );
    SellNowSignMock sign = new SellNowSignMock();
    assertEq(TYPEHASH, sign.getTypeHash(), 'WRONG_TYPEHASH');
    console.logBytes32(TYPEHASH);
  }
}
