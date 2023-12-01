// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {DataTypes} from '../../types/DataTypes.sol';

interface IUToken {
  /**
   * @dev Emitted when an uToken is initialized
   * @param underlyingAsset The address of the underlying asset
   * @param interestRate The address of the interest rate
   * @param treasury The address of the treasury
   *
   */
  event Initialized(
    address indexed underlyingAsset,
    address indexed interestRate,
    address indexed strategy,
    address treasury
  );

  /**
   * @dev Initializes the bToken
   * @param aclManager Admin address
   * @param treasury The address of the Unlockd treasury, receiving the fees on this bToken
   * @param underlyingAsset The address of the underlying asset of this bToken
   * @param interestRateAddress The address of interest rate
   * @param debtTokenAddress The address of interest rate
   * @param decimals The amount of token decimals
   * @param reserveFactor Reserve factor
   * @param tokenName The name of the token
   * @param tokenSymbol The token symbol
   */
  function initialize(
    address aclManager,
    address treasury,
    address underlyingAsset,
    address interestRateAddress,
    address strategyAddress,
    address debtTokenAddress,
    uint8 decimals,
    uint16 reserveFactor,
    string calldata tokenName,
    string calldata tokenSymbol
  ) external;

  /**
   * @dev Emitted when the state of a reserve is updated. NOTE: This event is actually declared
   * in the ReserveLogic library and emitted in the updateInterestRates() function. Since the function is internal,
   * the event will actually be fired by the UToken contract. The event is therefore replicated here so it
   * gets added to the UToken ABI
   * @param reserve The address of the underlying asset of the reserve
   * @param liquidityRate The new liquidity rate
   * @param variableBorrowRate The new variable borrow rate
   * @param liquidityIndex The new liquidity index
   * @param variableBorrowIndex The new variable borrow index
   *
   */
  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );
  /**
   * @dev Emitted on deposit()
   * @param user The address initiating the deposit
   * @param amount The amount deposited
   * @param reserve The address of the underlying asset of the reserve
   * @param onBehalfOf The beneficiary of the deposit, receiving the uTokens
   * @param referral The referral code used
   *
   */
  event Deposit(
    address user,
    address indexed reserve,
    uint256 amount,
    address indexed onBehalfOf,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on borrowOnBelhalf()
   * @param onBehalfOf The on belfhalf of the user
   * @param iniciator The address initiating the deposit
   * @param amount The amount deposited
   * @param loanId number
   * @param underlyingAsset address of the underlying
   * @param borrowRate index borrow rate
   */
  event BorrowOnBelhalf(
    address indexed onBehalfOf,
    address indexed iniciator,
    uint256 indexed amount,
    bytes32 loanId,
    address underlyingAsset,
    uint256 borrowRate
  );

  /**
   * @dev Emitted on repayOnBelhalf()
   * @param iniciator The address initiating the deposit
   * @param loanId number
   * @param underlyingAsset address of the underlying
   * @param amount The amount deposited
   * @param onBehalfOf The beneficiary of the deposit, receiving the uTokens
   * @param borrowRate index borrow rate
   */
  event RepayOnBelhalf(
    address iniciator,
    bytes32 loanId,
    address underlyingAsset,
    uint256 indexed amount,
    address indexed onBehalfOf,
    uint256 borrowRate
  );

  /**
   * @dev Emitted on withdraw()
   * @param user The address initiating the withdrawal, owner of uTokens
   * @param reserve The address of the underlyng asset being withdrawn
   * @param amount The amount to be withdrawn
   * @param to Address that will receive the underlying
   *
   */
  event Withdraw(address indexed user, address indexed reserve, uint256 amount, address indexed to);

  /**
   * @dev Emitted when the pause is triggered.
   */
  event Paused();

  /**
   * @dev Emitted when the pause is lifted.
   */
  event Unpaused();

  /**
   * @dev Emitted when the pause time is updated.
   */
  event PausedTimeUpdated(uint256 startTime, uint256 durationTime);

  /**
   * @dev Emitted after the mint action
   * @param from The address performing the mint
   * @param value The amount being
   * @param index The new liquidity index of the reserve
   *
   */
  event Mint(address indexed from, uint256 value, uint256 index);

  /**
   * @dev Emitted after uTokens are burned
   * @param from The owner of the uTokens, getting them burned
   * @param target The address that will receive the underlying
   * @param value The amount being burned
   * @param index The new liquidity index of the reserve
   *
   */
  event Burn(address indexed from, address indexed target, uint256 value, uint256 index);

  /**
   * @dev Emitted during the transfer action
   * @param from The user whose tokens are being transferred
   * @param to The recipient
   * @param value The amount being transferred
   * @param index The new liquidity index of the reserve
   *
   */
  event BalanceTransfer(address indexed from, address indexed to, uint256 value, uint256 index);

  /**
   * @dev Emitted when treasury address is updated in utoken
   * @param _newTreasuryAddress The new treasury address
   *
   */
  event TreasuryAddressUpdated(address indexed _newTreasuryAddress);

  /**
   * @dev Emitted after sweeping liquidity from the uToken to deposit it to external lending protocol
   * @param uToken The uToken swept
   * @param underlyingAsset The underlying asset from the uToken
   * @param amount The amount deposited to the lending protocol
   */
  event UTokenSwept(
    address indexed uToken,
    address indexed underlyingAsset,
    uint256 indexed amount
  );

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
  function deposit(uint256 amount, address onBehalfOf, uint16 referralCode) external;

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
  function withdraw(uint256 amount, address to) external returns (uint256);

  function getReserveNormalizedVariableDebt() external view returns (uint256);

  /**
   * @dev Returns the address of the underlying asset of this uToken
   *
   */
  function UNDERLYING_ASSET_ADDRESS() external view returns (address);

  /**
   * @dev Returns the address of the treasury set to this uToken
   *
   */
  function RESERVE_TREASURY_ADDRESS() external view returns (address);

  /**
   * @dev Sets the address of the treasury to this uToken
   *
   */
  function setTreasuryAddress(address treasury) external;

  /**
   * @dev Borrow on belfhalf
   */
  function borrowOnBelhalf(bytes32 loanId, uint256 amount, address to, address onBehalfOf) external;

  function repayOnBelhalf(
    bytes32 loanId,
    uint256 amount,
    address from,
    address onBehalfOf
  ) external;

  function getReserve() external view returns (DataTypes.ReserveData memory);

  /**
   * @dev External call to update the state of the reserves
   * */
  function updateStateReserve() external;

  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   *
   */
  function scaledBalanceOf(address user) external view returns (uint256);

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return The scaled total supply
   *
   */

  function scaledTotalSupply() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function totalUnderlyingBalanceNotInvested() external view returns (uint256);

  function totalUnderlyingBalance() external view returns (uint256);

  function getDebtToken() external view returns (address);
}
