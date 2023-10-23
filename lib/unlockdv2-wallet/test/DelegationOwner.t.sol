// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "forge-std/Test.sol";

// import { DelegationOwner, DelegationGuard, DelegationWalletFactory, TestNft, TestNftPlatform, Config, Errors } from "./utils/Config.sol";
// import { Adapter } from "./mocks/Adapter.sol";

// import { IGnosisSafe } from "../src/interfaces/IGnosisSafe.sol";
// import { AssetLogic } from "../src/libs/logic/AssetLogic.sol";

// import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import { GuardManager, GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
// import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
// import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// import { console } from "forge-std/console.sol";

// contract DelegationOwnerTest is Config {
//     event ExecutionSuccess(bytes32 txHash, uint256 payment);
//     uint256 private safeProxyNftId;
//     uint256 private kakarotoNftId;
//     address[] assets;
//     uint256[] assetIds;
//     TestNft public testNft2;
//     Adapter private adapter;

//     function setUp() public {
//         vm.startPrank(kakaroto);
//         (safeProxy, delegationOwnerProxy, delegationGuardProxy) = delegationWalletFactory.deploy(delegationController);

//         safe = GnosisSafe(payable(safeProxy));
//         delegationOwner = DelegationOwner(delegationOwnerProxy);
//         delegationGuard = DelegationGuard(delegationGuardProxy);

//         safeProxyNftId = testNft.mint(
//             address(safeProxy),
//             "ipfs://bafybeihpjhkeuiq3k6nqa3fkgeigeri7iebtrsuyuey5y6vy36n345xmbi/1"
//         );
//         kakarotoNftId = testNft.mint(kakaroto, "ipfs://bafybeihpjhkeuiq3k6nqa3fkgeigeri7iebtrsuyuey5y6vy36n345xmbi/2");

//         assets.push(address(testNft));
//         assetIds.push(safeProxyNftId);

//         testNft2 = new TestNft();
//         aclManager.addProtocolAdmin(kakaroto);
//         allowedControllers.setDelegationControllerAllowance(karpincho, true);

//         adapter = new Adapter(address(token));
//         token.mint(address(adapter), 1000);
//         vm.stopPrank();
//     }

//     // function test_sell_approval() public {
//     //     vm.assume(testNft.balanceOf(address(safeProxy)) == 1);
//     //     vm.assume(token.balanceOf(address(adapter)) == 1000);
//     //     vm.assume(token.balanceOf(address(safeProxy)) == 0);

//     //     vm.startPrank(kakaroto);

//     //     // WE approve the transfers
//     //     delegationOwner.approveSale(address(testNft), safeProxyNftId, address(token), 1000, address(adapter), 0);
//     //     adapter.sell(address(testNft), safeProxyNftId, address(safeProxy));
//     //     assertEq(testNft.balanceOf(address(safeProxy)), 0);
//     //     assertEq(token.balanceOf(address(safeProxy)), 1000);
//     //     vm.stopPrank();
//     // }

//     function test_setDelegationController_onlyOwner() public {
//         vm.prank(karpincho);
//         vm.expectRevert(Errors.Caller_notGovernanceAdmin.selector);
//         delegationOwner.setDelegationController(karpincho, true);
//     }

//     function test_setDelegationController_should_work() public {
//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, true);
//         assertTrue(delegationOwner.delegationControllers(karpincho));
//     }

//     function test_setDelegationController_should_allow_to_unset_a_controller() public {
//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, true);
//         assertTrue(delegationOwner.delegationControllers(karpincho));

//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, false);
//         assertFalse(delegationOwner.delegationControllers(karpincho));
//     }

//     function test_setDelegationController_notAllowedController() public {
//         vm.prank(kakaroto);
//         vm.expectRevert(Errors.DelegationOwner__setDelegationController_notAllowedController.selector);
//         delegationOwner.setDelegationController(vegeta, true);
//     }

//     function test_setDelegationController_should_allow_to_unset_non_allowed_controller() public {
//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, true);
//         vm.prank(kakaroto);
//         allowedControllers.setDelegationControllerAllowance(karpincho, false);

//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, false);
//     }

//     function test_delegate_only_rental_controller(address _nft, uint256 _id, uint256 _duration) public {
//         vm.assume(_duration != 0);
//         vm.prank(karpincho);

//         vm.expectRevert(Errors.DelegationOwner__onlyDelegationController.selector);

//         delegationOwner.delegate(_nft, _id, karpincho, _duration);
//     }

//     function test_delegate_not_owned_nft(uint256 _duration) public {
//         vm.assume(_duration != 0);
//         vm.prank(delegationController);

//         vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetNotOwned.selector);

//         delegationOwner.delegate(address(testNft), kakarotoNftId, karpincho, _duration);
//     }

//     function test_delegate_approved_nft(uint256 _duration) public {
//         vm.assume(_duration != 0);
//         vm.prank(kakaroto);

//         bytes memory payload = abi.encodeWithSignature("approve(address,uint256)", kakaroto, safeProxyNftId);
//         safe.execTransaction(
//             address(testNft),
//             0,
//             payload,
//             Enum.Operation.Call,
//             0,
//             0,
//             0,
//             address(0),
//             payable(0),
//             getTransactionSignature(kakarotoKey, address(testNft), payload, Enum.Operation.Call)
//         );

//         vm.prank(delegationController);

//         vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetApproved.selector);

//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, _duration);
//     }

//     function test_delegate_currently_delegated(uint256 _duration) public {
//         vm.assume(_duration > 10 days && _duration < 100 * 365 days);
//         vm.prank(delegationController);

//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, _duration);

//         vm.prank(delegationController);
//         vm.warp(block.timestamp + _duration - 1);

//         vm.expectRevert(Errors.DelegationOwner__delegate_currentlyDelegated.selector);

//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, _duration);
//     }

//     function test_delegate_invalid_delegatee(uint256 _duration) public {
//         vm.assume(_duration > 10 days && _duration < 100 * 365 days);
//         vm.prank(delegationController);

//         vm.expectRevert(Errors.DelegationOwner__delegate_invalidDelegatee.selector);

//         delegationOwner.delegate(address(testNft), safeProxyNftId, address(0), _duration);
//     }

//     function test_delegate_invalid_duration() public {
//         vm.prank(delegationController);

//         vm.expectRevert(Errors.DelegationOwner__delegate_invalidDuration.selector);

//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, 0);
//     }

//     function test_delegate_should_work(uint256 _duration) public {
//         vm.assume(_duration > 10 days && _duration < 100 * 365 days);
//         vm.prank(delegationController);

//         vm.expectCall(
//             address(delegationGuard),
//             abi.encodeWithSelector(
//                 DelegationGuard.setDelegationExpiry.selector,
//                 address(testNft),
//                 safeProxyNftId,
//                 block.timestamp + _duration
//             )
//         );
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, _duration);

//         (address controller, address delegatee, uint256 from, uint256 to) = delegationOwner.delegations(
//             AssetLogic.assetId(address(testNft), safeProxyNftId)
//         );

//         assertEq(controller, delegationController);
//         assertEq(delegatee, karpincho);
//         assertEq(from, block.timestamp);
//         assertEq(to, block.timestamp + _duration);
//     }

//     // end delegate
//     function test_endDelegate_notDelegated() public {
//         vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_notDelegated.selector);
//         delegationOwner.endDelegate(address(testNft), safeProxyNftId);
//     }

//     function test_endDelegate_onlyDelegationCreator() public {
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, 10 days);

//         vm.prank(kakaroto);
//         vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//         delegationOwner.endDelegate(address(testNft), safeProxyNftId);
//     }

//     function test_endDelegate_should_not_allow_new_delegationController_to_end_delegation_not_created() public {
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, 10 days);

//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, true);

//         vm.prank(karpincho);
//         vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//         delegationOwner.endDelegate(address(testNft), safeProxyNftId);
//     }

//     function test_endDelegate_should_work() public {
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, 10 days);

//         vm.prank(delegationController);
//         vm.expectCall(
//             address(delegationGuard),
//             abi.encodeWithSelector(DelegationGuard.setDelegationExpiry.selector, address(testNft), safeProxyNftId, 0)
//         );
//         delegationOwner.endDelegate(address(testNft), safeProxyNftId);

//         assertFalse(delegationOwner.isAssetDelegated(address(testNft), safeProxyNftId));
//     }

//     function test_endDelegate_should_allow_old_delegationController_to_end_delegation_created() public {
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, 10 days);

//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(delegationController, false);

//         vm.prank(delegationController);
//         delegationOwner.endDelegate(address(testNft), safeProxyNftId);

//         assertFalse(delegationOwner.isAssetDelegated(address(testNft), safeProxyNftId));
//     }

//     // delegate signature
//     function test_delegateSignature_onlyRentController() public {
//         vm.prank(karpincho);
//         vm.expectRevert(Errors.DelegationOwner__onlyDelegationController.selector);

//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);
//     }

//     function test_delegateSignature_invalidArity() public {
//         assets.push(address(testNft2));

//         vm.prank(delegationController);
//         vm.expectRevert(Errors.DelegationOwner__delegateSignature_invalidArity.selector);
//         delegationOwner.delegateSignature(assets, assetIds, vegeta, 10 days);
//     }

//     function test_delegateSignature_currentlyDelegated() public {
//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//         vm.prank(delegationController);
//         vm.expectRevert(Errors.DelegationOwner__delegateSignature_currentlyDelegated.selector);
//         delegationOwner.delegateSignature(assets, assetIds, vegeta, 10 days);
//     }

//     function test_delegateSignature_invalidDelegatee() public {
//         vm.prank(delegationController);
//         vm.expectRevert(Errors.DelegationOwner__delegateSignature_invalidDelegatee.selector);

//         delegationOwner.delegateSignature(assets, assetIds, address(0), 10 days);
//     }

//     function test_delegateSignature_invalidDuration() public {
//         vm.prank(delegationController);
//         vm.expectRevert(Errors.DelegationOwner__delegateSignature_invalidDuration.selector);

//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 0);
//     }

//     function test_delegateSignature_assetNotOwned() public {
//         uint256 duration = 10 days;
//         uint256[] memory notOwnedAssetIds = new uint256[](1);
//         notOwnedAssetIds[0] = kakarotoNftId;

//         vm.prank(delegationController);
//         vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetNotOwned.selector);

//         delegationOwner.delegateSignature(assets, notOwnedAssetIds, karpincho, duration);
//     }

//     function test_delegateSignature_assetApproved() public {
//         bytes memory payload = abi.encodeWithSignature("approve(address,uint256)", kakaroto, safeProxyNftId);
//         safe.execTransaction(
//             address(testNft),
//             0,
//             payload,
//             Enum.Operation.Call,
//             0,
//             0,
//             0,
//             address(0),
//             payable(0),
//             getTransactionSignature(kakarotoKey, address(testNft), payload, Enum.Operation.Call)
//         );

//         vm.prank(delegationController);
//         vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetApproved.selector);

//         uint256 duration = 10 days;
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);
//     }

//     function test_delegateSignature_should_work_() public {
//         uint256 duration = 10 days;
//         vm.prank(delegationController);
//         vm.expectCall(
//             address(delegationGuard),
//             abi.encodeWithSelector(
//                 DelegationGuard.setDelegationExpiries.selector,
//                 assets,
//                 assetIds,
//                 block.timestamp + duration
//             )
//         );
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);

//         (address controller, address delegatee, uint256 from, uint256 to) = delegationOwner.signatureDelegation();

//         assertEq(controller, delegationController);
//         assertEq(delegatee, karpincho);
//         assertEq(from, block.timestamp);
//         assertEq(to, block.timestamp + duration);
//     }

//     // end delegate signature
//     function test_endDelegateSignature_notDelegated() public {
//         vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_notDelegated.selector);
//         delegationOwner.endDelegateSignature();
//     }

//     function test_endDelegateSignature_onlyDelegationCreator() public {
//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//         vm.prank(kakaroto);
//         vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//         delegationOwner.endDelegateSignature();
//     }

//     function test_endDelegateSignature_should_not_allow_new_delegationController_to_end_delegation_not_created()
//         public
//     {
//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(karpincho, true);

//         vm.prank(karpincho);
//         vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//         delegationOwner.endDelegateSignature();
//     }

//     function test_endDelegateSignature_should_work() public {
//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//         vm.prank(delegationController);
//         vm.expectCall(
//             address(delegationGuard),
//             abi.encodeWithSelector(DelegationGuard.setDelegationExpiries.selector, assets, assetIds, 0)
//         );
//         delegationOwner.endDelegateSignature();

//         assertFalse(delegationOwner.isAssetDelegated(address(testNft), safeProxyNftId));
//     }

//     function test_endDelegateSignature_should_allow_old_delegationController_to_end_delegation_created() public {
//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//         vm.prank(kakaroto);
//         delegationOwner.setDelegationController(delegationController, false);

//         vm.prank(delegationController);
//         delegationOwner.endDelegateSignature();

//         assertFalse(delegationOwner.isAssetDelegated(address(testNft), safeProxyNftId));
//     }

//     // isValidSignature
//     function test_isValidSignature_with_off_chain_signature_should_work() public {
//         uint256 duration = 30 days;
//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);

//         vm.warp(block.timestamp + 10);

//         bytes32 singData = bytes32("hello world");
//         bytes memory userSignature = getSignature(singData, karpinchoKey);

//         // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
//         bytes memory signature = abi.encodePacked(
//             abi.encode(address(delegationOwner)), // r
//             abi.encode(uint256(65)), // s
//             bytes1(0), // v
//             abi.encode(userSignature.length),
//             userSignature
//         );

//         assertEq(
//             IGnosisSafe(address(safe)).isValidSignature(ECDSA.toEthSignedMessageHash(singData), signature),
//             UPDATED_MAGIC_VALUE
//         );
//     }

//     function test_isValidSignature_notDelegated() public {
//         bytes memory singData = abi.encodePacked(bytes32("hello world"));
//         bytes memory userSignature = getSignature(singData, vegetaKey);

//         // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
//         bytes memory signature = abi.encodePacked(
//             abi.encode(address(delegationOwner)), // r
//             abi.encode(uint256(65)), // s
//             bytes1(0), // v
//             abi.encode(userSignature.length),
//             userSignature
//         );

//         vm.expectRevert(Errors.DelegationOwner__isValidSignature_notDelegated.selector);
//         IGnosisSafe(address(safe)).isValidSignature(singData, signature);
//     }

//     function test_isValidSignature_invalidSigner() public {
//         uint256 duration = 30 days;

//         vm.prank(delegationController);
//         delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);

//         vm.warp(block.timestamp + 10);

//         bytes memory singData = abi.encodePacked(bytes32("hello world"));
//         bytes memory userSignature = getSignature(singData, vegetaKey);

//         // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
//         bytes memory signature = abi.encodePacked(
//             abi.encode(address(delegationOwner)), // r
//             abi.encode(uint256(65)), // s
//             bytes1(0), // v
//             abi.encode(userSignature.length),
//             userSignature
//         );

//         vm.expectRevert(Errors.DelegationOwner__isValidSignature_invalidSigner.selector);
//         IGnosisSafe(address(safe)).isValidSignature(singData, signature);
//     }

//     // execTransaction
//     function test_execTransaction_notDelegated() public {
//         vm.prank(karpincho);

//         vm.expectRevert(Errors.DelegationOwner__execTransaction_notDelegated.selector);

//         delegationOwner.execTransaction(
//             address(testNft),
//             safeProxyNftId,
//             address(testNftPlatform),
//             0,
//             abi.encodeWithSelector(TestNftPlatform.allowedFunction.selector),
//             0,
//             0,
//             0,
//             address(0),
//             payable(0)
//         );
//     }

//     function test_execTransaction_invalidDelegatee() public {
//         uint256 duration = 30 days;
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, duration);

//         vm.warp(block.timestamp + 10);

//         vm.prank(vegeta);
//         vm.expectRevert(Errors.DelegationOwner__execTransaction_invalidDelegatee.selector);

//         delegationOwner.execTransaction(
//             address(testNft),
//             safeProxyNftId,
//             address(testNftPlatform),
//             0,
//             abi.encodeWithSelector(TestNftPlatform.allowedFunction.selector),
//             0,
//             0,
//             0,
//             address(0),
//             payable(0)
//         );
//     }

//     function test_execTransaction_notAllowedFunction() public {
//         uint256 duration = 30 days;
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, duration);

//         vm.warp(block.timestamp + 10);

//         vm.prank(karpincho);
//         vm.expectRevert(Errors.DelegationOwner__execTransaction_notAllowedFunction.selector);

//         delegationOwner.execTransaction(
//             address(testNft),
//             safeProxyNftId,
//             address(testNftPlatform),
//             0,
//             abi.encodeWithSelector(TestNftPlatform.notAllowedFunction.selector),
//             0,
//             0,
//             0,
//             address(0),
//             payable(0)
//         );
//     }

//     function test_execTransaction_should_work() public {
//         uint256 duration = 30 days;
//         vm.prank(delegationController);
//         delegationOwner.delegate(address(testNft), safeProxyNftId, karpincho, duration);

//         vm.warp(block.timestamp + 10);

//         uint256 countBefore = testNftPlatform.count();

//         vm.prank(karpincho);

//         bool success = delegationOwner.execTransaction(
//             address(testNft),
//             safeProxyNftId,
//             address(testNftPlatform),
//             0,
//             abi.encodeWithSelector(TestNftPlatform.allowedFunction.selector),
//             0,
//             0,
//             0,
//             address(0),
//             payable(0)
//         );

//         assertEq(success, true);
//         assertEq(testNftPlatform.count(), countBefore + 1);
//     }

//     // function test_lockAsset_not_owned_nft(uint256 _duration) public {
//     //     vm.assume(_duration > 0 && _duration < 100 * 365 days);
//     //     bytes32 id = delegationOwner.assetId(address(testNft), safeProxyNftId);
//     //     vm.startPrank(address(0x2));

//     //     vm.expectRevert(Errors.Caller_notProtocol.selector);

//     //     delegationOwner.setLoanId(id, 0);
//     // }

//     // function test_claimAsset_claimAsset_notLocked(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.startPrank(kakaroto);

//     //     bytes32 id = delegationOwner.assetId(address(testNft), safeProxyNftId);

//     //     delegationOwner.setLoanId(id, 0); // Unlock

//     //     delegationOwner.claimAsset(address(testNft), safeProxyNftId, karpincho);

//     //     vm.stopPrank();
//     // }

//     // function test_claimAsset_assetNotClaimable_locked(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.startPrank(kakaroto);

//     //     bytes32 id = delegationOwner.assetId(address(testNft), safeProxyNftId);

//     //     delegationOwner.setLoanId(id, keccak256(abi.encode(100))); // Lock

//     //     vm.expectRevert(Errors.DelegationOwner__claimAsset_assetLocked.selector);
//     //     delegationOwner.claimAsset(address(testNft), safeProxyNftId, karpincho);
//     //     vm.stopPrank();
//     // }
// }
