// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "forge-std/Test.sol";

// import { DelegationOwner, DelegationGuard, DelegationWalletFactory, TestNftPlatform, Config, ICryptoPunks, Errors } from "./utils/Config.sol";

// import { IGnosisSafe } from "../src/interfaces/IGnosisSafe.sol";

// import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
// import { OwnerManager, GuardManager, GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

// contract DelegationGuardPunksTest is Config {
//     address[] assets;
//     address[] assets2;
//     uint256[] assetIds;
//     uint256[] assetIds2;
//     uint256 expiry;

//     function setUp() public {
//         vm.prank(kakaroto);
//         (safeProxy, delegationOwnerProxy, delegationGuardProxy) = delegationWalletFactory.deploy(
//             delegationController,
//             nftfi
//         );

//         safe = GnosisSafe(payable(safeProxy));
//         delegationOwner = DelegationOwner(delegationOwnerProxy);
//         delegationGuard = DelegationGuard(delegationGuardProxy);

//         vm.prank(REAL_OWNER);
//         testPunks.transferPunk(address(safeProxy), safeProxyPunkId);
//         assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));

//         vm.prank(REAL_OWNER2);
//         testPunks.transferPunk(address(safeProxy), safeProxyPunkId2);
//         assertEq(testPunks.punkIndexToAddress(safeProxyPunkId2), address(safeProxy));

//         assets.push(address(testPunks));
//         assets.push(address(testPunks));
//         assetIds.push(safeProxyPunkId);
//         assetIds.push(safeProxyPunkId2);

//         expiry = block.timestamp + 10 days;
//     }

//     //setDelegationExpiries
//     // function test_setDelegationExpiries_onlyDelegationOwner() public {
//     //     vm.expectRevert(Errors.DelegationGuard__onlyDelegationOwner.selector);
//     //     delegationGuard.setDelegationExpiries(assets, assetIds, expiry);
//     // }

//     // function test_setDelegationExpiries_should_work() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiries(assets, assetIds, expiry);

//     //     assertEq(delegationGuard.getExpiry(address(testPunks), safeProxyPunkId), expiry);
//     //     assertEq(delegationGuard.getExpiry(address(testPunks), safeProxyPunkId2), expiry);
//     // }

//     // //setDelegationExpiry
//     // function test_setDelegationExpiry_onlyDelegationOwner() public {
//     //     vm.expectRevert(Errors.DelegationGuard__onlyDelegationOwner.selector);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);
//     // }

//     // function test_setDelegationExpiry_should_work() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     assertEq(delegationGuard.getExpiry(address(testPunks), safeProxyPunkId), expiry);
//     // }

//     // //lockAsset
//     // function test_lockAsset_onlyDelegationOwner() public {
//     //     vm.expectRevert(Errors.DelegationGuard__onlyDelegationOwner.selector);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_lockAsset_should_work() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // //unlockAsset
//     // function test_unlockAsset_onlyDelegationOwner() public {
//     //     vm.expectRevert(Errors.DelegationGuard__onlyDelegationOwner.selector);
//     //     delegationGuard.unlockAsset(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_unlockAsset_should_work() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));

//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.unlockAsset(address(testPunks), safeProxyPunkId);

//     //     assertFalse(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // // _checkLocked
//     // function test_owner_can_no_transfer_out_delegated_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.warp(block.timestamp + 1);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.transferPunk.selector, kakaroto, safeProxyPunkId);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noTransfer.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));
//     // }

//     // function test_owner_can_no_accept_bid_for_delegated_punk() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.startPrank(kakaroto);

//     //     // Create a valid bid for CryptoPunk NFT
//     //     testPunks.enterBidForPunk{ value: 1 ether }(safeProxyPunkId);

//     //     // Accept bid from delegated wallet
//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.acceptBidForPunk.selector, safeProxyPunkId, 1 ether);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noTransfer.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));

//     //     vm.stopPrank();
//     // }

//     // function test_owner_can_transfer_out_delegated_asset_after_expiry() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.warp(block.timestamp + 10 days + 1);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.transferPunk.selector, kakaroto, safeProxyPunkId);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), kakaroto);
//     // }

//     // function test_owner_can_not_offerPunkForSale_delegated_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.warp(block.timestamp + 1);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.offerPunkForSale.selector, safeProxyPunkId, 1 ether);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noApproval.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertFalse(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_offerPunkForSale_delegated_asset_after_expiry() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.warp(block.timestamp + 10 days + 1);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.offerPunkForSale.selector, safeProxyPunkId, 1 ether);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertTrue(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_not_offerPunkForSaleToAddress_delegated_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.warp(block.timestamp + 1);

//     //     bytes memory payload = abi.encodeWithSelector(
//     //         ICryptoPunks.offerPunkForSaleToAddress.selector,
//     //         safeProxyPunkId,
//     //         1 ether,
//     //         kakaroto
//     //     );

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noApproval.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertFalse(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_offerPunkForSaleToAddress_delegated_asset_after_expiry() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.setDelegationExpiry(address(testPunks), safeProxyPunkId, expiry);

//     //     vm.warp(block.timestamp + 10 days + 1);

//     //     bytes memory payload = abi.encodeWithSelector(
//     //         ICryptoPunks.offerPunkForSaleToAddress.selector,
//     //         safeProxyPunkId,
//     //         1 ether,
//     //         kakaroto
//     //     );

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertTrue(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_not_transfer_out_locked_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.transferPunk.selector, kakaroto, safeProxyPunkId);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noTransfer.selector);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));
//     // }

//     // function test_owner_can_not_accept_bid_for_locked_punk() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     vm.startPrank(kakaroto);

//     //     // Create a valid bid for CryptoPunk NFT
//     //     testPunks.enterBidForPunk{ value: 1 ether }(safeProxyPunkId);

//     //     // Accept bid from delegated wallet
//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.acceptBidForPunk.selector, safeProxyPunkId, 1 ether);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noTransfer.selector);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     vm.stopPrank();

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));
//     // }

//     // function test_owner_can_transfer_out_unlocked_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.transferPunk.selector, kakaroto, safeProxyPunkId);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noTransfer.selector);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));

//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.unlockAsset(address(testPunks), safeProxyPunkId);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), kakaroto);
//     // }

//     // function test_owner_can_not_offerPunkForSale_locked_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.offerPunkForSale.selector, safeProxyPunkId, 1 ether);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noApproval.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertFalse(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_offerPunkForSale_unlocked_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     bytes memory payload = abi.encodeWithSelector(ICryptoPunks.offerPunkForSale.selector, safeProxyPunkId, 1 ether);

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noApproval.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );
//     //     assertFalse(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);

//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.unlockAsset(address(testPunks), safeProxyPunkId);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );
//     //     assertTrue(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_not_offerPunkForSaleToAddress_locked_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     bytes memory payload = abi.encodeWithSelector(
//     //         ICryptoPunks.offerPunkForSaleToAddress.selector,
//     //         safeProxyPunkId,
//     //         1 ether,
//     //         kakaroto
//     //     );

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noApproval.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );

//     //     assertFalse(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }

//     // function test_owner_can_offerPunkForSaleToAddress_unlocked_asset() public {
//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.lockAsset(address(testPunks), safeProxyPunkId);

//     //     bytes memory payload = abi.encodeWithSelector(
//     //         ICryptoPunks.offerPunkForSaleToAddress.selector,
//     //         safeProxyPunkId,
//     //         1 ether,
//     //         kakaroto
//     //     );

//     //     bytes memory tSig = getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationGuard__checkLocked_noApproval.selector);
//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );
//     //     assertFalse(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);

//     //     vm.prank(delegationOwnerProxy);
//     //     delegationGuard.unlockAsset(address(testPunks), safeProxyPunkId);

//     //     safe.execTransaction(
//     //         address(testPunks),
//     //         0,
//     //         payload,
//     //         Enum.Operation.Call,
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0),
//     //         tSig
//     //     );
//     //     assertTrue(testPunks.punksOfferedForSale(safeProxyPunkId).isForSale);
//     // }
// }
