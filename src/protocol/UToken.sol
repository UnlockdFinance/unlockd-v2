// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';

import {IUToken} from '../interfaces/tokens/IUToken.sol';
import {IStrategy} from '../interfaces/IStrategy.sol';

import {IDebtToken} from '../interfaces/tokens/IDebtToken.sol';
import {BaseERC20, Errors, DataTypes, ERC20Upgradeable} from '../libraries/base/BaseERC20.sol';
import {ReentrancyGuard} from '../libraries/utils/ReentrancyGuard.sol';
import {DelegateCall} from '../libraries/utils/DelegateCall.sol';
import {ReserveLogic} from '../libraries/logic/ReserveLogic.sol';
import {ValidationLogic} from '../libraries/logic/ValidationLogic.sol';
import {GenericLogic} from '../libraries/logic/GenericLogic.sol';

import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';

import {console} from 'forge-std/console.sol';

/**
 * @title ERC20 UToken
 * @dev Implementation of the interest bearing token for the Unlockd protocol
 * @author Unlockd
 */
contract UToken is IUToken, BaseERC20, ReentrancyGuard, UUPSUpgradeable {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;
  using ReserveLogic for DataTypes.ReserveData;
  using PercentageMath for uint256;
  using DelegateCall for address;

  /**
   * @dev Initializes the uToken
   * @param aclManager ACL Manager address
   * @param treasury The address of the Unlockd treasury, receiving the fees on this uToken
   * @param underlyingAsset The address of the underlying asset of this uToken
   * @param interestRateAddress address interes rate calculator
   * @param strategyAddress address of the strategy
   * @param debtTokenAddress address interes rate calculator
   * @param tokenDecimals decimals of the token
   * @param reserveFactor percentage reserve factor
   * @param tokenName token name
   * @param tokenSymbol token symbol
   
   */
  function initialize(
    address aclManager,
    address treasury,
    address underlyingAsset,
    address interestRateAddress,
    address strategyAddress,
    address debtTokenAddress,
    uint8 tokenDecimals,
    uint16 reserveFactor,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external initializer {
    __BaseERC20_init(aclManager, tokenName, tokenSymbol);
    _treasury = treasury;

    _reserve.init(
      underlyingAsset,
      interestRateAddress,
      strategyAddress,
      debtTokenAddress,
      tokenDecimals,
      reserveFactor
    );

    emit Initialized(underlyingAsset, interestRateAddress, strategyAddress, treasury);
  }

  /**
   * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying uTokens.
   * - E.g. User deposits 100 USDC and gets in return 100 uusdc
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the uTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of uTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   *
   */
  function deposit(
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external override nonReentrant isActive isFrozen {
    Errors.verifyNotZero(onBehalfOf);
    Errors.verifyNotZero(amount);

    IERC20(_reserve.underlyingAsset).safeTransferFrom(_msgSender(), address(this), amount);

    (uint256 amountToMint, uint256 newLiquidityIndex) = _reserve.updateState();
    _mintToTreasury(amountToMint, newLiquidityIndex);
    _reserve.updateInterestRates(amount, 0);

    _mint(onBehalfOf, amount, _reserve.liquidityIndex);

    if (_reserve.strategyAddress != address(0)) {
      _reserve.strategyAddress.functionDelegateCall(
        abi.encodeWithSelector(
          IStrategy.supply.selector,
          amount,
          address(this),
          IStrategy(_reserve.strategyAddress).getConfig()
        )
      );
    }

    emit Deposit(_msgSender(), _reserve.underlyingAsset, amount, onBehalfOf, referralCode);
  }

  /**
   * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent uTokens owned
   * E.g. User has 100 uusdc, calls withdraw() and receives 100 USDC, burning the 100 uusdc
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole uToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   *
   */
  function withdraw(uint256 amount, address to) external nonReentrant isActive returns (uint256) {
    Errors.verifyNotZero(to);
    Errors.verifyNotZero(amount);
    uint256 userBalance = this.balanceOf(_msgSender());
    if (amount > userBalance) {
      revert Errors.AmountExceedsBalance();
    }
    uint256 amountToWithdraw = amount;

    if (amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }
    uint256 availableLiquidity = super.totalSupply();
    if (amount > availableLiquidity) {
      revert Errors.NotEnoughLiquidity();
    }

    (uint256 amountToMint, uint256 newLiquidityIndex) = _reserve.updateState();
    _mintToTreasury(amountToMint, newLiquidityIndex);
    _reserve.updateInterestRates(0, amountToWithdraw);

    if (_reserve.strategyAddress != address(0)) {
      _reserve.strategyAddress.functionDelegateCall(
        abi.encodeWithSelector(
          IStrategy.withdraw.selector,
          amountToWithdraw,
          address(this),
          address(this),
          IStrategy(_reserve.strategyAddress).getConfig()
        )
      );
    }

    _burn(_msgSender(), to, amountToWithdraw, _reserve.liquidityIndex);

    emit Withdraw(_msgSender(), _reserve.underlyingAsset, amountToWithdraw, to);

    return amountToWithdraw;
  }

  /**
   * @dev Only protocol, can borrow onBelhalf of a user
   * @param loanId Loan id to assign the debt
   * @param amount Amount to borrow
   * @param to Who is going to receive the funds
   * @param onBehalfOf user that receive the debt tokens
   *
   */
  function borrowOnBelhalf(
    bytes32 loanId,
    uint256 amount,
    address to,
    address onBehalfOf
  ) external nonReentrant isActive onlyProtocol {
    Errors.verifyNotZero(onBehalfOf);
    Errors.verifyNotZero(to);
    Errors.verifyNotZero(amount);

    // Validate if we have enought liquidity
    uint256 availableLiquidity = super.totalSupply();
    if (amount > availableLiquidity) {
      revert Errors.NotEnoughLiquidity();
    }

    if (_reserve.strategyAddress != address(0)) {
      _reserve.strategyAddress.functionDelegateCall(
        abi.encodeWithSelector(
          IStrategy.withdraw.selector,
          amount,
          address(this),
          address(this),
          IStrategy(_reserve.strategyAddress).getConfig()
        )
      );
    }
    // Mint token to the user
    IDebtToken(_reserve.debtTokenAddress).mint(
      loanId,
      onBehalfOf,
      amount,
      _reserve.variableBorrowIndex
    );

    IERC20(_reserve.underlyingAsset).safeTransfer(to, amount);

    _reserve.updateInterestRates(0, amount);

    emit BorrowOnBelhalf(
      onBehalfOf,
      to,
      amount,
      loanId,
      _reserve.underlyingAsset,
      _reserve.currentVariableBorrowRate
    );
  }

  function repayOnBelhalf(
    bytes32 loanId,
    uint256 amount,
    address from,
    address onBehalfOf
  ) external nonReentrant isActive onlyProtocol {
    Errors.verifyNotZero(onBehalfOf);
    Errors.verifyNotZero(amount);

    // Move the amount from the user to deposit
    IERC20(_reserve.underlyingAsset).safeTransferFrom(from, address(this), amount);
    // Deposit again on the strategy if is needed
    if (_reserve.strategyAddress != address(0)) {
      _reserve.strategyAddress.functionDelegateCall(
        abi.encodeWithSelector(
          IStrategy.supply.selector,
          amount,
          address(this),
          IStrategy(_reserve.strategyAddress).getConfig()
        )
      );
    }
    // Update the interest rate
    _reserve.updateInterestRates(amount, 0);
    // Burn debpt token from the user
    IDebtToken(_reserve.debtTokenAddress).burn(
      loanId,
      onBehalfOf,
      amount,
      _reserve.variableBorrowIndex
    );

    emit RepayOnBelhalf(
      from,
      loanId,
      _reserve.underlyingAsset,
      amount,
      onBehalfOf,
      _reserve.currentVariableBorrowRate
    );
  }

  /**
   * @dev Sets new treasury to the specified UToken
   * @param treasury the new treasury address
   *
   */
  function setTreasury(address treasury) external onlyAdmin {
    Errors.verifyNotZero(treasury);
    _treasury = treasury;
    emit TreasuryAddressUpdated(treasury);
  }

  /**
   * @notice Checks authorization for UUPS upgrades
   * @dev Only ACL manager is allowed to upgrade
   */
  function _authorizeUpgrade(address) internal override onlyAdmin {}

  /**
   * @dev Calculates the balance of the user: principal balance + interest generated by the principal
   * @param user The user whose balance is calculated
   * @return The balance of the user
   *
   */
  function balanceOf(address user) public view override returns (uint256) {
    return super.balanceOf(user).rayMul(_reserve.getNormalizedIncome());
  }

  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   *
   */
  function scaledBalanceOf(address user) external view override returns (uint256) {
    return super.balanceOf(user);
  }

  /**
   * @dev Returns the normalized variable debt per unit of asset
   *
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt() external view returns (uint256) {
    return _reserve.getNormalizedDebt();
  }

  /**
   * @dev calculates the total supply of the specific uToken
   * since the balance of every single user increases over time, the total supply
   * does that too.
   * @return total supply generated by the
   *
   */
  function totalSupply() public view override(ERC20Upgradeable, IUToken) returns (uint256) {
    return super.totalSupply().rayMul(_reserve.getNormalizedIncome());
  }

  /**
   * @dev calculates the total supply of the specific uToken
   * since the balance of every single user increases over time, the total supply
   * does that too.
   * @return total supply generated by the
   *
   */
  function totalSupplyNotInvested() public view override returns (uint256) {
    return
      super.totalSupply().rayMul(_reserve.getNormalizedIncome()) -
      (
        _reserve.strategyAddress == address(0)
          ? 0
          : IStrategy(_reserve.strategyAddress).balanceOf(address(this))
      );
  }

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return the scaled total supply
   *
   */
  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  function getDebtToken() external view returns (address) {
    return _reserve.debtTokenAddress;
  }

  /**
   * @dev Returns the address of the Unlockd treasury, receiving the fees on this uToken
   *
   */
  function RESERVE_TREASURY_ADDRESS() public view returns (address) {
    return _treasury;
  }

  /**
   * @dev Returns the address of the underlying asset of this uToken
   *
   */
  function UNDERLYING_ASSET_ADDRESS() public view returns (address) {
    return _reserve.underlyingAsset;
  }

  /**
   * @dev Upate State on the reserve onlyProtocol
   */
  function updateStateReserve() external {
    _reserve.updateState();
  }

  /**
   * @dev Get Borrow Index
   * @return reserve The reserve's struct
   */
  function getReserve() external view returns (DataTypes.ReserveData memory) {
    return _reserve;
  }

  function decimals() public view virtual override returns (uint8) {
    return _reserve.decimals;
  }

  /**
   * @dev Set the treasury address
   * @param treasury address of the new treasury
   */
  function setTreasuryAddress(address treasury) external onlyAdmin {
    Errors.verifyNotZero(treasury);
    _treasury = treasury;
  }

  ///////////////////////////////////////////////////////
  /////////////////////// PRIVATE ///////////////////////
  ///////////////////////////////////////////////////////

  /**
   * @dev Burns uTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
   * - Only callable by the LendPool, as extra state updates there need to be managed
   * @param user The owner of the uTokens, getting them burned
   * @param receiverOfUnderlying The address that will receive the underlying
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   *
   */
  function _burn(
    address user,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) internal {
    uint256 amountScaled = amount.rayDiv(index);

    Errors.verifyNotZero(amountScaled);
    _burn(user, amountScaled);
    IERC20(_reserve.underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
    emit Burn(user, receiverOfUnderlying, amount, index);
  }

  /**
   * @dev Mints `amount` uTokens to `user`
   * - Only callable by the LendPool, as extra state updates there need to be managed
   * @param user The address receiving the minted tokens
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   * @return `true` if the the previous balance of the user was 0
   */
  function _mint(address user, uint256 amount, uint256 index) internal returns (bool) {
    uint256 previousBalance = super.balanceOf(user);
    uint256 amountScaled = amount.rayDiv(index);
    Errors.verifyNotZero(amountScaled);
    _mint(user, amountScaled);
    emit Mint(user, amount, index);
    return previousBalance == 0;
  }

  /**
   * @dev Mints uTokens to the reserve treasury
   * - Only callable by the LendPool
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   */
  function _mintToTreasury(uint256 amount, uint256 index) internal {
    if (amount == 0) return;
    _mint(_treasury, amount.rayDiv(index));
  }
}
