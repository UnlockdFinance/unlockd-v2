// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "forge-std/Test.sol";

// import { DelegationOwner, DelegationGuard, DelegationWalletFactory, TestNft, Config, TestNftPlatform, DelegationRecipes, Errors } from "./utils/Config.sol";

// import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
// import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// contract DelegationRecipesTest is Config {
//     function setUp() public {
//         vm.prank(kakaroto);
//         (safeProxy, delegationOwnerProxy, delegationGuardProxy) = delegationWalletFactory.deploy(delegationController);
//         safe = GnosisSafe(payable(safeProxy));
//     }

//     function test_add_onlyOwner() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](1);
//         string[] memory descriptions = new string[](1);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;
//         descriptions[0] = "Some description";

//         vm.prank(karpincho);
//         vm.expectRevert("Ownable: caller is not the owner");
//         delegationRecipes.add(kakaroto, contracts, selectors, descriptions);
//     }

//     function test_add_should_fail_arity_arityMismatch_1() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](1);
//         string[] memory descriptions = new string[](2);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;
//         descriptions[0] = "Some description";
//         descriptions[1] = "Some description 2";

//         vm.expectRevert(Errors.DelegationRecipes__add_arityMismatch.selector);
//         delegationRecipes.add(address(testNft), contracts, selectors, descriptions);
//     }

//     function test_add_should_fail_arity_arityMismatch_2() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](2);
//         string[] memory descriptions = new string[](1);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;
//         selectors[1] = TestNftPlatform.allowedFunction.selector;
//         descriptions[0] = "Some description";

//         vm.expectRevert(Errors.DelegationRecipes__add_arityMismatch.selector);
//         delegationRecipes.add(address(testNft), contracts, selectors, descriptions);
//     }

//     function test_add_should_work() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](1);
//         string[] memory descriptions = new string[](1);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;
//         descriptions[0] = "Some description";

//         delegationRecipes.add(kakaroto, contracts, selectors, descriptions);

//         assertTrue(
//             delegationRecipes.isAllowedFunction(
//                 kakaroto,
//                 address(testNftPlatform),
//                 TestNftPlatform.allowedFunction.selector
//             )
//         );
//         assertEq(
//             delegationRecipes.functionDescriptions(
//                 keccak256(
//                     abi.encodePacked(kakaroto, address(testNftPlatform), TestNftPlatform.allowedFunction.selector)
//                 )
//             ),
//             "Some description"
//         );
//     }

//     function test_remove_onlyOwner() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](1);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;

//         vm.prank(karpincho);
//         vm.expectRevert("Ownable: caller is not the owner");
//         delegationRecipes.remove(kakaroto, contracts, selectors);
//     }

//     function test_remove_should_fail_arity_arityMismatch_1() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](2);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;
//         selectors[1] = TestNftPlatform.allowedFunction.selector;

//         vm.expectRevert(Errors.DelegationRecipes__remove_arityMismatch.selector);
//         delegationRecipes.remove(address(testNft), contracts, selectors);
//     }

//     function test_remove_should_work() public {
//         address[] memory contracts = new address[](1);
//         bytes4[] memory selectors = new bytes4[](1);
//         contracts[0] = address(testNftPlatform);
//         selectors[0] = TestNftPlatform.allowedFunction.selector;
//         delegationRecipes.remove(address(testNft), contracts, selectors);

//         assertFalse(
//             delegationRecipes.isAllowedFunction(
//                 address(testNft),
//                 address(testNftPlatform),
//                 TestNftPlatform.allowedFunction.selector
//             )
//         );
//         assertEq(
//             delegationRecipes.functionDescriptions(
//                 keccak256(
//                     abi.encodePacked(
//                         address(testNft),
//                         address(testNftPlatform),
//                         TestNftPlatform.allowedFunction.selector
//                     )
//                 )
//             ),
//             ""
//         );
//     }
// }
