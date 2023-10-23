// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

// import "forge-std/Test.sol";

// import { DelegationOwner, DelegationGuard, DelegationWalletFactory, TestNftPlatform, Config, Errors } from "./utils/Config.sol";

// import { IGnosisSafe } from "../src/interfaces/IGnosisSafe.sol";
// import { AssetLogic } from "../src/libs/logic/AssetLogic.sol";

// import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import { GuardManager, GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
// import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
// import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// contract DelegationOwnerPunksTest is Config {
//     event ExecutionSuccess(bytes32 txHash, uint256 payment);
//     uint256 private constant kakarotoPunkId = 410;
//     address[] assets;
//     uint256[] assetIds;

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

//         vm.prank(0x717a578E4A157Ea52EE989be75f15957F294d1A9);
//         testPunks.transferPunk(kakaroto, kakarotoPunkId);
//         assertEq(testPunks.punkIndexToAddress(kakarotoPunkId), kakaroto);

//         assets.push(address(testPunks));
//         assetIds.push(safeProxyPunkId);

//         allowedControllers.setLockControllerAllowance(karpincho, true);
//         allowedControllers.setDelegationControllerAllowance(karpincho, true);
//     }

//     // function test_delegate_not_owned_nft(uint256 _duration) public {
//     //     vm.assume(_duration != 0);
//     //     vm.prank(delegationController);

//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetNotOwned.selector);

//     //     delegationOwner.delegate(address(testPunks), kakarotoPunkId, karpincho, _duration);
//     // }

//     // function test_delegate_punksOfferedForSale(uint256 _duration) public {
//     //     vm.assume(_duration != 0);
//     //     vm.prank(kakaroto);

//     //     bytes memory payload = abi.encodeWithSignature("offerPunkForSale(uint256,uint256)", safeProxyPunkId, 1 ether);
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
//     //         getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call)
//     //     );

//     //     vm.prank(delegationController);

//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetApproved.selector);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);
//     // }

//     // function test_delegate_punksOfferedForSale_toAddress(uint256 _duration) public {
//     //     vm.assume(_duration != 0);
//     //     vm.prank(kakaroto);

//     //     bytes memory payload = abi.encodeWithSignature(
//     //         "offerPunkForSaleToAddress(uint256,uint256,address)",
//     //         safeProxyPunkId,
//     //         1 ether,
//     //         kakaroto
//     //     );
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
//     //         getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call)
//     //     );

//     //     vm.prank(delegationController);

//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetApproved.selector);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);
//     // }

//     // function test_delegate_currently_delegated(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);
//     //     vm.prank(delegationController);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);

//     //     vm.prank(delegationController);
//     //     vm.warp(block.timestamp + _duration - 1);

//     //     vm.expectRevert(Errors.DelegationOwner__delegate_currentlyDelegated.selector);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);
//     // }

//     // function test_delegate_invalid_delegatee(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);
//     //     vm.prank(delegationController);

//     //     vm.expectRevert(Errors.DelegationOwner__delegate_invalidDelegatee.selector);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, address(0), _duration);
//     // }

//     // function test_delegate_invalid_duration() public {
//     //     vm.prank(delegationController);

//     //     vm.expectRevert(Errors.DelegationOwner__delegate_invalidDuration.selector);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 0);
//     // }

//     // function test_delegate_invalidExpiry(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));

//     //     vm.prank(delegationController);

//     //     vm.expectRevert(Errors.DelegationOwner__delegate_invalidExpiry.selector);

//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration + 1);
//     // }

//     // function test_delegate_should_work(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);
//     //     vm.prank(delegationController);

//     //     vm.expectCall(
//     //         address(delegationGuard),
//     //         abi.encodeWithSelector(
//     //             DelegationGuard.setDelegationExpiry.selector,
//     //             address(testPunks),
//     //             safeProxyPunkId,
//     //             block.timestamp + _duration
//     //         )
//     //     );
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);

//     //     (address controller, address delegatee, uint256 from, uint256 to) = delegationOwner.delegations(
//     //         AssetLogic.assetId(address(testPunks), safeProxyPunkId)
//     //     );

//     //     assertEq(controller, delegationController);
//     //     assertEq(delegatee, karpincho);
//     //     assertEq(from, block.timestamp);
//     //     assertEq(to, block.timestamp + _duration);
//     // }

//     // function test_delegate_should_work_with_locked_asset_and_ending_before_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     vm.prank(delegationController);

//     //     vm.expectCall(
//     //         address(delegationGuard),
//     //         abi.encodeWithSelector(
//     //             DelegationGuard.setDelegationExpiry.selector,
//     //             address(testPunks),
//     //             safeProxyPunkId,
//     //             block.timestamp + _duration - 1
//     //         )
//     //     );
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration - 1);

//     //     (address controller, address delegatee, uint256 from, uint256 to) = delegationOwner.delegations(
//     //         AssetLogic.assetId(address(testPunks), safeProxyPunkId)
//     //     );

//     //     assertEq(controller, delegationController);
//     //     assertEq(delegatee, karpincho);
//     //     assertEq(from, block.timestamp);
//     //     assertEq(to, block.timestamp + _duration - 1);
//     // }

//     // function test_delegate_should_work_with_locked_asset_and_ending_at_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     vm.prank(delegationController);

//     //     vm.expectCall(
//     //         address(delegationGuard),
//     //         abi.encodeWithSelector(
//     //             DelegationGuard.setDelegationExpiry.selector,
//     //             address(testPunks),
//     //             safeProxyPunkId,
//     //             block.timestamp + _duration
//     //         )
//     //     );
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);

//     //     (address controller, address delegatee, uint256 from, uint256 to) = delegationOwner.delegations(
//     //         AssetLogic.assetId(address(testPunks), safeProxyPunkId)
//     //     );

//     //     assertEq(controller, delegationController);
//     //     assertEq(delegatee, karpincho);
//     //     assertEq(from, block.timestamp);
//     //     assertEq(to, block.timestamp + _duration);
//     // }

//     // // end delegate
//     // function test_endDelegate_notDelegated() public {
//     //     vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_notDelegated.selector);
//     //     delegationOwner.endDelegate(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_endDelegate_onlyDelegationCreator() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 10 days);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//     //     delegationOwner.endDelegate(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_endDelegate_should_not_allow_new_delegationController_to_end_delegation_not_created() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 10 days);

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setDelegationController(karpincho, true);

//     //     vm.prank(karpincho);
//     //     vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//     //     delegationOwner.endDelegate(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_endDelegate_should_work() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 10 days);

//     //     vm.prank(delegationController);
//     //     vm.expectCall(
//     //         address(delegationGuard),
//     //         abi.encodeWithSelector(DelegationGuard.setDelegationExpiry.selector, address(testPunks), safeProxyPunkId, 0)
//     //     );
//     //     delegationOwner.endDelegate(address(testPunks), safeProxyPunkId);

//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_endDelegate_should_allow_old_delegationController_to_end_delegation_created() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 10 days);

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setDelegationController(delegationController, true);

//     //     vm.prank(delegationController);
//     //     delegationOwner.endDelegate(address(testPunks), safeProxyPunkId);

//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // // delegate signature
//     // function test_delegateSignature_onlyRentController() public {
//     //     vm.prank(karpincho);
//     //     vm.expectRevert(Errors.DelegationOwner__onlyDelegationController.selector);

//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);
//     // }

//     // function test_delegateSignature_invalidArity() public {
//     //     assets.push(address(testPunks));

//     //     vm.prank(delegationController);
//     //     vm.expectRevert(Errors.DelegationOwner__delegateSignature_invalidArity.selector);
//     //     delegationOwner.delegateSignature(assets, assetIds, vegeta, 10 days);
//     // }

//     // function test_delegateSignature_currentlyDelegated() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.prank(delegationController);
//     //     vm.expectRevert(Errors.DelegationOwner__delegateSignature_currentlyDelegated.selector);
//     //     delegationOwner.delegateSignature(assets, assetIds, vegeta, 10 days);
//     // }

//     // function test_delegateSignature_invalidDelegatee() public {
//     //     vm.prank(delegationController);
//     //     vm.expectRevert(Errors.DelegationOwner__delegateSignature_invalidDelegatee.selector);

//     //     delegationOwner.delegateSignature(assets, assetIds, address(0), 10 days);
//     // }

//     // function test_delegateSignature_invalidDuration() public {
//     //     vm.prank(delegationController);
//     //     vm.expectRevert(Errors.DelegationOwner__delegateSignature_invalidDuration.selector);

//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 0);
//     // }

//     // function test_delegateSignature_assetNotOwned() public {
//     //     uint256 duration = 10 days;
//     //     uint256[] memory notOwnedAssetIds = new uint256[](1);
//     //     notOwnedAssetIds[0] = kakarotoPunkId;

//     //     vm.prank(delegationController);
//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetNotOwned.selector);

//     //     delegationOwner.delegateSignature(assets, notOwnedAssetIds, karpincho, duration);
//     // }

//     // function test_delegateSignature_punksOfferedForSale() public {
//     //     bytes memory payload = abi.encodeWithSignature("offerPunkForSale(uint256,uint256)", safeProxyPunkId, 1 ether);
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
//     //         getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call)
//     //     );

//     //     vm.prank(delegationController);
//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetApproved.selector);

//     //     uint256 duration = 10 days;
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);
//     // }

//     // function test_delegateSignature_should_work_() public {
//     //     uint256 duration = 10 days;
//     //     vm.prank(delegationController);
//     //     vm.expectCall(
//     //         address(delegationGuard),
//     //         abi.encodeWithSelector(
//     //             DelegationGuard.setDelegationExpiries.selector,
//     //             assets,
//     //             assetIds,
//     //             block.timestamp + duration
//     //         )
//     //     );
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);

//     //     (address controller, address delegatee, uint256 from, uint256 to) = delegationOwner.signatureDelegation();

//     //     assertEq(controller, delegationController);
//     //     assertEq(delegatee, karpincho);
//     //     assertEq(from, block.timestamp);
//     //     assertEq(to, block.timestamp + duration);
//     // }

//     // // end delegate signature
//     // function test_endDelegateSignature_notDelegated() public {
//     //     vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_notDelegated.selector);
//     //     delegationOwner.endDelegateSignature();
//     // }

//     // function test_endDelegateSignature_onlyDelegationCreator() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//     //     delegationOwner.endDelegateSignature();
//     // }

//     // function test_endDelegateSignature_should_not_allow_new_delegationController_to_end_delegation_not_created()
//     //     public
//     // {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setDelegationController(karpincho, true);

//     //     vm.prank(karpincho);
//     //     vm.expectRevert(Errors.DelegationOwner__delegationCreatorChecks_onlyDelegationCreator.selector);
//     //     delegationOwner.endDelegateSignature();
//     // }

//     // function test_endDelegateSignature_should_work() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.prank(delegationController);
//     //     vm.expectCall(
//     //         address(delegationGuard),
//     //         abi.encodeWithSelector(DelegationGuard.setDelegationExpiries.selector, assets, assetIds, 0)
//     //     );
//     //     delegationOwner.endDelegateSignature();

//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_endDelegateSignature_should_allow_old_delegationController_to_end_delegation_created() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setDelegationController(delegationController, true);

//     //     vm.prank(delegationController);
//     //     delegationOwner.endDelegateSignature();

//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // // isValidSignature
//     // function test_isValidSignature_with_off_chain_signature_should_work() public {
//     //     uint256 duration = 30 days;
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);

//     //     vm.warp(block.timestamp + 10);

//     //     bytes32 singData = bytes32("hello world");
//     //     bytes memory userSignature = getSignature(singData, karpinchoKey);

//     //     // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
//     //     bytes memory signature = abi.encodePacked(
//     //         abi.encode(address(delegationOwner)), // r
//     //         abi.encode(uint256(65)), // s
//     //         bytes1(0), // v
//     //         abi.encode(userSignature.length),
//     //         userSignature
//     //     );

//     //     assertEq(
//     //         IGnosisSafe(address(safe)).isValidSignature(ECDSA.toEthSignedMessageHash(singData), signature),
//     //         UPDATED_MAGIC_VALUE
//     //     );
//     // }

//     // function test_isValidSignature_notDelegated() public {
//     //     bytes memory singData = abi.encodePacked(bytes32("hello world"));
//     //     bytes memory userSignature = getSignature(singData, vegetaKey);

//     //     // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
//     //     bytes memory signature = abi.encodePacked(
//     //         abi.encode(address(delegationOwner)), // r
//     //         abi.encode(uint256(65)), // s
//     //         bytes1(0), // v
//     //         abi.encode(userSignature.length),
//     //         userSignature
//     //     );

//     //     vm.expectRevert(Errors.DelegationOwner__isValidSignature_notDelegated.selector);
//     //     IGnosisSafe(address(safe)).isValidSignature(singData, signature);
//     // }

//     // function test_isValidSignature_invalidSigner() public {
//     //     uint256 duration = 30 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, duration);

//     //     vm.warp(block.timestamp + 10);

//     //     bytes memory singData = abi.encodePacked(bytes32("hello world"));
//     //     bytes memory userSignature = getSignature(singData, vegetaKey);

//     //     // https://docs.gnosis-safe.io/contracts/signatures#contract-signature-eip-1271
//     //     bytes memory signature = abi.encodePacked(
//     //         abi.encode(address(delegationOwner)), // r
//     //         abi.encode(uint256(65)), // s
//     //         bytes1(0), // v
//     //         abi.encode(userSignature.length),
//     //         userSignature
//     //     );

//     //     vm.expectRevert(Errors.DelegationOwner__isValidSignature_invalidSigner.selector);
//     //     IGnosisSafe(address(safe)).isValidSignature(singData, signature);
//     // }

//     // // execTransaction
//     // function test_execTransaction_notDelegated() public {
//     //     vm.prank(karpincho);

//     //     vm.expectRevert(Errors.DelegationOwner__execTransaction_notDelegated.selector);

//     //     delegationOwner.execTransaction(
//     //         address(testPunks),
//     //         safeProxyPunkId,
//     //         address(testPunksPlatform),
//     //         0,
//     //         abi.encodeWithSelector(TestNftPlatform.allowedFunction.selector),
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0)
//     //     );
//     // }

//     // function test_execTransaction_invalidDelegatee() public {
//     //     uint256 duration = 30 days;
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, duration);

//     //     vm.warp(block.timestamp + 10);

//     //     vm.prank(vegeta);
//     //     vm.expectRevert(Errors.DelegationOwner__execTransaction_invalidDelegatee.selector);

//     //     delegationOwner.execTransaction(
//     //         address(testPunks),
//     //         safeProxyPunkId,
//     //         address(testPunksPlatform),
//     //         0,
//     //         abi.encodeWithSelector(TestNftPlatform.allowedFunction.selector),
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0)
//     //     );
//     // }

//     // function test_execTransaction_notAllowedFunction() public {
//     //     uint256 duration = 30 days;
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, duration);

//     //     vm.warp(block.timestamp + 10);

//     //     vm.prank(karpincho);
//     //     vm.expectRevert(Errors.DelegationOwner__execTransaction_notAllowedFunction.selector);

//     //     delegationOwner.execTransaction(
//     //         address(testPunks),
//     //         safeProxyPunkId,
//     //         address(testPunksPlatform),
//     //         0,
//     //         abi.encodeWithSelector(TestNftPlatform.notAllowedFunction.selector),
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0)
//     //     );
//     // }

//     // function test_execTransaction_should_work() public {
//     //     uint256 duration = 30 days;
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, duration);

//     //     vm.warp(block.timestamp + 10);

//     //     uint256 countBefore = testPunksPlatform.count();

//     //     vm.prank(karpincho);

//     //     bool success = delegationOwner.execTransaction(
//     //         address(testPunks),
//     //         safeProxyPunkId,
//     //         address(testPunksPlatform),
//     //         0,
//     //         abi.encodeWithSelector(TestNftPlatform.allowedFunction.selector),
//     //         0,
//     //         0,
//     //         0,
//     //         address(0),
//     //         payable(0)
//     //     );

//     //     assertEq(success, true);
//     //     assertEq(testPunksPlatform.count(), countBefore + 1);
//     // }

//     // // loan

//     // function test_lockAsset_onlyLoanController() public {
//     //     vm.prank(karpincho);

//     //     vm.expectRevert(Errors.DelegationOwner__onlyLockController.selector);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + 10 days);
//     // }

//     // function test_lockAsset_not_owned_nft(uint256 _duration) public {
//     //     vm.assume(_duration > 0 && _duration < 100 * 365 days);
//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetNotOwned.selector);

//     //     delegationOwner.lockAsset(address(testPunks), kakarotoPunkId, block.timestamp + _duration);
//     // }

//     // function test_lockAsset_punksOfferedForSale(uint256 _duration) public {
//     //     vm.assume(_duration > 0 && _duration < 100 * 365 days);
//     //     vm.prank(kakaroto);

//     //     bytes memory payload = abi.encodeWithSignature("offerPunkForSale(uint256,uint256)", safeProxyPunkId, 1 ether);
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
//     //         getTransactionSignature(kakarotoKey, address(testPunks), payload, Enum.Operation.Call)
//     //     );

//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__checkOwnedAndNotApproved_assetApproved.selector);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     // }

//     // function test_lockAsset_assetLocked() public {
//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + 10 days);

//     //     vm.prank(nftfi);
//     //     vm.expectRevert(Errors.DelegationOwner__lockAsset_assetLocked.selector);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + 20 days);
//     // }

//     // function test_lockAsset_invalidClaimDate() public {
//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__lockAsset_invalidClaimDate.selector);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, 0);
//     // }

//     // function test_lockAsset_assetDelegatedLonger(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);

//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__checkClaimDate_assetDelegatedLonger.selector);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration - 1);
//     // }

//     // function test_lockAsset_signatureDelegatedLonger(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, _duration);

//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__checkClaimDate_signatureDelegatedLonger.selector);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration - 1);
//     // }

//     // function test_lockAsset_should_work() public {
//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + 10 days);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_lockAsset_should_work_with_asset_delegated_shorter(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration);

//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration + 1);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_lockAsset_should_work_with_signature_delegated_shorter(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 100 * 365 days);

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, _duration);

//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration + 1);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // // change claimDate
//     // function test_change_ClaimDate_DelegationOwner__lockCreatorChecks_assetNotLocked(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_assetNotLocked.selector);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     // }

//     // function test_change_ClaimDate_onlyLockCreator(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_onlyLockCreator.selector);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, block.timestamp + deleDuration - 1);
//     // }

//     // function test_change_ClaimDate_assetDelegatedLonger(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, deleDuration);

//     //     vm.prank(nftfi);
//     //     vm.expectRevert(Errors.DelegationOwner__checkClaimDate_assetDelegatedLonger.selector);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, block.timestamp + deleDuration - 1);
//     // }

//     // function test_change_ClaimDate_signatureDelegatedLonger(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, deleDuration);

//     //     vm.prank(nftfi);
//     //     vm.expectRevert(Errors.DelegationOwner__checkClaimDate_signatureDelegatedLonger.selector);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, block.timestamp + deleDuration - 1);
//     // }

//     // function test_change_ClaimDate_should_work_extending_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 newClaimDate = delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)) +
//     //         1;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_reducing_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 newClaimDate = delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)) -
//     //         1;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_with_reducing_claimDate_to_current_timestamp(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 newClaimDate = block.timestamp;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_with_delegation_shorter_than_new_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, deleDuration);

//     //     uint256 newClaimDate = block.timestamp + deleDuration + 1;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_with_delegation_equal_than_new_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, deleDuration);

//     //     uint256 newClaimDate = block.timestamp + deleDuration;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_with_sig_delegation_shorter_than_new_claimDate(
//     //     uint256 _duration
//     // ) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, deleDuration);

//     //     uint256 newClaimDate = block.timestamp + deleDuration + 1;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_with_sig_delegation_equal_than_new_claimDate(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 deleDuration = _duration - 5 days;

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, deleDuration);

//     //     uint256 newClaimDate = block.timestamp + deleDuration;

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_change_ClaimDate_should_work_with_lock_creator_after_changing_lockController(
//     //     uint256 _duration
//     // ) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     uint256 newClaimDate = delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)) +
//     //         1;

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setLockController(nftfi, false);

//     //     vm.prank(nftfi);
//     //     delegationOwner.changeClaimDate(address(testPunks), safeProxyPunkId, newClaimDate);

//     //     assertEq(delegationOwner.lockedAssets(AssetLogic.assetId(address(testPunks), safeProxyPunkId)), newClaimDate);
//     // }

//     // function test_unlockAsset_assetNotLocked(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_assetNotLocked.selector);
//     //     delegationOwner.unlockAsset(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_unlockAsset_onlyLockCreator(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_onlyLockCreator.selector);
//     //     delegationOwner.unlockAsset(address(testPunks), safeProxyPunkId);
//     // }

//     // function test_unlockAsset_not_owned_nft() public {
//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_assetNotLocked.selector);

//     //     delegationOwner.unlockAsset(address(testPunks), kakarotoPunkId);
//     // }

//     // function test_unlockAsset_should_work() public {
//     //     vm.prank(nftfi);

//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + 10 days);

//     //     assertTrue(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));

//     //     vm.prank(nftfi);

//     //     delegationOwner.unlockAsset(address(testPunks), safeProxyPunkId);

//     //     assertFalse(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_unlockAsset_should_work_with_lock_creator_after_changing_lockController(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setLockController(nftfi, false);

//     //     vm.prank(nftfi);
//     //     delegationOwner.unlockAsset(address(testPunks), safeProxyPunkId);

//     //     assertFalse(delegationGuard.isLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_claimAsset_assetNotLocked(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_assetNotLocked.selector);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, karpincho);
//     // }

//     // function test_claimAsset_onlyLockCreator(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     vm.prank(kakaroto);
//     //     vm.expectRevert(Errors.DelegationOwner__lockCreatorChecks_onlyLockCreator.selector);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, karpincho);
//     // }

//     // function test_claimAsset_assetNotClaimable_asset_delegated_before_expiry(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration - 1);

//     //     vm.warp(block.timestamp + _duration - 2);

//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__claimAsset_assetNotClaimable.selector);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));
//     // }

//     // function test_claimAsset_assetNotClaimable_asset_delegated_at_expiry(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration - 1);

//     //     vm.warp(block.timestamp + _duration - 1);

//     //     vm.prank(nftfi);

//     //     vm.expectRevert(Errors.DelegationOwner__claimAsset_assetNotClaimable.selector);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));
//     // }

//     // function test_claimAsset_assetNotClaimable_asset_included_in_signature_before_expiry(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, _duration - 1);

//     //     vm.warp(block.timestamp + _duration - 2);

//     //     vm.expectRevert(Errors.DelegationOwner__claimAsset_assetNotClaimable.selector);

//     //     vm.prank(nftfi);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));
//     // }

//     // function test_claimAsset_assetNotClaimable_asset_included_in_signature_at_expiry(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, _duration - 1);

//     //     vm.warp(block.timestamp + _duration - 1);

//     //     vm.expectRevert(Errors.DelegationOwner__claimAsset_assetNotClaimable.selector);

//     //     vm.prank(nftfi);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));
//     // }

//     // function test_claimAsset_should_work_after_claim_date(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));

//     //     vm.warp(block.timestamp + _duration);

//     //     vm.prank(nftfi);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(this));
//     // }

//     // function test_claimAsset_should_work_before_claim_date_no_delegation(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(safeProxy));

//     //     vm.warp(block.timestamp + _duration - 1);

//     //     vm.prank(nftfi);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(this));
//     // }

//     // function test_claimAsset_should_work_when_asset_delegated_expired(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, _duration - 2);

//     //     vm.warp(block.timestamp + _duration - 1);

//     //     vm.prank(nftfi);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(this));
//     // }

//     // function test_claimAsset_should_work_with_lock_creator_after_changing_lockController(uint256 _duration) public {
//     //     vm.assume(_duration > 10 days && _duration < 10 * 365 days);

//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + _duration);

//     //     vm.prank(kakaroto);
//     //     delegationOwner.setLockController(nftfi, false);

//     //     vm.prank(nftfi);
//     //     delegationOwner.claimAsset(address(testPunks), safeProxyPunkId, address(this));

//     //     assertEq(testPunks.punkIndexToAddress(safeProxyPunkId), address(this));
//     // }

//     // // utils

//     // function test_isAssetLocked_should_work() public {
//     //     assertFalse(delegationOwner.isAssetLocked(address(testPunks), safeProxyPunkId));
//     //     vm.prank(nftfi);
//     //     delegationOwner.lockAsset(address(testPunks), safeProxyPunkId, block.timestamp + 10 days);
//     //     assertTrue(delegationOwner.isAssetLocked(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_isSignatureDelegated_should_work() public {
//     //     assertFalse(delegationOwner.isSignatureDelegated());

//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     assertTrue(delegationOwner.isSignatureDelegated());
//     // }

//     // function test_isSignatureDelegated_should_work_until_delegation_expires() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.warp(block.timestamp + 10 days);

//     //     assertTrue(delegationOwner.isSignatureDelegated());

//     //     vm.warp(block.timestamp + 1);

//     //     assertFalse(delegationOwner.isSignatureDelegated());
//     // }

//     // function test_isAssetDelegated_should_work_when_asset_is_not_delegated_at_all() public {
//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_isAssetDelegated_should_work_when_asset_is_delegated() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 10 days);

//     //     assertTrue(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_isAssetDelegated_should_work_until_delegation_expires() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegate(address(testPunks), safeProxyPunkId, karpincho, 10 days);

//     //     vm.warp(block.timestamp + 10 days);

//     //     assertTrue(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));

//     //     vm.warp(block.timestamp + 1);

//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_isAssetDelegated_should_work_when_asset_is_included_in_signature_delegated() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     assertTrue(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }

//     // function test_isAssetDelegated_should_work_until_signature_delegation_expires() public {
//     //     vm.prank(delegationController);
//     //     delegationOwner.delegateSignature(assets, assetIds, karpincho, 10 days);

//     //     vm.warp(block.timestamp + 10 days);

//     //     assertTrue(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));

//     //     vm.warp(block.timestamp + 1);

//     //     assertFalse(delegationOwner.isAssetDelegated(address(testPunks), safeProxyPunkId));
//     // }
// }
