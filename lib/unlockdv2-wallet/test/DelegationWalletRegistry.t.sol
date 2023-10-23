// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { IDelegationWalletRegistry, DelegationWalletRegistry, Errors } from "../src/DelegationWalletRegistry.sol";
import { Config } from "./utils/Config.sol";

contract DelegationWalletRegistryTest is Config {
    DelegationWalletRegistry internal registry;

    function setUp() public {
        registry = new DelegationWalletRegistry();
    }

    function test_seFactory_onlyOwner() public {
        vm.prank(karpincho);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.setFactory(karpincho);
    }

    function test_seFactory_should_work() public {
        registry.setFactory(karpincho);

        assertEq(registry.delegationWalletFactory(), karpincho);
    }

    // function test_setWallet_onlyFactoryOrOwner() public {
    //     vm.prank(karpincho);
    //     vm.expectRevert(Errors.DelegationWalletRegistry__onlyFactoryOrOwner.selector);
    //     registry.setWallet(address(1), address(2), address(3), address(4));
    // }

    // function test_setWallet_owner_invalidWalletAddress() public {
    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidWalletAddress.selector);
    //     registry.setWallet(address(0), address(2), address(3), address(4));
    // }

    // function test_setWallet_owner_invalidOwnerAddress() public {
    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidOwnerAddress.selector);
    //     registry.setWallet(address(1), address(0), address(3), address(4));
    // }

    // function test_setWallet_owner_invalidDelegationOwnerAddress() public {
    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidDelegationOwnerAddress.selector);
    //     registry.setWallet(address(1), address(2), address(0), address(4));
    // }

    // function test_setWallet_owner_invalidGuardAddress() public {
    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidGuardAddress.selector);
    //     registry.setWallet(address(1), address(2), address(3), address(0));
    // }

    // function test_setWallet_owner_should_word() public {
    //     registry.setWallet(address(1), address(2), address(3), address(4));

    //     IDelegationWalletRegistry.Wallet memory wallet = registry.getWallet(address(1));
    //     assertEq(wallet.wallet, address(1));
    //     assertEq(wallet.owner, address(2));
    //     assertEq(wallet.delegationOwner, address(3));
    //     assertEq(wallet.delegationGuard, address(4));

    //     IDelegationWalletRegistry.Wallet memory walletAt = registry.getOwnerWalletAt(address(2), 0);
    //     assertEq(walletAt.wallet, address(1));
    //     assertEq(walletAt.owner, address(2));
    //     assertEq(walletAt.delegationOwner, address(3));
    //     assertEq(walletAt.delegationGuard, address(4));
    // }

    // function test_setWallet_factory_invalidWalletAddress() public {
    //     registry.setFactory(karpincho);
    //     vm.prank(karpincho);

    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidWalletAddress.selector);
    //     registry.setWallet(address(0), address(2), address(3), address(4));
    // }

    // function test_setWallet_factory_invalidOwnerAddress() public {
    //     registry.setFactory(karpincho);
    //     vm.prank(karpincho);

    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidOwnerAddress.selector);
    //     registry.setWallet(address(1), address(0), address(3), address(4));
    // }

    // function test_setWallet_factory_invalidDelegationOwnerAddress() public {
    //     registry.setFactory(karpincho);
    //     vm.prank(karpincho);

    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidDelegationOwnerAddress.selector);
    //     registry.setWallet(address(1), address(2), address(0), address(4));
    // }

    // function test_setWallet_factory_invalidGuardAddress() public {
    //     registry.setFactory(karpincho);
    //     vm.prank(karpincho);

    //     vm.expectRevert(Errors.DelegationWalletRegistry__setWallet_invalidGuardAddress.selector);
    //     registry.setWallet(address(1), address(2), address(3), address(0));
    // }

    // function test_setWallet_factory_should_word() public {
    //     registry.setFactory(karpincho);
    //     vm.prank(karpincho);

    //     registry.setWallet(address(1), address(2), address(3), address(4));

    //     IDelegationWalletRegistry.Wallet memory wallet = registry.getWallet(address(1));
    //     assertEq(wallet.wallet, address(1));
    //     assertEq(wallet.owner, address(2));
    //     assertEq(wallet.delegationOwner, address(3));
    //     assertEq(wallet.delegationGuard, address(4));

    //     IDelegationWalletRegistry.Wallet memory walletAt = registry.getOwnerWalletAt(address(2), 0);
    //     assertEq(walletAt.wallet, address(1));
    //     assertEq(walletAt.owner, address(2));
    //     assertEq(walletAt.delegationOwner, address(3));
    //     assertEq(walletAt.delegationGuard, address(4));
    // }
}
