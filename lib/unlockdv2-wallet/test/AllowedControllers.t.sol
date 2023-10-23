// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { AllowedControllers, Errors } from "src/libs/allowed/AllowedControllers.sol";
import { Config } from "./utils/Config.sol";

contract AllowedControllersTest is Config {
    function test_should_set_controllers_upon_creation(address[] memory _delegationControllers) public {
        uint256 i;

        for (i = 0; i < _delegationControllers.length; ) {
            vm.assume(_delegationControllers[i] != address(0));
            unchecked {
                i++;
            }
        }

        AllowedControllers allowed = new AllowedControllers(address(aclManager), _delegationControllers);

        for (i = 0; i < _delegationControllers.length; ) {
            assertTrue(allowed.isAllowedDelegationController(_delegationControllers[i]));
            unchecked {
                i++;
            }
        }
    }

    // function test_setLockControllerAllowance_onlyOwner() public {
    //     vm.prank(karpincho);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     allowedControllers.setLockControllerAllowance(karpincho, true);
    // }

    // function test_setLockControllerAllowance_invalidAddress() public {
    //     vm.expectRevert(Errors.AllowedControllers__setLockControllerAllowance_invalidAddress.selector);
    //     allowedControllers.setLockControllerAllowance(address(0), true);
    // }

    // function test_setLockControllerAllowance_should_work() public {
    //     allowedControllers.setLockControllerAllowance(karpincho, true);
    //     assertTrue(allowedControllers.isAllowedLockController(karpincho));
    //     allowedControllers.setLockControllerAllowance(karpincho, false);
    //     assertFalse(allowedControllers.isAllowedLockController(karpincho));
    // }

    // function test_setLockControllerAllowances_onlyOwner() public {
    //     address[] memory controllers = new address[](1);
    //     controllers[0] = karpincho;
    //     bool[] memory allowances = new bool[](1);
    //     vm.prank(karpincho);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     allowedControllers.setLockControllerAllowances(controllers, allowances);
    // }

    // function test_setLockControllerAllowances_arityMismatch() public {
    //     address[] memory controllers = new address[](2);
    //     controllers[0] = kakaroto;
    //     controllers[1] = vegeta;
    //     bool[] memory allowances = new bool[](1);
    //     allowances[0] = true;

    //     vm.expectRevert(Errors.AllowedControllers__setLockControllerAllowances_arityMismatch.selector);
    //     allowedControllers.setLockControllerAllowances(controllers, allowances);
    // }

    // function test_setLockControllerAllowances_invalidAddress() public {
    //     address[] memory controllers = new address[](1);
    //     controllers[0] = address(0);
    //     bool[] memory allowances = new bool[](1);
    //     allowances[0] = true;
    //     vm.expectRevert(Errors.AllowedControllers__setLockControllerAllowance_invalidAddress.selector);
    //     allowedControllers.setLockControllerAllowances(controllers, allowances);
    // }

    // function test_setLockControllerAllowances_should_work() public {
    //     address[] memory controllers = new address[](2);
    //     controllers[0] = kakaroto;
    //     controllers[1] = karpincho;
    //     bool[] memory allowances = new bool[](2);
    //     allowances[0] = true;
    //     allowances[1] = true;

    //     allowedControllers.setLockControllerAllowances(controllers, allowances);

    //     for (uint256 i; i < controllers.length; ) {
    //         assertEq(allowedControllers.isAllowedLockController(controllers[i]), allowances[i]);
    //         unchecked {
    //             i++;
    //         }
    //     }
    // }

    ////

    function test_setDelegationControllerAllowance_onlyOwner() public {
        vm.prank(karpincho);
        vm.expectRevert("Ownable: caller is not the owner");
        allowedControllers.setDelegationControllerAllowance(karpincho, true);
    }

    function test_setDelegationControllerAllowance_invalidAddress() public {
        vm.expectRevert(Errors.AllowedControllers__setDelegationControllerAllowance_invalidAddress.selector);
        allowedControllers.setDelegationControllerAllowance(address(0), true);
    }

    function test_setDelegationControllerAllowance_should_work() public {
        allowedControllers.setDelegationControllerAllowance(karpincho, true);
        assertTrue(allowedControllers.isAllowedDelegationController(karpincho));
        allowedControllers.setDelegationControllerAllowance(karpincho, false);
        assertFalse(allowedControllers.isAllowedDelegationController(karpincho));
    }

    function test_setDelegationControllerAllowances_onlyOwner() public {
        address[] memory controllers = new address[](1);
        controllers[0] = karpincho;
        bool[] memory allowances = new bool[](1);
        vm.prank(karpincho);
        vm.expectRevert("Ownable: caller is not the owner");
        allowedControllers.setDelegationControllerAllowances(controllers, allowances);
    }

    function test_setDelegationControllerAllowances_arityMismatch() public {
        address[] memory controllers = new address[](2);
        controllers[0] = kakaroto;
        controllers[1] = vegeta;
        bool[] memory allowances = new bool[](1);
        allowances[0] = true;

        vm.expectRevert(Errors.AllowedControllers__setDelegationControllerAllowances_arityMismatch.selector);
        allowedControllers.setDelegationControllerAllowances(controllers, allowances);
    }

    function test_setDelegationControllerAllowances_invalidAddress() public {
        address[] memory controllers = new address[](1);
        controllers[0] = address(0);
        bool[] memory allowances = new bool[](1);
        allowances[0] = true;
        vm.expectRevert(Errors.AllowedControllers__setDelegationControllerAllowance_invalidAddress.selector);
        allowedControllers.setDelegationControllerAllowances(controllers, allowances);
    }

    function test_setDelegationControllerAllowances_should_work() public {
        address[] memory controllers = new address[](2);
        controllers[0] = kakaroto;
        controllers[1] = karpincho;
        bool[] memory allowances = new bool[](2);
        allowances[0] = true;
        allowances[1] = true;

        allowedControllers.setDelegationControllerAllowances(controllers, allowances);

        for (uint256 i; i < controllers.length; ) {
            assertEq(allowedControllers.isAllowedDelegationController(controllers[i]), allowances[i]);
            unchecked {
                i++;
            }
        }
    }
}
