// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @notice IMaxApyVault contains the main interface for MaxApy V2 Vaults
 */
interface IMaxApyVault is IERC4626 {

    /// @notice Stores all data from a single strategy
    /// @dev Packed in two slots
    struct StrategyData {
        /// Slot 0
        /// @notice Maximum percentage available to be lent to strategies(in BPS)
        /// @dev in BPS. uint16 is enough to cover the max BPS value of 10_000
        uint16 strategyDebtRatio;
        /// @notice The performance fee
        /// @dev in BPS. uint16 is enough to cover the max BPS value of 10_000
        uint16 strategyPerformanceFee;
        /// @notice Timestamp when the strategy was added.
        /// @dev Overflowing July 21, 2554
        uint48 strategyActivation;
        /// @notice block.timestamp of the last time a report occured
        /// @dev Overflowing July 21, 2554
        uint48 strategyLastReport;
        /// @notice Upper limit on the increase of debt since last harvest
        /// @dev max debt per harvest to be set to a maximum value of 4,722,366,482,869,645,213,695
        uint128 strategyMaxDebtPerHarvest;
        /// Slot 1
        /// @notice Lower limit on the increase of debt since last harvest
        /// @dev min debt per harvest to be set to a maximum value of 16,777,215
        uint128 strategyMinDebtPerHarvest;
        /// @notice Total returns that Strategy reported to the Vault
        /// @dev max strategy total gain of 79,228,162,514,264,337,593,543,950,335
        uint128 strategyTotalUnrealizedGain;
        /// Slot 2
        /// @notice Total outstanding debt that Strategy has
        /// @dev max total debt of 79,228,162,514,264,337,593,543,950,335
        uint128 strategyTotalDebt;
        /// @notice Total losses that Strategy has realized for Vault
        /// @dev max strategy total loss of 79,228,162,514,264,337,593,543,950,335
        uint128 strategyTotalLoss;
        /// Slot 3
        /// @notice True if the strategy has switched to autopilot mode
        /// @dev it is activated from the strategy and will only work if `autoPilotEnabled` == true
        /// @dev the strategy can still be manually harvested in autopilot mode
        bool autoPilot;
    }

    function report(
        uint128 unrealizedGain,
        uint128 loss,
        uint128 debtPayment,
        address managementFeeReceiver
    )
        external
        returns (uint256);

    /// Ownership
    function transferOwnership(address newOwner) external payable;

    function renounceOwnership() external payable;

    function requestOwnershipHandover() external payable;

    function cancelOwnershipHandover() external payable;

    function completeOwnershipHandover(address pendingOwner) external payable;

    /// View ownership
    function ownershipHandoverExpiresAt(address pendingOwner) external view returns (uint256);

    function owner() external view returns (address result);

    /// Roles
    function grantRoles(address user, uint256 roles) external payable;

    function revokeRoles(address user, uint256 roles) external payable;

    function renounceRoles(uint256 roles) external payable;

    /// View roles
    function ADMIN_ROLE() external returns (uint256);

    function EMERGENCY_ADMIN_ROLE() external returns (uint256);

    function KEEPER_ROLE() external returns (uint256);

    function STRATEGY_ROLE() external returns (uint256);

    function hasAnyRole(address user, uint256 roles) external view returns (bool result);

    function hasAllRoles(address user, uint256 roles) external view returns (bool result);

    function rolesOf(address user) external view returns (uint256 roles);

    function rolesFromOrdinals(uint8[] memory ordinals) external pure returns (uint256 roles);

    function ordinalsFromRoles(uint256 roles) external pure returns (uint8[] memory ordinals);

    /// Vault configuration
    function debtRatio() external returns (uint256);

    function totalDebt() external returns (uint256);

    function totalIdle() external returns (uint256);

    function strategies(address strategy) external returns (StrategyData memory);

    function withdrawalQueue(uint256 index) external returns (address);

    function emergencyShutdown() external returns (bool);

    function nexHarvestStrategyIndex() external view returns (uint8);

    function autoPilotEnabled() external returns (bool);

    /// Vault management
    function setEmergencyShutdown(bool _emergencyShutdown) external;

    function addStrategy(
        address newStrategy,
        uint256 strategyDebtRatio,
        uint256 strategyMaxDebtPerHarvest,
        uint256 strategyMinDebtPerHarvest,
        uint256 strategyPerformanceFee
    )
        external;

    function revokeStrategy(address strategy) external;

    function removeStrategy(address strategy) external;

    function exitStrategy(address strategy) external;

    function updateStrategyData(
        address strategy,
        uint256 newDebtRatio,
        uint256 newMaxDebtPerHarvest,
        uint256 newMinDebtPerHarvest,
        uint256 newPerformanceFee
    )
        external;

    function setWithdrawalQueue(address[20] calldata queue) external;

    function setPerformanceFee(uint256 _performanceFee) external;

    function setManagementFee(uint256 _managementFee) external;

    function setDepositLimit(uint256 _depositLimit) external;

    function setTreasury(address _treasury) external;

    function setAutopilotEnabled(bool _autoPilotEnabled) external;

    function setAutoPilot(bool _autoPilot) external;

    /// Vault view functions
    function performanceFee() external returns (uint256);

    function managementFee() external returns (uint256);

    function AUTOPILOT_HARVEST_INTERVAL() external returns (uint256);

    function MAXIMUM_STRATEGIES() external returns (uint256);

    function debtOutstanding(address strategy) external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function totalDeposits() external view returns (uint256);

    function lastReport() external view returns (uint256);

    function treasury() external view returns (address);

    function sharePrice() external view returns (uint256);
}
