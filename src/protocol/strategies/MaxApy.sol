// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IMaxApyVault} from '../../interfaces/IMaxApyVault.sol';
import {IStrategy} from '../../interfaces/IStrategy.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {MathUtils} from '../../libraries/math/MathUtils.sol';
import {PercentageMath} from '../../libraries/math/PercentageMath.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';

/**
 * @title MaxApyStrategy
 * @dev This contract implements a strategy for maximizing APY in a vault system.
 * It interacts with a MaxApyVault to manage deposits and withdrawals, and implements
 * logic for calculating investment amounts and managing strategy configuration.
 */
contract MaxApyStrategy is IStrategy {
  using PercentageMath for uint256;

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
  * @dev Emitted when the deep configuration of the strategy is updated.
  * @param newMinAmountToInvest The new minimum amount to invest.
  * @param newRatio The new ratio value.
  */
  event DeepConfigUpdated(uint256 newMinAmountToInvest, uint256 newRatio);

  /**
  * @dev Emitted when the strategy configuration is updated.
  * @param newMinCap The new minimum cap value.
  * @param newPercentageToInvest The new percentage to invest.
  */
  event StrategyConfigUpdated(uint256 newMinCap, uint256 newPercentageToInvest);

  /*//////////////////////////////////////////////////////////////
                             CONSTANTS
  //////////////////////////////////////////////////////////////*/
  uint256 internal constant MAX_LOSS = 100; // 1%

  /*//////////////////////////////////////////////////////////////
                           IMMUTABLES
  //////////////////////////////////////////////////////////////*/
  address internal immutable _aclManager;
  address internal immutable _asset;
  address internal immutable _vault;

  /*//////////////////////////////////////////////////////////////
                         STATE VARIABLES
  //////////////////////////////////////////////////////////////*/
  uint256 internal _minAmountToInvest;
  uint256 internal _ratio;
  uint256 internal _minCap;
  uint256 internal _percentageToInvest;

  /*//////////////////////////////////////////////////////////////
                             MODIFIERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @dev Modifier to restrict access to admin users only.
   */
  modifier onlyAdmin() {
    if (!IACLManager(_aclManager).isUTokenAdmin(msg.sender)) {
      revert Errors.UTokenAccessDenied();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/
  /**
   * @dev Constructor to initialize the MaxApyStrategy contract.
   * @param aclManager_ Address of the ACL manager contract.
   * @param asset_ Address of the asset token.
   * @param vault_ Address of the vault contract.
   * @param minCap_ Minimum cap for investments.
   * @param percentageToInvest_ Percentage of funds to invest.
   */
  constructor(
    address aclManager_,
    address asset_,
    address vault_,
    uint256 minCap_,
    uint256 percentageToInvest_
  ) {
    _asset = asset_;
    _vault = vault_;
    _minCap = minCap_;
    _percentageToInvest = percentageToInvest_;
    _aclManager = aclManager_;
    // Default config
    _minAmountToInvest = 0.5 ether;
    _ratio = 3;
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @dev Returns the address of the asset token.
   * @return Address of the asset token.
   */
  function asset() external view returns (address) {
    return _asset;
  }

  /**
   * @dev Returns the current configuration of the strategy.
   * @return StrategyConfig struct containing the strategy configuration.
   */
  function getConfig() external view returns (StrategyConfig memory) {
    return
      StrategyConfig({
        asset: _asset,
        vault: _vault,
        minCap: _minCap,
        percentageToInvest: _percentageToInvest
      });
  }

  /**
   * @dev Returns the total value the strategy holds for a specific owner.
   * @param owner Address of the owner.
   * @return The total value in asset token amount.
   */
  function balanceOf(address owner) external view returns (uint256) {
    uint256 shares = IMaxApyVault(_vault).balanceOf(owner);
    return shares == 0 ? 0 : IMaxApyVault(_vault).convertToAssets(shares);
  }

  /**
   * @dev Returns the maximum amount of shares that can be redeemed by an owner.
   * @param owner Address of the owner.
   * @return maxShares Maximum number of shares that can be redeemed.
   */
  function maxRedeem(address owner) external view virtual returns (uint256 maxShares) {
    return IMaxApyVault(_vault).maxRedeem(owner);
  }

  /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @dev Calculates the amount to supply based on the total supply not invested.
   * @param totalSupplyNotInvested Total supply not yet invested.
   * @return Amount to supply.
   */
  function calculateAmountToSupply(
    uint256 totalSupplyNotInvested
  ) external view returns (uint256) {
    if (totalSupplyNotInvested <= _minCap) return 0;
    uint256 investAmount = (totalSupplyNotInvested - _minCap).percentMul(_percentageToInvest);
    return investAmount > _minAmountToInvest ? investAmount : 0;
  }

  /**
   * @dev Supplies assets to the vault.
   * @param asset_ Address of the asset token.
   * @param from_ Address to supply from.
   * @param amount_ Amount to supply.
   * @return Amount of shares received.
   */
  function supply(
    address asset_,
    address from_,
    uint256 amount_
  ) external returns (uint256) {
    IERC20(asset_).approve(_vault, amount_);
    return IMaxApyVault(_vault).deposit(amount_, from_);
  }

  /**
   * @dev Calculates the amount to redeem based on various parameters.
   * @param totalSupplyNotInvested_ Total supply not invested.
   * @param from_ Address to withdraw from.
   * @param amount_ Amount requested to withdraw.
   * @return Amount of shares to withdraw.
   */
  function calculateShareForAmount(
    uint256 totalSupplyNotInvested_,
    address from_,
    uint256 amount_
  ) external view returns (uint256) {
    uint256 amountToWithdraw = _getAmountToRedeem(totalSupplyNotInvested_, amount_);
    uint256 currentBalance = this.balanceOf(from_);
    if (currentBalance == 0 || amountToWithdraw == 0) return 0;
    if (totalSupplyNotInvested_ < _minCap) {
      uint256 amountToMinCap = _minCap - totalSupplyNotInvested_;
      amountToWithdraw = MathUtils.minOf(
        currentBalance,
        amountToWithdraw + amountToMinCap
      );
    }
    return IMaxApyVault(_vault).convertToShares(amountToWithdraw);
  }

  /**
   * @dev Redeems shares from the vault.
   * @param to_ Address to send the redeemed assets to.
   * @param owner_ Address of the owner of the shares.
   * @param shares_ Number of shares to redeem.
   * @return Amount of assets redeemed.
   */
  function redeem(
    address to_,
    address owner_,
    uint256 shares_
  ) external returns (uint256) {
    uint256 expectedAssets = IMaxApyVault(_vault).convertToAssets(shares_);
    uint256 minAcceptableAssets = expectedAssets - expectedAssets.percentMul(MAX_LOSS);
    uint256 assetsRedeemed = IMaxApyVault(_vault).redeem(shares_, to_, owner_);

    if (assetsRedeemed < minAcceptableAssets) {
      revert Errors.MaxLossReached();
    }
    return assetsRedeemed;
  }

  /**
   * @dev Updates the deep configuration of the strategy.
   * @param minAmountToInvest_ New minimum amount to invest.
   * @param ratio_ New ratio.
   */
  function updateDeepConfig(uint256 minAmountToInvest_, uint256 ratio_) external onlyAdmin {
    _minAmountToInvest = minAmountToInvest_;
    _ratio = ratio_;
    emit DeepConfigUpdated(minAmountToInvest_, ratio_);
  }

  /**
   * @dev Updates the strategy configuration.
   * @param minCap_ New minimum cap.
   * @param percentageToInvest_ New percentage to invest.
   */
  function updateStrategyConfig(uint256 minCap_, uint256 percentageToInvest_) external onlyAdmin {
    if (percentageToInvest_ > 10000) revert Errors.PercentageOutOfRange();
    _minCap = minCap_;
    _percentageToInvest = percentageToInvest_;
    emit StrategyConfigUpdated(minCap_, percentageToInvest_);
  }

  /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @dev Calculates the amount to withdraw based on current supply and requested amount.
   * @param currentSupply Current supply.
   * @param amount Requested amount to withdraw.
   * @return Amount to withdraw.
   */
  function _getAmountToRedeem(
    uint256 currentSupply,
    uint256 amount
  ) internal view returns (uint256) {
    return (currentSupply == 0 || currentSupply / _ratio < amount) ? amount : 0;
  }
}
