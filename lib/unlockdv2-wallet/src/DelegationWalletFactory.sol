// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import { console } from "forge-std/console.sol";

import { Enum } from "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import { GnosisSafeProxyFactory, GnosisSafeProxy } from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IGnosisSafe } from "./interfaces/IGnosisSafe.sol";
import { TransactionGuard } from "./libs/guards/TransactionGuard.sol";
import { IDelegationWalletRegistry } from "./interfaces/IDelegationWalletRegistry.sol";
import { GnosisSafe } from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import { GuardOwner } from "./libs/owners/GuardOwner.sol";
import { DelegationOwner } from "./libs/owners/DelegationOwner.sol";
import { ProtocolOwner } from "./libs/owners/ProtocolOwner.sol";

/**
 * @title DelegationWalletFactory
 * @author BootNode
 * @dev Factory contract for deploying and configuring a new Delegation Wallet
 * Deploys a GnosisSafe, a DelegationOwner and a DelegationGuard, sets Safe wallet threshold to 1, the DelegationOwner
 * contract as owner together with the deployer and the DelegationGuard as the Safe's guard.
 */
contract DelegationWalletFactory {
    /**
     * @notice Stores the Safe proxy factory address.
     */
    address public immutable gnosisSafeProxyFactory;
    /**
     * @notice Stores the Safe implementation address.
     */
    address public immutable singleton;
    /**
     * @notice Stores the Safe CompatibilityFallbackHandler address.
     */
    address public immutable compatibilityFallbackHandler;
    /**
     * @notice Stores the TransactionGuard beacon contract address.
     */
    address public immutable guardBeacon;
    /**
     * @notice Stores the GuardOwner beacon contract address.
     */
    address public immutable guardOwnerBeacon;
    /**
     * @notice Stores the DelegationOwner beacon contract address.
     */
    address public immutable delegationOwnerBeacon;
    /**
     * @notice Stores the DelegationOwner beacon contract address.
     */
    address public immutable protocolOwnerBeacon;
    /**
     * @notice Stores the DelegationWalletRegistry contract address.
     */
    address public immutable registry;

    event WalletDeployed(
        address indexed safe,
        address indexed owner,
        address indexed guard,
        address delegationOwner,
        address protocolOwner,
        address sender
    );

    constructor(
        address _gnosisSafeProxyFactory,
        address _singleton,
        address _compatibilityFallbackHandler,
        address _guardBeacon,
        address _guardOwnerBeacon,
        address _delegationOwnerBeacon,
        address _protocolOwnerBeacon,
        address _registry
    ) {
        gnosisSafeProxyFactory = _gnosisSafeProxyFactory;
        singleton = _singleton;
        compatibilityFallbackHandler = _compatibilityFallbackHandler;
        guardBeacon = _guardBeacon;
        guardOwnerBeacon = _guardOwnerBeacon;
        delegationOwnerBeacon = _delegationOwnerBeacon;
        protocolOwnerBeacon = _protocolOwnerBeacon;

        registry = _registry;
    }

    /**
     * @notice Deploys a new DelegationWallet with the msg.sender as the owner.
     */
    function deploy(address _delegationController) external returns (address, address, address, address) {
        return deployFor(msg.sender, _delegationController);
    }

    /**
     * @notice Deploys a new DelegationWallet for a given owner.
     * @param _owner - The owner's address.
     * @param _delegationController - Delegation controller owner
     */
    function deployFor(
        address _owner,
        address _delegationController
    ) public returns (address, address, address, address) {
        address safeProxy = address(
            GnosisSafeProxyFactory(gnosisSafeProxyFactory).createProxy(singleton, new bytes(0))
        );

        // Proxy creation
        address guardOwnerProxy = address(new BeaconProxy(guardOwnerBeacon, new bytes(0)));
        address delegationOwnerProxy = address(new BeaconProxy(delegationOwnerBeacon, new bytes(0)));
        address protocolOwnerProxy = address(new BeaconProxy(protocolOwnerBeacon, new bytes(0)));

        // Set owners
        address[] memory owners = new address[](4);
        owners[0] = _owner;
        owners[1] = guardOwnerProxy;
        owners[2] = delegationOwnerProxy;
        owners[3] = protocolOwnerProxy;

        // setup owners and threshold, this should be done before delegationOwner.initialize because DelegationOwners
        // has to be an owner to be able to set the guard
        GnosisSafe(payable(safeProxy)).setup(
            owners,
            1,
            address(0),
            new bytes(0),
            compatibilityFallbackHandler,
            address(0),
            0,
            payable(address(0))
        );

        // Setup logic of the GUARD

        //////////////////////////////////////////
        // Initialize Owners Manager
        //////////////////////////////////////////
        // Guard OWNER
        GuardOwner(guardOwnerProxy).initialize(
            guardBeacon,
            address(safeProxy),
            _owner,
            delegationOwnerProxy,
            protocolOwnerProxy
        );
        address guard = address(GuardOwner(guardOwnerProxy).guard());
        // Delegation OWNER
        DelegationOwner(delegationOwnerProxy).initialize(
            guard,
            safeProxy,
            _owner,
            _delegationController,
            protocolOwnerProxy
        );
        // Protocol OWNER
        ProtocolOwner(protocolOwnerProxy).initialize(guard, address(safeProxy), _owner, delegationOwnerProxy);

        // Save wallet
        IDelegationWalletRegistry(registry).setWallet(
            safeProxy,
            _owner,
            guard,
            guardOwnerProxy,
            delegationOwnerProxy,
            protocolOwnerProxy
        );

        emit WalletDeployed(safeProxy, _owner, guard, delegationOwnerProxy, protocolOwnerProxy, msg.sender);

        return (safeProxy, guard, delegationOwnerProxy, protocolOwnerProxy);
    }
}
