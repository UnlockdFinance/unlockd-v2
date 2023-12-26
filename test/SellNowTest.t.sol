// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import './test-utils/setups/Setup.sol';

import {stdStorage, StdStorage, Test, Vm} from 'forge-std/Test.sol';
import {IDelegationWalletRegistry} from '@unlockd-wallet/src/interfaces/IDelegationWalletRegistry.sol';

import {AssetLogic} from '@unlockd-wallet/src/libs/logic/AssetLogic.sol';
import {Errors as WalletErrors} from '@unlockd-wallet/src/libs/helpers/Errors.sol';

import {SellNow, SellNowSign} from '../src/protocol/modules/SellNow.sol';
import {Action, ActionSign} from '../src/protocol/modules/Action.sol';
import {DataTypes} from '../src/types/DataTypes.sol';
import {Unlockd} from '../src/protocol/Unlockd.sol';
import './test-utils/mock/asset/MintableERC20.sol';
import {NFTMarket} from './test-utils/mock/market/NFTMarket.sol';
import {console} from 'forge-std/console.sol';

// contract SellNowTest is Setup {
//   uint256 internal ACTOR = 1;
//   address internal _actor;
//   address internal _nft;
//   address internal _sellNow;
//   address internal _action;
//   address internal _wallet;
//   uint256 internal deadlineIncrement;
//   NFTMarket internal _market;
//   ReservoirData dataSellWETHCurrency;

//   function setUp() public virtual override {
//     super.setUp();
//     _market = new NFTMarket();
//     _actor = getActorAddress(ACTOR);
//     // // Fill the protocol with funds
//     addFundToUToken(address(_uTokens['WETH']), 'WETH', 10 ether);
//     addFundToUToken(address(_uTokens['DAI']), 'DAI', 10 ether);
//     // Add funds to the market
//     writeTokenBalance(address(_market), makeAsset('WETH'), 100 ether);

//     // Create wallet and mint to the safe wallet
//     createWalletAndMintTokens(ACTOR, 'PUNK');
//     _action = _unlock.moduleIdToProxy(Constants.MODULEID__ACTION);
//     _sellNow = _unlock.moduleIdToProxy(Constants.MODULEID__SELLNOW);
//     _nft = super.getNFT('PUNK');
//   }

//   /////////////////////////////////////////////////////////////////////////////////
//   // BORROW
//   /////////////////////////////////////////////////////////////////////////////////

//   struct GenerateSignParams {
//     address user;
//     bytes32 loanId;
//     uint256 price;
//     uint88 totalAssets;
//   }

//   function _generate_signature_borrow(
//     GenerateSignParams memory params
//   )
//     internal
//     view
//     returns (
//       DataTypes.SignAction memory,
//       DataTypes.EIP712Signature memory,
//       bytes32[] memory,
//       DataTypes.Asset[] memory
//     )
//   {
//     // Get nonce from the user
//     uint256 nonce = ActionSign(_action).getNonce(params.user);
//     uint256 deadline = block.timestamp + 1000;

//     // Generate AssetId
//     bytes32[] memory assetsIds = new bytes32[](params.totalAssets);
//     DataTypes.Asset[] memory assets = new DataTypes.Asset[](params.totalAssets);
//     for (uint256 i = 0; i < params.totalAssets; ) {
//       assetsIds[i] = AssetLogic.assetId(address(_nft), i + 1);
//       assets[i] = DataTypes.Asset({collection: address(_nft), tokenId: i + 1});
//       unchecked {
//         i++;
//       }
//     }
//     // Generate Assets Array

//     DataTypes.SignAction memory data;
//     DataTypes.EIP712Signature memory sig;
//     {
//       // Create the struct
//       data = DataTypes.SignAction({
//         loan: DataTypes.SignLoanConfig({
//           loanId: params.loanId, // Because is new need to be 0
//           aggLoanPrice: params.price,
//           aggLtv: 6000,
//           aggLiquidationThreshold: 6000,
//           totalAssets: params.totalAssets,
//           nonce: nonce,
//           deadline: deadline
//         }),
//         assets: assetsIds,
//         underlyingAsset: address(0),
//         nonce: nonce,
//         deadline: deadline
//       });

//       bytes32 digest = Action(_action).calculateDigest(nonce, data);
//       (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

//       // Build signature struct
//       sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
//     }
//     return (data, sig, assetsIds, assets);
//   }

//   function borrow_asset(uint88 totalNfts) public useActor(ACTOR) returns (bytes32 loanId) {
//     uint256 amountToBorrow = 1 ether;
//     vm.recordLogs();
//     // User doesn't have WETH
//     assertEq(balanceOfAsset('WETH', _actor), 0);
//     // Get data signed
//     (
//       DataTypes.SignAction memory signAction,
//       DataTypes.EIP712Signature memory sig,
//       bytes32[] memory assetsIds,
//       DataTypes.Asset[] memory assets
//     ) = _generate_signature_borrow(
//         GenerateSignParams({user: _actor, loanId: 0, price: 2 ether, totalAssets: totalNfts})
//       );

//     // Borrow amount
//     Action(_action).borrow(amountToBorrow, assets, signAction, sig);
//     // We check the new balance
//     assertEq(balanceOfAsset('WETH', super.getActorAddress(ACTOR)), amountToBorrow);
//     // Check if the asset is locked
//     IDelegationWalletRegistry.Wallet memory wallet = DelegationWalletRegistry(_walletRegistry)
//       .getOwnerWalletAt(super.getActorAddress(ACTOR), 0);

//     assertEq(ProtocolOwner(wallet.protocolOwner).isAssetLocked(assetsIds[0]), true);

//     Vm.Log[] memory entries = vm.getRecordedLogs();
//     // Return LoanId
//     loanId = bytes32(entries[entries.length - 1].topics[2]);
//   }

//   /////////////////////////////////////////////////////////////////////////////////
//   // SELLNOW
//   /////////////////////////////////////////////////////////////////////////////////
//   struct LoanData {
//     bytes32 loanId;
//     uint256 aggLoanPrice;
//     uint88 totalAssets;
//   }

//   function _generate_signature(
//     address sender,
//     LoanData memory loanData
//   ) internal view returns (DataTypes.SignSellNow memory, DataTypes.EIP712Signature memory) {
//     // Get nonce from the user
//     uint256 nonce = SellNowSign(_sellNow).getNonce(sender);
//     uint256 deadline = block.timestamp + 1000;

//     DataTypes.SignSellNow memory data;
//     DataTypes.EIP712Signature memory sig;
//     {
//       // Create the struct
//       data = DataTypes.SignSellNow({
//         loan: DataTypes.SignLoanConfig({
//           loanId: loanData.loanId, // Because is new need to be 0
//           aggLoanPrice: loanData.aggLoanPrice,
//           aggLtv: 6000,
//           aggLiquidationThreshold: 6000,
//           totalAssets: loanData.totalAssets,
//           nonce: nonce,
//           deadline: deadline
//         }),
//         marketApproval: dataSellWETHCurrency.approvalTo,
//         marketPrice: dataSellWETHCurrency.price,
//         underlyingAsset: config.weth,
//         from: dataSellWETHCurrency.from,
//         to: dataSellWETHCurrency.to,
//         data: dataSellWETHCurrency.data,
//         value: dataSellWETHCurrency.value,
//         nonce: nonce,
//         deadline: deadline
//       });

//       bytes32 digest = SellNow(_sellNow).calculateDigest(nonce, data);
//       (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPrivateKey, digest);

//       // Build signature struct
//       sig = DataTypes.EIP712Signature({v: v, r: r, s: s, deadline: deadline});
//     }
//     return (data, sig);
//   }

//   /////////////////////////////////////////////////////////////////////////////////
//   // SELL
//   /////////////////////////////////////////////////////////////////////////////////

//   function test_sellnow_sell_no_loan() public {
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 2,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         2,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });
//     vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: 0x0, aggLoanPrice: 0, totalAssets: 0})
//     );
//     hoax(_actor);
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);
//     assertEq(IERC20(makeAsset('WETH')).balanceOf(_actor), 1 ether);
//     assertEq(IERC721(address(_nft)).ownerOf(2), address(_market));
//   }

//   function test_sellnow_sell_repay_loan() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     bytes32 loanId = borrow_asset(1);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0})
//     );
//     hoax(_actor);
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);
//     assertEq(IERC721(address(_nft)).ownerOf(1), address(_market));
//   }

//   function test_sellnow_sell_repay_loan_multiple_assets() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(1) == getWalletAddress(ACTOR));
//     bytes32 loanId = borrow_asset(3);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: loanId, aggLoanPrice: 3 ether, totalAssets: 2})
//     );
//     hoax(_actor);
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);
//     assertEq(IERC721(address(_nft)).ownerOf(1), address(_market));
//   }

//   function test_sellnow_sell_error_unhealty_loan() public {
//     uint88 totalAssets = 2;
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     bytes32 loanId = borrow_asset(totalAssets);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         0.1 ether
//       ),
//       price: 0.1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: loanId, aggLoanPrice: 0.5 ether, totalAssets: 1})
//     );
//     hoax(_actor);
//     vm.expectRevert(abi.encodeWithSelector(Errors.UnhealtyLoan.selector)); // Unhealty loan
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);

//     assertEq(IERC721(address(_nft)).ownerOf(2), getWalletAddress(ACTOR));
//   }

//   function test_sellnow_sell_error_unhealty_loan_with_multiples_assets() public {
//     uint88 totalAssets = 2;
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     bytes32 loanId = borrow_asset(totalAssets);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 2,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         2,
//         makeAsset('WETH'),
//         0.2 ether
//       ),
//       price: 0.2 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: loanId, aggLoanPrice: 1 ether, totalAssets: 1})
//     );
//     hoax(_actor);
//     vm.expectRevert(abi.encodeWithSelector(Errors.UnhealtyLoan.selector)); // Unhealty loan
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);

//     assertEq(IERC721(address(_nft)).ownerOf(2), getWalletAddress(ACTOR));
//   }

//   function test_sellnow_sell_error_price_do_not_cover_debt() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     bytes32 loanId = borrow_asset(1);
//     // Preparing data to execute
//     // Current debt of the user is 1 ether
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         0.5 ether
//       ),
//       price: 0.5 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0})
//     );
//     hoax(_actor);
//     vm.expectRevert(abi.encodeWithSelector(Errors.UnhealtyLoan.selector));
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);
//   }

//   function test_sellnow_sell_error_token_asset_mismatch() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     bytes32 loanId = borrow_asset(2);
//     // Preparing data to execute
//     // Current debt of the user is 1 ether
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: loanId, aggLoanPrice: 2 ether, totalAssets: 3})
//     );
//     hoax(_actor);
//     vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);
//   }

//   function test_sellnow_sell_error_less_price() public {
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 2,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         2,
//         makeAsset('WETH'),
//         0.5 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });
//     vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
//     vm.assume(IERC721(address(_nft)).ownerOf(2) == getWalletAddress(ACTOR));
//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _actor,
//       LoanData({loanId: 0x0, aggLoanPrice: 0, totalAssets: 0})
//     );
//     hoax(_actor);
//     vm.expectRevert('SafeERC20: low-level call failed');
//     SellNow(_sellNow).sell(_reservoirAdapter, asset, data, sig);
//     assertEq(IERC20(makeAsset('WETH')).balanceOf(_actor), 0);
//     assertEq(IERC721(address(_nft)).ownerOf(2), getWalletAddress(ACTOR));
//   }

//   /////////////////////////////////////////////////////////////////////////////////
//   // FORCE SELL
//   /////////////////////////////////////////////////////////////////////////////////

//   function test_sellnow_force_sell_only_one_asset() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(1) == getWalletAddress(ACTOR));
//     vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);

//     bytes32 loanId = borrow_asset(1);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _admin,
//       LoanData({loanId: loanId, aggLoanPrice: 0, totalAssets: 0}) // Set unhealty loan
//     );
//     hoax(_admin);
//     SellNow(_sellNow).forceSell(_reservoirAdapter, asset, data, sig);
//     // Check that the nft is on the market
//     assertEq(IERC721(address(_nft)).ownerOf(1), address(_market));
//   }

//   function test_sellnow_force_sell_two_assets() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(1) == getWalletAddress(ACTOR));
//     vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
//     uint88 totalAssets = 3;
//     bytes32 loanId = borrow_asset(totalAssets);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _admin,
//       LoanData({loanId: loanId, aggLoanPrice: 1.5 ether, totalAssets: totalAssets - 1}) // Set unhealty loan
//     );
//     hoax(_admin);
//     SellNow(_sellNow).forceSell(_reservoirAdapter, asset, data, sig);
//     // Check that the nft is on the market
//     assertEq(IERC721(address(_nft)).ownerOf(1), address(_market));
//   }

//   function test_sellnow_force_sell_error_token_asset_mismatch() public {
//     vm.assume(IERC721(address(_nft)).ownerOf(1) == getWalletAddress(ACTOR));
//     vm.assume(IERC20(makeAsset('WETH')).balanceOf(_actor) == 0);
//     uint88 totalAssets = 3;
//     bytes32 loanId = borrow_asset(totalAssets);
//     // Preparing data to execute
//     dataSellWETHCurrency = ReservoirData({
//       blockNumber: block.number,
//       nftAsset: address(_nft),
//       nftTokenId: 1,
//       currency: makeAsset('WETH'),
//       from: getWalletAddress(ACTOR),
//       to: address(_market),
//       approval: address(_market),
//       approvalTo: address(_market),
//       approvalData: '0x',
//       data: abi.encodeWithSelector(
//         NFTMarket.sell.selector,
//         address(_nft),
//         1,
//         makeAsset('WETH'),
//         1 ether
//       ),
//       price: 1 ether,
//       value: 0
//     });

//     DataTypes.Asset memory asset = DataTypes.Asset({
//       collection: dataSellWETHCurrency.nftAsset,
//       tokenId: dataSellWETHCurrency.nftTokenId
//     });

//     (DataTypes.SignSellNow memory data, DataTypes.EIP712Signature memory sig) = _generate_signature(
//       _admin,
//       LoanData({loanId: loanId, aggLoanPrice: 1.5 ether, totalAssets: 0}) // Set unhealty loan
//     );
//     hoax(_admin);
//     vm.expectRevert(abi.encodeWithSelector(Errors.LoanNotUpdated.selector));
//     SellNow(_sellNow).forceSell(_reservoirAdapter, asset, data, sig);
//   }
// }
